import SwiftUI

/// "AI platform and data". No Figma design exists; built from the shared Settings vocabulary.
struct AIPlatformView: View {
    let apiKeyStore: APIKeyStore
    let settingsRepository: SettingsRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var connect: PlatformConnectModel
    @ObservedObject private var unreachableState = ProviderUnreachableState.shared
    @State private var activeProvider: AIProvider = .none
    @State private var modelId: String = ""
    @State private var storedKeys: Set<AIProvider> = []
    @State private var monthlySpendAlertThreshold: Double = 5.0
    @State private var isReplacingKey = false
    @State private var confirmDisconnect = false

    init(apiKeyStore: APIKeyStore, settingsRepository: SettingsRepository) {
        self.apiKeyStore = apiKeyStore
        self.settingsRepository = settingsRepository
        _connect = StateObject(wrappedValue: PlatformConnectModel(
            service: ProviderConnectionService(apiKeyStore: apiKeyStore, settingsRepository: settingsRepository),
            initialProvider: .none
        ))
    }

    private var viewing: AIProvider { connect.provider }
    private var hasKey: Bool { storedKeys.contains(viewing) }
    private var status: ProviderConnectionStatus {
        .resolve(selected: viewing, activeProvider: activeProvider, hasKey: hasKey,
                 isUnreachable: unreachableState.isUnreachable, isKeyRejected: unreachableState.isKeyRejected)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "AI platform", onBack: { dismiss() })

                SectionEyebrow(text: "PLATFORM")
                VStack(spacing: 12) {
                    ForEach(AIProvider.allCases, id: \.self) { option in
                        RadioOptionCard(
                            title: option == .none ? "None" : option.displayName,
                            subtitle: PlatformConnectModel.platformBlurb(for: option),
                            isSelected: viewing == option
                        ) { choose(option) }
                    }
                }

                if viewing != .none {
                    statusCard
                    if !hasKey || isReplacingKey { keyEntry }
                }

                if viewing != .none, viewing == activeProvider {
                    SectionEyebrow(text: "MODEL")
                    VStack(spacing: 12) {
                        ForEach(Array(ProviderModels.models(for: viewing).enumerated()), id: \.element.id) { index, model in
                            RadioOptionCard(
                                title: model.displayName,
                                subtitle: Self.costCopy(for: model.id),
                                badge: index == 0 ? "Recommended" : nil,
                                isSelected: modelId == model.id
                            ) { setModel(model.id) }
                        }
                    }
                }

                if activeProvider != .none { spendAlert }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data and privacy").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                        Text("Only the text of a nudge, sent straight to the platform you chose. No Nudge server. Sign in with Apple stays on this device.")
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

    private var statusCard: some View {
        let tint: Color = status == .connected ? Theme.success : (status == .cantReach || status == .keyRejected ? Theme.warn : Theme.muted)
        let soft: Color = status == .connected ? Theme.successSoft : (status == .cantReach || status == .keyRejected ? Theme.warnSoft : Theme.surfaceAlt)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: status == .connected ? "lock.fill" : "exclamationmark.circle").foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.label).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                    Text(status == .keyRejected ? "\(viewing.displayName) rejected your key. Replace it to keep sorting." : hasKey ? "Key stored in the iPhone Keychain." : "Add your \(viewing.displayName) API key to connect.")
                        .font(.system(size: 14)).foregroundStyle(Theme.ink)
                }
                Spacer()
                if hasKey {
                    Button(isReplacingKey ? "Cancel" : "Replace") {
                        isReplacingKey.toggle()
                        connect.keyInput = ""
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
            if hasKey {
                if confirmDisconnect {
                    Text("This deletes the \(viewing.displayName) key from this iPhone.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    HStack(spacing: 12) {
                        PlainButton(label: "Keep key") { confirmDisconnect = false }
                        PlainButton(label: "Disconnect", isDestructive: true) { disconnect() }
                    }
                } else {
                    PlainButton(label: "Disconnect", isDestructive: true) { confirmDisconnect = true }
                }
            }
        }
        .padding(16)
        .background(soft)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
    }

    private var keyEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("\(viewing.displayName) API key (\(PlatformConnectModel.keyPlaceholder(for: viewing)))", text: $connect.keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Paste") {
                    if let pasted = UIPasteboard.general.string { connect.keyInput = pasted }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))
            if let message = connect.errorMessage {
                Text(message).font(.system(size: 13)).foregroundStyle(Theme.warn)
            }
            PlainButton(label: connect.isConnecting ? "Checking key..." : (hasKey ? "Check and replace key" : "Connect")) {
                Task {
                    if await connect.connect() { isReplacingKey = false; load() }
                }
            }
            .disabled(connect.isConnecting)
        }
    }

    private var spendAlert: some View {
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
    }

    static func costCopy(for modelId: String) -> String {
        switch modelId {
        case ProviderModels.anthropicHaikuId: return "Fast and cheap. Great at sorting what you capture."
        case ProviderModels.anthropicSonnetId: return "Better follow-up questions in the app. Costs more."
        case ProviderModels.deepseekFlashId: return "Cheapest option. Great at sorting what you capture."
        case ProviderModels.deepseekProId: return "Stronger answers. Costs more."
        default: return ""
        }
    }

    private func load() {
        guard let settings = try? settingsRepository.fetchSettings() else { return }
        activeProvider = settings.provider
        modelId = ProviderModels.resolvedModelId(settings.modelId, for: settings.provider)
        monthlySpendAlertThreshold = settings.monthlySpendAlertThreshold
        storedKeys = Set(AIProvider.allCases.filter { apiKeyStore.hasKey(for: $0) })
        if connect.provider == .none && activeProvider != .none { connect.select(activeProvider) }
    }

    /// A platform with a stored key activates at once (model resets to its default);
    /// one without only opens key entry. No key is deleted by switching.
    private func choose(_ option: AIProvider) {
        isReplacingKey = false
        confirmDisconnect = false
        connect.select(option)
        if option == .none || storedKeys.contains(option) {
            guard option != activeProvider else { return }
            try? settingsRepository.update { $0.changeProvider(to: option) }
            Task { @MainActor in ProviderUnreachableState.shared.markReachable() }
            load()
        }
    }

    private func setModel(_ id: String) {
        modelId = id
        try? settingsRepository.update { $0.modelId = id }
    }

    private func disconnect() {
        confirmDisconnect = false
        connect.disconnect(viewing)
        load()
    }
}
