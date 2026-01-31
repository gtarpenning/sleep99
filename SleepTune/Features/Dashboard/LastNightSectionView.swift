import SwiftUI

struct LastNightSectionView: View {
    let stages: [SleepStageSample]
    let heartRate: SleepChartSeries?
    let hrv: SleepChartSeries?
    let respiratoryRate: SleepChartSeries?
    let metrics: LastNightMetrics

    var body: some View {
        VStack(alignment: .leading) {
            Text("Last night")
                .font(.headline)

            LastNightMetricsView(metrics: metrics)

            SleepStagesOverlayChartView(
                stages: stages,
                heartRate: heartRate,
                hrv: hrv,
                respiratoryRate: respiratoryRate
            )
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
