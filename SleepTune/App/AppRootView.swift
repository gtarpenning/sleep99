import SwiftUI

struct AppRootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        NavigationStack {
            DashboardView(viewModel: container.dashboardViewModel)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: SettingsDestination.settings) {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .navigationDestination(for: SettingsDestination.self) { destination in
                    switch destination {
                    case .settings:
                        SettingsView(viewModel: container.settingsViewModel)
                    case .tunedWeights:
                        TunedWeightsView(viewModel: container.settingsViewModel)
                    }
                }
        }
        .task {
            container.scheduleBackgroundSync()
        }
    }
}
