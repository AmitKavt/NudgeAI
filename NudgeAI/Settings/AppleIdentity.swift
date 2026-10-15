import Foundation
import Security

/// Framework-free mapping of Apple's credential state. No AuthenticationServices import.
enum AppleCredentialState: Equatable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown
}

enum AppleIdentityRules {
    /// Whether a stored identifier should keep counting as signed in.
    /// Revoked and notFound mean signed out. Transferred and unknown (for
    /// example a lookup that failed offline) keep the current state.
    static func remainsSignedIn(_ state: AppleCredentialState) -> Bool {
        switch state {
        case .authorized, .transferred, .unknown: return true
        case .revoked, .notFound: return false
        }
    }

    /// Initials for the avatar placeholder; "Y" when there is no name.
    static func initials(for name: String?) -> String {
        let parts = (name ?? "").split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "Y" : letters
    }

    /// Joins name components Apple returns; nil when empty.
    static func displayName(given: String?, family: String?) -> String? {
        let joined = [given, family].compactMap { $0 }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? nil : joined
    }
}

/// Settings-owned store for the Apple user identifier, separate from API keys.
protocol AppleIdentityStore {
    func saveIdentifier(_ identifier: String) throws
    func readIdentifier() throws -> String?
    func deleteIdentifier() throws
}

final class KeychainAppleIdentityStore: AppleIdentityStore {
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.shwairatech.nudgeai.apple-user-id",
            kSecAttrAccount as String: "apple-user-id"
        ]
    }

    func saveIdentifier(_ identifier: String) throws {
        guard let data = identifier.data(using: .utf8) else { throw APIKeyStoreError.invalidData }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Update in place so a failed write never destroys an existing identifier.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw APIKeyStoreError.unexpectedStatus(updateStatus) }

        let item = query.merging(attributes) { _, new in new }
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIKeyStoreError.unexpectedStatus(status) }
    }

    func readIdentifier() throws -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let data = out as? Data, let id = String(data: data, encoding: .utf8) else {
                throw APIKeyStoreError.invalidData
            }
            return id
        case errSecItemNotFound: return nil
        default: throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    func deleteIdentifier() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }
}

/// Local identity only: never touches nudges or API keys, never networks.
final class AppleIdentityManager {
    private let store: AppleIdentityStore
    private let settingsRepository: SettingsRepository
    private let credentialState: (String) async -> AppleCredentialState

    init(
        store: AppleIdentityStore,
        settingsRepository: SettingsRepository,
        credentialState: @escaping (String) async -> AppleCredentialState
    ) {
        self.store = store
        self.settingsRepository = settingsRepository
        self.credentialState = credentialState
    }

    var isSignedIn: Bool { ((try? store.readIdentifier()) ?? nil) != nil }

    /// Persists the identifier and name immediately: Apple returns the name only
    /// on the first sign-in, so a nil name never overwrites a stored one.
    func completeSignIn(userIdentifier: String, displayName: String?) throws {
        try store.saveIdentifier(userIdentifier)
        if let displayName, !displayName.isEmpty {
            try settingsRepository.update { $0.appleDisplayName = displayName }
        }
    }

    /// Clears identifier and name. Nudges and API keys are untouched.
    func signOut() throws {
        try store.deleteIdentifier()
        try settingsRepository.update { $0.appleDisplayName = nil }
    }

    /// Launch check: revoked or notFound is treated as signed out.
    func refreshOnLaunch() async {
        guard let id = (try? store.readIdentifier()) ?? nil else { return }
        let state = await credentialState(id)
        if !AppleIdentityRules.remainsSignedIn(state) { try? signOut() }
    }
}
