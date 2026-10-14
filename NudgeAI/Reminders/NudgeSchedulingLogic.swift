import Foundation

/// Pure scheduling math for long-horizon escalation — no SwiftUI/SwiftData
/// imports, unit-testable in isolation per coding-standards.md.
enum NudgeSchedulingLogic {
    struct ScheduleStages {
        let leadNudgeAt: Date
        let secondNudgeAt: Date
        let dueDateCheckInAt: Date
    }

    static func computeStages(
        deadline: Date,
        leadTimeFirstDays: Int = 15,
        leadTimeSecondDays: Int = 5,
        calendar: Calendar = .current
    ) -> ScheduleStages {
        let leadNudgeAt = calendar.date(byAdding: .day, value: -leadTimeFirstDays, to: deadline) ?? deadline
        let secondNudgeAt = calendar.date(byAdding: .day, value: -leadTimeSecondDays, to: deadline) ?? deadline
        return ScheduleStages(leadNudgeAt: leadNudgeAt, secondNudgeAt: secondNudgeAt, dueDateCheckInAt: deadline)
    }

    /// The next upcoming stage, relative to `now` — becomes `ReminderItem.nextNudgeAt`.
    static func nextNudgeAt(from stages: ScheduleStages, now: Date = Date()) -> Date? {
        [stages.leadNudgeAt, stages.secondNudgeAt, stages.dueDateCheckInAt]
            .filter { $0 >= now }
            .min()
    }

    /// "Not yet" and "Done" both advance the deadline by the full recurring
    /// interval and restart the stage sequence — per NudgeAI_Spec.md, "Not yet"
    /// is not a short snooze, it reschedules forward exactly like "Done" does,
    /// just without updating `lastCompletedAt`.
    static func nextCycleDeadline(
        currentDeadline: Date,
        recurringInterval: RecurringInterval,
        customIntervalMonths: Int? = nil,
        calendar: Calendar = .current
    ) -> Date? {
        switch recurringInterval {
        case .none:
            return nil
        case .sixMonth:
            return calendar.date(byAdding: .month, value: 6, to: currentDeadline)
        case .annual:
            return calendar.date(byAdding: .year, value: 1, to: currentDeadline)
        case .custom:
            guard let months = customIntervalMonths else { return nil }
            return calendar.date(byAdding: .month, value: months, to: currentDeadline)
        }
    }
}
