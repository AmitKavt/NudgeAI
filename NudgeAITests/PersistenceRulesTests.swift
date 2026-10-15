import XCTest
import SwiftData
@testable import NudgeAI

@MainActor
final class PersistenceRulesTests: XCTestCase {
    private func make() throws -> (SwiftDataReminderRepository, SwiftDataSettingsRepository, ModelContext) {
        let context = try TestStore.makeContext()
        return (SwiftDataReminderRepository(modelContext: context), SwiftDataSettingsRepository(modelContext: context), context)
    }

    func testNewCaptureIsUnsorted() throws {
        let (repo, _, _) = try make()
        let item = try repo.createReminder(rawText: "x", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        XCTAssertNil(item.bucket); XCTAssertNil(item.urgency); XCTAssertNil(item.classifiedBy)
        XCTAssertEqual(try repo.fetchUnclassifiedItems().count, 1)
        XCTAssertEqual(try repo.fetchNightlyReviewItems(confidenceThreshold: 0.7).count, 1)
    }

    func testLLMClassificationSetsClassifiedBy() throws {
        let (repo, _, _) = try make()
        let item = try repo.createReminder(rawText: "x", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        try repo.applyClassification(to: item.id, bucket: .quickTask, urgency: .low, deadline: nil,
                                     recurringInterval: RecurringInterval.none, confidence: 0.9, reviewedAt: Date())
        XCTAssertEqual(item.classifiedBy, .llm)
    }

    func testManualSortRules() throws {
        let (repo, _, _) = try make()
        let item = try repo.createReminder(rawText: "x", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        try repo.applyManualSort(to: item.id, bucket: .scheduledTask, urgency: .high, deadline: Date(),
                                 recurringInterval: nil, customIntervalMonths: nil)
        XCTAssertEqual(item.classifiedBy, .manual)
        XCTAssertNil(item.confidence)
        XCTAssertNotNil(item.reviewedAt)
        XCTAssertEqual(try repo.fetchUnclassifiedItems().count, 0)
        XCTAssertEqual(try repo.fetchNightlyReviewItems(confidenceThreshold: 0.7).count, 0)
    }

    func testReviewRateCountsOnlyLLMItems() throws {
        let (repo, settings, context) = try make()
        let a = try repo.createReminder(rawText: "a", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        let b = try repo.createReminder(rawText: "b", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        _ = try repo.createReminder(rawText: "c", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        try repo.applyClassification(to: a.id, bucket: .quickTask, urgency: .low, deadline: nil,
                                     recurringInterval: RecurringInterval.none, confidence: 0.9, reviewedAt: Date())
        try repo.applyManualSort(to: b.id, bucket: .quickTask, urgency: .low, deadline: nil, recurringInterval: nil, customIntervalMonths: nil)
        let vm = ProfileViewModel()
        vm.load(reminderRepository: repo, spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: context), settingsRepository: settings)
        XCTAssertEqual(vm.capturedCount, 3)
        XCTAssertEqual(vm.oneTapReviewRate, 1.0, accuracy: 0.001)   // only item a is llm-classified, and reviewed
    }

    func testChangeProviderResetsModel() throws {
        let (_, settings, _) = try make()
        try settings.update { $0.changeProvider(to: .anthropic); $0.modelId = ProviderModels.anthropicSonnetId }
        try settings.update { $0.changeProvider(to: .deepseek) }
        XCTAssertEqual(try settings.fetchSettings().modelId, ProviderModels.deepseekFlashId)
        try settings.update { $0.changeProvider(to: .none) }
        XCTAssertEqual(try settings.fetchSettings().modelId, "")
    }

    func testMigrationBackfillsAndIsIdempotent() throws {
        let (repo, settings, context) = try make()
        let item = try repo.createReminder(rawText: "old", createdAt: Date(), source: .siri, transcriptionConfidence: nil)
        item.bucket = .quickTask          // pre-Phase 7 row: bucket set, classifiedBy nil
        let row = try settings.fetchSettings()
        row.selectedModel = .sonnet
        try context.save()
        let store = InMemoryKeyStore(); store.keys[.anthropic] = "test-key"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "migration-test-\(UUID().uuidString)"))

        PersistenceMigrations.runPhase7IfNeeded(context: context, apiKeyStore: store, defaults: defaults)
        XCTAssertEqual(item.classifiedBy, .llm)
        XCTAssertEqual(row.provider, .anthropic)
        XCTAssertEqual(row.modelId, ProviderModels.anthropicSonnetId)

        // Second run (even with the flag cleared) changes nothing.
        defaults.removeObject(forKey: PersistenceMigrations.phase7DefaultsKey)
        item.classifiedBy = .manual
        row.modelId = ProviderModels.anthropicHaikuId
        PersistenceMigrations.runPhase7IfNeeded(context: context, apiKeyStore: store, defaults: defaults)
        XCTAssertEqual(item.classifiedBy, .manual)
        XCTAssertEqual(row.modelId, ProviderModels.anthropicHaikuId)
    }

    func testMigrationWithoutKeyLeavesProviderNone() throws {
        let (_, settings, context) = try make()
        _ = try settings.fetchSettings()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "migration-test-\(UUID().uuidString)"))
        PersistenceMigrations.runPhase7IfNeeded(context: context, apiKeyStore: InMemoryKeyStore(), defaults: defaults)
        XCTAssertEqual(try settings.fetchSettings().provider, AIProvider.none)
    }

    func testConfidenceThresholdIsReadLiveFromSettings() throws {
        let container = try ModelContainer(for: ReminderItem.self, AppSettings.self, SpendEstimate.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let settings = SwiftDataSettingsRepository(modelContext: ModelContext(container))
        XCTAssertEqual(settings.confidenceThreshold, 0.7, accuracy: 0.0001)
        try settings.update { $0.confidenceThreshold = 0.85 }
        XCTAssertEqual(settings.confidenceThreshold, 0.85, accuracy: 0.0001)
    }
}
