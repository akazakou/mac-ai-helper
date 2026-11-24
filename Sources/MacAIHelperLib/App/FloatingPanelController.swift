// FloatingPanelController.swift
// Manages one floating NSPanel that hosts the prompt popup and result views.
// The panel floats above all windows, is non-activating, and dismisses on focus loss.
// Each popup has its own controller, so pinned popups keep working next to a new one.

import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    /// Reference to the shared app state
    private let appState: AppState

    /// State of this popup: captured content, request progress and result
    private let session: PopupSession

    /// Runs the prompt; kept here so that closing the panel can stop its request
    private let viewModel: PromptPopupViewModel

    /// Called once the panel has closed, however it was closed
    private let onClose: (FloatingPanelController) -> Void

    /// The floating panel window
    private var panel: NSPanel?

    /// Local event monitor for ESC key to dismiss the panel
    private var escKeyMonitor: Any?

    /// Delay before auto-dismissing on focus loss, so clicks back into the panel don't close it
    private static let focusLossDismissDelay: Duration = .milliseconds(200)

    /// Key code of the ESC key
    private static let escKeyCode: UInt16 = 53

    /// How far each additional open popup is shifted, so it does not cover the previous one
    private static let cascadeStep: CGFloat = 28

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

    /// Whether the popup survives focus loss and the opening of another popup
    var staysOpen: Bool {
        session.isPinned || panel?.isMiniaturized == true
    }

    init(
        appState: AppState, session: PopupSession,
        onClose: @escaping (FloatingPanelController) -> Void
    ) {
        self.appState = appState
        self.session = session
        self.viewModel = PromptPopupViewModel(appState: appState, session: session)
        self.onClose = onClose
    }

    // MARK: - Size Persistence Helpers

    /// Returns the saved panel size from UserDefaults, clamped to min/max bounds,
    /// or the default size if nothing was saved yet.
    private func restoredPanelSize() -> NSSize {
        let defaults = UserDefaults.standard
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

    /// Persists the current panel content size to UserDefaults.
    private func savePanelSize() {
        // Content size, not frame size: the frame also holds the title bar,
        // which would make the panel taller on every reopen.
        guard let size = panel?.contentView?.frame.size else { return }
        let defaults = UserDefaults.standard
        defaults.set(Double(size.width), forKey: Self.panelWidthKey)
        defaults.set(Double(size.height), forKey: Self.panelHeightKey)
    }

    /// Shows the prompt popup panel centered on the screen, shifted by one
    /// cascade step for each popup that is already open.
    func show(cascadeIndex: Int) {
        // Create the SwiftUI content
        let contentView = PromptPopupView(
            viewModel: viewModel,
            appState: appState,
            session: session,
            onDismiss: { [weak self] in
                self?.close()
            },
            onResponseStarted: { [weak self] in
                self?.enterResponseMode()
            }
        )

        // Create the hosting view
        let hostingView = NSHostingView(rootView: contentView)

        // Restore saved size or fall back to defaults
        let panelSize = restoredPanelSize()

        // Create floating panel (resizable by the user) with the standard title bar
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        // Shown in the title bar and names the window in Mission Control
        panel.title = "Mac AI Helper"
        // A pinned panel must stay visible while another app is active
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentMinSize = NSSize(width: Self.minWidth, height: Self.minHeight)
        panel.contentMaxSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)
        panel.contentView = hostingView
        panel.delegate = self
        addPinButton(to: panel)

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let cascadeOffset = Self.cascadeStep * CGFloat(cascadeIndex)
            let origin = NSPoint(
                x: screenFrame.midX - panelSize.width / 2 + cascadeOffset,
                y: screenFrame.midY - panelSize.height / 2 + 100 - cascadeOffset  // Slightly above center
            )
            panel.setFrameOrigin(origin)
        }

        // Show the panel
        panel.orderFrontRegardless()
        panel.makeKey()

        self.panel = panel

        monitorEscKey()
    }

    /// Closes the panel. Cleanup happens in windowWillClose, which also runs
    /// when the user closes the panel with its title bar button.
    func close() {
        panel?.close()
    }

    /// Puts the pin button at the trailing edge of the title bar.
    private func addPinButton(to panel: NSPanel) {
        let hostingView = NSHostingView(rootView: PopupPinButton(session: session))
        hostingView.frame.size = hostingView.fittingSize

        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = hostingView
        accessory.layoutAttribute = .trailing
        panel.addTitlebarAccessoryViewController(accessory)
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

    /// Dismisses the panel when ESC is pressed while it is the key window.
    private func monitorEscKey() {
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // With a sheet open (e.g. the save panel), ESC belongs to the sheet.
            guard let self, event.keyCode == Self.escKeyCode, event.window === self.panel,
                self.panel?.attachedSheet == nil
            else {
                return event
            }
            self.close()
            return nil // Consume the event
        }
    }

    // MARK: - NSWindowDelegate

    /// Auto-dismisses the panel when it loses focus, unless the user pinned or minimized it.
    func windowDidResignKey(_ notification: Notification) {
        Task { [weak self] in
            try? await Task.sleep(for: Self.focusLossDismissDelay)
            // Only dismiss if panel is still not key (user didn't click back).
            // A sheet (e.g. the save panel) takes key status without the user leaving the popup.
            guard let self, self.panel?.isKeyWindow == false, self.panel?.attachedSheet == nil,
                !self.staysOpen
            else { return }
            self.close()
        }
    }

    /// Releases everything tied to the panel, including its unfinished API request.
    func windowWillClose(_ notification: Notification) {
        // Remove ESC key monitor
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }

        // Persist the current panel size before closing
        savePanelSize()

        viewModel.cancelRequest()
        panel = nil
        onClose(self)
    }
}
