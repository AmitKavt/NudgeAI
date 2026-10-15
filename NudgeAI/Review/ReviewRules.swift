import Foundation

/// Pure review-card rules (Foundation only, unit-tested).
enum ReviewRules {
    /// "Needs sorting": the item has no bucket yet (never classified, never sorted by hand).
    /// This includes an in-app follow-up whose provider call produced no result: it
    /// keeps the user's chip deadline/interval but no bucket, so it lands in review
    /// as "Needs sorting" (never assumed quickTask/medium).
    static func isUnsorted(bucket: ReminderBucket?) -> Bool {
        bucket == nil
    }

    /// Swipe-right / "Looks right" needs both fields to exist.
    static func canAccept(bucket: ReminderBucket?, urgency: ReminderUrgency?) -> Bool {
        bucket != nil && urgency != nil
    }
}

/// The banner and paused review only ever apply when a provider is connected.
enum UnreachablePresentation {
    static func shouldShow(isUnreachable: Bool, provider: AIProvider) -> Bool {
        isUnreachable && provider != .none
    }
}

/// State of the Adjust editor and its save rules.
struct AdjustDraft: Equatable {
    var bucket: ReminderBucket?
    var urgency: ReminderUrgency?
    var hasDeadline: Bool
    var deadline: Date
    /// Only meaningful for long-horizon: .sixMonth, .annual or .custom.
    var interval: RecurringInterval
    var customMonths: Int?

    static let customMonthsRange = 1...60

    enum Problem: Equatable {
        case missingBucket
        case missingUrgency
        case invalidInterval
        case missingCustomMonths
        case missingDeadline
    }

    struct Result: Equatable {
        let bucket: ReminderBucket
        let urgency: ReminderUrgency
        let deadline: Date?
        let recurringInterval: RecurringInterval
        let customIntervalMonths: Int?
    }

    var problems: [Problem] {
        var found: [Problem] = []
        if bucket == nil { found.append(.missingBucket) }
        if urgency == nil { found.append(.missingUrgency) }
        if bucket == .scheduledTask && !hasDeadline { found.append(.missingDeadline) }
        if bucket == .longHorizon {
            switch interval {
            case .none: found.append(.invalidInterval)
            case .custom:
                if let months = customMonths {
                    if !Self.customMonthsRange.contains(months) { found.append(.missingCustomMonths) }
                } else {
                    found.append(.missingCustomMonths)
                }
            case .sixMonth, .annual: break
            }
        }
        return found
    }

    var isValid: Bool { problems.isEmpty }

    /// Normalized values to persist, or nil when invalid. Non-long-horizon items
    /// never keep an interval. A long-horizon item with no chosen deadline gets
    /// one derived from its interval (now + 6 / 12 / custom months) so it can be nudged.
    func result(now: Date = Date(), calendar: Calendar = .current) -> Result? {
        guard isValid, let bucket, let urgency else { return nil }
        guard bucket == .longHorizon else {
            return Result(bucket: bucket, urgency: urgency, deadline: hasDeadline ? deadline : nil,
                          recurringInterval: .none, customIntervalMonths: nil)
        }
        let months: Int
        switch interval {
        case .sixMonth: months = 6
        case .annual: months = 12
        default: months = customMonths ?? 0
        }
        let finalDeadline = hasDeadline ? deadline : calendar.date(byAdding: .month, value: months, to: now)
        return Result(bucket: bucket, urgency: urgency, deadline: finalDeadline, recurringInterval: interval,
                      customIntervalMonths: interval == .custom ? customMonths : nil)
    }
}
