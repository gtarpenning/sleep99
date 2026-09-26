import SwiftUI

/// Compact card: 14-night weighted sleep debt against the user's personal
/// need, a ledger sparkline, and a trend. Tapping opens the detail sheet.
struct SleepDebtCardView: View {
    let summary: SleepDebtSummary
    @State private var showsDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSSectionHeader(title: "Sleep Debt")
                .padding(.horizontal, 20)

            Button {
                showsDetail = true
            } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(SleepDebt.summaryText(for: summary))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(severityColor)
                                .monospacedDigit()
                            Text("· target under \(SleepDebt.hoursText(SleepDebt.targetDebt))")
                                .font(.caption2)
                                .foregroundStyle(DS.textTertiary)
                        }
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                    }

                    Spacer(minLength: 0)

                    SleepDebtLedgerView(ledger: summary.ledger)
                        .frame(width: 84, height: 30)

                    stat(value: trendSymbol, unit: trendLabel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .dsCard(16)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showsDetail) {
            SleepDebtDetailSheet(summary: summary)
        }
    }

    private func stat(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
    }

    private var subtitle: String {
        let needText = SleepDebt.hoursText(summary.need)
        if summary.recoveryStreak >= 2, summary.ledgerDebt >= SleepDebt.targetDebt * 0.6 {
            return summary.recoveryStreak >= 3
                ? "\(summary.recoveryStreak) nights on target · debt cleared"
                : "\(summary.recoveryStreak) nights on target · recovering"
        }
        switch summary.severity {
        case .low:      return "Well rested · need \(needText)"
        case .mild:     return "A little behind your \(needText) need"
        case .moderate: return "Behind your \(needText) need"
        case .high:     return "Well behind — prioritize sleep"
        }
    }

    private var trendSymbol: String {
        switch summary.trend {
        case .improving: return "↓"
        case .steady:    return "→"
        case .worsening: return "↑"
        }
    }

    private var trendLabel: String {
        switch summary.trend {
        case .improving: return "recovering"
        case .steady:    return "steady"
        case .worsening: return "growing"
        }
    }

    private var severityColor: Color { SleepDebtStyle.color(for: summary.severity) }
}

enum SleepDebtStyle {
    static func color(for severity: SleepDebtSummary.Severity) -> Color {
        switch severity {
        case .low:      return DS.green
        case .mild:     return Color(red: 0.95, green: 0.77, blue: 0.06)
        case .moderate: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .high:     return .red.opacity(0.9)
        }
    }
}

// MARK: - Ledger sparkline

/// One bar per night: above the midline = surplus, below = shortfall.
struct SleepDebtLedgerView: View {
    let ledger: [SleepDebtLedgerEntry]

    var body: some View {
        let maxAbs = Swift.max(ledger.map { abs($0.delta) }.max() ?? 1, 1)
        HStack(alignment: .center, spacing: 2) {
            ForEach(ledger) { e in
                let frac = Swift.min(1, abs(e.delta) / maxAbs)
                let isShort = e.delta > 0.1
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isShort ? Color.clear : DS.green.opacity(0.8))
                        .frame(height: isShort ? 0 : Swift.max(2, 14 * frac))
                    Rectangle().fill(DS.border).frame(height: 1)
                    Rectangle()
                        .fill(isShort ? Color.red.opacity(0.75) : Color.clear)
                        .frame(height: isShort ? Swift.max(2, 14 * frac) : 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Detail sheet

struct SleepDebtDetailSheet: View {
    let summary: SleepDebtSummary

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headline
                        explainer
                        ledgerTable
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Sleep Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseButton() } }
        }
        .presentationDetents([.fraction(0.9), .large])
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SleepDebt.summaryText(for: summary))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(SleepDebtStyle.color(for: summary.severity))
            Text("Weighted over the last \(summary.nightsCounted) nights · target under \(SleepDebt.hoursText(SleepDebt.targetDebt))")
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "How it's measured")
            Text("Your need of \(SleepDebt.hoursText(summary.need)) is the 75th percentile of your sleep during your best-rested two weeks. Each night's hours are discounted for low efficiency or thin deep + REM sleep, and a hard training day adds up to 30 minutes of need. Last night counts 15 %, older nights fade over two weeks. Sleeping past your need repays at half rate, except on a recovery streak: two nights on target cuts the debt to 30 %, three or more clears it to 10 %, and any surplus on those nights repays in full. One short night breaks the streak.")
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
        }
    }

    private var ledgerTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "Last 14 nights", trailing: "vs need")
            VStack(spacing: 0) {
                ForEach(summary.ledger.reversed()) { e in
                    HStack {
                        Text(e.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.footnote)
                            .foregroundStyle(DS.textPrimary)
                        Spacer()
                        Text(e.hours.formatted(.number.precision(.fractionLength(1))) + "h")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(DS.textSecondary)
                        Text(deltaText(e.delta))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(e.delta > 0.1 ? .red.opacity(0.85) : DS.green)
                            .frame(width: 56, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(DS.border)
                }
            }
            .padding(.horizontal, 14)
            .dsCard(14)
        }
    }

    private func deltaText(_ d: Double) -> String {
        let v = (abs(d) * 10).rounded() / 10
        return (d > 0.1 ? "−" : "+") + v.formatted(.number.precision(.fractionLength(1))) + "h"
    }
}
