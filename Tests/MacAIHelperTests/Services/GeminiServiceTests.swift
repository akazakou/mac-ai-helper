// GeminiServiceTests.swift
// Tests for Gemini API response parsing and model name prefix stripping.

import Foundation
import Testing

@testable import MacAIHelperLib

@Suite("GeminiService Tests")
struct GeminiServiceTests {

    @Test("Parse models response and strip models/ prefix")
    func parseModelsResponse() throws {
        let mockJSON = """
            {
                "models": [
                    {
                        "name": "models/gemini-2.5-pro",
                        "displayName": "Gemini 2.5 Pro",
                        "supportedGenerationMethods": ["generateContent", "countTokens"]
                    },
                    {
                        "name": "models/gemini-2.0-flash",
                        "displayName": "Gemini 2.0 Flash",
                        "supportedGenerationMethods": ["generateContent"]
                    },
                    {
                        "name": "models/text-embedding-004",
                        "displayName": "Text Embedding",
                        "supportedGenerationMethods": ["embedContent"]
                    }
                ]
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiModelsResponseForTest.self, from: data)

        // Filter to those supporting generateContent
        let filtered = response.models.filter {
            $0.supportedGenerationMethods?.contains("generateContent") ?? false
        }

        #expect(filtered.count == 2)

        // Verify models/ prefix stripping
        let firstModelId = filtered[0].name.hasPrefix("models/")
            ? String(filtered[0].name.dropFirst("models/".count))
            : filtered[0].name
        #expect(firstModelId == "gemini-2.5-pro")

        // Verify embedding model is filtered out
        #expect(!filtered.contains(where: { $0.name.contains("embedding") }))
    }

    @Test("Parse generateContent response correctly")
    func parseGenerateContentResponse() throws {
        let mockJSON = """
            {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {"text": "Here is the translated text."}
                            ],
                            "role": "model"
                        }
                    }
                ]
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiGenerateResponseForTest.self, from: data)

        let text = response.candidates?.first?.content.parts.first?.text
        #expect(text == "Here is the translated text.")
    }

    @Test("Parse error response correctly")
    func parseErrorResponse() throws {
        let mockJSON = """
            {
                "error": {
                    "code": 400,
                    "message": "API key not valid. Please pass a valid API key.",
                    "status": "INVALID_ARGUMENT"
                }
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiErrorResponseForTest.self, from: data)

        #expect(response.error.message.contains("API key not valid"))
    }
}

// MARK: - Test-only Decodable types

private struct GeminiModelsResponseForTest: Decodable {
    let models: [GeminiModelEntryForTest]
}

private struct GeminiModelEntryForTest: Decodable {
    let name: String
    let displayName: String?
    let supportedGenerationMethods: [String]?
}

private struct GeminiGenerateResponseForTest: Decodable {
    let candidates: [GeminiCandidateForTest]?
}

private struct GeminiCandidateForTest: Decodable {
    let content: GeminiContentForTest
}

private struct GeminiContentForTest: Decodable {
    let parts: [GeminiPartForTest]
}

private struct GeminiPartForTest: Decodable {
    let text: String?
}

private struct GeminiErrorResponseForTest: Decodable {
    let error: GeminiErrorDetailForTest
}

private struct GeminiErrorDetailForTest: Decodable {
    let message: String
}
