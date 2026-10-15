import Foundation

/// Settings-owned interface for connecting a platform: the only path that
/// writes or deletes API keys (Onboarding and Settings both go through it).
final class ProviderConnectionService {
    private let apiKeyStore: APIKeyStore
    private let keyChecker: APIKeyChecker
    private let settingsRepository: SettingsRepository
    private let defaults: UserDefaults

    init(apiKeyStore: APIKeyStore, keyChecker: APIKeyChecker = LLMKeyChecker(), settingsRepository: SettingsRepository,
         defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.apiKeyStore = apiKeyStore
        self.keyChecker = keyChecker
        self.settingsRepository = settingsRepository
    }

    /// Verifies the key with one minimal request; only on success stores it and
    /// selects the platform. A failed check stores nothing. Throws `KeyCheckError`.
    func connect(provider: AIProvider, apiKey: String) async throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider != .none, !trimmed.isEmpty else { throw KeyCheckError.invalidKey }
        let current = try settingsRepository.fetchSettings()
        let modelId = current.provider == provider ? current.modelId : ProviderModels.defaultModelId(for: provider)
        try await keyChecker.check(provider: provider, apiKey: trimmed, modelId: modelId)
        try saveKeyUnchecked(provider: provider, apiKey: trimmed)
    }

    /// Stores the key and selects the platform without a network check. Used only
    /// by the existing onboarding/settings save paths until slice 4 wires `connect`.
    func saveKeyUnchecked(provider: AIProvider, apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        try apiKeyStore.saveAPIKey(trimmed, for: provider)
        try settingsRepository.update { settings in
            if settings.provider != provider { settings.changeProvider(to: provider) }
        }
        resetUnreachable()
    }

    /// Deletes the platform's key; if it was the active platform, the app
    /// returns to no provider.
    func disconnect(provider: AIProvider) throws {
        // Key first, deliberately: if the settings update fails below, the key is
        // already gone (fail-safe) rather than lingering after a "disconnect".
        try apiKeyStore.deleteAPIKey(for: provider)
        // Reconnecting the same platform must backfill still-unsorted items again.
        defaults.removeObject(forKey: BackfillPolicy.defaultsKey)
        try settingsRepository.update { settings in
            if settings.provider == provider { settings.changeProvider(to: .none) }
        }
        resetUnreachable()
    }

    /// A stale "can't reach" flag from a previous platform must not outlive a platform change.
    private func resetUnreachable() {
        Task { @MainActor in ProviderUnreachableState.shared.markReachable() }
    }
}
