import Foundation

/// App-wide signal for whether the last Claude API request failed outright.
/// Consumed by the Today banner and Review's paused state; cleared
/// automatically on the next successful classification call.
@MainActor
final class ClaudeUnreachableState: ObservableObject {
    /// Shared app-wide instance — holds no user data, just a reachability flag,
    /// so it's exempt from the no-singletons rule. Needed because the Siri
    /// App Intent runs outside the SwiftUI environment hierarchy.
    static let shared = ClaudeUnreachableState()

    @Published private(set) var isUnreachable = false

    func markUnreachable() {
        isUnreachable = true
    }

    func markReachable() {
        isUnreachable = false
    }
}
