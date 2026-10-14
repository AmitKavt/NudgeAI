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
    case requestFailed(Error)
    case unparseableResponse
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

private struct ClaudeResponseContract: Decodable {
    let bucket: String
    let urgency: String
    let deadline: String?
    let recurring_interval: String
    let confidence: Double
}

private struct ClaudeDigestEntryContract: Decodable {
    let id: String
    let bucket: String
    let urgency: String
    let deadline: String?
    let recurring_interval: String
    let confidence: Double
}

private struct ClaudeQuickReplyOptionContract: Decodable {
    let label: String
    let kind: QuickReplyKind
    let amount: Int?
}

private struct ClaudeFollowUpContract: Decodable {
    let question: String
    let options: [ClaudeQuickReplyOptionContract]
}

private struct AnthropicMessageEnvelope: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    let content: [ContentBlock]
}

final class AnthropicClassificationClient: ClassificationClient {
    private let apiKeyStore: APIKeyStore
    private let settingsRepository: SettingsRepository
    private let spendEstimateRepository: SpendEstimateRepository?
    private let session: URLSession
    private let dateFormatter: DateFormatter

    init(
        apiKeyStore: APIKeyStore,
        settingsRepository: SettingsRepository,
        spendEstimateRepository: SpendEstimateRepository? = nil,
        session: URLSession = .shared
    ) {
        self.apiKeyStore = apiKeyStore
        self.settingsRepository = settingsRepository
        self.spendEstimateRepository = spendEstimateRepository
        self.session = session
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.calendar = Calendar(identifier: .gregorian)
        self.dateFormatter.timeZone = TimeZone(identifier: "UTC")
    }

    func classify(rawText: String) async throws -> ClassificationResult {
        guard let apiKey = try apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw ClassificationError.missingAPIKey
        }

        let settings = try settingsRepository.fetchSettings()
        let request = try buildRequest(rawText: rawText, apiKey: apiKey, model: settings.selectedModel)

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw ClassificationError.requestFailed(error)
        }
        try? spendEstimateRepository?.recordRequest(model: settings.selectedModel)

        return try parse(data: data)
    }

    func classifyDigest(items: [DigestItem]) async throws -> [UUID: ClassificationResult] {
        guard !items.isEmpty else { return [:] }

        guard let apiKey = try apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw ClassificationError.missingAPIKey
        }

        let settings = try settingsRepository.fetchSettings()
        let request = try buildDigestRequest(items: items, apiKey: apiKey, model: settings.selectedModel)

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw ClassificationError.requestFailed(error)
        }
        try? spendEstimateRepository?.recordRequest(model: settings.selectedModel)

        return try parseDigest(data: data)
    }

    func generateFollowUp(rawText: String) async throws -> FollowUpQuestion {
        guard let apiKey = try apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw ClassificationError.missingAPIKey
        }

        let settings = try settingsRepository.fetchSettings()
        let request = try buildFollowUpRequest(rawText: rawText, apiKey: apiKey, model: settings.selectedModel)

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw ClassificationError.requestFailed(error)
        }
        try? spendEstimateRepository?.recordRequest(model: settings.selectedModel)

        return try parseFollowUp(data: data)
    }

    private func buildFollowUpRequest(rawText: String, apiKey: String, model: ClaudeModel) throws -> URLRequest {
        let modelId = model == .haiku ? "claude-haiku-4-5" : "claude-sonnet-5"
        let systemPrompt = """
        A user captured a personal reminder with no deadline specified. Ask one short clarifying \
        question about timing, and offer 2-4 quick-reply options. Respond with strict JSON only, matching exactly:
        {"question":"...","options":[{"label":"This week","kind":"relativeDays","amount":7}]}
        Valid "kind" values: "relativeDays" (amount = days from now), "relativeMonths" (amount = months \
        from now), "recurring" (amount = 6 or 12, meaning every N months), "noDeadline" (amount omitted).
        No prose, no markdown, no additional keys.
        """

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 256,
            "system": systemPrompt,
            "messages": [["role": "user", "content": rawText]]
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private func parseFollowUp(data: Data) throws -> FollowUpQuestion {
        guard
            let envelope = try? JSONDecoder().decode(AnthropicMessageEnvelope.self, from: data),
            let text = envelope.content.first(where: { $0.type == "text" })?.text,
            let contractData = text.data(using: .utf8),
            let contract = try? JSONDecoder().decode(ClaudeFollowUpContract.self, from: contractData)
        else {
            throw ClassificationError.unparseableResponse
        }

        let options = contract.options.map { entry -> QuickReplyOption in
            let recurringInterval: RecurringInterval? = entry.kind == .recurring
                ? (entry.amount == 12 ? .annual : .sixMonth)
                : nil
            return QuickReplyOption(
                label: entry.label,
                kind: entry.kind,
                amount: entry.amount,
                recurringInterval: recurringInterval
            )
        }

        return FollowUpQuestion(question: contract.question, options: options)
    }

    private func buildRequest(rawText: String, apiKey: String, model: ClaudeModel) throws -> URLRequest {
        let modelId = model == .haiku ? "claude-haiku-4-5" : "claude-sonnet-5"
        let systemPrompt = """
        You classify a personal reminder. Respond with strict JSON only, matching exactly:
        {"bucket":"quick_task|scheduled_task|long_horizon","urgency":"low|medium|high",\
        "deadline":"YYYY-MM-DD or null","recurring_interval":"none|monthly|six_month|annual|custom","confidence":0.0}
        No prose, no markdown, no additional keys.
        """

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 256,
            "system": systemPrompt,
            "messages": [["role": "user", "content": rawText]]
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private func buildDigestRequest(items: [DigestItem], apiKey: String, model: ClaudeModel) throws -> URLRequest {
        let modelId = model == .haiku ? "claude-haiku-4-5" : "claude-sonnet-5"
        let systemPrompt = """
        You classify a batch of personal reminders. Respond with a strict JSON array only, one entry per \
        input item in the same order, matching exactly:
        [{"id":"<the item's id, echoed back exactly>","bucket":"quick_task|scheduled_task|long_horizon",\
        "urgency":"low|medium|high","deadline":"YYYY-MM-DD or null",\
        "recurring_interval":"none|monthly|six_month|annual|custom","confidence":0.0}]
        No prose, no markdown, no additional keys.
        """

        let itemsPayload = items.map { ["id": $0.id.uuidString, "text": $0.rawText] }
        let userContent = try String(data: JSONSerialization.data(withJSONObject: itemsPayload), encoding: .utf8) ?? "[]"

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 256 * items.count,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userContent]]
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private func parseDigest(data: Data) throws -> [UUID: ClassificationResult] {
        guard
            let envelope = try? JSONDecoder().decode(AnthropicMessageEnvelope.self, from: data),
            let text = envelope.content.first(where: { $0.type == "text" })?.text,
            let contractData = text.data(using: .utf8),
            let entries = try? JSONDecoder().decode([ClaudeDigestEntryContract].self, from: contractData)
        else {
            throw ClassificationError.unparseableResponse
        }

        var results: [UUID: ClassificationResult] = [:]
        for entry in entries {
            guard
                let id = UUID(uuidString: entry.id),
                let bucket = Self.bucket(from: entry.bucket),
                let urgency = ReminderUrgency(rawValue: entry.urgency),
                let recurringInterval = Self.recurringInterval(from: entry.recurring_interval)
            else {
                continue
            }

            let deadline = entry.deadline.flatMap { dateFormatter.date(from: $0) }
            results[id] = ClassificationResult(
                bucket: bucket,
                urgency: urgency,
                deadline: deadline,
                recurringInterval: recurringInterval,
                confidence: entry.confidence
            )
        }
        return results
    }

    private func parse(data: Data) throws -> ClassificationResult {
        guard
            let envelope = try? JSONDecoder().decode(AnthropicMessageEnvelope.self, from: data),
            let text = envelope.content.first(where: { $0.type == "text" })?.text,
            let contractData = text.data(using: .utf8),
            let contract = try? JSONDecoder().decode(ClaudeResponseContract.self, from: contractData),
            let bucket = Self.bucket(from: contract.bucket),
            let urgency = ReminderUrgency(rawValue: contract.urgency),
            let recurringInterval = Self.recurringInterval(from: contract.recurring_interval)
        else {
            throw ClassificationError.unparseableResponse
        }

        let deadline = contract.deadline.flatMap { dateFormatter.date(from: $0) }

        return ClassificationResult(
            bucket: bucket,
            urgency: urgency,
            deadline: deadline,
            recurringInterval: recurringInterval,
            confidence: contract.confidence
        )
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
        case "custom": return .custom
        case "monthly": return .custom
        default: return nil
        }
    }
}
