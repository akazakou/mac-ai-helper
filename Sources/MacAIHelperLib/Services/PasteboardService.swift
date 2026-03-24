// PasteboardService.swift
// Wrapper around NSPasteboard for clipboard read/write operations.
// Includes simulated Cmd+C copy for capturing selected text from the frontmost app.

import AppKit
import ApplicationServices
import UniformTypeIdentifiers

struct PasteboardService: Sendable {
    /// Reads the current text content from the system clipboard.
    @MainActor
    static func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Writes text content to the system clipboard.
    @MainActor
    static func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Reads image data (PNG) from the system clipboard.
    @MainActor
    static func readImage() -> Data? {
        let pasteboard = NSPasteboard.general

        // Try reading PNG data first
        if let data = pasteboard.data(forType: .png) {
            return data
        }

        // Try reading TIFF and converting to PNG
        if let data = pasteboard.data(forType: .tiff),
            let image = NSImage(data: data),
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        {
            return pngData
        }

        return nil
    }

    // MARK: - Accessibility Permission

    /// Checks whether the app has Accessibility permission (needed for simulated Cmd+C).
    /// Uses `AXIsProcessTrusted()` which is safe inside App Sandbox.
    static func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        Log.hotkey.info("Accessibility permission: \(trusted ? "granted" : "denied")")
        return trusted
    }

    /// Prompts the system to show the Accessibility permission dialog.
    /// Passing `AXTrustedCheckOptionPrompt: true` triggers the OS-level prompt.
    static func requestAccessibilityPermission() {
        // Use the raw string key to avoid concurrency-safety warning on the global constant
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Simulated Copy

    /// Simulates Cmd+C to copy the currently selected text from the frontmost app,
    /// then reads the clipboard. Restores the previous clipboard content afterward.
    /// Requires Accessibility permission (PostEvent TCC privilege).
    /// Returns the selected text, or `nil` if nothing was copied.
    @MainActor
    static func copySelectedText() async -> String? {
        guard checkAccessibilityPermission() else {
            Log.hotkey.warning("Accessibility permission not granted — cannot simulate Cmd+C")
            showAccessibilityPermissionAlert()
            return nil
        }

        let pasteboard = NSPasteboard.general

        // Save current clipboard content to restore later
        let previousChangeCount = pasteboard.changeCount
        let previousText = pasteboard.string(forType: .string)

        // Simulate Cmd+C keystroke using CGEvent
        // Virtual key code 0x08 = "C" key
        let keyCode: CGKeyCode = 0x08

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            Log.hotkey.error("Failed to create CGEvent for Cmd+C simulation")
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Wait for the clipboard to update (the target app needs time to process Cmd+C)
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Read the newly copied text
        let copiedText: String?
        if pasteboard.changeCount != previousChangeCount {
            copiedText = pasteboard.string(forType: .string)
        } else {
            // Clipboard didn't change — no text was selected or copy failed
            Log.hotkey.debug("Clipboard unchanged after Cmd+C simulation — no text was selected")
            copiedText = nil
        }

        // Restore previous clipboard content (so we don't clobber the user's clipboard)
        if let previousText {
            pasteboard.clearContents()
            pasteboard.setString(previousText, forType: .string)
        }

        return copiedText
    }

    // MARK: - Permission Alert

    /// Shows an alert explaining that Accessibility permission is needed for text capture.
    @MainActor
    private static func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Mac AI Helper needs Accessibility permission to copy selected text \
            from other applications.

            Please open System Settings → Privacy & Security → Accessibility, \
            then enable access for Mac AI Helper.

            You may need to restart the app after granting permission.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )!
            )
        }
    }
}
