import SwiftUI
import SwiftData

/// Matches Figma node 8:248.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GroupedCard {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Theme.accentSoft)
                                .frame(width: 64, height: 64)
                                .overlay(Text("Y").font(.nudgeDisplay(28)).foregroundStyle(Theme.accent))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("You").font(.nudgeDisplay(32)).foregroundStyle(Theme.ink)
                                Text("Nudging since \(viewModel.nudgingSinceLabel)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }

                    HStack(spacing: 12) {
                        StatTile(value: "\(viewModel.capturedCount)", title: "Captured")
                        StatTile(value: "\(Int(viewModel.oneTapReviewRate * 100))%", title: "One-tap reviews")
                        StatTile(value: "—", title: "Avg capture")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLAUDE USAGE · THIS MONTH")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accentNight)
                        Text(viewModel.currentMonthSpend, format: .currency(code: "USD"))
                            .font(.nudgeDisplay(40))
                            .foregroundStyle(Theme.onNight)
                        Text("\(viewModel.currentMonthRequestCount) requests on Claude \(viewModel.selectedModel == .haiku ? "Haiku" : "Sonnet")")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.onNightMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.cardPadding)
                    .background(Theme.night)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

                    GroupedCard {
                        NavigationLink { SettingsView() } label: {
                            DisclosureRowContent(title: "Settings")
                        }
                        SettingsRowDivider()
                        NavigationLink { SettingsView() } label: {
                            DisclosureRowContent(title: "Siri phrase", value: "\u{201C}\(viewModel.siriPhrase)\u{201D}")
                        }
                        SettingsRowDivider()
                        NavigationLink { Text("Help coming soon").foregroundStyle(Theme.muted) } label: {
                            DisclosureRowContent(title: "Help and feedback")
                        }
                    }
                }
                .padding(Theme.Spacing.screenMargin)
            }
            .background(Theme.bg)
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.load(
                reminderRepository: SwiftDataReminderRepository(modelContext: modelContext),
                spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext),
                settingsRepository: SwiftDataSettingsRepository(modelContext: modelContext)
            )
        }
    }
}

private struct DisclosureRowContent: View {
    let title: String
    var value: String? = nil

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer()
            if let value {
                Text(value).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct StatTile: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.nudgeDisplay(30))
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))
    }
}
