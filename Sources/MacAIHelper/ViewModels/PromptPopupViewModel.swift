// PromptPopupViewModel.swift
// Manages prompt selection, model picker state, and AI request execution.

import Foundation

@Observable
@MainActor
final class PromptPopupViewModel {
    /// Reference to the shared app state
    private let appState: AppState

    /// Whether models are currently being loaded
    var isLoadingModels = false

    /// Error message from model loading
    var modelLoadError: String?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Currently available prompts from settings
    var prompts: [Prompt] {
        appState.settings.prompts
    }

    /// All available models across providers
    var availableModels: [AIModel] {
        appState.availableModels
    }

    /// Currently selected model ID
    var selectedModelId: String? {
        get { appState.settings.selectedModelId }
        set {
            appState.settings.selectedModelId = newValue
            // Update provider based on selected model
            if let modelId = newValue,
                let model = appState.availableModels.first(where: { $0.id == modelId })
            {
                appState.settings.selectedProvider = model.provider
            }
            appState.saveSettings()
        }
    }

    // MARK: - Model Loading

    /// Fetches models from all providers that have API keys configured.
    func loadModels() async {
        isLoadingModels = true
        modelLoadError = nil

        var allModels: [AIModel] = []

        // Gather unique providers that have API keys
        let configuredProviders = Set(appState.settings.apiKeyEntries.map(\.provider))

        for provider in configuredProviders {
            do {
                let apiKey = try KeychainService.apiKey(
                    for: provider, entries: appState.settings.apiKeyEntries
                )
                let models = try await AIServiceRouter.fetchModels(
                    provider: provider, apiKey: apiKey
                )
                allModels.append(contentsOf: models)
            } catch {
                print("⚠️ Failed to fetch models for \(provider.rawValue): \(error.localizedDescription)")
            }
        }

        appState.availableModels = allModels.sorted { $0.name < $1.name }
        isLoadingModels = false

        // If no model is selected yet, select the first available one
        if selectedModelId == nil, let firstModel = appState.availableModels.first {
            selectedModelId = firstModel.id
        }
    }

    // MARK: - Prompt Execution

    /// Executes a prompt with the captured text content.
    func selectPrompt(_ prompt: Prompt) async {
        guard let text = appState.capturedText else { return }
        let resolvedPrompt = prompt.resolved(with: text)
        await executeAIRequest(prompt: resolvedPrompt)
    }

    /// Executes a prompt with captured image data.
    func selectPromptWithImage(_ prompt: Prompt, imageData: Data) async {
        let resolvedPrompt = prompt.template.replacingOccurrences(
            of: "{text}", with: "Analyze this image."
        )
        await executeAIRequestWithImage(prompt: resolvedPrompt, imageData: imageData)
    }

    // MARK: - Private

    private func executeAIRequest(prompt: String) async {
        guard let modelId = appState.settings.selectedModelId,
            let provider = appState.settings.selectedProvider
        else {
            appState.lastError = AppError.noModelSelected.localizedDescription
            return
        }

        appState.isLoading = true
        appState.lastError = nil

        do {
            let apiKey = try KeychainService.apiKey(
                for: provider, entries: appState.settings.apiKeyEntries
            )
            let response = try await AIServiceRouter.sendPrompt(
                prompt, model: modelId, provider: provider, apiKey: apiKey
            )
            appState.aiResponse = response
            appState.showingResult = true
        } catch {
            appState.lastError = error.localizedDescription
        }

        appState.isLoading = false
    }

    private func executeAIRequestWithImage(prompt: String, imageData: Data) async {
        guard let modelId = appState.settings.selectedModelId,
            let provider = appState.settings.selectedProvider
        else {
            appState.lastError = AppError.noModelSelected.localizedDescription
            return
        }

        appState.isLoading = true
        appState.lastError = nil

        do {
            let apiKey = try KeychainService.apiKey(
                for: provider, entries: appState.settings.apiKeyEntries
            )
            let response = try await AIServiceRouter.sendPromptWithImage(
                prompt, imageData: imageData, model: modelId, provider: provider, apiKey: apiKey
            )
            appState.aiResponse = response
            appState.showingResult = true
        } catch {
            appState.lastError = error.localizedDescription
        }

        appState.isLoading = false
    }
}
