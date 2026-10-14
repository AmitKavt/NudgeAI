import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasCompletedOnboarding: Bool?

    var body: some View {
        Group {
            if hasCompletedOnboarding == true {
                MainTabView()
            } else if hasCompletedOnboarding == false {
                OnboardingFlowView(
                    apiKeyStore: KeychainAPIKeyStore(),
                    settingsRepository: SwiftDataSettingsRepository(modelContext: modelContext),
                    onComplete: { hasCompletedOnboarding = true }
                )
            } else {
                ProgressView()
                    .tint(Theme.accent)
            }
        }
        .background(Theme.bg)
        .onAppear {
            let settings = try? SwiftDataSettingsRepository(modelContext: modelContext).fetchSettings()
            hasCompletedOnboarding = settings?.onboardingCompleted ?? false
        }
    }
}

private struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .today
    @State private var isPresentingCapture = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch selection {
                case .today:
                    TodayView(onStartReview: { selection = .review })
                case .review:
                    ReviewScreen()
                case .horizon:
                    LongHorizonTabView(viewModel: LongHorizonViewModel(
                        reminderRepository: SwiftDataReminderRepository(modelContext: modelContext)
                    ))
                case .you:
                    ProfileView()
                }
            }
            .padding(.bottom, 90)

            VStack {
                Spacer()
                TabBar(selection: $selection) { isPresentingCapture = true }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $isPresentingCapture) {
            let reminderRepository = SwiftDataReminderRepository(modelContext: modelContext)
            let settingsRepository = SwiftDataSettingsRepository(modelContext: modelContext)
            CaptureSheet(
                viewModel: CaptureViewModel(
                    reminderRepository: reminderRepository,
                    settingsRepository: settingsRepository,
                    transcriptionService: SpeechTranscriptionService()
                ),
                client: AnthropicClassificationClient(
                    apiKeyStore: KeychainAPIKeyStore(),
                    settingsRepository: settingsRepository,
                    spendEstimateRepository: SwiftDataSpendEstimateRepository(modelContext: modelContext)
                ),
                reminderRepository: reminderRepository,
                settingsRepository: settingsRepository
            )
        }
    }
}

#Preview {
    ContentView()
}
