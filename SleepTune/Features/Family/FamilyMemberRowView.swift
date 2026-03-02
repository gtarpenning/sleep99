import SwiftUI

struct FamilyMemberRowView: View {
    let member: FamilyMember
    let score: DailySleepScore?

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(member.avatarEmoji != nil ? DS.surface : Color.fromHex(member.avatarColor))
                    .frame(width: 44, height: 44)
                if let emoji = member.avatarEmoji {
                    Text(emoji)
                        .font(.system(size: 26))
                } else {
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(Circle().strokeBorder(DS.border, lineWidth: 0.5))

            // Name + device
            VStack(alignment: .leading, spacing: 3) {
                Text(member.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(deviceLabel)
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
            }
            .frame(minWidth: 60)

            Spacer(minLength: 0)

            // Chips: duration · sleep score · recovery score
            if let score {
                HStack(spacing: 6) {
                    ScoreChip(label: "Asleep", value: Double(score.totalSleepMinutes) / 60.0, text: sleepText(minutes: score.totalSleepMinutes), isHours: true, width: 44)
                    ScoreChip(label: "Sleep", value: score.sleepScore, text: nil, width: 36)
                    ScoreChip(label: "Recover", value: score.recoveryScore, text: nil, width: 36)
                }
            } else {
                Text("—")
                    .font(.title2)
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private var deviceLabel: String {
        guard let score else {
            return member.isCurrentUser ? "Open Sleep tab to sync" : "No data yet"
        }
        switch score.primarySource {
        case .appleWatch:  return "Apple Watch"
        case .oura:        return "Oura Ring"
        case .whoop:       return "Whoop"
        case .appleHealth: return "Apple Health"
        case .inferred:    return "Inferred"
        case .otherDevice: return "Other Device"
        }
    }

    private func sleepText(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}

// MARK: - Chip

private struct ScoreChip: View {
    let label: String
    let value: Double?   // score (0–100) or hours (0–24); nil = neutral
    let text: String?    // display override; nil = use Int(value)
    var isHours: Bool = false
    var width: CGFloat = 56

    var body: some View {
        let color = value.map(scoreColor) ?? DS.textSecondary

        VStack(spacing: 2) {
            Text(text ?? "\(Int((value ?? 0).rounded()))")
                .font(.system(size: text != nil ? 13 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(width: width, height: 44)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }

    private func scoreColor(_ v: Double) -> Color {
        if isHours {
            // Smooth hue sweep: 9h+ = green (120°), 5h = red (0°)
            let t = max(0, min(1, (v - 5) / 4))
            return Color(hue: t * 120 / 360, saturation: 0.85, brightness: 0.88)
        }
        return DS.scoreColor(for: v)
    }
}
