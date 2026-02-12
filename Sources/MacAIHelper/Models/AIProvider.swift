// AIProvider.swift
// Defines supported AI providers with their API endpoints and configuration URLs.

import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Google Gemini"

    var id: String { rawValue }

    /// Base URL for the provider's API
    var baseURL: URL {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        }
    }

    /// API endpoint path for listing available models
    var modelsEndpoint: String {
        switch self {
        case .openAI: "/models"
        case .anthropic: "/models"
        case .gemini: "/models"
        }
    }

    /// URL to the provider's API key management page
    var helpURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")!
        }
    }
}
