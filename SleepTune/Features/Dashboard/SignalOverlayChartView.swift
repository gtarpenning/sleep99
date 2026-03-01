import Charts
import SwiftUI

struct SignalOverlayChartView: View {
    let series: [SleepChartSeries]
    let xDomain: ClosedRange<Date>?
    @Binding var selectedDate: Date?

    var body: some View {
        let domain = resolvedDomain()
        Chart {
            ForEach(series, id: \.title) { series in
                ForEach(series.points, id: \.date) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value(series.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Signal", series.title))
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
}
