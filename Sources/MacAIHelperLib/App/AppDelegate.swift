// AppDelegate.swift
// Manages app lifecycle, initializes services, and handles hotkey callbacks.

import AppKit
import os
import SwiftUI

/// Identifies each tab in the Settings window for programmatic navigation
public enum SettingsTab: Hashable, Sendable {
    case prompts
    case apiKeys
    case shortcuts
    case about
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Static reference for access from views (NSApp.delegate is SwiftUI's wrapper)
    public static var shared: AppDelegate?

    /// Shared application state accessible throughout the app
    public let appState = AppState()

    /// Global hotkey monitoring service
    private var hotkeyService: HotkeyService?

    /// Floating panel for prompt popup
    private var floatingPanel: FloatingPanelController?

    /// Settings window (retained to keep it alive)
    private var settingsWindow: NSWindow?

    /// Tip Jar window (retained to keep it alive)
    private var tipJarWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Log.general.info("Application did finish launching")
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
            Log.general.info("No API keys configured — opening settings on API Keys tab")
            // Small delay to let the menu bar finish initializing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings(tab: .apiKeys)
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        Log.general.info("Application will terminate")
        hotkeyService?.stopMonitoring()
    }

    // MARK: - Settings Window

    /// Opens the settings window on a specific tab, creating it if necessary.
    public func openSettings(tab: SettingsTab? = nil) {
        Log.ui.info("openSettings called with tab: \(String(describing: tab))")
        if let tab {
            appState.selectedSettingsTab = tab
        }

        if let window = settingsWindow, window.isVisible {
            Log.ui.debug("Settings window already visible, bringing to front")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        Log.ui.debug("Creating new settings window")
        let settingsView = SettingsView()
            .environment(appState)

        Log.ui.debug("Creating NSHostingView for settings")
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 565),
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
    public func openTipJar() {
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

    /// Initializes and starts global hotkey monitoring using KeyboardShortcuts.
    /// No Accessibility permission is required — Carbon hotkeys work in sandbox.
    private func setupHotkeyService() {
        hotkeyService = HotkeyService()
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

    // MARK: - Shortcut Handlers

    private func handleTextShortcut() {
        guard appState.hasAPIKeys else {
            showNoAPIKeysAlert()
            return
        }

        Task { @MainActor in
            // Simulate Cmd+C to copy selected text from the frontmost app
            let text = await PasteboardService.copySelectedText()

            if let text, !text.isEmpty {
                appState.capturedText = text
            } else {
                // Show the popup anyway so the user gets visual feedback
                // that the shortcut worked, even if no text was selected.
                Log.hotkey.debug("No text captured — showing prompt popup with empty state")
                appState.capturedText = nil
                appState.lastError = "No text was captured. Select text in another app and try again."
            }

            appState.capturedImage = nil
            showPromptPopup()
        }
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
                Log.capture.debug("Screenshot capture cancelled by user")
            } catch {
                Log.capture.error("Screenshot capture failed: \(error.localizedDescription)")
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
public final class AppState {
    public var capturedText: String?
    public var capturedImage: Data?
    public var aiResponse: String?
    public var isLoading = false
    public var lastError: String?
    public var showingResult = false

    /// Whether the user pinned the popup so it stays open when focus moves elsewhere
    public var isPopupPinned = false

    /// Currently selected tab in the Settings window
    public var selectedSettingsTab: SettingsTab = .prompts

    /// Settings loaded from persistence
    public var settings: AppSettings

    /// Whether at least one API key is configured
    public var hasAPIKeys: Bool { !settings.apiKeyEntries.isEmpty }

    /// Available AI models fetched from providers
    public var availableModels: [AIModel] = []

    /// Providers whose models list failed to load during the last fetch
    public var failedProviders: Set<AIProvider> = []

    private let settingsService = SettingsService()

    public init() {
        var loadedSettings = SettingsService().loadSettings()
        loadedSettings.migrateLegacyModelSelection()
        self.settings = loadedSettings
    }

    public func saveSettings() {
        do {
            try settingsService.saveSettings(settings)
        } catch {
            Log.settings.error("Failed to save settings: \(error.localizedDescription)")
            lastError = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    /// Whether models are currently being loaded
    public var isLoadingModels = false

    /// Fetches models from all configured providers.
    /// Uses a single keychain read to avoid multiple password prompts.
    public func loadModels() async {
        isLoadingModels = true

        // Read all API keys in a single keychain access (one password prompt)
        let cachedKeys = KeychainService.readAllKeys()

        let configuredProviders = Set(settings.apiKeyEntries.map(\.provider))
        var allModels: [AIModel] = []
        var failed: Set<AIProvider> = []

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
                failed.insert(provider)
                Log.ai.error("Failed to fetch models for \(provider.rawValue): \(error.localizedDescription)")
            }
        }

        availableModels = allModels.sorted { $0.name < $1.name }
        failedProviders = failed
        isLoadingModels = false

        syncPromptModels()
    }

    /// Resolves whether a prompt's model can currently be used.
    public func availability(of model: AIModel?) -> ModelAvailability {
        guard let model else { return .notSelected }
        if isLoadingModels { return .loading }
        if !settings.apiKeyEntries.contains(where: { $0.provider == model.provider })
            || failedProviders.contains(model.provider)
        {
            return .providerLoadFailed
        }
        return fetchedModel(matching: model) == nil ? .outdated : .available
    }

    // MARK: - Private

    private func fetchedModel(matching model: AIModel) -> AIModel? {
        availableModels.first { $0.id == model.id && $0.provider == model.provider }
    }

    /// Assigns the first available model to prompts without one and refreshes
    /// display names of known models. Outdated models are never replaced silently.
    private func syncPromptModels() {
        let defaultModel = availableModels.first
        var updatedPrompts = settings.prompts

        for index in updatedPrompts.indices {
            if let model = updatedPrompts[index].model {
                updatedPrompts[index].model = fetchedModel(matching: model) ?? model
            } else {
                updatedPrompts[index].model = defaultModel
            }
        }

        guard updatedPrompts != settings.prompts else { return }
        settings.prompts = updatedPrompts
        saveSettings()
    }
}
