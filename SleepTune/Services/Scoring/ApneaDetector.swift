import Foundation

/// A respiratory-rate spike that may indicate an apnea event.
/// Apnea typically presents as a brief cessation followed by hyperventilation —
/// we detect the latter (the post-event RR spike) since cessation is harder to
/// see in coarse Apple Health samples.
struct ApneaEvent: Equatable, Sendable {
    let date: Date
    /// Peak RR value during this event (br/min).
    let value: Double
    /// User's baseline mean RR for the night (br/min).
    let baseline: Double
    /// Standard deviations above the baseline. ≥ 2σ is the typical clinical threshold.
    let sigmasAboveBaseline: Double

    var deltaAboveBaseline: Double { value - baseline }
}

enum ApneaDetector {
    /// Detect apnea-suggestive RR spikes in a sorted-by-time series.
    ///
    /// Algorithm:
    ///   1. Compute the mean and standard deviation of all RR samples for the night.
    ///   2. Flag any point >= max(mean + 2σ, mean + 3 br/min).
    ///      The absolute floor of +3 br/min protects against high-noise nights where
    ///      σ is small and 2σ alone would fire on benign variation.
    ///   3. Cluster flagged points within `clusteringWindow` seconds into a single
    ///      event (the highest-magnitude point in each cluster) so the user sees one
    ///      marker per apnea episode, not a cloud of dots.
    ///
    /// - Parameters:
    ///   - points: RR samples for the sleep window, in br/min.
    ///   - minSpikeAboveBaseline: absolute floor in br/min (default 3.0).
    ///   - sigmaMultiplier: statistical floor in σ (default 2.0).
    ///   - clusteringWindow: events within this many seconds collapse into one
    ///     (default 15 min — typical post-apnea recovery breathing window).
    static func detect(
        in points: [SleepChartPoint],
        minSpikeAboveBaseline: Double = 3.0,
        sigmaMultiplier: Double = 2.0,
        clusteringWindow: TimeInterval = 15 * 60
    ) -> [ApneaEvent] {
        guard points.count >= 5 else { return [] }
        let sorted = points.sorted { $0.date < $1.date }
        let values = sorted.map(\.value)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { acc, v in acc + (v - mean) * (v - mean) } / Double(values.count)
        let stdev = variance.squareRoot()

        let threshold = Swift.max(mean + sigmaMultiplier * stdev, mean + minSpikeAboveBaseline)

        // Step 1: flag every point above threshold.
        let flagged = sorted.filter { $0.value >= threshold }
        guard !flagged.isEmpty else { return [] }

        // Step 2: collapse consecutive flagged points within clusteringWindow
        // into a single event represented by the cluster's peak.
        var clusters: [[SleepChartPoint]] = [[flagged[0]]]
        for point in flagged.dropFirst() {
            if let last = clusters.last?.last,
               point.date.timeIntervalSince(last.date) <= clusteringWindow {
                clusters[clusters.count - 1].append(point)
            } else {
                clusters.append([point])
            }
        }

        return clusters.compactMap { cluster -> ApneaEvent? in
            guard let peak = cluster.max(by: { $0.value < $1.value }) else { return nil }
            let sigmas = stdev > 0 ? (peak.value - mean) / stdev : 0
            return ApneaEvent(date: peak.date, value: peak.value, baseline: mean, sigmasAboveBaseline: sigmas)
        }
    }
}
