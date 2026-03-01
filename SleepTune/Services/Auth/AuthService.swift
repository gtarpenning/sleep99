import Foundation
import AuthenticationServices
import Observation

@MainActor
@Observable
final class AuthService {
    var userID: String?
    var displayName: String?
    var isSignedIn: Bool { userID != nil }

    init() {
        userID = KeychainItem.currentUserID
        displayName = UserDefaults.standard.string(forKey: "auth.displayName")
    }

    // MARK: - Session restore (call on launch)

    func restoreSession() async {
        guard let storedID = userID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: storedID)
        if state == .revoked || state == .notFound {
            clearSession()
        }
    }

    // MARK: - Called by SignInView after SignInWithAppleButton succeeds

    func handleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        let uid = credential.user
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        do {
            try KeychainItem(service: "com.sleep-tune.app", account: "userID").saveItem(uid)
        } catch {
            print("[Auth] Keychain save failed: \(error)")
        }

        // fullName is only delivered on first sign-in; preserve stored name on re-auth
        if !name.isEmpty {
            displayName = name
            UserDefaults.standard.set(name, forKey: "auth.displayName")
        }
        userID = uid
    }

    func signOut() {
        clearSession()
    }

    // MARK: - Private

    private func clearSession() {
        userID = nil
        displayName = nil
        try? KeychainItem(service: "com.sleep-tune.app", account: "userID").deleteItem()
        UserDefaults.standard.removeObject(forKey: "auth.displayName")
    }
}
