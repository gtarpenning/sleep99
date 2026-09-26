import Charts
import SwiftUI

/// Compact trend row: a 7-night score sparkline that opens the Trends screen.
/// Ranges, overlays and legends live there, not on the dashboard.
struct ScoreTrendsSectionView: View {
    @Bindable var viewModel: DashboardViewModel

    private var points: [SleepScoreTrendPoint] {
        Array(viewModel.scoreHistory.filter { $0.score > 0 }.sorted { $0.date < $1.date }.suffix(7))
    }

    private var delta: Double? {
        guard points.count >= 4, let last = points.last else { return nil }
        let prior = points.dropLast()
        return last.score - prior.map(\.score).reduce(0, +) / Double(prior.count)
    }

    var body: some View {
        NavigationLink {
            TrendsView(viewModel: TrendsViewModel(store: viewModel.nightStore))
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trend")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                }

                if points.count >= 2 {
                    TrendSparkline(points: points)
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer(minLength: 0)
                }

                HStack(spacing: 3) {
                    Text("All")
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.purple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DS.border, lineWidth: 0.5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trend, \(subtitle). Opens all trends.")
    }

    private var subtitle: String {
        guard points.count >= 2 else { return "Scores appear as you sync" }
        guard let delta else { return "\(points.count)-night score" }
        let d = Int(delta.rounded())
        if d == 0 { return "\(points.count)-night score · steady" }
        return "\(points.count)-night score · \(d > 0 ? "+" : "")\(d) vs avg"
    }
}

struct TrendSparkline: View {
    let points: [SleepScoreTrendPoint]

    var body: some View {
        let lo = (points.map(\.score).min() ?? 0) - 6
        let hi = (points.map(\.score).max() ?? 100) + 6
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Score", p.score))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(DS.sleepArc)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            if let last = points.last {
                PointMark(x: .value("Date", last.date), y: .value("Score", last.score))
                    .foregroundStyle(DS.sleepArc)
                    .symbolSize(36)
            }
        }
        .chartYScale(domain: lo...hi)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}
