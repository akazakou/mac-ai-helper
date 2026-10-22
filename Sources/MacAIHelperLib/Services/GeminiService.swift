// GeminiService.swift
// Handles communication with the Google Gemini API for model listing and content generation.

import Foundation

struct GeminiService: AIServiceProtocol {
    let provider: AIProvider = .gemini

    // MARK: - Fetch Models

    /// GET /v1beta/models?key={key} — lists available Gemini models.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        var components = URLComponents(
            url: provider.baseURL.appendingPathComponent("models"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await AIRequestLogger.perform(
            request, metadata: .modelListing(provider: provider)
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
        return decoded.models
            .filter { model in
                // Only include models that support generateContent
                model.supportedGenerationMethods?.contains("generateContent") ?? false
            }
            .map { model in
                // Strip "models/" prefix from the name
                let modelId = model.name.hasPrefix("models/")
                    ? String(model.name.dropFirst("models/".count))
                    : model.name
                return AIModel(
                    id: modelId,
                    name: model.displayName ?? modelId,
                    provider: .gemini
                )
            }
            .sorted { $0.id < $1.id }
    }

    // MARK: - Send Text Prompt

    /// POST /v1beta/models/{model}:generateContent?key={key} — sends a text prompt.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        var body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": SystemPromptFactory.currentDateTimeSystemPrompt()]
                ]
            ],
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        if webSearch {
            applyGoogleSearchTool(to: &body)
        }
        return try await generateContent(
            model: model, apiKey: apiKey, body: body, hasImage: false, webSearch: webSearch
        )
    }

    // MARK: - Send Prompt with Image

    /// POST /v1beta/models/{model}:generateContent?key={key} — sends a prompt with an image.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        let base64Image = imageData.base64EncodedString()
        var body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": SystemPromptFactory.currentDateTimeSystemPrompt()]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": base64Image,
                            ]
                        ],
                        ["text": prompt],
                    ]
                ]
            ]
        ]
        if webSearch {
            applyGoogleSearchTool(to: &body)
        }
        return try await generateContent(
            model: model, apiKey: apiKey, body: body, hasImage: true, webSearch: webSearch
        )
    }

    // MARK: - Helpers

    /// Adds Gemini's native Google Search grounding tool to a request body.
    private func applyGoogleSearchTool(to body: inout [String: Any]) {
        body["tools"] = [["google_search": [String: String]()]]
    }

    /// POSTs a generateContent body and extracts the first text part from the response.
    private func generateContent(
        model: String, apiKey: String, body: [String: Any], hasImage: Bool, webSearch: Bool
    ) async throws -> String {
        let url = try buildGenerateContentURL(model: model, apiKey: apiKey)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: webSearch, hasImage: hasImage,
                purpose: "prompt"
            )
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content.parts.compactMap(\.text).first else {
            throw AppError.decodingError("No text content in Gemini response")
        }
        return text
    }

    private func buildGenerateContentURL(model: String, apiKey: String) throws -> URL {
        let path = "models/\(model):generateContent"
        var components = URLComponents(
            url: provider.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw AppError.networkError("Failed to construct Gemini URL")
        }
        return url
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message =
                (try? JSONDecoder().decode(GeminiErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Response Types

private struct GeminiModelsResponse: Decodable {
    let models: [GeminiModelEntry]
}

private struct GeminiModelEntry: Decodable {
    let name: String
    let displayName: String?
    let supportedGenerationMethods: [String]?
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct GeminiContent: Decodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Decodable {
    let text: String?
}

private struct GeminiErrorResponse: Decodable {
    let error: GeminiErrorDetail
}

private struct GeminiErrorDetail: Decodable {
    let message: String
}
