// SettingsService.swift
// JSON file persistence for AppSettings in the Application Support directory.

import Foundation

struct SettingsService: Sendable {
    /// File name for the settings JSON file
    private static let fileName = "settings.json"

    /// Returns the URL for the settings file in ~/Library/Application Support/MacAIHelper.
    func settingsFileURL() -> URL {
        let appDirectory = URL.applicationSupportDirectory
            .appendingPathComponent("MacAIHelper", isDirectory: true)

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
