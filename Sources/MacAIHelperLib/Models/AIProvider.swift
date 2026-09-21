// AIProvider.swift
// Defines supported AI providers with their API endpoints and configuration URLs.

import Foundation

public enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Google Gemini"
    case openRouter = "OpenRouter"

    public var id: String { rawValue }

    /// Base URL for the provider's API
    public var baseURL: URL {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")!
        }
    }

    /// API endpoint path for listing available models
    public var modelsEndpoint: String {
        switch self {
        case .openAI: "/models"
        case .anthropic: "/models"
        case .gemini: "/models"
        case .openRouter: "/models"
        }
    }

    /// URL to the provider's API key management page
    public var helpURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")!
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")!
        }
    }
}
