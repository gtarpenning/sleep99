import XCTest

final class AnalyticsSyncPolicyTests: XCTestCase {
    func testAllowsImmediateFirstAttempt() {
        let policy = AnalyticsSyncPolicy(minimumInterval: 60, maxBatchSize: 10, retryDelays: [10, 20])
        let now = Date()

        XCTAssertTrue(policy.canAttemptSync(lastAttempt: nil, consecutiveFailures: 0, now: now))
    }

    func testEnforcesMinimumInterval() {
        let policy = AnalyticsSyncPolicy(minimumInterval: 60, maxBatchSize: 10, retryDelays: [10, 20])
        let now = Date()

        XCTAssertFalse(policy.canAttemptSync(lastAttempt: now, consecutiveFailures: 0, now: now))
        XCTAssertTrue(policy.canAttemptSync(lastAttempt: now.addingTimeInterval(-60), consecutiveFailures: 0, now: now))
    }

    func testUsesRetryDelayForFailures() {
        let policy = AnalyticsSyncPolicy(minimumInterval: 10, maxBatchSize: 10, retryDelays: [30, 120])
        let now = Date()

        XCTAssertFalse(policy.canAttemptSync(lastAttempt: now.addingTimeInterval(-20), consecutiveFailures: 1, now: now))
        XCTAssertTrue(policy.canAttemptSync(lastAttempt: now.addingTimeInterval(-30), consecutiveFailures: 1, now: now))
    }
}
