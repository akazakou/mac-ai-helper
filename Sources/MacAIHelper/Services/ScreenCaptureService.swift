// ScreenCaptureService.swift
// Screen region capture using ScreenCaptureKit.

import AppKit
import Foundation
import ScreenCaptureKit

struct ScreenCaptureService: Sendable {
    /// Captures a screen region selected by the user.
    /// Uses the macOS built-in screencapture utility for interactive region selection,
    /// which provides the native crosshair selection experience.
    /// Returns PNG image data.
    @MainActor
    static func captureRegion() async throws -> Data {
        // Check permission first
        guard checkPermission() else {
            throw AppError.screenCapturePermissionDenied
        }

        // Create a temporary file for the screenshot
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        // Use macOS screencapture command for interactive region selection
        // -i: interactive mode (region selection)
        // -s: selection mode
        // -t png: output as PNG
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", "-t", "png", tempURL.path]

        try process.run()
        process.waitUntilExit()

        // Check if the user cancelled (file won't exist)
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw AppError.screenCapturePermissionDenied
        }

        let data = try Data(contentsOf: tempURL)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        guard !data.isEmpty else {
            throw AppError.screenCapturePermissionDenied
        }

        return data
    }

    /// Checks if the screen recording permission has been granted.
    @MainActor
    static func checkPermission() -> Bool {
        // Attempt to check via CGWindowListCreateImage — if nil, permission likely denied
        // This is a lightweight check that doesn't actually capture anything visible
        CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) != nil
    }
}
