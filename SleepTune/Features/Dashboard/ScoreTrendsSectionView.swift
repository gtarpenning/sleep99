import Charts
import SwiftUI

struct ScoreTrendsSectionView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DSSectionHeader(title: "Trend")

            // Range picker
            Picker("Range", selection: $viewModel.trendRange) {
                ForEach(SleepScoreTrendRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
            .onChange(of: viewModel.trendRange) { _, newValue in
                viewModel.updateTrendRange(newValue)
            }

            if viewModel.scoreHistory.isEmpty {
                Text("Scores will appear here as you sync data.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textTertiary)
                    .frame(height: 120, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.scoreHistory) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(DS.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.purple.opacity(0.3), DS.purple.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DS.border)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.caption2)
                                    .foregroundStyle(DS.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 130)
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
    }
}
