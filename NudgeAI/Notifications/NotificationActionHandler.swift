import Foundation
import UserNotifications

enum NudgeNotificationAction: String {
    case done = "NUDGE_DONE"
    case notYet = "NUDGE_NOT_YET"
}

/// Registers the Done/Not yet actionable category and routes responses —
/// works without opening the app, per design-system.md's NudgeNotificationAction.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    var onDone: ((UUID) -> Void)?
    var onNotYet: ((UUID) -> Void)?

    func registerCategories() {
        let doneAction = UNNotificationAction(
            identifier: NudgeNotificationAction.done.rawValue,
            title: "Done",
            options: []
        )
        let notYetAction = UNNotificationAction(
            identifier: NudgeNotificationAction.notYet.rawValue,
            title: "Not yet",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: UNNotificationScheduler.dueDateCheckInCategory,
            actions: [doneAction, notYetAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard
            response.notification.request.content.categoryIdentifier == UNNotificationScheduler.dueDateCheckInCategory,
            let itemId = Self.itemId(from: response.notification.request.identifier)
        else { return }

        switch response.actionIdentifier {
        case NudgeNotificationAction.done.rawValue:
            onDone?(itemId)
        case NudgeNotificationAction.notYet.rawValue:
            onNotYet?(itemId)
        default:
            break
        }
    }

    private static func itemId(from requestIdentifier: String) -> UUID? {
        let uuidString = requestIdentifier.split(separator: "-").suffix(5).joined(separator: "-")
        return UUID(uuidString: uuidString)
    }
}
