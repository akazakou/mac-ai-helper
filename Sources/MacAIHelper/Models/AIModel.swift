// AIModel.swift
// Represents an AI model from a specific provider.

import Foundation

struct AIModel: Identifiable, Codable, Hashable, Sendable {
    /// Model identifier used in API calls, e.g. "gpt-4o", "claude-sonnet-4-5", "gemini-2.5-pro"
    let id: String
    /// Human-readable display name
    let name: String
    /// The provider this model belongs to
    let provider: AIProvider
}
