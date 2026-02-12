// SettingsViewModelTests.swift
// Tests for SettingsViewModel business logic.

import Foundation
import Testing

@testable import MacAIHelper

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {

    @Test("Default settings have three prompts")
    func defaultSettingsHavePrompts() {
        let settings = AppSettings.defaultSettings
        #expect(settings.prompts.count == 3)
        #expect(settings.prompts[0].title.contains("Translate"))
        #expect(settings.prompts[1].title.contains("Rewrite"))
        #expect(settings.prompts[2].title.contains("IT expert"))
    }

    @Test("Default settings have no API keys")
    func defaultSettingsNoApiKeys() {
        let settings = AppSettings.defaultSettings
        #expect(settings.apiKeyEntries.isEmpty)
        #expect(settings.selectedModelId == nil)
        #expect(settings.selectedProvider == nil)
    }

    @Test("Default shortcuts are configured correctly")
    func defaultShortcuts() {
        let settings = AppSettings.defaultSettings

        // Text prompt shortcut: CMD+C+C (double tap)
        #expect(settings.promptShortcut.keyCode == 8)  // C key
        #expect(settings.promptShortcut.doubleTap == true)
        #expect(settings.promptShortcut.displayName == "⌘C + C")

        // Screenshot shortcut: CMD+Shift+C
        #expect(settings.screenshotShortcut.keyCode == 8)  // C key
        #expect(settings.screenshotShortcut.doubleTap == false)
        #expect(settings.screenshotShortcut.displayName == "⇧⌘C")
    }

    @Test("Prompt template resolves correctly")
    func promptTemplateResolution() {
        let prompt = Prompt(
            title: "Translate",
            template: "Translate the following text to English:\n\n{text}",
            icon: "globe"
        )

        let resolved = prompt.resolved(with: "Bonjour le monde")
        #expect(resolved == "Translate the following text to English:\n\nBonjour le monde")
    }

    @Test("Prompt template with no placeholder passes through")
    func promptTemplateNoPlaceholder() {
        let prompt = Prompt(
            title: "No placeholder",
            template: "Just do something",
            icon: "star"
        )

        let resolved = prompt.resolved(with: "some text")
        #expect(resolved == "Just do something")
    }

    @Test("Settings JSON round-trip")
    func settingsRoundTrip() throws {
        let service = SettingsService()
        let original = AppSettings.defaultSettings

        try service.saveSettings(original)
        let loaded = service.loadSettings()

        #expect(loaded.prompts.count == original.prompts.count)
        #expect(loaded.promptShortcut.keyCode == original.promptShortcut.keyCode)
        #expect(loaded.screenshotShortcut.displayName == original.screenshotShortcut.displayName)
    }

    @Test("AIProvider has correct base URLs")
    func providerBaseURLs() {
        #expect(AIProvider.openAI.baseURL.host == "api.openai.com")
        #expect(AIProvider.anthropic.baseURL.host == "api.anthropic.com")
        #expect(AIProvider.gemini.baseURL.host == "generativelanguage.googleapis.com")
    }

    @Test("AIProvider allCases contains all three providers")
    func providerAllCases() {
        #expect(AIProvider.allCases.count == 3)
        #expect(AIProvider.allCases.contains(.openAI))
        #expect(AIProvider.allCases.contains(.anthropic))
        #expect(AIProvider.allCases.contains(.gemini))
    }

    @Test("APIKeyEntry defaults label to provider name")
    func apiKeyEntryDefaultLabel() {
        let entry = APIKeyEntry(provider: .openAI)
        #expect(entry.label == "OpenAI")

        let customEntry = APIKeyEntry(provider: .anthropic, label: "My Key")
        #expect(customEntry.label == "My Key")
    }

    @Test("AppError descriptions are human-readable")
    func appErrorDescriptions() {
        let errors: [AppError] = [
            .noAPIKey(.openAI),
            .noModelSelected,
            .networkError("timeout"),
            .apiError(statusCode: 401, message: "unauthorized"),
            .decodingError("bad json"),
            .keychainError("access denied"),
            .accessibilityPermissionDenied,
            .screenCapturePermissionDenied,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}
