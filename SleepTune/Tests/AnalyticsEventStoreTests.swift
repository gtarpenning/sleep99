import XCTest

final class AnalyticsEventStoreTests: XCTestCase {
    func testFileStorePersistsEvents() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "analytics-events-\(UUID().uuidString).json")
        let store = FileAnalyticsEventStore(fileURL: fileURL)
        let event = AnalyticsEvent(name: "test_event")

        await store.enqueue(event)
        let fetched = await store.fetchBatch(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.event.id, event.id)

        let reloadedStore = FileAnalyticsEventStore(fileURL: fileURL)
        let reloadedFetched = await reloadedStore.fetchBatch(limit: 10)
        XCTAssertEqual(reloadedFetched.count, 1)
        XCTAssertEqual(reloadedFetched.first?.event.id, event.id)
    }

    func testMarkAttemptUpdatesRecords() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "analytics-events-\(UUID().uuidString).json")
        let store = FileAnalyticsEventStore(fileURL: fileURL)
        let event = AnalyticsEvent(name: "attempt_event")
        let now = Date()

        await store.enqueue(event)
        await store.markAttempt(ids: [event.id], at: now)

        let fetched = await store.fetchBatch(limit: 10)
        XCTAssertEqual(fetched.first?.attemptCount, 1)
        XCTAssertEqual(fetched.first?.lastAttemptAt, now)
    }
}
