import SwiftUI

/// Compact card summarizing the user's rolling 7-night sleep debt.
/// Debt = hours behind an 8h target, inflated slightly by hard-training nights.
struct SleepDebtCardView: View {
    let summary: SleepDebtSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSSectionHeader(title: "Sleep Debt")
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                // Headline debt figure
                VStack(alignment: .leading, spacing: 2) {
                    Text(SleepDebt.summaryText(for: summary))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(severityColor)
                        .monospacedDigit()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                }

                Spacer(minLength: 0)

                // Supporting stats
                HStack(spacing: 16) {
                    stat(value: String(format: "%.1f", summary.avgHours), unit: "h avg")
                    stat(value: "\(summary.nightsAtOrAboveTarget)/\(summary.nightsCounted)", unit: "on target")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .dsCard(16)
            .padding(.horizontal, 20)
        }
    }

    private func stat(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
    }

    private var subtitle: String {
        switch summary.severity {
        case .none:     return "You're well rested"
        case .mild:     return "Slightly behind over 7 nights"
        case .moderate: return "Building up over 7 nights"
        case .high:     return "Significant deficit — prioritize sleep"
        }
    }

    private var severityColor: Color {
        switch summary.severity {
        case .none:     return DS.green
        case .mild:     return Color(red: 0.95, green: 0.77, blue: 0.06)
        case .moderate: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .high:     return .red.opacity(0.9)
        }
    }
}
