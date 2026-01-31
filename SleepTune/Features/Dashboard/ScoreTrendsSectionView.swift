import Charts
import SwiftUI

struct ScoreTrendsSectionView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Trends")
                .font(.headline)

            Picker("Range", selection: $viewModel.trendRange) {
                ForEach(SleepScoreTrendRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .tint(.gray)
            .background(.gray.opacity(0.18), in: .rect(cornerRadius: 10))
            .onChange(of: viewModel.trendRange) { _, newValue in
                viewModel.updateTrendRange(newValue)
            }

            if viewModel.scoreHistory.isEmpty {
                Text("No trend data yet.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(viewModel.scoreHistory) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(.linearGradient(colors: [.blue.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
