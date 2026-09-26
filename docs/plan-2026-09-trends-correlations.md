# Plan: long-range trends, correlations, alcohol flag, chart polish

_Drafted 2026-09-26 from the week's notes. Ordered so each phase ships on its own._

## Guiding constraints

- **Progressive disclosure, not more sections.** Today the dashboard is a single scroll: Hero → Breakdown → Debt → Metric Breakdown → Last Night → Insights → Trend → Rating → Tags. We add at most **one** new top-level surface (a "Trends" screen reached from the existing Trend card) and otherwise enrich what exists via toggles, sheets, and annotations.
- **Daily stats stay primary.** The dashboard remains "last night". Long-range views live one tap away.
- **Data first.** Every visual in the notes is blocked on the same thing: the local store only holds 30 days and only stores per-night *indicators* plus scores. Phase 1 fixes that once; everything else reads from it.

## Phase 0 — Remove apnea (small, do first, ship alone)

Delete the feature end to end. Touch points:

| File | Change |
|---|---|
| `SleepTune/Services/Scoring/ApneaDetector.swift` | delete |
| `SleepTune/Tests/ApneaDetectorTests.swift` | delete |
| `SleepTune/Services/Scoring/MetricDefinition.swift:47-53` | remove the `Apnea Events` entry; re-check that `sleepArchitecture` weights still normalise sensibly (engine normalises by total, so no renumbering needed) |
| `SleepTune/Services/HealthKit/HealthKitClient.swift:793-825` | remove the RR-spike fetch and indicator append |
| `SleepTune/Features/Dashboard/SignalOverlayChartView.swift:35-58` | remove the apnea `PointMark` block |
| `SleepTune/Debug/MockSleepData.swift:90-105` | drop the synthetic apnea spike from the mock RR series (keep the series) |
| `SleepTune/Services/Storage/LocalStore.swift` | bump `currentSchemaVersion` 6 → 7 so stale cached `Apnea Events` indicators are purged |
| `project.yml` / xcodeproj | regenerate if xcodegen is in use so the deleted files drop out |

Also grep `MetricProfiles.swift` and `SleepScoreEngineTests.swift` for the name; no hits found today but re-check after edits. Run the unit test target.

## Phase 1 — Data foundation: nightly summary history

**Problem.** `UserDefaultsSleepStore` caches indicators for 30 days (`prefetchWeek`), and `loadMonthlyStats` / `TagInsightEngine` / `SleepDebt` each re-walk day-by-day. Nothing holds months of history, and UserDefaults is the wrong home for it.

**Deliverable.** A `NightRecord` table (SwiftData, per AGENTS.md) that is the single source for everything longer than "last night":

```swift
@Model final class NightRecord {
    @Attribute(.unique) var night: Date          // startOfDay of the wake date
    var score, sleepScore, recoveryScore: Double
    var metrics: [String: Double]                // indicator name → value (all 29 names)
    var avgHR, minHR, maxHR: Double?             // overnight
    var avgHRV, avgRR: Double?
    var stageMinutes: [String: Double]           // rem/deep/core/awake
    var steps, activeKcal, exerciseMin, peakHR, vo2Max: Double?   // prior day's activity
    var sleepStart, sleepEnd: Date?
    var isWeekend: Bool                          // derived at write time (Fri & Sat *nights*)
    var tags: [UUID]
    var alcoholFlag: Bool?                       // Phase 4
    var schemaVersion: Int
}
```

Work items:

1. **`NightRecordStore`** (`Services/Storage/`): `upsert(_:)`, `records(from:to:)`, `latest(n:)`. Keep `SleepLocalStore` for now; write to both during the transition, then delete the UserDefaults score/indicator dicts in a follow-up.
2. **Backfill job** (`Services/HealthKit/HistoryBackfill.swift`): on first launch after upgrade, and on a manual "Rebuild history" button in Settings, walk back day by day using `fetchSleepIndicators`, `fetchSignals`, `fetchActivitySnapshot` until 3 consecutive empty nights or 400 days. Run in a detached task with a progress value surfaced on the Trends screen ("Importing 142 of ~300 nights…"). Batch by 14 days and `await Task.yield()` between batches so the UI stays responsive. Persist a `backfillCursor` so it resumes after a kill.
3. **`prefetchWeek` becomes `syncRecent`**: last 7 days, upserting into `NightRecord`. `recalculateScore` also upserts the selected night.
4. Refactor readers to the new store: `loadMonthlyStats`, `loadActivityMonthlyStats`, `loadSleepDebt`, `loadTrendHistory`, both `TagInsightEngine` methods. Each of these currently issues 30–60 sequential async loads; they become a single range query.
5. Tests: `NightRecordStoreTests` with an in-memory `ModelContainer`; backfill cursor resume test.

**Risk to call out.** Historic `fetchSleepIndicators` costs ~10 HealthKit queries per night. 300 nights ≈ 3000 queries; on device that's a few minutes in the background. Acceptable once, hence the cursor and batching.

## Phase 2 — Weekday / weekend split

**Model.** `isWeekend` on `NightRecord`. Define a *weekend night* as the sleep that ends on Saturday or Sunday morning (Fri and Sat nights). Make the rule a single `DayType.classify(wakeDate:)` function so it is testable and easy to change.

**Stats.** `MetricStats` grows a sibling: `SplitStats { all, weekday, weekend: MetricStats }`. `loadMonthlyStats` produces all three from one range query.

**Where it shows (progressive disclosure):**

- **Baseline for scoring** stays "all nights" by default. Add a Settings toggle *"Use weekday baseline for scoring"*. That is the one behaviour change; everything else is display.
- **Metric Breakdown rows** (`MetricBreakdownView`): the subtitle that shows "30d avg" gains a small `Wd`/`We` chip only when the two differ by more than ~8 %. Tapping into `MetricDetailSheet` shows a three-value row: All / Weekdays / Weekends, with the current night highlighted against the matching group.
- **Day-of-week breakdown** lives in the new Trends screen (Phase 3), not on the dashboard: a 7-bar chart of average score per weekday, tap a bar to see that day's metric averages. This directly answers "breakdown my day of the week" without adding a dashboard card.
- **Hero**: no change. Maybe a tiny "weekend" glyph next to the date; decide in review.

## Phase 3 — Trends screen (the one new surface)

**Entry point.** The existing `ScoreTrendsSectionView` card on the dashboard gets a `NavigationLink` ("See all trends") and its range picker gains `3M`, `6M`, `1Y` (`SleepScoreTrendRange` + `daySpan`). Keep the dashboard chart score-only.

**Screen structure** (`Features/Trends/`):

1. **Range bar** — 1M / 3M / 6M / 1Y / All, plus a `Wd | We | All` segmented filter that applies to every chart on the screen.
2. **Primary chart** — one metric at a time, chosen from a horizontally scrolling chip row: Score, Sleeping HR, HRV, Resp. rate, Duration, Deep, REM, Efficiency, Steps, Peak HR, VO₂ max. Daily points as faint dots, a 7-night rolling mean as the line, monthly mean for ranges ≥ 6M (aggregate in the view model, not in the chart). Dotted horizontal line for the range average.
3. **Overlay** — a second chip row "Compare with…" adds one more series on a right-hand axis (Swift Charts doesn't do dual axes natively; normalise the second series to the first's domain and label the trailing axis manually, same trick as `SignalOverlayChartView`). Cap at two series so the chart stays readable. Persist the last pair in `@AppStorage`.
4. **Day-of-week card** — from Phase 2.
5. **Scrub tooltip** — reuse `ScrubTooltipView`; make it non-private and move to `Utilities/`.

**View model.** `TrendsViewModel` (`@MainActor @Observable`), fed by `NightRecordStore.records(from:to:)`. Aggregation helpers (`rollingMean`, `monthlyBuckets`, `weekdayAverages`) go in a pure `Services/Analytics/TrendMath.swift` with unit tests.

**Widget.** No change.

## Phase 4 — Alcohol heuristic and callout

**Detection** (`Services/Analytics/AlcoholHeuristic.swift`, pure, tested):

```
elevated  = avgHR_night / baselineHR_30d_weekday(or all) - 1
score     = weighted sum of:
   elevated ≥ 0.20                      strong  (+2)
   elevated ≥ 0.12                      weak    (+1)
   HRV_night < 0.75 × baselineHRV       +1
   deepMinutes < 0.6 × baselineDeep     +1
   time-to-lowest-HR > baseline + 90 min +1   (alcohol pushes the HR trough late)
flag if score ≥ 3; "possible" if score == 2
```

Start with just HR + HRV thresholds and tune against the user's own tagged nights: the existing `SleepTag` store already lets you tag "Drinks". Add a debug-only comparison in Settings ("Heuristic vs tags: 18 / 21 matched") to calibrate before widening.

**Surface (minimal):**

- **Hero**: a small pill under the score — `wineglass` icon + "Elevated HR · likely alcohol". Tap → a short sheet explaining what was detected (HR +23 % vs baseline, HRV −31 %) with a one-tap "Yes, I drank" / "No" that writes the `Drinks` tag or a negative mark. That feedback loop is also the calibration set.
- **Tag Insights**: once ≥ 5 confirmed nights, the existing `TagCorrelation` machinery will surface "Drinks" automatically; nothing new needed.
- **Baselines**: exclude flagged nights from the recovery baseline (`effectiveBaseline`) behind the same Settings toggle as weekday baseline. Off by default.

## Phase 5 — Correlation module

Build on `TagInsightEngine`, but generalise it from "tagged vs untagged" to "continuous X vs sleep metric Y".

1. **`CorrelationEngine`** (`Services/Analytics/`): Pearson and Spearman over `NightRecord`, for a curated pair list rather than all-pairs (avoid false discoveries):
   - Prior-day steps / exercise minutes / peak HR / active kcal → score, sleeping HR, HRV, deep
   - VO₂ max (30-night rolling, since it updates sparsely) → sleeping HR, HRV
   - Bedtime hour → score, REM
   - Sleep duration → next-day steps (the reverse direction)
   Report only |r| ≥ 0.25 with n ≥ 20, and a plain-English strength label.
2. **Slow trends** ("I'm getting fitter, is my sleep changing?"): for VO₂ max and sleeping HR, compute a 90-night linear slope and render as a sentence in the Trends screen: "Sleeping HR down 3.1 bpm over 90 nights while VO₂ max rose 2.4". This is the overlay chart from Phase 3 with a default pair preselected.
3. **Lagged effects**: same engine with X shifted by −1 and −2 nights for the activity pairs. Show only if the lagged r beats the same-day r.
4. **UI**: a "Correlations" card at the bottom of the Trends screen with the top 3 sentences, each tapping into a scatter sheet (`CorrelationDetailSheet`, modelled on `TagCorrelationDetailSheet`). No dashboard footprint beyond what `InsightsBlockView` already shows.
5. Tests with synthetic data: known-r series, null series, lag detection.

## Phase 6 — "Last Night" chart polish

All in `SignalOverlayChartView` / `SleepStagesOverlayChartView`:

- **Axes**: unhide a sparse X axis (every 2 h, `h a` format, caption2, `DS.textTertiary`) and a trailing Y axis with 3 values for the *first* enabled series. Keep `SleepStageChartView` axis-free so the two don't double up.
- **Max HR bubble**: mirror the existing min-HR `PointMark` (lines 20–33) at the max point, annotation on top. Skip if max is within the first/last 5 min of the window (wake-up artefacts).
- **Dotted average line per enabled series**: `RuleMark(y:)` in the series colour at 0.5 opacity, `dash: [3, 3]`, with a trailing label of the value. Since all three series share one normalised Y domain today (`yDomain()` flattens all values), first fix the domain: normalise each series to its own 0–1 range so HR (50–70) and HRV (20–90) don't squash each other, then plot the averages in normalised space. This is the one non-trivial change here; do it before adding the rule marks.
- Widget copies the layout: leave alone.

## Sequencing and estimates

| Phase | Depends on | Size | Ship alone? |
|---|---|---|---|
| 0 Apnea removal | – | S | yes |
| 6 Last Night polish | – | S–M | yes (can run in parallel with 1) |
| 1 NightRecord + backfill + debt v3 | 0 | L | yes, debt fix is user-visible |
| 2 Weekday/weekend | 1 | M | yes |
| 3 Trends screen | 1, 2 | L | yes |
| 4 Alcohol | 1 | M | yes |
| 5 Correlations | 1, 3 | L | yes |

Suggested order: **0 → 6 → 1 → 4 → 2 → 3 → 5**. Alcohol before the Trends screen because it's the highest-signal, lowest-UI item and it starts collecting confirmation data early.

## Decisions (2026-09-26)

- **Storage: SwiftData**, local only, no CloudKit on this table. Robustness rules so it doesn't bite later:
  - Declare a `VersionedSchema` + `SchemaMigrationPlan` from day one, even for v1. Adding optional fields is a lightweight migration; renaming or changing types is not, and without a plan SwiftData silently fails to open the store.
  - All writes go through one `@ModelActor` (`NightRecordStore`); views never touch `ModelContext`. Backfill runs on that actor, not on `@MainActor`.
  - `metrics: [String: Double]` is stored as a `Codable` transformable blob. That's fine for reads by date range, but it can't be queried by metric value in a `#Predicate`. Every query we need is "records between dates", so acceptable. If we ever need "nights where deep < 40", promote that column.
  - Wrap `ModelContainer` creation in a fallback: if it throws (corrupt store), move the file aside, recreate, and trigger a backfill. Data is fully re-derivable from HealthKit, so this is safe.
  - Store `night` as `startOfDay` in the user's *current* calendar and key uniqueness on it; store also a `nightKey: String` (yyyy-MM-dd) as the `@Attribute(.unique)` because `Date` uniqueness across timezone moves is unreliable.
  - Where SwiftData would be limiting: cross-device sync (not wanted), complex aggregate queries (we do those in memory over ≤365 rows, trivial), and widget access (widget keeps reading the snapshot file, unchanged).
- **Weekend = "not a school night"**: Friday and Saturday nights, i.e. sleep that ends Saturday or Sunday morning. `DayType.classify(wakeDate:)`.
- **Backfill cap: 365 nights.**

## Phase 1.5 — Sleep debt v3 (fold into Phase 1, reads from `NightRecord`)

### What's wrong today

Verified against the code just pushed (`a3aebd2`):

1. **`loadSleepDebt` anchors on `Date()`, not `selectedDate`** (`DashboardViewModel.swift:463-475`). Scrolling back days never changes the card.
2. **Loop is `1...windowNights`**, so the selected night is excluded. A 44/100 night doesn't move the number you're looking at; it only shows up tomorrow.
3. **Debt is duration-only.** A 7h night at 44/100 (fragmented, high HR) adds zero debt. That's why "terrible night, still 2h" and "good week, still behind" both feel wrong: the card and the score measure different things.
4. **Decay 0.7 is far steeper than the industry.** Weight sum is 3.3 nights, and last night is 30 % of the total. Rise weights last night 15 % and spreads 85 % over the prior 13 nights. Whoop and Garmin (Firstbeat) both use `need = baseline + f(strain) + f(debt) − naps` and carry a fraction of debt forward. Ours forgets a bad night in ~4 days, which is why it can flip to "caught up" after two decent nights and then feel sticky at other times.
5. **Need is `p60` of 30 nights, floor 6.5.** After a bad fortnight the p60 drops with it, so need chases actual sleep downward and hides debt. Rise fixes need from the best-rested stretch, Whoop learns a baseline slowly. `surplusCredit 0.5` plus a low need is also why good nights barely dent the number.

### What the brands do (sourced)

| | Window | Need | Weighting | Strain | Naps | Surplus |
|---|---|---|---|---|---|---|
| Rise | 14 nights | fixed per person, learned from ~14 nights, "genetically set" | last night 15 %, rest of 85 % declining | no | reduce debt | reported separately, doesn't zero debt |
| Whoop | rolling | baseline learned over time (7–9h typical) | `need = baseline + f(strain) + f(debt) − naps`; only part of debt is asked back each night | yes, adds to need | subtract from need | partial repayment |
| Garmin | rolling | age baseline (~8h <35, ~7.5h 65+) adjusted by history | similar model, adds HRV/recovery signal | yes | reduce need | – |

Rise also frames the target as "keep it **under 5h**", not "zero", which avoids the "caught up / behind" flip-flop.

### Proposed model

```
need_t        = baselineNeed + strainBonus_t              (per night)
baselineNeed  = p75 of nights in the best-rested 14-night stretch of the last 90
                (highest mean score), clamped 6.5–9.  Recompute weekly, not nightly.
strainBonus_t = clamp(0, 0.5h, 0.25h × (exerciseMin_prevDay − 45) / 60)   // ≈ Whoop f1
effective_t   = hours_t × min(1, efficiency_t / 0.85)                      // quality-adjust
                          × (1 − 0.5 × max(0, (baselineDeepREM − deepREM_t)/baselineDeepREM))
delta_t       = need_t − effective_t                                       // + = shortfall
debt          = Σ_{k=0..13} w_k × delta_{t−k},  w_0 = 0.15, w_1..13 geometric summing to 0.85
                shortfall counts 100 %, surplus counts 50 %, floor at 0, cap at 2 × need
```

- k = 0 is the **selected** night, and `t` is `selectedDate`, so the card follows the date picker.
- Effective hours make the 44/100 night register even if it was 7h long. Keep the multiplier bounded so it can't exceed a 30 % haircut.
- Show the number with Rise-style framing: a 14-bar ledger sparkline (green above need, red below), "2.5h · target under 3h", and a trend arrow. Drop "Caught up" as a state; use "Low" under the target.
- Detail sheet (tap card): need value and how it was derived, last 14 nights as a table, the biggest contributor night.

### Body age / advanced metrics

Whoop Age uses six months of data over nine inputs: sleep duration, sleep consistency, steps, HR zone time, strength activity, VO₂ max, resting HR, lean body mass, with overlap adjustment. Oura's Cardiovascular Age is a PPG waveform / pulse-wave-velocity estimate, which we cannot replicate from HealthKit. A credible SleepTune version would need six months of `NightRecord` plus activity, so it belongs **after** Phase 5, as a "Fitness age" card on the Trends screen using: resting HR, VO₂ max, weekly exercise minutes, steps, sleep duration, bedtime consistency. Compare each to age-band norms, sum z-scores, map to years. Note this in the backlog but do not schedule yet.

Sources: [Rise: how much sleep debt do I have](https://www.risescience.com/blog/how-much-sleep-debt-do-i-have), [Rise: what is sleep debt](https://help.risescience.com/hc/en-us/articles/6047219133079-What-is-Sleep-Dept-And-how-to-track-it-with-RISE), [Whoop: how much sleep do I need](https://www.whoop.com/us/en/thelocker/how-much-sleep-do-i-need/), [Whoop: sleep debt playbook](https://www.whoop.com/us/en/thelocker/sleep-debt-optimal-playbook/), [Garmin: five factors sleep coach uses](https://www.garmin.com/en-US/blog/fitness/five-factors-garmin-sleep-coach-uses-to-find-your-sleep-needs/), [Whoop Healthspan guide](https://support.whoop.com/s/article/Healthspan-WHOOP-Age-Pace-of-Aging-Guide?language=en_US), [Oura Cardiovascular Age](https://support.ouraring.com/hc/en-us/articles/28451491040019-Cardiovascular-Age).

## Housekeeping

Sleep-debt v2 landed as `a3aebd2` on `main`. Each phase from here is its own branch.
