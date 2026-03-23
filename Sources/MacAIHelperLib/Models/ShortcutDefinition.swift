// ShortcutDefinition.swift
// Defines global keyboard shortcut names for the KeyboardShortcuts framework.
// Shortcuts are persisted automatically by the library in UserDefaults.

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Shortcut for triggering the text prompt popup (default: ⇧⌘C)
    static let textPrompt = Self("textPrompt", default: .init(.c, modifiers: [.command, .shift]))
    /// Shortcut for triggering screen region capture (default: ⌃⌘C)
    static let screenshotCapture = Self(
        "screenshotCapture", default: .init(.c, modifiers: [.command, .control]))
}
