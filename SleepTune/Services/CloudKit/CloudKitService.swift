import Foundation
import CloudKit

actor CloudKitService {
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase

    init() {
        container = CKContainer(identifier: "iCloud.com.sleep-tune.app")
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase
    }

    // MARK: - Publish

    func publishTodayScore(
        _ summary: SleepScoreSummary,
        totalMinutes: Int,
        userID: String,
        displayName: String,
        avatarColor: String
    ) async throws {
        // Fetch existing record for today to upsert
        let dateKey = Calendar.current.startOfDay(for: summary.date)
        let predicate = NSPredicate(
            format: "memberID == %@ AND date >= %@ AND date < %@",
            userID,
            dateKey as NSDate,
            Calendar.current.date(byAdding: .day, value: 1, to: dateKey)! as NSDate
        )
        let query = CKQuery(recordType: "SleepScore", predicate: predicate)
        let results = try await privateDB.records(matching: query)
        let existing = results.matchResults.compactMap { try? $0.1.get() }.first

        let record = existing ?? CKRecord(recordType: "SleepScore")
        record["memberID"] = userID
        record["displayName"] = displayName
        record["avatarColor"] = avatarColor
        record["date"] = summary.date
        record["score"] = summary.score
        record["sleepScore"] = summary.sleepScore
        record["recoveryScore"] = summary.recoveryScore
        record["totalSleepMinutes"] = totalMinutes
        record["primarySource"] = summary.primarySource.rawValue

        try await privateDB.save(record)
    }

    // MARK: - Fetch

    /// Returns (member, score) pairs from the shared database.
    func fetchGroupData() async throws -> [(FamilyMember, DailySleepScore)] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let predicate = NSPredicate(format: "date >= %@", yesterday as NSDate)
        let query = CKQuery(recordType: "SleepScore", predicate: predicate)
        let results = try await sharedDB.records(matching: query)
        var seen = Set<String>()
        var pairs: [(FamilyMember, DailySleepScore)] = []
        for result in results.matchResults {
            guard let record = try? result.1.get(),
                  let memberID = record["memberID"] as? String,
                  let displayName = record["displayName"] as? String,
                  let date = record["date"] as? Date,
                  let score = record["score"] as? Double,
                  !seen.contains(memberID)
            else { continue }
            seen.insert(memberID)
            let member = FamilyMember(
                id: memberID,
                displayName: displayName,
                avatarColor: "#5E5CE6",
                isCurrentUser: false
            )
            let sleepScore: Double = record["sleepScore"] as? Double ?? 0
            let recoveryScore: Double = record["recoveryScore"] as? Double ?? 0
            let totalMinutes: Int = record["totalSleepMinutes"] as? Int ?? 0
            let sourceRaw: String = record["primarySource"] as? String ?? ""
            let source: SleepIndicatorSource = SleepIndicatorSource(rawValue: sourceRaw) ?? .appleHealth
            let dailyScore = DailySleepScore(
                id: record.recordID.recordName,
                memberID: memberID,
                date: date,
                score: score,
                sleepScore: sleepScore,
                recoveryScore: recoveryScore,
                totalSleepMinutes: totalMinutes,
                primarySource: source
            )
            pairs.append((member, dailyScore))
        }
        return pairs
    }

    func shareScore(recordID: CKRecord.ID) async throws -> URL {
        let record = try await privateDB.record(for: recordID)
        let share = CKShare(rootRecord: record)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "My Sleep Score"
        _ = try await privateDB.save(share)
        guard let url = share.url else {
            throw CloudKitError.noShareURL
        }
        return url
    }

    // MARK: - Today's record ID

    func todayRecordID(for userID: String) async throws -> CKRecord.ID? {
        let dateKey = Calendar.current.startOfDay(for: Date())
        let predicate = NSPredicate(
            format: "memberID == %@ AND date >= %@ AND date < %@",
            userID,
            dateKey as NSDate,
            Calendar.current.date(byAdding: .day, value: 1, to: dateKey)! as NSDate
        )
        let query = CKQuery(recordType: "SleepScore", predicate: predicate)
        let results = try await privateDB.records(matching: query)
        return results.matchResults.compactMap { try? $0.1.get() }.first?.recordID
    }
}

enum CloudKitError: Error {
    case noShareURL
}

