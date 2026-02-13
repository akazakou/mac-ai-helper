// AppDelegate.swift
// Manages app lifecycle, initializes services, and handles hotkey callbacks.

import AppKit
import SwiftUI

/// Identifies each tab in the Settings window for programmatic navigation
enum SettingsTab: Hashable, Sendable {
    case prompts
    case apiKeys
    case shortcuts
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Static reference for access from views (NSApp.delegate is SwiftUI's wrapper)
    static var shared: AppDelegate?

    /// Shared application state accessible throughout the app
    let appState = AppState()

    /// Global hotkey monitoring service
    private var hotkeyService: HotkeyService?

    /// Floating panel for prompt popup
    private var floatingPanel: FloatingPanelController?

    /// Settings window (retained to keep it alive)
    private var settingsWindow: NSWindow?

    /// Tip Jar window (retained to keep it alive)
    private var tipJarWindow: NSWindow?

    /// Timer that silently polls for accessibility permission after initial prompt
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Ensure the app doesn't appear in the Dock
        NSApp.setActivationPolicy(.accessory)

        setupHotkeyService()

        // Load AI models at startup so the popup opens instantly
        Task {
            await appState.loadModels()
        }

        // If no API keys are configured, open settings on the API Keys tab
        if !appState.hasAPIKeys {
            // Small delay to let the menu bar finish initializing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings(tab: .apiKeys)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.stopMonitoring()
    }

    // MARK: - Settings Window

    /// Opens the settings window on a specific tab, creating it if necessary.
    func openSettings(tab: SettingsTab? = nil) {
        if let tab {
            appState.selectedSettingsTab = tab
        }

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environment(appState)

        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mac AI Helper Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.settingsWindow = window

        // Bring the window to front without showing a Dock icon
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Tip Jar Window

    /// Opens the Tip Jar window, creating it if necessary.
    func openTipJar() {
        if let window = tipJarWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let tipJarView = TipJarView { [weak self] in
            self?.tipJarWindow?.orderOut(nil)
        }

        let hostingView = NSHostingView(rootView: tipJarView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tip Developer"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.tipJarWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hotkey Service Setup

    private func setupHotkeyService() {
        guard HotkeyService.checkAccessibilityPermission() else {
            // Show permission dialog once on startup
            HotkeyService.requestAccessibilityPermission()
            // Start silently polling until the user grants permission
            startPermissionPolling()
            return
        }

        activateHotkeyMonitoring()
    }

    /// Silently polls for accessibility permission without showing any dialog.
    /// Automatically activates hotkey monitoring once permission is granted.
    private func startPermissionPolling() {
        // Invalidate any existing timer to avoid duplicates
        permissionPollTimer?.invalidate()

        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Silent check — no dialog shown
                if HotkeyService.checkAccessibilityPermission() {
                    self.permissionPollTimer?.invalidate()
                    self.permissionPollTimer = nil
                    self.activateHotkeyMonitoring()
                }
            }
        }
    }

    /// Creates the hotkey service and starts monitoring global keyboard events.
    private func activateHotkeyMonitoring() {
        // Stop polling if still active
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil

        hotkeyService = HotkeyService(
            textShortcut: appState.settings.promptShortcut,
            screenshotShortcut: appState.settings.screenshotShortcut
        )
        hotkeyService?.onTextShortcut = { [weak self] in
            Task { @MainActor in
                self?.handleTextShortcut()
            }
        }
        hotkeyService?.onScreenshotShortcut = { [weak self] in
            Task { @MainActor in
                self?.handleScreenshotShortcut()
            }
        }
        hotkeyService?.startMonitoring()
    }

    // MARK: - Shortcut Updates

    /// Called by SettingsViewModel when shortcuts are changed by the user.
    func updateShortcuts() {
        hotkeyService?.updateShortcuts(
            textShortcut: appState.settings.promptShortcut,
            screenshotShortcut: appState.settings.screenshotShortcut
        )
    }

    /// Pauses global hotkey monitoring (e.g. while recording a new shortcut).
    func pauseHotkeys() {
        hotkeyService?.stopMonitoring()
    }

    /// Resumes global hotkey monitoring with current shortcut definitions.
    func resumeHotkeys() {
        hotkeyService?.updateShortcuts(
            textShortcut: appState.settings.promptShortcut,
            screenshotShortcut: appState.settings.screenshotShortcut
        )
        hotkeyService?.startMonitoring()
    }

    // MARK: - Shortcut Handlers

    private func handleTextShortcut() {
        guard appState.hasAPIKeys else {
            showNoAPIKeysAlert()
            return
        }

        let text = PasteboardService.readText()
        guard let text, !text.isEmpty else { return }

        appState.capturedText = text
        appState.capturedImage = nil
        showPromptPopup()
    }

    private func handleScreenshotShortcut() {
        guard appState.hasAPIKeys else {
            showNoAPIKeysAlert()
            return
        }

        Task {
            do {
                let imageData = try await ScreenCaptureService.captureRegion()
                appState.capturedImage = imageData
                appState.capturedText = nil
                showPromptPopup()
            } catch AppError.screenCaptureCancelled {
                // User pressed ESC — silently ignore
            } catch {
                print("⚠️ Screenshot capture failed: \(error)")
                appState.lastError = error.localizedDescription
            }
        }
    }

    /// Shows a centered alert informing the user that API keys are required,
    /// then opens settings on the API Keys tab when dismissed.
    private func showNoAPIKeysAlert() {
        // Bring app to front so the alert is visible
        NSApp.activate(ignoringOtherApps: true)

        let alertView = NoAPIKeysAlertView {
            // Dismiss handler — close the alert window and open settings
            NSApp.stopModal()
        }

        let hostingView = NSHostingView(rootView: alertView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 220)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.titled, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isFloatingPanel = true
        window.center()
        window.isReleasedWhenClosed = false

        NSApp.runModal(for: window)
        window.orderOut(nil)

        openSettings(tab: .apiKeys)
    }

    private func showPromptPopup() {
        if floatingPanel == nil {
            floatingPanel = FloatingPanelController(appState: appState)
        }
        floatingPanel?.showPopup()
    }
}

// MARK: - AppState

/// Observable application state shared across views and services
@Observable
@MainActor
final class AppState {
    var capturedText: String?
    var capturedImage: Data?
    var aiResponse: String?
    var isLoading = false
    var lastError: String?
    var showingResult = false

    /// Currently selected tab in the Settings window
    var selectedSettingsTab: SettingsTab = .prompts

    /// Settings loaded from persistence
    var settings: AppSettings

    /// Whether at least one API key is configured
    var hasAPIKeys: Bool { !settings.apiKeyEntries.isEmpty }

    /// Available AI models fetched from providers
    var availableModels: [AIModel] = []

    private let settingsService = SettingsService()

    init() {
        self.settings = SettingsService().loadSettings()
    }

    func saveSettings() {
        do {
            try settingsService.saveSettings(settings)
        } catch {
            lastError = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    /// Whether models are currently being loaded
    var isLoadingModels = false

    /// Fetches models from all configured providers.
    /// Uses a single keychain read to avoid multiple password prompts.
    func loadModels() async {
        isLoadingModels = true

        // Read all API keys in a single keychain access (one password prompt)
        let cachedKeys = KeychainService.readAllKeys()

        let configuredProviders = Set(settings.apiKeyEntries.map(\.provider))
        var allModels: [AIModel] = []

        for provider in configuredProviders {
            do {
                let apiKey = try KeychainService.apiKey(
                    for: provider, entries: settings.apiKeyEntries,
                    cachedKeys: cachedKeys
                )
                let models = try await AIServiceRouter.fetchModels(
                    provider: provider, apiKey: apiKey
                )
                allModels.append(contentsOf: models)
            } catch {
                print("⚠️ Failed to fetch models for \(provider.rawValue): \(error.localizedDescription)")
            }
        }

        availableModels = allModels.sorted { $0.name < $1.name }
        isLoadingModels = false

        // Auto-select first model if none selected
        if settings.selectedModelId == nil, let firstModel = availableModels.first {
            settings.selectedModelId = firstModel.id
            settings.selectedProvider = firstModel.provider
            saveSettings()
        }
    }
}
