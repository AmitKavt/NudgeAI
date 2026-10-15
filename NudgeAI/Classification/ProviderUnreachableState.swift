import Foundation

/// App-wide signal for whether the last provider API request failed outright.
/// Consumed by the Today banner and Review's paused state; cleared
/// automatically on the next successful classification call.
@MainActor
final class ProviderUnreachableState: ObservableObject {
    /// Shared app-wide instance — holds no user data, just a reachability flag,
    /// so it's exempt from the no-singletons rule. Needed because the Siri
    /// App Intent runs outside the SwiftUI environment hierarchy.
    static let shared = ProviderUnreachableState()

    @Published private(set) var isUnreachable = false

    /// The provider answered 401/403: reachable, but the stored key was rejected.
    @Published private(set) var isKeyRejected = false

    func markKeyRejected() {
        isKeyRejected = true
    }

    func markUnreachable() {
        isUnreachable = true
    }

    func markReachable() {
        isUnreachable = false
        isKeyRejected = false
    }
}
