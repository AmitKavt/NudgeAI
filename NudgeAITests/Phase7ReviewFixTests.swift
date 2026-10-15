import XCTest
import SwiftData
@testable import NudgeAI

final class FakeScheduler: NotificationScheduler {
    var scheduled: [UUID] = []
    var cancelled: [UUID] = []
    func requestAuthorization() async -> Bool { true }
    func scheduleNightlyReviewDigest(pendingCount: Int, hour: Int, minute: Int) async {}
    func scheduleLongHorizonSequence(itemId: UUID, rawText: String, stages: NudgeSchedulingLogic.ScheduleStages,
                                     includeDueDateCheckIn: Bool, quietHoursWindow: QuietHours.Window) async {
        scheduled.append(itemId)
    }
    func cancelLongHorizonSequence(itemId: UUID) async { cancelled.append(itemId) }
}

final class StubClient: ClassificationClient {
    var digest: (([DigestItem]) async throws -> [UUID: ClassificationResult])?
    var single: ClassificationResult?
    var followUp: FollowUpQuestion?
    var digestCalls = 0
    func classify(rawText: String) async throws -> ClassificationResult {
        guard let single else { throw ClassificationError.requestFailed(URLError(.timedOut)) }
        return single
    }
    func classifyDigest(items: [DigestItem]) async throws -> [UUID: ClassificationResult] {
        digestCalls += 1
        guard let digest else { return [:] }
        return try await digest(items)
    }
    func generateFollowUp(rawText: String) async throws -> FollowUpQuestion {
        guard let followUp else { throw ClassificationError.requestFailed(URLError(.timedOut)) }
        return followUp
    }
}

final class InMemoryIdentityStore: AppleIdentityStore {
    var id: String?
    var saves = 0
    func saveIdentifier(_ identifier: String) throws { saves += 1; id = identifier }
    func readIdentifier() throws -> String? { id }
    func deleteIdentifier() throws { id = nil }
}

private func result(_ bucket: ReminderBucket = .longHorizon, deadline: Date? = Date().addingTimeInterval(86_400 * 200),
                    interval: RecurringInterval = .annual, confidence: Double = 0.9) -> ClassificationResult {
    ClassificationResult(bucket: bucket, urgency: .low, deadline: deadline, recurringInterval: interval, confidence: confidence)
}

@MainActor
final class Phase7ReviewFixTests: XCTestCase {
    private struct Env {
        let context: ModelContext
        let repo: SwiftDataReminderRepository
        let settings: SwiftDataSettingsRepository
    }

    private func env() throws -> Env {
        let context = try TestStore.makeContext()
        return Env(context: context, repo: SwiftDataReminderRepository(modelContext: context),
                   settings: SwiftDataSettingsRepository(modelContext: context))
    }

    private func newItem(_ e: Env, _ text: String = "x") throws -> ReminderItem {
        try e.repo.createReminder(rawText: text, createdAt: Date(), source: .siri, transcriptionConfidence: nil)
    }

    // MARK: H1

    func testLateProviderResultNeverOverwritesManualSort() throws {
        let e = try env()
        let item = try newItem(e)
        try e.repo.applyManualSort(to: item.id, bucket: .quickTask, urgency: .high, deadline: nil,
                                   recurringInterval: nil, customIntervalMonths: nil)
        let applied = try e.repo.applyClassification(to: item.id, bucket: .longHorizon, urgency: .low, deadline: Date(),
                                                     recurringInterval: .annual, confidence: 0.9, reviewedAt: Date())
        XCTAssertFalse(applied)
        XCTAssertEqual(item.bucket, .quickTask)
        XCTAssertEqual(item.classifiedBy, .manual)
        XCTAssertEqual(item.urgency, .high)
    }

    func testAlreadyClassifiedItemIsNotReclassified() throws {
        let e = try env()
        let item = try newItem(e)
        XCTAssertTrue(try e.repo.applyClassification(to: item.id, bucket: .quickTask, urgency: .low, deadline: nil,
                                                     recurringInterval: RecurringInterval.none, confidence: 0.9, reviewedAt: Date()))
        XCTAssertFalse(try e.repo.applyClassification(to: item.id, bucket: .scheduledTask, urgency: .high, deadline: Date(),
                                                      recurringInterval: RecurringInterval.none, confidence: 0.9, reviewedAt: Date()))
        XCTAssertEqual(item.bucket, .quickTask)
    }

    func testBatchRaceManualSortDuringInFlightCallIsPreserved() async throws {
        let e = try env()
        let item = try newItem(e, "renew passport")
        let other = try newItem(e, "other")
        let id = item.id
        let client = StubClient()
        client.digest = { [repo = e.repo] items in
            // The user sorts the item by hand while the provider call is in flight.
            try repo.applyManualSort(to: id, bucket: .quickTask, urgency: .high, deadline: nil,
                                     recurringInterval: nil, customIntervalMonths: nil)
            return Dictionary(uniqueKeysWithValues: items.map { ($0.id, result()) })
        }
        let scheduler = FakeScheduler()
        let coordinator = ClassificationCoordinator(client: client, reminderRepository: e.repo, settingsRepository: e.settings,
                                                    unreachableState: ProviderUnreachableState(),
                                                    notificationScheduler: scheduler, gate: ClassificationGate())
        let reachable = await coordinator.classifyUnsorted()
        XCTAssertTrue(reachable)
        XCTAssertEqual(item.bucket, .quickTask)
        XCTAssertEqual(item.classifiedBy, .manual)
        XCTAssertNil(item.deadline)
        XCTAssertFalse(scheduler.scheduled.contains(id), "no notifications for a skipped item")
        XCTAssertEqual(other.bucket, .longHorizon)          // the untouched item still classified
        XCTAssertTrue(scheduler.scheduled.contains(other.id))
    }

    // MARK: M1

    func testFollowUpWithoutProviderResultLeavesItemUnsortedAndInReview() async throws {
        let e = try env()
        let item = try newItem(e)
        let client = StubClient()
        client.followUp = FollowUpQuestion(question: "When?", options: [])
        let vm = FollowUpViewModel(item: item, client: client, reminderRepository: e.repo,
                                   settingsRepository: e.settings, notificationScheduler: FakeScheduler())
        await vm.start()
        await vm.select(QuickReplyOption(label: "In a week", kind: .relativeDays, amount: 7, recurringInterval: nil))
        XCTAssertNil(item.bucket); XCTAssertNil(item.urgency); XCTAssertNil(item.confidence)
        XCTAssertFalse(item.isPreStructured)
        XCTAssertNil(item.reviewedAt)
        XCTAssertNotNil(item.deadline, "chip-chosen deadline is kept")
        XCTAssertTrue(ReviewRules.isUnsorted(bucket: item.bucket))
        XCTAssertEqual(try e.repo.fetchNightlyReviewItems(confidenceThreshold: 0.7).map(\.id), [item.id])
        XCTAssertTrue(vm.isComplete)
    }

    func testFollowUpClientTimeoutIsSetOnRequests() async throws {
        let context = try TestStore.makeContext()
        let settings = SwiftDataSettingsRepository(modelContext: context)
        try settings.update { $0.changeProvider(to: .deepseek) }
        let store = InMemoryKeyStore(); store.keys[.deepseek] = "test-key"
        let session = MockURLProtocol.session()
        MockURLProtocol.respond(body: Fixtures.deepSeekEnvelope(text: Fixtures.classificationJSON))
        let client = DeepSeekClassificationClient(apiKeyStore: store, settingsRepository: settings, session: session,
                                                  requestTimeout: FollowUpViewModel.requestTimeout)
        _ = try await client.classify(rawText: "x")
        XCTAssertEqual(MockURLProtocol.requests.first?.timeoutInterval, 20)
        XCTAssertEqual(FollowUpViewModel.requestTimeout, 20)
    }

    // MARK: M2

    func testSkipOnlyDropsFromSessionAndItemReturnsNextReview() throws {
        let e = try env()
        let item = try newItem(e)
        try e.repo.applyClassification(to: item.id, bucket: .quickTask, urgency: .low, deadline: nil,
                                       recurringInterval: RecurringInterval.none, confidence: 0.4, reviewedAt: nil)
        let vm = ReviewViewModel(reminderRepository: e.repo, settingsRepository: e.settings, notificationScheduler: FakeScheduler())
        vm.loadQueue()
        XCTAssertEqual(vm.queue.count, 1)
        vm.skip(item)
        XCTAssertTrue(vm.queue.isEmpty)
        XCTAssertNil(item.reviewedAt)
        vm.loadQueue()   // next review
        XCTAssertEqual(vm.queue.map(\.id), [item.id])
    }

    // MARK: M3

    func testCustomWithoutMonthsIsNeverAutoAccepted() throws {
        let e = try env()
        let item = try newItem(e)
        try e.repo.applyClassification(to: item.id, bucket: .longHorizon, urgency: .low, deadline: Date().addingTimeInterval(86_400 * 90),
                                       recurringInterval: .custom, customIntervalMonths: nil, confidence: 0.95, reviewedAt: Date())
        XCTAssertNil(item.reviewedAt)
        // High confidence + deadline would normally skip review; custom/nil must still appear.
        XCTAssertEqual(try e.repo.fetchNightlyReviewItems(confidenceThreshold: 0.7).map(\.id), [item.id])
        // Skip path (markReviewed without months) cannot clear it.
        try e.repo.markReviewed(id: item.id, customIntervalMonths: nil)
        XCTAssertNil(item.reviewedAt)
        // Accept path with months resolves it.
        try e.repo.markReviewed(id: item.id, customIntervalMonths: 9)
        XCTAssertNotNil(item.reviewedAt)
        XCTAssertEqual(item.customIntervalMonths, 9)
        XCTAssertTrue(try e.repo.fetchNightlyReviewItems(confidenceThreshold: 0.7).isEmpty)
    }

    func testReviewAcceptOfCustomWithoutMonthsAsksForMonths() throws {
        let e = try env()
        let item = try newItem(e)
        try e.repo.applyClassification(to: item.id, bucket: .longHorizon, urgency: .low, deadline: Date().addingTimeInterval(86_400 * 90),
                                       recurringInterval: .custom, customIntervalMonths: nil, confidence: 0.95, reviewedAt: Date())
        let vm = ReviewViewModel(reminderRepository: e.repo, settingsRepository: e.settings, notificationScheduler: FakeScheduler())
        vm.accept(item)
        XCTAssertEqual(vm.itemNeedingCustomInterval?.id, item.id)
        XCTAssertNil(item.reviewedAt)
    }

    // MARK: M4

    func testAdjustAwayFromLongHorizonCancelsSequenceAndClearsNextNudge() async throws {
        let e = try env()
        let item = try newItem(e)
        try e.repo.applyClassification(to: item.id, bucket: .longHorizon, urgency: .low, deadline: Date().addingTimeInterval(86_400 * 90),
                                       recurringInterval: .annual, confidence: 0.4, reviewedAt: nil)
        item.nextNudgeAt = Date().addingTimeInterval(86_400)
        let scheduler = FakeScheduler()
        let vm = ReviewViewModel(reminderRepository: e.repo, settingsRepository: e.settings, notificationScheduler: scheduler)
        let draft = AdjustDraft(bucket: .quickTask, urgency: .low, hasDeadline: false, deadline: Date(),
                                interval: .sixMonth, customMonths: nil)
        await vm.saveAdjust(item, draft: draft)
        XCTAssertEqual(scheduler.cancelled, [item.id])
        XCTAssertNil(item.nextNudgeAt)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    // MARK: M5

    func testDisconnectClearsBackfillMarker() throws {
        let e = try env()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "disconnect-test-\(UUID().uuidString)"))
        defaults.set("deepseek", forKey: BackfillPolicy.defaultsKey)
        let store = InMemoryKeyStore(); store.keys[.deepseek] = "test-key"
        let service = ProviderConnectionService(apiKeyStore: store, settingsRepository: e.settings, defaults: defaults)
        try service.disconnect(provider: .deepseek)
        XCTAssertNil(defaults.string(forKey: BackfillPolicy.defaultsKey))
        XCTAssertTrue(BackfillPolicy.shouldRun(provider: .deepseek, lastBackfilled: defaults.string(forKey: BackfillPolicy.defaultsKey)))
    }

    func testSingleFlightGateBlocksConcurrentRun() async throws {
        let e = try env()
        _ = try newItem(e)
        let client = StubClient()
        let gate = ClassificationGate()
        let coordinator = ClassificationCoordinator(client: client, reminderRepository: e.repo, settingsRepository: e.settings,
                                                    unreachableState: ProviderUnreachableState(),
                                                    notificationScheduler: FakeScheduler(), gate: gate)
        let entered = await gate.tryEnter()
        XCTAssertTrue(entered)
        let blocked = await coordinator.classifyUnsorted()
        XCTAssertFalse(blocked)
        XCTAssertEqual(client.digestCalls, 0)
        await gate.leave()
        _ = await coordinator.classifyUnsorted()
        XCTAssertEqual(client.digestCalls, 1)
        // The gate is released after a run.
        let again = await gate.tryEnter()
        XCTAssertTrue(again)
    }

    // MARK: L1 / L3

    func testScheduledTaskRequiresDeadline() {
        let noDeadline = AdjustDraft(bucket: .scheduledTask, urgency: .low, hasDeadline: false, deadline: Date(),
                                     interval: .sixMonth, customMonths: nil)
        XCTAssertEqual(noDeadline.problems, [.missingDeadline])
        XCTAssertNil(noDeadline.result())
        var ok = noDeadline; ok.hasDeadline = true
        XCTAssertTrue(ok.isValid)
    }

    // MARK: S1 / S2 / S3

    func testKeychainMigrationResavesOnceAndSetsFlag() throws {
        let keys = InMemoryKeyStore(); keys.keys[.anthropic] = "test-key"
        let identity = InMemoryIdentityStore(); identity.id = "apple-id"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "kc-test-\(UUID().uuidString)"))
        PersistenceMigrations.runKeychainAccessibilityIfNeeded(apiKeyStore: keys, identityStore: identity, defaults: defaults)
        XCTAssertEqual(keys.saveCount, 1)
        XCTAssertEqual(identity.saves, 1)
        XCTAssertEqual(keys.keys[.anthropic], "test-key")
        PersistenceMigrations.runKeychainAccessibilityIfNeeded(apiKeyStore: keys, identityStore: identity, defaults: defaults)
        XCTAssertEqual(keys.saveCount, 1)
    }

    func testHasKeyNeverReadsValue() throws {
        let e = try env()
        let store = InMemoryKeyStore(); store.keys[.anthropic] = "test-key"
        XCTAssertTrue(store.hasKey(for: .anthropic))
        XCTAssertFalse(store.hasKey(for: .deepseek))
        // Existence checks in migration and the factory go through hasKey.
        try e.settings.update { $0.changeProvider(to: .anthropic) }
        _ = ClassificationClientFactory.makeClient(settingsRepository: e.settings, apiKeyStore: store)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "haskey-\(UUID().uuidString)"))
        PersistenceMigrations.runPhase7IfNeeded(context: e.context, apiKeyStore: store, defaults: defaults)
        XCTAssertEqual(store.readCount, 0)
        XCTAssertFalse(KeychainAPIKeyStore().hasKey(for: .none))
    }

    func testDefaultSessionIsEphemeralWithoutCache() {
        let config = LLMSession.makeConfiguration()
        XCTAssertNil(config.urlCache)
        XCTAssertNil(config.httpCookieStorage)
        XCTAssertEqual(config.requestCachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertNil(LLMSession.ephemeral.configuration.urlCache)
    }

    // MARK: S4

    func testAuthFailureIsDistinctAndNotCountedAsSpend() async throws {
        let context = try TestStore.makeContext()
        let settings = SwiftDataSettingsRepository(modelContext: context)
        try settings.update { $0.changeProvider(to: .deepseek) }
        let store = InMemoryKeyStore(); store.keys[.deepseek] = "test-key"
        let spend = SwiftDataSpendEstimateRepository(modelContext: context)
        for status in [401, 403] {
            let session = MockURLProtocol.session()
            MockURLProtocol.respond(status: status, body: "{}")
            let client = DeepSeekClassificationClient(apiKeyStore: store, settingsRepository: settings,
                                                      spendEstimateRepository: spend, session: session)
            do {
                _ = try await client.classify(rawText: "x")
                XCTFail("expected authRejected")
            } catch ClassificationError.authRejected {
            } catch { XCTFail("wrong error \(error)") }
        }
        XCTAssertEqual(try spend.currentMonthEstimate().requestCount, 0)
    }

    func testCoordinatorSurfacesKeyRejectedWithoutMarkingUnreachable() async throws {
        let e = try env()
        _ = try newItem(e)
        let client = StubClient()
        client.digest = { _ in throw ClassificationError.authRejected }
        let state = ProviderUnreachableState()
        let coordinator = ClassificationCoordinator(client: client, reminderRepository: e.repo, settingsRepository: e.settings,
                                                    unreachableState: state, notificationScheduler: FakeScheduler(), gate: ClassificationGate())
        let ok = await coordinator.classifyUnsorted()
        XCTAssertFalse(ok)
        XCTAssertTrue(state.isKeyRejected)
        XCTAssertFalse(state.isUnreachable)
        XCTAssertEqual(ProviderConnectionStatus.resolve(selected: .deepseek, activeProvider: .deepseek, hasKey: true,
                                                        isUnreachable: false, isKeyRejected: true), .keyRejected)
        XCTAssertEqual(ProviderConnectionStatus.keyRejected.label, "Key rejected")
        state.markReachable()
        XCTAssertFalse(state.isKeyRejected)
    }
}
