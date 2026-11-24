// AIProvider.swift
// Defines supported AI providers with their API endpoints and configuration URLs.

import Foundation

public enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Google Gemini"
    case openRouter = "OpenRouter"
    case googleTranslate = "Google Translate"
    case googleTranslateFree = "Google Translate (Free)"

    public var id: String { rawValue }

    /// Compact label shown next to model names, e.g. "[Google] Gemma 3"
    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Google"
        case .openRouter: "OpenRouter"
        case .googleTranslate: "Google Translate"
        case .googleTranslateFree: "Google Translate Free"
        }
    }

    /// Base URL for the provider's API
    public var baseURL: URL {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")!
        case .googleTranslate: URL(string: "https://translation.googleapis.com/language/translate/v2")!
        case .googleTranslateFree: URL(string: "https://translate.googleapis.com/translate_a")!
        }
    }

    /// URL to the provider's API key management page (the product page for keyless providers)
    public var helpURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")!
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")!
        case .googleTranslate: URL(string: "https://console.cloud.google.com/apis/credentials")!
        case .googleTranslateFree: URL(string: "https://translate.google.com")!
        }
    }

    /// Translation services receive the captured text as-is (no prompt template),
    /// return plain text, and expose target languages as their "models".
    public var isTranslationService: Bool {
        self == .googleTranslate || self == .googleTranslateFree
    }

    /// Keyless providers are always available and never appear in the API Keys tab.
    public var requiresAPIKey: Bool {
        self != .googleTranslateFree
    }
}
