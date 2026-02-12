// SettingsView.swift
// Main settings window with tabs for Prompts, API Keys, and Shortcuts.

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            PromptsSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }

            APIKeysSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }

            ShortcutSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 550, height: 450)
    }
}
