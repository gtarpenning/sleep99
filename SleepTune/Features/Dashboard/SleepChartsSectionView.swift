import SwiftUI

struct SleepChartsSectionView: View {
    let series: [SleepChartSeries]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Trends")
                .font(.headline)

            ForEach(series, id: \ .title) { series in
                SleepLineChartView(series: series)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
