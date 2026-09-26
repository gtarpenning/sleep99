import Charts
import SwiftUI

/// Compact list of the strongest curated correlations; tap a row for the scatter.
struct CorrelationsCardView: View {
    let findings: [CorrelationFinding]
    let fitnessSentence: String?
    let nightCount: Int
    @State private var selected: CorrelationFinding?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("What moves your sleep")
                    .font(.headline)
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                Text("\(nightCount) nights")
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
            }

            if let fitnessSentence {
                Text(fitnessSentence)
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            }

            if findings.isEmpty {
                Text(nightCount < CorrelationEngine.minNights
                     ? "Needs \(CorrelationEngine.minNights) nights to look for patterns."
                     : "No clear patterns yet. Relationships show up here once they reach |r| ≥ 0.25.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(findings.prefix(5)) { f in
                        Button { selected = f } label: { row(f) }
                            .buttonStyle(.plain)
                        if f.id != findings.prefix(5).last?.id {
                            Divider().overlay(DS.borderFaint)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
        .sheet(item: $selected) { f in
            CorrelationDetailSheet(finding: f)
                .presentationDetents([.medium, .large])
        }
    }

    private func row(_ f: CorrelationFinding) -> some View {
        HStack(spacing: 10) {
            StrengthDots(strength: f.strength, color: f.r > 0 ? DS.green : Color(red: 1.0, green: 0.42, blue: 0.42))
            VStack(alignment: .leading, spacing: 2) {
                Text(f.headline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DS.textPrimary)
                Text(f.detail)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(.vertical, 10)
    }
}

private struct StrengthDots: View {
    let strength: CorrelationFinding.Strength
    let color: Color
    private var filled: Int {
        switch strength { case .weak: return 1; case .moderate: return 2; case .strong: return 3 }
    }
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(i < filled ? color : DS.surfaceHigh).frame(width: 6, height: 6)
            }
        }
        .frame(width: 26)
    }
}

// MARK: - Detail

struct CorrelationDetailSheet: View {
    let finding: CorrelationFinding
    @Environment(\.dismiss) private var dismiss

    private struct Dot: Identifiable { let id: Int; let x: Double; let y: Double }
    private var dots: [Dot] { finding.pairs.enumerated().map { Dot(id: $0.offset, x: $0.element.0, y: $0.element.1) } }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(finding.headline)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(finding.detail + ". " + strengthText)
                            .font(.subheadline)
                            .foregroundStyle(DS.textSecondary)

                        scatter
                            .frame(height: 240)

                        Text(scatterCaption)
                            .font(.footnote)
                            .foregroundStyle(DS.textTertiary)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Correlation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private var scatterCaption: String {
        var parts = ["Each dot is one night."]
        if finding.isNextDay {
            parts.append("\(finding.y.title) is from the day after that night.")
        } else if finding.x.isActivity {
            let shift = finding.lagNights > 0 ? " (shifted \(finding.lagNights) day\(finding.lagNights == 1 ? "" : "s"))" : ""
            parts.append("\(finding.x.title) is from the day before the night\(shift).")
        }
        parts.append("Correlation is not causation; use this as a prompt to experiment, not a verdict.")
        return parts.joined(separator: " ")
    }

    private var strengthText: String {
        switch finding.strength {
        case .weak: return "A weak relationship."
        case .moderate: return "A moderate relationship."
        case .strong: return "A strong relationship."
        }
    }

    private var scatter: some View {
        let xs = finding.pairs.map(\.0), ys = finding.pairs.map(\.1)
        let xr = TrendChart.padded(xs), yr = TrendChart.padded(ys)
        let fit = fitLine(xs, ys)
        return Chart {
            ForEach(dots) { d in
                PointMark(x: .value(finding.x.title, d.x), y: .value(finding.y.title, d.y))
                    .foregroundStyle(finding.y.color.opacity(0.6))
                    .symbolSize(22)
            }
            if let fit {
                LineMark(x: .value("x", xr.lowerBound), y: .value("y", fit.0 + fit.1 * xr.lowerBound))
                    .foregroundStyle(DS.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                LineMark(x: .value("x", xr.upperBound), y: .value("y", fit.0 + fit.1 * xr.upperBound))
                    .foregroundStyle(DS.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXScale(domain: xr)
        .chartYScale(domain: yr)
        .chartXAxisLabel(finding.x.title + (finding.x.unit.isEmpty ? "" : " (\(finding.x.unit))"), alignment: .center)
        .chartYAxisLabel(finding.y.title + (finding.y.unit.isEmpty ? "" : " (\(finding.y.unit))"), position: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(DS.border)
                AxisValueLabel().font(.caption2).foregroundStyle(DS.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(DS.border)
                AxisValueLabel().font(.caption2).foregroundStyle(DS.textTertiary)
            }
        }
    }

    /// Least-squares (intercept, slope).
    private func fitLine(_ xs: [Double], _ ys: [Double]) -> (Double, Double)? {
        guard xs.count >= 3 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in xs.indices { num += (xs[i] - mx) * (ys[i] - my); den += (xs[i] - mx) * (xs[i] - mx) }
        guard den > 0 else { return nil }
        let b = num / den
        return (my - b * mx, b)
    }
}
