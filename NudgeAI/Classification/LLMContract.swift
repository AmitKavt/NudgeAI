import Foundation

/// Shared, provider-neutral prompts. Pure Swift (Foundation only).
/// Every prompt contains the word "JSON" (DeepSeek JSON mode requires it).
enum LLMPrompts {
    static let classifySystem = """
    You classify a personal reminder. Respond with strict JSON only, matching exactly:
    {"bucket":"quick_task|scheduled_task|long_horizon","urgency":"low|medium|high",\
    "deadline":"YYYY-MM-DD or null","recurring_interval":"none|monthly|six_month|annual|custom","confidence":0.0}
    No prose, no markdown, no additional keys.
    """

    static let digestSystem = """
    You classify a batch of personal reminders. Respond with a strict JSON array only, one entry per \
    input item in the same order, matching exactly:
    [{"id":"<the item's id, echoed back exactly>","bucket":"quick_task|scheduled_task|long_horizon",\
    "urgency":"low|medium|high","deadline":"YYYY-MM-DD or null",\
    "recurring_interval":"none|monthly|six_month|annual|custom","confidence":0.0}]
    No prose, no markdown, no additional keys.
    """

    static let followUpSystem = """
    A user captured a personal reminder with no deadline specified. Ask one short clarifying \
    question about timing, and offer 2-4 quick-reply options. Respond with strict JSON only, matching exactly:
    {"question":"...","options":[{"label":"This week","kind":"relativeDays","amount":7}]}
    Valid "kind" values: "relativeDays" (amount = days from now), "relativeMonths" (amount = months \
    from now), "recurring" (amount = 6 or 12, meaning every N months), "noDeadline" (amount omitted).
    No prose, no markdown, no additional keys.
    """

    static let classifyMaxTokens = 256
    static let followUpMaxTokens = 256
    static func digestMaxTokens(itemCount: Int) -> Int { 256 * max(itemCount, 1) }

    static func digestUserContent(items: [DigestItem]) -> String {
        let payload = items.map { ["id": $0.id.uuidString, "text": $0.rawText] }
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }
}

/// What an adapter needs to send; the adapter owns URL, auth and envelope.
struct LLMRequest {
    let system: String
    let user: String
    let maxTokens: Int
    /// True when the model must return a single JSON object (DeepSeek JSON mode
    /// rejects top-level arrays, so the digest sets this to false).
    let expectsJSONObject: Bool
}

enum LLMRequests {
    static func classify(rawText: String) -> LLMRequest {
        LLMRequest(system: LLMPrompts.classifySystem, user: rawText,
                   maxTokens: LLMPrompts.classifyMaxTokens, expectsJSONObject: true)
    }

    static func digest(items: [DigestItem]) -> LLMRequest {
        LLMRequest(system: LLMPrompts.digestSystem, user: LLMPrompts.digestUserContent(items: items),
                   maxTokens: LLMPrompts.digestMaxTokens(itemCount: items.count), expectsJSONObject: false)
    }

    static func followUp(rawText: String) -> LLMRequest {
        LLMRequest(system: LLMPrompts.followUpSystem, user: rawText,
                   maxTokens: LLMPrompts.followUpMaxTokens, expectsJSONObject: true)
    }
}

/// Shared JSON-contract parsing of the model's text output. Pure Swift.
/// Anything malformed throws `ClassificationError.unparseableResponse`; never crashes.
enum LLMResponseParser {
    private struct Contract: Decodable {
        let bucket: String
        let urgency: String
        let deadline: String?
        let recurring_interval: String
        let confidence: Double
    }

    private struct DigestEntry: Decodable {
        let id: String
        let bucket: String
        let urgency: String
        let deadline: String?
        let recurring_interval: String
        let confidence: Double
    }

    private struct QuickReply: Decodable {
        let label: String
        let kind: QuickReplyKind
        let amount: Int?
    }

    private struct FollowUp: Decodable {
        let question: String
        let options: [QuickReply]
    }

    /// Removes ``` / ```json fences and surrounding prose, keeping the outermost JSON value.
    static func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let newline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: newline)...])
            } else {
                trimmed = String(trimmed.dropFirst(3))
            }
            if let close = trimmed.range(of: "```", options: .backwards) {
                trimmed = String(trimmed[..<close.lowerBound])
            }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let openers: [(Character, Character)] = [("{", "}"), ("[", "]")]
        if let first = trimmed.first, !openers.contains(where: { $0.0 == first }) {
            // Leading prose: take from the earliest opener to its matching last closer.
            let candidates = openers.compactMap { pair -> Range<String.Index>? in
                guard let start = trimmed.firstIndex(of: pair.0),
                      let end = trimmed.lastIndex(of: pair.1), start < end else { return nil }
                return start..<trimmed.index(after: end)
            }
            if let best = candidates.min(by: { $0.lowerBound < $1.lowerBound }) {
                return String(trimmed[best])
            }
        }
        return trimmed
    }

    static func parseClassification(text: String) throws -> ClassificationResult {
        guard
            let data = stripCodeFences(text).data(using: .utf8),
            let contract = try? JSONDecoder().decode(Contract.self, from: data),
            let result = makeResult(contract.bucket, contract.urgency, contract.deadline,
                                    contract.recurring_interval, contract.confidence)
        else { throw ClassificationError.unparseableResponse }
        return result
    }

    static func parseDigest(text: String) throws -> [UUID: ClassificationResult] {
        guard
            let data = stripCodeFences(text).data(using: .utf8),
            let entries = decodeDigestEntries(data)
        else { throw ClassificationError.unparseableResponse }

        var results: [UUID: ClassificationResult] = [:]
        for entry in entries {
            guard
                let id = UUID(uuidString: entry.id),
                let result = makeResult(entry.bucket, entry.urgency, entry.deadline,
                                        entry.recurring_interval, entry.confidence)
            else { continue }
            results[id] = result
        }
        return results
    }

    /// Accepts a bare array, or an object wrapping one (some JSON modes force objects).
    private static func decodeDigestEntries(_ data: Data) -> [DigestEntry]? {
        if let entries = try? JSONDecoder().decode([DigestEntry].self, from: data) { return entries }
        struct Wrapper: Decodable { let items: [DigestEntry]? ; let results: [DigestEntry]? }
        if let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) {
            return wrapper.items ?? wrapper.results
        }
        return nil
    }

    static func parseFollowUp(text: String) throws -> FollowUpQuestion {
        guard
            let data = stripCodeFences(text).data(using: .utf8),
            let contract = try? JSONDecoder().decode(FollowUp.self, from: data)
        else { throw ClassificationError.unparseableResponse }

        let options = contract.options.map { entry -> QuickReplyOption in
            let interval: RecurringInterval? = entry.kind == .recurring
                ? (entry.amount == 12 ? .annual : .sixMonth)
                : nil
            return QuickReplyOption(label: entry.label, kind: entry.kind,
                                    amount: entry.amount, recurringInterval: interval)
        }
        return FollowUpQuestion(question: contract.question, options: options)
    }

    private static func makeResult(
        _ bucket: String, _ urgency: String, _ deadline: String?, _ interval: String, _ confidence: Double
    ) -> ClassificationResult? {
        guard
            let bucket = Self.bucket(from: bucket),
            let urgency = ReminderUrgency(rawValue: urgency),
            let interval = recurringInterval(from: interval)
        else { return nil }
        return ClassificationResult(
            bucket: bucket, urgency: urgency, deadline: deadline.flatMap(parseDate),
            recurringInterval: interval, confidence: confidence
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: value)
    }

    private static func bucket(from value: String) -> ReminderBucket? {
        switch value {
        case "quick_task": return .quickTask
        case "scheduled_task": return .scheduledTask
        case "long_horizon": return .longHorizon
        default: return nil
        }
    }

    private static func recurringInterval(from value: String) -> RecurringInterval? {
        switch value {
        case "none": return RecurringInterval.none
        case "six_month": return .sixMonth
        case "annual": return .annual
        case "custom", "monthly": return .custom
        default: return nil
        }
    }
}

extension LLMRequests {
    /// Smallest valid request, used only to verify a key on connect.
    static let keyCheck = LLMRequest(
        system: "Reply with the JSON object {\"ok\":true} and nothing else.",
        user: "ping", maxTokens: 16, expectsJSONObject: true
    )
}
