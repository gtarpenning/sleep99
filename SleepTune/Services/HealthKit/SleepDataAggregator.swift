import Foundation
import HealthKit

/// Resolves conflicts when multiple devices write the same metric to Apple Health.
/// For each metric type, picks the source with the most samples in the sleep window.
struct SleepDataAggregator {

    /// Known bundle IDs for wearable devices
    private enum KnownSource {
        static let appleWatch = "com.apple.health"
        static let oura = "com.ouraring.oura"
        static let whoop = "com.whoop.whoop"

        static func sleepIndicatorSource(for bundleID: String) -> SleepIndicatorSource {
            switch bundleID {
            case let id where id.contains("apple") || id.contains("watch"):
                return .appleWatch
            case let id where id.contains("ouraring") || id.contains("oura"):
                return .oura
            case let id where id.contains("whoop"):
                return .whoop
            default:
                return .otherDevice
            }
        }
    }

    /// Given raw HealthKit quantity samples grouped by identifier, returns
    /// the best source (most samples in window) and the resolved source enum.
    func resolveBestSource(
        from samples: [HKQuantitySample],
        identifier: HKQuantityTypeIdentifier
    ) -> (samples: [HKQuantitySample], source: SleepIndicatorSource) {
        guard !samples.isEmpty else { return ([], .appleHealth) }

        // Group by source bundle ID
        let grouped = Dictionary(grouping: samples) { sample in
            sample.sourceRevision.source.bundleIdentifier
        }

        // Pick the group with most samples
        let best = grouped.max { a, b in a.value.count < b.value.count }
        let bestSamples = best?.value ?? samples
        let bundleID = best?.key ?? ""
        let source = KnownSource.sleepIndicatorSource(for: bundleID)

        return (bestSamples, source)
    }

    /// Given category samples (sleep stages), picks the source with most samples.
    func resolveBestSleepSource(
        from samples: [HKCategorySample]
    ) -> (samples: [HKCategorySample], source: SleepIndicatorSource) {
        guard !samples.isEmpty else { return ([], .appleHealth) }

        let grouped = Dictionary(grouping: samples) { sample in
            sample.sourceRevision.source.bundleIdentifier
        }

        let best = grouped.max { a, b in a.value.count < b.value.count }
        let bestSamples = best?.value ?? samples
        let bundleID = best?.key ?? ""
        let source = KnownSource.sleepIndicatorSource(for: bundleID)

        return (bestSamples, source)
    }
}
