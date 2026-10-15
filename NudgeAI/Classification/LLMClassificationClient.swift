import Foundation

/// Default session for provider calls: ephemeral, so nothing (cache, cookies,
/// credentials) from requests carrying API keys is written to disk.
enum LLMSession {
    static func makeConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        return config
    }

    static let ephemeral = URLSession(configuration: makeConfiguration())
}

/// Shared request/response flow for every platform. Adapters (`LLMTransport`)
/// only build the HTTP request and unwrap the envelope.
class LLMClassificationClient: ClassificationClient {
    private let transport: LLMTransport
    private let provider: AIProvider
    private let apiKeyStore: APIKeyStore
    private let settingsRepository: SettingsRepository
    private let spendEstimateRepository: SpendEstimateRepository?
    private let session: URLSession
    /// Per-request timeout; nil keeps the URLRequest default (60s).
    private let requestTimeout: TimeInterval?

    init(
        transport: LLMTransport,
        provider: AIProvider,
        apiKeyStore: APIKeyStore,
        settingsRepository: SettingsRepository,
        spendEstimateRepository: SpendEstimateRepository?,
        session: URLSession,
        requestTimeout: TimeInterval? = nil
    ) {
        self.requestTimeout = requestTimeout
        self.transport = transport
        self.provider = provider
        self.apiKeyStore = apiKeyStore
        self.settingsRepository = settingsRepository
        self.spendEstimateRepository = spendEstimateRepository
        self.session = session
    }

    func classify(rawText: String) async throws -> ClassificationResult {
        try LLMResponseParser.parseClassification(text: try await send(LLMRequests.classify(rawText: rawText)))
    }

    func classifyDigest(items: [DigestItem]) async throws -> [UUID: ClassificationResult] {
        guard !items.isEmpty else { return [:] }
        return try LLMResponseParser.parseDigest(text: try await send(LLMRequests.digest(items: items)))
    }

    func generateFollowUp(rawText: String) async throws -> FollowUpQuestion {
        try LLMResponseParser.parseFollowUp(text: try await send(LLMRequests.followUp(rawText: rawText)))
    }

    private func send(_ request: LLMRequest) async throws -> String {
        guard let apiKey = try apiKeyStore.readAPIKey(for: provider), !apiKey.isEmpty else {
            throw ClassificationError.missingAPIKey
        }
        let settings = try settingsRepository.fetchSettings()
        let model = ProviderModels.resolvedModelId(settings.modelId, for: provider)
        var urlRequest = try transport.makeRequest(request, model: model, apiKey: apiKey)
        if let requestTimeout { urlRequest.timeoutInterval = requestTimeout }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw ClassificationError.requestFailed(error)
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
            throw ClassificationError.authRejected
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 429 || http.statusCode >= 500 {
            throw ClassificationError.requestFailed(URLError(.badServerResponse))
        }
        try? spendEstimateRepository?.recordRequest(provider: provider, model: model)
        return try transport.extractText(from: data)
    }
}

final class AnthropicClassificationClient: LLMClassificationClient {
    init(
        apiKeyStore: APIKeyStore,
        settingsRepository: SettingsRepository,
        spendEstimateRepository: SpendEstimateRepository? = nil,
        session: URLSession = LLMSession.ephemeral,
        requestTimeout: TimeInterval? = nil
    ) {
        super.init(transport: AnthropicTransport(), provider: .anthropic, apiKeyStore: apiKeyStore,
                   settingsRepository: settingsRepository, spendEstimateRepository: spendEstimateRepository,
                   session: session, requestTimeout: requestTimeout)
    }
}

final class DeepSeekClassificationClient: LLMClassificationClient {
    init(
        apiKeyStore: APIKeyStore,
        settingsRepository: SettingsRepository,
        spendEstimateRepository: SpendEstimateRepository? = nil,
        session: URLSession = LLMSession.ephemeral,
        requestTimeout: TimeInterval? = nil
    ) {
        super.init(transport: DeepSeekTransport(), provider: .deepseek, apiKeyStore: apiKeyStore,
                   settingsRepository: settingsRepository, spendEstimateRepository: spendEstimateRepository,
                   session: session, requestTimeout: requestTimeout)
    }
}

enum ClassificationClientFactory {
    /// nil when no provider is connected or no key is stored: callers skip
    /// classification silently (not an error, no unreachable state).
    static func makeClient(
        settingsRepository: SettingsRepository,
        apiKeyStore: APIKeyStore,
        spendEstimateRepository: SpendEstimateRepository? = nil,
        session: URLSession = LLMSession.ephemeral,
        requestTimeout: TimeInterval? = nil
    ) -> ClassificationClient? {
        guard let settings = try? settingsRepository.fetchSettings() else { return nil }
        let provider = settings.provider
        guard provider != .none,
              apiKeyStore.hasKey(for: provider) else { return nil }
        switch provider {
        case .none: return nil
        case .anthropic:
            return AnthropicClassificationClient(apiKeyStore: apiKeyStore, settingsRepository: settingsRepository,
                                                 spendEstimateRepository: spendEstimateRepository, session: session,
                                                 requestTimeout: requestTimeout)
        case .deepseek:
            return DeepSeekClassificationClient(apiKeyStore: apiKeyStore, settingsRepository: settingsRepository,
                                                spendEstimateRepository: spendEstimateRepository, session: session,
                                                requestTimeout: requestTimeout)
        }
    }
}

enum KeyCheckError: Error, Equatable {
    case invalidKey
    case unreachable
    case rejected(Int)
}

protocol APIKeyChecker {
    /// One minimal request. Never logs the key or the response.
    func check(provider: AIProvider, apiKey: String, modelId: String) async throws
}

struct LLMKeyChecker: APIKeyChecker {
    var session: URLSession = LLMSession.ephemeral

    func check(provider: AIProvider, apiKey: String, modelId: String) async throws {
        guard let transport = LLMTransports.transport(for: provider) else { throw KeyCheckError.rejected(0) }
        let model = ProviderModels.resolvedModelId(modelId, for: provider)
        let request = try transport.makeRequest(LLMRequests.keyCheck, model: model, apiKey: apiKey)
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw KeyCheckError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw KeyCheckError.unreachable }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403: throw KeyCheckError.invalidKey
        case 429, 500...: throw KeyCheckError.unreachable
        default: throw KeyCheckError.rejected(http.statusCode)
        }
    }
}
