import Foundation
import SwiftData

/// Decides when still-unsorted items are classified after a provider is connected.
enum BackfillPolicy {
    static let defaultsKey = "backfilledProvider"

    /// Run once per connected platform: only when a provider is connected and the
    /// last platform backfilled differs. Never when no provider.
    static func shouldRun(provider: AIProvider, lastBackfilled: String?) -> Bool {
        provider != .none && lastBackfilled != provider.rawValue
    }
}

/// One-shot background classification of never-sorted items (bucket == nil,
/// which excludes manual sorts and items a previous provider classified).
@MainActor
enum ProviderBackfill {
    private static var isRunning = false

    static func runIfNeeded(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        guard !isRunning,
              let settings = try? SwiftDataSettingsRepository(modelContext: modelContext).fetchSettings(),
              BackfillPolicy.shouldRun(provider: settings.provider, lastBackfilled: defaults.string(forKey: BackfillPolicy.defaultsKey)) else { return }
        let provider = settings.provider
        let reminderRepository = SwiftDataReminderRepository(modelContext: modelContext)
        let settingsRepository = SwiftDataSettingsRepository(modelContext: modelContext)
        guard let client = ClassificationClientFactory.makeClient(
            settingsRepository: settingsRepository,
            apiKeyStore: KeychainAPIKeyStore(),
            spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
        ) else { return }
        isRunning = true
        let coordinator = ClassificationCoordinator(
            client: client, reminderRepository: reminderRepository,
            settingsRepository: settingsRepository, unreachableState: .shared
        )
        Task {
            // Marked done only when the provider was reachable; otherwise retried next launch/visit.
            if await coordinator.classifyUnsorted() { defaults.set(provider.rawValue, forKey: BackfillPolicy.defaultsKey) }
            isRunning = false
        }
    }
}
