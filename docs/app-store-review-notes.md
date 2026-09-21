# Mac AI Helper — App Store Review Notes

> **Version:** 1.0.0 (Build 1)
> **Bundle ID:** com.castloud.MacAIHelper
> **Platform:** macOS 14.0+ (Sonoma), Universal Binary (arm64 + x86_64)
> **Category:** Productivity / Utilities
> **Developer:** KAZAKOVA SOFTWARE CONSULTING LLC (Team ID: T2MHQ9ZQXG)
> **Last Updated:** March 24, 2026

---

## 1. App Overview

Mac AI Helper is a native macOS menu bar utility that enables users to quickly analyze selected text or screenshot regions using AI services (OpenAI, Anthropic, Google Gemini, OpenRouter). The app lives exclusively in the menu bar (LSUIElement) with no Dock icon, registers global keyboard shortcuts, and presents a floating popup for prompt selection and AI response display.

**Core workflow:**

1. User selects text in any application (or triggers a screenshot capture).
2. User presses a global keyboard shortcut (default: ⇧⌘C for text, ⌃⌘C for screenshot).
3. A floating popup appears with a list of user-configured AI prompt templates.
4. User picks a prompt → the captured content is sent to the configured AI provider → the response is displayed in the popup with copy functionality.

**The app is free to download with no paywalled features.** It offers an optional Tip Jar (consumable in-app purchases via StoreKit 2) to support development. Tips do not unlock any functionality.

---

## 2. Test Account & Setup Instructions

**No test account is required.** The app connects to third-party AI provider APIs using the user's own API keys. To test the app's functionality during review:

### Option A: Use a Test API Key (Recommended)

1. **Launch the app** — it will appear as an icon in the menu bar (no Dock icon).
2. The app will automatically open the Settings window on the API Keys tab since no keys are configured.
3. **Add an API key** from one of the supported providers:
   - **OpenAI:** Get a key at https://platform.openai.com/api-keys
   - **Anthropic:** Get a key at https://console.anthropic.com/settings/keys
   - **Google Gemini:** Get a key at https://aistudio.google.com/app/apikey
   - **OpenRouter:** Get a key at https://openrouter.ai/settings/keys
4. After adding a key, the app will automatically fetch the available models from the provider.
5. **Grant permissions** (see Section 4 below for details on Accessibility and Screen Recording).
6. **Test the text shortcut:** Select any text in any app → press ⇧⌘C (Cmd+Shift+C) → pick a prompt → view the AI response.
7. **Test the screenshot shortcut:** Press ⌃⌘C (Ctrl+Cmd+C) → drag to select a screen region → pick a prompt → view the AI response.

### Option B: Test Without an API Key

The app is fully navigable without an API key:

- The menu bar icon, dropdown menu, and all Settings tabs (Prompts, API Keys, Shortcuts, About) are fully functional.
- The shortcut triggers and popup UI will display but will show a "No API keys configured" alert prompting the user to add keys.
- The Tip Jar window is fully functional and can be tested using the StoreKit sandbox environment.

---

## 3. Entitlements & Sandbox Configuration

The app is fully sandboxed with minimal entitlements:

| Entitlement                             | Value                                       | Justification                                                                                                         |
| --------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `com.apple.security.app-sandbox`        | `true`                                      | Required for Mac App Store                                                                                            |
| `com.apple.security.network.client`     | `true`                                      | Outgoing HTTPS connections to AI provider APIs (api.openai.com, api.anthropic.com, generativelanguage.googleapis.com) |
| `com.apple.security.application-groups` | `T2MHQ9ZQXG.group.com.castloud.MacAIHelper` | Shared UserDefaults container for settings persistence                                                                |

**No other entitlements are requested.** The app does not use:

- File system access beyond its sandbox container
- Incoming network connections
- Camera or microphone
- Location services
- Apple Events / scripting bridge
- Temporary exception entitlements

---

## 4. macOS Permissions Required

### 4.1 Accessibility Permission (Text Capture Feature)

**What:** The app requests Accessibility permission via `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()`.

**Why:** When the user triggers the text capture shortcut (⇧⌘C), the app simulates a Cmd+C keystroke using `CGEvent` to copy the currently selected text from the frontmost application. This requires Accessibility (TCC) permission. The simulated keystroke flow is:

1. User presses the global hotkey (registered via Carbon `RegisterEventHotKey`, which does NOT require Accessibility).
2. The app creates a `CGEvent` for key code 0x08 (C key) with `.maskCommand` modifier.
3. The event is posted via `CGEvent.post(tap: .cghidEventTap)`.
4. After a 200ms delay, the app reads the pasteboard to get the copied text.
5. The previous pasteboard content is restored so the user's clipboard is not disrupted.

**User consent flow:**

- If Accessibility is not granted, the app shows a native `NSAlert` explaining what is needed and offers an "Open System Settings" button.
- The Settings → Shortcuts tab displays the current permission status with green/red indicators and a button to open System Settings.
- The app's Info.plist includes `NSAccessibilityUsageDescription`: _"Mac AI Helper needs Accessibility permission to copy selected text from other applications for AI processing."_

**Graceful degradation:** The app is fully functional without Accessibility permission — the screenshot capture feature and all other UI (Settings, Tip Jar, menu bar) work normally. Only the text capture shortcut requires this permission.

### 4.2 Screen Recording Permission (Screenshot Feature)

**What:** The app uses Apple's ScreenCaptureKit framework (`SCScreenshotManager.captureImage`) to capture a user-selected screen region.

**Why:** The screenshot capture feature lets users select a region of their screen via a drag-to-select overlay, then sends the captured image to an AI provider for analysis (e.g., "Describe what you see in this screenshot").

**Implementation details:**

- Uses `SCShareableContent.excludingDesktopWindows` and `SCScreenshotManager.captureImage` — both are public, sandbox-compatible ScreenCaptureKit APIs.
- Permission is checked via `CGPreflightScreenCaptureAccess()` (safe in sandbox).
- The captured image is held in memory only for the duration of the AI request and is never persisted to disk.

**User consent flow:**

- If Screen Recording is not granted and a capture is attempted, ScreenCaptureKit returns error code -3801. The app catches this and shows an `NSAlert` explaining what permission is needed, with an "Open System Settings" button.
- The Settings → Shortcuts tab displays permission status with a visual indicator.
- Info.plist includes `NSScreenCaptureUsageDescription`: _"Mac AI Helper needs screen recording permission to capture screenshots for AI analysis."_

**Graceful degradation:** The app is fully functional without Screen Recording permission — text capture, Settings, Tip Jar, and all other features work normally.

---

## 5. Global Keyboard Shortcuts

The app registers two global keyboard shortcuts using the [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) open-source library by Sindre Sorhus.

| Shortcut    | Default           | Purpose                                       |
| ----------- | ----------------- | --------------------------------------------- |
| Text Prompt | ⇧⌘C (Cmd+Shift+C) | Copy selected text and show prompt popup      |
| Screenshot  | ⌃⌘C (Ctrl+Cmd+C)  | Capture a screen region and show prompt popup |

**Technical implementation:** KeyboardShortcuts uses Carbon `RegisterEventHotKey` API under the hood. This API is fully sandbox-compatible and does **not** require Accessibility permission. The shortcuts can be customized by the user in Settings → Shortcuts using the built-in KeyboardShortcuts.Recorder control.

---

## 6. AI-Generated Content & Guideline 4.7 Compliance

Mac AI Helper displays AI-generated content from third-party providers. We have implemented the following safeguards:

### 6.1 Content Disclaimers

1. **Result View footer:** Every AI response displayed in the app includes a persistent footer disclaimer: _"AI-generated content — may not be accurate. Verify important information independently."_

2. **About tab:** The Settings → About tab contains a dedicated "AI-Generated Content" section with a full disclaimer: _"Responses displayed in this app are generated by third-party AI services (OpenAI, Anthropic, Google). AI-generated content may be inaccurate, incomplete, or misleading. Always verify important information independently. Do not rely on AI responses as a substitute for professional advice."_

3. **Terms of Use:** The publicly hosted Terms of Use (https://www.castloud.com/eula.html) includes a comprehensive "AI-Generated Content" section covering accuracy, user responsibility, and professional advice warnings.

### 6.2 Content Moderation

- The app relies on the built-in content moderation systems of the AI providers (OpenAI Content Policy, Anthropic Acceptable Use Policy, Google Gemini Terms of Service).
- The app does not bypass, circumvent, or modify any provider-side content filters.
- The app does not generate its own AI content — it is purely a client that forwards user content to provider APIs and displays the provider's responses.
- No user-generated content is shared between users or published publicly.

### 6.3 User Control

- Users must provide their own API keys — the app does not include any bundled API keys.
- Users choose which AI provider and model to use.
- Users configure their own prompt templates.
- All content interaction is strictly 1:1 (user ↔ AI provider), with no social or sharing features.

---

## 7. In-App Purchases (Tip Jar)

The app offers 5 consumable in-app purchases as voluntary developer tips:

| Product ID                         | Display Name | Price  |
| ---------------------------------- | ------------ | ------ |
| `com.castloud.MacAIHelper.tips.1`  | Small Tip    | $0.99  |
| `com.castloud.MacAIHelper.tips.5`  | Medium Tip   | $4.99  |
| `com.castloud.MacAIHelper.tips.10` | Large Tip    | $9.99  |
| `com.castloud.MacAIHelper.tips.30` | Generous Tip | $29.99 |
| `com.castloud.MacAIHelper.tips.50` | Mega Tip     | $49.99 |

**Implementation:**

- Uses StoreKit 2 (`Product.products(for:)`, `product.purchase()`, `Transaction.updates`).
- All products are consumable — they are finished immediately after successful purchase.
- Tips are purely voluntary and do not unlock any features, remove any limitations, or change the app's functionality in any way.
- The Tip Jar is accessible from the menu bar dropdown ("Tip Developer ❤️") and opens in a separate window.
- The Tip Jar window clearly states: _"Tips are optional and do not unlock any features or change the functionality of the app."_

---

## 8. Data Privacy & Privacy Nutrition Labels

### 8.1 Data NOT Collected

Mac AI Helper does **not** collect, transmit, or store any personal data on developer servers:

- **No analytics** — no usage tracking, event logging, or telemetry of any kind
- **No crash reporting** — no third-party crash reporting SDKs
- **No advertising** — no ad SDKs or tracking pixels
- **No backend** — the app has no server infrastructure
- **No user accounts** — no registration, login, or authentication

### 8.2 Data Stored Locally

| Data                            | Storage Location                         | Purpose                          |
| ------------------------------- | ---------------------------------------- | -------------------------------- |
| API keys                        | macOS Keychain (encrypted, sandboxed)    | Authentication with AI providers |
| Settings (prompts, preferences) | App Group container (JSON file)          | User configuration persistence   |
| Keyboard shortcuts              | UserDefaults (via KeyboardShortcuts lib) | Global hotkey registration       |

### 8.3 Data Sent to Third Parties

When the user explicitly triggers an AI request, the following data is sent **directly** from the user's device to the selected AI provider's API:

- **Text content:** The user's selected text + prompt template, sent to the AI provider for processing.
- **Image data:** Screenshot PNG data (base64-encoded), sent to the AI provider for analysis.

This data is transmitted over HTTPS directly to the provider's API endpoint. It does not pass through any Castloud servers. The specific provider depends on the user's configuration:

- OpenAI: `https://api.openai.com/v1/`
- Anthropic: `https://api.anthropic.com/v1/`
- Google Gemini: `https://generativelanguage.googleapis.com/v1beta/`
- OpenRouter: `https://openrouter.ai/api/v1/`

### 8.4 Recommended App Privacy Responses

For the App Store Connect privacy questionnaire:

- **Data Linked to You:** None
- **Data Used to Track You:** None
- **Data Not Linked to You:** None collected
- **Types of data collected:** None by the developer. User content is sent directly to third-party AI providers as described above.

---

## 9. Third-Party Libraries

| Library                                                                | Version | License | Purpose                                                    |
| ---------------------------------------------------------------------- | ------- | ------- | ---------------------------------------------------------- |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.2.2+  | MIT     | Global keyboard shortcut registration and customization UI |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)        | 2.4.0+  | MIT     | Rendering AI responses as formatted Markdown               |

Both libraries are integrated via Swift Package Manager. No private APIs are used.

---

## 10. Encryption (ECCN / Export Compliance)

The app uses encryption exclusively for:

1. **HTTPS/TLS** — All network communication with AI provider APIs uses standard URLSession with HTTPS.
2. **macOS Keychain** — API keys are stored using the Security framework (`SecItemAdd`, `SecItemCopyMatching`, etc.) which uses the system Keychain.

Both are standard platform-provided encryption mechanisms. The app qualifies for the **encryption exemption** under the "uses only standard OS-provided encryption" category (no custom cryptographic implementations).

**Recommended App Store Connect response:** "Yes, the app uses encryption" → "The app qualifies for an exemption" → "Uses only standard OS-provided encryption (HTTPS/TLS and Keychain)."

---

## 11. Launch at Login

The app offers an optional "Launch at Login" toggle in Settings → Shortcuts. This is implemented using Apple's modern `SMAppService.mainApp` API (macOS 13+), which is the recommended, sandbox-compatible approach for login items. The feature is opt-in and defaults to disabled.

---

## 12. Legal & Compliance

| Document            | URL                                   | Status    |
| ------------------- | ------------------------------------- | --------- |
| Privacy Policy      | https://www.castloud.com/privacy.html | Published |
| Terms of Use (EULA) | https://www.castloud.com/eula.html    | Published |

The Terms of Use include:

- AI-generated content disclaimer and accuracy warnings
- Third-party API charges disclosure (user is responsible for their own API usage costs)
- Limitation of liability
- User responsibilities (API key security, content compliance)
- In-app purchase terms (voluntary tips, no feature unlock)

---

## 13. Age Rating Recommendations

Given that the app displays AI-generated content from third-party services, we recommend:

- **Unrestricted Web Access:** Yes (the app sends user content to AI APIs and displays responses)
- **Age Rating:** 17+ (due to AI-generated content that may include mature themes depending on user prompts)

The app does not contain any developer-controlled objectionable content. All content is generated by third-party AI services in response to user-initiated requests.

---

## 14. Worldwide Availability Notes

The app itself has no regionalization restrictions. However, the third-party AI provider APIs it connects to may have limited availability in certain regions:

- **OpenAI API:** Not available in all countries (notably restricted in some regions)
- **Anthropic API:** May have regional restrictions
- **Google Gemini API:** May have regional restrictions

The app gracefully handles API unavailability — network errors are displayed to the user with descriptive error messages. The app does not require any AI provider to be functional for UI navigation, settings management, or tip jar purchases.

---

## 15. Demo / Testing Steps for Reviewer

### Quick Test (no API key needed):

1. Launch the app → menu bar icon appears
2. Click the menu bar icon → verify dropdown menu works
3. Click "Settings…" → verify all 4 tabs load (Prompts, API Keys, Shortcuts, About)
4. Click "Tip Developer ❤️" → verify Tip Jar window loads with StoreKit sandbox products
5. Press ⇧⌘C → verify "No API keys configured" alert appears
6. Verify About tab shows AI disclaimer and legal links

### Full Test (with API key):

1. Add an API key in Settings → API Keys
2. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)
3. Grant Screen Recording permission (System Settings → Privacy & Security → Screen Recording)
4. Select text in any app → press ⇧⌘C → pick a prompt → verify AI response appears with disclaimer footer
5. Press ⌃⌘C → drag to select a screen region → pick a prompt → verify AI response appears
6. Click "Copy" on a response → verify text is copied to clipboard
7. In Settings → Shortcuts, verify shortcut recorder allows customization
8. Verify "Launch at Login" toggle works

---

_End of Review Notes_
