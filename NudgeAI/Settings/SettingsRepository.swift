import Foundation
import SwiftData

protocol SettingsRepository {
    func fetchSettings() throws -> AppSettings

    /// Fetches (creating defaults if needed), applies `mutate`, then saves —
    /// the one write path for AppSettings, so no module ever touches
    /// ModelContext/UserDefaults directly per data-conventions.md.
    func update(_ mutate: (AppSettings) -> Void) throws
}

extension SettingsRepository {
    /// Live confidence threshold below which an item goes to nightly review.
    var confidenceThreshold: Double {
        (try? fetchSettings().confidenceThreshold) ?? classificationConfidenceThreshold
    }
}

final class SwiftDataSettingsRepository: SettingsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSettings() throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let defaults = AppSettings()
        modelContext.insert(defaults)
        try modelContext.save()
        return defaults
    }

    func update(_ mutate: (AppSettings) -> Void) throws {
        let settings = try fetchSettings()
        mutate(settings)
        try modelContext.save()
    }
}
