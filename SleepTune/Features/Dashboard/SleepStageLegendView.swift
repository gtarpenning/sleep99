import SwiftUI

struct SleepStageLegendView: View {
    let stages: [SleepStageSample]

    var body: some View {
        let uniqueStages = Set(stages.map(\.stage)).sorted { $0.sortOrder < $1.sortOrder }
        if uniqueStages.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading) {
                Text("Stages")
                    .font(.subheadline)
                    .bold()
                HStack {
                    ForEach(uniqueStages, id: \.self) { stage in
                        HStack {
                            Rectangle()
                                .fill(stageColor(for: stage))
                                .frame(width: 8, height: 8)
                                .clipShape(.circle)
                            Text(stage.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func stageColor(for stage: SleepStage) -> Color {
        switch stage {
        case .inBed:
            return .gray.opacity(0.2)
        case .awake:
            return .orange.opacity(0.6)
        case .asleep:
            return .blue.opacity(0.4)
        case .asleepCore:
            return .blue.opacity(0.65)
        case .asleepDeep:
            return .indigo.opacity(0.75)
        case .asleepREM:
            return .purple.opacity(0.65)
        }
    }
}
