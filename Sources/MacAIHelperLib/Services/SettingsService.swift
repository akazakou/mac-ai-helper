// SettingsService.swift
// JSON file persistence for AppSettings in the Application Support directory.

import Foundation

struct SettingsService: Sendable {
    /// File name for the settings JSON file
    private static let fileName = "settings.json"

    /// Returns the URL for the settings file inside the App Group shared container.
    /// Falls back to Application Support if the group container is unavailable.
    func settingsFileURL() -> URL {
        let appDirectory: URL

        if let groupContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) {
            appDirectory = groupContainer.appendingPathComponent("Library/Application Support", isDirectory: true)
        } else {
            // Fallback to standard Application Support if group container is unavailable
            Log.settings.error("App Group container unavailable, falling back to Application Support.")
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            appDirectory = appSupport.appendingPathComponent("MacAIHelper", isDirectory: true)
        }

        // Ensure the directory exists
        try? FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )

        return appDirectory.appendingPathComponent(Self.fileName)
    }

    /// Loads settings from disk. Returns default settings if file doesn't exist or is corrupt.
    func loadSettings() -> AppSettings {
        let url = settingsFileURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .defaultSettings
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            // If file is corrupt, return defaults rather than crashing
            Log.settings.error("Failed to load settings: \(error.localizedDescription). Using defaults.")
            return .defaultSettings
        }
    }

    /// Saves settings to disk as JSON.
    func saveSettings(_ settings: AppSettings) throws {
        let url = settingsFileURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }
}
