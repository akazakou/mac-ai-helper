// APIKeyStoreTests.swift
// Tests for APIKeyStore CRUD operations.

import Foundation
import Testing

@testable import MacAIHelperLib

@Suite("APIKeyStore Tests")
struct APIKeyStoreTests {
    /// A temporary directory per test keeps the user's real API keys untouched
    private let store = APIKeyStore(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("MacAIHelperTests-\(UUID().uuidString)", isDirectory: true)
    )

    @Test("Save and read key round-trip")
    func saveAndReadKey() throws {
        let entryId = UUID()
        let testKey = "test-api-key-\(UUID().uuidString)"

        // Save
        try store.saveKey(testKey, for: entryId)

        // Read
        let retrieved = try store.readKey(for: entryId)
        #expect(retrieved == testKey)

        // Cleanup
        try store.deleteKey(for: entryId)
    }

    @Test("Reading non-existent key returns nil")
    func readNonExistentKey() throws {
        let entryId = UUID()
        let result = try store.readKey(for: entryId)
        #expect(result == nil)
    }

    @Test("Delete key removes it from the store")
    func deleteKey() throws {
        let entryId = UUID()
        let testKey = "test-key-to-delete"

        try store.saveKey(testKey, for: entryId)
        try store.deleteKey(for: entryId)

        let result = try store.readKey(for: entryId)
        #expect(result == nil)
    }

    @Test("Update key overwrites existing value")
    func updateKey() throws {
        let entryId = UUID()
        let originalKey = "original-key"
        let updatedKey = "updated-key"

        try store.saveKey(originalKey, for: entryId)
        try store.updateKey(updatedKey, for: entryId)

        let retrieved = try store.readKey(for: entryId)
        #expect(retrieved == updatedKey)

        // Cleanup
        try store.deleteKey(for: entryId)
    }

    @Test("Save overwrites existing key")
    func saveOverwritesExisting() throws {
        let entryId = UUID()
        let firstKey = "first-key"
        let secondKey = "second-key"

        try store.saveKey(firstKey, for: entryId)
        try store.saveKey(secondKey, for: entryId)

        let retrieved = try store.readKey(for: entryId)
        #expect(retrieved == secondKey)

        // Cleanup
        try store.deleteKey(for: entryId)
    }

    @Test("Delete non-existent key does not throw")
    func deleteNonExistentKey() throws {
        let entryId = UUID()
        // Should not throw for non-existent keys
        try store.deleteKey(for: entryId)
    }

    @Test("API key lookup for provider")
    func apiKeyForProvider() throws {
        let entryId = UUID()
        let testKey = "test-openai-key"
        let entry = APIKeyEntry(id: entryId, provider: .openAI, label: "Test")

        try store.saveKey(testKey, for: entryId)

        let result = try store.apiKey(for: .openAI, entries: [entry])
        #expect(result == testKey)

        // Cleanup
        try store.deleteKey(for: entryId)
    }

    @Test("API key lookup throws when no entry exists")
    func apiKeyThrowsForMissingProvider() {
        #expect(throws: AppError.self) {
            _ = try store.apiKey(for: .anthropic, entries: [])
        }
    }
}
