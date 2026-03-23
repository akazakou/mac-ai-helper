// HotkeyService.swift
// Global keyboard shortcut registration using the KeyboardShortcuts framework.
// Sandbox-compatible — uses Carbon RegisterEventHotKey under the hood,
// which works inside App Sandbox without Accessibility permission.

import KeyboardShortcuts

@MainActor
final class HotkeyService {
    /// Callback fired when the text shortcut is detected
    var onTextShortcut: (@MainActor () -> Void)?

    /// Callback fired when the screenshot shortcut is detected
    var onScreenshotShortcut: (@MainActor () -> Void)?

    // MARK: - Monitoring

    /// Registers global keyboard shortcut handlers.
    func startMonitoring() {
        KeyboardShortcuts.onKeyUp(for: .textPrompt) { [weak self] in
            Task { @MainActor in
                self?.onTextShortcut?()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .screenshotCapture) { [weak self] in
            Task { @MainActor in
                self?.onScreenshotShortcut?()
            }
        }
    }

    /// Disables all registered shortcut handlers.
    func stopMonitoring() {
        KeyboardShortcuts.disable(.textPrompt)
        KeyboardShortcuts.disable(.screenshotCapture)
    }

    /// Pauses global hotkey monitoring (e.g., while recording a new shortcut).
    func pause() {
        KeyboardShortcuts.disable(.textPrompt)
        KeyboardShortcuts.disable(.screenshotCapture)
    }

    /// Resumes global hotkey monitoring by re-registering handlers.
    func resume() {
        startMonitoring()
    }
}
