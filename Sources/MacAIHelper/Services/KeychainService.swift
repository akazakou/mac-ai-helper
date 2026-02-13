// KeychainService.swift
// CRUD operations for API keys stored securely in the macOS Keychain.

import Foundation
import Security

struct KeychainService: Sendable {
    /// Keychain service identifier
    private static let serviceName = "pro.kantora.MacAIHelper"

    /// Saves an API key to the Keychain for a given entry UUID.
    static func saveKey(_ key: String, for entryId: UUID) throws {
        guard let data = key.data(using: .utf8) else {
            throw AppError.keychainError("Failed to encode key data")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: entryId.uuidString,
            kSecValueData as String: data,
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychainError("Failed to save key: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)")
        }
    }

    /// Retrieves an API key from the Keychain by entry UUID.
    /// Returns nil if no key is found.
    static func readKey(for entryId: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: entryId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                let key = String(data: data, encoding: .utf8)
            else {
                throw AppError.keychainError("Failed to decode stored key")
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw AppError.keychainError("Failed to read key: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)")
        }
    }

    /// Deletes an API key from the Keychain by entry UUID.
    static func deleteKey(for entryId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: entryId.uuidString,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.keychainError("Failed to delete key: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)")
        }
    }

    /// Updates an existing API key in the Keychain.
    static func updateKey(_ key: String, for entryId: UUID) throws {
        guard let data = key.data(using: .utf8) else {
            throw AppError.keychainError("Failed to encode key data")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: entryId.uuidString,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // If item doesn't exist, create it
            try saveKey(key, for: entryId)
        } else if status != errSecSuccess {
            throw AppError.keychainError("Failed to update key: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)")
        }
    }

    /// Retrieves all API keys for the app's service in a single Keychain query.
    /// Returns a dictionary mapping account (UUID string) to its API key.
    static func readAllKeys() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let items = result as? [[String: Any]]
        else {
            return [:]
        }

        var keys: [String: String] = [:]
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                let data = item[kSecValueData as String] as? Data,
                let key = String(data: data, encoding: .utf8),
                !key.isEmpty
            else { continue }
            keys[account] = key
        }
        return keys
    }

    /// Retrieves the first available API key for a given provider from settings.
    static func apiKey(for provider: AIProvider, entries: [APIKeyEntry]) throws -> String {
        guard let entry = entries.first(where: { $0.provider == provider }) else {
            throw AppError.noAPIKey(provider)
        }
        guard let key = try readKey(for: entry.id), !key.isEmpty else {
            throw AppError.noAPIKey(provider)
        }
        return key
    }

    /// Retrieves the API key for a provider from a pre-loaded keys dictionary.
    static func apiKey(
        for provider: AIProvider,
        entries: [APIKeyEntry],
        cachedKeys: [String: String]
    ) throws -> String {
        guard let entry = entries.first(where: { $0.provider == provider }) else {
            throw AppError.noAPIKey(provider)
        }
        guard let key = cachedKeys[entry.id.uuidString], !key.isEmpty else {
            throw AppError.noAPIKey(provider)
        }
        return key
    }
}
