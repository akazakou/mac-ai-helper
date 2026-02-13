// ShortcutRecorderView.swift
// A reusable shortcut recorder component following standard macOS conventions.
// Captures modifier+key combinations via local NSEvent monitoring.
// Automatically detects double-tap sequences (e.g. ⌘C + C).

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderView: View {
    /// The current shortcut definition (binding to parent)
    @Binding var shortcut: ShortcutDefinition

    /// Callback when the shortcut is saved
    var onSave: (ShortcutDefinition) -> Void

    /// Whether currently in recording mode
    @State private var isRecording = false

    /// Temporarily captured key code during recording
    @State private var recordedKeyCode: UInt16?

    /// Temporarily captured modifier flags during recording
    @State private var recordedModifiers: UInt64 = 0

    /// Whether a double-tap was detected during recording
    @State private var recordedDoubleTap = false

    /// Live display text during recording
    @State private var recordingDisplay = ""

    /// The local event monitor handle
    @State private var eventMonitor: Any?

    /// Timer for detecting double-tap timeout
    @State private var doubleTapTimer: Timer?

    /// Whether we're waiting for a potential second tap
    @State private var awaitingSecondTap = false

    /// Time window for double-tap detection (seconds)
    private let doubleTapWindow: TimeInterval = 1.5

    var body: some View {
        HStack(spacing: 6) {
            if isRecording {
                recordingView
            } else {
                displayView
            }
        }
    }

    // MARK: - Display Mode

    private var displayView: some View {
        HStack(spacing: 6) {
            // Shortcut badge
            Text(shortcut.displayName)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 120, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Edit button
            Button {
                startRecording()
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Edit shortcut")
        }
    }

    // MARK: - Recording Mode

    private var recordingView: some View {
        HStack(spacing: 6) {
            // Live recording display with minimum width for ~15 characters
            Text(recordingDisplay.isEmpty ? "Type shortcut…" : recordingDisplay)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(recordingDisplay.isEmpty ? .secondary : .primary)
                .frame(minWidth: 150, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                )

            // Save button (checkmark)
            Button {
                saveRecordedShortcut()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.borderless)
            .disabled(recordedKeyCode == nil)
            .help("Save shortcut")

            // Clear button (x mark)
            Button {
                cancelRecording()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Cancel recording")
        }
    }

    // MARK: - Recording Logic

    private func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = 0
        recordedDoubleTap = false
        recordingDisplay = ""
        awaitingSecondTap = false

        // Pause global hotkeys so they don't fire while recording
        AppDelegate.shared?.pauseHotkeys()

        // Monitor key events locally (within this app's windows only)
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { event in
            handleKeyEvent(event)
            // Return nil to consume the event so it doesn't propagate
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        doubleTapTimer?.invalidate()
        doubleTapTimer = nil
        awaitingSecondTap = false
        isRecording = false

        // Resume global hotkeys with current shortcut definitions
        AppDelegate.shared?.resumeHotkeys()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // ESC clears the shortcut and cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return
        }

        // Only process keyDown events for actual key capture
        guard event.type == .keyDown else {
            // For flagsChanged, show live modifier preview before any key is pressed
            if event.type == .flagsChanged && recordedKeyCode == nil && !awaitingSecondTap {
                let cgFlags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                let modifiers = ShortcutDefinition.sanitizedModifierFlags(cgFlags)
                if modifiers != 0 {
                    recordingDisplay = modifierSymbols(for: modifiers) + "…"
                } else {
                    recordingDisplay = ""
                }
            }
            return
        }

        let keyCode = event.keyCode
        let cgFlags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        let modifiers = ShortcutDefinition.sanitizedModifierFlags(cgFlags)

        // Require at least one modifier for a global shortcut
        guard modifiers != 0 else { return }

        // Check if this is a second tap of the same key+modifiers (double-tap detection)
        if awaitingSecondTap,
            let firstKeyCode = recordedKeyCode,
            keyCode == firstKeyCode,
            modifiers == recordedModifiers
        {
            // Double-tap detected!
            doubleTapTimer?.invalidate()
            doubleTapTimer = nil
            awaitingSecondTap = false
            recordedDoubleTap = true
            recordingDisplay = ShortcutDefinition.buildDisplayName(
                keyCode: keyCode, modifierFlags: modifiers, doubleTap: true
            )
            return
        }

        // First key press (or different key — reset and start fresh)
        doubleTapTimer?.invalidate()
        recordedKeyCode = keyCode
        recordedModifiers = modifiers
        recordedDoubleTap = false
        awaitingSecondTap = true

        // Show the single-key display immediately
        recordingDisplay = ShortcutDefinition.buildDisplayName(
            keyCode: keyCode, modifierFlags: modifiers, doubleTap: false
        )

        // Start timer — if no second tap within the window, finalize as single
        doubleTapTimer = Timer.scheduledTimer(withTimeInterval: doubleTapWindow, repeats: false) {
            _ in
            DispatchQueue.main.async {
                self.awaitingSecondTap = false
            }
        }
    }

    private func saveRecordedShortcut() {
        guard let keyCode = recordedKeyCode else { return }

        let newShortcut = ShortcutDefinition(
            keyCode: keyCode,
            modifierFlags: recordedModifiers,
            doubleTap: recordedDoubleTap,
            displayName: ShortcutDefinition.buildDisplayName(
                keyCode: keyCode,
                modifierFlags: recordedModifiers,
                doubleTap: recordedDoubleTap
            )
        )

        shortcut = newShortcut
        onSave(newShortcut)
        stopRecording()
    }

    private func cancelRecording() {
        stopRecording()
    }

    // MARK: - Helpers

    /// Builds modifier symbols string for live preview (e.g. "⌃⌥⇧⌘")
    private func modifierSymbols(for modifiers: UInt64) -> String {
        let flags = CGEventFlags(rawValue: modifiers)
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        return parts.joined()
    }
}
