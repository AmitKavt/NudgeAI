import SwiftUI
import AuthenticationServices

enum AppleSignIn {
    /// Live credential-state lookup used on launch.
    static func credentialState(for userIdentifier: String) async -> AppleCredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                switch state {
                case .authorized: continuation.resume(returning: .authorized)
                case .revoked: continuation.resume(returning: .revoked)
                case .notFound: continuation.resume(returning: .notFound)
                case .transferred: continuation.resume(returning: .transferred)
                @unknown default: continuation.resume(returning: .unknown)
                }
            }
        }
    }

    static func makeManager(settingsRepository: SettingsRepository) -> AppleIdentityManager {
        AppleIdentityManager(
            store: KeychainAppleIdentityStore(),
            settingsRepository: settingsRepository,
            credentialState: { await credentialState(for: $0) }
        )
    }
}

/// Apple's button; reports success (saved locally) or failure (caller continues local-only).
struct AppleSignInButton: View {
    let manager: AppleIdentityManager
    var onFinished: (_ signedIn: Bool) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            guard case .success(let auth) = result,
                  let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                onFinished(false)
                return
            }
            let name = AppleIdentityRules.displayName(
                given: credential.fullName?.givenName,
                family: credential.fullName?.familyName
            )
            let saved = (try? manager.completeSignIn(userIdentifier: credential.user, displayName: name)) != nil
            onFinished(saved)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
    }
}
