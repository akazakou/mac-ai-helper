// APIKeyStore.swift
// CRUD operations for API keys stored in a JSON file in the Application Support directory.
// All keys are stored as a single JSON object in one file.
// The keys are kept out of the macOS Keychain on purpose: for a self-signed app the Keychain
// ties access to the exact binary, so it asked for the login password after every update.

import Foundation

struct APIKeyStore: Sendable {
    /// File name for the consolidated key store
    private static let fileName = "api-keys.json"

    /// Read and write access for the owner only
    private static let ownerOnlyPermissions = 0o600

    /// Directory that holds the key store file
    private let directory: URL

    /// Defaults to ~/Library/Application Support/MacAIHelper.
    /// Tests must pass a temporary directory: the default one holds the user's real API keys.
    init(directory: URL = AppConstants.dataDirectory) {
        self.directory = directory
    }

    private var fileURL: URL {
        directory.appendingPathComponent(Self.fileName)
    }

    /// Whether the key store file was ever written
    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Internal Store Operations

    /// Reads the consolidated JSON key store from disk.
    /// Returns an empty dictionary if no store exists yet.
    private func readStore() throws -> [String: String] {
        guard exists else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: fileURL))
        } catch {
            throw AppError.keyStoreError("Failed to read key store: \(error.localizedDescription)")
        }
    }

    /// Writes the consolidated JSON key store to disk, readable by the owner only.
    private func writeStore(_ store: [String: String]) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(store).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: Self.ownerOnlyPermissions], ofItemAtPath: fileURL.path
            )
        } catch {
            throw AppError.keyStoreError("Failed to write key store: \(error.localizedDescription)")
        }
    }

    // MARK: - Public CRUD API

    /// Saves an API key to the store for a given entry UUID.
    func saveKey(_ key: String, for entryId: UUID) throws {
        var store = try readStore()
        store[entryId.uuidString] = key
        try writeStore(store)
    }

    /// Retrieves an API key from the store by entry UUID.
    /// Returns nil if no key is found.
    func readKey(for entryId: UUID) throws -> String? {
        let store = try readStore()
        let value = store[entryId.uuidString]
        return (value?.isEmpty == true) ? nil : value
    }

    /// Deletes an API key from the store by entry UUID.
    func deleteKey(for entryId: UUID) throws {
        var store = try readStore()
        store.removeValue(forKey: entryId.uuidString)
        try writeStore(store)
    }

    /// Adds keys that are already mapped by entry UUID string, keeping the stored ones.
    func importKeys(_ keys: [String: String]) throws {
        try writeStore(try readStore().merging(keys) { storedKey, _ in storedKey })
    }

    /// Updates an existing API key in the store (same as saveKey for consolidated store).
    func updateKey(_ key: String, for entryId: UUID) throws {
        try saveKey(key, for: entryId)
    }

    /// Retrieves all API keys in a single read.
    /// Returns a dictionary mapping entry UUID string to its API key.
    func readAllKeys() -> [String: String] {
        do {
            return try readStore()
        } catch {
            Log.keyStore.error("Failed to read key store: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Retrieves the first available API key for a given provider from settings.
    /// Keyless providers get an empty key.
    func apiKey(for provider: AIProvider, entries: [APIKeyEntry]) throws -> String {
        guard provider.requiresAPIKey else { return "" }
        guard let entry = entries.first(where: { $0.provider == provider }) else {
            throw AppError.noAPIKey(provider)
        }
        guard let key = try readKey(for: entry.id), !key.isEmpty else {
            throw AppError.noAPIKey(provider)
        }
        return key
    }

    /// Retrieves the API key for a provider from a pre-loaded keys dictionary.
    /// Keyless providers get an empty key.
    static func apiKey(
        for provider: AIProvider,
        entries: [APIKeyEntry],
        cachedKeys: [String: String]
    ) throws -> String {
        guard provider.requiresAPIKey else { return "" }
        guard let entry = entries.first(where: { $0.provider == provider }) else {
            throw AppError.noAPIKey(provider)
        }
        guard let key = cachedKeys[entry.id.uuidString], !key.isEmpty else {
            throw AppError.noAPIKey(provider)
        }
        return key
    }
}
