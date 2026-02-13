// AppDelegate.swift
// Manages app lifecycle, initializes services, and handles hotkey callbacks.

import AppKit
import SwiftUI

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Ensure the app doesn't appear in the Dock
        NSApp.setActivationPolicy(.accessory)

        setupHotkeyService()

        // Load AI models at startup so the popup opens instantly
        Task {
            await appState.loadModels()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.stopMonitoring()
    }

    // MARK: - Settings Window

    /// Opens the settings window, creating it if necessary.
    func openSettings() {
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

        // Temporarily become a regular app so the window can appear and receive focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hotkey Service Setup

    private func setupHotkeyService() {
        guard HotkeyService.checkAccessibilityPermission() else {
            HotkeyService.requestAccessibilityPermission()
            // Retry after a delay — user may grant permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.setupHotkeyService()
            }
            return
        }

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
        let text = PasteboardService.readText()
        guard let text, !text.isEmpty else { return }

        appState.capturedText = text
        appState.capturedImage = nil
        showPromptPopup()
    }

    private func handleScreenshotShortcut() {
        Task {
            do {
                let imageData = try await ScreenCaptureService.captureRegion()
                appState.capturedImage = imageData
                appState.capturedText = nil
                showPromptPopup()
            } catch {
                print("⚠️ Screenshot capture failed: \(error)")
                appState.lastError = error.localizedDescription
            }
        }
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

    /// Settings loaded from persistence
    var settings: AppSettings

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
