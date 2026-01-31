import SwiftUI

struct FeelingCheckInView: View {
    @Binding var selectedFeeling: SleepFeeling?

    var body: some View {
        VStack(alignment: .leading) {
            Text("How did you feel this morning?")
                .font(.subheadline)
                .bold()

            Picker("Feeling", selection: feelingBinding) {
                Text("Skip").tag(Optional<SleepFeeling>.none)
                ForEach(SleepFeeling.allCases, id: \ .self) { feeling in
                    Text(feeling.rawValue.capitalized).tag(Optional(feeling))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var feelingBinding: Binding<SleepFeeling?> {
        Binding(
            get: { selectedFeeling },
            set: { selectedFeeling = $0 }
        )
    }
}
