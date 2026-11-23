// GoogleTranslateService.swift
// Handles communication with the Google Cloud Translation API (Basic, v2).
// Target languages play the role of "models": AIModel.id is the language code.

import Foundation

struct GoogleTranslateService: AIServiceProtocol {
    let provider: AIProvider = .googleTranslate

    /// Language the names in the languages list are written in
    private static let languageNamesLocale = "en"
    private static let apiKeyHeader = "X-goog-api-key"

    // MARK: - Fetch Languages

    /// GET /language/translate/v2/languages?target=en — lists supported target languages.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        var components = URLComponents(
            url: provider.baseURL.appendingPathComponent("languages"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "target", value: Self.languageNamesLocale)]

        let request = authorizedRequest(url: components.url!, apiKey: apiKey)
        let (data, response) = try await AIRequestLogger.perform(
            request, metadata: .modelListing(provider: provider)
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(
            GoogleTranslateResponse<GoogleTranslateLanguages>.self, from: data
        )
        return decoded.data.languages.map { language in
            AIModel(id: language.language, name: language.name ?? language.language, provider: provider)
        }
    }

    // MARK: - Translate Text

    /// POST /language/translate/v2 — translates the text into the target language given as `model`.
    /// The source language is detected by Google. Web search does not apply to translation.
    // ponytail: one request per text, Google rejects very long texts; split into chunks if users hit the limit.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        var request = authorizedRequest(url: provider.baseURL, apiKey: apiKey)
        request.httpMethod = "POST"
        // "text" keeps the translation free of HTML entities (the API default format is HTML).
        request.httpBody = try JSONEncoder().encode(
            GoogleTranslateRequest(q: prompt, target: model, format: "text")
        )

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: false, hasImage: false,
                purpose: "translation"
            )
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(
            GoogleTranslateResponse<GoogleTranslateTranslations>.self, from: data
        )
        guard let translation = decoded.data.translations.first else {
            throw AppError.decodingError("No translation in Google Translate response")
        }
        return translation.translatedText
    }

    // MARK: - Images

    /// The Cloud Translation API translates text only.
    func sendPromptWithImage(
        _ prompt: String, imageData: Data, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        throw AppError.imageNotSupported(provider)
    }

    // MARK: - Helpers

    /// The key travels in a header, so it never appears in URLs or logs.
    private func authorizedRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message =
                (try? JSONDecoder().decode(GoogleTranslateErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Request and Response Types

private struct GoogleTranslateRequest: Encodable {
    /// Text to translate ("q" is the field name the API requires)
    let q: String
    let target: String
    let format: String
}

/// Every successful response wraps its payload in a "data" object.
private struct GoogleTranslateResponse<Payload: Decodable>: Decodable {
    let data: Payload
}

private struct GoogleTranslateLanguages: Decodable {
    let languages: [GoogleTranslateLanguage]
}

private struct GoogleTranslateLanguage: Decodable {
    /// Language code, e.g. "en"
    let language: String
    let name: String?
}

private struct GoogleTranslateTranslations: Decodable {
    let translations: [GoogleTranslateTranslation]
}

private struct GoogleTranslateTranslation: Decodable {
    let translatedText: String
}

private struct GoogleTranslateErrorResponse: Decodable {
    let error: GoogleTranslateErrorDetail
}

private struct GoogleTranslateErrorDetail: Decodable {
    let message: String
}
