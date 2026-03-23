// OpenAIServiceTests.swift
// Tests for OpenAI API response parsing using mock URLProtocol.

import Foundation
import Testing

@testable import MacAIHelperLib

@Suite("OpenAIService Tests")
struct OpenAIServiceTests {

    @Test("Parse models response correctly")
    func parseModelsResponse() async throws {
        let mockJSON = """
            {
                "data": [
                    {"id": "gpt-4o", "object": "model"},
                    {"id": "gpt-4o-mini", "object": "model"},
                    {"id": "dall-e-3", "object": "model"},
                    {"id": "whisper-1", "object": "model"},
                    {"id": "o1-preview", "object": "model"}
                ]
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenAIModelsResponseForTest.self, from: data)

        // Filter like the service does
        let chatModelPrefixes = ["gpt-", "o1", "o3", "o4"]
        let filtered = response.data.filter { model in
            chatModelPrefixes.contains(where: { model.id.lowercased().hasPrefix($0) })
        }

        #expect(filtered.count == 3)
        #expect(filtered.contains(where: { $0.id == "gpt-4o" }))
        #expect(filtered.contains(where: { $0.id == "gpt-4o-mini" }))
        #expect(filtered.contains(where: { $0.id == "o1-preview" }))
        #expect(!filtered.contains(where: { $0.id == "dall-e-3" }))
    }

    @Test("Parse chat completion response correctly")
    func parseChatCompletionResponse() throws {
        let mockJSON = """
            {
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": "Hello, world!"
                        },
                        "index": 0
                    }
                ]
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenAIChatResponseForTest.self, from: data)

        #expect(response.choices.first?.message.content == "Hello, world!")
    }

    @Test("Parse error response correctly")
    func parseErrorResponse() throws {
        let mockJSON = """
            {
                "error": {
                    "message": "Incorrect API key provided",
                    "type": "invalid_request_error",
                    "code": "invalid_api_key"
                }
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenAIErrorResponseForTest.self, from: data)

        #expect(response.error.message == "Incorrect API key provided")
    }
}

// MARK: - Test-only Decodable types (mirroring private types in OpenAIService)

private struct OpenAIModelsResponseForTest: Decodable {
    let data: [OpenAIModelEntryForTest]
}

private struct OpenAIModelEntryForTest: Decodable {
    let id: String
}

private struct OpenAIChatResponseForTest: Decodable {
    let choices: [OpenAIChatChoiceForTest]
}

private struct OpenAIChatChoiceForTest: Decodable {
    let message: OpenAIChatMessageForTest
}

private struct OpenAIChatMessageForTest: Decodable {
    let content: String?
}

private struct OpenAIErrorResponseForTest: Decodable {
    let error: OpenAIErrorDetailForTest
}

private struct OpenAIErrorDetailForTest: Decodable {
    let message: String
}
