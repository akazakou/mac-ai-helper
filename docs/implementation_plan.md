# Implementation Plan

[Overview]
Build a native macOS menu bar utility app called "Mac AI Helper" that captures selected text or screenshots via global keyboard shortcuts, presents a popup with predefined AI prompts, sends the content to a configured AI provider, and displays the response with copy functionality.

The app lives exclusively in the macOS menu bar (no Dock icon) and is built entirely with Swift 6 and SwiftUI, targeting macOS 14+ (Sonoma). It supports three AI providers — OpenAI, Anthropic (Claude), and Google Gemini — with dynamic model listing from each provider's API. Users can configure an unlimited number of custom prompts, manage API keys securely via Keychain, and customize keyboard shortcuts.

The primary workflow is:

1. User selects text in any application
2. User presses CMD+C+C (hold CMD, press C twice) — the selected text is copied to the clipboard
3. A floating popup appears showing a model selector and a list of predefined prompts
4. User clicks a prompt — the app sends the clipboard text + prompt to the selected AI model
5. A result window appears with the AI response and a Copy button

A secondary workflow uses CMD+Shift+C to capture a screenshot region and follows the same prompt → AI → result flow, but with an image instead of text.

The app requires macOS Accessibility permission for global hotkey monitoring and Screen Recording permission for screenshot capture.

[Types]
Define all data models, enums, and protocols that form the type system for the application.

### AIProvider Enum

```swift
// File: Sources/MacAIHelper/Models/AIProvider.swift
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Google Gemini"

    var id: String { rawValue }

    var baseURL: URL {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        }
    }

    var modelsEndpoint: String {
        switch self {
        case .openAI: "/models"
        case .anthropic: "/models"
        case .gemini: "/models"
        }
    }

    var helpURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")!
        }
    }
}
```

### AIModel Struct

```swift
// File: Sources/MacAIHelper/Models/AIModel.swift
struct AIModel: Identifiable, Codable, Hashable {
    let id: String        // e.g. "gpt-4o", "claude-sonnet-4-5", "gemini-2.5-pro"
    let name: String      // Display name
    let provider: AIProvider
}
```

### Prompt Struct

```swift
// File: Sources/MacAIHelper/Models/Prompt.swift
struct Prompt: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String     // Display text, e.g. "Translate text to English"
    var template: String  // Full prompt template with {text} placeholder
    var icon: String      // SF Symbol name

    init(id: UUID = UUID(), title: String, template: String, icon: String = "text.bubble") {
        self.id = id
        self.title = title
        self.template = template
        self.icon = icon
    }
}
```

### APIKeyEntry Struct

```swift
// File: Sources/MacAIHelper/Models/APIKeyEntry.swift
struct APIKeyEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let provider: AIProvider
    var label: String     // User-friendly label

    init(id: UUID = UUID(), provider: AIProvider, label: String = "") {
        self.id = id
        self.provider = provider
        self.label = label.isEmpty ? provider.rawValue : label
    }
}
```

### ShortcutDefinition Struct

```swift
// File: Sources/MacAIHelper/Models/ShortcutDefinition.swift
struct ShortcutDefinition: Codable, Hashable {
    var keyCode: UInt16           // CGKeyCode value
    var modifierFlags: UInt64     // CGEventFlags raw value
    var doubleTap: Bool           // Whether it requires double-press
    var displayName: String       // Human-readable, e.g. "⌘C+C"
}
```

### AppSettings Struct

```swift
// File: Sources/MacAIHelper/Models/AppSettings.swift
struct AppSettings: Codable {
    var prompts: [Prompt]
    var apiKeyEntries: [APIKeyEntry]       // Metadata only — actual keys in Keychain
    var selectedModelId: String?
    var selectedProvider: AIProvider?
    var promptShortcut: ShortcutDefinition
    var screenshotShortcut: ShortcutDefinition

    static var defaultSettings: AppSettings {
        AppSettings(
            prompts: [
                Prompt(title: "Translate text to the English language",
                       template: "Translate the following text to English:\n\n{text}",
                       icon: "globe"),
                Prompt(title: "Rewrite text informal but professional way in the Email style",
                       template: "Rewrite the following text in an informal but professional email style:\n\n{text}",
                       icon: "envelope"),
                Prompt(title: "Act like professional IT expert. I need to solve that issue",
                       template: "You are a professional IT expert. Help me solve this issue:\n\n{text}",
                       icon: "desktopcomputer"),
            ],
            apiKeyEntries: [],
            selectedModelId: nil,
            selectedProvider: nil,
            promptShortcut: ShortcutDefinition(
                keyCode: 8,               // C key
                modifierFlags: CGEventFlags.maskCommand.rawValue,
                doubleTap: true,
                displayName: "⌘C + C"
            ),
            screenshotShortcut: ShortcutDefinition(
                keyCode: 8,               // C key
                modifierFlags: (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue),
                doubleTap: false,
                displayName: "⇧⌘C"
            )
        )
    }
}
```

### AIServiceProtocol

```swift
// File: Sources/MacAIHelper/Services/AIServiceProtocol.swift
protocol AIServiceProtocol: Sendable {
    var provider: AIProvider { get }
    func fetchModels(apiKey: String) async throws -> [AIModel]
    func sendPrompt(_ prompt: String, model: String, apiKey: String) async throws -> String
    func sendPromptWithImage(_ prompt: String, imageData: Data, model: String, apiKey: String) async throws -> String
}
```

### Custom Errors

```swift
// File: Sources/MacAIHelper/Models/AppError.swift
enum AppError: LocalizedError {
    case noAPIKey(AIProvider)
    case noModelSelected
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case decodingError(String)
    case keychainError(String)
    case accessibilityPermissionDenied
    case screenCapturePermissionDenied

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider): "No API key configured for \(provider.rawValue)"
        case .noModelSelected: "No AI model selected"
        case .networkError(let msg): "Network error: \(msg)"
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        case .decodingError(let msg): "Failed to decode response: \(msg)"
        case .keychainError(let msg): "Keychain error: \(msg)"
        case .accessibilityPermissionDenied: "Accessibility permission is required for global shortcuts"
        case .screenCapturePermissionDenied: "Screen recording permission is required for screenshots"
        }
    }
}
```

[Files]
All files to be created in this greenfield project.

### New Files

**Project Configuration:**

- `Package.swift` — Swift Package Manager manifest, macOS 14+ target, no external dependencies

**App Entry:**

- `Sources/MacAIHelper/App/MacAIHelperApp.swift` — SwiftUI App entry point with MenuBarExtra, window management
- `Sources/MacAIHelper/App/AppDelegate.swift` — NSApplicationDelegate for hotkey service lifecycle, accessibility permission check

**Models (7 files):**

- `Sources/MacAIHelper/Models/AIProvider.swift` — AIProvider enum
- `Sources/MacAIHelper/Models/AIModel.swift` — AIModel struct
- `Sources/MacAIHelper/Models/Prompt.swift` — Prompt struct
- `Sources/MacAIHelper/Models/APIKeyEntry.swift` — APIKeyEntry struct
- `Sources/MacAIHelper/Models/ShortcutDefinition.swift` — ShortcutDefinition struct
- `Sources/MacAIHelper/Models/AppSettings.swift` — AppSettings struct with defaults
- `Sources/MacAIHelper/Models/AppError.swift` — AppError enum

**Services (9 files):**

- `Sources/MacAIHelper/Services/AIServiceProtocol.swift` — Protocol for AI services
- `Sources/MacAIHelper/Services/OpenAIService.swift` — OpenAI API: chat completions + model listing
- `Sources/MacAIHelper/Services/AnthropicService.swift` — Anthropic API: messages + model listing
- `Sources/MacAIHelper/Services/GeminiService.swift` — Gemini API: generateContent + model listing
- `Sources/MacAIHelper/Services/AIServiceRouter.swift` — Routes requests to correct provider service
- `Sources/MacAIHelper/Services/HotkeyService.swift` — CGEvent tap for global shortcut detection
- `Sources/MacAIHelper/Services/PasteboardService.swift` — NSPasteboard read/write wrapper
- `Sources/MacAIHelper/Services/ScreenCaptureService.swift` — ScreenCaptureKit region capture
- `Sources/MacAIHelper/Services/KeychainService.swift` — Keychain CRUD for API keys
- `Sources/MacAIHelper/Services/SettingsService.swift` — JSON-file persistence for AppSettings

**ViewModels (3 files):**

- `Sources/MacAIHelper/ViewModels/PromptPopupViewModel.swift` — Manages prompt selection, model picker state, triggers AI call
- `Sources/MacAIHelper/ViewModels/ResultViewModel.swift` — Manages AI response display, copy action
- `Sources/MacAIHelper/ViewModels/SettingsViewModel.swift` — Manages all settings CRUD operations

**Views (8 files):**

- `Sources/MacAIHelper/Views/MenuBarView.swift` — MenuBarExtra content: open settings, quit
- `Sources/MacAIHelper/Views/PromptPopupView.swift` — Floating panel: model dropdown + prompt list
- `Sources/MacAIHelper/Views/ResultView.swift` — Response display with copy button
- `Sources/MacAIHelper/Views/SettingsView.swift` — TabView container for settings
- `Sources/MacAIHelper/Views/PromptsSettingsView.swift` — Prompts CRUD list with shortcut config
- `Sources/MacAIHelper/Views/APIKeysSettingsView.swift` — API keys list with delete
- `Sources/MacAIHelper/Views/APIKeyAddView.swift` — Sheet dialog: provider dropdown + key input
- `Sources/MacAIHelper/Views/ShortcutSettingsView.swift` — Shortcut recorder/display for both shortcuts

**Resources:**

- `Sources/MacAIHelper/Resources/Info.plist` — App metadata, LSUIElement=true (no dock icon), privacy descriptions
- `Sources/MacAIHelper/Resources/MacAIHelper.entitlements` — App Sandbox disabled (needed for CGEvent tap), Keychain access

**Tests (5 files):**

- `Tests/MacAIHelperTests/Services/KeychainServiceTests.swift`
- `Tests/MacAIHelperTests/Services/OpenAIServiceTests.swift`
- `Tests/MacAIHelperTests/Services/AnthropicServiceTests.swift`
- `Tests/MacAIHelperTests/Services/GeminiServiceTests.swift`
- `Tests/MacAIHelperTests/ViewModels/SettingsViewModelTests.swift`

**Other:**

- `.gitignore` — Swift/Xcode gitignore
- `README.md` — Project description and setup instructions

[Functions]
All functions are new since this is a greenfield project. Key functions organized by service.

### HotkeyService

- `startMonitoring()` — Creates CGEvent tap, registers for keyDown and flagsChanged events, adds to run loop. Called from AppDelegate on app launch.
- `stopMonitoring()` — Disables and removes event tap from run loop.
- `handleEvent(proxy:type:event:userInfo:) -> Unmanaged<CGEvent>?` — Static C callback for CGEvent tap. Extracts keyCode and modifier flags, delegates to instance method.
- `processKeyEvent(keyCode:flags:)` — Tracks consecutive key presses within time window. For double-tap shortcuts (CMD+C+C): increments tap counter on C press while CMD held, fires callback on second tap within 0.5s. For single shortcuts (CMD+Shift+C): fires immediately on match.
- `checkAccessibilityPermission() -> Bool` — Calls `AXIsProcessTrusted()` to check if accessibility permission is granted. Returns Bool.
- `requestAccessibilityPermission()` — Opens System Settings accessibility pane using `AXIsProcessTrustedWithOptions`.

### PasteboardService

- `copyTextFromSelection()` — Synthesizes CMD+C keypress via CGEvent to copy current selection, then reads from NSPasteboard after brief delay.
- `readText() -> String?` — Reads string from NSPasteboard.generalPasteboard.
- `writeText(_ text: String)` — Writes string to NSPasteboard.generalPasteboard.
- `readImage() -> Data?` — Reads image data (PNG) from NSPasteboard.

### ScreenCaptureService

- `captureRegion() async throws -> Data` — Uses ScreenCaptureKit to initiate interactive region capture. Returns PNG image data. Throws on permission denied or user cancel.
- `checkPermission() -> Bool` — Checks screen recording permission status.

### KeychainService

- `saveKey(_ key: String, for entryId: UUID) throws` — Stores API key string in Keychain with entry UUID as account identifier.
- `readKey(for entryId: UUID) throws -> String?` — Retrieves API key from Keychain by entry UUID.
- `deleteKey(for entryId: UUID) throws` — Removes API key from Keychain by entry UUID.
- `updateKey(_ key: String, for entryId: UUID) throws` — Updates existing Keychain entry.

### SettingsService

- `loadSettings() -> AppSettings` — Reads AppSettings from JSON file in Application Support directory. Returns defaults if file not found.
- `saveSettings(_ settings: AppSettings) throws` — Writes AppSettings to JSON file.
- `settingsFileURL() -> URL` — Returns the path to the settings JSON file.

### OpenAIService (implements AIServiceProtocol)

- `fetchModels(apiKey:) async throws -> [AIModel]` — GET `https://api.openai.com/v1/models`, headers: `Authorization: Bearer {key}`. Parses response `data` array, filters to chat-capable models (ids containing "gpt" or "o1" or "o3"), maps to `[AIModel]`.
- `sendPrompt(_:model:apiKey:) async throws -> String` — POST `https://api.openai.com/v1/chat/completions`, body: `{"model": model, "messages": [{"role":"user","content": prompt}]}`. Returns `choices[0].message.content`.
- `sendPromptWithImage(_:imageData:model:apiKey:) async throws -> String` — Same endpoint but with multimodal content: `[{"type":"text","text":prompt},{"type":"image_url","image_url":{"url":"data:image/png;base64,..."}}]`.

### AnthropicService (implements AIServiceProtocol)

- `fetchModels(apiKey:) async throws -> [AIModel]` — GET `https://api.anthropic.com/v1/models`, headers: `x-api-key: {key}`, `anthropic-version: 2023-06-01`. Parses `data` array, maps to `[AIModel]`.
- `sendPrompt(_:model:apiKey:) async throws -> String` — POST `https://api.anthropic.com/v1/messages`, headers: same. Body: `{"model": model, "max_tokens": 4096, "messages": [{"role":"user","content": prompt}]}`. Returns `content[0].text`.
- `sendPromptWithImage(_:imageData:model:apiKey:) async throws -> String` — Same endpoint with content: `[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"..."}},{"type":"text","text":prompt}]`.

### GeminiService (implements AIServiceProtocol)

- `fetchModels(apiKey:) async throws -> [AIModel]` — GET `https://generativelanguage.googleapis.com/v1beta/models?key={key}`. Parses `models` array, filters to those supporting "generateContent", maps to `[AIModel]` using `name` field (strips "models/" prefix).
- `sendPrompt(_:model:apiKey:) async throws -> String` — POST `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}`, body: `{"contents":[{"parts":[{"text":prompt}]}]}`. Returns `candidates[0].content.parts[0].text`.
- `sendPromptWithImage(_:imageData:model:apiKey:) async throws -> String` — Same endpoint with parts: `[{"inline_data":{"mime_type":"image/png","data":"..."}},{"text":prompt}]`.

### AIServiceRouter

- `service(for provider: AIProvider) -> AIServiceProtocol` — Returns the correct service instance for a given provider.
- `fetchModels(provider:apiKey:) async throws -> [AIModel]` — Delegates to correct service.
- `sendPrompt(_:model:provider:apiKey:) async throws -> String` — Delegates to correct service.
- `sendPromptWithImage(_:imageData:model:provider:apiKey:) async throws -> String` — Delegates to correct service.

### PromptPopupViewModel

- `loadModels() async` — Fetches models from all providers that have API keys configured. Populates model list for dropdown.
- `selectPrompt(_ prompt: Prompt) async` — Takes clipboard content, applies prompt template (replaces `{text}` with clipboard text), calls AI service, navigates to result view.
- `selectPromptWithImage(_ prompt: Prompt, imageData: Data) async` — Same but for screenshot workflow.

### ResultViewModel

- `copyResponse()` — Copies AI response text to clipboard via PasteboardService.

### SettingsViewModel

- `addPrompt(title:template:icon:)` — Creates new Prompt, appends to settings, saves.
- `updatePrompt(_ prompt: Prompt)` — Updates existing prompt in settings, saves.
- `deletePrompt(at offsets: IndexSet)` — Removes prompt from settings, saves.
- `movePrompt(from:to:)` — Reorders prompts, saves.
- `addAPIKey(provider:key:label:) throws` — Creates APIKeyEntry, saves key to Keychain, appends entry to settings.
- `deleteAPIKey(_ entry: APIKeyEntry) throws` — Removes from Keychain and settings.
- `updateShortcut(type:definition:)` — Updates prompt or screenshot shortcut definition in settings.
- `fetchModelsForProvider(_ provider: AIProvider) async throws -> [AIModel]` — Fetches models to show in settings for validation.

[Classes]
This project uses structs and enums primarily, with minimal class usage required by macOS APIs.

### Classes

- **`AppDelegate: NSObject, NSApplicationDelegate`** — File: `Sources/MacAIHelper/App/AppDelegate.swift`. Manages app lifecycle. In `applicationDidFinishLaunching`: initializes HotkeyService, checks accessibility permission. Holds references to HotkeyService and window controllers. Provides callbacks from HotkeyService to trigger popup display.

- **`HotkeyService: NSObject`** (must be a class for `Unmanaged` pointer in CGEvent callback) — File: `Sources/MacAIHelper/Services/HotkeyService.swift`. Maintains CGEvent tap state, tap counter, timing, and run loop source references. Properties: `eventTap: CFMachPort?`, `runLoopSource: CFRunLoopSource?`, `tapCount: Int`, `lastTapTime: TimeInterval`, `onTextShortcut: (() -> Void)?`, `onScreenshotShortcut: (() -> Void)?`.

- **`ScreenCaptureService`** — File: `Sources/MacAIHelper/Services/ScreenCaptureService.swift`. Wraps ScreenCaptureKit APIs. May need to be a class if holding SCStream references.

- **`FloatingPanelController: NSWindowController`** — Inline in `Sources/MacAIHelper/App/MacAIHelperApp.swift` or separate file. Creates and manages the NSPanel (floating, non-activating) that hosts PromptPopupView and ResultView. Key behaviors: appears above all windows, dismisses on focus loss, positions near cursor or center screen.

### ViewModels (using @Observable macro)

All ViewModels use the `@Observable` macro (Swift 5.9+/macOS 14+) instead of being classes with ObservableObject:

- `PromptPopupViewModel` — @Observable class
- `ResultViewModel` — @Observable class
- `SettingsViewModel` — @Observable class

[Dependencies]
No third-party dependencies. The app uses only Apple frameworks.

### Frameworks Used

- **SwiftUI** — All UI views and layout
- **AppKit** — NSPanel for floating window, NSPasteboard, NSApplication delegate, menu bar integration
- **Security** — Keychain Services API (SecItemAdd, SecItemCopyMatching, SecItemUpdate, SecItemDelete)
- **CoreGraphics** — CGEvent tap creation and event processing for global shortcuts
- **Carbon** — Key code constants (kVK_ANSI_C = 0x08)
- **ScreenCaptureKit** — SCShareableContent, SCStream, SCStreamConfiguration for screenshot capture
- **UniformTypeIdentifiers** — UTType for clipboard type identification

### Package.swift Configuration

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAIHelper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacAIHelper",
            path: "Sources/MacAIHelper",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MacAIHelperTests",
            dependencies: ["MacAIHelper"],
            path: "Tests/MacAIHelperTests"
        )
    ]
)
```

[Testing]
Unit tests focus on service layer logic and ViewModel business logic. UI tests are deferred to a later phase.

### Test Files

**KeychainServiceTests.swift:**

- Test save, read, update, delete cycle for API keys
- Test reading non-existent key returns nil
- Test overwrite behavior

**OpenAIServiceTests.swift:**

- Test model list parsing from mock JSON response
- Test chat completion response parsing
- Test error handling for 401, 429, 500 status codes
- Test image prompt construction

**AnthropicServiceTests.swift:**

- Test model list parsing from mock JSON response
- Test message response parsing (content[0].text extraction)
- Test error handling for various status codes

**GeminiServiceTests.swift:**

- Test model list parsing and "models/" prefix stripping
- Test generateContent response parsing
- Test API key as query parameter (not header)

**SettingsViewModelTests.swift:**

- Test adding/removing/reordering prompts
- Test default settings initialization
- Test settings persistence round-trip (save then load)

### Testing Strategy

- Use `URLProtocol` subclass to mock network requests in service tests
- Use temporary directory for settings file in persistence tests
- Use separate Keychain access group or test-specific service tags to avoid polluting real Keychain

[Implementation Order]
Build the app bottom-up: models first, then services, then ViewModels, then UI, then integration.

1. **Project scaffolding** — Create Package.swift, directory structure, .gitignore, Info.plist, entitlements, and app entry point (MacAIHelperApp.swift with MenuBarExtra skeleton). Verify it builds and shows a menu bar icon.

2. **Data models** — Create all model files: AIProvider, AIModel, Prompt, APIKeyEntry, ShortcutDefinition, AppSettings, AppError. These have no dependencies and are used everywhere.

3. **Persistence services** — Implement KeychainService (CRUD for API keys) and SettingsService (JSON file read/write for AppSettings). These are foundational for all settings UI.

4. **PasteboardService** — Implement clipboard read/write. Simple wrapper around NSPasteboard.

5. **AI provider services** — Implement AIServiceProtocol, then OpenAIService, AnthropicService, GeminiService, and AIServiceRouter. Each service handles model listing and prompt sending for its provider.

6. **HotkeyService** — Implement CGEvent tap for global shortcut detection. This is the core UX trigger. Include accessibility permission checking.

7. **SettingsViewModel + Settings UI** — Build SettingsViewModel and all settings views (SettingsView, PromptsSettingsView, APIKeysSettingsView, APIKeyAddView, ShortcutSettingsView). User needs to configure the app before the main workflow works.

8. **PromptPopupViewModel + Popup UI** — Build the floating panel, PromptPopupView with model dropdown and prompt list, and the ViewModel that handles prompt selection and AI calls.

9. **ResultViewModel + Result UI** — Build ResultView showing AI response with copy button and its ViewModel.

10. **ScreenCaptureService** — Implement screenshot region capture using ScreenCaptureKit. Wire it to the CMD+Shift+C shortcut flow.

11. **AppDelegate + Integration** — Wire everything together: AppDelegate starts HotkeyService, hotkey callbacks trigger popup display, popup triggers AI call, AI response shows in result view.

12. **Tests** — Write unit tests for Keychain, AI services (with mock URLProtocol), and SettingsViewModel.

13. **Polish** — Loading states, error alerts, empty states, README documentation.
