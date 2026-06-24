//
//  KeyboardInputEngine.swift
//  Chorder
//

import AppKit
import Foundation

protocol KeyboardInputEngineDelegate: AnyObject {
    func keyboardInputEngine(_ engine: KeyboardInputEngine, capitalisationModeDidChange mode: CapitalisationMode)
}

/// Handles global keyboard input: chord detection, replacement, spacing, and capitalisation.
final class KeyboardInputEngine {
    weak var delegate: KeyboardInputEngineDelegate?

    private let appSettings: AppSettings
    private let chordDetection = ChordDetectionState()
    private let textReplacer = TextReplacer()

    private var owedSpace = false
    private var autoInsertedSpaceBeforeCurrentInput = false
    private var shiftPressedDown = false
    private(set) var capitalisationMode = CapitalisationMode.off
    private var otherKeysPressedDuringShift = false

    var calculatedCapitalisationMode: CapitalisationMode {
        if shiftPressedDown {
            return .fullCapitalisation
        }
        return capitalisationMode
    }

    var owesTrailingSpace: Bool { owedSpace }
    var joinedHeldCharacters: String { chordDetection.joinedCharactersLowercased() }

    init(appSettings: AppSettings) {
        self.appSettings = appSettings

        chordDetection.onChordMatched = { [weak self] normalisedInputKey in
            self?.handleChordMatch(normalisedInputKey: normalisedInputKey)
        }
        chordDetection.isRegisteredChord = { [weak self] normalisedKey in
            guard let self else { return false }
            return self.appSettings.alphabeticalInputOutputMappingDictionary[normalisedKey] != nil
        }
    }

    func handleFlagsChanged(_ event: NSEvent) {
        // This is fired whenever shift is toggled, but we have to track its state ourselves
        if event.modifierFlags.contains(.shift) {
            shiftPressedDown = true
        } else if shiftPressedDown {
            shiftPressedDown = false

            // Remove all characters. There's a strange issue where, sometimes, after shift is released, the characters typed with shift pressed (eg @) remain in the held-key set.
            // This solves it by clearing held keys when shift is released.
            chordDetection.reset()
            autoInsertedSpaceBeforeCurrentInput = false

            // If characters were entered while holding shift, then we'll assume the intent of holding shift was to capitalise those letters, and not to turn on capitilisation mode
            if otherKeysPressedDuringShift {
                otherKeysPressedDuringShift = false
                setCapitalisationMode(.off)
                return
            }

            // When shift is released again, but only if no other keys have been pressed in the meantime.
            switch capitalisationMode {
            case .off:
                setCapitalisationMode(.singleCharacter)
            case .singleCharacter:
                setCapitalisationMode(.fullCapitalisation)
            case .fullCapitalisation:
                setCapitalisationMode(.off)
            }
        }
        gDebugPrint("shift pressed \(shiftPressedDown)")
    }

    func handleKeyDown(_ event: NSEvent) {
        let eventKey = event.keyCode
        let character = event.characters
        gDebugPrint("eventKey \(eventKey) character \(character ?? "")")

        // Modifier shortcuts are not chord input; clear any in-progress detection.
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.function) {
            resetChordInputState()
            return
        }

        if chordDetection.consumeEchoIfPending() {
            return
        }

        if shiftPressedDown {
            gDebugPrint("Other keys pressed during shift")
            otherKeysPressedDuringShift = true
        }

        // Ignore space and backspace and clear held keys
        if eventKey == KeyboardConstants.spaceEventKey || eventKey == KeyboardConstants.tabEventKey || eventKey == KeyboardConstants.backspaceEventKey || eventKey == KeyboardConstants.returnEventKey || eventKey == KeyboardConstants.escapeEventKey {
            resetChordInputState()
            return
        }

        // If navigating through text, clear everything
        if eventKey == KeyboardConstants.leftEventKey || eventKey == KeyboardConstants.rightEventKey {
            resetChordInputState()
            return
        }

        if KeyboardConstants.skipPrecedingSpaceCharacters.contains(character ?? "") {
            if owedSpace {
                gDebugPrint("Dropping owed space due to punctuation!")
            }
            owedSpace = false
        }

        gDebugPrint("owedSpace \(owedSpace)")
        gDebugPrint("char \(character ?? "")")

        if owedSpace {
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = true

            gDebugPrint("ADDING SPACE")
            chordDetection.scheduleEchoes(textReplacer.insertOwedSpaceBefore(character: character ?? ""))
        }

        chordDetection.keyDown(
            keyCode: eventKey,
            character: character,
            holdDuration: appSettings.millisecondsToHold / 1000
        )
        gDebugPrint("chordDetection phase \(chordDetection.phase) joined \(chordDetection.joinedCharactersLowercased())")
    }

    func handleKeyUp(_ event: NSEvent) {
        if chordDetection.consumeEchoIfPending() {
            return
        }

        chordDetection.keyUp(
            keyCode: event.keyCode,
            holdDuration: appSettings.millisecondsToHold / 1000
        )
        gDebugPrint("chordDetection phase \(chordDetection.phase) joined \(chordDetection.joinedCharactersLowercased())")
    }

    func handleChordMatch(normalisedInputKey: String) {
        guard let chord = appSettings.alphabeticalInputOutputMappingDictionary[normalisedInputKey] else {
            gDebugPrint("No chord for normalised input '\(normalisedInputKey)'")
            chordDetection.resumeAccumulating()
            return
        }

        gDebugPrint("** Matched chord: \(chord.input)")
        chordDetection.beginReplacement()

        replaceCharacters(chord: chord)
        appSettings.incrementUsage(for: chord)
        setCapitalisationMode(.off)

        chordDetection.endReplacementIfNoPendingEchoes()
    }

    private func replaceCharacters(chord: Chord) {
        let resolved = chord.resolveReplacement(
            capitalisationMode: calculatedCapitalisationMode,
            autoInsertedSpaceBeforeInput: autoInsertedSpaceBeforeCurrentInput
        )

        if appSettings.useAccessibilityAPI {

            // There are numerous reasons that this could fail and return false, in which case we'll fall back to replaceViaSyntheticKeys
            if textReplacer.replaceViaAccessibility(chord: chord, resolved: resolved) {
                gDebugPrint("replaced via AX")
                updatePostReplacementSpacingState(for: chord)
                return
            }

        } else {
            gDebugPrint("AX: skipped — useAccessibilityAPI setting is off")
        }

        gDebugPrint("using CGEvent synthetic key replacement")
        chordDetection.scheduleEchoes(textReplacer.replaceViaSyntheticKeys(chord: chord, resolved: resolved))
        updatePostReplacementSpacingState(for: chord)
    }

    private func updatePostReplacementSpacingState(for chord: Chord) {
        autoInsertedSpaceBeforeCurrentInput = false
        owedSpace = !chord.hasPipe
    }

    /// Clears in-progress chord detection when input is interrupted (modifiers, navigation, special keys).
    private func resetChordInputState() {
        setCapitalisationMode(.off)
        chordDetection.reset()
        owedSpace = false
        autoInsertedSpaceBeforeCurrentInput = false
    }

    private func setCapitalisationMode(_ mode: CapitalisationMode) {
        guard capitalisationMode != mode else { return }
        capitalisationMode = mode
        delegate?.keyboardInputEngine(self, capitalisationModeDidChange: mode)
    }
}
