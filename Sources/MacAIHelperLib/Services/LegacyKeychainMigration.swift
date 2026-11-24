// LegacyKeychainMigration.swift
// Moves API keys saved by versions up to 1.1.0 from the macOS Keychain into APIKeyStore.
// macOS asks for the login password one last time, because the Keychain item
// still belongs to the binary that created it.

import Foundation
import Security

enum LegacyKeychainMigration {
    /// Keychain service identifier
    private static let serviceName = "com.castloud.MacAIHelper"

    /// Fixed account name for the consolidated key store
    private static let storeAccount = "api-keys-store"

    private static var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: storeAccount,
        ]
    }

    /// Runs only until the store file exists, so the Keychain is asked at most once after a successful move.
    static func moveKeys(to store: APIKeyStore) {
        guard !store.exists, let keys = readKeychainKeys() else { return }

        do {
            try store.importKeys(keys)
        } catch {
            Log.keyStore.error("Keychain migration failed, keys stay in the Keychain: \(error.localizedDescription)")
            return
        }

        let deleteStatus = SecItemDelete(itemQuery as CFDictionary)
        if deleteStatus != errSecSuccess {
            Log.keyStore.error("Migrated keys were not removed from the Keychain (status \(deleteStatus))")
        }
    }

    /// Returns nil when there is nothing to migrate or the user denied Keychain access.
    private static func readKeychainKeys() -> [String: String]? {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }

        guard status == errSecSuccess, let data = result as? Data,
              let keys = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            Log.keyStore.error("Failed to read legacy Keychain key store (status \(status))")
            return nil
        }
        return keys
    }
}
