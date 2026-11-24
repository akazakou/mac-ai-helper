// ResultViewModel.swift
// Manages AI response display, copy-to-clipboard and saving of translated images.

import Foundation

@Observable
@MainActor
final class ResultViewModel {
    /// State of the popup window showing the result
    private let session: PopupSession

    /// Whether the response was recently copied (for UI feedback)
    var copied = false

    /// Whether the translated image was recently saved (for UI feedback)
    var saved = false

    /// Why the last attempt to save the translated image failed
    var saveErrorMessage: String?

    /// How long the "Copied!" and "Saved!" confirmations stay visible
    private static let confirmationDuration: Duration = .seconds(2)

    init(session: PopupSession) {
        self.session = session
    }

    /// The response to display
    var response: PromptResponse? {
        session.response
    }

    /// Whether there is something to copy
    var canCopy: Bool {
        response != nil && response?.text != ""
    }

    /// Whether the app is waiting for an AI response
    var isLoading: Bool {
        session.isLoading
    }

    /// The most recent error message
    var errorMessage: String? {
        session.lastError
    }

    /// Copies the response (text or translated image) to the system clipboard.
    func copyResponse() {
        guard canCopy, let response else { return }
        switch response {
        case .markdown(let text), .plainText(let text):
            PasteboardService.writeText(text)
        case .image(let pngData):
            PasteboardService.writeImage(pngData)
        }
        copied = true

        // Reset the copied state after a brief delay for UI feedback
        Task {
            try? await Task.sleep(for: Self.confirmationDuration)
            copied = false
        }
    }

    /// Writes the translated image to the file the user picked.
    func saveImage(to url: URL) {
        guard case .image(let pngData) = response else { return }
        do {
            try pngData.write(to: url, options: .atomic)
        } catch {
            saveErrorMessage = "Failed to save the image: \(error.localizedDescription)"
            return
        }
        saveErrorMessage = nil
        saved = true

        Task {
            try? await Task.sleep(for: Self.confirmationDuration)
            saved = false
        }
    }

    /// Dismisses the result view and resets state.
    func dismiss() {
        session.showingResult = false
        session.response = nil
        session.lastError = nil
    }
}
