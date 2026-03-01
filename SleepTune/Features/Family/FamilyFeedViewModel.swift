import Foundation
import Observation

@MainActor
@Observable
final class FamilyFeedViewModel {
    var members: [FamilyMember] = []
    var scores: [String: DailySleepScore] = [:]
    var selectedDate: Date = Date()
    var isLoading: Bool = false
    var shareURL: URL?
    var shareError: String?

    private let authService: AuthService
    private let cloudKitService: CloudKitService

    init(authService: AuthService, cloudKitService: CloudKitService) {
        self.authService = authService
        self.cloudKitService = cloudKitService

        let myID = authService.userID ?? "me"
        let myName = authService.displayName ?? "You"
        members = [FamilyMember(id: myID, displayName: myName, avatarColor: "#5E5CE6", isCurrentUser: true)]
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let pairs = try await cloudKitService.fetchGroupData()
            let myID = authService.userID ?? "me"
            let myName = authService.displayName ?? "You"

            var newMembers: [FamilyMember] = [
                FamilyMember(id: myID, displayName: myName, avatarColor: "#5E5CE6", isCurrentUser: true)
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
        scores[member.id]
    }

    func generateInviteLink() async {
        guard let userID = authService.userID else { return }
        do {
            guard let recordID = try await cloudKitService.todayRecordID(for: userID) else { return }
            shareURL = try await cloudKitService.shareScore(recordID: recordID)
        } catch {
            shareError = error.localizedDescription
        }
    }
}
