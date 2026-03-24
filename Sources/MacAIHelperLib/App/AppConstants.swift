// AppConstants.swift
// Centralized application-wide constants.

import Foundation

enum AppConstants {
    /// App Group identifier following Apple's naming convention:
    /// teamid.group.com.yourcompany.yourapp
    static let appGroupIdentifier = "T2MHQ9ZQXG.group.com.castloud.MacAIHelper"

    /// Shared UserDefaults backed by the App Group container.
    /// Falls back to `.standard` if the suite cannot be created (should never happen at runtime).
    /// UserDefaults is thread-safe; the `nonisolated(unsafe)` suppression is safe here.
    nonisolated(unsafe) static let sharedDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            Log.settings.error("Failed to create UserDefaults for App Group \(appGroupIdentifier). Falling back to standard.")
            return .standard
        }
        return defaults
    }()
}
