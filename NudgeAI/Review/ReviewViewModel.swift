import Foundation
import SwiftUI

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published private(set) var queue: [ReminderItem] = []
    @Published var itemNeedingCustomInterval: ReminderItem?
    @Published var itemBeingAdjusted: ReminderItem?

    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let notificationScheduler: NotificationScheduler

    init(
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        notificationScheduler: NotificationScheduler = UNNotificationScheduler()
    ) {
        self.reminderRepository = reminderRepository
        self.settingsRepository = settingsRepository
        self.notificationScheduler = notificationScheduler
    }

    /// Connected platform; `.none` when the user sorts everything by hand.
    var provider: AIProvider {
        (try? settingsRepository.fetchSettings().provider) ?? AIProvider.none
    }

    func loadQueue() {
        queue = (try? reminderRepository.fetchNightlyReviewItems(
            confidenceThreshold: classificationConfidenceThreshold
        )) ?? []
    }

    /// Swipe right: accept the classification as-is.
    func accept(_ item: ReminderItem) {
        // Unsorted cards can't be accepted until bucket and urgency are set (via Adjust).
        guard ReviewRules.canAccept(bucket: item.bucket, urgency: item.urgency) else { return }
        guard item.recurringInterval == .custom, item.customIntervalMonths == nil else {
            Task { await resolve(item, customIntervalMonths: nil) }
            return
        }
        itemNeedingCustomInterval = item
    }

    /// Swipe left: skip for now. Only drops the card from this session's queue;
    /// nothing is persisted, so the item returns at the next review (never marked reviewed).
    func skip(_ item: ReminderItem) {
        queue.removeAll { $0.id == item.id }
    }

    func confirmCustomInterval(months: Int) {
        guard let item = itemNeedingCustomInterval else { return }
        itemNeedingCustomInterval = nil
        Task { await resolve(item, customIntervalMonths: months) }
    }

    func beginAdjust(_ item: ReminderItem) {
        itemBeingAdjusted = item
    }

    /// Adjust save: manual sort (classifiedBy = .manual, confidence nil, reviewedAt now),
    /// then the same long-horizon scheduling an accepted suggestion gets. The card leaves the queue.
    func saveAdjust(_ item: ReminderItem, draft: AdjustDraft) async {
        guard let result = draft.result() else { return }
        itemBeingAdjusted = nil
        do {
            try reminderRepository.applyManualSort(
                to: item.id,
                bucket: result.bucket,
                urgency: result.urgency,
                deadline: result.deadline,
                recurringInterval: result.recurringInterval,
                customIntervalMonths: result.customIntervalMonths
            )
        } catch { return }
        queue.removeAll { $0.id == item.id }

        if result.bucket != .longHorizon || result.deadline == nil {
            await notificationScheduler.cancelLongHorizonSequence(itemId: item.id)
        }
        if result.bucket == .longHorizon, let deadline = result.deadline {
            await LongHorizonNotificationScheduling.schedule(
                itemId: item.id,
                rawText: item.rawText,
                deadline: deadline,
                settingsRepository: settingsRepository,
                notificationScheduler: notificationScheduler
            )
        }
        await refreshNightlyNotification()
    }

    private func refreshNightlyNotification() async {
        await NightlyReviewScheduling.refresh(
            reminderRepository: reminderRepository,
            settingsRepository: settingsRepository,
            notificationScheduler: notificationScheduler
        )
    }

    private func resolve(_ item: ReminderItem, customIntervalMonths: Int?) async {
        // Accept path only (skip never reaches here). Unsorted items are only dropped
        // from this session's queue; they stay unreviewed until sorted via Adjust.
        guard let bucket = item.bucket else {
            queue.removeAll { $0.id == item.id }
            return
        }
        try? reminderRepository.markReviewed(id: item.id, customIntervalMonths: customIntervalMonths)
        queue.removeAll { $0.id == item.id }

        if bucket == .longHorizon, let deadline = item.deadline {
            await LongHorizonNotificationScheduling.schedule(
                itemId: item.id,
                rawText: item.rawText,
                deadline: deadline,
                settingsRepository: settingsRepository,
                notificationScheduler: notificationScheduler
            )
        }
        await refreshNightlyNotification()
    }
}
