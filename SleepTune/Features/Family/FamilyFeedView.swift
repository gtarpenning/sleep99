import SwiftUI
import CloudKit
import UIKit

struct FamilyFeedView: View {
    @Bindable var viewModel: FamilyFeedViewModel
    @State private var showInviteSheet = false

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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !member.isCurrentUser {
                                Button(role: .destructive) {
                                    viewModel.removeMember(member)
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
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
                        shareTapped()
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(DS.purple)
                    }
                }
            }
            .task { await viewModel.refresh() }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showInviteSheet) {
                InviteSheet(makeShare: { try await viewModel.makeShare() })
            }
            .alert("Could not share", isPresented: .init(
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

    private func shareTapped() {
        guard viewModel.canShareOrSetError() else { return }
        showInviteSheet = true
    }
}

// MARK: - Custom Invite Sheet

/// Dark-themed invite sheet. Prepares a CKShare and presents UICloudSharingController,
/// allowing CloudKit to generate and distribute the invite.
private struct InviteSheet: View {
    let makeShare: () async throws -> (CKShare, CKContainer)
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var pendingShare: WrappedShare? = nil  // non-nil triggers the share controller

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(DS.border)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 32)

                Spacer()

                // Icon + headline
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(DS.purpleDim)
                            .frame(width: 72, height: 72)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(DS.purple)
                    }

                    VStack(spacing: 8) {
                        Text("Invite a Friend")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                        Text("Share a link so a friend can see your sleep scores in their Family tab.")
                            .font(.subheadline)
                            .foregroundStyle(DS.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // Action area
                VStack(spacing: 16) {
                    if let msg = errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .padding(.top, 1)
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(DS.textSecondary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(14)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.border, lineWidth: 0.5))
                    }

                    Button {
                        Task { await fetchAndShare() }
                    } label: {
                        ZStack {
                            if isLoading {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Creating link…")
                                        .fontWeight(.semibold)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "message.fill")
                                    Text(errorMessage != nil ? "Try Again" : "Share via iMessage")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.purple, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .colorScheme(.dark)
        .presentationDetents([.medium])
        .presentationBackground(DS.bg)
        .sheet(item: $pendingShare, onDismiss: { dismiss() }) { wrapped in
            CloudSharingView(
                share: wrapped.share,
                container: wrapped.container,
                onSaveError: { message in errorMessage = message }
            )
        }
    }

    @MainActor
    private func fetchAndShare() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (share, container) = try await makeShare()
            pendingShare = WrappedShare(share: share, container: container)
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "Sign in to iCloud in Settings → [your name] → iCloud to share sleep scores."
            case .networkUnavailable, .networkFailure:
                return "No internet connection. Check your network and try again."
            case .quotaExceeded:
                return "iCloud storage is full. Free up space and try again."
            case .permissionFailure:
                return "iCloud permission denied. Check Settings → Privacy → iCloud."
            default:
                return "CloudKit error \(ckError.code.rawValue): \(ckError.localizedDescription)"
            }
        }
        if let shareError = error as? ShareError {
            return shareError.errorDescription ?? error.localizedDescription
        }
        // Simulator-specific: CloudKit is unavailable without a signed-in iCloud account.
        let desc = error.localizedDescription
        if desc.contains("iCloud") || desc.contains("CloudKit") || desc.contains("account") {
            return "iCloud is not available. Sign in to iCloud in Settings, or test on a real device."
        }
        return desc
    }
}

// MARK: - Helpers

private struct WrappedShare: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

private struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onSaveError: (String) -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadOnly, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSaveError: onSaveError)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let onSaveError: (String) -> Void

        init(onSaveError: @escaping (String) -> Void) {
            self.onSaveError = onSaveError
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "My Sleep Score"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
            onSaveError(error.localizedDescription)
        }
    }
}
