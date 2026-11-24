// GoogleTranslateFreeService.swift
// Translates through the keyless endpoint the Google Translate web client uses.
// Target languages play the role of "models": AIModel.id is the language code.
// ponytail: undocumented endpoint, Google may rate-limit or change it without notice;
// the official API (GoogleTranslateService, own API key) is the stable path.

import Foundation

struct GoogleTranslateFreeService: TranslationServiceProtocol {
    let provider: AIProvider = .googleTranslateFree

    /// Client id the endpoint accepts without an API key
    private static let clientId = "gtx"
    /// Language the names in the languages list are written in
    private static let languageNamesLocale = "en"
    private static let tooManyRequestsStatusCode = 429

    // MARK: - Fetch Languages

    /// GET /translate_a/l?client=gtx&hl=en — lists supported target languages. No key is needed.
    func fetchModels(apiKey: String) async throws -> [AIModel] {
        let url = endpointURL(
            path: "l",
            queryItems: [URLQueryItem(name: "hl", value: Self.languageNamesLocale)]
        )
        let (data, response) = try await AIRequestLogger.perform(
            URLRequest(url: url), metadata: .modelListing(provider: provider)
        )
        try validateResponse(response)

        let decoded = try JSONDecoder().decode(FreeTranslateLanguages.self, from: data)
        return decoded.targetLanguages.map { code, name in
            AIModel(id: code, name: name, provider: provider)
        }
    }

    // MARK: - Translate Text

    /// POST /translate_a/single — translates the text into the target language given as `model`.
    /// The source language is detected by Google. Web search does not apply to translation.
    func sendPrompt(
        _ prompt: String, model: String, apiKey: String, webSearch: Bool
    ) async throws -> String {
        let url = endpointURL(
            path: "single",
            queryItems: [
                URLQueryItem(name: "sl", value: "auto"),
                URLQueryItem(name: "tl", value: model),
                // dt=t requests the translation, dj=1 a JSON object instead of nested arrays.
                URLQueryItem(name: "dt", value: "t"),
                URLQueryItem(name: "dj", value: "1"),
            ]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type"
        )
        // The text travels in the body, so it never appears in URLs or logs.
        request.httpBody = Data(formEncoded(name: "q", value: prompt).utf8)

        let (data, response) = try await AIRequestLogger.perform(
            request,
            metadata: AIRequestLogger.Metadata(
                provider: provider, model: model, webSearch: false, hasImage: false,
                purpose: "translation"
            )
        )
        try validateResponse(response)

        let decoded = try JSONDecoder().decode(FreeTranslateResponse.self, from: data)
        // Google splits the text into sentences; each piece keeps its own spacing and line breaks.
        let translation = decoded.sentences.compactMap(\.trans).joined()
        guard !translation.isEmpty else {
            throw AppError.decodingError("No translation in Google Translate response")
        }
        return translation
    }

    // MARK: - Translate Several Texts

    /// The endpoint takes one text per request, so the texts travel as lines of a single text.
    /// If Google does not return the same number of lines, each text is translated on its own.
    func translate(
        _ texts: [String], into languageCode: String, apiKey: String
    ) async throws -> [String] {
        let lines = texts.map { $0.replacingOccurrences(of: "\n", with: " ") }
        let joinedTranslation = try await sendPrompt(
            lines.joined(separator: "\n"), model: languageCode, apiKey: apiKey, webSearch: false
        )
        let translations = joinedTranslation.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if translations.count == texts.count {
            return translations
        }

        var separateTranslations: [String] = []
        for line in lines {
            separateTranslations.append(
                try await sendPrompt(line, model: languageCode, apiKey: apiKey, webSearch: false)
            )
        }
        return separateTranslations
    }

    // MARK: - Helpers

    private func endpointURL(path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(
            url: provider.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "client", value: Self.clientId)] + queryItems
        return components.url!
    }

    /// Builds a "name=value" form body. URLComponents leaves "+" as is, but a form
    /// decoder reads it as a space, so it is escaped separately.
    private func formEncoded(name: String, value: String) -> String {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: name, value: value)]
        return (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
    }

    /// Error bodies are HTML pages, so the message is built from the status code alone.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = httpResponse.statusCode == Self.tooManyRequestsStatusCode
                ? "Google is limiting requests to the free Translate endpoint. "
                    + "Try again later, or add a Google Translate API key."
                : "The free Google Translate endpoint rejected the request."
            throw AppError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Response Types

private struct FreeTranslateLanguages: Decodable {
    /// Language code → English name, e.g. "en": "English"
    let targetLanguages: [String: String]

    enum CodingKeys: String, CodingKey {
        case targetLanguages = "tl"
    }
}

private struct FreeTranslateResponse: Decodable {
    let sentences: [FreeTranslateSentence]
}

private struct FreeTranslateSentence: Decodable {
    /// Translated piece; absent in entries that carry only transliteration data
    let trans: String?
}
