// FloatingPanelController.swift
// Manages the floating NSPanel that hosts the prompt popup and result views.
// The panel floats above all windows, is non-activating, and dismisses on focus loss.

import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    /// Reference to the shared app state
    private let appState: AppState

    /// The floating panel window
    private var panel: NSPanel?

    /// Local event monitor for ESC key to dismiss the panel
    private var escKeyMonitor: Any?

    /// Observer that auto-dismisses the panel when it loses focus
    private var resignKeyObserver: NSObjectProtocol?

    /// Delay before auto-dismissing on focus loss, so clicks back into the panel don't close it
    private nonisolated static let focusLossDismissDelay: TimeInterval = 0.2

    /// Key code of the ESC key
    private static let escKeyCode: UInt16 = 53

    // MARK: - Panel Size Constants & Persistence Keys

    /// Default initial panel size (used when no saved size exists)
    private static let defaultWidth: CGFloat = 600
    private static let defaultHeight: CGFloat = 650

    private static let minWidth: CGFloat = 480
    private static let minHeight: CGFloat = 260
    private static let maxWidth: CGFloat = 1200
    private static let maxHeight: CGFloat = 1170

    /// UserDefaults keys for persisting the user-chosen panel size
    private static let panelWidthKey = "floatingPanelWidth"
    private static let panelHeightKey = "floatingPanelHeight"

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Size Persistence Helpers

    /// Returns the saved panel size from App Group UserDefaults, clamped to min/max bounds,
    /// or the default size if nothing was saved yet.
    private func restoredPanelSize() -> NSSize {
        let defaults = AppConstants.sharedDefaults
        let savedWidth = defaults.double(forKey: Self.panelWidthKey)
        let savedHeight = defaults.double(forKey: Self.panelHeightKey)

        // If both values are zero the user has never resized — use defaults
        guard savedWidth > 0, savedHeight > 0 else {
            return NSSize(width: Self.defaultWidth, height: Self.defaultHeight)
        }

        let clampedWidth = min(max(CGFloat(savedWidth), Self.minWidth), Self.maxWidth)
        let clampedHeight = min(max(CGFloat(savedHeight), Self.minHeight), Self.maxHeight)
        return NSSize(width: clampedWidth, height: clampedHeight)
    }

    /// Persists the current panel frame size to App Group UserDefaults.
    private func savePanelSize() {
        guard let size = panel?.frame.size else { return }
        let defaults = AppConstants.sharedDefaults
        defaults.set(Double(size.width), forKey: Self.panelWidthKey)
        defaults.set(Double(size.height), forKey: Self.panelHeightKey)
    }

    /// Shows the prompt popup panel centered on the screen.
    func showPopup() {
        // Dismiss existing panel if present
        dismissPopup()

        // Create the SwiftUI content
        let viewModel = PromptPopupViewModel(appState: appState)
        let contentView = PromptPopupView(
            viewModel: viewModel,
            appState: appState,
            onDismiss: { [weak self] in
                self?.dismissPopup()
            },
            onResponseStarted: { [weak self] in
                self?.enterResponseMode()
            }
        )

        // Create the hosting view
        let hostingView = NSHostingView(rootView: contentView)

        // Restore saved size or fall back to defaults
        let panelSize = restoredPanelSize()

        // Create floating panel (resizable by the user)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        // Title is hidden in the panel but names the window in Mission Control
        panel.title = "Mac AI Helper"
        // A pinned panel must stay visible while another app is active
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
        panel.maxSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)
        panel.contentView = hostingView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let origin = NSPoint(
                x: screenFrame.midX - panelSize.width / 2,
                y: screenFrame.midY - panelSize.height / 2 + 100  // Slightly above center
            )
            panel.setFrameOrigin(origin)
        }

        // Show the panel
        panel.orderFrontRegardless()
        panel.makeKey()

        self.panel = panel

        monitorEscKey()
        observeFocusLoss(of: panel)
    }

    /// Turns the popup into a regular app window once a prompt is running:
    /// Dock icon, Cmd+Tab and Mission Control entries, no longer always on top.
    private func enterResponseMode() {
        guard let panel else { return }
        NSApp.setActivationPolicy(.regular)
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.collectionBehavior = [.managed, .participatesInCycle]
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Dismisses the panel when ESC is pressed.
    private func monitorEscKey() {
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escKeyCode else { return event }
            self?.dismissPopup()
            return nil // Consume the event
        }
    }

    /// Auto-dismisses the panel when it loses focus, unless the user pinned it.
    private func observeFocusLoss(of panel: NSPanel) {
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.focusLossDismissDelay) {
                // Only dismiss if panel is still not key (user didn't click back)
                guard let self, self.panel?.isKeyWindow == false, !self.appState.isPopupPinned
                else { return }
                self.dismissPopup()
            }
        }
    }

    /// Dismisses the floating panel.
    func dismissPopup() {
        // Remove ESC key monitor
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }

        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }

        // Persist the current panel size before closing
        savePanelSize()

        panel?.close()
        panel = nil

        // Back to menu-bar-only: no Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Reset transient state
        appState.isLoading = false
        appState.showingResult = false
        appState.isPopupPinned = false
    }
}
