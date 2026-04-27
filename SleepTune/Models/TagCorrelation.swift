import Foundation

struct MetricImpact: Identifiable, Codable {
    var id: String { metricName }
    let metricName: String
    let unit: String
    let taggedAvg: Double
    let baselineAvg: Double
    let lowerIsBetter: Bool

    var delta: Double { taggedAvg - baselineAvg }
    var isHarmful: Bool { lowerIsBetter ? delta > 0 : delta < 0 }
}

struct TagCorrelation: Identifiable {
    var id: String { tag.id.uuidString }
    let tag: SleepTag
    let taggedNights: Int
    let avgScoreTagged: Double
    let avgScoreBaseline: Double
    let metricImpacts: [MetricImpact]

    var scoreDelta: Double { avgScoreTagged - avgScoreBaseline }
}
