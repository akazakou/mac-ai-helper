// SettingsViewModel.swift
// Manages all settings CRUD operations for prompts and API keys.
// Keyboard shortcuts are managed by the KeyboardShortcuts framework directly.

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

    /// All available models across providers
    var availableModels: [AIModel] {
        appState.availableModels
    }

    /// Model preselected for a new prompt
    var defaultModel: AIModel? {
        appState.defaultModel
    }

    /// Whether provider model lists are currently being fetched
    var isLoadingModels: Bool {
        appState.isLoadingModels
    }

    /// Resolves whether a model can currently be used by a prompt.
    func availability(of model: AIModel?) -> ModelAvailability {
        appState.availability(of: model)
    }

    /// Adds a new prompt to the list.
    func addPrompt(_ prompt: Prompt) {
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

    /// Adds a new API key for a provider, saving it to the key store.
    /// A Google Translate key with a project ID is checked against the Translation LLM first.
    func addAPIKey(_ entry: APIKeyEntry, key: String) async throws {
        if entry.provider == .googleTranslate {
            try await GoogleTranslateService(projectId: entry.projectId).verifyTranslationLLM(apiKey: key)
        }
        try APIKeyStore().saveKey(key, for: entry.id)
        appState.settings.apiKeyEntries.append(entry)
        appState.saveSettings()

        // Refresh available models to include the new provider
        Task { await appState.loadModels() }
    }

    /// Deletes an API key entry and removes it from the key store.
    /// Always removes the settings entry even if key store cleanup fails.
    func deleteAPIKey(_ entry: APIKeyEntry) {
        // Best-effort key store cleanup — don't block settings removal
        try? APIKeyStore().deleteKey(for: entry.id)
        appState.settings.apiKeyEntries.removeAll { $0.id == entry.id }
        appState.saveSettings()

        // Refresh available models to remove the deleted provider's models
        Task { await appState.loadModels() }
    }

    // MARK: - Model Management

    /// Fetches available models for a specific provider to validate API key.
    func fetchModelsForProvider(_ provider: AIProvider) async throws -> [AIModel] {
        let apiKey = try APIKeyStore().apiKey(
            for: provider, entries: appState.settings.apiKeyEntries
        )
        return try await AIServiceRouter.fetchModels(provider: provider, apiKey: apiKey)
    }

    // MARK: - Launch at Login

    /// Toggles the launch-at-login state, registering/unregistering with the system.
    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            appState.settings.launchAtLogin = enabled
            appState.saveSettings()
        } catch {
            operationError = "Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
        }
    }
}
