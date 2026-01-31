import Foundation

enum AnalyticsEventName {
    static let appLaunched = "app.launched"
    static let dashboardLoaded = "dashboard.loaded"
    static let healthKitRefreshRequested = "healthkit.refresh.requested"
    static let healthKitRefreshCompleted = "healthkit.refresh.completed"
    static let indicatorUpdated = "indicator.updated"
    static let feelingUpdated = "feeling.updated"
}
