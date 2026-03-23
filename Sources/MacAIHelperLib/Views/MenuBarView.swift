// MenuBarView.swift
// Content displayed in the menu bar dropdown when the user clicks the menu bar icon.
// Uses only NSMenu-compatible items (Button, Divider, Text) since MenuBarExtra
// defaults to .menu style which renders as a native NSMenu.

import KeyboardShortcuts
import SwiftUI

public struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        // Status indicator (rendered as a disabled menu item)
        if appState.settings.apiKeyEntries.isEmpty {
            Text("⚠ No API keys configured")
            Divider()
        }

        // Tip Developer
        Button("Tip Developer ❤️") {
            AppDelegate.shared?.openTipJar()
        }

        Divider()

        // Open Settings
        Button("Settings…") {
            // Use static shared reference since NSApp.delegate is SwiftUI's wrapper
            AppDelegate.shared?.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // Shortcut hints (rendered as disabled/info menu items)
        Text("Shortcuts:")
        Text("  \(shortcutDisplayName(.textPrompt)) — Text prompt")
        Text("  \(shortcutDisplayName(.screenshotCapture)) — Screenshot")

        Divider()

        // Quit
        Button("Quit Mac AI Helper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    /// Returns a human-readable display name for a KeyboardShortcuts.Name,
    /// or a fallback if the shortcut is not configured.
    private func shortcutDisplayName(_ name: KeyboardShortcuts.Name) -> String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            return "Not set"
        }
        return shortcut.description
    }
}
