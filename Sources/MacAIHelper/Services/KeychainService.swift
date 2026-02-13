// KeychainService.swift
// CRUD operations for API keys stored securely in the macOS Keychain.
// All keys are stored as a single JSON blob in one keychain item
// to avoid multiple password prompts on access.

import Foundation
import Security

struct KeychainService: Sendable {
    /// Keychain service identifier
    private static let serviceName = "pro.kantora.MacAIHelper"

    /// Fixed account name for the consolidated key store
    private static let storeAccount = "api-keys-store"

    // MARK: - Internal Store Operations


    /// Reads the consolidated JSON key store from the Keychain.
    /// Returns an empty dictionary if no store exists yet.
    private static func readStore() throws -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: storeAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw AppError.keychainError("Failed to read key store data")
            }
            guard let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                throw AppError.keychainError("Failed to decode key store JSON")
            }
            return dict
        case errSecItemNotFound:
            return [:]
        default:
            throw AppError.keychainError(
                "Failed to read key store: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)"
            )
        }
    }

    /// Writes the consolidated JSON key store to the Keychain.
    private static func writeStore(_ store: [String: String]) throws {
        guard let data = try? JSONEncoder().encode(store) else {
            throw AppError.keychainError("Failed to encode key store JSON")
        }

        // Try to update existing item first
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: storeAccount,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet — create it
            var addQuery = searchQuery
            addQuery[kSecValueData as String] = data

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AppError.keychainError(
                    "Failed to create key store: \(SecCopyErrorMessageString(addStatus, nil) ?? "Unknown error" as CFString)"
                )
            }
        } else if updateStatus != errSecSuccess {
            throw AppError.keychainError(
                "Failed to update key store: \(SecCopyErrorMessageString(updateStatus, nil) ?? "Unknown error" as CFString)"
            )
        }
    }

    // MARK: - Public CRUD API

    /// Saves an API key to the Keychain for a given entry UUID.
    static func saveKey(_ key: String, for entryId: UUID) throws {
        var store = try readStore()
        store[entryId.uuidString] = key
        try writeStore(store)
    }

    /// Retrieves an API key from the Keychain by entry UUID.
    /// Returns nil if no key is found.
    static func readKey(for entryId: UUID) throws -> String? {
        let store = try readStore()
        let value = store[entryId.uuidString]
        return (value?.isEmpty == true) ? nil : value
    }

    /// Deletes an API key from the Keychain by entry UUID.
    static func deleteKey(for entryId: UUID) throws {
        var store = try readStore()
        store.removeValue(forKey: entryId.uuidString)
        if store.isEmpty {
            // Remove the entire keychain item when no keys remain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: storeAccount,
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw AppError.keychainError(
                    "Failed to delete key store: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)"
                )
            }
        } else {
            try writeStore(store)
        }
    }

    /// Updates an existing API key in the Keychain (same as saveKey for consolidated store).
    static func updateKey(_ key: String, for entryId: UUID) throws {
        try saveKey(key, for: entryId)
    }

    /// Retrieves all API keys in a single Keychain read.
    /// Returns a dictionary mapping entry UUID string to its API key.
    static func readAllKeys() -> [String: String] {
        do {
            return try readStore()
        } catch {
            print("⚠️ Failed to read key store: \(error.localizedDescription)")
            return [:]
        }
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
