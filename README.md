# Chorder

A macOS app that turns any ordinary keyboard into a chording keyboard — no dedicated hardware required.

## How it works

The app listens to keypresses globally. When it detects a chord (multiple keys held together), it deletes the typed characters and inserts the chord's configured output.

For example, pressing `t` and `h` together matches the chord `th` → `the`. The app sends backspace events to remove `th` (or `ht`), then types `the`.

Chords can include:

- A cursor pipe (`|`) to position the caret mid-output
- Date placeholders (`{{yyyy-MM-dd}}`, etc.)
- Per-chord options for capitalisation and leading-space behaviour

## Requirements

- macOS 13 or later
- Xcode 15 or later (for building and running tests)
- Accessibility and Input Monitoring permissions (granted on first launch)

## Running locally

### Clone and run

```bash
git clone git@github.com:georgegillams/software-chording-keyboard.git
cd software-chording-keyboard
open "Chorder.xcodeproj"
```

In Xcode:

1. Select the **Chorder** scheme.
2. Choose **My Mac** as the run destination.
3. Press **Run** (⌘R).

The app builds and launches from Xcode. Look for the keyboard icon in the menu bar.

### Schemes

| Scheme | Use when |
| --- | --- |
| **Chorder** | Normal development and testing. |
| **G_DEBUG Chorder** | Opens Preferences automatically on launch, and enables debug logs. |

No third-party dependencies are required — open the project and build.

### Local development vs production builds

When you **Run** from Xcode, the app uses the **Debug** build configuration. When you **Archive** for release, it uses **Release**. Several deliberate differences make it easy to tell the two apart and stop them interfering with each other.

| | Local development (Debug) | Production (Release / App Store) |
| --- | --- | --- |
| App bundle on disk | `Chorder Local.app` | `Chorder.app` |
| Bundle identifier | `uk.co.georgegillams.chorder.mac-os.local` | `uk.co.georgegillams.chorder.mac-os` |
| Display name | `Chorder (Local)` | `Chorder` |
| Menu build line | `Chorder local development` | `Chorder {version}` (marketing version) |
| Accessibility entry | **Chorder (Local)** | **Chorder** |
| Input Monitoring entry | **Chorder (Local)** | **Chorder** |
| Debug logging (`gDebugPrint`) | Enabled when running the **G_DEBUG** scheme | Compiled out |
| Sandbox / app data | Separate container | App Store container |

Archiving always uses **Release**, so a normal archive produces the production app name, bundle ID, and version label. The local-only settings exist only in the Debug configuration in `Chorder.xcodeproj`.

#### How each difference is implemented

**App name and bundle identifier**

Set per build configuration in `Chorder.xcodeproj/project.pbxproj`:

- **Debug:** `PRODUCT_NAME = "Chorder Local"` and `PRODUCT_BUNDLE_IDENTIFIER = uk.co.georgegillams.chorder.mac-os.local`
- **Release:** `PRODUCT_NAME = "$(TARGET_NAME)"` (→ `Chorder`) and `PRODUCT_BUNDLE_IDENTIFIER = uk.co.georgegillams.chorder.mac-os`

macOS treats different bundle IDs as different apps. That gives local and production builds separate Accessibility and Input Monitoring permissions, separate sandbox containers (preferences, chord config), and separate Launch at Login entries.

**Display name and permission usage strings**

Debug-only Info.plist keys in the same Debug build configuration:

- `INFOPLIST_KEY_CFBundleDisplayName = "Chorder (Local)"`
- `INFOPLIST_KEY_CFBundleName = "Chorder Local"`
- `INFOPLIST_KEY_NSAccessibilityUsageDescription` and `INFOPLIST_KEY_NSInputMonitoringUsageDescription` — local-specific permission prompt text

Release builds inherit the defaults from `Chorder-Info.plist` and generated Info.plist keys.

**Menu build line (`local development` vs version)**

`Chorder/Utils/Bundle+Version.swift` defines `menuBuildLabel`, which returns `"local development"` when `isLocalDevelopment` is true. That flag is `#if DEBUG` — true only in Debug builds, false in Release regardless of how the app was installed.

`AppDelegate+StatusBar.openMenu()` uses `Bundle.main.menuBuildLabel` for the footer item (e.g. `Chorder local development` or `Chorder 1.0`).

**Debug logging**

`Chorder/Models/Debug.swift` wraps `gDebugPrint` in `#if DEBUG` and only prints when the `G_DEBUG` launch argument is present (`isGDebugScheme`). Use the **G_DEBUG Chorder** scheme to see log output; the normal Debug scheme compiles logging support but stays quiet.

**G_DEBUG Chorder scheme**

The **G_DEBUG Chorder** scheme is separate from the local/production split. It passes the `G_DEBUG` launch argument (see `Chorder.xcodeproj/xcshareddata/xcschemes/G_DEBUG Chorder.xcscheme`). `isGDebugScheme` in `Debug.swift` checks for that argument and, in `AppDelegate`, opens Preferences on launch. Both schemes still build the Debug configuration when you Run.

For local development, app sandboxing is typically disabled. Re-enable it before release builds.

## Running tests

The project uses [Xcode test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback) in the `TestPlans/` directory:

| Test plan | What it runs |
|-----------|--------------|
| **UnitTests** (default) | Unit tests only — matches CI |
| **AllTests** | Unit tests + UI tests |

### From Xcode

1. Open the project in Xcode.
2. Select the **Chorder** scheme.
3. Press `⌘U` to run the active test plan, or use **Product → Test**.

To switch plans: **Product → Test Plan → UnitTests** or **AllTests**. You can also choose the plan in the Test navigator (⌘6).

Unit tests live in **ChorderTests**. UI tests live in **ChorderUITests**.

### From the command line

Run the default unit test plan:

```bash
xcodebuild test \
  -scheme "Chorder" \
  -destination 'platform=macOS' \
  -testPlan UnitTests \
  CODE_SIGNING_ALLOWED=NO
```

Run all tests (unit + UI):

```bash
xcodebuild test \
  -scheme "Chorder" \
  -destination 'platform=macOS' \
  -testPlan AllTests \
  CODE_SIGNING_ALLOWED=NO
```

List available test plans:

```bash
xcodebuild -scheme "Chorder" -showTestPlans
```

## Permissions during development

The app needs **Accessibility** and **Input Monitoring** permissions to detect chords and type output. Local and production builds require **separate** permission grants because they use different bundle identifiers (see above).

### Granting permission

1. Launch the app from Xcode.
2. When prompted, grant permissions in the Preferences window, or go to **System Settings → Privacy & Security**.
3. Enable the toggles for **Chorder (Local)** under both **Accessibility** and **Input Monitoring** (not the production **Chorder** entries).

### Tips when permission does not work

**Enable the correct entries.** When running from Xcode, grant permission to **Chorder (Local)**. The App Store build (**Chorder**) is a separate entry and permission on one does not apply to the other.

**Restart the app after changing permission.** Quit completely (menu bar → Quit, or stop the run in Xcode) and launch again so macOS applies the new setting.

**Toggle permission off and on.** If chord detection still fails after granting access, remove the app from the permission lists, rebuild and run, then re-enable it.

**Reset TCC state while iterating on permissions.** During development you can clear consent and start fresh:

```bash
# Local development build (Xcode Run)
tccutil reset Accessibility uk.co.georgegillams.chorder.mac-os.local
tccutil reset ListenEvent uk.co.georgegillams.chorder.mac-os.local

# App Store / production build
tccutil reset Accessibility uk.co.georgegillams.chorder.mac-os
tccutil reset ListenEvent uk.co.georgegillams.chorder.mac-os
```

Then rebuild, run, and grant permission again through Preferences or System Settings.

**Delete conflicting installs.** If permissions behave unexpectedly, remove any installed production copy from `/Applications`, clean the Xcode build folder (**Product → Clean Build Folder**), and rebuild.

## Release

Before releasing, re-enable app sandbox in the project entitlements.
