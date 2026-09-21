// OpenRouterService.swift
// Handles communication with the OpenRouter API for model listing and chat completions.
// OpenRouter exposes an OpenAI-compatible API, so request/response shapes mirror OpenAIService.

import Foundation

struct OpenRouterService: AIServiceProtocol {
    let provider: AIProvider = .openRouter

    // MARK: - Fetch Models

    /// GET /api/v1/models — lists available models, filtered to text-output (chat-capable) ones.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        var request = URLRequest(url: modelsURL)
        applyHeaders(to: &request, apiKey: apiKey)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        return decoded.data
            .filter { model in
                model.architecture?.outputModalities?.contains("text") ?? false
            }
            .map { AIModel(id: $0.id, name: $0.name ?? $0.id, provider: .openRouter) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Send Text Prompt

    /// POST /api/v1/chat/completions — sends a text prompt.
    func sendPrompt(_ prompt: String, model: String, apiKey: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": SystemPromptFactory.currentDateTimeSystemPrompt()],
                ["role": "user", "content": prompt]
            ],
        ]
        return try await sendChatCompletion(body: body, apiKey: apiKey)
    }

    // MARK: - Send Prompt with Image

    /// POST /api/v1/chat/completions — sends a prompt with a base64-encoded image.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String
    ) async throws -> String {
        let base64Image = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": SystemPromptFactory.currentDateTimeSystemPrompt()],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/png;base64,\(base64Image)"],
                        ],
                    ],
                ] as [String: Any]
            ],
        ]
        return try await sendChatCompletion(body: body, apiKey: apiKey)
    }

    // MARK: - Helpers

    private var modelsURL: URL {
        provider.baseURL.appendingPathComponent("models")
    }

    private var chatCompletionsURL: URL {
        provider.baseURL.appendingPathComponent("chat/completions")
    }

    /// Applies Bearer auth plus OpenRouter's optional app attribution header.
    private func applyHeaders(to request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mac AI Helper", forHTTPHeaderField: "X-Title")
    }

    /// POSTs a chat completion body and extracts the assistant message content.
    private func sendChatCompletion(body: [String: Any], apiKey: String) async throws -> String {
        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        applyHeaders(to: &request, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AppError.decodingError("No content in response")
        }
        return content
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message =
                (try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data))?.error
                    .message
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Response Types

private struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModelEntry]
}

private struct OpenRouterModelEntry: Decodable {
    let id: String
    let name: String?
    let architecture: OpenRouterModelArchitecture?
}

private struct OpenRouterModelArchitecture: Decodable {
    let outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case outputModalities = "output_modalities"
    }
}

private struct OpenRouterChatResponse: Decodable {
    let choices: [OpenRouterChatChoice]
}

private struct OpenRouterChatChoice: Decodable {
    let message: OpenRouterChatMessage
}

private struct OpenRouterChatMessage: Decodable {
    let content: String?
}

private struct OpenRouterErrorResponse: Decodable {
    let error: OpenRouterErrorDetail
}

private struct OpenRouterErrorDetail: Decodable {
    let message: String
}
