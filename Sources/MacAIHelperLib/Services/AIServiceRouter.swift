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
        _ prompt: String, model: String, provider: AIProvider, apiKey: String
    ) async throws -> String {
        try await service(for: provider).sendPrompt(prompt, model: model, apiKey: apiKey)
    }

    /// Sends a prompt with an image to the specified model via the appropriate provider.
    static func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, provider: AIProvider, apiKey: String
    ) async throws -> String {
        try await service(for: provider).sendPromptWithImage(
            prompt, imageData: imageData, model: model, apiKey: apiKey
        )
    }
}
