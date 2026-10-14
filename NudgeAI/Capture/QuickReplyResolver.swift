import Foundation

/// Resolves a quick-reply chip tap to a concrete deadline/recurringInterval
/// entirely client-side — Claude is never asked to interpret the tap.
/// Pure logic, no SwiftUI/SwiftData, per coding-standards.md.
enum QuickReplyResolver {
    struct Resolution {
        let deadline: Date?
        let recurringInterval: RecurringInterval
    }

    static func resolve(_ option: QuickReplyOption, now: Date = Date(), calendar: Calendar = .current) -> Resolution {
        switch option.kind {
        case .relativeDays:
            let days = option.amount ?? 0
            let deadline = calendar.date(byAdding: .day, value: days, to: now)
            return Resolution(deadline: deadline, recurringInterval: .none)
        case .relativeMonths:
            let months = option.amount ?? 0
            let deadline = calendar.date(byAdding: .month, value: months, to: now)
            return Resolution(deadline: deadline, recurringInterval: .none)
        case .recurring:
            let interval = option.recurringInterval ?? .sixMonth
            let months = interval == .annual ? 12 : 6
            let deadline = calendar.date(byAdding: .month, value: months, to: now)
            return Resolution(deadline: deadline, recurringInterval: interval)
        case .noDeadline:
            return Resolution(deadline: nil, recurringInterval: .none)
        }
    }
}
