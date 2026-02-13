// HotkeyService.swift
// Global keyboard shortcut detection using CGEvent tap.
// Monitors for configurable shortcuts defined by ShortcutDefinition.

import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
final class HotkeyService {
    /// Callback fired when the text shortcut is detected
    var onTextShortcut: (@MainActor () -> Void)?

    /// Callback fired when the screenshot shortcut is detected
    var onScreenshotShortcut: (@MainActor () -> Void)?

    /// Current shortcut definitions (configurable)
    private var textShortcut: ShortcutDefinition
    private var screenshotShortcut: ShortcutDefinition

    /// The CGEvent tap port
    private var eventTap: CFMachPort?

    /// The run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?

    /// Retained state pointer for cleanup
    private var statePtr: UnsafeMutableRawPointer?

    /// Time window for detecting a double-tap (seconds)
    private let doubleTapWindow: TimeInterval = 1.5

    init(textShortcut: ShortcutDefinition, screenshotShortcut: ShortcutDefinition) {
        self.textShortcut = textShortcut
        self.screenshotShortcut = screenshotShortcut
    }

    // MARK: - Permission Checking

    /// Checks if accessibility permission is granted for global hotkey monitoring.
    nonisolated static func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Opens System Settings to the accessibility pane so the user can grant permission.
    nonisolated static func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt" as CFString: true as CFBoolean
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Shortcut Updates

    /// Updates the shortcut definitions and restarts monitoring to apply changes.
    func updateShortcuts(
        textShortcut: ShortcutDefinition, screenshotShortcut: ShortcutDefinition
    ) {
        self.textShortcut = textShortcut
        self.screenshotShortcut = screenshotShortcut

        // Restart monitoring with new shortcuts
        if eventTap != nil {
            stopMonitoring()
            startMonitoring()
        }
    }

    // MARK: - Monitoring

    /// Creates a CGEvent tap and starts monitoring global keyboard events.
    func startMonitoring() {
        // Create shared state for the C callback
        let state = HotkeyState(
            textShortcut: textShortcut,
            screenshotShortcut: screenshotShortcut,
            doubleTapWindow: doubleTapWindow,
            onTextShortcut: { [weak self] in
                Task { @MainActor in
                    self?.onTextShortcut?()
                }
            },
            onScreenshotShortcut: { [weak self] in
                Task { @MainActor in
                    self?.onScreenshotShortcut?()
                }
            }
        )

        let ptr = Unmanaged.passRetained(state).toOpaque()

        // Create event tap for key down events
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                callback: hotkeyEventCallback,
                userInfo: ptr
            )
        else {
            Unmanaged<HotkeyState>.fromOpaque(ptr).release()
            print("⚠️ Failed to create CGEvent tap. Accessibility permission may not be granted.")
            return
        }

        statePtr = ptr
        eventTap = tap
        state.eventTap = tap

        // Add to run loop
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Disables and removes the event tap from the run loop.
    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let ptr = statePtr {
            Unmanaged<HotkeyState>.fromOpaque(ptr).release()
        }
        eventTap = nil
        runLoopSource = nil
        statePtr = nil
    }
}

// MARK: - Shared Hotkey State (for C callback)

/// Encapsulates mutable state accessed from the CGEvent tap callback.
/// This class is intentionally not Sendable — it's only accessed from the main run loop.
private final class HotkeyState {
    let textKeyCode: UInt16
    let textModifiers: UInt64
    let textDoubleTap: Bool
    let screenshotKeyCode: UInt16
    let screenshotModifiers: UInt64
    let screenshotDoubleTap: Bool
    let doubleTapWindow: TimeInterval
    let onTextShortcut: @Sendable () -> Void
    let onScreenshotShortcut: @Sendable () -> Void

    var tapCount = 0
    var lastTapTime: TimeInterval = 0
    var lastTapKeyCode: UInt16 = 0
    var eventTap: CFMachPort?

    init(
        textShortcut: ShortcutDefinition,
        screenshotShortcut: ShortcutDefinition,
        doubleTapWindow: TimeInterval,
        onTextShortcut: @escaping @Sendable () -> Void,
        onScreenshotShortcut: @escaping @Sendable () -> Void
    ) {
        self.textKeyCode = textShortcut.keyCode
        self.textModifiers = textShortcut.modifierFlags
        self.textDoubleTap = textShortcut.doubleTap
        self.screenshotKeyCode = screenshotShortcut.keyCode
        self.screenshotModifiers = screenshotShortcut.modifierFlags
        self.screenshotDoubleTap = screenshotShortcut.doubleTap
        self.doubleTapWindow = doubleTapWindow
        self.onTextShortcut = onTextShortcut
        self.onScreenshotShortcut = onScreenshotShortcut
    }

    /// Checks if the given event flags contain all required modifier flags.
    func flagsMatch(eventFlags: CGEventFlags, required: UInt64) -> Bool {
        let requiredFlags = CGEventFlags(rawValue: required)
        let sanitized = ShortcutDefinition.sanitizedModifierFlags(eventFlags)
        let sanitizedFlags = CGEventFlags(rawValue: sanitized)

        // All required modifiers must be present
        if requiredFlags.contains(.maskCommand) && !sanitizedFlags.contains(.maskCommand) {
            return false
        }
        if requiredFlags.contains(.maskShift) && !sanitizedFlags.contains(.maskShift) {
            return false
        }
        if requiredFlags.contains(.maskAlternate) && !sanitizedFlags.contains(.maskAlternate) {
            return false
        }
        if requiredFlags.contains(.maskControl) && !sanitizedFlags.contains(.maskControl) {
            return false
        }
        // No extra modifiers beyond what's required
        return sanitized == required
    }
}

// MARK: - C Callback

/// Static C-compatible callback for CGEvent tap.
private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passRetained(event)
    }

    let state = Unmanaged<HotkeyState>.fromOpaque(userInfo).takeUnretainedValue()

    // If the tap is disabled (e.g. by timeout), re-enable it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = state.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags

    // Check screenshot shortcut (non-double-tap first, then double-tap)
    if keyCode == state.screenshotKeyCode
        && state.flagsMatch(eventFlags: flags, required: state.screenshotModifiers)
    {
        if state.screenshotDoubleTap {
            let now = ProcessInfo.processInfo.systemUptime
            if state.lastTapKeyCode == state.screenshotKeyCode
                && now - state.lastTapTime < state.doubleTapWindow
            {
                state.tapCount = 0
                state.lastTapTime = 0
                state.lastTapKeyCode = 0
                state.onScreenshotShortcut()
                return Unmanaged.passRetained(event)
            } else {
                state.tapCount = 1
                state.lastTapTime = now
                state.lastTapKeyCode = state.screenshotKeyCode
                return Unmanaged.passRetained(event)
            }
        } else {
            state.tapCount = 0
            state.onScreenshotShortcut()
            // Consume the event to prevent it from reaching other apps
            return nil
        }
    }

    // Check text shortcut
    if keyCode == state.textKeyCode
        && state.flagsMatch(eventFlags: flags, required: state.textModifiers)
    {
        if state.textDoubleTap {
            let now = ProcessInfo.processInfo.systemUptime
            if state.lastTapKeyCode == state.textKeyCode
                && now - state.lastTapTime < state.doubleTapWindow
            {
                // Second tap within the window — fire text shortcut
                state.tapCount = 0
                state.lastTapTime = 0
                state.lastTapKeyCode = 0
                state.onTextShortcut()
            } else {
                // First tap — start tracking
                state.tapCount = 1
                state.lastTapTime = now
                state.lastTapKeyCode = state.textKeyCode
            }
            // Always pass through so the normal key action still works (e.g. CMD+C copy)
            return Unmanaged.passRetained(event)
        } else {
            state.tapCount = 0
            state.onTextShortcut()
            return nil
        }
    }

    // Not a matching shortcut — reset counter and pass through
    state.tapCount = 0
    state.lastTapKeyCode = 0
    return Unmanaged.passRetained(event)
}
