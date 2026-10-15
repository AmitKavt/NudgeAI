import Foundation
import SwiftData

enum ReminderSource: String, Codable {
    case siri
    case inApp
}

enum ReminderBucket: String, Codable {
    case quickTask
    case scheduledTask
    case longHorizon
}

enum ReminderUrgency: String, Codable {
    case low
    case medium
    case high
}

enum RecurringInterval: String, Codable {
    case none
    case sixMonth
    case annual
    case custom
}

/// Who assigned bucket/urgency. nil while the item is still unsorted.
enum ClassifiedBy: String, Codable {
    case llm
    case manual
}

enum ReminderStatus: String, Codable {
    case open
    case completed
    case snoozed
}

@Model
final class ReminderItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var rawText: String
    var createdAt: Date
    var source: ReminderSource
    var bucket: ReminderBucket?
    var urgency: ReminderUrgency?
    var deadline: Date?
    var recurringInterval: RecurringInterval?
    var customIntervalMonths: Int?
    var confidence: Double?
    var classifiedBy: ClassifiedBy?
    var status: ReminderStatus
    var reviewedAt: Date?
    var nextNudgeAt: Date?
    var isPreStructured: Bool
    var lastCompletedAt: Date?
    var transcriptionConfidence: Double?

    init(
        id: UUID = UUID(),
        rawText: String,
        createdAt: Date,
        source: ReminderSource,
        bucket: ReminderBucket? = nil,
        urgency: ReminderUrgency? = nil,
        deadline: Date? = nil,
        recurringInterval: RecurringInterval? = nil,
        customIntervalMonths: Int? = nil,
        confidence: Double? = nil,
        classifiedBy: ClassifiedBy? = nil,
        status: ReminderStatus = .open,
        reviewedAt: Date? = nil,
        nextNudgeAt: Date? = nil,
        isPreStructured: Bool = false,
        lastCompletedAt: Date? = nil,
        transcriptionConfidence: Double? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.createdAt = createdAt
        self.source = source
        self.bucket = bucket
        self.urgency = urgency
        self.deadline = deadline
        self.recurringInterval = recurringInterval
        self.customIntervalMonths = customIntervalMonths
        self.confidence = confidence
        self.classifiedBy = classifiedBy
        self.status = status
        self.reviewedAt = reviewedAt
        self.nextNudgeAt = nextNudgeAt
        self.isPreStructured = isPreStructured
        self.lastCompletedAt = lastCompletedAt
        self.transcriptionConfidence = transcriptionConfidence
    }
}
