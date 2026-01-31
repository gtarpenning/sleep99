struct SleepInsight: Identifiable, Hashable {
    let id: String
    var title: String
    var detail: String
    var impact: SleepInsightImpact
}
