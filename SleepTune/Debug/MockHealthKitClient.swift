#if DEBUG
import Foundation
import HealthKit

/// Drop-in replacement for HealthKitClient that returns MockSleepData.
/// Never touches the real HealthKit store.
final class MockHealthKitClient: HealthKitClient {

    override func authorizationState() async -> HealthAuthorizationState {
        .authorized
    }

    override func requestAuthorization() async throws {
        // No-op — already "authorized"
    }

    override func fetchSleepIndicators(for date: Date) async throws -> [SleepIndicator] {
        MockSleepData.indicators
    }

    override func fetchSleepStages(for date: Date) async throws -> [SleepStageSample] {
        MockSleepData.stages
    }

    override func fetchSignals(for date: Date) async throws -> [SleepSignalSample] {
        MockSleepData.signals
    }
}
#endif
