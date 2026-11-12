# Dusk

A small macOS menu bar app that dims your screen below the hardware minimum, for comfortable nighttime browsing. It works on every display, including over the menu bar, the Dock and full-screen apps.

## Download

**[⬇ Download Dusk.dmg](https://github.com/Naimy441/Dusk/releases/latest/download/Dusk.dmg)**: signed and notarized by Apple, and runs on Apple silicon and Intel Macs with macOS 13 or later.

Open the DMG, drag **Dusk** into **Applications**, and launch it. Dusk runs in the menu bar (look for the moon) and has no Dock icon.

## Features

- **Brightness slider**: dims from 100% down to 5%. The popover stays readable above the shade.
- **Warmth**: an optional amber tint for late-night reading.
- **Presets**: Low, Medium, Dark and Night, one click each.
- **Schedule**: turns dimming on and off automatically, e.g. 10 PM to 7 AM. A manual override holds until the next scheduled change.
- **Global shortcuts** (no Accessibility permission needed):
  - `⌃⌥⌘ ↑` / `⌃⌥⌘ ↓`: brighter / darker, with an on-screen indicator
  - `⌃⌥⌘ D`: toggle dimming
- **Menu bar icon**:
  - click: open the controls
  - ⌥-click: toggle dimming
  - right-click: quick menu
  - scroll over the icon: adjust brightness
- **Multi-display**: handles displays being plugged in or unplugged and sleep/wake.
- **Launch at login**.
- Clicks always pass through the shade, so it never gets in your way.

## Build & install

Requires macOS 13+ and Xcode (or the Command Line Tools).

```bash
./build.sh            # builds build/Dusk.app (universal: Apple silicon + Intel)
./build.sh --install  # also copies it to /Applications and launches it
```

To use Launch at login, run Dusk from `/Applications`.

To make a signed, notarized release, you need a Developer ID Application certificate and a `notarytool` keychain profile:

```bash
NOTARY_PROFILE=<your-profile> ./build.sh --release   # → build/Dusk.dmg, build/Dusk.zip
```

## How it works

Dusk places a borderless, click-through, transparent window on each display at screen-saver window level. The window joins all Spaces and full-screen apps. Its black layer's opacity sets the dimming, and an amber layer underneath adds the warmth. Quitting Dusk removes the shade right away, and Dusk never changes system brightness or gamma settings.

## Project layout

| File | Purpose |
| --- | --- |
| `Sources/Dusk/AppDelegate.swift` | Menu bar item, popover, shortcuts, scroll-to-dim |
| `Sources/Dusk/OverlayController.swift` | The per-display dimming windows |
| `Sources/Dusk/PopoverView.swift` | SwiftUI control panel |
| `Sources/Dusk/Settings.swift` | Persisted preferences |
| `Sources/Dusk/Scheduler.swift` | Automatic on/off schedule |
| `Sources/Dusk/HotKeys.swift` | Carbon global hot keys |
| `Sources/Dusk/HUD.swift` | On-screen brightness indicator |
| `Tools/make-icon.swift` | Renders the app icon at build time |
