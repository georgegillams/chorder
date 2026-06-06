# Space handling sequence diagrams

Sequence diagrams for how spaces are added (and removed) when using the chording keyboard. Logic lives in `KeyboardInputEngine`, `Chord.resolveReplacement`, and `TextReplacer`.

There are two related mechanisms:

1. **Trailing owed space** — after a chord without a pipe (`|`), the engine remembers that the _next_ letter should be preceded by a space.
2. **Space before output** — per-chord setting (`default` / `always` / `never`) that adjusts replacement output when a chord fires, based on whether an owed space was actually inserted before the chord input.

---

## State variables

| Variable                              | Where                      | Meaning                                                                                                                                                       |
| ------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `owedSpace`                           | `KeyboardInputEngine`      | After a non-piped chord, the next letter key should trigger auto-space insertion. Exposed as `owesTrailingSpace`.                                             |
| `autoInsertedSpaceBeforeCurrentInput` | `KeyboardInputEngine`      | Set when owed-space insertion runs; passed into `resolveReplacement` so the matched chord knows a leading space was auto-inserted. Cleared after replacement. |
| `spaceBeforeOutputMode`               | `Chord`                    | Per-chord: `default`, `always`, or `never`. Controls whether replacement output should include a leading space.                                               |
| `backspacesBeforeOutput`              | `ResolvedChordReplacement` | Extra backspaces before typing output, to remove an auto-inserted space the chord does not want.                                                              |

---

## Synthetic keys and echo counting

When the engine posts CGEvent synthetic keys (`insertOwedSpaceBefore`, `replaceViaSyntheticKeys`), those events pass through the same global monitor as real user input. To avoid re-processing them:

1. The replacer posts all CGEvents synchronously and returns an echo count.
2. `scheduleEchoes(count)` runs immediately on return (before the run loop delivers synthetic monitor callbacks).
3. Each synthetic `keyDown`/`keyUp` that arrives later hits `consumeEchoIfPending()` in `handleKeyDown`/`handleKeyUp` and is dropped.
4. For chord replacement, `finishReplacement()` runs when the last echo is consumed (or immediately via `endReplacementIfNoPendingEchoes()` on the AX path, which posts no echoes).

In code, both call sites nest the replacer inside `scheduleEchoes`:

```swift
chordDetection.scheduleEchoes(textReplacer.insertOwedSpaceBefore(character: character ?? ""))
chordDetection.scheduleEchoes(textReplacer.replaceViaSyntheticKeys(chord: chord, resolved: resolved))
```

Swift evaluates the argument first, so CGEvent posts always complete before the echo count is registered — but still before monitor delivery.

---

## Trailing owed space

### When owed space is set

After a successful chord replacement, `updatePostReplacementSpacingState` runs:

```swift
owedSpace = !chord.hasPipe
```

Chords whose output contains a pipe (e.g. `hel|lo`) place the cursor mid-output and do **not** enter owed-space mode.

### When owed space is cleared

| Trigger             | Examples                                                                            |
| ------------------- | ----------------------------------------------------------------------------------- |
| Owed space consumed | Next letter keyDown runs insertion                                                  |
| Special keys        | space, tab, backspace, return, escape                                               |
| Navigation          | left/right arrow                                                                    |
| Modifiers           | cmd, option, control, fn                                                            |
| Punctuation         | Characters in `KeyboardConstants.skipPrecedingSpaceCharacters` (e.g. `.`, `,`, `!`) |

---

## Case 1: Chord without pipe → owed space on next letter

**Setup:** Chord `th→the` (no pipe). User has typed `the` via chord; field shows `the`.

**Result:** User presses `h`. Field becomes `the h` (space inserted before `h`).

```mermaid
sequenceDiagram
    participant User
    participant TargetApp as TargetApp
    participant Monitor as GlobalMonitor
    participant Engine as KeyboardInputEngine
    participant Detection as ChordDetectionState
    participant Replacer as TextReplacer

    Note over Engine: Prior: chord th→the matched<br/>owedSpace=true, autoInserted=false

    User->>TargetApp: h keyDown
    TargetApp->>TargetApp: field = "theh" (key passes through)
    Monitor->>Engine: handleKeyDown(h)

    Engine->>Engine: owedSpace=true → consume owed space
    Note over Engine: owedSpace=false<br/>autoInsertedSpaceBeforeCurrentInput=true

    Engine->>Replacer: insertOwedSpaceBefore("h")
    Replacer->>TargetApp: backspace (keyDown + keyUp)
    Note over TargetApp: field = "the"
    Replacer->>TargetApp: type " h" (keyDown + keyUp)
    Note over TargetApp: field = "the h"
    Replacer-->>Engine: return 4

    Engine->>Detection: scheduleEchoes(4)
    Note over Detection: Registered before run loop delivers<br/>synthetic monitor callbacks<br/>(backspace down/up + type down/up)

    Monitor->>Engine: handleKeyDown ×4 (synthetic)
    Engine->>Detection: consumeEchoIfPending() ×4

    Engine->>Detection: keyDown(h)
    Note over Detection: accumulating, held=[h]<br/>(real user key, same handleKeyDown call)
```

The user's `h` keyDown reaches the target app first (observe-only monitors). The engine then synthetically backspaces and re-types ` h`, which is why insertion uses `insertOwedSpaceBefore` rather than typing a standalone space.

---

## Case 2: Owed-space insertion — synthetic key sequence

Detail of `TextReplacer.insertOwedSpaceBefore(character:)`:

```mermaid
sequenceDiagram
    participant Engine as KeyboardInputEngine
    participant Replacer as TextReplacer
    participant TargetApp as TargetApp
    participant Detection as ChordDetectionState
    participant Monitor as GlobalMonitor

    Engine->>Replacer: insertOwedSpaceBefore("h")

    Replacer->>TargetApp: pressKey(backspace) — keyDown + keyUp
    Replacer->>TargetApp: typeText(" h") — keyDown + keyUp
    Replacer-->>Engine: return 4 (echo count)

    Engine->>Detection: scheduleEchoes(4)
    Note over Detection: Echo count registered synchronously on return,<br/>before monitor callbacks from posted CGEvents are delivered

    Monitor->>Engine: handleKeyDown ×4 (synthetic)
    Engine->>Detection: consumeEchoIfPending() ×4
```

Echo counting prevents the engine from treating its own synthetic events as new user input. In code, `scheduleEchoes` is the outer call and `insertOwedSpaceBefore` is its argument, so CGEvent posts finish first; echoes are registered on return, still before the run loop delivers those synthetic events to the monitor.

---

## Case 3: Chord with pipe → no trailing owed space

**Setup:** Chord `ab→a|b`. Output places the cursor between `a` and `b`.

**Result:** After replacement, `owedSpace` stays false; the next letter is typed immediately with no auto-space.

```mermaid
sequenceDiagram
    participant User
    participant Engine as KeyboardInputEngine
    participant Detection as ChordDetectionState

    Detection->>Engine: onChordMatched("ab")
    Engine->>Engine: handleChordMatch → replaceCharacters
    Engine->>Engine: updatePostReplacementSpacingState
    Note over Engine: chord.hasPipe=true<br/>owedSpace=false

    User->>Engine: handleKeyDown(next letter)
    Note over Engine: owedSpace=false<br/>no insertOwedSpaceBefore
    Engine->>Detection: keyDown (normal accumulation)
```

---

## Case 4: User cancels owed space before typing

### 4a — User presses space (or backspace, tab, etc.)

```mermaid
sequenceDiagram
    participant User
    participant Engine as KeyboardInputEngine
    participant Detection as ChordDetectionState

    Note over Engine: owedSpace=true after prior chord

    User->>Engine: handleKeyDown(space)
    Engine->>Engine: owedSpace=false<br/>autoInsertedSpaceBeforeCurrentInput=false
    Engine->>Detection: reset()
    Note over Engine: Special keys do not accumulate<br/>for chord detection
```

### 4b — User presses punctuation (skip list)

Characters like `.`, `,`, `!`, `@` clear owed space without inserting one:

```mermaid
sequenceDiagram
    participant User
    participant Engine as KeyboardInputEngine

    Note over Engine: owedSpace=true after prior chord

    User->>Engine: handleKeyDown(".")
    Engine->>Engine: skipPrecedingSpaceCharacters contains "."
    Note over Engine: owedSpace=false (dropped)
    Engine->>Engine: no insertOwedSpaceBefore
```

---

## Space before output (per-chord setting)

When a chord matches, `resolveReplacement` decides whether the replacement text needs a leading space or an extra backspace.

### `wantsSpaceBeforeInputWhenTyped`

| Mode      | Wants leading space when…                                                                        |
| --------- | ------------------------------------------------------------------------------------------------ |
| `default` | Global owed-space insertion ran before this chord input (`autoInsertedSpaceBeforeInput == true`) |
| `always`  | Always                                                                                           |
| `never`   | Never                                                                                            |

### Correction matrix

Because owedSpace insertion happens on keyDown, before we know what chord (if any) is being typed, we need to "correct" the space (or lack thereof) once we find out what chord we're typing.

`spaceBeforeOutputCorrection(autoInserted:wantsSpace:)`:

| Auto-inserted before input? | Chord wants space? | Correction                                                      |
| --------------------------- | ------------------ | --------------------------------------------------------------- |
| yes                         | no                 | `.removeAutoInsertedSpace` → `backspacesBeforeOutput = 1`       |
| no                          | yes                | `.prependSpaceToOutput` → prepend `" "` to first output segment |
| yes                         | yes                | `.none`                                                         |
| no                          | no                 | `.none`                                                         |

---

## Case 5: Default mode — owed space before chord input

**Setup:** Chord `th→the`, mode `default`. Prior chord left `owedSpace=true`. User types `th` (owed space inserts before `t`).

**Result:** Replacement types `the` with no extra correction; auto-inserted space is kept because default mode wants space when auto-inserted.

```mermaid
sequenceDiagram
    participant User
    participant Engine as KeyboardInputEngine
    participant Chord as Chord th→the
    participant Replacer as TextReplacer
    participant Detection as ChordDetectionState
    participant Monitor as GlobalMonitor
    participant TargetApp as TargetApp

    User->>Engine: t keyDown (first key after prior chord)
    Engine->>Replacer: insertOwedSpaceBefore("t")
    Replacer->>TargetApp: backspace + type " t"
    Replacer-->>Engine: return 4
    Engine->>Detection: scheduleEchoes(4)
    Note over Engine: autoInsertedSpaceBeforeCurrentInput=true
    Engine->>Detection: keyDown(t)
    Monitor->>Engine: handleKeyDown ×4 (synthetic)
    Engine->>Detection: consumeEchoIfPending() ×4

    Note over User: User completes th chord hold…
    Engine->>Engine: handleChordMatch("ht")
    Engine->>Detection: beginReplacement()

    Engine->>Chord: resolveReplacement(autoInsertedSpaceBeforeInput: true)
    Note over Chord: wantsSpace=true (default + autoInserted)<br/>correction=.none<br/>segments=["the"]

    Engine->>Replacer: replaceViaSyntheticKeys
    Replacer->>TargetApp: delete " th", type "the"
    Replacer-->>Engine: return N
    Engine->>Detection: scheduleEchoes(N)
    Engine->>Engine: owedSpace=true (no pipe)
    Engine->>Detection: endReplacementIfNoPendingEchoes()
    Note over Detection: phase=.replacing until echoes consumed

    Monitor->>Engine: handleKeyDown/keyUp ×N (synthetic)
    Engine->>Detection: consumeEchoIfPending() ×N
    Note over Detection: last echo → finishReplacement() → idle
    Note over TargetApp: Field: "… the" (leading space retained)
```

---

## Case 6: Always mode — prepend space at replacement time

**Setup:** Chord `ab→hello`, mode `always`. No owed-space insertion ran (`autoInsertedSpaceBeforeInput=false`).

**Result:** Output is typed as ` hello` (space prepended to first segment).

```mermaid
sequenceDiagram
    participant Engine as KeyboardInputEngine
    participant Chord as Chord ab→hello (always)
    participant Replacer as TextReplacer
    participant Detection as ChordDetectionState
    participant Monitor as GlobalMonitor
    participant TargetApp as TargetApp

    Engine->>Engine: handleChordMatch("ab")
    Engine->>Detection: beginReplacement()
    Engine->>Chord: resolveReplacement(autoInsertedSpaceBeforeInput: false)

    Note over Chord: wantsSpace=true (always)<br/>correction=.prependSpaceToOutput<br/>segments=[" hello"]

    Engine->>Replacer: replaceViaSyntheticKeys
    Replacer->>TargetApp: delete "ab", type " hello"
    Replacer-->>Engine: return N
    Engine->>Detection: scheduleEchoes(N)
    Engine->>Detection: endReplacementIfNoPendingEchoes()
    Note over TargetApp: Leading space added in output text

    Monitor->>Engine: handleKeyDown/keyUp ×N (synthetic)
    Engine->>Detection: consumeEchoIfPending() ×N
    Note over Detection: last echo → finishReplacement() → idle
```

---

## Case 7: Never mode — remove auto-inserted space before output

**Setup:** Chord `ab→hello`, mode `never`. Owed-space insertion ran before the user typed `ab`.

**Result:** One extra backspace before typing output removes the unwanted leading space.

```mermaid
sequenceDiagram
    participant Engine as KeyboardInputEngine
    participant Chord as Chord ab→hello (never)
    participant Replacer as TextReplacer
    participant Detection as ChordDetectionState
    participant Monitor as GlobalMonitor
    participant TargetApp as TargetApp

    Note over Engine: autoInsertedSpaceBeforeCurrentInput=true<br/>(owed space inserted before "a")

    Engine->>Engine: handleChordMatch("ab")
    Engine->>Detection: beginReplacement()
    Engine->>Chord: resolveReplacement(autoInsertedSpaceBeforeInput: true)

    Note over Chord: wantsSpace=false (never)<br/>correction=.removeAutoInsertedSpace<br/>backspacesBeforeOutput=1

    Engine->>Replacer: replaceViaSyntheticKeys
    Replacer->>TargetApp: delete " ab"
    Replacer->>TargetApp: backspace × 1 (remove leading space)
    Replacer->>TargetApp: type "hello"
    Replacer-->>Engine: return N
    Engine->>Detection: scheduleEchoes(N)
    Engine->>Detection: endReplacementIfNoPendingEchoes()
    Note over TargetApp: No leading space before "hello"

    Monitor->>Engine: handleKeyDown/keyUp ×N (synthetic)
    Engine->>Detection: consumeEchoIfPending() ×N
    Note over Detection: last echo → finishReplacement() → idle
```

The Accessibility path uses the same `backspacesBeforeOutput` value: `AccessibilityReplacementVerification` extends the selection backward by one character when `leadingSpaceDeletionCount == 1`.

---

## End-to-end flow (overview)

```mermaid
flowchart TD
    Match[Chord matched] --> Replace[replaceCharacters]
    Replace --> Resolve[resolveReplacement]
    Resolve --> Wants{wantsSpace vs<br/>autoInserted?}
    Wants -->|prepend| Prepend[Prepend space to output]
    Wants -->|remove| Backspace[backspacesBeforeOutput = 1]
    Wants -->|none| NoFix[No space correction]
    Prepend --> Type[Type replacement via AX or CGEvent]
    Backspace --> Type
    NoFix --> Type
    Type --> Echo{CGEvent path?}
    Echo -->|yes| Schedule[scheduleEchoes on return]
    Echo -->|no| Post[updatePostReplacementSpacingState]
    Schedule --> Consume[Monitor consumes synthetic echoes]
    Consume --> Post
    Post --> Pipe{chord.hasPipe?}
    Pipe -->|no| Owed[owedSpace = true]
    Pipe -->|yes| NoOwed[owedSpace = false]

    Owed --> NextKey[Next letter keyDown]
    NextKey --> Insert[insertOwedSpaceBefore]
    Insert --> Echo1[scheduleEchoes on return]
    Echo1 --> Flag[autoInsertedSpaceBeforeCurrentInput = true]
    Flag --> Accum[Continue chord detection]
```

---

## Quick reference

| Scenario                                        | owedSpace after chord? | Space added how?                      |
| ----------------------------------------------- | ---------------------- | ------------------------------------- |
| `th→the` (no pipe)                              | yes                    | Next letter: backspace + ` ␣{letter}` |
| `ab→a\|b` (pipe)                                | no                     | —                                     |
| User presses space/backspace before next letter | cleared                | —                                     |
| User presses `.` before next letter             | cleared                | —                                     |
| Chord `always`, no auto-space                   | —                      | Prepended to replacement output       |
| Chord `never`, auto-space ran                   | —                      | Extra backspace before output         |
| Chord `default`, auto-space ran                 | —                      | No correction (space kept)            |
| Chord `default`, no auto-space                  | —                      | No leading space                      |

---

## Files to read alongside these diagrams

- [`KeyboardInputEngine.swift`](../Software%20Chording%20Keyboard/Services/KeyboardInputEngine.swift) — `owedSpace`, `handleKeyDown`, `updatePostReplacementSpacingState`
- [`Chord.swift`](../Software%20Chording%20Keyboard/Models/Chord.swift) — `ChordSpaceBeforeOutputMode`, `resolveReplacement`, `spaceBeforeOutputCorrection`
- [`TextReplacer.swift`](../Software%20Chording%20Keyboard/Services/TextReplacer.swift) — `insertOwedSpaceBefore`, `replaceViaSyntheticKeys`
- [`Constants.swift`](../Software%20Chording%20Keyboard/Constants/Constants.swift) — `skipPrecedingSpaceCharacters`
- [`Software_Chording_KeyboardTests.swift`](../Software%20Chording%20KeyboardTests/Software_Chording_KeyboardTests.swift) — `testKeyboardInputEngineOwedSpaceKeyDownSchedulesEchoesBeforeAccumulatingKeys`, `testSpaceBeforeOutputCorrectionMatrix`, `testResolveReplacementPrependsSpaceWhenNeeded`
