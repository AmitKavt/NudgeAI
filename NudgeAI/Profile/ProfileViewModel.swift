import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var capturedCount = 0
    @Published private(set) var oneTapReviewRate: Double = 0
    @Published private(set) var currentMonthSpend: Double = 0
    @Published private(set) var currentMonthRequestCount = 0
    @Published private(set) var nudgingSinceLabel: String = ""
    @Published private(set) var selectedModelName: String = ""
    @Published private(set) var siriPhrase: String = ""
    @Published private(set) var provider: AIProvider = .none
    @Published private(set) var signOutError: String?
    @Published private(set) var unpricedRequestCount = 0

    @Published private(set) var appleDisplayName: String?
    @Published private(set) var isSignedInWithApple = false
    private var identity: AppleIdentityManager?

    var displayName: String { appleDisplayName ?? "You" }
    var initials: String { AppleIdentityRules.initials(for: appleDisplayName) }

    var providerName: String { provider.displayName }
    /// Usage section is hidden with no provider.
    var showsUsage: Bool { provider != .none }
    /// Cost is shown only when every request was priced; otherwise request count only.
    var showsCost: Bool { unpricedRequestCount == 0 }

    /// All stats are read-only aggregates computed at request time — never
    /// materialized/stored fields that could drift from source data, per
    /// data-conventions.md. Avg capture time isn't tracked by the data model
    /// yet, so it isn't surfaced here.
    func load(
        reminderRepository: ReminderRepository,
        spendEstimateRepository: SpendEstimateRepository,
        settingsRepository: SettingsRepository,
        identity: AppleIdentityManager? = nil
    ) {
        if let identity { self.identity = identity }
        let items = (try? reminderRepository.fetchAll()) ?? []
        capturedCount = items.count

        // Only LLM-classified items count toward the review rate; manually sorted
        // and never-sorted items are excluded.
        let llmItems = items.filter { $0.classifiedBy == .llm }
        let reviewed = llmItems.filter { $0.reviewedAt != nil }
        oneTapReviewRate = llmItems.isEmpty ? 0 : Double(reviewed.count) / Double(llmItems.count)

        let estimate = try? spendEstimateRepository.currentMonthEstimate()
        currentMonthSpend = estimate?.estimatedCost ?? 0
        currentMonthRequestCount = estimate?.requestCount ?? 0
        unpricedRequestCount = estimate?.unpricedRequestCount ?? 0

        // No onboarding-completed date is stored — approximate from the earliest capture.
        let earliest = items.map(\.createdAt).min() ?? Date()
        nudgingSinceLabel = earliest.formatted(.dateTime.month(.wide).year())

        if let settings = try? settingsRepository.fetchSettings() {
            provider = settings.provider
            selectedModelName = ProviderModels.displayName(for: settings.modelId)
            siriPhrase = settings.siriPhrase
            appleDisplayName = settings.appleDisplayName
        }
        isSignedInWithApple = identity?.isSignedIn ?? false
    }

    /// Clears the Apple identifier and name. Nudges and API keys are kept.
    func signOut(reloading reload: () -> Void) {
        do {
            try identity?.signOut()
            signOutError = nil
        } catch {
            signOutError = "Couldn't sign out. Try again."
        }
        reload()
    }
}
