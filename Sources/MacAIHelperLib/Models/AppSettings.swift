// AppSettings.swift
// Application settings container with default configuration.
// Persisted as JSON in the Application Support directory.
// Note: Keyboard shortcuts are managed by the KeyboardShortcuts framework
// and stored separately in UserDefaults.

import Foundation

public struct AppSettings: Codable, Sendable {
    /// User-defined prompt templates
    public var prompts: [Prompt]
    /// Metadata for API keys (actual keys stored in Keychain)
    public var apiKeyEntries: [APIKeyEntry]
    /// Currently selected AI model identifier
    public var selectedModelId: String?
    /// Currently selected AI provider
    public var selectedProvider: AIProvider?
    /// Whether the app should launch automatically at system login
    public var launchAtLogin: Bool

    /// Default settings with three starter prompts
    public static var defaultSettings: AppSettings {
        AppSettings(
            prompts: [
                Prompt(
                    title: "Translate text to the English language",
                    template: "Translate the following text to English:\n\n{text}",
                    icon: "globe"
                ),
                Prompt(
                    title: "Rewrite text informal but professional way in the Email style",
                    template:
                        "Rewrite the following text in an informal but professional email style:\n\n{text}",
                    icon: "envelope"
                ),
                Prompt(
                    title: "Act like professional IT expert. I need to solve that issue",
                    template:
                        "You are a professional IT expert. Help me solve this issue:\n\n{text}",
                    icon: "desktopcomputer"
                ),
            ],
            apiKeyEntries: [],
            selectedModelId: nil,
            selectedProvider: nil,
            launchAtLogin: false
        )
    }
}
