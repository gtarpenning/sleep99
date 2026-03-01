import SwiftUI
import Foundation
import UIKit

// MARK: - Bin

struct DopplerBin: Sendable {
    var startDate: Date
    var isAsleep: Bool
    var awakeWeight: Double   // 0…1 (1 = fully awake)
    var movement: Double      // 0…1
    var hrDelta: Double       // 0…1 (deviation above nightly baseline)
    var hrvDelta: Double      // 0…1 (deviation below baseline = stressed)
    var stageDepth: Double    // 0…1 (deep=1, awake=0)
    var stage: SleepStage?

    /// 0 = bad/stressed/awake, 1 = excellent deep recovery
    var quality: Double {
        if awakeWeight >= 0.85 { return 0.0 }
        let q = stageDepth        * 0.35
              + (1 - hrDelta)     * 0.35   // more weight → bigger color shift with HR
              + (1 - hrvDelta)    * 0.20
              + (1 - awakeWeight) * 0.10
        return max(0, min(1, q))
    }
}

// MARK: - Color mapping

/// Maps quality 0…1 to a warm→cool color ramp.
/// 0.0 = hot orange (awake/stressed), 1.0 = cool indigo (deep/recovered)
func qualityColor(_ q: Double) -> Color {
    // Control points
    let stops: [(Double, Color)] = [
        (0.00, Color(red: 1.00, green: 0.33, blue: 0.10)), // hot orange
        (0.25, Color(red: 1.00, green: 0.62, blue: 0.04)), // amber
        (0.50, Color(red: 0.28, green: 0.32, blue: 0.52)), // dim blue-gray (transition)
        (0.75, Color(red: 0.31, green: 0.56, blue: 0.97)), // blue
        (1.00, Color(red: 0.48, green: 0.36, blue: 0.96)), // indigo
    ]
    let clamped = max(0, min(1, q))
    // Find surrounding stops
    for i in 0..<(stops.count - 1) {
        let (t0, c0) = stops[i]
        let (t1, c1) = stops[i + 1]
        if clamped <= t1 {
            let frac = (clamped - t0) / (t1 - t0)
            return lerpColor(c0, c1, t: frac)
        }
    }
    return stops.last!.1
}

private func lerpColor(_ a: Color, _ b: Color, t: Double) -> Color {
    let ta = t
    let ra = 1 - ta
    // Decompose via UIColor for reliable lerp
    var (r0, g0, b0, a0): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    UIColor(a).getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
    UIColor(b).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    return Color(
        red:   Double(r0 * ra + r1 * ta),
        green: Double(g0 * ra + g1 * ta),
        blue:  Double(b0 * ra + b1 * ta),
        opacity: Double(a0 * ra + a1 * ta)
    )
}

// MARK: - Bin builder

/// Builds 60-second bins from HealthKit stage + signal data. Safe to call off-main-thread.
func buildDopplerBins(
    stages: [SleepStageSample],
    heartRate: SleepChartSeries?,
    hrv: SleepChartSeries?,
    monthlyAvgHR: Double = 0,
    binSeconds: TimeInterval = 60
) -> [DopplerBin] {
    // Only include from first sleep to last sleep (trim leading/trailing in-bed)
    let sleepStages = stages.filter { $0.stage != .inBed }
    guard
        let start = sleepStages.map({ $0.startDate }).min(),
        let end   = sleepStages.map({ $0.endDate }).max(),
        end > start
    else { return [] }

    let hrPoints  = heartRate?.points.sorted { $0.date < $1.date } ?? []
    let hrvPoints = hrv?.points.sorted      { $0.date < $1.date } ?? []

    // Nightly baselines using values in the sleep window
    let windowHR  = hrPoints.filter  { $0.date >= start && $0.date <= end }.map { $0.value }
    let windowHRV = hrvPoints.filter { $0.date >= start && $0.date <= end }.map { $0.value }

    let hrSorted  = windowHR.sorted()
    let hrBaseline: Double  = hrSorted.isEmpty ? 60 : hrSorted[hrSorted.count / 2]
    // Use 10th percentile as "low baseline" — deviation above this is notable
    let hrLow: Double = hrSorted.isEmpty ? hrBaseline : hrSorted[max(0, hrSorted.count / 10)]
    let hrRange = max(hrBaseline - hrLow + 5, 5.0)

    let hrvSorted = windowHRV.sorted()
    let hrvBaseline: Double = hrvSorted.isEmpty ? 30 : hrvSorted[hrvSorted.count / 2]
    // Deviation below median = stressed
    let hrvRange = max(hrvBaseline * 0.5, 5.0)

    var bins: [DopplerBin] = []
    var t = start
    while t < end {
        let binEnd = t.addingTimeInterval(binSeconds)
        let binMid = t.addingTimeInterval(binSeconds / 2)

        let stage = stages.first { $0.startDate <= binMid && $0.endDate > binMid }?.stage

        let isAsleep: Bool = switch stage {
        case .asleepCore, .asleepDeep, .asleepREM, .asleep: true
        default: false
        }

        let awakeW: Double = switch stage {
        case .awake:      1.0
        case .inBed:      0.6
        case .asleep:     0.2
        case .asleepCore: 0.1
        case .asleepREM:  0.12
        case .asleepDeep: 0.0
        case nil:         0.5
        }

        let depth: Double = switch stage {
        case .asleepDeep: 1.00
        case .asleepREM:  0.85
        case .asleepCore: 0.65
        case .asleep:     0.55
        case .inBed:      0.20
        case .awake:      0.05
        case nil:         0.40
        }

        // HR delta: interpolate HR at bin midpoint (handles sparse ~5-min HealthKit samples).
        let hrDelta: Double
        let ref = monthlyAvgHR > 0 ? monthlyAvgHR : hrBaseline
        if let interpolated = interpolateHR(at: binMid, from: hrPoints) {
            hrDelta = min(max(0.5 + (interpolated - ref) / 20.0, 0), 1.0)
        } else {
            hrDelta = 0.5
        }

        // HRV delta: how far below baseline?
        let binHRV = hrvPoints.filter { $0.date >= t && $0.date < binEnd }.map { $0.value }
        let hrvDelta: Double
        if binHRV.isEmpty {
            hrvDelta = 0
        } else {
            let avg = binHRV.reduce(0, +) / Double(binHRV.count)
            hrvDelta = min(max(hrvBaseline - avg, 0) / hrvRange, 1.0)
        }

        bins.append(DopplerBin(
            startDate: t,
            isAsleep: isAsleep,
            awakeWeight: awakeW,
            movement: 0,
            hrDelta: hrDelta,
            hrvDelta: hrvDelta,
            stageDepth: depth,
            stage: stage
        ))
        t = binEnd
    }
    return bins
}

/// Linear interpolation of HR at a given date from sparse sorted samples.
/// Returns nil only if there are no samples at all.
private func interpolateHR(at date: Date, from points: [SleepChartPoint]) -> Double? {
    guard !points.isEmpty else { return nil }
    // Exact hit or find surrounding samples
    if let exact = points.first(where: { $0.date == date }) { return exact.value }
    let before = points.last  { $0.date <= date }
    let after  = points.first { $0.date >= date }
    switch (before, after) {
    case let (b?, a?) where b.date != a.date:
        let span = a.date.timeIntervalSince(b.date)
        let frac = date.timeIntervalSince(b.date) / span
        return b.value + (a.value - b.value) * frac
    case let (b?, nil): return b.value
    case let (nil, a?): return a.value
    default: return points.first?.value
    }
}

// MARK: - DopplerStripeView

struct DopplerStripeView: View {
    let bins: [DopplerBin]
    let score: Double
    var height: CGFloat = 36

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { ctx, size in
            drawStripe(ctx: ctx, size: size)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
        .background(DS.surfaceHigh, in: RoundedRectangle(cornerRadius: height / 2))
        .overlay(RoundedRectangle(cornerRadius: height / 2).strokeBorder(DS.border, lineWidth: 0.5))
        .accessibilityLabel("Sleep quality visualization. Score \(Int(score.rounded())).")
    }

    private func drawStripe(ctx: GraphicsContext, size: CGSize) {
        guard !bins.isEmpty else { return }

        let n = bins.count
        let binW = size.width / CGFloat(n)
        let midY = size.height / 2

        // Smooth both quality and hrDelta to avoid single-bin noise
        let smoothed = smoothQualities(bins: bins, radius: 2)
        let smoothedHR = smoothHRDeltas(bins: bins, radius: 2)

        for (i, bin) in bins.enumerated() {
            let q = smoothed[i]
            let hrD = smoothedHR[i]

            // Base quality color
            var color = qualityColor(q)

            // HR warmth override: linear blend toward red above nightly median.
            // hrD=0.5 = at baseline, hrD=1.0 = +10 bpm above baseline.
            let hrAbove = max(0, hrD - 0.5) * 2  // 0…1
            if hrAbove > 0 {
                let warmRed = Color(red: 1.0, green: 0.15, blue: 0.05)
                color = lerpColor(color, warmRed, t: min(hrAbove * 0.90, 0.90))
            }

            let xLeft = CGFloat(i) * binW
            let w = binW + 0.5 // slight overdraw to avoid hairline gaps

            let isAwake = bin.awakeWeight > 0.7
            let frac: CGFloat = isAwake ? 0.55 : CGFloat(0.65 + bin.stageDepth * 0.35)
            let barH = size.height * frac

            let rect = CGRect(
                x: xLeft,
                y: midY - barH / 2,
                width: w,
                height: barH
            )

            // Uniform alpha — don't let quality drive opacity or blue bins win twice
            let alpha: Double = isAwake ? 0.90 : 0.88

            ctx.fill(Path(rect), with: .color(color.opacity(alpha)))
        }

        // Stage boundary markers: tiny 1px white hairlines at stage transitions
        // helps orient where sleep zones are without cluttering
        var prevStage = bins.first?.stage
        for (i, bin) in bins.dropFirst().enumerated() {
            guard bin.stage != prevStage, bin.stage != nil else {
                prevStage = bin.stage
                continue
            }
            let x = CGFloat(i + 1) * binW
            let line = Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
            }
            ctx.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
            prevStage = bin.stage
        }
    }

    /// Rolling average over ±radius bins for smooth color transitions
    private func smoothQualities(bins: [DopplerBin], radius: Int) -> [Double] {
        let n = bins.count
        return (0..<n).map { i in
            let lo = max(0, i - radius)
            let hi = min(n - 1, i + radius)
            let slice = bins[lo...hi]
            return slice.map { $0.quality }.reduce(0, +) / Double(slice.count)
        }
    }

    private func smoothHRDeltas(bins: [DopplerBin], radius: Int) -> [Double] {
        let n = bins.count
        return (0..<n).map { i in
            let lo = max(0, i - radius)
            let hi = min(n - 1, i + radius)
            let slice = bins[lo...hi]
            return slice.map { $0.hrDelta }.reduce(0, +) / Double(slice.count)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Doppler Stripe") {
    let stages = MockSleepData.stages
    let hr = MockSleepData.heartRateSeries
    let hrv = MockSleepData.hrvSeries
    let bins = buildDopplerBins(stages: stages, heartRate: hr, hrv: hrv)
    return VStack(spacing: 24) {
        // Good night simulation (high quality bins)
        DopplerStripeView(bins: bins, score: 82, height: 36)
            .padding(.horizontal, 20)
        // Empty state
        DopplerStripeView(bins: [], score: 0, height: 36)
            .padding(.horizontal, 20)
    }
    .padding(.vertical, 40)
    .background(DS.bg)
    .colorScheme(.dark)
}
#endif
