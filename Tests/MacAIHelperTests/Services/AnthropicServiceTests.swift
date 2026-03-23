// AnthropicServiceTests.swift
// Tests for Anthropic API response parsing.

import Foundation
import Testing

@testable import MacAIHelperLib

@Suite("AnthropicService Tests")
struct AnthropicServiceTests {

    @Test("Parse models response correctly")
    func parseModelsResponse() throws {
        let mockJSON = """
            {
                "data": [
                    {"id": "claude-sonnet-4-5-20250514", "display_name": "Claude Sonnet 4.5"},
                    {"id": "claude-3-5-haiku-20241022", "display_name": "Claude 3.5 Haiku"}
                ]
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicModelsResponseForTest.self, from: data)

        #expect(response.data.count == 2)
        #expect(response.data[0].id == "claude-sonnet-4-5-20250514")
        #expect(response.data[0].displayName == "Claude Sonnet 4.5")
    }

    @Test("Parse message response correctly")
    func parseMessageResponse() throws {
        let mockJSON = """
            {
                "content": [
                    {"type": "text", "text": "This is the AI response."}
                ],
                "model": "claude-sonnet-4-5-20250514",
                "role": "assistant"
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicMessageResponseForTest.self, from: data)

        let textBlock = response.content.first(where: { $0.type == "text" })
        #expect(textBlock?.text == "This is the AI response.")
    }

    @Test("Parse error response correctly")
    func parseErrorResponse() throws {
        let mockJSON = """
            {
                "error": {
                    "type": "authentication_error",
                    "message": "Invalid API key"
                }
            }
            """

        let data = mockJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicErrorResponseForTest.self, from: data)

        #expect(response.error.message == "Invalid API key")
    }
}

// MARK: - Test-only Decodable types

private struct AnthropicModelsResponseForTest: Decodable {
    let data: [AnthropicModelEntryForTest]
}

private struct AnthropicModelEntryForTest: Decodable {
    let id: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

private struct AnthropicMessageResponseForTest: Decodable {
    let content: [AnthropicContentBlockForTest]
}

private struct AnthropicContentBlockForTest: Decodable {
    let type: String
    let text: String?
}

private struct AnthropicErrorResponseForTest: Decodable {
    let error: AnthropicErrorDetailForTest
}

private struct AnthropicErrorDetailForTest: Decodable {
    let message: String
}
