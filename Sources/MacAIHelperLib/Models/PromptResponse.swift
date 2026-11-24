// PromptResponse.swift
// Result of running a prompt, in the form the result view presents it.

import Foundation

public enum PromptResponse: Sendable, Equatable {
    /// AI answer, rendered as Markdown
    case markdown(String)
    /// Translated text, shown verbatim
    case plainText(String)
    /// Translated screenshot as PNG data
    case image(Data)

    /// Text of the response, or nil for an image
    public var text: String? {
        switch self {
        case .markdown(let text), .plainText(let text): text
        case .image: nil
        }
    }
}
