import Charts
import SwiftUI

struct SleepStageChartView: View {
    let stages: [SleepStageSample]
    let xDomain: ClosedRange<Date>?

    var body: some View {
        let domain = resolvedDomain()
        Chart(stages, id: \.self) { sample in
            let yStart = Double(sample.stage.sortOrder) - 0.45
            let yEnd   = Double(sample.stage.sortOrder) + 0.45
            RectangleMark(
                xStart: .value("Start", sample.startDate),
                xEnd:   .value("End",   sample.endDate),
                yStart: .value("Stage Start", yStart),
                yEnd:   .value("Stage End",   yEnd)
            )
            .foregroundStyle(DS.stageColor(for: sample.stage))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain())
        .chartXScale(domain: domain)
        .background(DS.surfaceHigh, in: RoundedRectangle(cornerRadius: 12))
    }

    private func yDomain() -> ClosedRange<Double> {
        let orders = stages
            .filter { $0.stage != .inBed }
            .map { Double($0.stage.sortOrder) }
        let lo = (orders.min() ?? 1) - 0.5
        let hi = (orders.max() ?? 4) + 0.5
        return lo...hi
    }

    private func resolvedDomain() -> ClosedRange<Date> {
        if let xDomain { return xDomain }
        guard let min = stages.map(\.startDate).min(),
              let max = stages.map(\.endDate).max() else {
            let now = Date(); return now...now
        }
        return min...max
    }
}

