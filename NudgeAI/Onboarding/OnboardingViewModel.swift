import Foundation
import AVFoundation
import os

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case signIn
    case choosePlatform
    case teachSiri
    case permissions

    static var total: Int { allCases.count }
    /// 1-based position, shown as "N of 5" (Welcome has no header).
    var position: Int { rawValue + 1 }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: OnboardingStep
    @Published private(set) var signedInWithApple = false
    @Published private(set) var signInNote: String?
    let connect: PlatformConnectModel

    private let settingsRepository: SettingsRepository
    let identity: AppleIdentityManager
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Onboarding")

    init(
        connectService: ProviderConnectionService,
        identity: AppleIdentityManager,
        settingsRepository: SettingsRepository,
        startingStep: OnboardingStep = .welcome
    ) {
        self.connect = PlatformConnectModel(service: connectService)
        self.identity = identity
        self.settingsRepository = settingsRepository
        self.step = startingStep
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            complete()
            return
        }
        step = next
    }

    func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Declined or failed sign-in continues with a local-only profile.
    func appleSignInFinished(success: Bool) {
        signedInWithApple = success
        if !success { signInNote = "Continuing without Sign in with Apple. You can sign in later from You." }
        advance()
    }

    func skipSignIn() { advance() }

    func connectAndContinue() async {
        if await connect.connect() { advance() }
    }

    /// Leaves the provider as none; the app works with manual sorting.
    func skipPlatform() { advance() }

    func requestPermissionsAndComplete() async {
        _ = await UNNotificationScheduler().requestAuthorization()
        _ = await SpeechTranscriptionService().requestAuthorization()
        _ = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        complete()
    }

    private func complete() {
        try? settingsRepository.update { $0.onboardingCompleted = true }
    }
}
