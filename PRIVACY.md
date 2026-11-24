# Privacy Policy

_Last updated: November 24, 2026_

Mac AI Helper ("the App") is open-source software developed and maintained by Castloud.
This policy explains what data the App handles and how it is treated.

## Data We Do Not Collect

The App does **not** collect, transmit, or store any personal data on our servers.
We have no backend, no analytics, and no tracking of any kind.

## Data Stored Locally on Your Device

- **API Keys** — Your provider API keys (OpenAI, Anthropic, Google Gemini, OpenRouter, Google Translate)
  are stored on your device in `~/Library/Application Support/MacAIHelper/api-keys.json`,
  a file only your macOS user account can read. They are not encrypted, so software running
  under your account can read them. They are never sent to us.
- **Settings** — Your prompt templates, keyboard shortcuts, and preferences are saved
  locally in `~/Library/Application Support/MacAIHelper`.

## Data Sent to Third Parties

When you use the App to analyze text or screenshots, the content you submit is sent
directly from your device to the AI provider you have configured (OpenAI, Anthropic,
Google, or OpenRouter). This communication happens between your Mac and the provider's
API — it does not pass through any Castloud servers.

When you run a Google Translate prompt, the selected text is sent directly from your
device to Google: to the Google Cloud Translation API when the prompt uses your API key,
or to the keyless Google Translate endpoint (`translate.googleapis.com`) when it uses
"Google Translate Free".

On launch the App requests the list of supported languages from the keyless Google
Translate endpoint. This request contains no personal data or content.

To find updates, the App requests the latest release from the GitHub API (`api.github.com`)
on launch and once a day, and downloads the new version from GitHub when you choose to install it.
These requests contain no personal data or content. See the
[GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

Please review the privacy policies of the AI providers you use:

- [OpenAI Privacy Policy](https://openai.com/policies/privacy-policy)
- [Anthropic Privacy Policy](https://www.anthropic.com/privacy)
- [Google Privacy Policy](https://policies.google.com/privacy)
- [Google Cloud Privacy Notice](https://cloud.google.com/terms/cloud-privacy-notice) (Google Translate)
- [OpenRouter Privacy Policy](https://openrouter.ai/privacy)

## Screen Recording

The screenshot feature uses macOS ScreenCaptureKit to capture a region of your screen.
The captured image is processed locally and sent only to the AI provider you have
configured. With a Google Translate prompt the image itself is not sent anywhere: its text
is recognized on your device, only that text is sent to Google, and the translated image
is written to disk only where you choose to save it.
Screenshots are not stored permanently and are discarded after the analysis
is complete.

## Third-Party API Charges

You are solely responsible for all charges incurred from your use of third-party AI
APIs with your own API keys.

## Children's Privacy

The App is not directed at children under the age of 13. We do not knowingly collect
any information from children.

## Changes to This Policy

We may update this privacy policy from time to time. Changes are published in this
file with an updated revision date.

## License

The App is distributed under the [GNU General Public License v3.0](LICENSE), without
any warranty.

## Contact

Questions about this policy: [privacy@castloud.com](mailto:privacy@castloud.com).

© 2026 Castloud.
