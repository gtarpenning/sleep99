import Foundation
import SwiftUI

struct LastNightMetricsView: View {
    let metrics: LastNightMetrics

    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent("Time to lowest heart rate", value: timeToLowestHeartRateText())
            LabeledContent("Lowest heart rate", value: lowestHeartRateText())
            LabeledContent("Avg HRV", value: averageHRVText())
        }
    }

    private func timeToLowestHeartRateText() -> String {
        guard
            let sleepStart = metrics.sleepStart,
            let lowestTime = metrics.lowestHeartRateTime
        else {
            return "—"
        }
        let duration = max(lowestTime.timeIntervalSince(sleepStart), 0)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }

    private func lowestHeartRateText() -> String {
        guard let lowest = metrics.lowestHeartRate else { return "—" }
        let value = lowest.formatted(.number.precision(.fractionLength(0)))
        return "\(value) bpm"
    }

    private func averageHRVText() -> String {
        guard let average = metrics.averageHRV else { return "—" }
        let value = average.formatted(.number.precision(.fractionLength(0)))
        return "\(value) ms"
    }
}
