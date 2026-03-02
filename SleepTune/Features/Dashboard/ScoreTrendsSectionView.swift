import Charts
import SwiftUI

// MARK: - Chart series identifier

private enum TrendSeries: String, Plottable {
    case sleep    = "Sleep"
    case recovery = "Recovery"

    var color: Color {
        switch self {
        case .sleep:    return DS.sleepArc
        case .recovery: return DS.recoveryArc
        }
    }

    var lineWidth: CGFloat { 2.0 }
}

// MARK: - Flat row for Swift Charts

private struct TrendRow: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let series: TrendSeries
}

// MARK: - View

struct ScoreTrendsSectionView: View {
    @Bindable var viewModel: DashboardViewModel

    private var rows: [TrendRow] {
        viewModel.scoreHistory.flatMap { point -> [TrendRow] in
            var out: [TrendRow] = []
            if let s = point.sleepScore    { out.append(TrendRow(date: point.date, score: s, series: .sleep)) }
            if let r = point.recoveryScore { out.append(TrendRow(date: point.date, score: r, series: .recovery)) }
            return out
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DSSectionHeader(title: "Trend")

            Picker("Range", selection: $viewModel.trendRange) {
                ForEach(SleepScoreTrendRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
            .onChange(of: viewModel.trendRange) { _, _ in
                viewModel.updateTrendRange(viewModel.trendRange)
            }

            if viewModel.scoreHistory.isEmpty {
                Text("Scores will appear here as you sync data.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textTertiary)
                    .frame(height: 120, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                chart
                legend
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(rows) { row in
            LineMark(
                x: .value("Date", row.date),
                y: .value("Score", row.score),
                series: .value("Series", row.series.rawValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(row.series.color)
            .lineStyle(StrokeStyle(lineWidth: row.series.lineWidth))

        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DS.border)
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.caption2)
                            .foregroundStyle(DS.textTertiary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 130)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach([TrendSeries.sleep, .recovery], id: \.self) { series in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(series.color)
                        .frame(width: 16, height: 2)
                    Text(series.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.textSecondary)
                }
            }
        }
    }
}
