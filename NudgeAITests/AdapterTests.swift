import XCTest
import SwiftData
@testable import NudgeAI

@MainActor
final class AdapterTests: XCTestCase {
    private func makeSettings(provider: AIProvider, modelId: String? = nil) throws -> (SwiftDataSettingsRepository, ModelContext) {
        let context = try TestStore.makeContext()
        let repo = SwiftDataSettingsRepository(modelContext: context)
        try repo.update { $0.changeProvider(to: provider); if let modelId { $0.modelId = modelId } }
        return (repo, context)
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: request building

    func testAnthropicRequestShape() throws {
        let req = try AnthropicTransport().makeRequest(LLMRequests.classify(rawText: "buy milk"), model: "claude-haiku-5-5", apiKey: "test-key")
        XCTAssertEqual(req.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let json = try body(req)
        XCTAssertEqual(json["model"] as? String, "claude-haiku-5-5")
        XCTAssertEqual(json["system"] as? String, LLMPrompts.classifySystem)
        XCTAssertEqual((json["thinking"] as? [String: String])?["type"], "disabled")
        let sonnet = try body(AnthropicTransport().makeRequest(LLMRequests.classify(rawText: "x"), model: "claude-sonnet-5-5", apiKey: "test-key"))
        XCTAssertEqual((sonnet["thinking"] as? [String: String])?["type"], "between_tools")
    }

    func testDeepSeekRequestShape() throws {
        let req = try DeepSeekTransport().makeRequest(LLMRequests.classify(rawText: "buy milk"), model: "deepseek-flash", apiKey: "test-key")
        XCTAssertEqual(req.url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        let json = try body(req)
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.first?["role"], "system")
        XCTAssertEqual(messages.last?["content"], "buy milk")
        XCTAssertEqual((json["response_format"] as? [String: String])?["type"], "json_object")
        XCTAssertEqual((json["thinking"] as? [String: String])?["type"], "disabled")
        // Digest returns an array, which JSON mode cannot express.
        let digest = try body(DeepSeekTransport().makeRequest(LLMRequests.digest(items: [DigestItem(id: UUID(), rawText: "a")]), model: "deepseek-flash", apiKey: "test-key"))
        XCTAssertNil(digest["response_format"])
    }

    // MARK: response parsing through mocked URLSession

    func testAnthropicClassifyEndToEnd() async throws {
        let (settings, context) = try makeSettings(provider: .anthropic)
        let store = InMemoryKeyStore(); store.keys[.anthropic] = "test-key"
        let session = MockURLProtocol.session()
        MockURLProtocol.respond(body: Fixtures.anthropicEnvelope(text: "```json\n\(Fixtures.classificationJSON)\n```"))
        let spend = SwiftDataSpendEstimateRepository(modelContext: context)
        let client = AnthropicClassificationClient(apiKeyStore: store, settingsRepository: settings, spendEstimateRepository: spend, session: session)
        let result = try await client.classify(rawText: "dentist")
        XCTAssertEqual(result.bucket, .scheduledTask)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertEqual(try spend.currentMonthEstimate().requestCount, 1)
    }

    func testDeepSeekClassifyEndToEnd() async throws {
        let (settings, _) = try makeSettings(provider: .deepseek)
        let store = InMemoryKeyStore(); store.keys[.deepseek] = "test-key"
        let session = MockURLProtocol.session()
        MockURLProtocol.respond(body: Fixtures.deepSeekEnvelope(text: Fixtures.classificationJSON))
        let client = DeepSeekClassificationClient(apiKeyStore: store, settingsRepository: settings, session: session)
        let result = try await client.classify(rawText: "dentist")
        XCTAssertEqual(result.urgency, .high)
        XCTAssertEqual(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    }

    func testDeepSeekMalformedAndEmptyAreUnparseable() async throws {
        let (settings, _) = try makeSettings(provider: .deepseek)
        let store = InMemoryKeyStore(); store.keys[.deepseek] = "test-key"
        let session = MockURLProtocol.session()
        let client = DeepSeekClassificationClient(apiKeyStore: store, settingsRepository: settings, session: session)
        for body in [Fixtures.deepSeekEnvelope(text: "sorry, can't"), Fixtures.deepSeekEnvelope(text: ""), "{\"choices\":[]}", "garbage"] {
            MockURLProtocol.respond(body: body)
            do { _ = try await client.classify(rawText: "x"); XCTFail("expected throw") }
            catch ClassificationError.unparseableResponse {}
        }
    }

    func testServerErrorMapsToRequestFailedAndAuthErrorIsDistinct() async throws {
        let (settings, _) = try makeSettings(provider: .anthropic)
        let store = InMemoryKeyStore(); store.keys[.anthropic] = "test-key"
        let session = MockURLProtocol.session()
        let client = AnthropicClassificationClient(apiKeyStore: store, settingsRepository: settings, session: session)
        MockURLProtocol.respond(status: 503, body: "{}")
        do { _ = try await client.classify(rawText: "x"); XCTFail() } catch ClassificationError.requestFailed {}
        MockURLProtocol.respond(status: 401, body: "{\"error\":{}}")
        do { _ = try await client.classify(rawText: "x"); XCTFail() } catch ClassificationError.authRejected {}
    }

    func testMissingKeyThrows() async throws {
        let (settings, _) = try makeSettings(provider: .anthropic)
        let client = AnthropicClassificationClient(apiKeyStore: InMemoryKeyStore(), settingsRepository: settings, session: MockURLProtocol.session())
        do { _ = try await client.classify(rawText: "x"); XCTFail() } catch ClassificationError.missingAPIKey {}
    }

    func testStaleModelFallsBackToProviderDefault() async throws {
        let (settings, _) = try makeSettings(provider: .deepseek, modelId: "claude-haiku-5-5")
        let store = InMemoryKeyStore(); store.keys[.deepseek] = "test-key"
        let session = MockURLProtocol.session()
        MockURLProtocol.respond(body: Fixtures.deepSeekEnvelope(text: Fixtures.classificationJSON))
        _ = try await DeepSeekClassificationClient(apiKeyStore: store, settingsRepository: settings, session: session).classify(rawText: "x")
        let json = try body(try XCTUnwrap(MockURLProtocol.requests.first.map { req -> URLRequest in
            var copy = req; copy.httpBody = req.httpBody ?? Self.readStream(req); return copy }))
        XCTAssertEqual(json["model"] as? String, "deepseek-flash")
    }

    static func readStream(_ req: URLRequest) -> Data? {
        guard let stream = req.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
        return data
    }

    // MARK: factory

    func testFactoryNilPaths() throws {
        let context = try TestStore.makeContext()
        let settings = SwiftDataSettingsRepository(modelContext: context)
        let store = InMemoryKeyStore()
        // provider none
        XCTAssertNil(ClassificationClientFactory.makeClient(settingsRepository: settings, apiKeyStore: store))
        // provider set, no key
        try settings.update { $0.changeProvider(to: .deepseek) }
        XCTAssertNil(ClassificationClientFactory.makeClient(settingsRepository: settings, apiKeyStore: store))
        // key stored only for another platform
        store.keys[.anthropic] = "test-key"
        XCTAssertNil(ClassificationClientFactory.makeClient(settingsRepository: settings, apiKeyStore: store))
        store.keys[.deepseek] = "test-key"
        XCTAssertTrue(ClassificationClientFactory.makeClient(settingsRepository: settings, apiKeyStore: store) is DeepSeekClassificationClient)
        try settings.update { $0.changeProvider(to: .anthropic) }
        XCTAssertTrue(ClassificationClientFactory.makeClient(settingsRepository: settings, apiKeyStore: store) is AnthropicClassificationClient)
    }

    // MARK: key check + connection service

    func testKeyCheckStatuses() async throws {
        let session = MockURLProtocol.session()
        let checker = LLMKeyChecker(session: session)
        MockURLProtocol.respond(body: Fixtures.deepSeekEnvelope(text: "{\"ok\":true}"))
        try await checker.check(provider: .deepseek, apiKey: "test-key", modelId: "deepseek-flash")
        MockURLProtocol.respond(status: 401, body: "{}")
        do { try await checker.check(provider: .anthropic, apiKey: "test-key", modelId: "claude-haiku-5-5"); XCTFail() }
        catch let error as KeyCheckError { XCTAssertEqual(error, .invalidKey) }
        MockURLProtocol.respond(status: 500, body: "{}")
        do { try await checker.check(provider: .anthropic, apiKey: "test-key", modelId: "claude-haiku-5-5"); XCTFail() }
        catch let error as KeyCheckError { XCTAssertEqual(error, .unreachable) }
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do { try await checker.check(provider: .deepseek, apiKey: "test-key", modelId: "x"); XCTFail() }
        catch let error as KeyCheckError { XCTAssertEqual(error, .unreachable) }
    }

    func testConnectStoresOnlyOnSuccessAndDisconnectDeletes() async throws {
        let context = try TestStore.makeContext()
        let settings = SwiftDataSettingsRepository(modelContext: context)
        let store = InMemoryKeyStore()
        let session = MockURLProtocol.session()
        let service = ProviderConnectionService(apiKeyStore: store, keyChecker: LLMKeyChecker(session: session), settingsRepository: settings)

        MockURLProtocol.respond(status: 401, body: "{}")
        do { try await service.connect(provider: .deepseek, apiKey: "test-key"); XCTFail() } catch is KeyCheckError {}
        XCTAssertNil(store.keys[.deepseek])
        XCTAssertEqual(try settings.fetchSettings().provider, AIProvider.none)

        MockURLProtocol.respond(body: Fixtures.deepSeekEnvelope(text: "{\"ok\":true}"))
        try await service.connect(provider: .deepseek, apiKey: "  test-key \n")
        XCTAssertEqual(store.keys[.deepseek], "test-key")
        XCTAssertEqual(try settings.fetchSettings().provider, .deepseek)
        XCTAssertEqual(try settings.fetchSettings().modelId, ProviderModels.deepseekFlashId)

        try service.disconnect(provider: .deepseek)
        XCTAssertNil(store.keys[.deepseek])
        XCTAssertEqual(try settings.fetchSettings().provider, AIProvider.none)
    }

    // MARK: spend

    func testPricing() {
        XCTAssertNotNil(ModelPricing.costPerRequest(provider: .deepseek, modelId: ProviderModels.deepseekFlashId))
        XCTAssertNil(ModelPricing.costPerRequest(provider: .anthropic, modelId: "claude-sonnet-5"))
        XCTAssertNil(ModelPricing.costPerRequest(provider: .deepseek, modelId: "unknown"))
    }

    func testUnknownPricingCountsRequestsOnly() throws {
        let repo = SwiftDataSpendEstimateRepository(modelContext: try TestStore.makeContext())
        try repo.recordRequest(provider: .anthropic, model: "claude-sonnet-5")
        try repo.recordRequest(provider: .deepseek, model: ProviderModels.deepseekFlashId)
        let estimate = try repo.currentMonthEstimate()
        XCTAssertEqual(estimate.requestCount, 2)
        XCTAssertEqual(estimate.unpricedRequestCount, 1)
        XCTAssertGreaterThan(estimate.estimatedCost, 0)
    }
}
