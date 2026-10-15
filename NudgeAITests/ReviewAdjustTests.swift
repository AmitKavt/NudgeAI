import XCTest
@testable import NudgeAI

final class ReviewAdjustTests: XCTestCase {
    private func draft(bucket: ReminderBucket? = .quickTask, urgency: ReminderUrgency? = .low,
                       hasDeadline: Bool = false, interval: RecurringInterval = .sixMonth,
                       months: Int? = nil) -> AdjustDraft {
        AdjustDraft(bucket: bucket, urgency: urgency, hasDeadline: hasDeadline,
                    deadline: Date(timeIntervalSince1970: 1_800_000_000), interval: interval, customMonths: months)
    }

    func testUnsortedAndAcceptRules() {
        XCTAssertTrue(ReviewRules.isUnsorted(bucket: nil))
        XCTAssertFalse(ReviewRules.isUnsorted(bucket: .quickTask))
        XCTAssertFalse(ReviewRules.canAccept(bucket: nil, urgency: nil))
        XCTAssertFalse(ReviewRules.canAccept(bucket: .quickTask, urgency: nil))
        XCTAssertTrue(ReviewRules.canAccept(bucket: .quickTask, urgency: .low))
    }

    func testMissingFieldsAreInvalid() {
        XCTAssertEqual(draft(bucket: nil, urgency: nil).problems, [.missingBucket, .missingUrgency])
        XCTAssertNil(draft(bucket: nil).result())
    }

    func testCustomRequiresMonthsAndNeverPersistsNil() {
        XCTAssertFalse(draft(bucket: .longHorizon, interval: .custom, months: nil).isValid)
        XCTAssertFalse(draft(bucket: .longHorizon, interval: .custom, months: 0).isValid)
        XCTAssertFalse(draft(bucket: .longHorizon, interval: .custom, months: 61).isValid)
        let ok = draft(bucket: .longHorizon, interval: .custom, months: 9).result()
        XCTAssertEqual(ok?.customIntervalMonths, 9)
        XCTAssertEqual(ok?.recurringInterval, .custom)
    }

    func testLongHorizonRejectsNoneInterval() {
        XCTAssertEqual(draft(bucket: .longHorizon, interval: RecurringInterval.none).problems, [.invalidInterval])
    }

    func testNonLongHorizonDropsIntervalAndCustomMonths() {
        let r = draft(bucket: .scheduledTask, hasDeadline: true, interval: .custom, months: 4).result()
        XCTAssertEqual(r?.recurringInterval, RecurringInterval.none)
        XCTAssertNil(r?.customIntervalMonths)
        XCTAssertNotNil(r?.deadline)
        XCTAssertNil(draft(bucket: .quickTask).result()?.deadline)
    }

    func testLongHorizonWithoutDeadlineDerivesOneFromInterval() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar(identifier: .gregorian)
        let r = draft(bucket: .longHorizon, interval: .annual).result(now: now, calendar: cal)
        XCTAssertEqual(r?.deadline, cal.date(byAdding: .month, value: 12, to: now))
    }

    func testUnreachableNeverShowsWithoutProvider() {
        XCTAssertFalse(UnreachablePresentation.shouldShow(isUnreachable: true, provider: .none))
        XCTAssertTrue(UnreachablePresentation.shouldShow(isUnreachable: true, provider: .deepseek))
        XCTAssertFalse(UnreachablePresentation.shouldShow(isUnreachable: false, provider: .anthropic))
    }

    func testBackfillPolicyRunsOncePerPlatform() {
        XCTAssertFalse(BackfillPolicy.shouldRun(provider: .none, lastBackfilled: nil))
        XCTAssertTrue(BackfillPolicy.shouldRun(provider: .deepseek, lastBackfilled: nil))
        XCTAssertFalse(BackfillPolicy.shouldRun(provider: .deepseek, lastBackfilled: "deepseek"))
        XCTAssertTrue(BackfillPolicy.shouldRun(provider: .anthropic, lastBackfilled: "deepseek"))
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(AIProvider.deepseek.displayName, "DeepSeek")
        XCTAssertEqual(AIProvider.none.displayName, "")
    }
}

@MainActor
final class ReviewQueueTests: XCTestCase {
    func testQueueIncludesUnsortedAndExcludesManualAndPreviousProviderItems() throws {
        let context = try TestStore.makeContext()
        let repo = SwiftDataReminderRepository(modelContext: context)
        let unsorted = try repo.createReminder(rawText: "a", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        let manual = try repo.createReminder(rawText: "b", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        try repo.applyManualSort(to: manual.id, bucket: .quickTask, urgency: .low, deadline: nil,
                                 recurringInterval: nil, customIntervalMonths: nil)
        let llm = try repo.createReminder(rawText: "c", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        try repo.applyClassification(to: llm.id, bucket: .quickTask, urgency: .low, deadline: nil,
                                     recurringInterval: RecurringInterval.none, confidence: 0.9, reviewedAt: Date())

        let queue = try repo.fetchNightlyReviewItems(confidenceThreshold: 0.7).map(\.id)
        XCTAssertEqual(queue, [unsorted.id])
        // Backfill candidates: only never-sorted items; manual and prior-provider items untouched.
        XCTAssertEqual(try repo.fetchUnclassifiedItems().map(\.id), [unsorted.id])
    }
}
