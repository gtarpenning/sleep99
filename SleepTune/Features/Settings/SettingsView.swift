import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section("Health") {
                HealthConnectionRowView(
                    title: viewModel.healthStatusTitle,
                    message: viewModel.healthStatusMessage,
                    statusIconName: viewModel.healthStatusIconName,
                    statusIconStyle: viewModel.healthStatusIconStyle,
                    showsConnectButton: viewModel.showsHealthConnectButton,
                    showsSettingsButton: viewModel.showsHealthSettingsButton,
                    connectAction: {
                        Task {
                            await viewModel.requestHealthAccess()
                        }
                    },
                    openSettingsAction: {
                        guard let url = viewModel.appSettingsURL else { return }
                        openURL(url)
                    }
                )
            }

            Section("Account") {
                LabeledContent("Status", value: viewModel.accountStatusText)

                if viewModel.isSignedIn {
                    Button("Log Out", systemImage: "person.crop.circle.badge.minus") {
                        viewModel.logOut()
                    }
                } else {
                    Button("Log In", systemImage: "person.crop.circle.badge.plus") {
                        viewModel.logIn()
                    }
                }
            }

            Section("Appearance") {
                Toggle("Reduce Motion", isOn: $viewModel.isReduceMotionEnabled)
                Toggle("High Contrast", isOn: $viewModel.isHighContrastEnabled)
                Toggle("Compact Layout", isOn: $viewModel.isCompactLayoutEnabled)
            }
            .disabled(true)

            Section("Sleep Score") {
                NavigationLink(value: SettingsDestination.tunedWeights) {
                    Text("View Tuned Weights")
                }
            }
        }
        .task {
            await viewModel.refreshHealthAuthorizationState()
        }
        .navigationTitle("Settings")
    }
}
