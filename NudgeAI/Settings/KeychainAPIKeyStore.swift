import Foundation
import Security

/// One Keychain entry per platform. Only Settings writes; only Classification reads.
protocol APIKeyStore {
    func saveAPIKey(_ key: String, for provider: AIProvider) throws
    func readAPIKey(for provider: AIProvider) throws -> String?
    func deleteAPIKey(for provider: AIProvider) throws
    /// Existence check that never reads the key value.
    func hasKey(for provider: AIProvider) -> Bool
}

enum APIKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
    case noProvider
}

final class KeychainAPIKeyStore: APIKeyStore {
    /// Anthropic keeps its pre-Phase 7 service/account, so existing installs'
    /// keys are found in place (that is the migration; no copy needed).
    private func identity(for provider: AIProvider) throws -> (service: String, account: String) {
        switch provider {
        case .anthropic: return ("com.shwairatech.nudgeai.anthropic-api-key", "anthropic-api-key")
        case .deepseek: return ("com.shwairatech.nudgeai.deepseek-api-key", "deepseek-api-key")
        case .none: throw APIKeyStoreError.noProvider
        }
    }

    private func baseQuery(for provider: AIProvider) throws -> [String: Any] {
        let id = try identity(for: provider)
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: id.service,
            kSecAttrAccount as String: id.account
        ]
    }

    func saveAPIKey(_ key: String, for provider: AIProvider) throws {
        guard let data = key.data(using: .utf8) else { throw APIKeyStoreError.invalidData }
        let query = try baseQuery(for: provider)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Update in place so a failed write never destroys an existing key.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw APIKeyStoreError.unexpectedStatus(updateStatus) }

        let newItem = query.merging(attributes) { _, new in new }
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIKeyStoreError.unexpectedStatus(status) }
    }

    func hasKey(for provider: AIProvider) -> Bool {
        guard var query = try? baseQuery(for: provider) else { return false }
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func readAPIKey(for provider: AIProvider) throws -> String? {
        var query = try baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
                throw APIKeyStoreError.invalidData
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    func deleteAPIKey(for provider: AIProvider) throws {
        let status = SecItemDelete(try baseQuery(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }
}
