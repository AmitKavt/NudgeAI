import Foundation

/// Shared entry point for (re)scheduling a long-horizon item's notification
/// sequence from live `AppSettings` — used wherever an item first becomes
/// `.longHorizon` with a deadline (classification, nightly digest, in-app
/// follow-up, nightly review accept) and by `LongHorizonCoordinator` on
/// Done/Not yet.
enum LongHorizonNotificationScheduling {
    static func schedule(
        itemId: UUID,
        rawText: String,
        deadline: Date,
        settingsRepository: SettingsRepository,
        notificationScheduler: NotificationScheduler
    ) async {
        guard let settings = try? settingsRepository.fetchSettings() else { return }

        let stages = NudgeSchedulingLogic.computeStages(
            deadline: deadline,
            leadTimeFirstDays: settings.leadTimeFirstDays,
            leadTimeSecondDays: settings.leadTimeSecondDays
        )

        _ = await notificationScheduler.requestAuthorization()
        await notificationScheduler.scheduleLongHorizonSequence(
            itemId: itemId,
            rawText: rawText,
            stages: stages,
            includeDueDateCheckIn: settings.dueDateCheckInEnabled,
            quietHoursWindow: QuietHours.Window.from(settings: settings)
        )
    }
}
