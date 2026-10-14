import Foundation
import SwiftData

enum ClaudeModel: String, Codable {
    case haiku
    case sonnet
}

enum AmbiguousTranscriptionPolicy: String, Codable {
    case saveAndFlag
    case dontSave
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var selectedModel: ClaudeModel

    var siriPhrase: String
    var confirmWithHaptic: Bool
    var confirmWithSpokenWord: Bool
    var language: String
    var unsureTranscriptionPolicy: AmbiguousTranscriptionPolicy
    var nightlyReviewTime: Date
    var skipReviewWhenEmpty: Bool
    var leadTimeFirstDays: Int
    var leadTimeSecondDays: Int
    var dueDateCheckInEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: Date
    var quietHoursEnd: Date
    var monthlySpendAlertThreshold: Double
    var onboardingCompleted: Bool

    init(
        id: UUID = UUID(),
        selectedModel: ClaudeModel = .haiku,
        siriPhrase: String = "Hey Siri, nudge me",
        confirmWithHaptic: Bool = true,
        confirmWithSpokenWord: Bool = false,
        language: String = Locale.current.identifier,
        unsureTranscriptionPolicy: AmbiguousTranscriptionPolicy = .saveAndFlag,
        nightlyReviewTime: Date = AppSettings.defaultTimeOfDay(hour: 21, minute: 0),
        skipReviewWhenEmpty: Bool = true,
        leadTimeFirstDays: Int = 15,
        leadTimeSecondDays: Int = 5,
        dueDateCheckInEnabled: Bool = true,
        quietHoursEnabled: Bool = true,
        quietHoursStart: Date = AppSettings.defaultTimeOfDay(hour: 22, minute: 0),
        quietHoursEnd: Date = AppSettings.defaultTimeOfDay(hour: 7, minute: 0),
        monthlySpendAlertThreshold: Double = 5.0,
        onboardingCompleted: Bool = false
    ) {
        self.id = id
        self.selectedModel = selectedModel
        self.siriPhrase = siriPhrase
        self.confirmWithHaptic = confirmWithHaptic
        self.confirmWithSpokenWord = confirmWithSpokenWord
        self.language = language
        self.unsureTranscriptionPolicy = unsureTranscriptionPolicy
        self.nightlyReviewTime = nightlyReviewTime
        self.skipReviewWhenEmpty = skipReviewWhenEmpty
        self.leadTimeFirstDays = leadTimeFirstDays
        self.leadTimeSecondDays = leadTimeSecondDays
        self.dueDateCheckInEnabled = dueDateCheckInEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.monthlySpendAlertThreshold = monthlySpendAlertThreshold
        self.onboardingCompleted = onboardingCompleted
    }

    private static func defaultTimeOfDay(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}
