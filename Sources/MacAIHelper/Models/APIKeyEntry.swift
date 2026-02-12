// APIKeyEntry.swift
// Metadata for an API key stored in the Keychain.
// The actual key value is never persisted in settings — only in the Keychain.

import Foundation

struct APIKeyEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// The AI provider this key belongs to
    let provider: AIProvider
    /// User-friendly label for display
    var label: String

    init(id: UUID = UUID(), provider: AIProvider, label: String = "") {
        self.id = id
        self.provider = provider
        self.label = label.isEmpty ? provider.rawValue : label
    }
}
