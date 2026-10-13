import SwiftUI
import SwiftData

@main
struct NudgeAIApp: App {
    let modelContainer = PersistenceContainer.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
