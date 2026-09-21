// AnthropicService.swift
// Handles communication with the Anthropic (Claude) API for model listing and messages.

import Foundation

struct AnthropicService: AIServiceProtocol {
    let provider: AIProvider = .anthropic

    /// Required Anthropic API version header
    private let anthropicVersion = "2023-06-01"

    // MARK: - Fetch Models

    /// GET /v1/models — lists available Anthropic models.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        let url = provider.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await AIRequestLogger.perform(
            request, metadata: .modelListing(provider: provider)
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
        return decoded.data
            .map { AIModel(id: $0.id, name: $0.displayName ?? $0.id, provider: .anthropic) }
            .sorted { $0.id < $1.id }
    }

    // MARK: - Send Text Prompt

    /// POST /v1/messages — sends a text prompt to Claude.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        let url = provider.baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": SystemPromptFactory.currentDateTimeSystemPrompt(),
            "messages": [
                ["role": "user", "content": prompt]
            ],
        ]
        if webSearch {
            applyWebSearchTool(to: &body)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: webSearch, hasImage: false,
                purpose: "text prompt"
            )
        )
        try validateResponse(response, data: data)

        return try extractText(from: data)
    }

    // MARK: - Send Prompt with Image

    /// POST /v1/messages — sends a prompt with a base64-encoded image to Claude.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        let url = provider.baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64Image = imageData.base64EncodedString()
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": SystemPromptFactory.currentDateTimeSystemPrompt(),
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": base64Image,
                            ],
                        ] as [String: Any],
                        ["type": "text", "text": prompt],
                    ],
                ] as [String: Any]
            ],
        ]
        if webSearch {
            applyWebSearchTool(to: &body)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: webSearch, hasImage: true,
                purpose: "image prompt"
            )
        )
        try validateResponse(response, data: data)

        return try extractText(from: data)
    }

    // MARK: - Helpers

    /// Adds Anthropic's server-side web search tool to a request body.
    private func applyWebSearchTool(to body: inout [String: Any]) {
        body["tools"] = [
            [
                "type": "web_search_20250305",
                "name": "web_search",
            ]
        ]
    }

    /// Extracts the answer text from a messages response.
    /// Web search responses interleave tool-result blocks with text blocks, so all text is joined.
    private func extractText(from data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        let textBlocks = decoded.content.filter { $0.type == "text" }.compactMap(\.text)
        guard let answer = textBlocks.last, !answer.isEmpty else {
            throw AppError.decodingError("No text content in response")
        }
        return answer
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message =
                (try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Response Types

private struct AnthropicModelsResponse: Decodable {
    let data: [AnthropicModelEntry]
}

private struct AnthropicModelEntry: Decodable {
    let id: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

private struct AnthropicMessageResponse: Decodable {
    let content: [AnthropicContentBlock]
}

private struct AnthropicContentBlock: Decodable {
    let type: String
    let text: String?
}

private struct AnthropicErrorResponse: Decodable {
    let error: AnthropicErrorDetail
}

private struct AnthropicErrorDetail: Decodable {
    let message: String
}
