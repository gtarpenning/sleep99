import SwiftUI

struct SettingsView: View {
    @State private var weekdayBaseline = ScoringBaselineSetting.weekdayOnly
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
                    Toggle("Weekday-only baseline", isOn: $weekdayBaseline)
                        .tint(DS.purple)
                        .foregroundStyle(DS.textPrimary)
                        .onChange(of: weekdayBaseline) { _, newValue in
                            ScoringBaselineSetting.weekdayOnly = newValue
                            Task { await container.dashboardViewModel.reloadBaselines() }
                        }
                } header: {
                    Text("Scoring")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                } footer: {
                    Text("Judge each night against your weekday (Sun–Thu night) averages instead of all nights, so weekends don't drag your targets down.")
                        .font(.caption2)
                        .foregroundStyle(DS.textTertiary)
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)

                Section {
                    HistoryBackfillRow(backfill: container.historyBackfill)
                } header: {
                    Text("History")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                } footer: {
                    Text("SleepTune keeps up to a year of nightly summaries on this device for trends and correlations. Rebuild if numbers look wrong.")
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

// MARK: - History backfill row

private struct HistoryBackfillRow: View {
    let backfill: HistoryBackfill
    @State private var confirming = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("Sleep history", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(DS.textPrimary)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer()
            switch backfill.state {
            case .running:
                ProgressView().tint(DS.textSecondary).scaleEffect(0.8)
            default:
                Button("Rebuild") { confirming = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.purple)
            }
        }
        .confirmationDialog("Rebuild sleep history?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Rebuild from Health", role: .destructive) {
                Task { await backfill.rebuild() }
            }
        } message: {
            Text("Re-imports up to a year of nights from Apple Health. Takes a few minutes in the background.")
        }
    }

    private var statusText: String {
        switch backfill.state {
        case .idle:
            return backfill.isComplete ? "Up to date" : "Waiting to import"
        case .running(let done, let total):
            return "Importing… \(done) of ~\(total) nights"
        case .complete(let n):
            return "\(n) nights imported"
        }
    }
}
