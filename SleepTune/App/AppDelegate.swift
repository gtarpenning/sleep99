import SwiftUI
import CloudKit

extension Notification.Name {
    /// Posted on the main thread after a CKShare is successfully accepted.
    static let cloudKitShareAccepted = Notification.Name("cloudKitShareAccepted")
}

/// Handles CKShare accept callbacks so recipients can join a family group.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
        container.accept(cloudKitShareMetadata) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cloudKitShareAccepted, object: nil)
            }
        }
    }
}
