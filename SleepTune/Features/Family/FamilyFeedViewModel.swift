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
    /// Set before presenting UICloudSharingController
    var pendingShare: (CKShare, CKContainer)?

    private let authService: AuthService
    private let cloudKitService: CloudKitService

    init(authService: AuthService, cloudKitService: CloudKitService) {
        self.authService = authService
        self.cloudKitService = cloudKitService

        let myID = authService.userID ?? "me"
        let myName = authService.displayName ?? "You"
        members = [FamilyMember(id: myID, displayName: myName, avatarColor: "#5E5CE6", avatarEmoji: authService.avatarEmoji, isCurrentUser: true)]
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

    func prepareShare() async {
        guard let userID = authService.userID else {
            shareError = "Sign in with Apple to create an invite."
            return
        }
        guard let score = currentUserScore else {
            shareError = "Open the Sleep tab and let your score load first, then try again."
            return
        }
        do {
            pendingShare = try await cloudKitService.prepareShare(
                score.toSummary(),
                totalMinutes: score.totalSleepMinutes,
                userID: userID,
                displayName: authService.displayName ?? "Me",
                avatarColor: "#5E5CE6",
                avatarEmoji: authService.avatarEmoji
            )
        } catch {
            shareError = error.localizedDescription
        }
    }
}
