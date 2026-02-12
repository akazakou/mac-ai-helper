// MenuBarView.swift
// Content displayed in the menu bar dropdown when the user clicks the menu bar icon.
// Uses only NSMenu-compatible items (Button, Divider, Text) since MenuBarExtra
// defaults to .menu style which renders as a native NSMenu.

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        // Status indicator (rendered as a disabled menu item)
        if appState.settings.apiKeyEntries.isEmpty {
            Text("⚠ No API keys configured")
            Divider()
        }

        // Open Settings
        Button("Settings…") {
            // Use static shared reference since NSApp.delegate is SwiftUI's wrapper
            AppDelegate.shared?.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // Shortcut hints (rendered as disabled/info menu items)
        Text("Shortcuts:")
        Text("  \(appState.settings.promptShortcut.displayName) — Text prompt")
        Text("  \(appState.settings.screenshotShortcut.displayName) — Screenshot")

        Divider()

        // Quit
        Button("Quit Mac AI Helper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
