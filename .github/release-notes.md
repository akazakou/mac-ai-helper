## Installation

Pick one package (all are Universal — Apple Silicon and Intel, macOS 14+):

- **`.dmg`** — open it and drag **MacAIHelper** into **Applications**
- **`.pkg`** — guided installer into `/Applications`
- **`.zip`** — unzip and move **MacAIHelper.app** into `/Applications`

### First launch

Mac AI Helper is open source and not notarized by Apple, so macOS blocks the first
launch of every downloaded version. Allow it once:

1. Open the app — macOS shows a warning, click **Done**
2. Open **System Settings → Privacy & Security**, scroll down, click **Open Anyway**

Or from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/MacAIHelper.app
```

### Permissions

Grant **Accessibility** (copy selected text) and **Screen Recording** (screenshots)
when asked. Every release is signed with the same certificate, so the grants survive updates.

Verify a download with `shasum -a 256 -c SHA256SUMS.txt`.
