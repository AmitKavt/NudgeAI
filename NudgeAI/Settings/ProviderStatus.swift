import Foundation

/// Honest connection status shown in Settings, derived from real state.
enum ProviderConnectionStatus: Equatable {
    case notConnected
    case connected
    case cantReach
    case keyRejected

    var label: String {
        switch self {
        case .notConnected: return "Not connected"
        case .connected: return "Connected"
        case .cantReach: return "Can't reach"
        case .keyRejected: return "Key rejected"
        }
    }

    static func resolve(selected: AIProvider, activeProvider: AIProvider, hasKey: Bool, isUnreachable: Bool, isKeyRejected: Bool = false) -> ProviderConnectionStatus {
        guard selected != .none, hasKey else { return .notConnected }
        guard selected == activeProvider else { return .notConnected }
        if isKeyRejected { return .keyRejected }
        return isUnreachable ? .cantReach : .connected
    }
}

enum KeyCheckMessages {
    /// Plain-language message for a failed key check. Never includes the key or raw response.
    static func message(for error: Error, provider: AIProvider) -> String {
        let name = provider.displayName
        guard let check = error as? KeyCheckError else { return "Couldn't save the key. Try again." }
        switch check {
        case .invalidKey: return "That key wasn't accepted by \(name). Check it and try again."
        case .unreachable: return "Couldn't reach \(name). Check your connection and try again."
        case .rejected(402): return "\(name) says the account has insufficient balance. Add credit there, then try again."
        case .rejected: return "\(name) rejected the request. Check the key and try again."
        }
    }
}
