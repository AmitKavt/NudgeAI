import Foundation

@MainActor
final class LongHorizonViewModel: ObservableObject {
    @Published private(set) var nudgingSoon: [ReminderItem] = []
    @Published private(set) var later: [ReminderItem] = []

    private let reminderRepository: ReminderRepository
    private let leadTimeFirstDays: Int

    init(reminderRepository: ReminderRepository, leadTimeFirstDays: Int = 15) {
        self.reminderRepository = reminderRepository
        self.leadTimeFirstDays = leadTimeFirstDays
    }

    func load() {
        nudgingSoon = (try? reminderRepository.fetchLongHorizonNudgingSoon(leadTimeFirstDays: leadTimeFirstDays)) ?? []
        later = (try? reminderRepository.fetchLongHorizonLater(leadTimeFirstDays: leadTimeFirstDays)) ?? []
    }
}
