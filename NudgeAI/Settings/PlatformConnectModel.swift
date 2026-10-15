import Foundation

/// Shared key-entry/connect state for Onboarding and Settings. All key writes
/// go through ProviderConnectionService; the key is never logged.
@MainActor
final class PlatformConnectModel: ObservableObject {
    @Published var provider: AIProvider
    @Published var keyInput = ""
    @Published private(set) var isConnecting = false
    @Published private(set) var errorMessage: String?

    private let service: ProviderConnectionService

    init(service: ProviderConnectionService, initialProvider: AIProvider = .deepseek) {
        self.service = service
        self.provider = initialProvider
    }

    func select(_ newProvider: AIProvider) {
        guard newProvider != provider else { return }
        provider = newProvider
        keyInput = ""
        errorMessage = nil
    }

    /// Returns true when the key was verified and stored.
    @discardableResult
    func connect() async -> Bool {
        guard !isConnecting else { return false }
        let target = provider   // the platform can change while the check is in flight
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard target != .none else { return false }
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your \(target.displayName) API key."
            return false
        }
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }
        do {
            try await service.connect(provider: target, apiKey: trimmed)
            if provider == target { keyInput = "" }
            return true
        } catch {
            errorMessage = KeyCheckMessages.message(for: error, provider: target)
            return false
        }
    }

    func disconnect(_ target: AIProvider) {
        do {
            try service.disconnect(provider: target)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't remove the key. Try again."
        }
    }

    static func keyPlaceholder(for provider: AIProvider) -> String { provider.keyPlaceholder }

    static func platformBlurb(for provider: AIProvider) -> String { provider.blurb }
}
