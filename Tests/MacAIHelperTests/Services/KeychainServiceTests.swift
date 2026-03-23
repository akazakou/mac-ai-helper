// KeychainServiceTests.swift
// Tests for KeychainService CRUD operations.

import Foundation
import Testing

@testable import MacAIHelperLib

@Suite("KeychainService Tests")
struct KeychainServiceTests {

    @Test("Save and read key round-trip")
    func saveAndReadKey() throws {
        let entryId = UUID()
        let testKey = "test-api-key-\(UUID().uuidString)"

        // Save
        try KeychainService.saveKey(testKey, for: entryId)

        // Read
        let retrieved = try KeychainService.readKey(for: entryId)
        #expect(retrieved == testKey)

        // Cleanup
        try KeychainService.deleteKey(for: entryId)
    }

    @Test("Reading non-existent key returns nil")
    func readNonExistentKey() throws {
        let entryId = UUID()
        let result = try KeychainService.readKey(for: entryId)
        #expect(result == nil)
    }

    @Test("Delete key removes it from Keychain")
    func deleteKey() throws {
        let entryId = UUID()
        let testKey = "test-key-to-delete"

        try KeychainService.saveKey(testKey, for: entryId)
        try KeychainService.deleteKey(for: entryId)

        let result = try KeychainService.readKey(for: entryId)
        #expect(result == nil)
    }

    @Test("Update key overwrites existing value")
    func updateKey() throws {
        let entryId = UUID()
        let originalKey = "original-key"
        let updatedKey = "updated-key"

        try KeychainService.saveKey(originalKey, for: entryId)
        try KeychainService.updateKey(updatedKey, for: entryId)

        let retrieved = try KeychainService.readKey(for: entryId)
        #expect(retrieved == updatedKey)

        // Cleanup
        try KeychainService.deleteKey(for: entryId)
    }

    @Test("Save overwrites existing key")
    func saveOverwritesExisting() throws {
        let entryId = UUID()
        let firstKey = "first-key"
        let secondKey = "second-key"

        try KeychainService.saveKey(firstKey, for: entryId)
        try KeychainService.saveKey(secondKey, for: entryId)

        let retrieved = try KeychainService.readKey(for: entryId)
        #expect(retrieved == secondKey)

        // Cleanup
        try KeychainService.deleteKey(for: entryId)
    }

    @Test("Delete non-existent key does not throw")
    func deleteNonExistentKey() throws {
        let entryId = UUID()
        // Should not throw for non-existent keys
        try KeychainService.deleteKey(for: entryId)
    }

    @Test("API key lookup for provider")
    func apiKeyForProvider() throws {
        let entryId = UUID()
        let testKey = "test-openai-key"
        let entry = APIKeyEntry(id: entryId, provider: .openAI, label: "Test")

        try KeychainService.saveKey(testKey, for: entryId)

        let result = try KeychainService.apiKey(for: .openAI, entries: [entry])
        #expect(result == testKey)

        // Cleanup
        try KeychainService.deleteKey(for: entryId)
    }

    @Test("API key lookup throws when no entry exists")
    func apiKeyThrowsForMissingProvider() {
        #expect(throws: AppError.self) {
            _ = try KeychainService.apiKey(for: .anthropic, entries: [])
        }
    }
}
