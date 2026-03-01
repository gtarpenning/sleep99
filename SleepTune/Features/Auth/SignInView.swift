import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AppContainer.self) private var container
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(DS.purple)

                    Text("sleeptune")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Sleep scores for you and your family.")
                        .font(.subheadline)
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                            container.authService.handleCredential(credential)
                        case .failure(let error):
                            let code = (error as? ASAuthorizationError)?.code
                            guard code != .canceled else { return }
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
