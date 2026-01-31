import SwiftUI

struct ScoreComponentRowView: View {
    let component: SleepScoreComponent

    var body: some View {
        HStack {
            Text(component.name)
                .font(.footnote)
            Spacer()
            Text(component.contribution, format: .number.precision(.fractionLength(0)))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
