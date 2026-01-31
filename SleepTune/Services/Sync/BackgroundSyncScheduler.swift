import BackgroundTasks
import Foundation

protocol BackgroundSyncScheduling: Sendable {
    func schedule()
}

struct NoopBackgroundSyncScheduler: BackgroundSyncScheduling {
    func schedule() {}
}

struct AppRefreshBackgroundSyncScheduler: BackgroundSyncScheduling {
    let identifier: String
    let earliestBeginInterval: TimeInterval

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(earliestBeginInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Ignore scheduling errors; sync can still happen opportunistically in-app.
        }
    }
}
