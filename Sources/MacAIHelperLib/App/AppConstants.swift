// AppConstants.swift
// Centralized application-wide constants.

import Foundation

enum AppConstants {
    /// Public GitHub repository with source code and releases
    static let sourceCodeURL = URL(string: "https://github.com/akazakou/mac-ai-helper")!

    /// Releases page, the manual fallback when the in-app update fails
    static let releasesURL = sourceCodeURL.appending(path: "releases")

    /// GitHub API endpoint describing the latest published release (pre-releases are excluded)
    static let latestReleaseAPIURL = URL(
        string: "https://api.github.com/repos/akazakou/mac-ai-helper/releases/latest"
    )!

    /// Folder with the user's settings and API keys: ~/Library/Application Support/MacAIHelper
    static let dataDirectory = URL.applicationSupportDirectory
        .appendingPathComponent("MacAIHelper", isDirectory: true)

    /// GitHub Sponsors page for voluntary support
    static let sponsorURL = URL(string: "https://github.com/sponsors/akazakou")!

    /// Privacy policy published in the repository
    static let privacyPolicyURL = sourceCodeURL.appending(path: "blob/master/PRIVACY.md")

    /// GPL-3.0 license text published in the repository
    static let licenseURL = sourceCodeURL.appending(path: "blob/master/LICENSE")
}
