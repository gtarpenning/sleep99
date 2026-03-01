import SwiftUI

struct AppRootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        TabView {
            SleepDashboardView(viewModel: container.dashboardViewModel)
                .tabItem { Label("Sleep", systemImage: "moon.fill") }

            FamilyFeedView(viewModel: container.familyFeedViewModel)
                .tabItem { Label("Family", systemImage: "person.2.fill") }

            NavigationStack {
                SettingsView(viewModel: container.settingsViewModel)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(DS.purple)
        .colorScheme(.dark)
    }
}
