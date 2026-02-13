// ScreenCaptureService.swift
// Screen region capture using ScreenCaptureKit with a custom selection overlay.

import AppKit
import Foundation
import ScreenCaptureKit

struct ScreenCaptureService: Sendable {
    /// Captures a screen region selected by the user via a transparent overlay.
    /// Uses ScreenCaptureKit for the actual pixel capture.
    /// Returns PNG image data.
    @MainActor
    static func captureRegion() async throws -> Data {
        // Step 1: Let the user select a region FIRST (no permission needed for the overlay)
        let selectedRect = try await RegionSelector.selectRegion()

        // Step 2: Now try to capture the selected region using ScreenCaptureKit
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )

            guard let mainDisplay = content.displays.first else {
                throw AppError.screenCapturePermissionDenied
            }

            let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = selectedRect
            config.width = Int(selectedRect.width * CGFloat(mainDisplay.scaleFactor))
            config.height = Int(selectedRect.height * CGFloat(mainDisplay.scaleFactor))
            config.showsCursor = false
            config.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let bitmapRep = NSBitmapImageRep(cgImage: image)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]),
                  !pngData.isEmpty
            else {
                throw AppError.screenCapturePermissionDenied
            }

            return pngData
        } catch {
            // If the error is a ScreenCaptureKit TCC denial, show a helpful alert
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain"
                && nsError.code == -3801
            {
                showPermissionDeniedAlert()
                throw AppError.screenCapturePermissionDenied
            }
            throw error
        }
    }

    /// Checks if screen recording permission has been granted.
    static func checkPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            return true
        } catch {
            return false
        }
    }

    /// Shows an alert explaining that Screen Recording permission is needed.
    @MainActor
    private static func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
            Mac AI Helper needs Screen Recording permission to capture screenshots.

            Please open System Settings → Privacy & Security → Screen Recording, \
            then enable access for Terminal (or MacAIHelper).

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
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )!
            )
        }
    }
}

// MARK: - Display Scale Factor Extension

private extension SCDisplay {
    /// Retina scale factor for the display.
    var scaleFactor: Int {
        guard let screen = NSScreen.screens.first(where: {
            Int($0.frame.width) == Int(width) && Int($0.frame.height) == Int(height)
        }) else {
            return 2 // Default to Retina
        }
        return Int(screen.backingScaleFactor)
    }
}

// MARK: - Region Selector

/// Presents a transparent fullscreen overlay for the user to drag-select a screen region.
/// Uses a crosshair cursor and draws the selection rectangle.
@MainActor
private final class RegionSelector {
    /// Retains the active selection window to prevent ARC deallocation
    private static var activeWindow: RegionSelectorWindow?

    /// Prompts the user to select a region on screen.
    /// Returns the selected CGRect in screen coordinates (top-left origin for CG).
    static func selectRegion() async throws -> CGRect {
        defer { activeWindow = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let selector = RegionSelectorWindow(continuation: continuation)
            activeWindow = selector
            selector.beginSelection()
        }
    }
}

// MARK: - Region Selector Window

/// A transparent fullscreen window that lets the user drag to select a region.
@MainActor
private final class RegionSelectorWindow: NSWindow {
    private let continuation: CheckedContinuation<CGRect, Error>
    private var selectionView: SelectionOverlayView?
    private var resolved = false

    // Borderless windows must override canBecomeKey to receive keyboard events (e.g. ESC)
    override var canBecomeKey: Bool { true }

    init(continuation: CheckedContinuation<CGRect, Error>) {
        self.continuation = continuation

        // Cover the entire screen
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Configure as transparent overlay
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        self.level = .screenSaver
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false

        // Set up the selection overlay view
        let overlay = SelectionOverlayView(frame: screenFrame)
        overlay.onSelectionComplete = { [weak self] rect in
            self?.completeSelection(rect)
        }
        overlay.onSelectionCancelled = { [weak self] in
            self?.cancelSelection()
        }
        self.contentView = overlay
        self.selectionView = overlay
    }

    func beginSelection() {
        // Activate the app so the overlay window can receive focus
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)
        NSCursor.crosshair.push()
    }

    private func completeSelection(_ rect: NSRect) {
        guard !resolved else { return }
        resolved = true

        NSCursor.pop()
        orderOut(nil)

        guard let screen = NSScreen.main else {
            continuation.resume(throwing: AppError.screenCapturePermissionDenied)
            return
        }

        // Convert from AppKit coordinates (bottom-left origin) to CG coordinates (top-left origin)
        let cgRect = CGRect(
            x: rect.origin.x,
            y: screen.frame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        guard cgRect.width >= 4 && cgRect.height >= 4 else {
            continuation.resume(throwing: AppError.screenCapturePermissionDenied)
            return
        }

        continuation.resume(returning: cgRect)
    }

    private func cancelSelection() {
        guard !resolved else { return }
        resolved = true

        NSCursor.pop()
        orderOut(nil)
        continuation.resume(throwing: AppError.screenCaptureCancelled)
    }
}

// MARK: - Selection Overlay View

/// Custom NSView that handles mouse drag for region selection.
private final class SelectionOverlayView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    var onSelectionCancelled: (() -> Void)?

    private var dragOrigin: NSPoint?
    private var selectionRect: NSRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw semi-transparent background overlay
        NSColor.black.withAlphaComponent(0.2).setFill()
        dirtyRect.fill()

        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        // Clear the selected area
        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        // Draw border around selection
        let borderPath = NSBezierPath(rect: selectionRect)
        borderPath.lineWidth = 2
        NSColor.white.withAlphaComponent(0.8).setStroke()
        borderPath.stroke()

        // Draw dashed inner border
        let dashedPath = NSBezierPath(rect: selectionRect.insetBy(dx: 1, dy: 1))
        dashedPath.lineWidth = 1
        dashedPath.setLineDash([4, 4], count: 2, phase: 0)
        NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
        dashedPath.stroke()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(origin.x, current.x)
        let y = min(origin.y, current.y)
        let width = abs(current.x - origin.x)
        let height = abs(current.y - origin.y)

        selectionRect = NSRect(x: x, y: y, width: width, height: height)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard selectionRect.width > 2 && selectionRect.height > 2 else {
            onSelectionCancelled?()
            return
        }
        onSelectionComplete?(selectionRect)
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onSelectionCancelled?()
        }
    }
}
