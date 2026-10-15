import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var unreachableState = ProviderUnreachableState.shared
    @State private var reviewPendingCount = 0
    @State private var todayItems: [ReminderItem] = []
    @State private var provider: AIProvider = .none
    @State private var noteDismissed = UserDefaults.standard.bool(forKey: TodayView.noteDismissedKey)

    static let noteDismissedKey = "noProviderNoteDismissed"

    let onStartReview: () -> Void
    var onConnectProvider: () -> Void = {}

    private var showUnreachable: Bool {
        UnreachablePresentation.shouldShow(isUnreachable: unreachableState.isUnreachable, provider: provider)
    }
    private var isEmpty: Bool { todayItems.isEmpty && reviewPendingCount == 0 && !showUnreachable }

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if showUnreachable {
                    OfflineBanner(providerName: provider.displayName, onRetry: retryClassification)
                }
                if provider == .none && !noteDismissed {
                    NoProviderNote(
                        onConnect: onConnectProvider,
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: Self.noteDismissedKey)
                            noteDismissed = true
                        }
                    )
                }

                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.muted)
                        Text("Today")
                            .font(.nudgeDisplay(48))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("A")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        )
                }

                if showUnreachable {
                    PausedReviewCard(providerName: provider.displayName)
                } else if reviewPendingCount > 0 {
                    ReviewSummaryCard(count: reviewPendingCount, onStartReview: onStartReview)
                }

                if !todayItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CAPTURED TODAY")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.muted)

                        VStack(spacing: 0) {
                            ForEach(Array(todayItems.enumerated()), id: \.element.id) { index, item in
                                TodayRow(item: item, isUnreachable: showUnreachable)
                                if index < todayItems.count - 1 {
                                    Divider().background(Theme.line)
                                }
                            }
                        }
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))
                    }
                }

                if isEmpty {
                    Spacer(minLength: 0)
                    EmptyStateView(
                        systemImage: "mic",
                        title: "Nothing captured yet",
                        subtitle: "Tap the mic below or say your Siri phrase to log your first nudge."
                    )
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.top, 6)
            .frame(minHeight: geometry.size.height, alignment: .top)
        }
        }
        .background(Theme.bg)
        .onAppear(perform: load)
    }

    private func load() {
        let repository = SwiftDataReminderRepository(modelContext: modelContext)
        let settingsRepository = SwiftDataSettingsRepository(modelContext: modelContext)
        provider = (try? settingsRepository.fetchSettings().provider) ?? AIProvider.none
        ProviderBackfill.runIfNeeded(modelContext: modelContext)
        Task {
            await NightlyReviewScheduling.refresh(
                reminderRepository: repository,
                settingsRepository: settingsRepository,
                notificationScheduler: UNNotificationScheduler()
            )
        }
        reviewPendingCount = (try? repository.fetchNightlyReviewItems(
            confidenceThreshold: classificationConfidenceThreshold
        ).count) ?? 0

        let calendar = Calendar.current
        todayItems = ((try? repository.fetchAll()) ?? []).filter {
            calendar.isDateInToday($0.createdAt)
        }
    }

    /// Retries by re-running the digest for anything still unclassified —
    /// clears `ProviderUnreachableState` automatically on success.
    private func retryClassification() {
        let reminderRepository = SwiftDataReminderRepository(modelContext: modelContext)
        let settingsRepository = SwiftDataSettingsRepository(modelContext: modelContext)
        guard let client = ClassificationClientFactory.makeClient(
            settingsRepository: settingsRepository,
            apiKeyStore: KeychainAPIKeyStore(),
            spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
        ) else { return }
        let coordinator = ClassificationCoordinator(
            client: client,
            reminderRepository: reminderRepository,
            settingsRepository: settingsRepository,
            unreachableState: .shared
        )
        Task {
            await coordinator.runNightlyDigest()
            load()
        }
    }
}

private struct NoProviderNote: View {
    let onConnect: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("No AI platform connected. You'll sort nudges yourself at review.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                Button("Connect one", action: onConnect)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(16)
        .background(Theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
    }
}

private struct PausedReviewCard: View {
    let providerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TONIGHT'S REVIEW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Text("Paused until \(providerName) is reachable")
                .font(.nudgeDisplay(28))
                .foregroundStyle(Theme.ink)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

private struct ReviewSummaryCard: View {
    let count: Int
    let onStartReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TONIGHT'S REVIEW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.accentNight)
            Text("\(count) to sort")
                .font(.nudgeDisplay(38))
                .foregroundStyle(Theme.onNight)
            Text("About 30 seconds. One tap each.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.onNightMuted)

            Button(action: onStartReview) {
                Text("Start review")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .padding(.top, 12)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.night)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

private struct TodayRow: View {
    let item: ReminderItem
    let isUnreachable: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.rawText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(sourceLabel) · \(item.createdAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if isUnreachable && item.bucket == nil {
                StatusChip(label: "Waiting", style: .neutral)
            } else {
                StatusChip(label: chipLabel, isWarn: item.reviewedAt == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var sourceLabel: String {
        item.source == .siri ? "Siri" : "In-app"
    }

    private var chipLabel: String {
        guard item.reviewedAt != nil, let bucket = item.bucket else { return "To sort" }
        switch bucket {
        case .quickTask: return "Quick task"
        case .scheduledTask: return "Scheduled"
        case .longHorizon: return "Long-horizon"
        }
    }
}

enum StatusChipStyle {
    case warn
    case success
    case neutral
}

struct StatusChip: View {
    let label: String
    var style: StatusChipStyle = .neutral

    init(label: String, style: StatusChipStyle) {
        self.label = label
        self.style = style
    }

    init(label: String, isWarn: Bool) {
        self.label = label
        self.style = isWarn ? .warn : .success
    }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch style {
        case .warn: return Theme.warnSoft
        case .success: return Theme.successSoft
        case .neutral: return Theme.surfaceAlt
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .warn: return Theme.warn
        case .success: return Theme.success
        case .neutral: return Theme.muted
        }
    }
}
