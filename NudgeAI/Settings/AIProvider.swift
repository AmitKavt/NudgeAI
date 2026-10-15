import Foundation

/// The AI platform the user connected. `none` means the app runs fully
/// without a provider (items stay unsorted until sorted manually).
enum AIProvider: String, Codable, CaseIterable {
    case none
    case deepseek
    case anthropic
}

struct ProviderModel: Equatable {
    let id: String
    let displayName: String
}

/// Provider-scoped model lists and defaults. Pure Swift — no framework imports.
/// Ids verified 2026-10-15 against platform.claude.com/docs/en/models/overview and
/// api-docs.deepseek.com/quick_start/pricing.
enum ProviderModels {
    static let anthropicHaikuId = "claude-haiku-5-5"
    static let anthropicSonnetId = "claude-sonnet-5-5"
    static let deepseekFlashId = "deepseek-flash"
    static let deepseekProId = "deepseek-v4-pro"

    /// Older ids that existing installs may have stored. Still accepted by the
    /// API, so they are honored as-is but no longer offered in the picker.
    static let legacyAnthropicIds: [ProviderModel] = [
        ProviderModel(id: "claude-haiku-4-5", displayName: "Claude Haiku 4.5"),
        ProviderModel(id: "claude-sonnet-5", displayName: "Claude Sonnet 5")
    ]

    static func models(for provider: AIProvider) -> [ProviderModel] {
        switch provider {
        case .none:
            return []
        case .anthropic:
            return [
                ProviderModel(id: anthropicHaikuId, displayName: "Claude Haiku"),
                ProviderModel(id: anthropicSonnetId, displayName: "Claude Sonnet")
            ]
        case .deepseek:
            return [
                ProviderModel(id: deepseekFlashId, displayName: "DeepSeek Flash"),
                ProviderModel(id: deepseekProId, displayName: "DeepSeek Pro")
            ]
        }
    }

    /// Default model id for a provider; empty for `.none`.
    static func defaultModelId(for provider: AIProvider) -> String {
        models(for: provider).first?.id ?? ""
    }

    static func displayName(for modelId: String) -> String {
        for provider in AIProvider.allCases {
            if let model = models(for: provider).first(where: { $0.id == modelId }) {
                return model.displayName
            }
        }
        if let legacy = legacyAnthropicIds.first(where: { $0.id == modelId }) {
            return legacy.displayName
        }
        return modelId
    }

    /// Model id safe to send to `provider`: the stored id when it belongs to that
    /// provider (current or legacy), otherwise the provider's default.
    static func resolvedModelId(_ stored: String, for provider: AIProvider) -> String {
        if models(for: provider).contains(where: { $0.id == stored }) { return stored }
        if provider == .anthropic, legacyAnthropicIds.contains(where: { $0.id == stored }) { return stored }
        return defaultModelId(for: provider)
    }
}

extension AIProvider {
    /// Platform name shown in user-facing copy ("Can't reach DeepSeek"). Empty for `.none`.
    var displayName: String {
        switch self {
        case .none: return ""
        case .deepseek: return "DeepSeek"
        case .anthropic: return "Anthropic"
        }
    }

    /// Hint shown in the API key field.
    var keyPlaceholder: String {
        switch self {
        case .none: return ""
        case .deepseek: return "sk-..."
        case .anthropic: return "sk-ant-..."
        }
    }

    /// One-line description on the platform picker.
    var blurb: String {
        switch self {
        case .none: return "Sort everything yourself at review."
        case .deepseek: return "Low-cost models. Typically well under $1 a month."
        case .anthropic: return "Claude models. Haiku is fast and cheap."
        }
    }

    /// Platforms offered when connecting, in display order (excludes `.none`).
    static let selectable: [AIProvider] = [.deepseek, .anthropic]
}
