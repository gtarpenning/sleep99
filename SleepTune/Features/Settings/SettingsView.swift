import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AppContainer.self) private var container
    @Environment(\.openURL) private var openURL
    @State private var showEmojiPicker = false
    @State private var notificationsEnabled = false
    @State private var resettingShare = false
    @State private var resetShareMessage: String? = nil

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

                Section {
                    Toggle("Daily reminder (10am)", isOn: $notificationsEnabled)
                        .tint(DS.purple)
                        .foregroundStyle(DS.textPrimary)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            Task {
                                let service = NotificationService()
                                if newValue {
                                    let granted = await service.enable()
                                    if !granted {
                                        notificationsEnabled = false
                                    }
                                } else {
                                    await service.disable()
                                }
                            }
                        }
                } header: {
                    Text("Notifications")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                } footer: {
                    Text("We'll remind you each morning to rate last night's sleep.")
                        .font(.caption2)
                        .foregroundStyle(DS.textTertiary)
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)

                Section {
                    Button {
                        Task {
                            resettingShare = true
                            resetShareMessage = nil
                            do {
                                try await container.cloudKitService.resetZoneShare()
                                resetShareMessage = "Share reset. Send a fresh invite link from the Family tab."
                            } catch {
                                resetShareMessage = "Couldn't reset: \(error.localizedDescription)"
                            }
                            resettingShare = false
                        }
                    } label: {
                        HStack {
                            Label("Reset Family Share", systemImage: "arrow.counterclockwise.circle")
                                .foregroundStyle(DS.textPrimary)
                            Spacer()
                            if resettingShare { ProgressView().tint(DS.textSecondary).scaleEffect(0.8) }
                        }
                    }
                    .disabled(resettingShare)
                } header: {
                    Text("Family")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                } footer: {
                    if let msg = resetShareMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(DS.textSecondary)
                    } else {
                        Text("If invite links aren't working, reset and send a fresh one.")
                            .font(.caption2)
                            .foregroundStyle(DS.textTertiary)
                    }
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .task {
            await viewModel.refreshHealthAuthorizationState()
            let service = NotificationService()
            let status = await service.currentAuthorizationStatus()
            notificationsEnabled = service.isEnabled && (status == .authorized || status == .provisional)
        }
        .navigationTitle("Settings")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showEmojiPicker) { EmojiPickerView() }
    }
}
