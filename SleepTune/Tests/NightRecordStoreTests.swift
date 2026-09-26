import XCTest
@testable import SleepTune

final class NightRecordStoreTests: XCTestCase {

    private func makeStore() -> NightRecordStore {
        NightRecordStore(modelContainer: NightRecordStore.makeContainer(inMemory: true))
    }

    private func night(_ daysAgo: Int, score: Double = 70, hours: Double = 7.2) -> NightSummary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))!
        return NightSummary(
            night: date, score: score, sleepScore: score, recoveryScore: score,
            metrics: ["Sleep Duration": hours], maxHR: nil, steps: 8000, activeCalories: nil,
            exerciseMinutes: 30, peakHR: nil, vo2Max: nil, sleepStart: nil, sleepEnd: nil,
            dayType: DayType.classify(wakeDate: date), alcoholFlag: nil
        )
    }

    func testUpsertInsertsThenUpdatesSameKey() async throws {
        let store = makeStore()
        try await store.upsert(night(1, score: 60))
        try await store.upsert(night(1, score: 80))
        let count = try await store.count()
        XCTAssertEqual(count, 1)
        let fetched = try await store.record(for: night(1).night)
        XCTAssertEqual(fetched?.score, 80)
    }

    func testRangeQueryIsInclusiveAndSorted() async throws {
        let store = makeStore()
        try await store.upsert([night(5), night(3), night(1), night(0)])
        let rows = try await store.records(from: night(3).night, to: night(1).night)
        XCTAssertEqual(rows.map(\.night), [night(3).night, night(1).night])
    }

    func testLatestReturnsNewestNAscending() async throws {
        let store = makeStore()
        try await store.upsert((0..<10).map { night($0) })
        let rows = try await store.latest(3)
        XCTAssertEqual(rows.map(\.night), [night(2).night, night(1).night, night(0).night])
    }

    func testUpdateMergesFieldsAndKeepsOthers() async throws {
        let store = makeStore()
        try await store.upsert(night(2, score: 66))
        try await store.update(key: night(2).key) { $0.alcoholFlag = true }
        let row = try await store.record(for: night(2).night)
        XCTAssertEqual(row?.alcoholFlag, true)
        XCTAssertEqual(row?.score, 66)
    }

    func testUpsertPreservesAlcoholFlagWhenNewValueIsNil() async throws {
        let store = makeStore()
        try await store.upsert(night(2))
        try await store.update(key: night(2).key) { $0.alcoholFlag = true }
        try await store.upsert(night(2, score: 71))   // alcoholFlag nil in the new summary
        let row = try await store.record(for: night(2).night)
        XCTAssertEqual(row?.alcoholFlag, true)
        XCTAssertEqual(row?.score, 71)
    }

    func testDeleteAll() async throws {
        let store = makeStore()
        try await store.upsert([night(1), night(2)])
        try await store.deleteAll()
        let count = try await store.count()
        XCTAssertEqual(count, 0)
    }

    func testDayTypeClassification() {
        var comps = DateComponents(); comps.year = 2026; comps.month = 9
        let cal = Calendar.current
        comps.day = 26; XCTAssertEqual(DayType.classify(wakeDate: cal.date(from: comps)!), .weekend) // Sat
        comps.day = 27; XCTAssertEqual(DayType.classify(wakeDate: cal.date(from: comps)!), .weekend) // Sun
        comps.day = 28; XCTAssertEqual(DayType.classify(wakeDate: cal.date(from: comps)!), .weekday) // Mon
        comps.day = 25; XCTAssertEqual(DayType.classify(wakeDate: cal.date(from: comps)!), .weekday) // Fri wake = Thu night
    }
}

final class MetricSplitStatsTests: XCTestCase {
    private func stats(_ avg: Double, count: Int = 6) -> MetricStats {
        MetricStats(avg: avg, min: avg - 1, max: avg + 1, count: count, sortedValues: Array(repeating: avg, count: count))
    }

    func testDiffersMeaningfullyUsesEightPercentThreshold() {
        XCTAssertFalse(MetricSplitStats(all: stats(50), weekday: stats(50), weekend: stats(53)).differsMeaningfully())
        XCTAssertTrue(MetricSplitStats(all: stats(50), weekday: stats(50), weekend: stats(55)).differsMeaningfully())
        XCTAssertFalse(MetricSplitStats(all: stats(50), weekday: nil, weekend: stats(70)).differsMeaningfully())
    }

    func testStatsForDayType() {
        let split = MetricSplitStats(all: stats(1), weekday: stats(2), weekend: stats(3))
        XCTAssertEqual(split.stats(for: .weekday)?.avg, 2)
        XCTAssertEqual(split.stats(for: .weekend)?.avg, 3)
    }
}
