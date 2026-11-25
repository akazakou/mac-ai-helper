// PromptPopupViewModel.swift
// Manages prompt execution with each prompt's own AI model.

import Foundation

@Observable
@MainActor
final class PromptPopupViewModel {
    /// Reference to the shared app state
    private let appState: AppState

    /// State of the popup window this view model serves
    private let session: PopupSession

    /// The running prompt request, kept so that closing the popup can stop it
    private var requestTask: Task<Void, Never>?

    init(appState: AppState, session: PopupSession) {
        self.appState = appState
        self.session = session
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

    /// Starts the prompt on the content captured for this popup.
    func start(_ prompt: Prompt) {
        requestTask = Task {
            if let imageData = session.capturedImage {
                await selectPromptWithImage(prompt, imageData: imageData)
            } else {
                await selectPrompt(prompt)
            }
        }
    }

    /// Stops the running request, if any. The API call is cancelled together with its task.
    func cancelRequest() {
        requestTask?.cancel()
    }

    // MARK: - Private

    /// Executes a prompt with the captured text content.
    private func selectPrompt(_ prompt: Prompt) async {
        guard let text = session.capturedText else { return }
        await run(prompt) { model, apiKey in
            // Translation services translate the captured text itself, not an instruction about it.
            if let translator = translationService(for: model) {
                return .plainText(
                    try await translator.sendPrompt(text, model: model.id, apiKey: apiKey, webSearch: false)
                )
            }
            return .markdown(
                try await AIServiceRouter.sendPrompt(
                    prompt.resolved(with: text), model: model.id, provider: model.provider,
                    apiKey: apiKey, webSearch: prompt.webSearchEnabled
                )
            )
        }
    }

    /// Executes a prompt with captured image data.
    private func selectPromptWithImage(_ prompt: Prompt, imageData: Data) async {
        let resolvedPrompt = prompt.resolved(with: "Analyze this image.")
        await run(prompt) { model, apiKey in
            if let translator = translationService(for: model) {
                let imageTranslation = ImageTranslationService(translator: translator, apiKey: apiKey)
                return .image(try await imageTranslation.translate(imageData, into: model.id))
            }
            return .markdown(
                try await AIServiceRouter.sendPromptWithImage(
                    resolvedPrompt, imageData: imageData, model: model.id, provider: model.provider,
                    apiKey: apiKey, webSearch: prompt.webSearchEnabled
                )
            )
        }
    }

    /// Validates the prompt's model, then performs the request and publishes the result or error.
    private func run(
        _ prompt: Prompt,
        request: (AIModel, String) async throws -> PromptResponse
    ) async {
        session.lastError = nil
        session.isLoading = true
        defer { session.isLoading = false }

        do {
            let model = try usableModel(for: prompt)
            let apiKey = try APIKeyStore().apiKey(
                for: model.provider, entries: appState.settings.apiKeyEntries
            )
            session.response = try await request(model, apiKey)
            session.showingResult = true
        } catch {
            session.lastError = error.localizedDescription
        }
    }

    /// The translation service of the model's provider, or nil for an AI model.
    private func translationService(for model: AIModel) -> TranslationServiceProtocol? {
        AIServiceRouter.translationService(
            for: model.provider, entries: appState.settings.apiKeyEntries
        )
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
