// MacAIHelperApp.swift
// Main entry point for the Mac AI Helper menu bar application.
// Configures the app as a menu-bar-only utility using MenuBarExtra.

import AppKit
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
            if let icon = Self.loadMenuBarIcon() {
                Image(nsImage: icon)
            } else {
                // Fallback to system image if custom icon fails to load
                Image(systemName: "brain.head.profile")
            }
        }
    }

    /// Loads the monochrome template icon from the main app bundle for menu bar display.
    /// The image is marked as a template so macOS auto-tints it for dark/light mode.
    /// Resources are placed into the app bundle by the Makefile during build.
    private static func loadMenuBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "menubar-icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        // Menu bar icons should be ~18pt (36px @2x)
        let menuBarSize = NSSize(width: 18, height: 18)
        image.size = menuBarSize

        // Mark as template so the system handles dark/light appearance
        image.isTemplate = true

        return image
    }
}
