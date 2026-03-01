import SwiftUI
import CloudKit

/// Handles CKShare accept callbacks so recipients can join a family group.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
        container.accept(cloudKitShareMetadata) { _, error in
            if let error {
                print("[CloudKit] Failed to accept share: \(error)")
            }
        }
    }
}
