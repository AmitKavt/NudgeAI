import Foundation
import Security

protocol APIKeyStore {
    func saveAPIKey(_ key: String) throws
    func readAPIKey() throws -> String?
    func deleteAPIKey() throws
}

enum APIKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainAPIKeyStore: APIKeyStore {
    private let service = "com.shwairatech.nudgeai.anthropic-api-key"
    private let account = "anthropic-api-key"

    func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw APIKeyStoreError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    func readAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

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

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }
}
