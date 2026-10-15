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

    /// Provider-result path only: sets `classifiedBy = .llm`. Returns false (and
    /// changes nothing) when the item was already sorted by hand or already has a
    /// classification, so a late provider result can never overwrite either.
    /// A `.custom` result with no month count is never auto-accepted: `reviewedAt`
    /// stays nil so the item goes to review and gets months from the user.
    @discardableResult
    func applyClassification(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?,
        confidence: Double,
        reviewedAt: Date?
    ) throws -> Bool

    /// Returns unsorted items (bucket == nil) as well as low-confidence / undated ones.
    func fetchNightlyReviewItems(confidenceThreshold: Double) throws -> [ReminderItem]

    /// Records that the user accepted/skipped-through an already-sorted item
    /// without altering its classification. No-op for unsorted items.
    func markReviewed(id: UUID, customIntervalMonths: Int?) throws

    /// User sorted the item by hand: sets classifiedBy = .manual, confidence = nil,
    /// reviewedAt = now. Never re-classified by a provider afterwards.
    func applyManualSort(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval?,
        customIntervalMonths: Int?
    ) throws

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
        confidence: Double,
        classifiedBy: ClassifiedBy?
    ) throws

    /// In-app follow-up when the provider produced no result: keeps only what the
    /// user chose (deadline / interval). Leaves bucket and urgency nil, not
    /// pre-structured and unreviewed, so the item lands in review as "Needs sorting".
    func applyFollowUpChoice(
        to id: UUID,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?
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

    @discardableResult
    func applyClassification(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int? = nil,
        confidence: Double,
        reviewedAt: Date?
    ) throws -> Bool {
        var descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try modelContext.fetch(descriptor).first else { return false }
        if item.classifiedBy == .manual { return false }
        if item.bucket != nil && item.classifiedBy != nil { return false }

        item.bucket = bucket
        item.urgency = urgency
        item.deadline = deadline
        item.recurringInterval = recurringInterval
        item.customIntervalMonths = customIntervalMonths
        item.confidence = confidence
        item.classifiedBy = .llm
        let needsMonths = recurringInterval == .custom && customIntervalMonths == nil
        item.reviewedAt = needsMonths ? nil : reviewedAt
        try modelContext.save()
        return true
    }

    func fetchNightlyReviewItems(confidenceThreshold: Double) throws -> [ReminderItem] {
        // Never-sorted items (bucket == nil) always have deadline == nil and
        // reviewedAt == nil, so they match without an explicit bucket clause
        // (adding one makes the #Predicate too complex to type-check).
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { item in
                !item.isPreStructured &&
                item.reviewedAt == nil &&
                (item.deadline == nil || (item.confidence ?? 0) < confidenceThreshold)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        var items = try modelContext.fetch(descriptor)
        // A custom interval with no months must always be reviewed, even when it
        // has a deadline and high confidence (filtered in memory: optional enum predicate).
        let seen = Set(items.map(\.id))
        let needMonths = try modelContext.fetch(FetchDescriptor<ReminderItem>(
            predicate: #Predicate { !$0.isPreStructured && $0.reviewedAt == nil }
        )).filter { !seen.contains($0.id) && $0.recurringInterval == .custom && $0.customIntervalMonths == nil }
        if !needMonths.isEmpty {
            items.append(contentsOf: needMonths)
            items.sort { $0.createdAt > $1.createdAt }
        }
        return items
    }

    func markReviewed(id: UUID, customIntervalMonths: Int?) throws {
        guard let item = try fetchItem(id: id), item.bucket != nil else { return }
        if let customIntervalMonths { item.customIntervalMonths = customIntervalMonths }
        // Never mark a custom interval reviewed without its month count.
        if item.recurringInterval == .custom && item.customIntervalMonths == nil { return }
        item.reviewedAt = Date()
        try modelContext.save()
    }

    func applyManualSort(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval?,
        customIntervalMonths: Int?
    ) throws {
        guard let item = try fetchItem(id: id) else { return }
        item.bucket = bucket
        item.urgency = urgency
        item.deadline = deadline
        item.recurringInterval = recurringInterval
        item.customIntervalMonths = customIntervalMonths
        item.classifiedBy = .manual
        item.confidence = nil
        item.reviewedAt = Date()
        // A sort that is not a dated long-horizon item has no nudge sequence.
        if bucket != .longHorizon || deadline == nil { item.nextNudgeAt = nil }
        try modelContext.save()
    }

    func fetchUnclassifiedItems() throws -> [ReminderItem] {
        // Filtered in memory: SwiftData cannot build a predicate on an optional
        // Codable-enum attribute ("keypath bucket not found in entity").
        let descriptor = FetchDescriptor<ReminderItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).filter { $0.bucket == nil }
    }

    func applyPreStructuredResult(
        to id: UUID,
        bucket: ReminderBucket,
        urgency: ReminderUrgency,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?,
        confidence: Double,
        classifiedBy: ClassifiedBy?
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
        item.classifiedBy = classifiedBy
        item.isPreStructured = true
        item.reviewedAt = Date()
        try modelContext.save()
    }

    func applyFollowUpChoice(
        to id: UUID,
        deadline: Date?,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int?
    ) throws {
        guard let item = try fetchItem(id: id), item.bucket == nil else { return }
        item.deadline = deadline
        item.recurringInterval = recurringInterval
        item.customIntervalMonths = customIntervalMonths
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
        let farFuture = Date.distantFuture   // an unscheduled item sorts as "later"
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { item in
                item.bucket == longHorizon &&
                (item.nextNudgeAt ?? farFuture) <= windowEnd
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
        let farFuture = Date.distantFuture   // an unscheduled item sorts as "later"
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { item in
                item.bucket == longHorizon &&
                (item.nextNudgeAt ?? farFuture) > windowEnd
            },
            sortBy: [SortDescriptor(\.nextNudgeAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
}
