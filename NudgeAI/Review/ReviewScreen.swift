import SwiftUI
import SwiftData

struct ReviewScreen: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ReviewCardStack(viewModel: ReviewViewModel(
            reminderRepository: SwiftDataReminderRepository(modelContext: modelContext),
            settingsRepository: SwiftDataSettingsRepository(modelContext: modelContext)
        ))
        .background(Theme.bg)
    }
}
