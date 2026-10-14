import Foundation
import SwiftData

/// Rough per-request cost estimates — not real Anthropic billing figures.
/// Placeholder until actual per-model pricing is confirmed; revisit before
/// the Phase 6 spend-estimate-accuracy pass.
enum ModelPricing {
    static func costPerRequest(for model: ClaudeModel) -> Double {
        switch model {
        case .haiku: return 0.001
        case .sonnet: return 0.01
        }
    }
}

@Model
final class SpendEstimate {
    @Attribute(.unique) var monthKey: String
    var requestCount: Int
    var estimatedCost: Double

    init(monthKey: String, requestCount: Int = 0, estimatedCost: Double = 0) {
        self.monthKey = monthKey
        self.requestCount = requestCount
        self.estimatedCost = estimatedCost
    }
}

protocol SpendEstimateRepository {
    func recordRequest(model: ClaudeModel) throws
    func currentMonthEstimate() throws -> SpendEstimate
}

final class SwiftDataSpendEstimateRepository: SpendEstimateRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func recordRequest(model: ClaudeModel) throws {
        let key = Self.currentMonthKey()
        let record = try fetchOrCreate(monthKey: key)
        record.requestCount += 1
        record.estimatedCost += ModelPricing.costPerRequest(for: model)
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
