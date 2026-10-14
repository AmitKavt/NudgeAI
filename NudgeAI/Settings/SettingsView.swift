import SwiftUI
import SwiftData

/// Matches Figma node 9:131.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmWithHaptic = true
    @State private var skipReviewWhenEmpty = true
    @State private var nightlyReviewTime = Date()
    @State private var leadTimeFirstDays = 15
    @State private var leadTimeSecondDays = 5
    @State private var quietHoursStart = Date()
    @State private var quietHoursEnd = Date()
    @State private var siriPhrase = ""
    @State private var selectedModel: ClaudeModel = .haiku

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Settings", onBack: { dismiss() })

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "CAPTURE")
                    GroupedCard {
                        NavigationLink {
                            CaptureSettingsView(settingsRepository: settingsRepository)
                        } label: {
                            DisclosureRowLabel(title: "Siri phrase", value: "\u{201C}\(siriPhrase)\u{201D}")
                        }
                        SettingsRowDivider()
                        ToggleRow(title: "Confirm with a haptic", isOn: $confirmWithHaptic)
                            .onChange(of: confirmWithHaptic) { _, newValue in
                                try? settingsRepository.update { $0.confirmWithHaptic = newValue }
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "REVIEW")
                    GroupedCard {
                        NavigationLink {
                            ReviewAndNudgeTimingView(settingsRepository: settingsRepository)
                        } label: {
                            DisclosureRowLabel(title: "Nightly review", value: nightlyReviewTime.formatted(date: .omitted, time: .shortened))
                        }
                        SettingsRowDivider()
                        ToggleRow(title: "Skip when nothing to sort", isOn: $skipReviewWhenEmpty)
                            .onChange(of: skipReviewWhenEmpty) { _, newValue in
                                try? settingsRepository.update { $0.skipReviewWhenEmpty = newValue }
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "NUDGES")
                    GroupedCard {
                        NavigationLink {
                            ReviewAndNudgeTimingView(settingsRepository: settingsRepository)
                        } label: {
                            DisclosureRowLabel(title: "Lead times", value: "\(leadTimeFirstDays) and \(leadTimeSecondDays) days")
                        }
                        SettingsRowDivider()
                        NavigationLink {
                            ReviewAndNudgeTimingView(settingsRepository: settingsRepository)
                        } label: {
                            DisclosureRowLabel(
                                title: "Quiet hours",
                                value: "\(quietHoursStart.formatted(date: .omitted, time: .shortened)) to \(quietHoursEnd.formatted(date: .omitted, time: .shortened))"
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "CLAUDE AND DATA")
                    GroupedCard {
                        HStack {
                            Text("API key").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            StatusChip(label: "Connected", style: .success)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        SettingsRowDivider()
                        NavigationLink {
                            ClaudeAndPrivacyView(
                                apiKeyStore: KeychainAPIKeyStore(),
                                settingsRepository: settingsRepository,
                                spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
                            )
                        } label: {
                            DisclosureRowLabel(title: "Model", value: selectedModel == .haiku ? "Claude Haiku" : "Claude Sonnet")
                        }
                        SettingsRowDivider()
                        NavigationLink {
                            ClaudeAndPrivacyView(
                                apiKeyStore: KeychainAPIKeyStore(),
                                settingsRepository: settingsRepository,
                                spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
                            )
                        } label: {
                            DisclosureRowLabel(title: "Data and privacy")
                        }
                    }
                }
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.bg)
        .navigationBarHidden(true)
        .onAppear(perform: load)
    }

    private var settingsRepository: SettingsRepository {
        SwiftDataSettingsRepository(modelContext: modelContext)
    }

    private func load() {
        guard let settings = try? settingsRepository.fetchSettings() else { return }
        confirmWithHaptic = settings.confirmWithHaptic
        skipReviewWhenEmpty = settings.skipReviewWhenEmpty
        nightlyReviewTime = settings.nightlyReviewTime
        leadTimeFirstDays = settings.leadTimeFirstDays
        leadTimeSecondDays = settings.leadTimeSecondDays
        quietHoursStart = settings.quietHoursStart
        quietHoursEnd = settings.quietHoursEnd
        siriPhrase = settings.siriPhrase
        selectedModel = settings.selectedModel
    }
}

private struct DisclosureRowLabel: View {
    let title: String
    var value: String? = nil

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer()
            if let value {
                Text(value).font(.system(size: 15)).foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
