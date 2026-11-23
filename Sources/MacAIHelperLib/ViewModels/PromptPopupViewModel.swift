// PromptPopupViewModel.swift
// Manages prompt execution with each prompt's own AI model.

import Foundation

@Observable
@MainActor
final class PromptPopupViewModel {
    /// Reference to the shared app state
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    /// Availability of the given prompt's model, used for badge rendering
    func availability(of prompt: Prompt) -> ModelAvailability {
        appState.availability(of: prompt.model)
    }

    // MARK: - Model Loading

    /// Reloads models if the list is empty (models are pre-loaded at app startup).
    func loadModelsIfNeeded() async {
        guard appState.availableModels.isEmpty, !appState.isLoadingModels else { return }
        await appState.loadModels()
    }

    // MARK: - Prompt Execution

    /// Executes a prompt with the captured text content.
    func selectPrompt(_ prompt: Prompt) async {
        guard let text = appState.capturedText else { return }
        await run(prompt) { model, apiKey in
            // Translation services translate the captured text itself, not an instruction about it.
            let content = model.provider.isTranslationService ? text : prompt.resolved(with: text)
            return try await AIServiceRouter.sendPrompt(
                content, model: model.id, provider: model.provider, apiKey: apiKey,
                webSearch: prompt.webSearchEnabled
            )
        }
    }

    /// Executes a prompt with captured image data.
    func selectPromptWithImage(_ prompt: Prompt, imageData: Data) async {
        let resolvedPrompt = prompt.resolved(with: "Analyze this image.")
        await run(prompt) { model, apiKey in
            try await AIServiceRouter.sendPromptWithImage(
                resolvedPrompt, imageData: imageData, model: model.id, provider: model.provider,
                apiKey: apiKey, webSearch: prompt.webSearchEnabled
            )
        }
    }

    // MARK: - Private

    /// Validates the prompt's model, then performs the request and publishes the result or error.
    private func run(
        _ prompt: Prompt,
        request: (AIModel, String) async throws -> String
    ) async {
        appState.lastError = nil
        appState.isLoading = true
        defer { appState.isLoading = false }

        do {
            let model = try usableModel(for: prompt)
            let apiKey = try KeychainService.apiKey(
                for: model.provider, entries: appState.settings.apiKeyEntries
            )
            appState.aiResponse = try await request(model, apiKey)
            appState.isResponsePlainText = model.provider.isTranslationService
            appState.showingResult = true
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    /// Returns the prompt's model, or throws if it is missing or known to be outdated.
    /// Models whose provider list failed to load are still sent, letting the API decide.
    private func usableModel(for prompt: Prompt) throws -> AIModel {
        guard let model = prompt.model else { throw AppError.noModelSelected }
        if appState.availability(of: model) == .outdated {
            throw AppError.modelUnavailable(model.name)
        }
        return model
    }
}
