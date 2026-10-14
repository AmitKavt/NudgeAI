import Foundation
import Speech
import os

enum TranscriptionError: Error {
    case authorizationDenied
    case recognizerUnavailable
}

struct TranscriptionResult {
    let text: String
    let confidence: Double
}

protocol TranscriptionService {
    func requestAuthorization() async -> Bool
    func transcribeAudioFile(at url: URL) async throws -> TranscriptionResult
}

final class SpeechTranscriptionService: TranscriptionService {
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Capture")
    private let locale: Locale

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribeAudioFile(at url: URL) async throws -> TranscriptionResult {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            logger.error("Speech recognizer unavailable")
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }

                let confidence = Self.averageConfidence(for: result)
                continuation.resume(
                    returning: TranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: confidence
                    )
                )
            }
        }
    }

    private static func averageConfidence(for result: SFSpeechRecognitionResult) -> Double {
        let segments = result.bestTranscription.segments
        guard !segments.isEmpty else { return 0 }
        let total = segments.reduce(0.0) { $0 + Double($1.confidence) }
        return total / Double(segments.count)
    }
}
