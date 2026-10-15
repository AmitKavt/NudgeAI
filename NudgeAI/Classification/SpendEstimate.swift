import Foundation
import SwiftData

struct TokenRates: Equatable {
    let inputPerMTok: Double
    let outputPerMTok: Double
}

/// Per platform/model pricing in USD per million tokens. Unknown model => nil,
/// and the estimate then counts requests only.
/// Sources (2026-10-15): platform.claude.com/docs/en/models/overview (Anthropic,
/// Haiku 5.5 is "from" pricing) and api-docs.deepseek.com/quick_start/pricing
/// (DeepSeek peak-hour cache-miss rates, the conservative side).
/// PLACEHOLDER: Anthropic figures are list prices combined with assumed token
/// counts below, not validated against billing (see TASKS.md).
enum ModelPricing {
    static let assumedInputTokensPerRequest = 400.0
    static let assumedOutputTokensPerRequest = 100.0

    static func rates(provider: AIProvider, modelId: String) -> TokenRates? {
        switch (provider, modelId) {
        case (.anthropic, ProviderModels.anthropicHaikuId): return TokenRates(inputPerMTok: 0.10, outputPerMTok: 0.50)
        case (.anthropic, ProviderModels.anthropicSonnetId): return TokenRates(inputPerMTok: 2, outputPerMTok: 10)
        case (.deepseek, ProviderModels.deepseekFlashId): return TokenRates(inputPerMTok: 0.30, outputPerMTok: 1.20)
        case (.deepseek, ProviderModels.deepseekProId): return TokenRates(inputPerMTok: 1.32, outputPerMTok: 3.96)
        default: return nil
        }
    }

    /// nil when pricing is unknown (show request count only).
    static func costPerRequest(provider: AIProvider, modelId: String) -> Double? {
        guard let rates = rates(provider: provider, modelId: modelId) else { return nil }
        return (assumedInputTokensPerRequest * rates.inputPerMTok + assumedOutputTokensPerRequest * rates.outputPerMTok) / 1_000_000
    }
}

@Model
final class SpendEstimate {
    @Attribute(.unique) var monthKey: String
    var requestCount: Int
    var estimatedCost: Double
    /// Requests with no known pricing; when > 0 the cost figure is incomplete.
    var unpricedRequestCount: Int = 0

    init(monthKey: String, requestCount: Int = 0, estimatedCost: Double = 0) {
        self.monthKey = monthKey
        self.requestCount = requestCount
        self.estimatedCost = estimatedCost
    }
}

protocol SpendEstimateRepository {
    func recordRequest(provider: AIProvider, model: String) throws
    func currentMonthEstimate() throws -> SpendEstimate
}

final class SwiftDataSpendEstimateRepository: SpendEstimateRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func recordRequest(provider: AIProvider, model: String) throws {
        let key = Self.currentMonthKey()
        let record = try fetchOrCreate(monthKey: key)
        record.requestCount += 1
        if let cost = ModelPricing.costPerRequest(provider: provider, modelId: model) {
            record.estimatedCost += cost
        } else {
            record.unpricedRequestCount += 1
        }
        try modelContext.save()
    }

    func currentMonthEstimate() throws -> SpendEstimate {
        try fetchOrCreate(monthKey: Self.currentMonthKey())
    }

    private func fetchOrCreate(monthKey: String) throws -> SpendEstimate {
        var descriptor = FetchDescriptor<SpendEstimate>(predicate: #Predicate { $0.monthKey == monthKey })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let record = SpendEstimate(monthKey: monthKey)
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    private static func currentMonthKey(calendar: Calendar = .current, now: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month], from: now)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
}
