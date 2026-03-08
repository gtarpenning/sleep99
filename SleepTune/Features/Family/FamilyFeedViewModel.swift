import Foundation
import Observation
import CloudKit

@MainActor
@Observable
final class FamilyFeedViewModel {
    var members: [FamilyMember] = []
    var scores: [String: DailySleepScore] = [:]
    var currentUserScore: DailySleepScore?   // set from AppRootView whenever dashboard updates
    var selectedDate: Date = Date()
    var isLoading: Bool = false
    var shareError: String?

    private let authService: AuthService
    private let cloudKitService: CloudKitService

    init(authService: AuthService, cloudKitService: CloudKitService) {
        self.authService = authService
        self.cloudKitService = cloudKitService

        let myID = authService.userID ?? "me"
        let myName = authService.displayName ?? "You"
        members = [FamilyMember(id: myID, displayName: myName, avatarColor: "#5E5CE6", avatarEmoji: authService.avatarEmoji, isCurrentUser: true)]

        // Refresh family feed whenever a share is accepted (e.g. tapping a link in iMessage).
        Task { @MainActor [weak self] in
            let stream = NotificationCenter.default.notifications(named: .cloudKitShareAccepted)
            for await _ in stream {
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let pairs = try await cloudKitService.fetchGroupData()
            let myID = authService.userID ?? "me"
            let myName = authService.displayName ?? "You"

            var newMembers: [FamilyMember] = [
                FamilyMember(id: myID, displayName: myName, avatarColor: "#5E5CE6", avatarEmoji: authService.avatarEmoji, isCurrentUser: true)
            ]
            var newScores: [String: DailySleepScore] = [:]

            for (member, score) in pairs where member.id != myID {
                newMembers.append(member)
                newScores[score.memberID] = score
            }

            members = newMembers
            scores = newScores
        } catch {
            // Silently fail — stub data remains
        }
    }

    func score(for member: FamilyMember) -> DailySleepScore? {
        member.isCurrentUser ? currentUserScore : scores[member.id]
    }

    /// Returns (CKShare, CKContainer) for use inside UICloudSharingController's preparation handler.
    /// Called only after the user picks a share method — network latency is hidden by composition time.
    func makeShare() async throws -> (CKShare, CKContainer) {
        guard authService.isSignedIn, let userID = authService.userID else {
            throw ShareError.notSignedIn
        }
        guard let score = currentUserScore else {
            throw ShareError.noScore
        }
        return try await cloudKitService.prepareShare(
            score.toSummary(),
            totalMinutes: score.totalSleepMinutes,
            userID: userID,
            displayName: authService.displayName ?? "Me",
            avatarColor: "#5E5CE6",
            avatarEmoji: authService.avatarEmoji
        )
    }

    /// Checks prerequisites before showing the share sheet. Sets shareError and returns false if unmet.
    func canShareOrSetError() -> Bool {
        if !authService.isSignedIn {
            shareError = "Sign in with Apple to share your score."
            return false
        }
        if currentUserScore == nil {
            shareError = "Open the Sleep tab and let your score load first."
            return false
        }
        return true
    }
}

enum ShareError: LocalizedError {
    case notSignedIn
    case noScore

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in with Apple to share your score."
        case .noScore:     return "Open the Sleep tab and let your score load first."
        }
    }
}
