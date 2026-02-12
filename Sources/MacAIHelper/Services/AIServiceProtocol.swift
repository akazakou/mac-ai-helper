// AIServiceProtocol.swift
// Protocol defining the interface for AI provider services.

import Foundation

protocol AIServiceProtocol: Sendable {
    /// The AI provider this service handles
    var provider: AIProvider { get }

    /// Fetches the list of available models from the provider's API.
    func fetchModels(apiKey: String) async throws -> [AIModel]

    /// Sends a text prompt to the specified model and returns the response.
    func sendPrompt(_ prompt: String, model: String, apiKey: String) async throws -> String

    /// Sends a prompt with an image to the specified model and returns the response.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String
    ) async throws -> String
}
