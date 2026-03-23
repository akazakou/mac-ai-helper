# Mac AI Helper

A native macOS menu bar utility that captures selected text or screenshots via global keyboard shortcuts, presents a popup with predefined AI prompts, sends the content to a configured AI provider, and displays the response with copy functionality.

## Features

- **Menu Bar Only** — Lives exclusively in the macOS menu bar (no Dock icon)
- **Global Shortcuts** — Trigger from any application (sandbox-compatible via Carbon hotkeys)
  - `⇧⌘C` (`Cmd+Shift+C`) — Capture selected text and show prompt popup
  - `⌃⌘C` (`Ctrl+Cmd+C`) — Capture a screenshot region and show prompt popup
- **Multiple AI Providers** — Supports OpenAI, Anthropic (Claude), and Google Gemini
- **Dynamic Model Listing** — Fetches available models from each provider's API
- **Custom Prompts** — Configure unlimited AI prompt templates
- **Secure Key Storage** — API keys stored in macOS Keychain
- **Native UI** — Built with SwiftUI, uses floating panels for the popup
- **Tip Jar** — Optional in-app purchases to support development (StoreKit 2)
- **App Sandbox** — Fully sandboxed for Mac App Store distribution

## Requirements

- macOS 14+ (Sonoma) — Apple Silicon and Intel
- Swift 6.0+
- Xcode 16+ (for building)

## Building

```bash
# Build the project (debug, current architecture)
swift build

# Run directly
swift run MacAIHelper

# Build Universal .app bundle (arm64 + x86_64)
make app

# Full release pipeline: build → sign → .pkg + .dmg
make release

# See all available targets
make help
```

## Release & Packaging

The project uses a `Makefile` to automate building, signing, and packaging.

### Build Targets

**Development (ad-hoc signed):**

| Target         | Description                                            |
| -------------- | ------------------------------------------------------ |
| `make app`     | Build Universal Binary .app bundle (ad-hoc signed)     |
| `make release` | Full ad-hoc pipeline: clean → build → sign → pkg + dmg |

**Developer ID Distribution (outside App Store):**

| Target                | Description                                                         |
| --------------------- | ------------------------------------------------------------------- |
| `make release-signed` | Full pipeline: clean → build → sign → notarize → staple → pkg + dmg |
| `make sign`           | Code sign the .app bundle                                           |
| `make notarize`       | Submit .app to Apple for notarization                               |
| `make pkg`            | Create .pkg installer (signed if identity provided)                 |
| `make dmg`            | Create .dmg disk image                                              |

**Mac App Store Distribution:**

| Target                  | Description                                    |
| ----------------------- | ---------------------------------------------- |
| `make appstore`         | Full pipeline: clean → icon → archive → upload |
| `make appstore-icon`    | Generate 1024×1024 App Store icon PNG from SVG |
| `make appstore-archive` | Create Xcode archive for App Store submission  |
| `make appstore-upload`  | Export archive and upload to App Store Connect |

**Utilities:**

| Target                   | Description                                |
| ------------------------ | ------------------------------------------ |
| `make build-arm64`       | Build release for Apple Silicon only       |
| `make build-x86_64`      | Build release for Intel only               |
| `make universal-binary`  | Create Universal Binary via lipo           |
| `make icon`              | Generate AppIcon.icns from SVG             |
| `make check-identity`    | Verify signing identities are in keychain  |
| `make store-credentials` | Store notarization credentials in keychain |
| `make clean`             | Remove all build artifacts                 |

### Ad-hoc Build (Local Testing)

```bash
# Build with ad-hoc signing (no Apple Developer account needed)
make release

# Override version
make release APP_VERSION=2.0.0
```

### Mac App Store Submission

**Prerequisites:**

1. An [Apple Developer Program](https://developer.apple.com/programs/) membership
2. **Mac App Distribution** + **Mac Installer Distribution** certificates
3. App ID registered with bundle ID `com.castloud.MacAIHelper`
4. App Store provisioning profile
5. App listing created in [App Store Connect](https://appstoreconnect.apple.com)

**Update Team ID in ExportOptions.plist:**

Edit `SupportFiles/ExportOptions.plist` and replace `REPLACE_WITH_YOUR_TEAM_ID` with your actual Team ID.

**Submit to App Store:**

```bash
make appstore
```

**Test StoreKit locally:**

The project includes a StoreKit configuration file at `SupportFiles/StoreKitConfiguration.storekit` for local testing of in-app purchases without needing App Store Connect sandbox.

### Apple Developer Build (Direct Distribution)

For distributing outside the App Store with full Gatekeeper trust:

**One-time setup — store notarization credentials in keychain:**

```bash
make store-credentials APPLE_ID="you@example.com" TEAM_ID="XXXXXXXXXX"
```

**Full signed + notarized release:**

```bash
make release-signed \
  SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Your Name (TEAMID)" \
  APPLE_ID="you@example.com" \
  TEAM_ID="XXXXXXXXXX" \
  APP_PASSWORD="@keychain:notarytool"
```

### Output Artifacts

After `make release` or `make release-signed`, the following are produced in `build/`:

- `build/release/MacAIHelper.app` — Signed Universal Binary application
- `build/MacAIHelper-X.Y.Z.pkg` — macOS installer package (installs to /Applications)
- `build/MacAIHelper-X.Y.Z.dmg` — Disk image with drag-to-install

## Setup

1. **Launch the app** — It will appear as an icon in the menu bar
2. **Add API keys** — Open Settings (click menu bar icon → Settings) → API Keys tab → Add keys for your preferred providers
3. **Configure prompts** — Settings → Prompts tab to add, edit, or reorder prompts
4. **Start using** — Select text in any app, press `⇧⌘C`, pick a prompt, and get AI responses!

## Architecture

```
Sources/MacAIHelper/
├── App/                    # App entry point, delegate, floating panel
├── Models/                 # Data models (AIProvider, Prompt, AppSettings, etc.)
├── Services/               # Business logic (AI APIs, Keychain, Hotkeys, etc.)
├── ViewModels/             # Observable state management
├── Views/                  # SwiftUI views (Settings, Popup, Result)
└── Resources/              # Menu bar icon
```

### Key Components

- **HotkeyService** — Global shortcuts via KeyboardShortcuts (Carbon RegisterEventHotKey)
- **AIServiceRouter** — Routes requests to OpenAI, Anthropic, or Gemini
- **KeychainService** — Secure API key storage
- **FloatingPanelController** — NSPanel-based floating popup window
- **ScreenCaptureService** — Interactive screen region capture via ScreenCaptureKit
- **TipJarService** — StoreKit 2 consumable in-app purchases

## Permissions

The app requires one macOS permission:

- **Screen Recording** — For capturing screenshot regions (only needed for the screenshot feature)

Note: Global keyboard shortcuts use Carbon APIs and do **not** require Accessibility permission.

## Privacy

Privacy policy: [www.castloud.com/privacy.html](https://www.castloud.com/privacy.html)

- No data collected or transmitted to Castloud servers
- API keys stored locally in macOS Keychain
- Content sent directly to user-configured AI providers
- No analytics or tracking

## License

Private project. © 2026 Castloud.
