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
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = CloudKitShareSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CloudKitShareAccepter.accept(cloudKitShareMetadata)
    }
}

/// Handles scene-based CloudKit share acceptance for modern multi-scene apps.
final class CloudKitShareSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CloudKitShareAccepter.accept(cloudKitShareMetadata)
    }
}

private enum CloudKitShareAccepter {
    static func accept(_ metadata: CKShare.Metadata) {
        let container = CKContainer(identifier: metadata.containerIdentifier)
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        operation.qualityOfService = .utility
        operation.perShareResultBlock = { _, result in
            guard case .success = result else { return }
            Task { @MainActor in
                NotificationCenter.default.post(name: .cloudKitShareAccepted, object: nil)
            }
        }
        container.add(operation)
    }
}
