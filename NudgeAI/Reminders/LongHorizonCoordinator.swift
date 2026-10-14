import Foundation
import os

/// Wires the due-date check-in notification actions to the reschedule logic.
/// On "Done": lastCompletedAt updates, next cycle is scheduled.
/// On "Not yet": the sequence restarts at the next cycle, lastCompletedAt is untouched.
final class LongHorizonCoordinator {
    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let notificationScheduler: NotificationScheduler
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Reminders")

    init(
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        notificationScheduler: NotificationScheduler
    ) {
        self.reminderRepository = reminderRepository
        self.settingsRepository = settingsRepository
        self.notificationScheduler = notificationScheduler
    }

    func attach(to actionHandler: NotificationActionHandler) {
        actionHandler.onDone = { [weak self] itemId in
            Task { await self?.handleCheckIn(itemId: itemId, completed: true) }
        }
        actionHandler.onNotYet = { [weak self] itemId in
            Task { await self?.handleCheckIn(itemId: itemId, completed: false) }
        }
    }

    private func handleCheckIn(itemId: UUID, completed: Bool) async {
        do {
            guard
                let item = try reminderRepository.fetchItem(id: itemId),
                let currentDeadline = item.deadline,
                let recurringInterval = item.recurringInterval,
                let settings = try? settingsRepository.fetchSettings()
            else { return }

            guard let newDeadline = NudgeSchedulingLogic.nextCycleDeadline(
                currentDeadline: currentDeadline,
                recurringInterval: recurringInterval,
                customIntervalMonths: item.customIntervalMonths
            ) else { return }

            let stages = NudgeSchedulingLogic.computeStages(
                deadline: newDeadline,
                leadTimeFirstDays: settings.leadTimeFirstDays,
                leadTimeSecondDays: settings.leadTimeSecondDays
            )
            let nextNudgeAt = NudgeSchedulingLogic.nextNudgeAt(from: stages)

            try reminderRepository.rescheduleLongHorizonCycle(
                itemId: itemId,
                newDeadline: newDeadline,
                newNextNudgeAt: nextNudgeAt,
                completedAt: completed ? Date() : nil
            )

            await LongHorizonNotificationScheduling.schedule(
                itemId: itemId,
                rawText: item.rawText,
                deadline: newDeadline,
                settingsRepository: settingsRepository,
                notificationScheduler: notificationScheduler
            )
            if completed {
                logger.info("Long-horizon cycle marked done")
            } else {
                logger.info("Long-horizon cycle rescheduled (not yet)")
            }
        } catch {
            logger.error("Failed to handle long-horizon check-in action")
        }
    }
}
