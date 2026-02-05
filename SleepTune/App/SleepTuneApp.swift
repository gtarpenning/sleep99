import SwiftUI

@main
struct SleepTuneApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .environment(container)
        .backgroundTask(.appRefresh(AnalyticsConfiguration.backgroundTaskIdentifier)) {
            await container.handleBackgroundRefresh()
        }
    }
}
