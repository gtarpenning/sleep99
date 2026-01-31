import SwiftUI

struct TunedWeightsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Score Weights") {
                WeightSliderRowView(
                    title: "Duration",
                    value: Binding(
                        get: { viewModel.weights.duration },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: $0,
                            efficiency: viewModel.weights.efficiency,
                            consistency: viewModel.weights.consistency,
                            recovery: viewModel.weights.recovery,
                            architecture: viewModel.weights.architecture,
                            environment: viewModel.weights.environment,
                            behavior: viewModel.weights.behavior
                        )) }
                    )
                )

                WeightSliderRowView(
                    title: "Efficiency",
                    value: Binding(
                        get: { viewModel.weights.efficiency },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: viewModel.weights.duration,
                            efficiency: $0,
                            consistency: viewModel.weights.consistency,
                            recovery: viewModel.weights.recovery,
                            architecture: viewModel.weights.architecture,
                            environment: viewModel.weights.environment,
                            behavior: viewModel.weights.behavior
                        )) }
                    )
                )

                WeightSliderRowView(
                    title: "Consistency",
                    value: Binding(
                        get: { viewModel.weights.consistency },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: viewModel.weights.duration,
                            efficiency: viewModel.weights.efficiency,
                            consistency: $0,
                            recovery: viewModel.weights.recovery,
                            architecture: viewModel.weights.architecture,
                            environment: viewModel.weights.environment,
                            behavior: viewModel.weights.behavior
                        )) }
                    )
                )

                WeightSliderRowView(
                    title: "Recovery",
                    value: Binding(
                        get: { viewModel.weights.recovery },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: viewModel.weights.duration,
                            efficiency: viewModel.weights.efficiency,
                            consistency: viewModel.weights.consistency,
                            recovery: $0,
                            architecture: viewModel.weights.architecture,
                            environment: viewModel.weights.environment,
                            behavior: viewModel.weights.behavior
                        )) }
                    )
                )

                WeightSliderRowView(
                    title: "Architecture",
                    value: Binding(
                        get: { viewModel.weights.architecture },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: viewModel.weights.duration,
                            efficiency: viewModel.weights.efficiency,
                            consistency: viewModel.weights.consistency,
                            recovery: viewModel.weights.recovery,
                            architecture: $0,
                            environment: viewModel.weights.environment,
                            behavior: viewModel.weights.behavior
                        )) }
                    )
                )

                WeightSliderRowView(
                    title: "Environment",
                    value: Binding(
                        get: { viewModel.weights.environment },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: viewModel.weights.duration,
                            efficiency: viewModel.weights.efficiency,
                            consistency: viewModel.weights.consistency,
                            recovery: viewModel.weights.recovery,
                            architecture: viewModel.weights.architecture,
                            environment: $0,
                            behavior: viewModel.weights.behavior
                        )) }
                    )
                )

                WeightSliderRowView(
                    title: "Behavior",
                    value: Binding(
                        get: { viewModel.weights.behavior },
                        set: { viewModel.updateWeights(SleepScoreWeights(
                            duration: viewModel.weights.duration,
                            efficiency: viewModel.weights.efficiency,
                            consistency: viewModel.weights.consistency,
                            recovery: viewModel.weights.recovery,
                            architecture: viewModel.weights.architecture,
                            environment: viewModel.weights.environment,
                            behavior: $0
                        )) }
                    )
                )
            }
            .disabled(!viewModel.isEditingTunedWeights)
        }
        .navigationTitle("Tuned Weights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.isEditingTunedWeights ? "Done" : "Edit") {
                    viewModel.toggleTunedWeightsEditing()
                }
            }
        }
        .task {
            viewModel.setTunedWeightsEditing(false)
        }
    }
}
