import SwiftUI

@main
struct SleepTuneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    #if DEBUG
    @State private var container: AppContainer = ProcessInfo.processInfo.arguments.contains("-mockData")
        ? .mock()
        : AppContainer()
    #else
    @State private var container = AppContainer()
    #endif

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environment(container)
                .task {
                    #if DEBUG
                    if !ProcessInfo.processInfo.arguments.contains("-mockData") {
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
