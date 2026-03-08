import SwiftUI
import Charts

#if DEBUG
#Preview("Last Night Chart") {
    SleepStagesOverlayChartView(
        stages: MockSleepData.stages,
        heartRate: MockSleepData.heartRateSeries,
        hrv: MockSleepData.hrvSeries,
        respiratoryRate: MockSleepData.rrSeries
    )
    .padding()
    .background(DS.bg)
    .colorScheme(.dark)
}
#endif

// Signal colors — shared between toggles, chart lines, and tooltip
let hrColor:  Color = Color(red: 1.0, green: 0.42, blue: 0.42)
let hrvColor: Color = Color(red: 0.22, green: 1.0, blue: 0.42)
let rrColor:  Color = Color(red: 0.48, green: 0.36, blue: 0.96)

func signalColor(for title: String) -> Color {
    switch title {
    case "Heart Rate":       return hrColor
    case "HRV":              return hrvColor
    case "Respiratory Rate": return rrColor
    default:                 return DS.textSecondary
    }
}

struct SleepStagesOverlayChartView: View {
    let stages: [SleepStageSample]
    let heartRate: SleepChartSeries?
    let hrv: SleepChartSeries?
    let respiratoryRate: SleepChartSeries?

    @State private var showsHeartRate = true
    @State private var showsHRV = false
    @State private var showsRespiratoryRate = false
    @State private var selectedDate: Date?

    var body: some View {
        let overlaySeries = overlaySignalSeries()
        let domain = xDomain(for: overlaySeries)
        let hasData = !stages.isEmpty || heartRate != nil

        VStack(alignment: .leading, spacing: 10) {
            if !hasData {
                Text("No sleep data for this night.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .frame(height: 140, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                // Chart + tooltip overlay
                ZStack(alignment: .topLeading) {
                    SleepStageChartView(stages: stages, xDomain: domain)
                        .overlay {
                            SignalOverlayChartView(
                                series: overlaySeries,
                                xDomain: domain,
                                selectedDate: $selectedDate
                            )
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Tooltip
                    if let sel = selectedDate {
                        let readings = scrubReadings(for: overlaySeries, selectedDate: sel)
                        if !readings.isEmpty {
                            ScrubTooltipView(date: sel, readings: readings)
                                .padding(8)
                                .allowsHitTesting(false)
                        }
                    }
                }

                // Legend row
                SleepStageLegendView(stages: stages)

                // Signal toggles row
                HStack(spacing: 8) {
                    if heartRate != nil {
                        SignalToggle(label: "HR", isOn: $showsHeartRate, color: hrColor)
                    }
                    if hrv != nil {
                        SignalToggle(label: "HRV", isOn: $showsHRV, color: hrvColor)
                    }
                    if respiratoryRate != nil {
                        SignalToggle(label: "RR", isOn: $showsRespiratoryRate, color: rrColor)
                    }
                    Spacer()
                }
            }
        }
    }

    private func overlaySignalSeries() -> [SleepChartSeries] {
        var s: [SleepChartSeries] = []
        if showsHeartRate,       let hr = heartRate       { s.append(hr) }
        if showsHRV,             let h  = hrv             { s.append(h) }
        if showsRespiratoryRate, let rr = respiratoryRate { s.append(rr) }
        return s
    }

    private func xDomain(for overlaySeries: [SleepChartSeries]) -> ClosedRange<Date>? {
        // Derive bounds from signal data (already clipped to sleep window by the VM).
        // Do NOT use stage.startDate/endDate — a wide inBed record from a third-party
        // app (e.g. AutoSleep) can span 2pm → 7am, pulling the X-axis back to afternoon.
        let signalDates = overlaySeries.flatMap { $0.points.map(\.date) }
        if let min = signalDates.min(), let max = signalDates.max() {
            return min...max
        }
        // No signals active — use asleep-only stage bounds as fallback.
        let asleepDates = stages
            .filter { $0.stage != .inBed && $0.stage != .awake }
            .flatMap { [$0.startDate, $0.endDate] }
        guard let min = asleepDates.min(), let max = asleepDates.max() else { return nil }
        return min...max
    }

    private func scrubReadings(for series: [SleepChartSeries], selectedDate: Date) -> [SleepSignalReading] {
        series.compactMap { item in
            guard let v = interpolatedValue(at: selectedDate, points: item.points) else { return nil }
            return SleepSignalReading(id: item.title, title: item.title, value: v, unit: item.unit)
        }
    }

    private func interpolatedValue(at date: Date, points: [SleepChartPoint]) -> Double? {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        if date <= first.date { return first.value }
        if date >= last.date  { return last.value }
        var prev = first
        for point in sorted.dropFirst() {
            if date <= point.date {
                let total = point.date.timeIntervalSince(prev.date)
                guard total > 0 else { return point.value }
                let frac = date.timeIntervalSince(prev.date) / total
                return prev.value + (point.value - prev.value) * frac
            }
            prev = point
        }
        return last.value
    }
}

// MARK: - Tooltip card

private struct ScrubTooltipView: View {
    let date: Date
    let readings: [SleepSignalReading]

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Self.timeFmt.string(from: date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            ForEach(readings) { reading in
                HStack(spacing: 5) {
                    Circle()
                        .fill(signalColor(for: reading.title))
                        .frame(width: 5, height: 5)
                    Text(formattedReadingValue(reading))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.border, lineWidth: 0.5))
    }

    private func formattedReadingValue(_ reading: SleepSignalReading) -> String {
        if reading.unit == "br/min" {
            return "\(reading.value.formatted(.number.precision(.fractionLength(1)))) \(reading.unit)"
        }
        return "\(Int(reading.value.rounded())) \(reading.unit)"
    }
}

// MARK: - Toggle

struct SignalToggle: View {
    let label: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { isOn.toggle() }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(isOn ? color : DS.textTertiary)
                    .frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? DS.textPrimary : DS.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOn ? color.opacity(0.12) : DS.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? color.opacity(0.3) : DS.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
