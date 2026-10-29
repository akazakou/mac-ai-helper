# Mac AI Helper

A native macOS menu bar utility that captures selected text or screenshots via global keyboard shortcuts, presents a popup with predefined AI prompts, sends the content to a configured AI provider, and displays the response with copy functionality.

Free and open source under [GPL-3.0](LICENSE).

## Features

- **Menu Bar Only** — Lives exclusively in the macOS menu bar (no Dock icon)
- **Global Shortcuts** — Trigger from any application (Carbon hotkeys, no permission needed)
  - `⇧⌘C` (`Cmd+Shift+C`) — Capture selected text and show prompt popup
  - `⌃⌘C` (`Ctrl+Cmd+C`) — Capture a screenshot region and show prompt popup
- **Multiple AI Providers** — Supports OpenAI, Anthropic (Claude), Google Gemini, and OpenRouter
- **Dynamic Model Listing** — Fetches available models from each provider's API
- **Per-Prompt Models** — Each prompt uses its own model, picked in the prompt editor; outdated or unreachable models are flagged with badges
- **Custom Prompts** — Configure unlimited AI prompt templates
- **Secure Key Storage** — API keys stored in macOS Keychain
- **Native UI** — Built with SwiftUI, uses floating panels for the popup

## Installation

1. Download the latest `.dmg`, `.pkg` or `.zip` from [Releases](https://github.com/akazakou/mac-ai-helper/releases) (Universal — Apple Silicon and Intel, macOS 14+)
2. Install into `/Applications`
3. First launch: the app is not notarized by Apple, so macOS blocks it once per downloaded version. Open **System Settings → Privacy & Security** and click **Open Anyway**, or run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/MacAIHelper.app
   ```

## Setup

1. **Launch the app** — It will appear as an icon in the menu bar
2. **Add API keys** — Open Settings (click menu bar icon → Settings) → API Keys tab → Add keys for your preferred providers
3. **Configure prompts** — Settings → Prompts tab to add, edit, or reorder prompts
4. **Start using** — Select text in any app, press `⇧⌘C`, pick a prompt, and get AI responses!

## Requirements (development)

- macOS 14+ (Sonoma)
- Xcode 16+ / Swift 6.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — generates `.xcodeproj` from `project.yml` (`brew install xcodegen`)

No Apple Developer Program membership is required.

## Development

```bash
swift build                 # compile
swift test                  # run unit tests
xcodegen generate && open MacAIHelper.xcodeproj   # run/debug from Xcode (Debug is "Sign to Run Locally")
```

The `.xcodeproj` is generated from `project.yml` and is not committed to git.

## Building & Releasing (GitHub Actions)

All release builds, signing and packaging run in [`.github/workflows/release.yml`](.github/workflows/release.yml) on `macos-latest`.
Each run produces a Universal (arm64 + x86_64) app packaged as **DMG**, **PKG** and **ZIP**, plus `SHA256SUMS.txt`.

| Trigger | Result |
| --- | --- |
| Push tag `vX.Y.Z` | GitHub Release `vX.Y.Z` with all packages |
| Push tag `vX.Y.Z-beta.1` (any `-suffix`) | Same, marked as pre-release |
| **Actions → Build & Release → Run workflow** (any branch) | Test build; download packages from the run's **Artifacts** |

```bash
git tag v1.2.0
git push origin v1.2.0
```

Version mapping: `CFBundleShortVersionString` comes from the tag without the `-suffix` (branch builds use the value in `SupportFiles/Info.plist`); `CFBundleVersion` is the workflow run number.

### Signing certificate

Releases are signed with a persistent **self-signed** code-signing certificate stored in GitHub Secrets.
macOS ties Accessibility / Screen Recording grants and Keychain access to the signing certificate,
so a stable certificate keeps users' permissions across updates. It does not replace Apple notarization:
Gatekeeper still asks users to confirm each downloaded version once.

One-time setup:

```bash
scripts/create-signing-cert.sh            # writes ~/.mac-ai-helper-signing/
base64 -i ~/.mac-ai-helper-signing/signing-cert.p12 | gh secret set MACOS_SIGNING_CERT_P12_BASE64
gh secret set MACOS_SIGNING_CERT_PASSWORD < ~/.mac-ai-helper-signing/signing-cert-password.txt
```

| Secret | Content |
| --- | --- |
| `MACOS_SIGNING_CERT_P12_BASE64` | Base64-encoded `.p12` (certificate + private key) |
| `MACOS_SIGNING_CERT_PASSWORD` | `.p12` password |

- Back up `~/.mac-ai-helper-signing/` in a password manager. Anyone holding the `.p12` can sign apps that inherit users' permission grants.
- Replacing the certificate resets every user's permissions once.
- Without the secrets (e.g. in forks) the workflow falls back to ad-hoc signing and prints a warning; permissions then reset on every update.

## Architecture

```
project.yml                 # XcodeGen project spec (generates .xcodeproj)
Package.swift               # SPM package manifest (dependency declarations)
.github/workflows/          # Build, sign, package and release pipeline
scripts/                    # Icon generation, signing certificate creation
SupportFiles/               # Info.plist, icons, installer (.pkg) resources
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

### Data Persistence

- **Settings** (`settings.json`) — Stored in `~/Library/Application Support/MacAIHelper/`.
- **API Keys** — Stored in macOS Keychain. Access survives updates as long as releases are signed with the same certificate.
- **Keyboard Shortcuts & panel size** — Stored in the app's UserDefaults.

## Permissions

The app requires two macOS permissions:

- **Accessibility** — To simulate `⌘C` and copy the selected text (text prompt shortcut)
- **Screen Recording** — For capturing screenshot regions (screenshot shortcut)

Global keyboard shortcuts themselves use Carbon APIs and need no permission.

macOS binds privacy permissions to the app's **code signature**. If permissions show as
granted but don't work (e.g. they were granted to a differently signed build), reset and grant again:

```bash
tccutil reset Accessibility com.castloud.MacAIHelper
tccutil reset ScreenCapture com.castloud.MacAIHelper
```

Screen Recording usually requires relaunching the app after it is granted.

## Privacy

See [PRIVACY.md](PRIVACY.md).

- No data collected or transmitted to Castloud servers
- API keys stored locally in macOS Keychain
- Content sent directly to user-configured AI providers
- No analytics or tracking

## Support

If the app is useful to you, consider [sponsoring development](https://github.com/sponsors/akazakou) ❤️

## License

[GNU General Public License v3.0](LICENSE). © 2026 Castloud.
