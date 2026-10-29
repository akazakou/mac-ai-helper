// AppConstants.swift
// Centralized application-wide constants.

import Foundation

enum AppConstants {
    /// Public GitHub repository with source code and releases
    static let sourceCodeURL = URL(string: "https://github.com/akazakou/mac-ai-helper")!

    /// GitHub Sponsors page for voluntary support
    static let sponsorURL = URL(string: "https://github.com/sponsors/akazakou")!

    /// Privacy policy published in the repository
    static let privacyPolicyURL = sourceCodeURL.appending(path: "blob/master/PRIVACY.md")

    /// GPL-3.0 license text published in the repository
    static let licenseURL = sourceCodeURL.appending(path: "blob/master/LICENSE")
}
