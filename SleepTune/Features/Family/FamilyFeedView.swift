import SwiftUI
import CloudKit

struct FamilyFeedView: View {
    @Bindable var viewModel: FamilyFeedViewModel
    @State private var showCloudSharing = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                List {
                    ForEach(sortedMembers) { member in
                        FamilyMemberRowView(
                            member: member,
                            score: viewModel.score(for: member)
                        )
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
                        Task { await prepareAndShare() }
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(DS.purple)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showCloudSharing) {
                if let (share, container) = viewModel.pendingShare {
                    CloudSharingView(share: share, container: container)
                        .ignoresSafeArea()
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

    private func prepareAndShare() async {
        await viewModel.prepareShare()
        if viewModel.pendingShare != nil {
            showCloudSharing = true
        }
    }
}

// MARK: - UICloudSharingController wrapper

private struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadOnly, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("[CloudSharing] failed: \(error)")
        }
        func itemTitle(for csc: UICloudSharingController) -> String? { "My Sleep Score" }
    }
}
