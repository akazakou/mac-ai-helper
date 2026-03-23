// APIKeyEntry.swift
// Metadata for an API key stored in the Keychain.
// The actual key value is never persisted in settings — only in the Keychain.

import Foundation

public struct APIKeyEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// The AI provider this key belongs to
    public let provider: AIProvider
    /// User-friendly label for display
    public var label: String

    public init(id: UUID = UUID(), provider: AIProvider, label: String = "") {
        self.id = id
        self.provider = provider
        self.label = label.isEmpty ? provider.rawValue : label
    }
}
