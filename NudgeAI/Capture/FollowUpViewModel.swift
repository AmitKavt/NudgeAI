import Foundation
import os

@MainActor
final class FollowUpViewModel: ObservableObject {
    @Published private(set) var question: FollowUpQuestion?
    @Published private(set) var isComplete = false
    @Published private(set) var computedBucket: ReminderBucket?
    @Published private(set) var computedDeadline: Date?
    @Published var isPromptingCustomInterval = false
    /// True when no provider is connected: the nudge is saved unsorted, no question asked.
    @Published private(set) var isSavedUnsorted = false

    /// Provider calls made from the capture UI give up after this long; the nudge
    /// is then saved unsorted instead of leaving the user waiting.
    nonisolated static let requestTimeout: TimeInterval = 20

    private let item: ReminderItem
    private let client: ClassificationClient?
    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let notificationScheduler: NotificationScheduler
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Capture")

    private var classifyTask: Task<ClassificationResult?, Never>?

    init(
        item: ReminderItem,
        client: ClassificationClient?,
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        notificationScheduler: NotificationScheduler = UNNotificationScheduler()
    ) {
        self.item = item
        self.client = client
        self.reminderRepository = reminderRepository
        self.settingsRepository = settingsRepository
        self.notificationScheduler = notificationScheduler
    }

    func start() async {
        // No provider connected: nothing to ask. The nudge stays stored and unsorted.
        guard let client else {
            isSavedUnsorted = true
            isComplete = true
            return
        }
        classifyTask = Task {
            try? await client.classify(rawText: item.rawText)
        }

        do {
            question = try await client.generateFollowUp(rawText: item.rawText)
        } catch {
            logger.error("Follow-up question generation failed")
            await finishWithoutDeadline()
        }
    }

    func select(_ option: QuickReplyOption) async {
        let resolution = QuickReplyResolver.resolve(option)
        await finish(deadline: resolution.deadline, recurringInterval: resolution.recurringInterval, customIntervalMonths: nil)
    }

    func promptCustomInterval() {
        isPromptingCustomInterval = true
    }

    func confirmCustomInterval(months: Int) async {
        isPromptingCustomInterval = false
        let deadline = Calendar.current.date(byAdding: .month, value: months, to: Date())
        await finish(deadline: deadline, recurringInterval: .custom, customIntervalMonths: months)
    }

    private func finishWithoutDeadline() async {
        await finish(deadline: nil, recurringInterval: .none, customIntervalMonths: nil)
    }

    private func finish(deadline: Date?, recurringInterval: RecurringInterval, customIntervalMonths: Int?) async {
        let classification = await classifyTask?.value

        var bucket: ReminderBucket?
        do {
            if let classification {
                bucket = classification.bucket
                try reminderRepository.applyPreStructuredResult(
                    to: item.id,
                    bucket: classification.bucket,
                    urgency: classification.urgency,
                    deadline: deadline,
                    recurringInterval: recurringInterval,
                    customIntervalMonths: customIntervalMonths,
                    confidence: classification.confidence,
                    classifiedBy: .llm
                )
            } else {
                // No provider result (timeout / failure): never assume a bucket or
                // urgency. Keep the user's chip choice; the item lands in review.
                try reminderRepository.applyFollowUpChoice(
                    to: item.id,
                    deadline: deadline,
                    recurringInterval: recurringInterval,
                    customIntervalMonths: customIntervalMonths
                )
            }
        } catch {
            logger.error("Failed to apply follow-up result")
        }

        if bucket == .longHorizon, let deadline {
            await LongHorizonNotificationScheduling.schedule(
                itemId: item.id,
                rawText: item.rawText,
                deadline: deadline,
                settingsRepository: settingsRepository,
                notificationScheduler: notificationScheduler
            )
        }

        computedBucket = bucket
        computedDeadline = deadline
        isComplete = true
    }
}
