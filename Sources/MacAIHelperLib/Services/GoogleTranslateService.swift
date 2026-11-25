// GoogleTranslateService.swift
// Handles communication with the Google Cloud Translation API (Basic, v2).
// Target languages play the role of "models": AIModel.id is the language code.
// With a Google Cloud project ID it uses the Translation LLM instead of the standard model.

import Foundation

struct GoogleTranslateService: TranslationServiceProtocol {
    let provider: AIProvider = .googleTranslate

    /// Google Cloud project that runs the Translation LLM; nil uses the standard model
    let projectId: String?

    /// Language the names in the languages list are written in
    private static let languageNamesLocale = "en"
    private static let apiKeyHeader = "X-goog-api-key"
    /// The API accepts at most 128 texts per request
    private static let maxTextsPerRequest = 100
    /// Region that serves the Translation LLM
    private static let translationLLMRegion = "us-central1"
    /// Returned when the Translation LLM does not support the language pair
    private static let badRequestStatusCode = 400

    init(projectId: String? = nil) {
        self.projectId = projectId
    }

    /// Resource name of the Translation LLM in the user's project
    private var translationLLMModel: String? {
        projectId.map {
            "projects/\($0)/locations/\(Self.translationLLMRegion)/models/general/translation-llm"
        }
    }

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

    /// Translates the text into the target language given as `model`.
    /// The source language is detected by Google. Web search does not apply to translation.
    // ponytail: one request per text, Google rejects very long texts; split into chunks if users hit the limit.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        guard let translation = try await translateBatch([prompt], into: model, apiKey: apiKey).first
        else {
            throw AppError.decodingError("No translation in Google Translate response")
        }
        return translation
    }

    /// Translates the texts in context as lines of one text, and separately if the lines don't match up.
    func translate(
        _ texts: [String], into languageCode: String, apiKey: String
    ) async throws -> [String] {
        let translateText = { (text: String) in
            try await sendPrompt(text, model: languageCode, apiKey: apiKey, webSearch: false)
        }
        if let translations = try await translateAsLines(texts, using: translateText) {
            return translations
        }

        var translations: [String] = []
        for batchStart in stride(from: 0, to: texts.count, by: Self.maxTextsPerRequest) {
            let batch = Array(texts[batchStart..<min(batchStart + Self.maxTextsPerRequest, texts.count)])
            translations += try await translateBatch(batch, into: languageCode, apiKey: apiKey)
        }
        return translations
    }

    /// Makes a test translation with the Translation LLM, so a wrong project ID or a project
    /// without access is reported when the key is added instead of failing later.
    func verifyTranslationLLM(apiKey: String) async throws {
        guard let translationLLMModel else { return }
        _ = try await requestTranslations(
            ["Hello"],
            options: TranslationOptions(languageCode: "de", model: translationLLMModel),
            apiKey: apiKey
        )
    }

    /// Translates up to maxTextsPerRequest texts, with the Translation LLM when it is configured.
    private func translateBatch(
        _ texts: [String], into languageCode: String, apiKey: String
    ) async throws -> [String] {
        let standardOptions = TranslationOptions(languageCode: languageCode, model: nil)
        guard let translationLLMModel else {
            return try await requestTranslations(texts, options: standardOptions, apiKey: apiKey)
        }

        do {
            return try await requestTranslations(
                texts,
                options: TranslationOptions(languageCode: languageCode, model: translationLLMModel),
                apiKey: apiKey
            )
        } catch AppError.apiError(let statusCode, let message) where statusCode == Self.badRequestStatusCode {
            // The Translation LLM covers fewer language pairs than the standard model.
            Log.ai.info(
                "Translation LLM rejected the request, using the standard model: \(message, privacy: .public)"
            )
            return try await requestTranslations(texts, options: standardOptions, apiKey: apiKey)
        }
    }

    /// POST /language/translate/v2 — translates the texts in one request.
    private func requestTranslations(
        _ texts: [String], options: TranslationOptions, apiKey: String
    ) async throws -> [String] {
        var request = authorizedRequest(url: provider.baseURL, apiKey: apiKey)
        request.httpMethod = "POST"
        // "text" keeps the translation free of HTML entities (the API default format is HTML).
        request.httpBody = try JSONEncoder().encode(
            GoogleTranslateRequest(
                q: texts, target: options.languageCode, format: "text", model: options.model
            )
        )

        let loggedModel = options.model == nil ? options.languageCode : "llm:\(options.languageCode)"
        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: loggedModel, webSearch: false, hasImage: false,
                purpose: "translation"
            )
        )
        try validateResponse(response, data: data)

        let decoded = try JSONDecoder().decode(
            GoogleTranslateResponse<GoogleTranslateTranslations>.self, from: data
        )
        guard decoded.data.translations.count == texts.count else {
            throw AppError.decodingError("Google Translate returned an unexpected number of translations")
        }
        return decoded.data.translations.map(\.translatedText)
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

/// Target language and, for the Translation LLM, its resource name
private struct TranslationOptions {
    let languageCode: String
    /// nil selects the standard model
    let model: String?
}

private struct GoogleTranslateRequest: Encodable {
    /// Texts to translate ("q" is the field name the API requires)
    let q: [String]
    let target: String
    let format: String
    /// Translation LLM resource name; omitted from the JSON for the standard model
    let model: String?
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
