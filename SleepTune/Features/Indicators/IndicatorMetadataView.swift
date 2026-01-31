import SwiftUI

struct IndicatorMetadataView: View {
    let indicator: SleepIndicator

    var body: some View {
        VStack(alignment: .leading) {
            Text("Source")
                .font(.headline)

            Text(indicator.source.rawValue.capitalized)
                .foregroundStyle(.secondary)

            if let range = indicator.range {
                Text("Typical Range")
                    .font(.headline)

                Text("\(range.lowerBound, format: .number.precision(.fractionLength(1))) - \(range.upperBound, format: .number.precision(.fractionLength(1))) \(indicator.unit)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
