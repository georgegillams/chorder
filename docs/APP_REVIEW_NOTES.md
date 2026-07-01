# App Review notes (Mac App Store)

## Summary

Chorder is a **text input method** for macOS. The App Store build uses **Input Method Kit (IMK)** exclusively to receive keystrokes and insert chord output. It does **not** use the Accessibility API or Input Monitoring for its primary typing path.

## Input method setup

Users enable Chorder in **System Settings → Keyboard → Input Sources** (Edit… → +) and select it from the input menu while typing. The app installs `ChorderInputMethod.app` from `Chorder.app/Contents/Library/Input Methods/` into `~/Library/Input Methods/`.

## Privacy

- **No Accessibility permission** is requested in the Release / App Store configuration.
- **No Input Monitoring permission** is requested in the Release / App Store configuration.
- Chord settings are shared between the menu-bar app and the input method via App Group `group.uk.co.georgegillams.chorder`.

## Legacy global monitoring

A legacy global-monitoring mode exists for local Debug builds only. It is **not available** in the sandboxed App Store build and is **not** the mechanism used by the shipping product.

## Testing

1. Install the app and open Preferences.
2. Confirm **Keyboard input** is **Input method (recommended)**.
3. Install the input method and add Chorder in Keyboard settings.
4. Select Chorder as the active input source.
5. Open TextEdit, hold `t` + `h`, and verify chord expansion (e.g. `the`).
