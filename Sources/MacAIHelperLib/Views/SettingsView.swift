// SettingsView.swift
// Main settings window with tabs for Prompts, API Keys, and Shortcuts.

import os
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let _ = Log.ui.debug("SettingsView body evaluation started, current tab: \(String(describing: appState.selectedSettingsTab))")
        @Bindable var appState = appState

        TabView(selection: $appState.selectedSettingsTab) {
            let _ = Log.ui.debug("SettingsView: constructing PromptsSettingsView tab")
            PromptsSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
                .tag(SettingsTab.prompts)

            let _ = Log.ui.debug("SettingsView: constructing APIKeysSettingsView tab")
            APIKeysSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }
                .tag(SettingsTab.apiKeys)

            let _ = Log.ui.debug("SettingsView: constructing ShortcutSettingsView tab")
            ShortcutSettingsView(viewModel: SettingsViewModel(appState: appState))
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(SettingsTab.shortcuts)

            let _ = Log.ui.debug("SettingsView: all tabs constructed")
        }
        .frame(width: 550, height: 450)
        .onChange(of: appState.selectedSettingsTab) { oldTab, newTab in
            Log.ui.info("Settings tab changed from \(String(describing: oldTab)) to \(String(describing: newTab))")
        }
        // Dismiss settings window on ESC key press
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
    }
}
