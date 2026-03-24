// SettingsView.swift
// Main settings window with tabs for Prompts, API Keys, Shortcuts, and About.

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

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 550, height: 565)
        .onChange(of: appState.selectedSettingsTab) { oldTab, newTab in
            Log.ui.info("Settings tab changed from \(String(describing: oldTab)) to \(String(describing: newTab))")
        }
        // Dismiss settings window on ESC key press
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
    }
}
