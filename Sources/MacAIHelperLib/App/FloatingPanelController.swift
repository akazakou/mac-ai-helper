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

    init(appState: AppState) {
        self.appState = appState
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

        // Create floating panel (resizable by the user)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
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
        panel.minSize = NSSize(width: 320, height: 200)
        panel.maxSize = NSSize(width: 800, height: 900)
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

        panel?.close()
        panel = nil

        // Reset transient state
        appState.isLoading = false
        appState.showingResult = false
    }
}
