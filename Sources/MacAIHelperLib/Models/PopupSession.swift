// PopupSession.swift
// State of one popup window: the captured content, the running request and its result.
// Every popup owns its own session, so several popups can work side by side.

import Foundation

@Observable
@MainActor
final class PopupSession {
    let capturedText: String?
    let capturedImage: Data?
    /// Result of the prompt: an AI answer, a translation, or a translated screenshot
    var response: PromptResponse?
    var isLoading = false
    var lastError: String?
    var showingResult = false

    /// Whether the user pinned the popup so it stays open when focus moves elsewhere
    /// and when the next popup is opened
    var isPinned = false

    /// Whether the popup is waiting for or showing a response
    var isResponseVisible: Bool {
        isLoading || showingResult
    }

    init(capturedText: String? = nil, capturedImage: Data? = nil, lastError: String? = nil) {
        self.capturedText = capturedText
        self.capturedImage = capturedImage
        self.lastError = lastError
    }
}
