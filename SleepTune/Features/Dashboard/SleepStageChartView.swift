import Charts
import SwiftUI

struct SleepStageChartView: View {
    let stages: [SleepStageSample]
    let xDomain: ClosedRange<Date>?

    var body: some View {
        let domain = resolvedDomain()
        Chart(stages, id: \.self) { sample in
            let yStart = Double(sample.stage.sortOrder) - 0.45
            let yEnd = Double(sample.stage.sortOrder) + 0.45

            RectangleMark(
                xStart: .value("Start", sample.startDate),
                xEnd: .value("End", sample.endDate),
                yStart: .value("Stage Start", yStart),
                yEnd: .value("Stage End", yEnd)
            )
            .foregroundStyle(stageColor(for: sample.stage))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: -0.5...5.5)
        .chartXScale(domain: domain)
    }

    private func stageColor(for stage: SleepStage) -> Color {
        switch stage {
        case .inBed:
            return .gray.opacity(0.2)
        case .awake:
            return .orange.opacity(0.6)
        case .asleep:
            return .blue.opacity(0.4)
        case .asleepCore:
            return .blue.opacity(0.65)
        case .asleepDeep:
            return .indigo.opacity(0.75)
        case .asleepREM:
            return .purple.opacity(0.65)
        }
    }

    private func resolvedDomain() -> ClosedRange<Date> {
        if let xDomain {
            return xDomain
        }
        guard let minStart = stages.map(\.startDate).min(),
              let maxEnd = stages.map(\.endDate).max()
        else {
            let now = Date()
            return now...now
        }
        return minStart...maxEnd
    }
}
