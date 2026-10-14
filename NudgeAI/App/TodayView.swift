import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var unreachableState = ClaudeUnreachableState.shared
    @State private var reviewPendingCount = 0
    @State private var todayItems: [ReminderItem] = []

    let onStartReview: () -> Void

    private var isEmpty: Bool { todayItems.isEmpty && reviewPendingCount == 0 && !unreachableState.isUnreachable }

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if unreachableState.isUnreachable {
                    OfflineBanner(onRetry: retryClassification)
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

                if unreachableState.isUnreachable {
                    PausedReviewCard()
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
                                TodayRow(item: item, isUnreachable: unreachableState.isUnreachable)
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
        reviewPendingCount = (try? repository.fetchNightlyReviewItems(
            confidenceThreshold: classificationConfidenceThreshold
        ).count) ?? 0

        let calendar = Calendar.current
        todayItems = ((try? repository.fetchAll()) ?? []).filter {
            calendar.isDateInToday($0.createdAt)
        }
    }

    /// Retries by re-running the digest for anything still unclassified —
    /// clears `ClaudeUnreachableState` automatically on success.
    private func retryClassification() {
        let reminderRepository = SwiftDataReminderRepository(modelContext: modelContext)
        let settingsRepository = SwiftDataSettingsRepository(modelContext: modelContext)
        let coordinator = ClassificationCoordinator(
            client: AnthropicClassificationClient(
                apiKeyStore: KeychainAPIKeyStore(),
                settingsRepository: settingsRepository,
                spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
            ),
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

private struct PausedReviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TONIGHT'S REVIEW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Text("Paused until Claude is reachable")
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
