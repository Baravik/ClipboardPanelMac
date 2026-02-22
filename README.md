# Clipboard Panel OS

A lightweight macOS menu bar app that keeps your clipboard history — similar to **Windows + V** on Windows.

Press **⌘⇧V** (Cmd+Shift+V) anywhere to pop up a floating panel with your recent clipboard entries, search through them, and paste any item instantly.

---

## Features

- **Menu bar only** — no Dock icon, stays out of your way
- **Clipboard history** — stores the last 50 text items (in-memory, cleared on quit)
- **Floating panel** — appears at your cursor when you press the hotkey
- **Search** — quickly filter clipboard items by typing
- **Keyboard navigation** — Arrow keys + Enter to select, Escape to dismiss
- **Customizable hotkey** — change the shortcut in Settings
- **Click outside to dismiss** — panel closes when it loses focus
- **Duplicate detection** — identical copies are moved to the top, not duplicated

---

## Download

### From GitHub Releases (recommended)

1. Go to the [Releases](https://github.com/Baravik/ClipboardPanelMac/releases) page
2. Download the latest **Clipboard-Panel-OS.zip** from the Assets section
3. Unzip and drag **Clipboard Panel OS.app** into your `/Applications` folder
4. **Important — remove the macOS quarantine flag** (required because the app is not notarized):
   ```bash
   xattr -cr "/Applications/Clipboard Panel OS.app"
   ```
   Or: right-click the app → **Open** → click **Open** in the dialog.
5. Launch the app — you'll see a clipboard icon (📋) in your menu bar

> **"App is damaged and can't be opened"?** — This is macOS Gatekeeper blocking unsigned downloads. Run the `xattr -cr` command above to fix it.

### Build from source

Requires **Xcode 15+** and **macOS 14+**.

```bash
git clone https://github.com/Baravik/ClipboardPanelMac.git
cd ClipboardPanelMac
xcodebuild -project WinCForMac.xcodeproj -scheme WinCForMac -configuration Release build
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/`.

---

## Setup

### Grant Accessibility Permission

Clipboard Panel OS needs Accessibility access to simulate paste keystrokes and listen for global shortcuts.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button or find **Clipboard Panel OS** in the list
3. Toggle it **ON** (you may need to unlock with your password)

> If you skip this step, the app will show an onboarding screen explaining what to do.

---

## Usage

| Action | How |
|--------|-----|
| **Open clipboard panel** | Press **⌘⇧V** (or your custom hotkey) |
| **Search** | Start typing with the panel open |
| **Navigate items** | **↑** / **↓** arrow keys |
| **Paste selected item** | Press **Enter** or click the item |
| **Dismiss panel** | Press **Escape** or click outside |
| **Clear history** | Click "Clear All" in the panel footer, or use the menu bar menu |
| **Change hotkey** | Menu bar icon → **Settings** → click the shortcut button → press your new key combo |
| **Quit** | Menu bar icon → **Quit Clipboard Panel OS** |

---

## Configuration

Open **Settings** from the menu bar icon to:

- **Record a new shortcut** — click the shortcut button and press your preferred key combination (must include at least Cmd+another modifier, or Ctrl/Option)
- **Check Accessibility status** — see if permissions are granted, with a button to open System Settings

Settings are persisted across app restarts via UserDefaults.

---

## Notes

- Clipboard history is **in-memory only** — it resets when you quit the app. Nothing is written to disk.
- Only **text** clipboard entries are captured (images, files, etc. are ignored).
- The default hotkey is **⌘⇧V**. Single-modifier shortcuts like ⌘V are blocked to prevent conflicts with system paste.

---

## License

MIT
