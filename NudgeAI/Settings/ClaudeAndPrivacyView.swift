import SwiftUI

/// Matches Figma node 9:281.
struct ClaudeAndPrivacyView: View {
    let apiKeyStore: APIKeyStore
    let settingsRepository: SettingsRepository
    let spendEstimateRepository: SpendEstimateRepository
    @Environment(\.dismiss) private var dismiss

    @State private var selectedModel: ClaudeModel = .haiku
    @State private var monthlySpendAlertThreshold: Double = 5.0
    @State private var newAPIKey: String = ""
    @State private var keyReplaceError: String?
    @State private var isReplacingKey = false
    @ObservedObject private var unreachableState = ClaudeUnreachableState.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Claude", onBack: { dismiss() })

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.success)
                        Text("Key stored in the iPhone Keychain.").font(.system(size: 14)).foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Button("Replace") { isReplacingKey = true }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(16)
                .background(Theme.successSoft)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))

                if isReplacingKey {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("New Anthropic API key", text: $newAPIKey)
                            .padding(16)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))
                        if let keyReplaceError {
                            Text(keyReplaceError).font(.system(size: 13)).foregroundStyle(Theme.warn)
                        }
                        PlainButton(label: "Save new key", action: replaceKey)
                    }
                }

                SectionEyebrow(text: "MODEL")
                VStack(spacing: 12) {
                    RadioOptionCard(
                        title: "Claude Haiku",
                        subtitle: "Fast and cheap. Great at sorting what you capture.",
                        badge: "Recommended",
                        isSelected: selectedModel == .haiku
                    ) { setModel(.haiku) }

                    RadioOptionCard(
                        title: "Claude Sonnet",
                        subtitle: "Better follow-up questions in the app. Costs more.",
                        isSelected: selectedModel == .sonnet
                    ) { setModel(.sonnet) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Monthly spend alert").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("$\(Int(monthlySpendAlertThreshold))").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.accent)
                    }
                    Slider(value: $monthlySpendAlertThreshold, in: 1...50, step: 1)
                        .tint(Theme.accent)
                        .onChange(of: monthlySpendAlertThreshold) { _, newValue in
                            try? settingsRepository.update { $0.monthlySpendAlertThreshold = newValue }
                        }
                    Text("You'll get a warning, never a surprise bill.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What leaves your phone").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                        Text("Only the text of a nudge, sent straight to Claude. No Nudge server, no account.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(16)
                .background(Theme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.bg)
        .navigationBarHidden(true)
        .onAppear(perform: load)
    }

    private func load() {
        guard let settings = try? settingsRepository.fetchSettings() else { return }
        selectedModel = settings.selectedModel
        monthlySpendAlertThreshold = settings.monthlySpendAlertThreshold
    }

    private func setModel(_ model: ClaudeModel) {
        selectedModel = model
        try? settingsRepository.update { $0.selectedModel = model }
    }

    private func replaceKey() {
        let trimmed = newAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try apiKeyStore.saveAPIKey(trimmed)
            newAPIKey = ""
            keyReplaceError = nil
            isReplacingKey = false
        } catch {
            keyReplaceError = "Couldn't save the key. Try again."
        }
    }
}
