// ResultViewModel.swift
// Manages AI response display and copy-to-clipboard functionality.

import Foundation

@Observable
@MainActor
final class ResultViewModel {
    /// Reference to the shared app state
    private let appState: AppState

    /// Whether the response was recently copied (for UI feedback)
    var copied = false

    init(appState: AppState) {
        self.appState = appState
    }

    /// The AI response text to display
    var responseText: String {
        appState.aiResponse ?? ""
    }

    /// Whether the app is waiting for an AI response
    var isLoading: Bool {
        appState.isLoading
    }

    /// The most recent error message
    var errorMessage: String? {
        appState.lastError
    }

    /// Copies the AI response text to the system clipboard.
    func copyResponse() {
        guard !responseText.isEmpty else { return }
        PasteboardService.writeText(responseText)
        copied = true

        // Reset the copied state after a brief delay for UI feedback
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    /// Dismisses the result view and resets state.
    func dismiss() {
        appState.showingResult = false
        appState.aiResponse = nil
        appState.lastError = nil
    }
}
