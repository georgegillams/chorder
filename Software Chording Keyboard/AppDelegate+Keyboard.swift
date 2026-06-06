//
//  AppDelegate+Keyboard.swift
//  Software Chording Keyboard
//

import AppKit
import Foundation

extension AppDelegate {
    func flagsChangedHandler(event: NSEvent) {
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
                capitalisationMode = .off
                return
            }

            // When shift is released again, but only if no other keys have been pressed in the meantime.
            switch capitalisationMode {
            case .off:
                capitalisationMode = .singleCharacter
            case .singleCharacter:
                capitalisationMode = .fullCapitalisation
            case .fullCapitalisation:
                capitalisationMode = .off
            }
        }
        gDebugPrint("shift pressed \(shiftPressedDown)")
    }

    func keyDownHandler(event: NSEvent) {
        if chordDetection.consumeEchoIfPending() {
            return
        }

        let eventKey = event.keyCode
        let character = event.characters
        gDebugPrint("eventKey \(eventKey) character \(character)")

        // Modifier shortcuts are not chord input; clear any in-progress detection.
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.function) {
            capitalisationMode = .off
            chordDetection.reset()
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = false
            return
        }

        if shiftPressedDown {
            gDebugPrint("Other keys pressed during shift")
            otherKeysPressedDuringShift = true
        }

        // Ignore space and backspace and clear held keys
        if eventKey == KeyboardConstants.spaceEventKey || eventKey == KeyboardConstants.tabEventKey || eventKey == KeyboardConstants.backspaceEventKey || eventKey == KeyboardConstants.returnEventKey || eventKey == KeyboardConstants.escapeEventKey {
            capitalisationMode = .off
            chordDetection.reset()
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = false
            return
        }

        // If navigating through text, clear everything
        if eventKey == KeyboardConstants.leftEventKey || eventKey == KeyboardConstants.rightEventKey {
            capitalisationMode = .off
            chordDetection.reset()
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = false
            return
        }

        if KeyboardConstants.skipPrecedingSpaceCharacters.contains(character ?? "") {
            if owedSpace {
                gDebugPrint("Dropping owed space due to punctuation!")
            }
            owedSpace = false
        }

        gDebugPrint("owedSpace \(owedSpace)")
        gDebugPrint("char \(character)")

        if owedSpace {
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = true

            gDebugPrint("ADDING SPACE")
            chordDetection.scheduleEchoes(textReplacer.insertOwedSpaceBefore(character: character ?? ""))
        }

        chordDetection.keyDown(
            keyCode: eventKey,
            character: character,
            holdDuration: appModel.appSettings.millisecondsToHold / 1000
        )
        gDebugPrint("chordDetection phase \(chordDetection.phase) joined \(chordDetection.joinedCharactersLowercased())")
    }

    func keyUpHandler(event: NSEvent) {
        if chordDetection.consumeEchoIfPending() {
            return
        }

        chordDetection.keyUp(
            keyCode: event.keyCode,
            holdDuration: appModel.appSettings.millisecondsToHold / 1000
        )
        gDebugPrint("chordDetection phase \(chordDetection.phase) joined \(chordDetection.joinedCharactersLowercased())")
    }

    func handleChordMatch(normalisedInputKey: String) {
        guard let chord = appModel.appSettings.alphabeticalInputOutputMappingDictionary[normalisedInputKey] else {
            gDebugPrint("No chord for normalised input '\(normalisedInputKey)'")
            chordDetection.resumeAccumulating()
            return
        }

        gDebugPrint("** Matched chord: \(chord.input)")
        chordDetection.beginReplacement()

        replaceCharacters(chord: chord)
        appModel.appSettings.incrementUsage(for: chord)
        appModel.appSettings.setUsageCountDirty()
        capitalisationMode = .off

        chordDetection.endReplacementIfNoPendingEchoes()
    }

    func replaceCharacters(chord: Chord) {
        let resolved = chord.resolveReplacement(
            capitalisationMode: calculatedCapitalisationMode,
            autoInsertedSpaceBeforeInput: autoInsertedSpaceBeforeCurrentInput
        )

        if appModel.appSettings.useAccessibilityAPI && textReplacer.replaceViaAccessibility(chord: chord, resolved: resolved) {
            gDebugPrint("replaced via AX")
            updatePostReplacementSpacingState(for: chord)
            return
        }

        gDebugPrint("AX replacement disabled or failed, falling back to CGEvent")
        chordDetection.scheduleEchoes(textReplacer.replaceViaSyntheticKeys(chord: chord, resolved: resolved))
        updatePostReplacementSpacingState(for: chord)
    }

    func updatePostReplacementSpacingState(for chord: Chord) {
        autoInsertedSpaceBeforeCurrentInput = false
        owedSpace = !chord.hasPipe
    }
}
