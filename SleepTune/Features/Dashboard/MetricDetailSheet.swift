import SwiftUI

struct MetricDetailSheet: View {
    let metric: MetricContribution
    @State private var selectedDetent: PresentationDetent = .fraction(0.9)

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        currentValueSection
                        if let stats = metric.stats {
                            rangeSection(stats: stats)
                            statsGrid(stats: stats)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                }
            }
        }
        .presentationDetents([.fraction(0.9), .large], selection: $selectedDetent)
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }

    // MARK: - Current value

    private var currentValueSection: some View {
        VStack(spacing: 6) {
            Text("Tonight")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            Text(metric.formattedValue)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(currentValueColor)
                .monospacedDigit()

            if let sub = contextLabel {
                Text(sub)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(DS.border, lineWidth: 0.5))
    }

    // MARK: - 30d range bar

    private func rangeSection(stats: MetricStats) -> some View {
        let accent = rangeAccentColor(stats: stats)

        return VStack(alignment: .leading, spacing: 14) {
            Text("30-Day Range")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(DS.surfaceHigh)
                        .frame(height: 8)

                    // Fill up to tonight's position
                    let tonightPos = stats.normalizedPosition(of: metric.rawValue)
                    Capsule()
                        .fill(accent.opacity(0.7))
                        .frame(width: max(w * tonightPos, 8), height: 8)

                    // Avg marker
                    let avgX = w * stats.normalizedAvg
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DS.textSecondary)
                        .frame(width: 2, height: 14)
                        .offset(x: avgX - 1)

                    // Tonight marker
                    Circle()
                        .fill(accent)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(DS.bg, lineWidth: 2))
                        .offset(x: max(w * tonightPos - 7, 0))
                }
            }
            .frame(height: 14)

            // Min / avg / max labels
            HStack {
                rangeLabel(formatted(value: stats.min, unit: metric.unit), subtitle: "30d low")
                Spacer()
                rangeLabel(formatted(value: stats.avg, unit: metric.unit), subtitle: "30d avg")
                    .frame(maxWidth: .infinity)
                Spacer()
                rangeLabel(formatted(value: stats.max, unit: metric.unit), subtitle: "30d high")
            }
        }
        .padding(20)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
    }

    private func rangeLabel(_ value: String, subtitle: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(DS.textTertiary)
        }
    }

    // MARK: - Stats grid

    private func statsGrid(stats: MetricStats) -> some View {
        let ptsValue = String(
            format: "%.1f/%.1f",
            metric.displayedPointContribution,
            metric.displayedMaxPointContribution
        )
        return HStack(spacing: 10) {
            statCell(
                value: formatted(value: metric.rawValue - stats.avg, unit: metric.unit, signed: true),
                label: "vs avg",
                valueColor: isAtOrBetterThanAverage(avg: stats.avg) ? DS.green : Color(red: 1.0, green: 0.62, blue: 0.04)
            )
            statCell(
                value: "\(stats.count)",
                label: "nights tracked",
                valueColor: DS.textPrimary
            )
            statCell(
                value: ptsValue,
                label: "pts",
                valueColor: metric.normalizedScore >= 75 ? DS.green : Color(red: 1.0, green: 0.62, blue: 0.04)
            )
        }
    }

    private func statCell(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DS.border, lineWidth: 0.5))
    }

    // MARK: - Helpers

    private var currentValueColor: Color {
        if let stats = metric.stats {
            if isAtOrBetterThanAverage(avg: stats.avg) {
                return DS.green
            }
            return metric.normalizedScore >= 50
                ? Color(red: 1.0, green: 0.62, blue: 0.04)
                : Color(red: 1.0, green: 0.27, blue: 0.23)
        }

        let s = metric.normalizedScore
        if s >= 85 { return DS.green }
        if s >= 70 { return DS.purple }
        if s >= 55 { return Color(red: 1.0, green: 0.62, blue: 0.04) }
        return Color(red: 1.0, green: 0.27, blue: 0.23)
    }

    private var contextLabel: String? {
        if let hint = metric.hint { return hint }
        if let stats = metric.stats {
            let delta = metric.rawValue - stats.avg
            let threshold: Double = metric.unit == "fraction" ? 0.05 : 0.5
            guard abs(delta) >= threshold else { return nil }
            let deltaStr = formatted(value: delta, unit: metric.unit, signed: true)
            let direction = delta > 0 ? "above" : "below"
            return "\(deltaStr) \(direction) your average"
        }
        return nil
    }

    private func rangeAccentColor(stats: MetricStats) -> Color {
        if isAtOrBetterThanAverage(avg: stats.avg) {
            return DS.green
        }

        // Beneath personal baseline should not look "perfect green".
        return Color(red: 0.90, green: 0.76, blue: 0.24)
    }

    private func isAtOrBetterThanAverage(avg: Double) -> Bool {
        let delta = metric.rawValue - avg
        let threshold = baselineThreshold(for: metric.unit)
        if abs(delta) < threshold { return true }
        return metric.lowerIsBetter ? metric.rawValue < avg : metric.rawValue > avg
    }

    private func baselineThreshold(for unit: String) -> Double {
        switch unit {
        case "hr":
            return 10.0 / 60.0
        case "fraction":
            return 0.05
        default:
            return 0.5
        }
    }
}

// MARK: - Signed formatting helper

private func formatted(value: Double, unit: String, signed: Bool) -> String {
    let prefix = signed && value > 0 ? "+" : ""
    switch unit {
    case "hr":
        let mins = Int(abs(value) * 60)
        return "\(value < 0 ? "-" : "+")\(mins)m"
    case "%":
        return "\(prefix)\(String(format: "%.0f", value))%"
    case "fraction":
        return "\(prefix)\(String(format: "%.2f", value))"
    case "ms", "bpm", "min":
        return "\(prefix)\(Int(abs(value).rounded())) \(unit)"
    default:
        return "\(prefix)\(String(format: "%.1f", value)) \(unit)"
    }
}

// MARK: - Close button

private struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
                .frame(width: 28, height: 28)
                .background(DS.surface, in: Circle())
                .overlay(Circle().strokeBorder(DS.border, lineWidth: 0.5))
        }
    }
}
