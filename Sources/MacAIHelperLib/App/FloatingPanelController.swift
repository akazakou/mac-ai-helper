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

        // Monitor ESC key to dismiss the panel
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.dismissPopup()
                return nil // Consume the event
            }
            return event
        }

        // Observe when the panel loses focus to auto-dismiss
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Small delay to allow clicking within the panel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Only dismiss if panel is still not key (user didn't click back)
                if self?.panel?.isKeyWindow == false {
                    self?.dismissPopup()
                }
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

        // Persist the current panel size before closing
        savePanelSize()

        panel?.close()
        panel = nil

        // Reset transient state
        appState.isLoading = false
        appState.showingResult = false
    }
}
