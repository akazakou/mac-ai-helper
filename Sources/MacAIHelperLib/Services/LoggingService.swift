// LoggingService.swift
// Centralized logging using Apple's os.Logger framework.
// Provides structured, subsystem-based logging with categories for each domain.
// Logs are viewable in Console.app or via:
//   log stream --predicate 'subsystem == "com.castloud.MacAIHelper"' --level debug

import os

enum Log {
    private static let subsystem = "com.castloud.MacAIHelper"

    /// General app lifecycle events (launch, terminate, activation)
    static let general = Logger(subsystem: subsystem, category: "general")

    /// Settings persistence (load, save, migration)
    static let settings = Logger(subsystem: subsystem, category: "settings")

    /// API key storage (read, write, delete API keys, migration from the Keychain)
    static let keyStore = Logger(subsystem: subsystem, category: "keyStore")

    /// In-app updates (version check, download, install)
    static let update = Logger(subsystem: subsystem, category: "update")

    /// Keyboard shortcut registration and handling
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")

    /// AI service requests (prompt execution, model loading)
    static let ai = Logger(subsystem: subsystem, category: "ai")

    /// Screen capture and permission checks
    static let capture = Logger(subsystem: subsystem, category: "capture")

    /// UI events (view lifecycle, tab switching, window management)
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
