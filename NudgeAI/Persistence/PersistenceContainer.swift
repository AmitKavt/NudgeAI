import SwiftData

enum PersistenceContainer {
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([ReminderItem.self, AppSettings.self, SpendEstimate.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}
