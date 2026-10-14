import Foundation
import os

/// The confidence threshold below which an item is routed to nightly review
/// instead of being auto-accepted. Hardcoded for now — not part of
/// AppSettings.md's field set, so there's no Settings UI slot for it yet.
let classificationConfidenceThreshold = 0.7

final class ClassificationCoordinator {
    private let client: ClassificationClient
    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let unreachableState: ClaudeUnreachableState
    private let notificationScheduler: NotificationScheduler
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Classification")

    init(
        client: ClassificationClient,
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        unreachableState: ClaudeUnreachableState,
        notificationScheduler: NotificationScheduler = UNNotificationScheduler()
    ) {
        self.client = client
        self.reminderRepository = reminderRepository
        self.settingsRepository = settingsRepository
        self.unreachableState = unreachableState
        self.notificationScheduler = notificationScheduler
    }

    /// Fire-and-forget: Capture calls this after its local write completes and never awaits it.
    func classify(itemId: UUID, rawText: String) {
        Task {
            do {
                let result = try await client.classify(rawText: rawText)
                let reviewedAt: Date? = result.confidence < classificationConfidenceThreshold ? nil : Date()

                try reminderRepository.applyClassification(
                    to: itemId,
                    bucket: result.bucket,
                    urgency: result.urgency,
                    deadline: result.deadline,
                    recurringInterval: result.recurringInterval,
                    customIntervalMonths: nil,
                    confidence: result.confidence,
                    reviewedAt: reviewedAt
                )
                await unreachableState.markReachable()
                logger.info("Classification completed")

                if result.bucket == .longHorizon, let deadline = result.deadline {
                    await LongHorizonNotificationScheduling.schedule(
                        itemId: itemId,
                        rawText: rawText,
                        deadline: deadline,
                        settingsRepository: settingsRepository,
                        notificationScheduler: notificationScheduler
                    )
                }
            } catch ClassificationError.requestFailed {
                await unreachableState.markUnreachable()
                logger.error("Classification request failed — marking Claude unreachable")
            } catch {
                logger.error("Classification failed to parse or apply")
            }
        }
    }

    /// Runs once per day: retries any item that never received a classification
    /// (e.g. Claude was unreachable at capture time), batched into a single call.
    func runNightlyDigest() async {
        let unclassified: [ReminderItem]
        do {
            unclassified = try reminderRepository.fetchUnclassifiedItems()
        } catch {
            logger.error("Nightly digest failed to fetch unclassified items")
            return
        }

        guard !unclassified.isEmpty else { return }

        let digestItems = unclassified.map { DigestItem(id: $0.id, rawText: $0.rawText) }
        let rawTextById = Dictionary(uniqueKeysWithValues: unclassified.map { ($0.id, $0.rawText) })

        do {
            let results = try await client.classifyDigest(items: digestItems)
            for (id, result) in results {
                let reviewedAt: Date? = result.confidence < classificationConfidenceThreshold ? nil : Date()
                try? reminderRepository.applyClassification(
                    to: id,
                    bucket: result.bucket,
                    urgency: result.urgency,
                    deadline: result.deadline,
                    recurringInterval: result.recurringInterval,
                    customIntervalMonths: nil,
                    confidence: result.confidence,
                    reviewedAt: reviewedAt
                )

                if result.bucket == .longHorizon, let deadline = result.deadline, let rawText = rawTextById[id] {
                    await LongHorizonNotificationScheduling.schedule(
                        itemId: id,
                        rawText: rawText,
                        deadline: deadline,
                        settingsRepository: settingsRepository,
                        notificationScheduler: notificationScheduler
                    )
                }
            }
            await unreachableState.markReachable()
            logger.info("Nightly digest completed")
        } catch ClassificationError.requestFailed {
            await unreachableState.markUnreachable()
            logger.error("Nightly digest request failed — marking Claude unreachable")
        } catch {
            logger.error("Nightly digest failed to parse")
        }

        let pendingCount = (try? reminderRepository.fetchNightlyReviewItems(
            confidenceThreshold: classificationConfidenceThreshold
        ).count) ?? 0
        let settings = try? settingsRepository.fetchSettings()
        let reviewTime = settings?.nightlyReviewTime
        let components = Calendar.current.dateComponents([.hour, .minute], from: reviewTime ?? Date())

        _ = await notificationScheduler.requestAuthorization()
        await notificationScheduler.scheduleNightlyReviewDigest(
            pendingCount: pendingCount,
            hour: components.hour ?? 21,
            minute: components.minute ?? 0
        )
    }
}
