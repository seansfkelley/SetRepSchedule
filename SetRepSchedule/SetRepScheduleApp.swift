import SwiftUI
import SwiftData

@main
struct SetRepScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Plan.self, Exercise.self])
    }
}
