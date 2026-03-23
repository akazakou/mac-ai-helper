// SettingsView.swift
// Main settings window with tabs for Prompts, API Keys, and Shortcuts.

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedSettingsTab) {
            PromptsSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
                .tag(SettingsTab.prompts)

            APIKeysSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }
                .tag(SettingsTab.apiKeys)

            ShortcutSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(SettingsTab.shortcuts)
        }
        .frame(width: 550, height: 450)
        // Dismiss settings window on ESC key press
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
    }
}
