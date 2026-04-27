import SwiftUI

@main
struct SleepTuneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    #if DEBUG
    // Debug builds use mock data by default. Add "-realData" as a launch argument to test real HealthKit.
    @State private var container: AppContainer = ProcessInfo.processInfo.arguments.contains("-realData")
        ? AppContainer()
        : .mock()
    #else
    @State private var container = AppContainer()
    #endif

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environment(container)
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-realData") {
                        await container.authService.restoreSession()
                    }
                    #else
                    await container.authService.restoreSession()
                    #endif
                }
        }
    }
}

private struct RootGateView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        if container.authService.isSignedIn {
            AppRootView()
        } else {
            SignInView()
        }
    }
}
