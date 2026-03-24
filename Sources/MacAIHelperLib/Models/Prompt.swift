// Prompt.swift
// Represents a user-defined AI prompt template.

import Foundation

public struct Prompt: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// Display text shown in the prompt list, e.g. "Translate text to English"
    public var title: String
    /// Full prompt template with {text} placeholder for user content
    public var template: String
    /// SF Symbol name for the prompt icon
    public var icon: String

    public init(id: UUID = UUID(), title: String, template: String, icon: String = "text.bubble") {
        self.id = id
        self.title = title
        self.template = template
        self.icon = icon
    }

    /// Resolves the template by replacing {text} with actual content.
    /// If {text} placeholder is not present, appends the text after the prompt separated by a divider.
    public func resolved(with text: String) -> String {
        if template.contains("{text}") {
            return template.replacingOccurrences(of: "{text}", with: text)
        }
        return "\(template)\n---\n\(text)"
    }
}
