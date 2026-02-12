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

- macOS 14+ (Sonoma)
- Swift 6.0+
- Xcode 16+ (for building)

## Building

```bash
# Build the project
swift build

# Run directly
swift run MacAIHelper

# Build for release
swift build -c release
```

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
