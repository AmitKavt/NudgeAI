import Foundation
import os

/// The confidence threshold below which an item is routed to nightly review
/// instead of being auto-accepted. Hardcoded for now — not part of
/// AppSettings.md's field set, so there's no Settings UI slot for it yet.
let classificationConfidenceThreshold = 0.7

/// Single-flight guard so the backfill, Today retry and nightly digest never
/// classify the same unsorted items concurrently.
actor ClassificationGate {
    static let shared = ClassificationGate()
    private var isBusy = false

    func tryEnter() -> Bool {
        if isBusy { return false }
        isBusy = true
        return true
    }

    func leave() { isBusy = false }
}

final class ClassificationCoordinator {
    private let client: ClassificationClient
    private let reminderRepository: ReminderRepository
    private let settingsRepository: SettingsRepository
    private let unreachableState: ProviderUnreachableState
    private let notificationScheduler: NotificationScheduler
    private let gate: ClassificationGate
    private let logger = Logger(subsystem: "com.shwairatech.nudgeai", category: "Classification")

    init(
        client: ClassificationClient,
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        unreachableState: ProviderUnreachableState,
        notificationScheduler: NotificationScheduler = UNNotificationScheduler(),
        gate: ClassificationGate = .shared
    ) {
        self.gate = gate
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

                let applied = try reminderRepository.applyClassification(
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
                // Skipped (sorted by hand or already classified): no side effects.
                guard applied else { return }
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
                logger.error("Classification request failed — marking provider unreachable")
            } catch ClassificationError.authRejected {
                await unreachableState.markKeyRejected()
                logger.error("Classification key rejected by provider")
            } catch {
                logger.error("Classification failed to parse or apply")
            }
        }
    }

    /// Runs once per day: retries any item that never received a classification
    /// (e.g. the provider was unreachable at capture time), batched into a single call.
    func runNightlyDigest() async {
        _ = await classifyUnsorted()
        await NightlyReviewScheduling.refresh(
            reminderRepository: reminderRepository,
            settingsRepository: settingsRepository,
            notificationScheduler: notificationScheduler
        )
    }

    /// Classifies every never-sorted item (bucket == nil) in batches. Returns true
    /// when the provider was reachable (or nothing needed doing). Items that already
    /// have a bucket (manual or earlier provider) are never touched.
    func classifyUnsorted() async -> Bool {
        // Another run (backfill / retry / digest) is already working on these items.
        guard await gate.tryEnter() else { return false }
        let result = await runClassifyUnsorted()
        await gate.leave()
        return result
    }

    private func runClassifyUnsorted() async -> Bool {
        let unclassified: [ReminderItem]
        do {
            unclassified = try reminderRepository.fetchUnclassifiedItems()
        } catch {
            logger.error("Failed to fetch unsorted items")
            return false
        }
        guard !unclassified.isEmpty else { return true }

        let batchSize = 20
        var reachable = true
        var start = 0
        while start < unclassified.count && reachable {
            let batch = Array(unclassified[start..<min(start + batchSize, unclassified.count)])
            reachable = await classifyBatch(batch)
            start += batchSize
        }
        return reachable
    }

    private func classifyBatch(_ unclassified: [ReminderItem]) async -> Bool {
        let digestItems = unclassified.map { DigestItem(id: $0.id, rawText: $0.rawText) }
        let rawTextById = Dictionary(uniqueKeysWithValues: unclassified.map { ($0.id, $0.rawText) })

        do {
            let results = try await client.classifyDigest(items: digestItems)
            for (id, result) in results {
                let reviewedAt: Date? = result.confidence < classificationConfidenceThreshold ? nil : Date()
                let applied = (try? reminderRepository.applyClassification(
                    to: id,
                    bucket: result.bucket,
                    urgency: result.urgency,
                    deadline: result.deadline,
                    recurringInterval: result.recurringInterval,
                    customIntervalMonths: nil,
                    confidence: result.confidence,
                    reviewedAt: reviewedAt
                )) ?? false
                guard applied else { continue }

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
            logger.info("Batch classification completed")
            return true
        } catch ClassificationError.requestFailed {
            await unreachableState.markUnreachable()
            logger.error("Batch classification request failed — marking provider unreachable")
            return false
        } catch ClassificationError.authRejected {
            await unreachableState.markKeyRejected()
            logger.error("Batch classification key rejected by provider")
            return false
        } catch {
            logger.error("Batch classification failed to parse")
            return true
        }
    }
}

/// Keeps the nightly review notification's count in step with the queue, which
/// includes never-sorted items. The scheduler skips scheduling when the count is 0.
enum NightlyReviewScheduling {
    static func refresh(
        reminderRepository: ReminderRepository,
        settingsRepository: SettingsRepository,
        notificationScheduler: NotificationScheduler
    ) async {
        let pendingCount = (try? reminderRepository.fetchNightlyReviewItems(
            confidenceThreshold: classificationConfidenceThreshold
        ).count) ?? 0
        let reviewTime = (try? settingsRepository.fetchSettings())?.nightlyReviewTime
        let components = Calendar.current.dateComponents([.hour, .minute], from: reviewTime ?? Date())

        if pendingCount > 0 { _ = await notificationScheduler.requestAuthorization() }
        await notificationScheduler.scheduleNightlyReviewDigest(
            pendingCount: pendingCount,
            hour: components.hour ?? 21,
            minute: components.minute ?? 0
        )
    }
}
