import SwiftUI
import SwiftData
import UserNotifications

@main
struct NudgeAIApp: App {
    let modelContainer = PersistenceContainer.makeModelContainer()

    let longHorizonCoordinator: LongHorizonCoordinator

    init() {
        let container = modelContainer
        PersistenceMigrations.runPhase7IfNeeded(
            context: container.mainContext,
            apiKeyStore: KeychainAPIKeyStore()
        )
        PersistenceMigrations.runKeychainAccessibilityIfNeeded(
            apiKeyStore: KeychainAPIKeyStore(),
            identityStore: KeychainAppleIdentityStore()
        )
        UNUserNotificationCenter.current().delegate = NotificationActionHandler.shared
        NotificationActionHandler.shared.registerCategories()

        longHorizonCoordinator = LongHorizonCoordinator(
            reminderRepository: SwiftDataReminderRepository(modelContext: container.mainContext),
            settingsRepository: SwiftDataSettingsRepository(modelContext: container.mainContext),
            notificationScheduler: UNNotificationScheduler()
        )
        longHorizonCoordinator.attach(to: NotificationActionHandler.shared)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
