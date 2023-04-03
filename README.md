# software-chording-keyboard

A software-powered chording keyboard.

Now you can turn any ordinary keyboard into a chording keyboard without dedicated hardware.

## How this works

This software listens to keypresses. If it detects a chord, it will imitate backspace key presses to delete the typed characters, before typing the chord output.

For example, if you press `t` and `h` together, it will detect the chord `th` which maps to `the`. It will therefore send two backspace key events (to remove `th` or `ht`) and then send three further key events to type `the`.
