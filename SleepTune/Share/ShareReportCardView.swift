import SwiftUI

struct ShareReportCardView: View {
    let summary: SleepScoreSummary

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sleep Tune")
                .textCase(.uppercase)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(summary.score, format: .number.precision(.fractionLength(0)))
                .font(.largeTitle)
                .bold()

            Text("Sleep Score")
                .foregroundStyle(.secondary)

            Divider()

            ForEach(summary.components, id: \ .name) { component in
                HStack {
                    Text(component.name)
                    Spacer()
                    Text(component.contribution, format: .number.precision(.fractionLength(0)))
                }
                .font(.footnote)
            }

            Text(summary.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 24))
        .padding()
    }
}
