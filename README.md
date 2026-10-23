# Mac AI Helper

A native macOS menu bar utility that captures selected text or screenshots via global keyboard shortcuts, presents a popup with predefined AI prompts, sends the content to a configured AI provider, and displays the response with copy functionality.

## Features

- **Menu Bar Only** — Lives exclusively in the macOS menu bar (no Dock icon)
- **Global Shortcuts** — Trigger from any application (sandbox-compatible via Carbon hotkeys)
  - `⇧⌘C` (`Cmd+Shift+C`) — Capture selected text and show prompt popup
  - `⌃⌘C` (`Ctrl+Cmd+C`) — Capture a screenshot region and show prompt popup
- **Multiple AI Providers** — Supports OpenAI, Anthropic (Claude), Google Gemini, and OpenRouter
- **Dynamic Model Listing** — Fetches available models from each provider's API
- **Per-Prompt Models** — Each prompt uses its own model, picked in the prompt editor; outdated or unreachable models are flagged with badges
- **Custom Prompts** — Configure unlimited AI prompt templates
- **Secure Key Storage** — API keys stored in macOS Keychain
- **Native UI** — Built with SwiftUI, uses floating panels for the popup
- **Tip Jar** — Optional in-app purchases to support development (StoreKit 2)
- **App Sandbox** — Fully sandboxed for Mac App Store distribution
- **Persistent Settings** — Settings, API keys, and prompts persist across App Store updates

## Requirements

- macOS 14+ (Sonoma) — Apple Silicon and Intel
- Swift 6.0+
- Xcode 16+ (for building)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — generates `.xcodeproj` from `project.yml` (`brew install xcodegen`)
- Apple Developer Program membership (for signing and distribution)

## Building

The build system uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate a `.xcodeproj` from `project.yml`, then builds with `xcodebuild`. This ensures SPM dependency resource bundles (e.g. KeyboardShortcuts localizations) are correctly placed inside `Contents/Resources/` in the `.app` bundle.

```bash
# Install build dependency (one-time)
brew install xcodegen

# Build Universal .app bundle (arm64 + x86_64)
make app

# Build, sign with App Store cert, and launch locally for testing
make dev

# Build, sign, and install into /Applications (use this for everyday local use)
make install

# Regenerate .xcodeproj from project.yml (done automatically by make)
make generate-xcodeproj

# See all available targets
make help
```

## Release & Packaging

The project uses a `Makefile` + `xcodebuild` (via XcodeGen) to automate building, signing, and packaging. The `.xcodeproj` is generated from `project.yml` at build time — it is not committed to git. All builds are signed with App Store certificates to ensure consistent sandbox container and Keychain access across builds.

### Build Targets

**Development:**

| Target                   | Description                                                  |
| ------------------------ | ------------------------------------------------------------ |
| `make dev`               | Build, sign with App Store cert, and launch locally          |
| `make install`           | Build, sign, and install into `/Applications`                |
| `make reset-permissions` | Reset stale Accessibility / Screen Recording grants          |
| `make app`               | Build **unsigned** Universal Binary .app (permissions won't work) |

**Mac App Store Distribution:**

| Target                 | Description                                    |
| ---------------------- | ---------------------------------------------- |
| `make appstore`        | Full pipeline: clean → icon → sign → pkg       |
| `make appstore-icon`   | Generate 1024×1024 App Store icon PNG from SVG |
| `make appstore-sign`   | Sign .app with App Store certificate           |
| `make appstore-pkg`    | Create signed .pkg for App Store submission    |
| `make appstore-upload` | Upload .pkg to App Store Connect               |

**Utilities:**

| Target                    | Description                                |
| ------------------------- | ------------------------------------------ |
| `make generate-xcodeproj` | Regenerate `.xcodeproj` from `project.yml` |
| `make icon`               | Generate AppIcon.icns from SVG             |
| `make check-identity`     | Verify signing identities are in keychain  |
| `make store-credentials`  | Store credentials in keychain              |
| `make clean`              | Remove all build artifacts                 |

### Mac App Store Submission

**Prerequisites:**

1. An [Apple Developer Program](https://developer.apple.com/programs/) membership
2. **Mac App Distribution** + **Mac Installer Distribution** certificates
3. App ID registered with bundle ID `com.castloud.MacAIHelper`
4. App Store provisioning profile
5. App listing created in [App Store Connect](https://appstoreconnect.apple.com)

**Submit to App Store:**

```bash
make appstore
```

Then upload via Transporter.app or:

```bash
make appstore-upload APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

**Test StoreKit locally:**

The project includes a StoreKit configuration file at `SupportFiles/StoreKitConfiguration.storekit` for local testing of in-app purchases without needing App Store Connect sandbox.

### Output Artifacts

After `make appstore`, the following are produced in `build/`:

- `build/release/MacAIHelper.app` — Signed Universal Binary application
- `build/MacAIHelper-X.Y.Z-appstore.pkg` — Signed .pkg for App Store submission
- `build/AppStoreIcon.png` — 1024×1024 App Store icon

## Setup

1. **Launch the app** — It will appear as an icon in the menu bar
2. **Add API keys** — Open Settings (click menu bar icon → Settings) → API Keys tab → Add keys for your preferred providers
3. **Configure prompts** — Settings → Prompts tab to add, edit, or reorder prompts
4. **Start using** — Select text in any app, press `⇧⌘C`, pick a prompt, and get AI responses!

## Architecture

```
project.yml                 # XcodeGen project spec (generates .xcodeproj)
Package.swift               # SPM package manifest (dependency declarations)
Makefile                    # Build, sign, and package automation
Sources/MacAIHelper/
├── App/                    # App entry point (@main)
Sources/MacAIHelperLib/
├── App/                    # AppDelegate, FloatingPanelController, AppState
├── Models/                 # Data models (AIProvider, Prompt, AppSettings, etc.)
├── Services/               # Business logic (AI APIs, Keychain, Hotkeys, etc.)
├── ViewModels/             # Observable state management
└── Views/                  # SwiftUI views (Settings, Popup, Result)
```

### Key Components

- **HotkeyService** — Global shortcuts via KeyboardShortcuts (Carbon RegisterEventHotKey)
- **AIServiceRouter** — Routes requests to OpenAI, Anthropic, Gemini, or OpenRouter
- **KeychainService** — Secure API key storage in macOS Keychain
- **SettingsService** — JSON-based settings persistence in Application Support
- **FloatingPanelController** — NSPanel-based floating popup window
- **ScreenCaptureService** — Interactive screen region capture via ScreenCaptureKit
- **TipJarService** — StoreKit 2 consumable in-app purchases

### Data Persistence

- **Settings** (`settings.json`) — Stored in the sandboxed Application Support directory. Persists across App Store updates because the sandbox container is tied to the bundle ID and team signing identity.
- **API Keys** — Stored in macOS Keychain, scoped to the app's code signing identity. Persists across updates as long as builds are signed with the same team certificate.
- **Keyboard Shortcuts** — Managed by the KeyboardShortcuts framework via UserDefaults.

## Permissions

The app requires two macOS permissions:

- **Accessibility** — To simulate `⌘C` and copy the selected text (text prompt shortcut)
- **Screen Recording** — For capturing screenshot regions (screenshot shortcut)

Global keyboard shortcuts themselves use Carbon APIs and need no permission.

### Local builds and permissions

macOS binds privacy permissions to the app's **code signature**. An unsigned build
(`make app`) never matches a granted permission, even though System Settings shows
the toggle as enabled. For local use always run `make install`, which signs the app
with the same certificate on every build so grants survive rebuilds.

If permissions still show as missing after installing (e.g. they were granted to a
differently signed build), reset them and grant again:

```bash
make reset-permissions
```

Screen Recording usually requires relaunching the app after it is granted.

## Privacy

Privacy policy: [www.castloud.com/privacy.html](https://www.castloud.com/privacy.html)

- No data collected or transmitted to Castloud servers
- API keys stored locally in macOS Keychain
- Content sent directly to user-configured AI providers
- No analytics or tracking

## License

Private project. © 2026 Castloud.
