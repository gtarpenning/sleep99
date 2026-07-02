import Charts
import SwiftUI

struct SignalOverlayChartView: View {
    let series: [SleepChartSeries]
    let xDomain: ClosedRange<Date>?
    @Binding var selectedDate: Date?

    var body: some View {
        let domain = resolvedDomain()
        Chart {
            ForEach(series, id: \.title) { s in
                let segments = segmented(points: s.points, maxGap: 30 * 60)
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    segmentMarks(seg: seg, title: s.title)
                }
            }

            // Lowest HR marker — subtle enlarged dot at the minimum heart rate point
            if let hrSeries = series.first(where: { $0.title == "Heart Rate" }),
               let minPoint = hrSeries.points.min(by: { $0.value < $1.value }) {
                PointMark(
                    x: .value("Time", minPoint.date),
                    y: .value("HR Low", minPoint.value)
                )
                .symbolSize(72)
                .foregroundStyle(hrColor.opacity(0.55))
                .annotation(position: .bottom, spacing: 2) {
                    Text("\(Int(minPoint.value.rounded()))")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(hrColor.opacity(0.7))
                }
            }

            // Apnea event markers — one dot per detected spike cluster.
            // Threshold is baseline-relative (≥ 2σ above the night's mean RR, with a
            // 3 br/min absolute floor) so it adapts to each user's normal range.
            if let rrSeries = series.first(where: { $0.title == "Respiratory Rate" }) {
                let events = ApneaDetector.detect(in: rrSeries.points)
                ForEach(events, id: \.date) { event in
                    PointMark(
                        x: .value("Time", event.date),
                        y: .value("Apnea", event.value)
                    )
                    .symbolSize(72)
                    .foregroundStyle(rrColor.opacity(0.55))
                    .annotation(position: .top, spacing: 2) {
                        VStack(spacing: 0) {
                            Text("apnea")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(rrColor.opacity(0.65))
                            Text("\(Int(event.value.rounded()))")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(rrColor.opacity(0.8))
                        }
                    }
                }
            }

            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                ForEach(series, id: \.title) { item in
                    if let value = interpolatedValue(at: selectedDate, points: item.points) {
                        PointMark(
                            x: .value("Selected", selectedDate),
                            y: .value(item.title, value)
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
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: domain)
        .chartYScale(domain: yDomain())
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

    private func yDomain() -> ClosedRange<Double> {
        let allValues = series.flatMap { $0.points.map(\.value) }
        guard let minVal = allValues.min(), let maxVal = allValues.max(), minVal < maxVal else {
            return 0...100
        }
        let padding = (maxVal - minVal) * 0.12
        return (minVal - padding)...(maxVal + padding)
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
    private func segmentMarks(seg: [SleepChartPoint], title: String) -> some ChartContent {
        if seg.count == 1 {
            PointMark(
                x: .value("Time", seg[0].date),
                y: .value(title, seg[0].value)
            )
            .symbolSize(30)
            .foregroundStyle(by: .value("Signal", title))
        } else {
            ForEach(seg, id: \.date) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(title, point.value),
                    series: .value("Series", title)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Signal", title))
            }
        }
    }
}
