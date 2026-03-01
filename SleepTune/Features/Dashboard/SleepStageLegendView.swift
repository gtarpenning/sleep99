import SwiftUI

struct SleepStageLegendView: View {
    let stages: [SleepStageSample]

    var body: some View {
        let uniqueStages = Set(stages.map(\.stage)).sorted { $0.sortOrder < $1.sortOrder }
        if uniqueStages.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(uniqueStages, id: \.self) { stage in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DS.stageColor(for: stage))
                                .frame(width: 10, height: 6)
                            Text(stage.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.textSecondary)
                        }
                    }
                }
            }
        )
    }
}
