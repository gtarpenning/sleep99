import SwiftUI

struct FamilyMemberRowView: View {
    let member: FamilyMember
    let score: DailySleepScore?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            avatarView
                .frame(width: 34, alignment: .center)

            VStack(alignment: .leading, spacing: 5) {
                Text(member.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                if let score {
                    HStack(spacing: 5) {
                        ScoreChip(label: "Sleep",   value: score.sleepScore,    text: nil)
                        ScoreChip(label: "Recover", value: score.recoveryScore, text: nil)
                        ScoreChip(label: "Asleep",  value: Double(score.totalSleepMinutes) / 60.0, text: sleepText(minutes: score.totalSleepMinutes), isHours: true)
                        if let hr = score.avgHR {
                            ScoreChip(label: "HR",  value: hrScore(bpm: hr),  text: "\(hr)")
                        } else {
                            ScoreChip(label: "HR",  value: nil, text: "—")
                        }
                        if let hrv = score.avgHRV {
                            ScoreChip(label: "HRV", value: hrvScore(ms: hrv), text: "\(hrv)")
                        } else {
                            ScoreChip(label: "HRV", value: nil, text: "—")
                        }
                    }
                } else {
                    Text(member.isCurrentUser ? "Open Sleep tab to sync" : "Not checked in")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                }
            }
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let emoji = member.avatarEmoji {
            Text(emoji)
                .font(.system(size: 28))
        } else {
            Text(String(member.displayName.prefix(1)).uppercased())
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DS.textSecondary)
        }
    }

    private func sleepText(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }

    // Rough coloring: resting HR ≤55 = great, ≥75 = poor
    private func hrScore(bpm: Int) -> Double {
        let v = Double(bpm)
        if v <= 55 { return 90 }
        if v >= 75 { return 30 }
        return 90 - (v - 55) / 20 * 60
    }

    // Rough coloring: HRV ≥60ms = great, ≤20ms = poor
    private func hrvScore(ms: Int) -> Double {
        let v = Double(ms)
        if v >= 60 { return 90 }
        if v <= 20 { return 30 }
        return 30 + (v - 20) / 40 * 60
    }
}

// MARK: - Chip

private struct ScoreChip: View {
    let label: String
    let value: Double?
    let text: String?
    var isHours: Bool = false

    var body: some View {
        let color = value.map(scoreColor) ?? DS.textSecondary

        VStack(spacing: 2) {
            Text(text ?? "\(Int((value ?? 0).rounded()))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }

    private func scoreColor(_ v: Double) -> Color {
        if isHours {
            let t = max(0, min(1, (v - 5) / 4))
            return Color(hue: t * 120 / 360, saturation: 0.85, brightness: 0.88)
        }
        return DS.scoreColor(for: v)
    }
}
