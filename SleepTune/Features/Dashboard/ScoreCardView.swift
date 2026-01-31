import SwiftUI

struct ScoreCardView: View {
    let summary: SleepScoreSummary

    var body: some View {
        VStack(alignment: .leading) {
            Text("Last Night")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline) {
                Text(summary.score, format: .number.precision(.fractionLength(0)))
                    .font(.largeTitle)
                    .bold()
                Text("Score")
                    .foregroundStyle(.secondary)
            }

            Text(summary.note)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScoreComponentListView(components: summary.components)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}
