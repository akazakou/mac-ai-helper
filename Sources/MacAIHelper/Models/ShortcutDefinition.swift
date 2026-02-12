// ShortcutDefinition.swift
// Defines a keyboard shortcut configuration for global hotkey detection.

import CoreGraphics
import Foundation

struct ShortcutDefinition: Codable, Hashable, Sendable {
    /// CGKeyCode value for the target key
    var keyCode: UInt16
    /// CGEventFlags raw value representing modifier keys (CMD, Shift, etc.)
    var modifierFlags: UInt64
    /// Whether the shortcut requires a double-press of the key
    var doubleTap: Bool
    /// Human-readable description, e.g. "⌘C+C"
    var displayName: String
}
