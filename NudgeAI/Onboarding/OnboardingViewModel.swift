import Foundation
import AVFoundation
import os

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case connectClaude
    case teachSiri
    case permissions
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var apiKeyInput: String = ""
    @Published private(set) var isValidatingKey = false
    @Published private(set) var keyValidationError: String?

    private let apiKeyStore: APIKeyStore
    private let settingsRepository: SettingsRepository
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Onboarding")

    init(apiKeyStore: APIKeyStore, settingsRepository: SettingsRepository, startingStep: OnboardingStep = .welcome) {
        self.apiKeyStore = apiKeyStore
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

    /// Writes the key through the same Keychain-backed path Settings' API-key
    /// replace flow uses — Onboarding never implements its own Keychain write,
    /// per security-baseline.md.
    func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            keyValidationError = "Enter your Anthropic API key."
            return
        }

        do {
            try apiKeyStore.saveAPIKey(trimmed)
            keyValidationError = nil
            advance()
        } catch {
            keyValidationError = "Couldn't save the key. Try again."
            logger.error("Failed to save API key during onboarding")
        }
    }

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
