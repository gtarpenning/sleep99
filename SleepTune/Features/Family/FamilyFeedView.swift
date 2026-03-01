import SwiftUI

struct FamilyFeedView: View {
    @Bindable var viewModel: FamilyFeedViewModel
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                List {
                    ForEach(sortedMembers) { member in
                        NavigationLink {
                            FamilyMemberDashboardView(
                                member: member,
                                score: viewModel.score(for: member)
                            )
                        } label: {
                            FamilyMemberRowView(
                                member: member,
                                score: viewModel.score(for: member)
                            )
                        }
                        .listRowBackground(DS.surface)
                        .listRowSeparatorTint(DS.border)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Family")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await generateInvite() }
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(DS.purple)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = viewModel.shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Could not create invite", isPresented: .init(
                get: { viewModel.shareError != nil },
                set: { if !$0 { viewModel.shareError = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.shareError = nil }
            } message: {
                if let msg = viewModel.shareError { Text(msg) }
            }
        }
    }

    private var sortedMembers: [FamilyMember] {
        viewModel.members.sorted { a, b in
            if a.isCurrentUser { return true }
            if b.isCurrentUser { return false }
            return (viewModel.score(for: a)?.score ?? 0) > (viewModel.score(for: b)?.score ?? 0)
        }
    }

    private func generateInvite() async {
        await viewModel.generateInviteLink()
        if viewModel.shareURL != nil {
            showShareSheet = true
        }
    }
}

// MARK: - UIActivityViewController wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
