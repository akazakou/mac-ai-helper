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
    /// Legacy global model identifier, kept only to migrate it into prompts (see migrateLegacyModelSelection)
    public var selectedModelId: String?
    /// Legacy global AI provider, kept only to migrate it into prompts (see migrateLegacyModelSelection)
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

    /// Moves the legacy global model selection into every prompt that has no model yet.
    /// The real model name is refreshed once provider model lists are fetched.
    public mutating func migrateLegacyModelSelection() {
        defer {
            selectedModelId = nil
            selectedProvider = nil
        }
        guard let modelId = selectedModelId, let provider = selectedProvider else { return }

        let legacyModel = AIModel(id: modelId, name: modelId, provider: provider)
        for index in prompts.indices where prompts[index].model == nil {
            prompts[index].model = legacyModel
        }
    }
}
