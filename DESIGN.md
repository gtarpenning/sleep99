# SleepTune — Design Document v2.0
**Pivot: Oura-like Sleep Score + Family View**
_Last updated: 2026-02-28_

---

## Vision

A single source of truth for sleep quality — pulling data from Apple Watch, Whoop, and Oura Ring (all via Apple Health) — that surfaces an Oura-style rich sleep score with a breakdown, and lets families share and compare their scores in real time.

**Core pillars:**
1. **Authoritative sleep score** — rich, explainable, device-agnostic
2. **Family/group feed** — see everyone's scores at a glance
3. **Drill-down** — tap anyone and see their full dashboard

---

## Target User

- Health-conscious Apple users who own one or more wearables (Apple Watch, Whoop, Oura)
- Families or households that want a shared wellness check-in
- People frustrated that Oura/Whoop scores differ from Apple Health summaries

---

## What Gets Ripped Out

| Feature | Disposition | Reason |
|---|---|---|
| Tunable score weights (SettingsView → TunedWeightsView) | **Remove** | Complexity without user value at MVP; score should just be "correct" |
| FeelingCheckInView (mood modifier) | **Remove** | Removes objectivity from score; move to qualitative journal later |
| IndicatorValueEditorView / manual overrides | **Remove** | Users shouldn't manually tune inputs |
| Insight generation (hardcoded rules) | **Defer** | Keep the model, gut the hardcoded rules for now |
| Share card / ShareViewModel | **Defer** | Nice-to-have post-MVP |
| SyncCoordinator / analytics pipeline | **Replace** | Repurpose file persistence layer for family sync; remove analytics HTTP posting |
| In-memory store | **Replace** | Needs real persistence (UserDefaults for prefs, CloudKit for family data) |
| Stub auth (isSignedIn, logIn, logOut) | **Replace** | Need real Sign in with Apple + CloudKit identity |
| Disabled appearance toggles | **Remove** | Dead UI |

---

## What Gets Kept / Repurposed

| Feature | Disposition |
|---|---|
| HealthKitClient | **Keep** — expand for multi-source awareness |
| SleepScoreEngine | **Keep** — refactor weights to reflect new metric set |
| All data models (SleepIndicator, SleepStage, etc.) | **Keep** — solid foundation |
| ScoreCardView | **Keep** — becomes the Oura-style hero card |
| SleepStagesOverlayChartView | **Keep** — core visualization |
| SignalOverlayChartView | **Keep** — HR, HRV, RR charts |
| ScoreTrendsSectionView | **Keep** |
| DashboardViewModel skeleton | **Refactor** |
| AppContainer DI pattern | **Keep** |
| MVVM + async/await architecture | **Keep** |
| NavigationStack routing | **Keep** |

---

## Score Methodology

### Inputs (from Apple Health, device-agnostic)

**Sleep Architecture (35%)**
- Total sleep duration (vs. personal baseline / population norms)
- Sleep efficiency (sleep / time in bed)
- REM % (target ~20-25%)
- Deep sleep % (target ~15-20%)
- Awakenings count + duration
- Sleep latency

**Recovery (40%)**
- Average overnight heart rate (lower = better, relative to resting)
- Lowest overnight heart rate (proxy for parasympathetic recovery)
- Time to lowest HR (earlier in the night = better)
- Average HRV (SDNN)
- HRV trend vs. 30-day baseline
- Average respiratory rate
- Min respiratory rate
- Blood oxygen saturation (SpO2)
- Wrist skin temperature deviation

**Consistency (15%)**
- Sleep start time variance (vs. 7-day average)
- Wake time variance
- Midpoint consistency

**Context / Confounders (10% — applied as modifiers, not direct score)**
- Prior day active energy (high activity → may lower HR targets)
- Exercise within 3h of bedtime (penalizes recovery)
- Alcohol proxy (elevated RR + HR combo pattern)

### Multi-Device Strategy (naive case)
- Pull all samples from Apple Health regardless of source
- When multiple sources provide the same metric (e.g., HR from Whoop and Apple Watch), prefer the source with the most samples in the sleep window; log source used
- Display source attribution per metric in the breakdown UI
- Future: per-metric calibration coefficients stored in CloudKit user record

### Score Display (Oura-style)
```
[Large Score Number]   e.g. "83"
[Color ring / arc]     green > 85, yellow 70-85, red < 70
[Label]                "Good" / "Fair" / "Poor"

Breakdown cards (horizontal scroll or stacked):
  Sleep          [score] [bar]
  Recovery       [score] [bar]
  Consistency    [score] [bar]

Then expandable detail rows per metric.
```

---

## App Architecture

### Navigation Structure (New)
```
AppRootView
├── Tab 1: My Sleep (SleepDashboardView)          ← Oura-style main view
│   ├── ScoreHeroView                             ← large score + ring
│   ├── ScoreBreakdownView                        ← Sleep / Recovery / Consistency cards
│   ├── SleepStagesChartView                      ← hypnogram
│   ├── SignalsChartView                          ← HR, HRV, RR overlay
│   ├── MetricDetailListView                      ← expandable rows
│   └── ScoreTrendView                            ← week/month/year
│
├── Tab 2: Family (FamilyFeedView)                ← NEW
│   ├── FamilyMemberRowView[]                     ← avatar, name, score badge, trend arrow
│   └── → FamilyMemberDashboardView               ← same as Tab 1 but for them
│
└── Tab 3: Settings (SettingsView)
    ├── HealthConnectionRowView
    ├── FamilyManagementView                      ← NEW: invite, remove members
    └── AccountView                               ← Sign in with Apple
```

### Data Flow
```
Apple Health
    ↓
HealthKitClient (async fetch, multi-source aware)
    ↓
SleepDataAggregator (NEW — resolves conflicts, picks best source per metric)
    ↓
SleepScoreEngine (refactored weights)
    ↓
SleepScoreSummary + SleepIndicator[]
    ↓
DashboardViewModel (@Observable, @MainActor)
    ↓
SwiftUI Views
```

### Family Data Flow
```
CloudKit (private + shared databases)
    ↓
FamilyRepository (NEW)
    ↓                    ↓
FamilyMember[]      FamilyMemberScore[] (shared by each member)
    ↓
FamilyFeedViewModel (@Observable)
    ↓
FamilyFeedView
```

---

## New Components to Build

### 1. `SleepDataAggregator` (Service)
- Takes raw HealthKit samples (all sources)
- Groups by metric type
- Source priority logic: most samples in window > Apple Watch > Oura > Whoop > other
- Returns `[SleepIndicator]` with `.source` set to winning device
- Emits `[MetricConflict]` for future calibration UI

### 2. `FamilyRepository` (Service)
- CloudKit wrapper
- `CKRecord` types: `FamilyGroup`, `FamilyMember`, `DailySleepScore`
- Sharing via `CKShare` (family group shared to members)
- Each user pushes their own daily score to shared database
- Pull scores for all family members on feed load

### 3. `FamilyFeedViewModel` (@Observable)
- `members: [FamilyMember]`
- `scores: [String: DailySleepScore]` keyed by member ID
- `selectedDate: Date`
- Loads on appear, refreshes with CloudKit push notifications

### 4. `FamilyFeedView`
- Sorted list (by score desc, or alphabetical toggle)
- `FamilyMemberRowView`: avatar initials, name, score bubble (color-coded), delta from yesterday
- Tap → `FamilyMemberDashboardView` (read-only, same layout as Tab 1)

### 5. `ScoreHeroView` (replace ScoreCardView)
- Large score number (animated counter on load)
- SVG-style arc/ring (using Canvas or custom Shape)
- Three colored sub-component arcs or segmented bar
- Date picker chevron (yesterday / today)

### 6. `ScoreBreakdownView` (replace ScoreComponentListView)
- Horizontal scroll of 3 cards: Sleep, Recovery, Consistency
- Each card: category icon, score, contributing metrics list
- Tap → expands to full MetricDetailView

---

## CloudKit Data Schema

### `FamilyGroup` (CKRecord)
```
id: CKRecord.ID
name: String
createdBy: CKRecord.Reference (user)
createdAt: Date
```

### `FamilyMember` (CKRecord, in shared DB)
```
familyGroup: CKRecord.Reference
userRecordID: String (CKCurrentUserDefaultName)
displayName: String
avatarColor: String (hex)
joinedAt: Date
```

### `DailySleepScore` (CKRecord, in shared DB)
```
member: CKRecord.Reference
date: Date
score: Double
sleepComponent: Double
recoveryComponent: Double
consistencyComponent: Double
totalSleepMinutes: Int
remPercent: Double
deepPercent: Double
avgHR: Double
lowestHR: Double
avgHRV: Double
avgRR: Double
primarySource: String  ("appleWatch" | "oura" | "whoop")
```

---

## Revised Model Layer

### Keep (unchanged)
- `SleepStage`, `SleepStageSample`
- `SleepChartPoint`, `SleepChartSeries`
- `SleepSignalSample`, `SleepSignalType`
- `SleepIndicator`, `SleepIndicatorCategory`
- `SleepInsight`, `SleepInsightImpact`
- `HealthAuthorizationState`

### Modify
- `SleepScoreSummary` — add `primarySource: SleepIndicatorSource`, remove `feeling`
- `SleepScoreComponent` — rename to align with new 3-category system
- `SleepScoreWeights` — new weight schema matching methodology above
- `SleepIndicatorSource` — add `.oura`, `.whoop`

### Add
- `FamilyMember` — id, displayName, avatarColor, userRecordID
- `DailySleepScore` — daily snapshot for CloudKit
- `MetricConflict` — (metric, source1, value1, source2, value2) for future calibration
- `FamilyInvite` — invite token, expiry, groupID

### Remove
- `SleepFeeling` — no more mood modifier
- `LastNightMetrics` — fold into SleepScoreSummary

---

## Revised Score Engine

```swift
struct SleepScoreWeights {
    // Architecture sub-weights (contribute to architectureScore)
    var duration: Double = 0.30
    var efficiency: Double = 0.20
    var remPercent: Double = 0.20
    var deepPercent: Double = 0.20
    var awakenings: Double = 0.10

    // Recovery sub-weights (contribute to recoveryScore)
    var avgHR: Double = 0.20
    var lowestHR: Double = 0.15
    var timeToLowestHR: Double = 0.10
    var avgHRV: Double = 0.25
    var hrvTrend: Double = 0.10
    var avgRR: Double = 0.10
    var minRR: Double = 0.05
    var spo2: Double = 0.05

    // Consistency sub-weights
    var sleepStartConsistency: Double = 0.50
    var wakeConsistency: Double = 0.30
    var midpointConsistency: Double = 0.20

    // Top-level category weights
    var architectureWeight: Double = 0.35
    var recoveryWeight: Double = 0.40
    var consistencyWeight: Double = 0.15
    var contextModifierWeight: Double = 0.10
}
```

---

## Phased Roadmap

### Phase 1 — Foundation (MVP, ~4 weeks)
- [ ] Refactor SleepScoreEngine with new weight schema
- [ ] Build SleepDataAggregator with source resolution
- [ ] Redesign ScoreHeroView (arc/ring, animated counter)
- [ ] Redesign ScoreBreakdownView (3-card horizontal scroll)
- [ ] Wire up MetricDetailListView with source attribution
- [ ] Remove: feeling check-in, manual overrides, weight editing, share cards, analytics pipeline
- [ ] Persist score via UserDefaults (simple daily cache)

### Phase 2 — Family (4–6 weeks after Phase 1)
- [ ] Sign in with Apple integration
- [ ] CloudKit schema setup + FamilyRepository
- [ ] FamilyFeedView + FamilyMemberRowView
- [ ] FamilyMemberDashboardView (read-only)
- [ ] Invite flow (deep link or share sheet)
- [ ] Push notifications on family member score availability

### Phase 3 — Polish & Intelligence (ongoing)
- [ ] Baseline learning (30-day rolling HR/HRV baselines)
- [ ] Contextualized insights (rule engine or lightweight ML)
- [ ] Multi-device calibration UI
- [ ] Apple Watch complication (score at a glance)
- [ ] Trend analysis (5-day patterns, weekly summaries)
- [ ] Export / CSV download

---

## Open Questions

1. **Family data privacy**: Can family members opt out of sharing specific metrics (e.g., hide HR)? Default = yes, share only score + components.
2. **Score caching**: Should we compute score on device and push result, or push raw metrics and let server compute? Device-side is simpler and preserves privacy.
3. **Baseline seeding**: What to show if user has < 7 days of data? Show "building baseline" state for consistency component.
4. **Whoop/Oura source detection**: These write to Apple Health with specific source bundle IDs. Need to map known bundle IDs to source labels.
5. **CloudKit environment**: Use private + shared DB only (no server-side functions needed at Phase 2).

---

## Key Source Bundle IDs (HealthKit)

For source detection in SleepDataAggregator:
```
Apple Watch:  com.apple.health (or hardware source)
Oura:         com.ouraring.oura
Whoop:        com.whoop.whoop
Garmin:       com.garmin.connect.mobile
Fitbit:       com.fitbit.FitbitMobile
```

---

## File Structure (Target)

```
SleepTune/
├── App/
│   ├── SleepTuneApp.swift
│   ├── AppContainer.swift           (updated DI)
│   ├── AppRootView.swift            (tab-based navigation)
│   └── Assets.xcassets/
│
├── Features/
│   ├── Dashboard/
│   │   ├── ViewModels/
│   │   │   └── DashboardViewModel.swift
│   │   └── Views/
│   │       ├── SleepDashboardView.swift
│   │       ├── ScoreHeroView.swift          (NEW — replaces ScoreCardView)
│   │       ├── ScoreBreakdownView.swift     (NEW — replaces ScoreComponentListView)
│   │       ├── SleepStagesChartView.swift
│   │       ├── SignalsChartView.swift
│   │       ├── MetricDetailListView.swift
│   │       └── ScoreTrendView.swift
│   │
│   ├── Family/                              (NEW)
│   │   ├── ViewModels/
│   │   │   └── FamilyFeedViewModel.swift
│   │   └── Views/
│   │       ├── FamilyFeedView.swift
│   │       ├── FamilyMemberRowView.swift
│   │       └── FamilyMemberDashboardView.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift               (simplified)
│       ├── HealthConnectionRowView.swift
│       ├── FamilyManagementView.swift       (NEW)
│       └── AccountView.swift               (NEW — Sign in with Apple)
│
├── Models/
│   ├── Sleep/
│   │   ├── SleepIndicator.swift
│   │   ├── SleepScoreSummary.swift
│   │   ├── SleepStage.swift
│   │   ├── SleepSignal.swift
│   │   └── SleepChart.swift
│   └── Family/                             (NEW)
│       ├── FamilyMember.swift
│       ├── DailySleepScore.swift
│       └── FamilyInvite.swift
│
├── Services/
│   ├── HealthKit/
│   │   ├── HealthKitClient.swift
│   │   └── SleepDataAggregator.swift       (NEW)
│   ├── Scoring/
│   │   ├── SleepScoreEngine.swift          (refactored)
│   │   └── SleepScoreWeights.swift
│   ├── Family/                             (NEW)
│   │   └── FamilyRepository.swift
│   └── Storage/
│       ├── SleepLocalStore.swift
│       └── UserDefaultsSleepStore.swift    (NEW — replace InMemory)
│
└── Utilities/
    ├── Date+StartOfDay.swift
    └── Color+Score.swift                   (NEW — score color helpers)
```

---

## Design Principles

1. **Score first** — the number is the hero, everything else supports it
2. **Source transparency** — always show where a metric came from
3. **Privacy by default** — family sharing is opt-in, granular
4. **No gamification** — resist adding streaks/badges; the score speaks for itself
5. **Objective over tunable** — the score reflects reality, not how you want to feel
