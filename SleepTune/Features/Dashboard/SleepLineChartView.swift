import Charts
import SwiftUI

struct SleepLineChartView: View {
    let series: SleepChartSeries

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(series.title)
                    .font(.subheadline)
                Spacer()
                Text(series.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(series.points, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.linearGradient(colors: [.cyan.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
    }
}
