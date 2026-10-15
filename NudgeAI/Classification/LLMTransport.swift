import Foundation

/// A provider adapter: builds the HTTP request and unwraps the response envelope.
/// Prompts and JSON-contract parsing are shared (see LLMContract.swift).
protocol LLMTransport {
    func makeRequest(_ request: LLMRequest, model: String, apiKey: String) throws -> URLRequest
    /// Returns the model's text from the provider envelope; throws `.unparseableResponse`.
    func extractText(from data: Data) throws -> String
}

enum LLMTransports {
    static func transport(for provider: AIProvider) -> LLMTransport? {
        switch provider {
        case .none: return nil
        case .anthropic: return AnthropicTransport()
        case .deepseek: return DeepSeekTransport()
        }
    }
}

struct AnthropicTransport: LLMTransport {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")
    static let apiVersion = "2023-06-01"

    private struct Envelope: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    /// Haiku 5.5 / Sonnet 5 accept thinking disabled; Sonnet 5.5 rejects it and
    /// needs "between_tools"; legacy Haiku 4.5 has no thinking by default.
    static func thinkingParameter(for model: String) -> [String: String]? {
        switch model {
        case "claude-haiku-5-5", "claude-sonnet-5": return ["type": "disabled"]
        case "claude-sonnet-5-5": return ["type": "between_tools"]
        default: return nil
        }
    }

    func makeRequest(_ request: LLMRequest, model: String, apiKey: String) throws -> URLRequest {
        guard let url = Self.endpoint else { throw ClassificationError.unparseableResponse }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "system": request.system,
            "messages": [["role": "user", "content": request.user]]
        ]
        if let thinking = Self.thinkingParameter(for: model) { body["thinking"] = thinking }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    func extractText(from data: Data) throws -> String {
        guard
            let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
            let text = envelope.content.first(where: { $0.type == "text" })?.text
        else { throw ClassificationError.unparseableResponse }
        return text
    }
}

struct DeepSeekTransport: LLMTransport {
    static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")

    private struct Envelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    func makeRequest(_ request: LLMRequest, model: String, apiKey: String) throws -> URLRequest {
        guard let url = Self.endpoint else { throw ClassificationError.unparseableResponse }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "messages": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.user]
            ],
            // Thinking defaults to enabled and would spend max_tokens on reasoning.
            "thinking": ["type": "disabled"],
            "stream": false
        ]
        if request.expectsJSONObject { body["response_format"] = ["type": "json_object"] }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    func extractText(from data: Data) throws -> String {
        guard
            let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
            let text = envelope.choices.first?.message.content,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty   // JSON mode can return empty content
        else { throw ClassificationError.unparseableResponse }
        return text
    }
}
