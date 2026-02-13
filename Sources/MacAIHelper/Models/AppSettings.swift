// AppSettings.swift
// Application settings container with default configuration.
// Persisted as JSON in the Application Support directory.

import CoreGraphics
import Foundation

struct AppSettings: Codable, Sendable {
    /// User-defined prompt templates
    var prompts: [Prompt]
    /// Metadata for API keys (actual keys stored in Keychain)
    var apiKeyEntries: [APIKeyEntry]
    /// Currently selected AI model identifier
    var selectedModelId: String?
    /// Currently selected AI provider
    var selectedProvider: AIProvider?
    /// Keyboard shortcut for text prompt workflow (default: ⌘C+C)
    var promptShortcut: ShortcutDefinition
    /// Keyboard shortcut for screenshot workflow (default: ⇧⌘C)
    var screenshotShortcut: ShortcutDefinition
    /// Whether the app should launch automatically at system login
    var launchAtLogin: Bool

    /// Default settings with three starter prompts and standard shortcuts
    static var defaultSettings: AppSettings {
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
            promptShortcut: ShortcutDefinition(
                keyCode: 8,  // C key
                modifierFlags: CGEventFlags.maskCommand.rawValue,
                doubleTap: true,
                displayName: "⌘C + C"
            ),
            screenshotShortcut: ShortcutDefinition(
                keyCode: 8,  // C key
                modifierFlags: CGEventFlags.maskCommand.rawValue
                    | CGEventFlags.maskShift.rawValue,
                doubleTap: false,
                displayName: "⇧⌘C"
            ),
            launchAtLogin: false
        )
    }
}
