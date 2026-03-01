import SwiftUI

struct FamilyMemberDashboardView: View {
    let member: FamilyMember
    let score: DailySleepScore?

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if let score {
                        ReadOnlyScoreHeroView(score: score, member: member)
                            .padding(.top, 8)

                        SubScoreRow(
                            sleepScore: score.sleepScore,
                            recoveryScore: score.recoveryScore
                        )
                        .padding(.horizontal, 20)

                    } else {
                        ContentUnavailableView(
                            "\(member.displayName) hasn't shared today yet",
                            systemImage: "moon.zzz",
                            description: Text("Check back later")
                        )
                        .foregroundStyle(DS.textSecondary)
                    }

                    Color.clear.frame(height: 20)
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if let score {
                ToolbarItem(placement: .bottomBar) {
                    Text("via \(score.primarySource.displayName)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DS.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DS.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(DS.border, lineWidth: 0.5))
                }
            }
        }
    }
}

struct ReadOnlyScoreHeroView: View {
    let score: DailySleepScore
    let member: FamilyMember

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(Int(score.score.rounded()))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.scoreColor(for: score.score))

                Text(score.scoreLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.scoreColor(for: score.score).opacity(0.65))
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.fromHex(member.avatarColor))
                    .frame(width: 10, height: 10)
                Text(member.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
            }
        }
    }
}

struct SubScoreRow: View {
    let sleepScore: Double
    let recoveryScore: Double

    var body: some View {
        HStack(spacing: 1) {
            SubScoreTile(label: "Sleep", score: sleepScore, color: DS.sleepArc)
            Rectangle().fill(DS.border).frame(width: 0.5)
            SubScoreTile(label: "Recovery", score: recoveryScore, color: DS.recoveryArc)
        }
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DS.border, lineWidth: 0.5))
    }
}

struct SubScoreTile: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text("\(Int(score.rounded()))")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}
