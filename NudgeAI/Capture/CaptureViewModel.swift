import Foundation
import SwiftUI
import os
import AVFoundation

/// Below this on-device Speech confidence, the "Don't save" ambiguous-transcription
/// policy discards the capture instead of persisting it. Not part of AppSettings.md's
/// field set — only the policy choice itself is user-configurable, not this cutoff.
let transcriptionConfidenceThreshold = 0.5

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var draftText: String = ""
    @Published private(set) var isRecording = false
    @Published private(set) var capturedItem: ReminderItem?
    @Published private(set) var wasDiscardedByPolicy = false
    /// Plain-language reason voice input did not work; nil when it did.
    @Published private(set) var voiceError: String?

    private var lastTranscriptionConfidence: Double?

    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let transcriptionService: TranscriptionService
    private let audioRecorder: AudioRecorder
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Capture")

    init(
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        transcriptionService: TranscriptionService,
        audioRecorder: AudioRecorder = AudioRecorder()
    ) {
        self.reminderRepository = reminderRepository
        self.settingsRepository = settingsRepository
        self.transcriptionService = transcriptionService
        self.audioRecorder = audioRecorder
    }

    func startVoiceInput() async {
        guard !isRecording else { return }
        voiceError = nil
        guard await Self.requestMicrophoneAccess() else {
            logger.error("Microphone access denied")
            voiceError = "Microphone is off for NudgeAI. Turn it on in Settings, or type instead."
            return
        }
        guard await transcriptionService.requestAuthorization() else {
            logger.error("Speech authorization denied")
            voiceError = "Speech recognition is off for NudgeAI. Turn it on in Settings, or type instead."
            return
        }

        do {
            _ = try audioRecorder.startRecording()
            isRecording = true
        } catch {
            logger.error("Failed to start audio recording")
            voiceError = "Couldn't start the microphone. Try again, or type instead."
        }
    }

    func stopVoiceInput() async {
        guard isRecording else { return }
        isRecording = false
        guard let url = audioRecorder.stopRecording() else { return }

        do {
            let result = try await transcriptionService.transcribeAudioFile(at: url)
            draftText = result.text
            lastTranscriptionConfidence = result.confidence
        } catch TranscriptionError.onDeviceUnavailable {
            logger.error("In-app transcription unavailable on device")
            voiceError = "On-device speech isn't available here (the Simulator often lacks it). Type instead."
        } catch TranscriptionError.emptyTranscript {
            voiceError = "Didn't catch that. Try again, or type instead."
        } catch {
            logger.error("In-app transcription failed")
            voiceError = "Couldn't turn that into text. Try again, or type instead."
        }
    }

    private static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Writes the raw item to Persistence immediately, before any classification
    /// or follow-up call — same zero-delay rule as Siri capture. Honors the
    /// ambiguous-transcription policy for low-confidence voice captures;
    /// typed text has no transcription confidence and is never discarded.
    func submitDraft() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let confidence = lastTranscriptionConfidence
        let policy = (try? settingsRepository.fetchSettings())?.unsureTranscriptionPolicy ?? .saveAndFlag
        if let confidence, confidence < transcriptionConfidenceThreshold, policy == .dontSave {
            wasDiscardedByPolicy = true
            logger.info("Discarded low-confidence in-app capture per Settings policy")
            return
        }

        do {
            capturedItem = try reminderRepository.createReminder(
                rawText: draftText,
                createdAt: Date(),
                source: .inApp,
                transcriptionConfidence: confidence
            )
            logger.info("Captured nudge via in-app text/voice entry")
        } catch {
            logger.error("Failed to persist in-app captured nudge")
        }
    }
}
