import Foundation
import SwiftData

protocol ReminderRepository {
    @discardableResult
    func createReminder(
        rawText: String,
        createdAt: Date,
        source: ReminderSource,
        transcriptionConfidence: Double?
    ) throws -> ReminderItem

    func fetchAll() throws -> [ReminderItem]

    func applyClassification(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?,
        confidence: Double,
        reviewedAt: Date?
    ) throws

    func fetchNightlyReviewItems(confidenceThreshold: Double) throws -> [ReminderItem]

    /// Items that never received a classification result at all — e.g. Claude
    /// was unreachable at capture time. The nightly digest retries these.
    func fetchUnclassifiedItems() throws -> [ReminderItem]

    /// For in-app conversational capture: the deadline/recurringInterval came from
    /// the user's own chip tap (resolved client-side), not from Claude directly.
    /// Always marks `isPreStructured = true` and `reviewedAt` so it never enters
    /// nightly review, per domain-glossary.md.
    func applyPreStructuredResult(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?,
        confidence: Double
    ) throws

    func fetchItem(id: UUID) throws -> ReminderItem?

    /// Advances a long-horizon item to its next cycle (new deadline + nextNudgeAt).
    /// `completedAt` is set only on "Done" — "Not yet" leaves `lastCompletedAt` unchanged.
    func rescheduleLongHorizonCycle(
        itemId: UUID,
        newDeadline: Date,
        newNextNudgeAt: Date?,
        completedAt: Date?
    ) throws

    /// "Nudging soon": long-horizon items inside their first lead-time window.
    func fetchLongHorizonNudgingSoon(leadTimeFirstDays: Int) throws -> [ReminderItem]

    /// "Later": every other long-horizon item.
    func fetchLongHorizonLater(leadTimeFirstDays: Int) throws -> [ReminderItem]
}

final class SwiftDataReminderRepository: ReminderRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func createReminder(
        rawText: String,
        createdAt: Date,
        source: ReminderSource,
        transcriptionConfidence: Double? = nil
    ) throws -> ReminderItem {
        let item = ReminderItem(
            rawText: rawText,
            createdAt: createdAt,
            source: source,
            transcriptionConfidence: transcriptionConfidence
        )
        modelContext.insert(item)
        try modelContext.save()
        return item
    }

    func fetchAll() throws -> [ReminderItem] {
        let descriptor = FetchDescriptor<ReminderItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func applyClassification(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int? = nil,
        confidence: Double,
        reviewedAt: Date?
    ) throws {
        var descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try modelContext.fetch(descriptor).first else { return }

        item.bucket = bucket
        item.urgency = urgency
        item.deadline = deadline
        item.recurringInterval = recurringInterval
        item.customIntervalMonths = customIntervalMonths
        item.confidence = confidence
        item.reviewedAt = reviewedAt
        try modelContext.save()
    }

    func fetchNightlyReviewItems(confidenceThreshold: Double) throws -> [ReminderItem] {
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { item in
                !item.isPreStructured &&
                item.reviewedAt == nil &&
                (item.deadline == nil || (item.confidence ?? 0) < confidenceThreshold)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchUnclassifiedItems() throws -> [ReminderItem] {
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { $0.bucket == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func applyPreStructuredResult(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?,
        confidence: Double
    ) throws {
        var descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try modelContext.fetch(descriptor).first else { return }

        item.bucket = bucket
        item.urgency = urgency
        item.deadline = deadline
        item.recurringInterval = recurringInterval
        item.customIntervalMonths = customIntervalMonths
        item.confidence = confidence
        item.isPreStructured = true
        item.reviewedAt = Date()
        try modelContext.save()
    }

    func fetchItem(id: UUID) throws -> ReminderItem? {
        var descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func rescheduleLongHorizonCycle(
        itemId: UUID,
        newDeadline: Date,
        newNextNudgeAt: Date?,
        completedAt: Date?
    ) throws {
        guard let item = try fetchItem(id: itemId) else { return }

        item.deadline = newDeadline
        item.nextNudgeAt = newNextNudgeAt
        if let completedAt {
            item.lastCompletedAt = completedAt
        }
        try modelContext.save()
    }

    func fetchLongHorizonNudgingSoon(leadTimeFirstDays: Int) throws -> [ReminderItem] {
        let now = Date()
        guard let windowEnd = Calendar.current.date(byAdding: .day, value: leadTimeFirstDays, to: now) else {
            return []
        }
        let longHorizon: ReminderBucket? = .longHorizon
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { item in
                item.bucket == longHorizon &&
                item.nextNudgeAt != nil &&
                item.nextNudgeAt! <= windowEnd
            },
            sortBy: [SortDescriptor(\.nextNudgeAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchLongHorizonLater(leadTimeFirstDays: Int) throws -> [ReminderItem] {
        let now = Date()
        guard let windowEnd = Calendar.current.date(byAdding: .day, value: leadTimeFirstDays, to: now) else {
            return []
        }
        let longHorizon: ReminderBucket? = .longHorizon
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { item in
                item.bucket == longHorizon &&
                (item.nextNudgeAt == nil || item.nextNudgeAt! > windowEnd)
            },
            sortBy: [SortDescriptor(\.nextNudgeAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
}
