// PasteboardService.swift
// Wrapper around NSPasteboard for clipboard read/write operations.

import AppKit
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
}
