import Foundation
import UserNotifications
import os

protocol NotificationScheduler {
    func requestAuthorization() async -> Bool
    func scheduleNightlyReviewDigest(pendingCount: Int, hour: Int, minute: Int) async
    func scheduleLongHorizonSequence(
        itemId: UUID,
        rawText: String,
        stages: NudgeSchedulingLogic.ScheduleStages,
        includeDueDateCheckIn: Bool,
        quietHoursWindow: QuietHours.Window
    ) async
    func cancelLongHorizonSequence(itemId: UUID) async
}

final class UNNotificationScheduler: NotificationScheduler {
    private static let nightlyReviewIdentifier = "nightly-review-digest"
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Notifications")

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Only schedules when there's something to review — avoids notification fatigue
    /// per CLAUDE.md's non-negotiable rule.
    func scheduleNightlyReviewDigest(pendingCount: Int, hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.nightlyReviewIdentifier])

        guard pendingCount > 0 else {
            logger.info("Nightly review queue empty — no notification scheduled")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Nightly review"
        content.body = pendingCount == 1
            ? "1 nudge needs a quick look."
            : "\(pendingCount) nudges need a quick look."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: Self.nightlyReviewIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logger.info("Nightly review digest notification scheduled")
        } catch {
            logger.error("Failed to schedule nightly review digest notification")
        }
    }

    func scheduleLongHorizonSequence(
        itemId: UUID,
        rawText: String,
        stages: NudgeSchedulingLogic.ScheduleStages,
        includeDueDateCheckIn: Bool,
        quietHoursWindow: QuietHours.Window
    ) async {
        await cancelLongHorizonSequence(itemId: itemId)

        await schedule(
            identifier: Self.identifier(for: itemId, stage: "lead"),
            title: "Coming up",
            body: rawText,
            at: stages.leadNudgeAt,
            categoryIdentifier: nil,
            quietHoursWindow: quietHoursWindow
        )
        await schedule(
            identifier: Self.identifier(for: itemId, stage: "second"),
            title: "Almost due",
            body: rawText,
            at: stages.secondNudgeAt,
            categoryIdentifier: nil,
            quietHoursWindow: quietHoursWindow
        )

        // If disabled, the item simply isn't prompted for completion and does
        // not auto-reschedule, per NudgeAI_Spec.md.
        guard includeDueDateCheckIn else { return }
        await schedule(
            identifier: Self.identifier(for: itemId, stage: "due"),
            title: "Due today",
            body: rawText,
            at: stages.dueDateCheckInAt,
            categoryIdentifier: Self.dueDateCheckInCategory,
            quietHoursWindow: quietHoursWindow
        )
    }

    func cancelLongHorizonSequence(itemId: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.identifier(for: itemId, stage: "lead"),
            Self.identifier(for: itemId, stage: "second"),
            Self.identifier(for: itemId, stage: "due")
        ])
    }

    private func schedule(
        identifier: String,
        title: String,
        body: String,
        at date: Date,
        categoryIdentifier: String?,
        quietHoursWindow: QuietHours.Window
    ) async {
        let adjustedDate = QuietHours.adjust(date, window: quietHoursWindow)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: adjustedDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to schedule long-horizon stage notification")
        }
    }

    private static func identifier(for itemId: UUID, stage: String) -> String {
        "long-horizon-\(stage)-\(itemId.uuidString)"
    }

    static let dueDateCheckInCategory = "due-date-check-in"
}
