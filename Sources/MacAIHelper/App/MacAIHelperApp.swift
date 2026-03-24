// MacAIHelperApp.swift
// Main entry point for the Mac AI Helper menu bar application.
// Configures the app as a menu-bar-only utility using MenuBarExtra.

import MacAIHelperLib
import SwiftUI

@main
struct MacAIHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar icon and dropdown content
        MenuBarExtra {
            MenuBarView()
                .environment(appDelegate.appState)
        } label: {
            // Loads "MenuBarIcon" from the asset catalog (template image).
            // The asset is configured as a template so macOS auto-tints for dark/light mode.
            Image("MenuBarIcon")
        }
    }
}
