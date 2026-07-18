import SwiftData
import SwiftUI

@main
struct SippedApp: App {
    private let environment = AppEnvironment.live
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            DrinkDefinition.self,
            ContainerDefinition.self,
            UserPreferences.self,
            DrinkUsagePreference.self,
            DrinkLog.self
        ])
        let inMemory = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Sipped store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
        .modelContainer(modelContainer)
    }
}
