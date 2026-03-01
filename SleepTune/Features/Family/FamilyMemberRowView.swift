import SwiftUI

struct FamilyMemberRowView: View {
    let member: FamilyMember
    let score: DailySleepScore?

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.fromHex(member.avatarColor))
                    .frame(width: 44, height: 44)
                Text(String(member.displayName.prefix(1)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            // Name + duration
            VStack(alignment: .leading, spacing: 3) {
                Text(member.isCurrentUser ? "You" : member.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                if let score {
                    Text(sleepText(minutes: score.totalSleepMinutes))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                } else {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                }
            }

            Spacer()

            // Score
            if let score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(score.score.rounded()))")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.scoreColor(for: score.score))

                    Text(score.scoreLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.textTertiary)
                }
            } else {
                Text("—")
                    .font(.title2)
                    .foregroundStyle(DS.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(.vertical, 8)
    }

    private func sleepText(minutes: Int) -> String {
        "\(minutes / 60)h \(minutes % 60)m sleep"
    }
}
