// HotkeyService.swift
// Global keyboard shortcut detection using CGEvent tap.
// Monitors for CMD+C+C (double-tap) and CMD+Shift+C shortcuts.

import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
final class HotkeyService {
    /// Callback fired when the text shortcut (CMD+C+C) is detected
    var onTextShortcut: (@MainActor () -> Void)?

    /// Callback fired when the screenshot shortcut (CMD+Shift+C) is detected
    var onScreenshotShortcut: (@MainActor () -> Void)?

    /// The CGEvent tap port
    private var eventTap: CFMachPort?

    /// The run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?

    /// Time window for detecting a double-tap (seconds)
    private let doubleTapWindow: TimeInterval = 0.5

    /// The C key code (from Carbon)
    private let cKeyCode: UInt16 = UInt16(kVK_ANSI_C)

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

    // MARK: - Monitoring

    /// Creates a CGEvent tap and starts monitoring global keyboard events.
    func startMonitoring() {
        // Create shared state for the C callback
        let state = HotkeyState(
            cKeyCode: cKeyCode,
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

        let statePtr = Unmanaged.passRetained(state).toOpaque()

        // Create event tap for key down events
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                callback: hotkeyEventCallback,
                userInfo: statePtr
            )
        else {
            Unmanaged<HotkeyState>.fromOpaque(statePtr).release()
            print("⚠️ Failed to create CGEvent tap. Accessibility permission may not be granted.")
            return
        }

        eventTap = tap

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
        eventTap = nil
        runLoopSource = nil
    }
}

// MARK: - Shared Hotkey State (for C callback)

/// Encapsulates mutable state accessed from the CGEvent tap callback.
/// This class is intentionally not Sendable — it's only accessed from the main run loop.
private final class HotkeyState {
    let cKeyCode: UInt16
    let doubleTapWindow: TimeInterval
    let onTextShortcut: @Sendable () -> Void
    let onScreenshotShortcut: @Sendable () -> Void

    var tapCount = 0
    var lastTapTime: TimeInterval = 0
    var eventTap: CFMachPort?

    init(
        cKeyCode: UInt16,
        doubleTapWindow: TimeInterval,
        onTextShortcut: @escaping @Sendable () -> Void,
        onScreenshotShortcut: @escaping @Sendable () -> Void
    ) {
        self.cKeyCode = cKeyCode
        self.doubleTapWindow = doubleTapWindow
        self.onTextShortcut = onTextShortcut
        self.onScreenshotShortcut = onScreenshotShortcut
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

    // Check for CMD+Shift+C (screenshot shortcut) — must check before CMD+C
    if keyCode == state.cKeyCode
        && flags.contains(.maskCommand)
        && flags.contains(.maskShift)
    {
        state.tapCount = 0
        state.onScreenshotShortcut()
        return Unmanaged.passRetained(event)
    }

    // Check for CMD+C (potential double-tap for text shortcut)
    if keyCode == state.cKeyCode
        && flags.contains(.maskCommand)
        && !flags.contains(.maskShift)
        && !flags.contains(.maskAlternate)
        && !flags.contains(.maskControl)
    {
        let now = ProcessInfo.processInfo.systemUptime

        if now - state.lastTapTime < state.doubleTapWindow {
            // Second tap within the window — fire text shortcut
            state.tapCount = 0
            state.lastTapTime = 0
            state.onTextShortcut()
        } else {
            // First tap — start tracking
            state.tapCount = 1
            state.lastTapTime = now
        }

        // Always pass through so the normal CMD+C copy still works
        return Unmanaged.passRetained(event)
    }

    // Not a matching shortcut — reset counter and pass through
    state.tapCount = 0
    return Unmanaged.passRetained(event)
}
