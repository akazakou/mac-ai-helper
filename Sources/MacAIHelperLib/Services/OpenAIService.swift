// OpenAIService.swift
// Handles communication with the OpenAI API for model listing and chat completions.

import Foundation

struct OpenAIService: AIServiceProtocol {
    let provider: AIProvider = .openAI

    // MARK: - Fetch Models

    /// GET /v1/models — lists available models, filtered to chat-capable ones.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        let url = provider.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)

        // Filter to chat-capable models (GPT, O1, O3 series)
        let chatModelPrefixes = ["gpt-", "o1", "o3", "o4"]
        return decoded.data
            .filter { model in
                chatModelPrefixes.contains(where: { model.id.lowercased().hasPrefix($0) })
            }
            .map { AIModel(id: $0.id, name: $0.id, provider: .openAI) }
            .sorted { $0.id < $1.id }
    }

    // MARK: - Send Text Prompt

    /// POST /v1/chat/completions — sends a text prompt.
    func sendPrompt(_ prompt: String, model: String, apiKey: String) async throws -> String {
        let url = provider.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AppError.decodingError("No content in response")
        }
        return content
    }

    // MARK: - Send Prompt with Image

    /// POST /v1/chat/completions — sends a prompt with a base64-encoded image.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String
    ) async throws -> String {
        let url = provider.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64Image = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": model,
            "messages": [
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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AppError.decodingError("No content in response")
        }
        return content
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message =
                (try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Response Types

private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModelEntry]
}

private struct OpenAIModelEntry: Decodable {
    let id: String
}

private struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChatChoice]
}

private struct OpenAIChatChoice: Decodable {
    let message: OpenAIChatMessage
}

private struct OpenAIChatMessage: Decodable {
    let content: String?
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIErrorDetail
}

private struct OpenAIErrorDetail: Decodable {
    let message: String
}
