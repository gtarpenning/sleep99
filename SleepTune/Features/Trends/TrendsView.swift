import Charts
import SwiftUI

/// Long-range view of every metric, with an optional second metric overlaid on
/// a normalised axis, a day-type filter, and a day-of-week breakdown.
struct TrendsView: View {
    @State var viewModel: TrendsViewModel
    @State private var showsCompareSheet = false

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    rangeBar
                    metricChips
                    chartCard
                    dayOfWeekCard
                    CorrelationsCardView(findings: viewModel.correlations,
                                         fitnessSentence: viewModel.fitnessSentence,
                                         nightCount: viewModel.correlationNights)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .sheet(isPresented: $showsCompareSheet) {
            CompareMetricSheet(primary: viewModel.primary, selected: viewModel.compare) { viewModel.compare = $0 }
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Controls

    private var rangeBar: some View {
        HStack(spacing: 8) {
            Picker("Range", selection: $viewModel.range) {
                ForEach(TrendRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)

            Picker("Days", selection: $viewModel.dayFilter) {
                ForEach(DayTypeFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
            .frame(width: 130)
        }
    }

    private var metricChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrendMetric.sleepMetrics + TrendMetric.activityMetrics) { m in
                    MetricChip(metric: m, selected: m == viewModel.primary) {
                        if viewModel.compare == m { viewModel.compare = nil }
                        viewModel.primary = m
                    }
                }
            }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.primary.title)
                        .font(.headline)
                        .foregroundStyle(DS.textPrimary)
                    if let avg = viewModel.primaryAverage {
                        Text("avg \(viewModel.primary.format(avg)) · \(viewModel.primaryPoints.count) nights")
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                }
                Spacer()
                compareButton
            }

            if viewModel.primaryPoints.count < 3 {
                Text(viewModel.isLoading ? "Loading…" : "Not enough nights yet. Keep syncing.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textTertiary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                TrendChart(
                    primary: viewModel.primary,
                    points: viewModel.primaryPoints,
                    line: viewModel.primaryLine,
                    average: viewModel.primaryAverage,
                    compare: viewModel.compare,
                    comparePoints: viewModel.comparePoints,
                    compareLine: viewModel.compareLine,
                    compareAverage: viewModel.compareAverage,
                    monthly: viewModel.range.usesMonthlyBuckets
                )
                .frame(height: 200)
                legend
            }

            if let s = viewModel.trendSentence {
                Text(s)
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
    }

    private var compareButton: some View {
        Button { showsCompareSheet = true } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.compare == nil ? "plus.circle" : "arrow.triangle.swap")
                Text(viewModel.compare.map { $0.title } ?? "Compare")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(viewModel.compare?.color ?? DS.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.surfaceHigh, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(viewModel.primary)
            if let c = viewModel.compare { legendItem(c) }
            HStack(spacing: 5) {
                Rectangle().fill(DS.textTertiary).frame(width: 16, height: 1)
                Text("avg").font(.system(size: 10, weight: .medium)).foregroundStyle(DS.textSecondary)
            }
        }
    }

    private func legendItem(_ m: TrendMetric) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1).fill(m.color).frame(width: 16, height: 2)
            Text(m.isActivity ? "\(m.title) (prev. day)" : m.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.textSecondary)
        }
    }

    // MARK: - Day of week

    private var dayOfWeekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score by day of week")
                .font(.headline)
                .foregroundStyle(DS.textPrimary)
            Text("Night of the week, over the selected range.")
                .font(.caption)
                .foregroundStyle(DS.textSecondary)
            DayOfWeekChart(averages: viewModel.weekdayScores)
                .frame(height: 120)
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
    }
}

// MARK: - Chip

private struct MetricChip: View {
    let metric: TrendMetric
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? DS.bg : DS.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? metric.color : DS.surfaceHigh, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chart

private struct TrendRow: Identifiable {
    let id: String
    let date: Date
    let y: Double      // normalised 0–1
    let raw: Double
    let series: String
}

struct TrendChart: View {
    let primary: TrendMetric
    let points: [TrendPoint]
    let line: [TrendPoint]
    let average: Double?
    let compare: TrendMetric?
    let comparePoints: [TrendPoint]
    let compareLine: [TrendPoint]
    let compareAverage: Double?
    let monthly: Bool

    @State private var scrub: Date?

    private var pRange: ClosedRange<Double> { Self.padded(points.map(\.value)) }
    private var cRange: ClosedRange<Double> { Self.padded(comparePoints.map(\.value)) }

    static func padded(_ v: [Double]) -> ClosedRange<Double> {
        guard let lo = v.min(), let hi = v.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.12, 0.5)
        return (lo - pad)...(hi + pad)
    }
    private static func norm(_ v: Double, _ r: ClosedRange<Double>) -> Double {
        (v - r.lowerBound) / (r.upperBound - r.lowerBound)
    }

    private var yLabels: [(Double, String)] {
        let r = pRange
        return [0.0, 0.5, 1.0].map { ($0, primary.format(r.lowerBound + $0 * (r.upperBound - r.lowerBound))) }
    }

    var body: some View {
        Chart {
            if !monthly {
                ForEach(points) { p in
                    PointMark(x: .value("Date", p.date), y: .value("v", Self.norm(p.value, pRange)))
                        .foregroundStyle(primary.color.opacity(0.28))
                        .symbolSize(10)
                }
            }
            ForEach(line) { p in
                if monthly {
                    BarMark(x: .value("Date", p.date, unit: .month), y: .value("v", Self.norm(p.value, pRange)))
                        .foregroundStyle(primary.color.opacity(compare == nil ? 0.8 : 0.45))
                        .cornerRadius(3)
                } else {
                    LineMark(x: .value("Date", p.date), y: .value("v", Self.norm(p.value, pRange)), series: .value("s", "p"))
                        .foregroundStyle(primary.color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
            }
            if let avg = average {
                RuleMark(y: .value("avg", Self.norm(avg, pRange)))
                    .foregroundStyle(primary.color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            if let compare {
                ForEach(compareLine) { p in
                    LineMark(x: .value("Date", monthly ? p.date.addingTimeInterval(15 * 86_400) : p.date),
                             y: .value("c", Self.norm(p.value, cRange)), series: .value("s", "c"))
                        .foregroundStyle(compare.color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if let avg = compareAverage {
                    RuleMark(y: .value("cavg", Self.norm(avg, cRange)))
                        .foregroundStyle(compare.color.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            if let scrub, let n = nearest(scrub) {
                RuleMark(x: .value("sel", n.date))
                    .foregroundStyle(DS.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(for: n.date)
                    }
            }
        }
        .chartYScale(domain: -0.05...1.08)
        .chartYAxis {
            AxisMarks(position: .trailing, values: yLabels.map(\.0)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(DS.border)
                AxisValueLabel {
                    if let d = v.as(Double.self), let l = yLabels.first(where: { abs($0.0 - d) < 0.01 }) {
                        Text(l.1).font(.caption2).foregroundStyle(DS.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: monthly ? .dateTime.month(.abbreviated) : .dateTime.month(.abbreviated).day())
                    .font(.caption2).foregroundStyle(DS.textTertiary)
            }
        }
        .chartXSelection(value: $scrub)
        .chartLegend(.hidden)
    }

    private func nearest(_ d: Date) -> TrendPoint? {
        let src = monthly ? line : points
        return src.min { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) }
    }

    private func tooltip(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date.formatted(monthly ? .dateTime.month(.wide).year() : .dateTime.month(.abbreviated).day()))
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.textSecondary)
            if let p = (monthly ? line : points).first(where: { $0.date == date }) {
                row(primary, p.value)
            }
            if let c = compare, let p = (monthly ? compareLine : comparePoints)
                .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }),
               abs(p.date.timeIntervalSince(date)) < 86_400 * (monthly ? 20 : 1) {
                row(c, p.value)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.border, lineWidth: 0.5))
    }

    private func row(_ m: TrendMetric, _ v: Double) -> some View {
        HStack(spacing: 5) {
            Circle().fill(m.color).frame(width: 5, height: 5)
            Text(m.format(v)).font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.textPrimary).monospacedDigit()
        }
    }
}

// MARK: - Day of week bars

struct DayOfWeekChart: View {
    let averages: [Int: (avg: Double, n: Int)]
    private let labels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        Chart {
            ForEach(1...7, id: \.self) { wd in
                if let a = averages[wd] {
                    BarMark(x: .value("Day", labels[wd - 1]), y: .value("Score", a.avg))
                        .foregroundStyle(DS.scoreColor(for: a.avg).opacity(0.85))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text("\(Int(a.avg.rounded()))").font(.system(size: 9, weight: .semibold)).foregroundStyle(DS.textSecondary)
                        }
                }
            }
        }
        .chartXScale(domain: labels)
        .chartYScale(domain: 0...100)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.caption2).foregroundStyle(DS.textTertiary) }
        }
    }
}

// MARK: - Compare picker

private struct CompareMetricSheet: View {
    let primary: TrendMetric
    let selected: TrendMetric?
    let onPick: (TrendMetric?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { onPick(nil); dismiss() } label: {
                        Label("None", systemImage: selected == nil ? "checkmark.circle.fill" : "circle")
                    }
                }
                Section("Sleep") { rows(TrendMetric.sleepMetrics) }
                Section("Previous day") { rows(TrendMetric.activityMetrics) }
            }
            .scrollContentBackground(.hidden)
            .background(DS.bg)
            .navigationTitle("Compare with")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func rows(_ ms: [TrendMetric]) -> some View {
        ForEach(ms.filter { $0 != primary }) { m in
            Button { onPick(m); dismiss() } label: {
                HStack {
                    Circle().fill(m.color).frame(width: 8, height: 8)
                    Text(m.title)
                    Spacer()
                    if selected == m { Image(systemName: "checkmark").foregroundStyle(DS.purple) }
                }
            }
            .foregroundStyle(DS.textPrimary)
        }
    }
}
