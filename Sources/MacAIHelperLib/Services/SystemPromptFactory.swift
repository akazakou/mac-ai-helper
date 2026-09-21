// SystemPromptFactory.swift
// Builds system prompts injected into AI API requests.

import Foundation

enum SystemPromptFactory {
    /// System prompt stating the current date and time so models can reason about "today".
    /// Evaluated at call time, so each request carries a fresh timestamp.
    static func currentDateTimeSystemPrompt() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        return "Current date and time: \(formatter.string(from: Date()))"
    }
}
