import Foundation
import SwiftUI

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published private(set) var queue: [ReminderItem] = []
    @Published var itemNeedingCustomInterval: ReminderItem?

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

    func loadQueue() {
        queue = (try? reminderRepository.fetchNightlyReviewItems(
            confidenceThreshold: classificationConfidenceThreshold
        )) ?? []
    }

    /// Swipe right: accept the classification as-is.
    func accept(_ item: ReminderItem) {
        guard item.recurringInterval == .custom, item.customIntervalMonths == nil else {
            Task { await resolve(item, customIntervalMonths: nil) }
            return
        }
        itemNeedingCustomInterval = item
    }

    /// Swipe left: skip for now, without discarding the item.
    func skip(_ item: ReminderItem) {
        Task { await resolve(item, customIntervalMonths: nil) }
    }

    func confirmCustomInterval(months: Int) {
        guard let item = itemNeedingCustomInterval else { return }
        itemNeedingCustomInterval = nil
        Task { await resolve(item, customIntervalMonths: months) }
    }

    private func resolve(_ item: ReminderItem, customIntervalMonths: Int?) async {
        let bucket = item.bucket ?? .quickTask
        try? reminderRepository.applyClassification(
            to: item.id,
            bucket: bucket,
            urgency: item.urgency ?? .low,
            deadline: item.deadline,
            recurringInterval: item.recurringInterval ?? .none,
            customIntervalMonths: customIntervalMonths,
            confidence: item.confidence ?? 0,
            reviewedAt: Date()
        )
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
    }
}
