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

    /// Unique across providers. `id` alone is not: both Google Translate providers use
    /// language codes ("ru"), and different providers can offer a model with the same id.
    public var uniqueID: String {
        "\(provider.rawValue)/\(id)"
    }

    public init(id: String, name: String, provider: AIProvider) {
        self.id = id
        self.name = name
        self.provider = provider
    }
}
