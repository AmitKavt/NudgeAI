import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var capturedCount = 0
    @Published private(set) var oneTapReviewRate: Double = 0
    @Published private(set) var currentMonthSpend: Double = 0
    @Published private(set) var currentMonthRequestCount = 0
    @Published private(set) var nudgingSinceLabel: String = ""
    @Published private(set) var selectedModel: ClaudeModel = .haiku
    @Published private(set) var siriPhrase: String = ""

    /// All stats are read-only aggregates computed at request time — never
    /// materialized/stored fields that could drift from source data, per
    /// data-conventions.md. Avg capture time isn't tracked by the data model
    /// yet, so it isn't surfaced here.
    func load(
        reminderRepository: ReminderRepository,
        spendEstimateRepository: SpendEstimateRepository,
        settingsRepository: SettingsRepository
    ) {
        let items = (try? reminderRepository.fetchAll()) ?? []
        capturedCount = items.count

        let reviewed = items.filter { $0.reviewedAt != nil }
        oneTapReviewRate = items.isEmpty ? 0 : Double(reviewed.count) / Double(items.count)

        let estimate = try? spendEstimateRepository.currentMonthEstimate()
        currentMonthSpend = estimate?.estimatedCost ?? 0
        currentMonthRequestCount = estimate?.requestCount ?? 0

        // No onboarding-completed date is stored — approximate from the earliest capture.
        let earliest = items.map(\.createdAt).min() ?? Date()
        nudgingSinceLabel = earliest.formatted(.dateTime.month(.wide).year())

        if let settings = try? settingsRepository.fetchSettings() {
            selectedModel = settings.selectedModel
            siriPhrase = settings.siriPhrase
        }
    }
}
