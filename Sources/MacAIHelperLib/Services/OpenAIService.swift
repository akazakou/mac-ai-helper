// OpenAIService.swift
// Handles communication with the OpenAI API for model listing and chat completions.
// Web-search requests use the Responses API, which is the only API exposing
// OpenAI's native web_search tool.

import Foundation

struct OpenAIService: AIServiceProtocol {
    let provider: AIProvider = .openAI

    // MARK: - Fetch Models

    /// GET /v1/models — lists available models, filtered to chat-capable ones.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        let url = provider.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await AIRequestLogger.perform(
            request, metadata: .modelListing(provider: provider)
        )
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

    /// POST /v1/chat/completions (or /v1/responses with the web_search tool) — sends a text prompt.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        if webSearch {
            return try await sendResponsesRequest(
                userContent: [["type": "input_text", "text": prompt]],
                model: model,
                apiKey: apiKey,
                hasImage: false
            )
        }

        let url = provider.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": SystemPromptFactory.currentDateTimeSystemPrompt()],
                ["role": "user", "content": prompt]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: webSearch, hasImage: false,
                purpose: "text prompt"
            )
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AppError.decodingError("No content in response")
        }
        return content
    }

    // MARK: - Send Prompt with Image

    /// POST /v1/chat/completions (or /v1/responses with the web_search tool) — sends a prompt with a base64-encoded image.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        let base64Image = imageData.base64EncodedString()
        let dataURL = "data:image/png;base64,\(base64Image)"

        if webSearch {
            return try await sendResponsesRequest(
                userContent: [
                    ["type": "input_text", "text": prompt],
                    ["type": "input_image", "image_url": dataURL],
                ],
                model: model,
                apiKey: apiKey,
                hasImage: true
            )
        }

        let url = provider.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                            "image_url": ["url": dataURL],
                        ],
                    ],
                ] as [String: Any]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: webSearch, hasImage: true,
                purpose: "image prompt"
            )
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AppError.decodingError("No content in response")
        }
        return content
    }

    // MARK: - Helpers

    /// POST /v1/responses — sends a prompt with OpenAI's native web_search tool enabled.
    private func sendResponsesRequest(
        userContent: [[String: Any]], model: String, apiKey: String, hasImage: Bool
    ) async throws -> String {
        let url = provider.baseURL.appendingPathComponent("responses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "instructions": SystemPromptFactory.currentDateTimeSystemPrompt(),
            "input": [
                ["role": "user", "content": userContent]
            ],
            "tools": [
                ["type": "web_search"]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: true, hasImage: hasImage,
                purpose: "text prompt (Responses API, web search)"
            )
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        let text = decoded.output
            .compactMap { $0.content }
            .flatMap { $0 }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n\n")
        guard !text.isEmpty else {
            throw AppError.decodingError("No content in response")
        }
        return text
    }

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

private struct OpenAIResponsesResponse: Decodable {
    let output: [OpenAIResponsesOutputItem]
}

private struct OpenAIResponsesOutputItem: Decodable {
    let type: String
    let content: [OpenAIResponsesContentBlock]?
}

private struct OpenAIResponsesContentBlock: Decodable {
    let type: String
    let text: String?
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIErrorDetail
}

private struct OpenAIErrorDetail: Decodable {
    let message: String
}
