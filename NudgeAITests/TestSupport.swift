import Foundation
import SwiftData
@testable import NudgeAI

final class InMemoryKeyStore: APIKeyStore {
    var keys: [AIProvider: String] = [:]
    func saveAPIKey(_ key: String, for provider: AIProvider) throws { saveCount += 1; keys[provider] = key }
    func readAPIKey(for provider: AIProvider) throws -> String? { readCount += 1; return keys[provider] }
    func deleteAPIKey(for provider: AIProvider) throws { keys[provider] = nil }
    var readCount = 0
    var saveCount = 0
    func hasKey(for provider: AIProvider) -> Bool { keys[provider] != nil }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}

    static func session() -> URLSession {
        handler = nil
        requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func respond(status: Int = 200, body: String) {
        handler = { request in
            let url = request.url ?? URL(fileURLWithPath: "/")
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
    }
}

@MainActor
enum TestStore {
    static func makeContext() throws -> ModelContext {
        let schema = Schema([ReminderItem.self, AppSettings.self, SpendEstimate.self])
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}

enum Fixtures {
    static let classificationJSON = """
    {"bucket":"scheduled_task","urgency":"high","deadline":"2026-10-20","recurring_interval":"none","confidence":0.92}
    """
    static func anthropicEnvelope(text: String) -> String {
        let escaped = String(data: (try? JSONEncoder().encode(text)) ?? Data(), encoding: .utf8) ?? "\"\""
        return "{\"content\":[{\"type\":\"thinking\",\"thinking\":\"\"},{\"type\":\"text\",\"text\":\(escaped)}]}"
    }
    static func deepSeekEnvelope(text: String) -> String {
        let escaped = String(data: (try? JSONEncoder().encode(text)) ?? Data(), encoding: .utf8) ?? "\"\""
        return "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\(escaped)}}]}"
    }
}
