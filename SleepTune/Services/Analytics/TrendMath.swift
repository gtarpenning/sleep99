import Foundation

/// A dated value for trend charts.
struct TrendPoint: Hashable, Sendable, Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Pure aggregation helpers for long-range charts. No SwiftUI, fully testable.
enum TrendMath {

    /// Centre-less trailing rolling mean over `window` points (uses whatever is
    /// available at the start, so the line begins at the first point).
    static func rollingMean(_ points: [TrendPoint], window: Int) -> [TrendPoint] {
        guard window > 1, !points.isEmpty else { return points }
        let sorted = points.sorted { $0.date < $1.date }
        var out: [TrendPoint] = []
        var sum = 0.0
        var queue: [Double] = []
        for p in sorted {
            queue.append(p.value); sum += p.value
            if queue.count > window { sum -= queue.removeFirst() }
            out.append(TrendPoint(date: p.date, value: sum / Double(queue.count)))
        }
        return out
    }

    /// Mean per calendar month, dated at the first of the month.
    static func monthlyBuckets(_ points: [TrendPoint], calendar: Calendar = .current) -> [TrendPoint] {
        var sums: [Date: (sum: Double, n: Int)] = [:]
        for p in points {
            guard let start = calendar.dateInterval(of: .month, for: p.date)?.start else { continue }
            let e = sums[start] ?? (0, 0)
            sums[start] = (e.sum + p.value, e.n + 1)
        }
        return sums.map { TrendPoint(date: $0.key, value: $0.value.sum / Double($0.value.n)) }
            .sorted { $0.date < $1.date }
    }

    /// Mean per weekday (1 = Sunday … 7 = Saturday), keyed by the calendar's weekday index.
    static func weekdayAverages(_ points: [TrendPoint], calendar: Calendar = .current) -> [Int: (avg: Double, n: Int)] {
        var sums: [Int: (Double, Int)] = [:]
        for p in points {
            let wd = calendar.component(.weekday, from: p.date)
            let e = sums[wd] ?? (0, 0)
            sums[wd] = (e.0 + p.value, e.1 + 1)
        }
        return sums.mapValues { ($0.0 / Double($0.1), $0.1) }
    }

    static func mean(_ points: [TrendPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    /// Least-squares slope in value-per-day, plus the total change over the span.
    static func linearTrend(_ points: [TrendPoint]) -> (slopePerDay: Double, change: Double)? {
        guard points.count >= 3, let first = points.map(\.date).min() else { return nil }
        let xs = points.map { $0.date.timeIntervalSince(first) / 86_400 }
        let ys = points.map(\.value)
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in xs.indices { num += (xs[i] - mx) * (ys[i] - my); den += (xs[i] - mx) * (xs[i] - mx) }
        guard den > 0 else { return nil }
        let slope = num / den
        let span = (xs.max() ?? 0) - (xs.min() ?? 0)
        return (slope, slope * span)
    }

    /// Pearson correlation of two aligned series. nil below `minPairs`.
    static func pearson(_ xs: [Double], _ ys: [Double], minPairs: Int = 10) -> Double? {
        guard xs.count == ys.count, xs.count >= minPairs else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var num = 0.0, dx = 0.0, dy = 0.0
        for i in xs.indices {
            let a = xs[i] - mx, b = ys[i] - my
            num += a * b; dx += a * a; dy += b * b
        }
        guard dx > 0, dy > 0 else { return nil }
        return num / (dx * dy).squareRoot()
    }

    /// Spearman rank correlation (Pearson on average ranks).
    static func spearman(_ xs: [Double], _ ys: [Double], minPairs: Int = 10) -> Double? {
        guard xs.count == ys.count, xs.count >= minPairs else { return nil }
        return pearson(ranks(xs), ranks(ys), minPairs: minPairs)
    }

    static func ranks(_ values: [Double]) -> [Double] {
        let indexed = values.enumerated().sorted { $0.element < $1.element }
        var ranks = [Double](repeating: 0, count: values.count)
        var i = 0
        while i < indexed.count {
            var j = i
            while j + 1 < indexed.count, indexed[j + 1].element == indexed[i].element { j += 1 }
            let avg = Double(i + j) / 2 + 1
            for k in i...j { ranks[indexed[k].offset] = avg }
            i = j + 1
        }
        return ranks
    }
}
