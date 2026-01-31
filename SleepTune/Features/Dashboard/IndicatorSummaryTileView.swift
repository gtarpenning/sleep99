import SwiftUI

struct IndicatorSummaryTileView: View {
    let indicator: SleepIndicator

    var body: some View {
        VStack(alignment: .leading) {
            Text(indicator.name)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("\(indicator.value, format: .number.precision(.fractionLength(1))) \(indicator.unit)")
                .bold()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }
}
