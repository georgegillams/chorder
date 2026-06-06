# Software Chording Keyboard

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

## Building

Open `Software Chording Keyboard.xcodeproj` in Xcode and build the **Software Chording Keyboard** scheme (`⌘B`).

For local development, app sandboxing is typically disabled. Re-enable it before release builds.

## Running tests

The project uses [Xcode test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback) in the `TestPlans/` directory:

| Test plan | What it runs |
|-----------|--------------|
| **UnitTests** (default) | Unit tests only — matches CI |
| **AllTests** | Unit tests + UI tests |

### From Xcode

1. Open the project in Xcode.
2. Select the **Software Chording Keyboard** scheme.
3. Press `⌘U` to run the active test plan, or use **Product → Test**.

To switch plans: **Product → Test Plan → UnitTests** or **AllTests**. You can also choose the plan in the Test navigator (⌘6).

Unit tests live in **Software Chording KeyboardTests**. UI tests live in **Software Chording KeyboardUITests**.

### From the command line

Run the default unit test plan:

```bash
xcodebuild test \
  -scheme "Software Chording Keyboard" \
  -destination 'platform=macOS' \
  -testPlan UnitTests \
  CODE_SIGNING_ALLOWED=NO
```

Run all tests (unit + UI):

```bash
xcodebuild test \
  -scheme "Software Chording Keyboard" \
  -destination 'platform=macOS' \
  -testPlan AllTests \
  CODE_SIGNING_ALLOWED=NO
```

List available test plans:

```bash
xcodebuild -scheme "Software Chording Keyboard" -showTestPlans
```

This matches the [CI workflow](.github/workflows/ci.yml), which runs the **UnitTests** plan on every push.

## Contributing

### Permissions issues during development

If permissions behave unexpectedly while developing:

1. Ensure app sandbox is disabled for development builds.
2. Delete any installed production copy of the app.
3. Remove it from `/Applications` if present.
4. Remove the app from **System Settings → Privacy & Security** — both Accessibility and Input Monitoring.
5. Clean the Xcode build folder (**Product → Clean Build Folder**).
6. Rebuild and re-accept permissions when prompted.

## Release

Before releasing, re-enable app sandbox in the project entitlements.
