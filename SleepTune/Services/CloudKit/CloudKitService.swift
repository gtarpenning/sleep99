import Foundation
import CloudKit

actor CloudKitService {
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase

    /// All SleepScore records live in this zone so CKShare works correctly.
    /// (Default-zone records cannot be individually shared via CKShare.)
    private let zone = CKRecordZone(zoneName: "SleepScores")

    init() {
        container = CKContainer(identifier: "iCloud.com.sleep-tune.app")
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase
    }

    // MARK: - Publish + Share (single atomic call)

    /// Saves today's score and returns a shareable URL.
    /// Creates the custom zone on first run (which also seeds the schema in dev).
    func publishAndShare(
        _ summary: SleepScoreSummary,
        totalMinutes: Int,
        userID: String,
        displayName: String,
        avatarColor: String,
        avatarEmoji: String? = nil
    ) async throws -> URL {
        // 1. Ensure the custom zone exists (no-op on subsequent calls).
        try await createZoneIfNeeded()

        // 2. Stable record ID → upsert semantics, no duplicates per user per day.
        let dateStamp = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: summary.date))
        let recordID = CKRecord.ID(recordName: "\(userID)-\(dateStamp)", zoneID: zone.zoneID)

        // 3. Fetch existing record to preserve system metadata; fall back to new.
        let record: CKRecord
        if let existing = try? await privateDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "SleepScore", recordID: recordID)
        }
        record["memberID"]          = userID
        record["displayName"]       = displayName
        record["avatarColor"]       = avatarColor
        record["avatarEmoji"]       = avatarEmoji
        record["date"]              = summary.date
        record["score"]             = summary.score
        record["sleepScore"]        = summary.sleepScore
        record["recoveryScore"]     = summary.recoveryScore
        record["totalSleepMinutes"] = totalMinutes
        record["primarySource"]     = summary.primarySource.rawValue

        // 4. Fetch or create the zone-level share (one share covers all records in the zone).
        let shareRecordID = CKRecord.ID(recordName: "cloudkit.share", zoneID: zone.zoneID)
        let share: CKShare
        if let existing = try? await privateDB.record(for: shareRecordID) as? CKShare {
            share = existing
        } else {
            share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = "My Sleep Score"
        }
        // Keep sharing mode consistent: public read-only link sharing.
        share.publicPermission = .readOnly

        // 5. Save record + share atomically. CKShare MUST be saved with the data record.
        // Capture the server-returned share from perRecordSaveBlock — that's where .url is populated.
        let op = CKModifyRecordsOperation(recordsToSave: [record, share])
        op.savePolicy = .changedKeys
        op.isAtomic = true

        let savedURL: URL = try await withCheckedThrowingContinuation { continuation in
            var capturedURL: URL?
            op.perRecordSaveBlock = { _, result in
                if case .success(let saved) = result, let s = saved as? CKShare, let url = s.url {
                    capturedURL = url
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let url = capturedURL {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: CloudKitError.noShareURL)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(op)
        }
        return savedURL
    }

    // MARK: - Prepare share for UICloudSharingController

    /// Returns the CKShare + CKContainer needed to present UICloudSharingController.
    /// Saves the score record and creates/fetches the zone-level share atomically.
    func prepareShare(
        _ summary: SleepScoreSummary,
        totalMinutes: Int,
        userID: String,
        displayName: String,
        avatarColor: String,
        avatarEmoji: String? = nil
    ) async throws -> (CKShare, CKContainer) {
        try await createZoneIfNeeded()

        let dateStamp = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: summary.date))
        let recordID = CKRecord.ID(recordName: "\(userID)-\(dateStamp)", zoneID: zone.zoneID)

        let record: CKRecord
        if let existing = try? await privateDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "SleepScore", recordID: recordID)
        }
        record["memberID"]          = userID
        record["displayName"]       = displayName
        record["avatarColor"]       = avatarColor
        record["avatarEmoji"]       = avatarEmoji
        record["date"]              = summary.date
        record["score"]             = summary.score
        record["sleepScore"]        = summary.sleepScore
        record["recoveryScore"]     = summary.recoveryScore
        record["totalSleepMinutes"] = totalMinutes
        record["primarySource"]     = summary.primarySource.rawValue

        let shareRecordID = CKRecord.ID(recordName: "cloudkit.share", zoneID: zone.zoneID)
        let share: CKShare
        if let existing = try? await privateDB.record(for: shareRecordID) as? CKShare {
            share = existing
        } else {
            share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = "My Sleep Score"
        }
        // Keep sharing mode consistent: public read-only link sharing.
        share.publicPermission = .readOnly

        let op = CKModifyRecordsOperation(recordsToSave: [record, share])
        op.savePolicy = .changedKeys
        op.isAtomic = true

        let savedShare: CKShare = try await withCheckedThrowingContinuation { continuation in
            var capturedShare: CKShare?
            op.perRecordSaveBlock = { _, result in
                if case .success(let saved) = result, let s = saved as? CKShare {
                    capturedShare = s
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: capturedShare ?? share)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(op)
        }
        return (savedShare, container)
    }

    // MARK: - Publish only (background sync, no share)

    /// Saves today's score without creating/returning a share URL.
    /// Called by DashboardViewModel after each score load.
    func publishTodayScore(
        _ summary: SleepScoreSummary,
        totalMinutes: Int,
        userID: String,
        displayName: String,
        avatarColor: String,
        avatarEmoji: String? = nil
    ) async throws {
        try await createZoneIfNeeded()
        let dateStamp = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: summary.date))
        let recordID = CKRecord.ID(recordName: "\(userID)-\(dateStamp)", zoneID: zone.zoneID)
        let record: CKRecord
        if let existing = try? await privateDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "SleepScore", recordID: recordID)
        }
        record["memberID"]          = userID
        record["displayName"]       = displayName
        record["avatarColor"]       = avatarColor
        record["avatarEmoji"]       = avatarEmoji
        record["date"]              = summary.date
        record["score"]             = summary.score
        record["sleepScore"]        = summary.sleepScore
        record["recoveryScore"]     = summary.recoveryScore
        record["totalSleepMinutes"] = totalMinutes
        record["primarySource"]     = summary.primarySource.rawValue
        try await privateDB.save(record)
    }

    // MARK: - Fetch group data

    /// Returns (member, score) pairs from records shared with the current user.
    func fetchGroupData() async throws -> [(FamilyMember, DailySleepScore)] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let predicate = NSPredicate(format: "date >= %@", yesterday as NSDate)
        let query = CKQuery(recordType: "SleepScore", predicate: predicate)
        let results = try await sharedDB.records(matching: query)
        var latestByMember: [String: (FamilyMember, DailySleepScore)] = [:]
        for result in results.matchResults {
            guard let record = try? result.1.get(),
                  let memberID = record["memberID"] as? String,
                  let displayName = record["displayName"] as? String,
                  let date = record["date"] as? Date,
                  let score = record["score"] as? Double
            else { continue }
            let member = FamilyMember(
                id: memberID,
                displayName: displayName,
                avatarColor: record["avatarColor"] as? String ?? "#5E5CE6",
                avatarEmoji: record["avatarEmoji"] as? String,
                isCurrentUser: false
            )
            let dailyScore = DailySleepScore(
                id: record.recordID.recordName,
                memberID: memberID,
                date: date,
                score: score,
                sleepScore: record["sleepScore"] as? Double ?? 0,
                recoveryScore: record["recoveryScore"] as? Double ?? 0,
                totalSleepMinutes: record["totalSleepMinutes"] as? Int ?? 0,
                primarySource: SleepIndicatorSource(rawValue: record["primarySource"] as? String ?? "") ?? .appleHealth
            )

            if let existing = latestByMember[memberID], existing.1.date >= dailyScore.date {
                continue
            }
            latestByMember[memberID] = (member, dailyScore)
        }
        return Array(latestByMember.values)
    }

    // MARK: - Helpers

    private func createZoneIfNeeded() async throws {
        let zones = try await privateDB.allRecordZones()
        guard !zones.contains(where: { $0.zoneID.zoneName == zone.zoneID.zoneName }) else { return }
        try await privateDB.save(zone)
    }
}

enum CloudKitError: Error, LocalizedError {
    case noShareURL

    var errorDescription: String? {
        switch self {
        case .noShareURL: return "Could not generate a share URL. Try again."
        }
    }
}
