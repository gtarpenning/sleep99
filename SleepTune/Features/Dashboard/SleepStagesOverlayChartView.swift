import SwiftUI

struct SleepStagesOverlayChartView: View {
    let stages: [SleepStageSample]
    let heartRate: SleepChartSeries?
    let hrv: SleepChartSeries?
    let respiratoryRate: SleepChartSeries?

    @State private var showsHeartRate = false
    @State private var showsHRV = false
    @State private var showsRespiratoryRate = false
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading) {
            let overlaySeries = overlaySignalSeries()
            let domain = xDomain(for: overlaySeries)
            let hasData = !stages.isEmpty || heartRate != nil || hrv != nil || respiratoryRate != nil

            if !hasData {
                Text("No sleep signals found for last night.")
                    .foregroundStyle(.secondary)
            } else {
                SleepStageChartView(stages: stages, xDomain: domain)
                    .overlay {
                        SignalOverlayChartView(series: overlaySeries, xDomain: domain, selectedDate: $selectedDate)
                    }
                    .frame(height: 220)

                SleepStageLegendView(stages: stages)

                if let selectedDate {
                    let readings = scrubReadings(for: overlaySeries, selectedDate: selectedDate)
                    LastNightScrubReadoutView(selectedDate: selectedDate, readings: readings)
                }

                if heartRate != nil {
                    Toggle("Add heart rate", isOn: $showsHeartRate)
                }
                if hrv != nil {
                    Toggle("Add HRV", isOn: $showsHRV)
                }
                if respiratoryRate != nil {
                    Toggle("Add respiratory rate", isOn: $showsRespiratoryRate)
                }
            }
        }
    }

    private func overlaySignalSeries() -> [SleepChartSeries] {
        var series: [SleepChartSeries] = []
        if showsHeartRate, let heartRate {
            series.append(heartRate)
        }
        if showsHRV, let hrv {
            series.append(hrv)
        }
        if showsRespiratoryRate, let respiratoryRate {
            series.append(respiratoryRate)
        }
        return series
    }

    private func xDomain(for overlaySeries: [SleepChartSeries]) -> ClosedRange<Date>? {
        let stageStarts = stages.map(\.startDate)
        let stageEnds = stages.map(\.endDate)
        let signalDates = overlaySeries.flatMap { $0.points.map(\.date) }
        let allStarts = stageStarts + signalDates
        let allEnds = stageEnds + signalDates
        guard let minStart = allStarts.min(), let maxEnd = allEnds.max() else { return nil }
        return minStart...maxEnd
    }

    private func scrubReadings(
        for series: [SleepChartSeries],
        selectedDate: Date
    ) -> [SleepSignalReading] {
        series.compactMap { item in
            guard let value = interpolatedValue(at: selectedDate, points: item.points) else { return nil }
            return SleepSignalReading(
                id: item.title,
                title: item.title,
                value: value,
                unit: item.unit
            )
        }
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
