import SwiftUI

struct LastNightScrubReadoutView: View {
    let selectedDate: Date
    let readings: [SleepSignalReading]

    var body: some View {
        VStack(alignment: .leading) {
            Text(selectedDate.formatted(.dateTime.hour().minute()))
                .font(.subheadline)
                .bold()

            ForEach(readings) { reading in
                HStack {
                    Text(reading.title)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(reading.value, format: .number.precision(.fractionLength(0))) \(reading.unit)")
                        .foregroundStyle(.primary)
                }
                .font(.caption)
            }
        }
    }
}
