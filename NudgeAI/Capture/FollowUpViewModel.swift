import Foundation
import os

@MainActor
final class FollowUpViewModel: ObservableObject {
    @Published private(set) var question: FollowUpQuestion?
    @Published private(set) var isComplete = false
    @Published private(set) var computedBucket: ReminderBucket?
    @Published private(set) var computedDeadline: Date?
    @Published var isPromptingCustomInterval = false

    private let item: ReminderItem
    private let client: ClassificationClient
    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let notificationScheduler: NotificationScheduler
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Capture")

    private var classifyTask: Task<ClassificationResult?, Never>?

    init(
        item: ReminderItem,
        client: ClassificationClient,
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

        let bucket = classification?.bucket ?? .quickTask
        let urgency = classification?.urgency ?? .medium
        let confidence = classification?.confidence ?? 0

        do {
            try reminderRepository.applyPreStructuredResult(
                to: item.id,
                bucket: bucket,
                urgency: urgency,
                deadline: deadline,
                recurringInterval: recurringInterval,
                customIntervalMonths: customIntervalMonths,
                confidence: confidence
            )
        } catch {
            logger.error("Failed to apply pre-structured result")
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
