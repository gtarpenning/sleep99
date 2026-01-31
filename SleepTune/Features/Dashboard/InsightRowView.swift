import SwiftUI

struct InsightRowView: View {
    let insight: SleepInsight

    var body: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading) {
                Text(insight.title)
                    .bold()
                Text(insight.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var indicatorColor: Color {
        switch insight.impact {
        case .positive:
            return .green
        case .negative:
            return .red
        case .neutral:
            return .gray
        }
    }
}
