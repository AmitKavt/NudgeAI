import Foundation

struct ClassificationResult {
    let bucket: ReminderBucket
    let urgency: ReminderUrgency
    let deadline: Date?
    let recurringInterval: RecurringInterval
    let confidence: Double
}

enum ClassificationError: Error {
    case missingAPIKey
    /// Network failure, timeout, 429 or 5xx: the only case that marks the provider unreachable.
    case requestFailed(Error)
    case unparseableResponse
    /// HTTP 401/403: the provider rejected the key. Not "unreachable", never counted as spend.
    case authRejected
}

struct DigestItem {
    let id: UUID
    let rawText: String
}

enum QuickReplyKind: String, Decodable {
    case relativeDays
    case relativeMonths
    case recurring
    case noDeadline
}

struct QuickReplyOption {
    let label: String
    let kind: QuickReplyKind
    /// Meaning depends on `kind`: day/month count for relative kinds, unused for `.recurring`/`.noDeadline`.
    let amount: Int?
    let recurringInterval: RecurringInterval?
}

struct FollowUpQuestion {
    let question: String
    let options: [QuickReplyOption]
}

protocol ClassificationClient {
    func classify(rawText: String) async throws -> ClassificationResult
    func classifyDigest(items: [DigestItem]) async throws -> [UUID: ClassificationResult]
    func generateFollowUp(rawText: String) async throws -> FollowUpQuestion
}
