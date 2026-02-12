// Prompt.swift
// Represents a user-defined AI prompt template.

import Foundation

struct Prompt: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// Display text shown in the prompt list, e.g. "Translate text to English"
    var title: String
    /// Full prompt template with {text} placeholder for user content
    var template: String
    /// SF Symbol name for the prompt icon
    var icon: String

    init(id: UUID = UUID(), title: String, template: String, icon: String = "text.bubble") {
        self.id = id
        self.title = title
        self.template = template
        self.icon = icon
    }

    /// Resolves the template by replacing {text} with actual content
    func resolved(with text: String) -> String {
        template.replacingOccurrences(of: "{text}", with: text)
    }
}
