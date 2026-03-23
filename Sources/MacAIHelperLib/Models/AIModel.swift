// AIModel.swift
// Represents an AI model from a specific provider.

import Foundation

public struct AIModel: Identifiable, Codable, Hashable, Sendable {
    /// Model identifier used in API calls, e.g. "gpt-4o", "claude-sonnet-4-5", "gemini-2.5-pro"
    public let id: String
    /// Human-readable display name
    public let name: String
    /// The provider this model belongs to
    public let provider: AIProvider

    public init(id: String, name: String, provider: AIProvider) {
        self.id = id
        self.name = name
        self.provider = provider
    }
}
