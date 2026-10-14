import Foundation

/// Pure logic — holds non-urgent notification delivery until the quiet-hours
/// window ends, per domain-glossary.md. No SwiftUI/SwiftData imports.
enum QuietHours {
    struct Window {
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int

        static let `default` = Window(startHour: 22, startMinute: 0, endHour: 7, endMinute: 0)

        /// An empty window — nothing ever falls inside it — used when the user
        /// has quiet hours disabled in Settings.
        static let disabled = Window(startHour: 0, startMinute: 0, endHour: 0, endMinute: 0)

        static func from(settings: AppSettings, calendar: Calendar = .current) -> Window {
            guard settings.quietHoursEnabled else { return .disabled }
            let startComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursStart)
            let endComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursEnd)
            return Window(
                startHour: startComponents.hour ?? 22,
                startMinute: startComponents.minute ?? 0,
                endHour: endComponents.hour ?? 7,
                endMinute: endComponents.minute ?? 0
            )
        }
    }

    /// If `date` falls inside the (overnight) quiet window, returns the window's
    /// end time on the appropriate day instead. Otherwise returns `date` unchanged.
    static func adjust(_ date: Date, window: Window = .default, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return date }

        let minutesOfDay = hour * 60 + minute
        let startMinutes = window.startHour * 60 + window.startMinute
        let endMinutes = window.endHour * 60 + window.endMinute

        let isInWindow: Bool
        if startMinutes > endMinutes {
            // Overnight window (e.g. 10 PM–7 AM)
            isInWindow = minutesOfDay >= startMinutes || minutesOfDay < endMinutes
        } else {
            isInWindow = minutesOfDay >= startMinutes && minutesOfDay < endMinutes
        }

        guard isInWindow else { return date }

        var endComponents = components
        endComponents.hour = window.endHour
        endComponents.minute = window.endMinute

        var dayOffset = 0
        if minutesOfDay >= startMinutes {
            dayOffset = 1
        }

        guard
            let sameDayEnd = calendar.date(from: endComponents),
            let adjusted = calendar.date(byAdding: .day, value: dayOffset, to: sameDayEnd)
        else {
            return date
        }
        return adjusted
    }
}
