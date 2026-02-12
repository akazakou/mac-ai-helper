// MacAIHelperApp.swift
// Main entry point for the Mac AI Helper menu bar application.
// Configures the app as a menu-bar-only utility using MenuBarExtra.

import SwiftUI

@main
struct MacAIHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar icon and dropdown content
        MenuBarExtra("Mac AI Helper", systemImage: "brain.head.profile") {
            MenuBarView()
                .environment(appDelegate.appState)
        }
    }
}
