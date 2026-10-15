import AppIntents
import SwiftData
import os

struct CaptureNudgeIntent: AppIntent {
    static var title: LocalizedStringResource = "Nudge Me"
    static var description = IntentDescription("Capture a nudge by speaking, with no further questions.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "What do you want to be nudged about?", requestValueDialog: "What's the nudge?")
    var spokenText: String

    private static let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Capture")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let modelContext = PersistenceContainer.makeModelContainer().mainContext
        let reminderRepository = SwiftDataReminderRepository(modelContext: modelContext)
        let settingsRepository = SwiftDataSettingsRepository(modelContext: modelContext)

        let item: ReminderItem
        do {
            item = try reminderRepository.createReminder(
                rawText: spokenText,
                createdAt: Date(),
                source: .siri,
                transcriptionConfidence: nil
            )
            Self.logger.info("Captured nudge via Siri")
        } catch {
            Self.logger.error("Failed to persist captured nudge")
            throw error
        }

        // No provider or no key: the nudge stays stored and unsorted, silently.
        guard let classificationClient = ClassificationClientFactory.makeClient(
            settingsRepository: settingsRepository,
            apiKeyStore: KeychainAPIKeyStore(),
            spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
        ) else {
            return .result(dialog: "Got it.")
        }
        let coordinator = ClassificationCoordinator(
            client: classificationClient,
            reminderRepository: reminderRepository,
            settingsRepository: settingsRepository,
            unreachableState: .shared
        )
        coordinator.classify(itemId: item.id, rawText: item.rawText)

        return .result(dialog: "Got it.")
    }
}

struct NudgeAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureNudgeIntent(),
            phrases: [
                "Nudge me with \(.applicationName)",
                "Add a nudge in \(.applicationName)"
            ],
            shortTitle: "Nudge Me",
            systemImageName: "bell.badge"
        )
    }
}
