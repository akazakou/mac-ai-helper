# Mac AI Helper

A native macOS menu bar utility that captures selected text or screenshots via global keyboard shortcuts, presents a popup with predefined AI prompts, sends the content to a configured AI provider, and displays the response with copy functionality.

## Features

- **Menu Bar Only** — Lives exclusively in the macOS menu bar (no Dock icon)
- **Global Shortcuts** — Trigger from any application
  - `⌘C + C` (hold CMD, press C twice) — Capture selected text and show prompt popup
  - `⇧⌘C` — Capture a screenshot region and show prompt popup
- **Multiple AI Providers** — Supports OpenAI, Anthropic (Claude), and Google Gemini
- **Dynamic Model Listing** — Fetches available models from each provider's API
- **Custom Prompts** — Configure unlimited AI prompt templates
- **Secure Key Storage** — API keys stored in macOS Keychain
- **Native UI** — Built with SwiftUI, uses floating panels for the popup

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

The project uses a `Makefile` to automate building, signing, and packaging for distribution outside the App Store.

### Build Targets

**Development (ad-hoc signed):**

| Target         | Description                                            |
| -------------- | ------------------------------------------------------ |
| `make app`     | Build Universal Binary .app bundle (ad-hoc signed)     |
| `make release` | Full ad-hoc pipeline: clean → build → sign → pkg + dmg |

**Distribution (Apple Developer signed):**

| Target                | Description                                                         |
| --------------------- | ------------------------------------------------------------------- |
| `make release-signed` | Full pipeline: clean → build → sign → notarize → staple → pkg + dmg |
| `make sign`           | Code sign the .app bundle                                           |
| `make notarize`       | Submit .app to Apple for notarization                               |
| `make notarize-dmg`   | Submit .dmg to Apple for notarization                               |
| `make staple`         | Staple notarization ticket to .app                                  |
| `make staple-dmg`     | Staple notarization ticket to .dmg                                  |
| `make pkg`            | Create .pkg installer (signed if identity provided)                 |
| `make dmg`            | Create .dmg disk image                                              |

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

### Apple Developer Build (Distribution)

For distributing outside the App Store with full Gatekeeper trust, you need an [Apple Developer account](https://developer.apple.com) ($99/year).

**Prerequisites:**

1. A **Developer ID Application** certificate installed in your keychain
2. A **Developer ID Installer** certificate installed in your keychain
3. An [app-specific password](https://appleid.apple.com) for notarization

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

**Check available signing identities:**

```bash
make check-identity
```

### Output Artifacts

After `make release` or `make release-signed`, the following are produced in `build/`:

- `build/release/MacAIHelper.app` — Signed Universal Binary application
- `build/MacAIHelper-X.Y.Z.pkg` — macOS installer package (installs to /Applications)
- `build/MacAIHelper-X.Y.Z.dmg` — Disk image with drag-to-install

With `make release-signed`, all artifacts are Developer ID signed, Apple notarized, and have stapled tickets — ready for download distribution.

## Setup

1. **Launch the app** — It will appear as an icon in the menu bar
2. **Grant Accessibility permission** — Required for global keyboard shortcuts. The app will prompt you on first launch.
3. **Add API keys** — Open Settings (click menu bar icon → Settings) → API Keys tab → Add keys for your preferred providers
4. **Configure prompts** — Settings → Prompts tab to add, edit, or reorder prompts
5. **Start using** — Select text in any app, press `⌘C + C`, pick a prompt, and get AI responses!

## Architecture

```
Sources/MacAIHelper/
├── App/                    # App entry point, delegate, floating panel
├── Models/                 # Data models (AIProvider, Prompt, AppSettings, etc.)
├── Services/               # Business logic (AI APIs, Keychain, Hotkeys, etc.)
├── ViewModels/             # Observable state management
├── Views/                  # SwiftUI views (Settings, Popup, Result)
└── Resources/              # Info.plist, Entitlements
```

### Key Components

- **HotkeyService** — CGEvent tap for global shortcut detection
- **AIServiceRouter** — Routes requests to OpenAI, Anthropic, or Gemini
- **KeychainService** — Secure API key storage
- **FloatingPanelController** — NSPanel-based floating popup window
- **ScreenCaptureService** — Interactive screen region capture

## Permissions

The app requires two macOS permissions:

- **Accessibility** — For monitoring global keyboard shortcuts via CGEvent tap
- **Screen Recording** — For capturing screenshot regions (only needed for the screenshot feature)

## License

Private project.
