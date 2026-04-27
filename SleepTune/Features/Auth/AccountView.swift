import SwiftUI

struct AccountView: View {
    @Environment(AppContainer.self) private var container
    @State private var showSignOutConfirm = false
    @State private var nameText: String = ""

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            List {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(DS.purpleDim)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text(initials)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(DS.purple)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Your name", text: $nameText)
                                .font(.headline)
                                .foregroundStyle(DS.textPrimary)
                                .submitLabel(.done)
                                .onChange(of: nameText) { _, new in
                                    container.authService.updateDisplayName(new)
                                }
                            Text("Shown in Family feed")
                                .font(.caption)
                                .foregroundStyle(DS.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    sectionHeader("Account")
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Text("Sign Out")
                            .foregroundStyle(.red)
                    }
                }
                .listRowBackground(DS.surface)
                .listRowSeparatorTint(DS.border)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Account")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { nameText = container.authService.displayName ?? "" }
        .confirmationDialog("Sign out of sleeptune?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                container.authService.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your sleep data stays on this device. You can sign back in at any time.")
        }
    }

    private var initials: String {
        let name = container.authService.displayName ?? ""
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters.map { Character(String($0).uppercased()) })
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(DS.textTertiary)
            .textCase(.uppercase)
    }
}
