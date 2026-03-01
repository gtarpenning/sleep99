import Foundation

struct FamilyMember: Identifiable, Hashable {
    let id: String
    var displayName: String
    var avatarColor: String
    var isCurrentUser: Bool

    static func placeholder(name: String, color: String) -> FamilyMember {
        FamilyMember(id: UUID().uuidString, displayName: name, avatarColor: color, isCurrentUser: false)
    }
}
