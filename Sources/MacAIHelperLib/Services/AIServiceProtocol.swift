// AIServiceProtocol.swift
// Protocol defining the interface for AI provider services.

import Foundation

protocol AIServiceProtocol: Sendable {
    /// The AI provider this service handles
    var provider: AIProvider { get }

    /// Fetches the list of available models from the provider's API.
    func fetchModels(apiKey: String) async throws -> [AIModel]

    /// Sends a text prompt to the specified model and returns the response.
    /// When webSearch is true, the provider's native web search tool is enabled.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String

    /// Sends a prompt with an image to the specified model and returns the response.
    /// When webSearch is true, the provider's native web search tool is enabled.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String
}

/// A provider that translates text. Its "models" are target languages (AIModel.id is the language code).
protocol TranslationServiceProtocol: AIServiceProtocol {
    /// Translates every text into the target language. The result keeps the order and count of `texts`.
    func translate(
        _ texts: [String], into languageCode: String, apiKey: String
    ) async throws -> [String]
}

extension TranslationServiceProtocol {
    /// Translation services return text only; screenshots are handled by ImageTranslationService,
    /// which recognizes the text first.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        throw AppError.imageNotSupported(provider)
    }
}
