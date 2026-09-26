import Charts
import SwiftUI

struct SignalOverlayChartView: View {
    let series: [SleepChartSeries]
    let xDomain: ClosedRange<Date>?
    @Binding var selectedDate: Date?

    /// Per-series value range used to normalise every signal onto a shared 0–1 axis,
    /// so HR (50–70 bpm), HRV (20–90 ms) and RR (12–18 br/min) each fill the plot
    /// instead of squashing one another.
    private var ranges: [String: ClosedRange<Double>] {
        series.reduce(into: [:]) { out, s in out[s.title] = Self.paddedRange(for: s) }
    }

    var body: some View {
        let domain = resolvedDomain()
        let ranges = ranges
        Chart {
            ForEach(series, id: \.title) { s in
                let range = ranges[s.title] ?? 0...1
                let segments = segmented(points: s.points, maxGap: 30 * 60)
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    segmentMarks(seg: seg, title: s.title, range: range)
                }

                // Dotted per-series average line with a trailing value label.
                let avg = s.points.map(\.value).reduce(0, +) / Double(Swift.max(s.points.count, 1))
                RuleMark(y: .value("Average", Self.normalise(avg, in: range)))
                    .foregroundStyle(signalColor(for: s.title).opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .trailing, alignment: .leading, spacing: 2) {
                        Text(Self.formatted(avg, unit: s.unit))
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(signalColor(for: s.title).opacity(0.7))
                    }
            }

            // Min / max HR markers — enlarged dots with a value label.
            if let hrSeries = series.first(where: { $0.title == "Heart Rate" }),
               let range = ranges["Heart Rate"] {
                if let minPoint = hrSeries.points.min(by: { $0.value < $1.value }) {
                    extremeMark(minPoint, range: range, position: .bottom)
                }
                if let maxPoint = Self.interiorMax(of: hrSeries.points, domain: domain) {
                    extremeMark(maxPoint, range: range, position: .top)
                }
            }

            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                ForEach(series, id: \.title) { item in
                    if let value = interpolatedValue(at: selectedDate, points: item.points),
                       let range = ranges[item.title] {
                        PointMark(
                            x: .value("Selected", selectedDate),
                            y: .value(item.title, Self.normalise(value, in: range))
                        )
                        .symbol(.circle)
                        .symbolSize(50)
                        .foregroundStyle(by: .value("Signal", item.title))
                    }
                }
            }
        }
        .chartForegroundStyleScale(
            domain: ["Heart Rate", "HRV", "Respiratory Rate"],
            range:  [hrColor, hrvColor, rrColor]
        )
        .sleepChartAxes(
            xDomain: domain,
            yLabels: yAxisLabels(ranges: ranges),
            visible: true
        )
        .chartLegend(.hidden)
        .chartXScale(domain: domain)
        .chartYScale(domain: -0.04...1.12)   // headroom for the max-HR label
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let frame = geometry[proxy.plotAreaFrame]
                                let xPosition = value.location.x - frame.origin.x
                                guard xPosition >= 0, xPosition <= frame.width else { return }
                                if let date: Date = proxy.value(atX: xPosition) {
                                    selectedDate = date
                                }
                            }
                            .onEnded { _ in
                                selectedDate = nil
                            }
                    )
            }
        }
    }

    // MARK: - Normalisation

    static func paddedRange(for s: SleepChartSeries) -> ClosedRange<Double> {
        let values = s.points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        guard hi > lo else { return (lo - 1)...(hi + 1) }
        let pad = (hi - lo) * 0.12
        return (lo - pad)...(hi + pad)
    }

    static func normalise(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return (value - range.lowerBound) / span
    }

    static func formatted(_ value: Double, unit: String) -> String {
        if unit == "br/min" {
            return value.formatted(.number.precision(.fractionLength(1)))
        }
        return "\(Int(value.rounded()))"
    }

    /// Highest HR point excluding the first and last five minutes of the window,
    /// where wake-up and settling-in artefacts dominate.
    static func interiorMax(of points: [SleepChartPoint], domain: ClosedRange<Date>) -> SleepChartPoint? {
        let margin: TimeInterval = 5 * 60
        let interior = points.filter {
            $0.date > domain.lowerBound.addingTimeInterval(margin) &&
            $0.date < domain.upperBound.addingTimeInterval(-margin)
        }
        return interior.max(by: { $0.value < $1.value })
    }

    /// Trailing Y-axis labels in the units of the first visible series.
    private func yAxisLabels(ranges: [String: ClosedRange<Double>]) -> [(position: Double, label: String)] {
        guard let first = series.first, let range = ranges[first.title] else { return [] }
        return [0.08, 0.5, 0.92].map { p in
            let raw = range.lowerBound + p * (range.upperBound - range.lowerBound)
            return (p, Self.formatted(raw, unit: first.unit))
        }
    }

    @ChartContentBuilder
    private func extremeMark(
        _ point: SleepChartPoint,
        range: ClosedRange<Double>,
        position: AnnotationPosition
    ) -> some ChartContent {
        PointMark(
            x: .value("Time", point.date),
            y: .value("HR", Self.normalise(point.value, in: range))
        )
        .symbolSize(72)
        .foregroundStyle(hrColor.opacity(0.55))
        .annotation(position: position, spacing: 2) {
            Text("\(Int(point.value.rounded()))")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(hrColor.opacity(0.7))
        }
    }

    private func resolvedDomain() -> ClosedRange<Date> {
        if let xDomain {
            return xDomain
        }
        let dates = series.flatMap { $0.points.map(\.date) }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            let now = Date()
            return now...now
        }
        return minDate...maxDate
    }

    private func interpolatedValue(at date: Date, points: [SleepChartPoint]) -> Double? {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        if date <= first.date { return first.value }
        if date >= last.date { return last.value }

        var previous = first
        for point in sorted.dropFirst() {
            if date <= point.date {
                let total = point.date.timeIntervalSince(previous.date)
                if total <= 0 { return point.value }
                let elapsed = date.timeIntervalSince(previous.date)
                let fraction = elapsed / total
                return previous.value + (point.value - previous.value) * fraction
            }
            previous = point
        }
        return last.value
    }

    /// Splits sorted points into contiguous segments where consecutive gaps ≤ maxGap seconds.
    private func segmented(points: [SleepChartPoint], maxGap: TimeInterval) -> [[SleepChartPoint]] {
        let sorted = points.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }
        var segments: [[SleepChartPoint]] = [[sorted[0]]]
        for point in sorted.dropFirst() {
            if point.date.timeIntervalSince(segments[segments.count - 1].last!.date) <= maxGap {
                segments[segments.count - 1].append(point)
            } else {
                segments.append([point])
            }
        }
        return segments
    }

    @ChartContentBuilder
    private func segmentMarks(seg: [SleepChartPoint], title: String, range: ClosedRange<Double>) -> some ChartContent {
        if seg.count == 1 {
            PointMark(
                x: .value("Time", seg[0].date),
                y: .value(title, Self.normalise(seg[0].value, in: range))
            )
            .symbolSize(30)
            .foregroundStyle(by: .value("Signal", title))
        } else {
            ForEach(seg, id: \.date) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(title, Self.normalise(point.value, in: range)),
                    series: .value("Series", title)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Signal", title))
            }
        }
    }
}

// MARK: - Shared axis configuration

/// Both stacked charts (stages underneath, signals on top) must reserve identical
/// axis space so their plot areas line up. The stage chart passes `visible: false`
/// to keep the reservation but hide the labels.
private struct SleepChartAxes: ViewModifier {
    let xDomain: ClosedRange<Date>
    let yLabels: [(position: Double, label: String)]
    let visible: Bool

    private var hourMarks: [Date] {
        let cal = Calendar.current
        guard var tick = cal.dateInterval(of: .hour, for: xDomain.lowerBound)?.end else { return [] }
        // Start on an even hour so labels read 10 PM, 12 AM, 2 AM…
        if cal.component(.hour, from: tick) % 2 == 1 {
            tick = cal.date(byAdding: .hour, value: 1, to: tick) ?? tick
        }
        var out: [Date] = []
        while tick < xDomain.upperBound {
            out.append(tick)
            tick = cal.date(byAdding: .hour, value: 2, to: tick) ?? xDomain.upperBound
        }
        return out
    }

    func body(content: Content) -> some View {
        let labelColor = visible ? DS.textTertiary : Color.clear
        let gridColor  = visible ? DS.border.opacity(0.6) : Color.clear
        content
            .chartXAxis {
                AxisMarks(values: hourMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(gridColor)
                    AxisValueLabel(anchor: .top) {
                        if let d = value.as(Date.self) {
                            Text(d, format: .dateTime.hour())
                                .font(.system(size: 8))
                                .foregroundStyle(labelColor)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: yLabels.map(\.position)) { value in
                    AxisValueLabel(anchor: .leading) {
                        if let p = value.as(Double.self),
                           let match = yLabels.first(where: { abs($0.position - p) < 0.001 }) {
                            Text(match.label)
                                .font(.system(size: 8))
                                .foregroundStyle(labelColor)
                                .frame(width: 24, alignment: .leading)
                        }
                    }
                }
            }
    }
}

extension View {
    func sleepChartAxes(
        xDomain: ClosedRange<Date>,
        yLabels: [(position: Double, label: String)],
        visible: Bool
    ) -> some View {
        modifier(SleepChartAxes(xDomain: xDomain, yLabels: yLabels, visible: visible))
    }
}
