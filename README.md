# software-chording-keyboard

A software-powered chording keyboard.

Now you can turn any ordinary keyboard into a chording keyboard without dedicated hardware.

## How this works

This software listens to keypresses. If it detects a chord, it will imitate backspace key presses to delete the typed characters, before typing the entire chord output.

For example, if you press `t` and `h` together, it will detect the chord `th` which maps to `the`. It will therefore send two backspace key events (to remove `th` or `ht`) and then send three further key events to type `the`.

## Contributing

### Permissions issues

If you have issues with permissions when developing, try the following.

1. Delete the installed production app
1. Remove it from bin too
1. Remove the app from privacy settings — both accessibility and input monitoring
1. Clean the Xcode build folder (Product > Clean Build Folder)
1. Rebuild and re-accept permissions
