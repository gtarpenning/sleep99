import WidgetKit
import SwiftUI
import Charts

// MARK: - Shared snapshot model
//
// Mirrors `WidgetSnapshot`/`WidgetSnapshotStore` in the main app. Both read/write
// the same App Group UserDefaults suite (`group.com.sleep-tune.app`). Keep the
// Codable shape of these structs identical to the app's copy.

struct WidgetStageSpan: Codable, Equatable, Hashable {
    let stage: Int   // 0 inBed · 1 deep · 2 core · 3 rem · 4 awake
    let x0: Double
    let x1: Double
}

struct WidgetLinePoint: Codable, Equatable, Hashable {
    let x: Double
    let y: Double
}

struct WidgetSnapshot: Codable, Equatable {
    let updatedAt: Date
    let score: Double
    let sleepScore: Double
    let recoveryScore: Double
    let totalSleepMinutes: Int
    var stages: [WidgetStageSpan]? = nil
    var hr: [WidgetLinePoint]? = nil
    var hrv: [WidgetLinePoint]? = nil
    var rr: [WidgetLinePoint]? = nil
}

private enum SharedStore {
    static let appGroup = "group.com.sleep-tune.app"
    static let key = "widgetSnapshot.v1"

    static func load() -> WidgetSnapshot? {
        let defaults = UserDefaults(suiteName: appGroup) ?? .standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

// MARK: - Colors (self-contained; mirror the app's design system)

// Slightly brighter than system `.secondary` for the small gray labels.
private let labelGray = Color(white: 0.74)

private let hrColor  = Color(red: 1.00, green: 0.42, blue: 0.42)
private let hrvColor = Color(red: 0.22, green: 1.00, blue: 0.42)
private let rrColor  = Color(red: 0.15, green: 0.85, blue: 0.88)

private func stageColor(_ order: Int) -> Color {
    switch order {
    case 0:  return Color(red: 0.145, green: 0.145, blue: 0.208)                 // In Bed
    case 1:  return Color(red: 0.482, green: 0.361, blue: 0.965).opacity(0.80)   // Deep
    case 2:  return Color(red: 0.310, green: 0.557, blue: 0.969).opacity(0.70)   // Core
    case 3:  return Color(red: 0.659, green: 0.333, blue: 0.969).opacity(0.78)   // REM
    case 4:  return Color(red: 1.000, green: 0.420, blue: 0.208).opacity(0.75)   // Awake
    default: return Color(red: 0.310, green: 0.557, blue: 0.969).opacity(0.55)
    }
}

private func scoreColor(_ v: Double) -> Color {
    switch v {
    case ..<55: return Color(red: 1.0, green: 0.35, blue: 0.35)
    case ..<70: return .orange
    case ..<85: return .yellow
    default:    return Color(red: 0.30, green: 0.86, blue: 0.46)
    }
}

private func sleepLabel(minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

// MARK: - Timeline

struct ScoreEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScoreEntry {
        ScoreEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        completion(ScoreEntry(date: Date(), snapshot: SharedStore.load() ?? Self.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        let entry = ScoreEntry(date: Date(), snapshot: SharedStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // A gentle synthetic night for placeholders / gallery preview.
    static var sample: WidgetSnapshot {
        let stages: [WidgetStageSpan] = [
            .init(stage: 0, x0: 0.00, x1: 0.04), .init(stage: 2, x0: 0.04, x1: 0.18),
            .init(stage: 1, x0: 0.18, x1: 0.30), .init(stage: 2, x0: 0.30, x1: 0.44),
            .init(stage: 3, x0: 0.44, x1: 0.54), .init(stage: 2, x0: 0.54, x1: 0.66),
            .init(stage: 4, x0: 0.66, x1: 0.68), .init(stage: 2, x0: 0.68, x1: 0.80),
            .init(stage: 3, x0: 0.80, x1: 0.92), .init(stage: 2, x0: 0.92, x1: 1.00),
        ]
        func wave(_ phase: Double, _ amp: Double, _ mid: Double) -> [WidgetLinePoint] {
            (0...40).map { i in
                let x = Double(i) / 40
                return WidgetLinePoint(x: x, y: mid + amp * sin(x * 6.28 * 1.5 + phase))
            }
        }
        return WidgetSnapshot(
            updatedAt: Date(), score: 81, sleepScore: 84, recoveryScore: 96, totalSleepMinutes: 391,
            stages: stages, hr: wave(0, 0.32, 0.45), hrv: wave(1.6, 0.22, 0.6), rr: wave(3.1, 0.14, 0.4)
        )
    }
}

// MARK: - Entry view

struct ScoreWidgetEntryView: View {
    var entry: ScoreProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    // MARK: Small — score + clear duration + stage composition bar

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(labelGray)
                Text("SLEEP")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(labelGray)
            }

            if let s = entry.snapshot {
                Text("\(Int(s.score.rounded()))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(s.score))
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(labelGray)
                    Text(sleepLabel(minutes: s.totalSleepMinutes))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 6)

                stageBar(s.stages ?? [], height: 7)

                HStack(spacing: 10) {
                    subScore("Sleep", s.sleepScore)
                    subScore("Rec", s.recoveryScore)
                }
                .padding(.top, 6)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.black }
    }

    // MARK: Medium — score column + last-night stage chart with overlaid lines

    private var mediumView: some View {
        HStack(spacing: 14) {
            if let s = entry.snapshot {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SLEEP")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(labelGray)
                    Text("\(Int(s.score.rounded()))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(s.score))
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(labelGray)
                        Text(sleepLabel(minutes: s.totalSleepMinutes))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 6)
                    subScore("Sleep", s.sleepScore)
                        .padding(.bottom, 3)
                    subScore("Recover", s.recoveryScore)
                }
                .frame(width: 92, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    LastNightChart(snapshot: s)
                    legend
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.black }
    }

    // MARK: Pieces

    private var legend: some View {
        HStack(spacing: 10) {
            legendDot("HR", hrColor)
            legendDot("HRV", hrvColor)
            legendDot("RR", rrColor)
            Spacer(minLength: 0)
        }
    }

    private func legendDot(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(labelGray)
        }
    }

    private func subScore(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(labelGray)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("\(Int(value.rounded()))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(value))
                .monospacedDigit()
        }
    }

    /// Flat colored timeline of sleep stages (a mini hypnogram).
    private func stageBar(_ spans: [WidgetStageSpan], height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                ForEach(spans, id: \.self) { span in
                    Rectangle()
                        .fill(stageColor(span.stage))
                        .frame(width: max(1, geo.size.width * (span.x1 - span.x0)))
                        .offset(x: geo.size.width * span.x0)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("—")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(labelGray)
            Text("Open SleepTune")
                .font(.caption2)
                .foregroundStyle(labelGray)
        }
    }
}

// MARK: - Last-night chart (stage bands + normalized signal lines)

private struct LastNightChart: View {
    let snapshot: WidgetSnapshot

    private var spans: [WidgetStageSpan] { snapshot.stages ?? [] }

    private var stageYDomain: ClosedRange<Double> {
        let orders = spans.map { Double($0.stage) }.filter { $0 != 0 }
        let lo = (orders.min() ?? 1) - 0.5
        let hi = (orders.max() ?? 4) + 0.5
        return lo...hi
    }

    private var lines: [(String, Color, [WidgetLinePoint])] {
        [("HR", hrColor, snapshot.hr ?? []),
         ("HRV", hrvColor, snapshot.hrv ?? []),
         ("RR", rrColor, snapshot.rr ?? [])]
            .filter { !$0.2.isEmpty }
    }

    var body: some View {
        ZStack {
            // Stage bands
            Chart(spans, id: \.self) { span in
                RectangleMark(
                    xStart: .value("s", span.x0),
                    xEnd:   .value("e", span.x1),
                    yStart: .value("ys", Double(span.stage) - 0.45),
                    yEnd:   .value("ye", Double(span.stage) + 0.45)
                )
                .foregroundStyle(stageColor(span.stage))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...1)
            .chartYScale(domain: stageYDomain)

            // Overlaid signal lines (each pre-normalized 0…1)
            Chart {
                ForEach(lines, id: \.0) { title, color, pts in
                    ForEach(pts, id: \.self) { p in
                        LineMark(
                            x: .value("x", p.x),
                            y: .value("y", p.y),
                            series: .value("s", title)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .foregroundStyle(color)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...1)
            .chartYScale(domain: -0.08...1.08)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Widget definition

struct ScoreWidget: Widget {
    let kind: String = "ScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScoreProvider()) { entry in
            ScoreWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sleep Score")
        .description("Your latest sleep score, time asleep, and last night's stages.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SleepTuneWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScoreWidget()
    }
}
