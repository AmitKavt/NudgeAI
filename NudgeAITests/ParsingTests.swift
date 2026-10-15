import XCTest
@testable import NudgeAI

final class ParsingTests: XCTestCase {
    func testValidClassification() throws {
        let result = try LLMResponseParser.parseClassification(text: Fixtures.classificationJSON)
        XCTAssertEqual(result.bucket, .scheduledTask)
        XCTAssertEqual(result.urgency, .high)
        XCTAssertEqual(result.confidence, 0.92, accuracy: 0.001)
        XCTAssertNotNil(result.deadline)
    }

    func testFencedAndProseWrappedClassification() throws {
        let fenced = "```json\n\(Fixtures.classificationJSON)\n```"
        XCTAssertEqual(try LLMResponseParser.parseClassification(text: fenced).bucket, .scheduledTask)
        let prose = "Here you go: \(Fixtures.classificationJSON) hope that helps"
        XCTAssertEqual(try LLMResponseParser.parseClassification(text: prose).urgency, .high)
    }

    func testMalformedThrowsUnparseable() {
        for text in ["", "not json", "{\"bucket\":\"nope\"}", "{\"bucket\":\"quick_task\",\"urgency\":\"zzz\",\"deadline\":null,\"recurring_interval\":\"none\",\"confidence\":1}", "{broken"] {
            XCTAssertThrowsError(try LLMResponseParser.parseClassification(text: text)) { error in
                guard case ClassificationError.unparseableResponse = error else { return XCTFail("wrong error for \(text)") }
            }
        }
    }

    func testNullDeadlineAndMonthlyMapsToCustom() throws {
        let json = "{\"bucket\":\"long_horizon\",\"urgency\":\"low\",\"deadline\":null,\"recurring_interval\":\"monthly\",\"confidence\":0.5}"
        let result = try LLMResponseParser.parseClassification(text: json)
        XCTAssertNil(result.deadline)
        XCTAssertEqual(result.recurringInterval, .custom)
    }

    func testDigestSkipsBadEntries() throws {
        let id = UUID()
        let json = "[{\"id\":\"\(id.uuidString)\",\"bucket\":\"quick_task\",\"urgency\":\"low\",\"deadline\":null,\"recurring_interval\":\"none\",\"confidence\":0.9},{\"id\":\"bad\",\"bucket\":\"quick_task\",\"urgency\":\"low\",\"deadline\":null,\"recurring_interval\":\"none\",\"confidence\":0.9}]"
        let results = try LLMResponseParser.parseDigest(text: "```\n\(json)\n```")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[id]?.bucket, .quickTask)
        XCTAssertThrowsError(try LLMResponseParser.parseDigest(text: "nope"))
    }

    func testFollowUp() throws {
        let json = "{\"question\":\"When?\",\"options\":[{\"label\":\"This week\",\"kind\":\"relativeDays\",\"amount\":7},{\"label\":\"Yearly\",\"kind\":\"recurring\",\"amount\":12}]}"
        let q = try LLMResponseParser.parseFollowUp(text: json)
        XCTAssertEqual(q.options.count, 2)
        XCTAssertEqual(q.options[1].recurringInterval, .annual)
        XCTAssertThrowsError(try LLMResponseParser.parseFollowUp(text: "{\"question\":1}"))
    }

    func testPromptsMentionJSON() {
        for prompt in [LLMPrompts.classifySystem, LLMPrompts.digestSystem, LLMPrompts.followUpSystem, LLMRequests.keyCheck.system] {
            XCTAssertTrue(prompt.contains("JSON"))
        }
    }
}
