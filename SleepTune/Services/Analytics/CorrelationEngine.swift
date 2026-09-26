import Foundation

/// One curated relationship between two metrics, evaluated over recent nights.
struct CorrelationFinding: Identifiable, Sendable, Hashable {
    enum Strength: String, Sendable { case weak, moderate, strong }

    let x: TrendMetric
    let y: TrendMetric
    /// Nights the activity metric leads the sleep metric by (0 = same night / previous day).
    let lagNights: Int
    let r: Double
    let n: Int
    let pairs: [(Double, Double)]

    var id: String { "\(x.rawValue)-\(y.rawValue)-\(lagNights)" }
    var strength: Strength {
        let a = abs(r)
        return a >= 0.5 ? .strong : a >= 0.35 ? .moderate : .weak
    }

    /// "More steps → higher HRV (r = 0.41, 62 nights)"
    var headline: String {
        let dir = r > 0 ? "higher" : "lower"
        return "Higher \(x.title) → \(dir) \(y.title)"
    }
    var detail: String {
        let lag = lagNights == 0 ? "" : ", \(lagNights + 1) days later"
        return "r = \(r.formatted(.number.precision(.fractionLength(2)))) over \(n) nights\(lag)"
    }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id && a.r == b.r && a.n == b.n }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// Curated pairwise correlations. Spearman on nights where both values exist.
/// Only a fixed list of pairs is tested to keep multiple-comparison noise down.
enum CorrelationEngine {
    static let minNights = 20
    static let minAbsR = 0.25
    static let lags = [0, 1, 2]

    /// (driver, outcome). Drivers are previous-day activity or a sleep metric.
    static let pairs: [(TrendMetric, TrendMetric)] = [
        (.steps, .score), (.steps, .hrv), (.steps, .deep), (.steps, .sleepingHR),
        (.exercise, .score), (.exercise, .deep), (.exercise, .hrv), (.exercise, .sleepingHR),
        (.peakHR, .sleepingHR), (.peakHR, .hrv),
        (.vo2Max, .sleepingHR), (.vo2Max, .hrv),
        (.duration, .score), (.hrv, .score), (.sleepingHR, .score), (.respiratoryRate, .sleepingHR),
    ]

    static func compute(nights: [NightSummary]) -> [CorrelationFinding] {
        let sorted = nights.sorted { $0.night < $1.night }
        var out: [CorrelationFinding] = []
        for (x, y) in pairs {
            var best: CorrelationFinding?
            for lag in (x.isActivity ? lags : [0]) {
                guard let f = finding(x: x, y: y, lag: lag, nights: sorted) else { continue }
                if best == nil || abs(f.r) > abs(best!.r) { best = f }
            }
            if let best, abs(best.r) >= minAbsR { out.append(best) }
        }
        return out.sorted { abs($0.r) > abs($1.r) }
    }

    static func finding(x: TrendMetric, y: TrendMetric, lag: Int, nights: [NightSummary]) -> CorrelationFinding? {
        let byKey = Dictionary(nights.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let cal = Calendar.current
        var pairs: [(Double, Double)] = []
        for n in nights {
            guard let yv = y.value(from: n) else { continue }
            let xNight: NightSummary?
            if lag == 0 { xNight = n } else {
                guard let d = cal.date(byAdding: .day, value: -lag, to: n.night) else { continue }
                xNight = byKey[NightSummary.key(for: d)]
            }
            guard let xNight, let xv = x.value(from: xNight) else { continue }
            pairs.append((xv, yv))
        }
        guard pairs.count >= minNights,
              let r = TrendMath.spearman(pairs.map(\.0), pairs.map(\.1), minPairs: minNights) else { return nil }
        return CorrelationFinding(x: x, y: y, lagNights: lag, r: r, n: pairs.count, pairs: pairs)
    }

    /// Long-horizon fitness sentence: VO₂ max vs sleeping HR slopes over up to 90 nights.
    static func fitnessSentence(nights: [NightSummary]) -> String? {
        let recent = nights.sorted { $0.night < $1.night }.suffix(90)
        let vo2 = recent.compactMap { n in n.vo2Max.map { TrendPoint(date: n.night, value: $0) } }
        let hr = recent.compactMap { n in n.avgHR.map { TrendPoint(date: n.night, value: $0) } }
        guard vo2.count >= 20, hr.count >= 20,
              let v = TrendMath.linearTrend(vo2), let h = TrendMath.linearTrend(hr),
              abs(v.change) >= 0.8, abs(h.change) >= 1.5 else { return nil }
        let vDir = v.change > 0 ? "up" : "down", hDir = h.change > 0 ? "up" : "down"
        return "VO₂ max \(vDir) \(v.change.magnitude.formatted(.number.precision(.fractionLength(1)))) and sleeping HR \(hDir) \(Int(h.change.magnitude.rounded())) bpm over the last \(hr.count) nights."
    }
}
