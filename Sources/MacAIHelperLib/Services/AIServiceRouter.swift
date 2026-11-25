// AIServiceRouter.swift
// Routes AI requests to the correct provider service implementation.

import Foundation

struct AIServiceRouter: Sendable {
    /// Returns the appropriate service for a given AI provider.
    static func service(for provider: AIProvider) -> AIServiceProtocol {
        switch provider {
        case .openAI: OpenAIService()
        case .anthropic: AnthropicService()
        case .gemini: GeminiService()
        case .openRouter: OpenRouterService()
        case .googleTranslate: GoogleTranslateService()
        case .googleTranslateFree: GoogleTranslateFreeService()
        }
    }

    /// Returns the service of a translation provider, configured from its API key entry,
    /// or nil for an AI model provider.
    static func translationService(
        for provider: AIProvider, entries: [APIKeyEntry]
    ) -> TranslationServiceProtocol? {
        switch provider {
        case .googleTranslate:
            GoogleTranslateService(projectId: entries.first { $0.provider == provider }?.projectId)
        case .googleTranslateFree:
            GoogleTranslateFreeService()
        case .openAI, .anthropic, .gemini, .openRouter:
            nil
        }
    }

    /// Fetches available models from the specified provider.
    static func fetchModels(
        provider: AIProvider, apiKey: String
    ) async throws -> [AIModel] {
        try await service(for: provider).fetchModels(apiKey: apiKey)
    }

    /// Sends a text prompt to the specified model via the appropriate provider.
    static func sendPrompt(
        _ prompt: String, model: String, provider: AIProvider, apiKey: String, webSearch: Bool
    ) async throws -> String {
        try await service(for: provider).sendPrompt(
            prompt, model: model, apiKey: apiKey, webSearch: webSearch
        )
    }

    /// Sends a prompt with an image to the specified model via the appropriate provider.
    static func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, provider: AIProvider, apiKey: String,
        webSearch: Bool
    ) async throws -> String {
        try await service(for: provider).sendPromptWithImage(
            prompt, imageData: imageData, model: model, apiKey: apiKey, webSearch: webSearch
        )
    }
}
