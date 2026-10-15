import Foundation
import SwiftData

/// One-time, idempotent data backfills run at launch (see NudgeAIApp).
///
/// Schema side: every Phase 7 addition is an optional or defaulted property
/// (`ReminderItem.classifiedBy`, `AppSettings.provider/modelId/appleDisplayName`),
/// so SwiftData lightweight migration applies with no custom stage. Existing rows
/// therefore load with `classifiedBy == nil`, `provider == .none`, and the default
/// `modelId`; this pass then fixes up the values:
///   - items with a bucket and no classifiedBy  -> `.llm` (they were all Claude results)
///   - an existing settings row that has a stored Anthropic key -> provider `.anthropic`,
///     modelId from the legacy `selectedModel` column
/// A new install (no settings row yet) is left at provider `.none`.
/// Completion is recorded in UserDefaults; re-running is also harmless because both
/// updates only touch rows still in their un-migrated state.
enum PersistenceMigrations {
    static let phase7DefaultsKey = "migration.phase7.slice1.v1"

    @MainActor
    static func runPhase7IfNeeded(
        context: ModelContext,
        apiKeyStore: APIKeyStore,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: phase7DefaultsKey) else { return }
        do {
            let items = try context.fetch(FetchDescriptor<ReminderItem>())
            for item in items where item.bucket != nil && item.classifiedBy == nil {
                item.classifiedBy = .llm
            }

            if let settings = try context.fetch(FetchDescriptor<AppSettings>()).first,
               settings.provider == .none,
               apiKeyStore.hasKey(for: .anthropic) {
                settings.provider = .anthropic
                settings.modelId = settings.selectedModel == .sonnet
                    ? ProviderModels.anthropicSonnetId
                    : ProviderModels.anthropicHaikuId
            }

            try context.save()
            defaults.set(true, forKey: phase7DefaultsKey)
        } catch {
            // Leave the flag unset so the pass retries next launch.
        }
    }

    static let keychainAccessibilityDefaultsKey = "migration.keychain.thisDeviceOnly.v1"

    /// One-time re-save so installs that stored secrets with the older
    /// `AfterFirstUnlock` class pick up `...ThisDeviceOnly` (the store deletes then
    /// adds). Values are only passed straight back to the store, never logged.
    /// Any failure leaves the flag unset so the pass retries next launch.
    static func runKeychainAccessibilityIfNeeded(
        apiKeyStore: APIKeyStore,
        identityStore: AppleIdentityStore,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: keychainAccessibilityDefaultsKey) else { return }
        do {
            for provider in AIProvider.allCases where provider != .none {
                if let key = try apiKeyStore.readAPIKey(for: provider) {
                    try apiKeyStore.saveAPIKey(key, for: provider)
                }
            }
            if let id = try identityStore.readIdentifier() {
                try identityStore.saveIdentifier(id)
            }
            defaults.set(true, forKey: keychainAccessibilityDefaultsKey)
        } catch {
            // Retry next launch.
        }
    }
}
