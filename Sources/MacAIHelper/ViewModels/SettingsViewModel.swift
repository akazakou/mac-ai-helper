// SettingsViewModel.swift
// Manages all settings CRUD operations for prompts, API keys, and shortcuts.

import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    /// Reference to the shared app state
    private let appState: AppState

    /// Tracks whether a model fetch is in progress
    var isFetchingModels = false

    /// Error from the last operation
    var operationError: String?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Current app settings
    var settings: AppSettings {
        get { appState.settings }
        set {
            appState.settings = newValue
            appState.saveSettings()
        }
    }

    // MARK: - Prompt Management

    /// Adds a new prompt to the list.
    func addPrompt(title: String, template: String, icon: String = "text.bubble") {
        let prompt = Prompt(title: title, template: template, icon: icon)
        appState.settings.prompts.append(prompt)
        appState.saveSettings()
    }

    /// Updates an existing prompt in the list.
    func updatePrompt(_ prompt: Prompt) {
        if let index = appState.settings.prompts.firstIndex(where: { $0.id == prompt.id }) {
            appState.settings.prompts[index] = prompt
            appState.saveSettings()
        }
    }

    /// Deletes prompts at the specified offsets.
    func deletePrompt(at offsets: IndexSet) {
        appState.settings.prompts.remove(atOffsets: offsets)
        appState.saveSettings()
    }

    /// Reorders prompts by moving items from source to destination.
    func movePrompt(from source: IndexSet, to destination: Int) {
        appState.settings.prompts.move(fromOffsets: source, toOffset: destination)
        appState.saveSettings()
    }

    // MARK: - API Key Management

    /// Adds a new API key for a provider, storing it securely in the Keychain.
    func addAPIKey(provider: AIProvider, key: String, label: String = "") throws {
        let entry = APIKeyEntry(provider: provider, label: label)
        try KeychainService.saveKey(key, for: entry.id)
        appState.settings.apiKeyEntries.append(entry)
        appState.saveSettings()

        // Refresh available models to include the new provider
        Task { await appState.loadModels() }
    }

    /// Deletes an API key entry and removes it from the Keychain.
    /// Always removes the settings entry even if keychain cleanup fails.
    func deleteAPIKey(_ entry: APIKeyEntry) {
        // Best-effort keychain cleanup — don't block settings removal
        try? KeychainService.deleteKey(for: entry.id)
        appState.settings.apiKeyEntries.removeAll { $0.id == entry.id }
        appState.saveSettings()

        // Refresh available models to remove the deleted provider's models
        Task { await appState.loadModels() }
    }

    // MARK: - Model Management

    /// Fetches available models for a specific provider to validate API key.
    func fetchModelsForProvider(_ provider: AIProvider) async throws -> [AIModel] {
        let apiKey = try KeychainService.apiKey(
            for: provider, entries: appState.settings.apiKeyEntries
        )
        return try await AIServiceRouter.fetchModels(provider: provider, apiKey: apiKey)
    }

    // MARK: - Shortcut Management

    /// Updates a keyboard shortcut definition.
    func updatePromptShortcut(_ definition: ShortcutDefinition) {
        appState.settings.promptShortcut = definition
        appState.saveSettings()
    }

    /// Updates the screenshot shortcut definition.
    func updateScreenshotShortcut(_ definition: ShortcutDefinition) {
        appState.settings.screenshotShortcut = definition
        appState.saveSettings()
    }
}
