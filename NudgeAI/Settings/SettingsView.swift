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
    @State private var selectedModelId: String = ""
    @State private var provider: AIProvider = .none
    @State private var hasKey = false
    @ObservedObject private var unreachableState = ProviderUnreachableState.shared

    private var connectionStatus: ProviderConnectionStatus {
        .resolve(selected: provider, activeProvider: provider, hasKey: hasKey, isUnreachable: unreachableState.isUnreachable, isKeyRejected: unreachableState.isKeyRejected)
    }

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
                    SectionEyebrow(text: "AI PLATFORM AND DATA")
                    GroupedCard {
                        NavigationLink { aiPlatformView } label: {
                            HStack {
                                Text("Platform").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(provider == .none ? "None" : provider.displayName)
                                    .font(.system(size: 15)).foregroundStyle(Theme.muted)
                                StatusChip(label: connectionStatus.label, style: statusStyle)
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        if provider != .none {
                            SettingsRowDivider()
                            NavigationLink { aiPlatformView } label: {
                                DisclosureRowLabel(title: "Model", value: ProviderModels.displayName(for: selectedModelId))
                            }
                        }
                        SettingsRowDivider()
                        NavigationLink { aiPlatformView } label: {
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

    private var aiPlatformView: some View {
        AIPlatformView(apiKeyStore: KeychainAPIKeyStore(), settingsRepository: settingsRepository)
    }

    private var statusStyle: StatusChipStyle {
        switch connectionStatus {
        case .connected: return .success
        case .cantReach, .keyRejected: return .warn
        case .notConnected: return .neutral
        }
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
        selectedModelId = settings.modelId
        provider = settings.provider
        hasKey = KeychainAPIKeyStore().hasKey(for: settings.provider)
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
