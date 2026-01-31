import SwiftUI

struct InsightsSectionView: View {
    let insights: [SleepInsight]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Insights")
                .font(.headline)

            ForEach(insights) { insight in
                InsightRowView(insight: insight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
