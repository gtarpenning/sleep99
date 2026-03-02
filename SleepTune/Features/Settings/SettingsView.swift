import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AppContainer.self) private var container
    @Environment(\.openURL) private var openURL
    @State private var showEmojiPicker = false

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: AccountView()) {
                        Label("Account", systemImage: "person.crop.circle")
                            .foregroundStyle(DS.textPrimary)
                    }
                    Button {
                        showEmojiPicker = true
                    } label: {
                        HStack {
                            Label("Profile Emoji", systemImage: "face.smiling")
                                .foregroundStyle(DS.textPrimary)
                            Spacer()
                            Text(container.authService.avatarEmoji ?? "None")
                                .foregroundStyle(DS.textSecondary)
                                .font(.body)
                        }
                    }
                } header: {
                    Text("Profile")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)

                Section {
                    HealthConnectionRowView(
                        title: viewModel.healthStatusTitle,
                        message: viewModel.healthStatusMessage,
                        statusIconName: viewModel.healthStatusIconName,
                        statusIconStyle: viewModel.healthStatusIconStyle,
                        showsConnectButton: viewModel.showsHealthConnectButton,
                        showsSettingsButton: viewModel.showsHealthSettingsButton,
                        connectAction: { Task { await viewModel.requestHealthAccess() } },
                        openSettingsAction: {
                            guard let url = viewModel.appSettingsURL else { return }
                            openURL(url)
                        }
                    )
                } header: {
                    Text("Health")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .task { await viewModel.refreshHealthAuthorizationState() }
        .navigationTitle("Settings")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showEmojiPicker) { EmojiPickerView() }
    }
}
