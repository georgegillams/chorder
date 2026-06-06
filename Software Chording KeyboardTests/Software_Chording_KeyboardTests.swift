//
//  Software_Chording_KeyboardTests.swift
//  Software Chording KeyboardTests
//
//  Created by George Gillams on 05/04/2023.
//

import AppKit
import XCTest
@testable import Software_Chording_Keyboard

final class Software_Chording_KeyboardTests: XCTestCase {

    func testNormalisedInputKeyTreatsPermutationsAndCaseAsEqual() {
        XCTAssertEqual(Chord.normalisedInputKey(for: "Ab"), Chord.normalisedInputKey(for: "ab"))
        XCTAssertEqual(Chord.normalisedInputKey(for: "Ab"), Chord.normalisedInputKey(for: "ba"))
        XCTAssertEqual(Chord.normalisedInputKey(for: "Ab"), Chord.normalisedInputKey(for: "BA"))
    }

    func testMergedUsageKeepsHighestCountPerMachine() {
        let existing = ["machine-a": 5, "machine-b": 3]
        let incoming = ["machine-a": 7, "machine-c": 1]
        let merged = Chord.mergedUsage(existing, incoming)
        XCTAssertEqual(merged["machine-a"], 7)
        XCTAssertEqual(merged["machine-b"], 3)
        XCTAssertEqual(merged["machine-c"], 1)
    }

    func testEmbeddedUsageIsDecodedForMigrationOnly() throws {
        let json = """
        {
          "millisecondsToHold": "100ms",
          "chords": [
            {
              "input": "abc",
              "output": "hello",
              "usageCount": "12"
            }
          ]
        }
        """
        let settings = try JSONDecoder().decode(LegacySerialisableAppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.chords.first?.resolvedUsage?[Chord.legacyUsageMachineKey], 12)
    }

    func testSettingsChordEncodingOmitsUsage() throws {
        let chord = SerialisableChord(
            id: "chord-1",
            input: "abc",
            output: "hello",
            capitalisationMode: "default",
            spaceBeforeOutput: "always"
        )
        let json = String(data: try JSONEncoder().encode(chord), encoding: .utf8)!
        XCTAssertFalse(json.contains("usage"))
        XCTAssertFalse(json.contains("usageCount"))
        XCTAssertTrue(json.contains("spaceBeforeOutput"))
        XCTAssertTrue(json.contains("always"))
    }

    func testSpaceBeforeOutputModeDefaultsWhenMissingFromSettings() throws {
        let json = """
        {
          "millisecondsToHold": "100ms",
          "chords": [
            {
              "id": "chord-1",
              "input": "abc",
              "output": "hello"
            }
          ]
        }
        """
        let settings = try JSONDecoder().decode(SerialisableAppSettings.self, from: Data(json.utf8))
        XCTAssertNil(settings.chords.first?.spaceBeforeOutput)
    }

    func testWantsSpaceBeforeInputWhenTypedRespectsMode() {
        let defaultChord = Chord(input: "ab", output: "hello")
        XCTAssertTrue(defaultChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: true))
        XCTAssertFalse(defaultChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: false))

        let pipedDefaultChord = Chord(input: "ab", output: "hel|lo")
        XCTAssertFalse(pipedDefaultChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: true))
        XCTAssertFalse(pipedDefaultChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: false))

        let alwaysChord = Chord(input: "ab", output: "hel|lo", spaceBeforeOutputMode: .always)
        XCTAssertTrue(alwaysChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: false))

        let neverChord = Chord(input: "ab", output: "hello", spaceBeforeOutputMode: .never)
        XCTAssertFalse(neverChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: true))
    }

    func testSpaceBeforeOutputCorrectionMatrix() {
        XCTAssertEqual(
            Chord.spaceBeforeOutputCorrection(autoInserted: true, wantsSpace: false),
            .removeAutoInsertedSpace
        )
        XCTAssertEqual(
            Chord.spaceBeforeOutputCorrection(autoInserted: false, wantsSpace: true),
            .prependSpaceToOutput
        )
        XCTAssertEqual(
            Chord.spaceBeforeOutputCorrection(autoInserted: true, wantsSpace: true),
            .none
        )
        XCTAssertEqual(
            Chord.spaceBeforeOutputCorrection(autoInserted: false, wantsSpace: false),
            .none
        )
    }

    func testResolveReplacementPrependsSpaceWhenNeeded() {
        let chord = Chord(
            input: "ab",
            output: "hello",
            spaceBeforeOutputMode: .always
        )
        let resolved = chord.resolveReplacement(autoInsertedSpaceBeforeInput: false)
        XCTAssertTrue(resolved.segments.first?.hasPrefix(" ") ?? false)
        XCTAssertEqual(resolved.backspacesBeforeOutput, 0)
    }

    func testResolveReplacementDefaultDoesNotPrependWithoutAutoInsertedSpace() {
        let chord = Chord(input: "ab", output: "hello", spaceBeforeOutputMode: .default)
        let resolved = chord.resolveReplacement(autoInsertedSpaceBeforeInput: false)
        XCTAssertEqual(resolved.segments.joined(), "hello")
        XCTAssertEqual(resolved.backspacesBeforeOutput, 0)
    }

    func testResolveReplacementBackspacesBeforeOutputWhenNeverAndAutoInserted() {
        let chord = Chord(
            input: "ab",
            output: "hello",
            spaceBeforeOutputMode: .never
        )
        let resolved = chord.resolveReplacement(autoInsertedSpaceBeforeInput: true)
        XCTAssertEqual(resolved.segments.joined(), "hello")
        XCTAssertEqual(resolved.backspacesBeforeOutput, 1)
    }

    func testResolvedReplacementOutputTextJoinsSegments() {
        let chord = Chord(input: "ab", output: "a|b")
        let resolved = chord.resolveReplacement(autoInsertedSpaceBeforeInput: false)
        XCTAssertEqual(resolved.outputText, resolved.segments.joined())
    }

    func testResolvedReplacementSyntheticKeyEchoCount() {
        let chord = Chord(input: "th", output: "the")
        let resolved = chord.resolveReplacement(autoInsertedSpaceBeforeInput: false)
        XCTAssertEqual(
            resolved.syntheticKeyEchoCount(inputDeleteCount: chord.deleteCount),
            (2 * (chord.deleteCount + 1 + resolved.backspacesBeforeOutput + resolved.leftArrowCount))
                + (2 * resolved.segments.count) + 2
        )
    }

    func testAccessibilityReplacementVerificationMatchesSortedInput() {
        XCTAssertTrue(AccessibilityReplacementVerification.sortedInputMatches("ht", chordInput: "th"))
        XCTAssertFalse(AccessibilityReplacementVerification.sortedInputMatches("to", chordInput: "th"))
    }

    func testAccessibilityReplacementVerificationComputesSelectionRange() {
        let result = AccessibilityReplacementVerification.verifiedSelection(
            fieldValue: " th",
            cursorRange: CFRange(location: 3, length: 0),
            chordInput: "th",
            leadingSpaceDeletionCount: 1
        )
        guard case let .success(verified) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(verified.startIndex, 0)
        XCTAssertEqual(verified.selectRange, CFRange(location: 0, length: 3))
    }

    func testAccessibilityReplacementVerificationRejectsMissingLeadingSpace() {
        guard case .failure(.expectedLeadingSpace(at: 0, found: "x")) = AccessibilityReplacementVerification.verifiedSelection(
            fieldValue: "xth",
            cursorRange: CFRange(location: 3, length: 0),
            chordInput: "th",
            leadingSpaceDeletionCount: 1
        ) else {
            XCTFail("expected expectedLeadingSpace failure")
        }
    }

    func testAccessibilityReplacementVerificationSelectedTextPrefix() {
        guard case .success = AccessibilityReplacementVerification.verifySelectedText(
            " th",
            chordInput: "th",
            leadingSpaceDeletionCount: 1
        ) else {
            XCTFail("expected success")
        }
        guard case .failure(.selectedTextMismatch(found: "to", expected: "th")) =
            AccessibilityReplacementVerification.verifySelectedText(
                " to",
                chordInput: "th",
                leadingSpaceDeletionCount: 1
            )
        else {
            XCTFail("expected selectedTextMismatch failure")
        }
    }

    func testAccessibilityReplacementVerificationPipeCursorLocation() {
        XCTAssertEqual(
            AccessibilityReplacementVerification.pipeCursorLocation(afterInsertionEnd: 10, leftArrowCount: 3),
            7
        )
        XCTAssertEqual(
            AccessibilityReplacementVerification.pipeCursorLocation(afterInsertionEnd: 2, leftArrowCount: 5),
            0
        )
    }

    func testChordAssignsIdOnCreation() {
        let chord = Chord(input: "abc", output: "hello")
        XCTAssertFalse(chord.id.isEmpty)
    }

    func testIncrementUsageCountTracksPerMachine() {
        let chord = Chord(id: "chord-1", input: "abc", output: "hello")
        chord.incrementUsageCount(for: "machine-a")
        chord.incrementUsageCount(for: "machine-a")
        chord.incrementUsageCount(for: "machine-b")
        XCTAssertEqual(chord.usageByMachine["machine-a"], 2)
        XCTAssertEqual(chord.usageByMachine["machine-b"], 1)
        XCTAssertEqual(chord.totalUsageCount, 3)
    }

    func testLoadAllMachineUsageAggregatesStatsFilesByChordId() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let machineAStats = MachineUsageStats(usageByChordId: ["chord-1": 4, "chord-2": 1])
        let machineBStats = MachineUsageStats(usageByChordId: ["chord-1": 2, "chord-3": 3])
        try ChordUsageStore.saveMachineUsage(
            machineAStats,
            to: ChordUsageStore.statsFileURL(for: "machine-a", in: root)
        )
        try ChordUsageStore.saveMachineUsage(
            machineBStats,
            to: ChordUsageStore.statsFileURL(for: "machine-b", in: root)
        )

        let aggregated = ChordUsageStore.loadAllMachineUsage(from: root)
        XCTAssertEqual(aggregated["machine-a"]?["chord-1"], 4)
        XCTAssertEqual(aggregated["machine-b"]?["chord-1"], 2)
        XCTAssertEqual(aggregated["machine-b"]?["chord-3"], 3)
    }

    func testMigrateInputBasedStatsToChordIds() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let chord = Chord(id: "chord-1", input: "abc", output: "hello")

        let statsURL = ChordUsageStore.statsFileURL(for: "machine-a", in: root)
        try ChordUsageStore.saveMachineUsage(
            MachineUsageStats(legacyUsageByInput: ["abc": 7]),
            to: statsURL
        )

        XCTAssertTrue(SettingsMigration.migrateInputBasedStatsToChordIds(
            chords: [chord],
            settingsRootDirectory: root
        ))

        let migrated = ChordUsageStore.loadMachineUsage(from: statsURL)
        XCTAssertEqual(migrated?.usageByChordId["chord-1"], 7)
        XCTAssertTrue(migrated?.legacyUsageByInput.isEmpty ?? false)
    }

    func testChordDetectionNormalisedKeyIsOrderIndependent() {
        let detection = ChordDetectionState()
        detection.keyDown(keyCode: 17, character: "t", holdDuration: 1)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: 1)
        XCTAssertEqual(detection.normalisedInputKey(), "ht")
        XCTAssertEqual(detection.joinedCharactersLowercased(), "th")
    }

    func testChordDetectionIgnoresKeyRepeat() {
        let detection = ChordDetectionState()
        detection.keyDown(keyCode: 17, character: "t", holdDuration: 1)
        detection.keyDown(keyCode: 17, character: "t", holdDuration: 1)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: 1)
        XCTAssertEqual(detection.joinedCharactersLowercased(), "th")
    }

    func testChordDetectionKeyUpRemovesByKeyCode() {
        let detection = ChordDetectionState()
        detection.keyDown(keyCode: 17, character: "t", holdDuration: 1)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: 1)
        detection.keyUp(keyCode: 17, holdDuration: 1)
        XCTAssertEqual(detection.joinedCharactersLowercased(), "h")
        XCTAssertEqual(detection.phase, .accumulating)
    }

    func testChordDetectionFiresAfterHoldWhenStable() {
        let detection = ChordDetectionState()
        let holdDuration: TimeInterval = 0.05
        let expectation = expectation(description: "chord matched")

        detection.isRegisteredChord = { $0 == "ht" }
        detection.onChordMatched = { normalisedKey in
            XCTAssertEqual(normalisedKey, "ht")
            expectation.fulfill()
        }

        detection.keyDown(keyCode: 17, character: "t", holdDuration: holdDuration)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: holdDuration)

        waitForExpectations(timeout: 1)
    }

    func testChordDetectionFiresShorterChordImmediatelyWhenLongerAlsoConfigured() {
        let detection = ChordDetectionState()
        let holdDuration: TimeInterval = 0.05
        var matchedKeys: [String] = []

        detection.isRegisteredChord = { ["ht", "hit"].contains($0) }
        detection.onChordMatched = { normalisedKey in
            matchedKeys.append(normalisedKey)
        }

        detection.keyDown(keyCode: 17, character: "t", holdDuration: holdDuration)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: holdDuration)

        let holdExpectation = expectation(description: "hold completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration + 0.02) {
            holdExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(matchedKeys, ["ht"])
    }

    func testChordDetectionDoesNotFireWhenKeysChangeBeforeHoldCompletes() {
        let detection = ChordDetectionState()
        let holdDuration: TimeInterval = 0.1
        var matchedKeys: [String] = []

        detection.isRegisteredChord = { ["ht", "hit"].contains($0) }
        detection.onChordMatched = { normalisedKey in
            matchedKeys.append(normalisedKey)
        }

        detection.keyDown(keyCode: 17, character: "t", holdDuration: holdDuration)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: holdDuration)
        detection.keyDown(keyCode: 34, character: "i", holdDuration: holdDuration)

        let holdExpectation = expectation(description: "thi hold window elapses")
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration + 0.02) {
            holdExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(matchedKeys, ["hit"])
    }

    func testChordDetectionResetClearsHeldKeys() {
        let detection = ChordDetectionState()
        detection.keyDown(keyCode: 17, character: "t", holdDuration: 1)
        detection.keyDown(keyCode: 4, character: "h", holdDuration: 1)
        detection.reset()
        XCTAssertEqual(detection.phase, .idle)
        XCTAssertEqual(detection.joinedCharactersLowercased(), "")
    }

    func testChordDetectionConsumesScheduledEchoes() {
        let detection = ChordDetectionState()
        detection.scheduleEchoes(3)
        XCTAssertTrue(detection.consumeEchoIfPending())
        XCTAssertTrue(detection.consumeEchoIfPending())
        XCTAssertTrue(detection.consumeEchoIfPending())
        XCTAssertFalse(detection.consumeEchoIfPending())
    }

    func testChordDetectionDefersReplacementFinishUntilEchoesDrain() {
        let detection = ChordDetectionState()
        detection.beginReplacement()
        detection.scheduleEchoes(2)
        detection.endReplacementIfNoPendingEchoes()
        XCTAssertEqual(detection.phase, .replacing)

        XCTAssertTrue(detection.consumeEchoIfPending())
        XCTAssertEqual(detection.phase, .replacing)

        XCTAssertTrue(detection.consumeEchoIfPending())
        XCTAssertEqual(detection.phase, .idle)
    }

    func testChordDetectionFinishesReplacementImmediatelyWithoutEchoes() {
        let detection = ChordDetectionState()
        detection.beginReplacement()
        detection.endReplacementIfNoPendingEchoes()
        XCTAssertEqual(detection.phase, .idle)
    }

    func testDecomposedOutputMarksMultipleUnescapedPipesInvalid() {
        let result = Chord.decomposedOutput(for: "a|b|c")
        XCTAssertTrue(result.invalid)
    }

    func testIsValidOutputAcceptsSinglePipeAndEscapedPipes() {
        XCTAssertTrue(Chord.isValidOutput("hello"))
        XCTAssertTrue(Chord.isValidOutput("hel|lo"))
        XCTAssertTrue(Chord.isValidOutput("a\\|b|c"))
    }

    func testIsValidOutputRejectsMultipleUnescapedPipes() {
        XCTAssertFalse(Chord.isValidOutput("a|b|c"))
    }

    func testInvalidOutputClearsDerivedState() {
        let chord = Chord(input: "ab", output: "hello")
        XCTAssertFalse(chord.outputChunks.isEmpty)

        chord.update(
            input: "ab",
            output: "a|b|c",
            capitalisationMode: .default,
            spaceBeforeOutputMode: .default
        )

        XCTAssertTrue(chord.hasInvalidOutput)
        XCTAssertTrue(chord.outputChunks.isEmpty)
        XCTAssertFalse(chord.hasPipe)
        XCTAssertEqual(chord.pipeNegativePosition, 0)
    }

    func testResolveTypingSegmentsReturnsEmptyForInvalidOutput() {
        let chord = Chord(input: "ab", output: "hello")
        chord.update(
            input: "ab",
            output: "x|y|z",
            capitalisationMode: .default,
            spaceBeforeOutputMode: .default
        )

        let (segments, leftArrowCount) = chord.resolveTypingSegments()
        XCTAssertTrue(segments.isEmpty)
        XCTAssertEqual(leftArrowCount, 0)
    }

    func testHasDuplicateInputLettersDetectsRepeatedCharacters() {
        XCTAssertFalse(Chord.hasDuplicateInputLetters("th"))
        XCTAssertTrue(Chord.hasDuplicateInputLetters("tt"))
        XCTAssertTrue(Chord.hasDuplicateInputLetters("book"))
    }

    func testParseHoldDelayMillisecondsValidatesRange() {
        XCTAssertEqual(AppSettings.parseHoldDelayMilliseconds(from: "100ms"), 100)
        XCTAssertEqual(AppSettings.parseHoldDelayMilliseconds(from: "10"), 10)
        XCTAssertNil(AppSettings.parseHoldDelayMilliseconds(from: "5ms"))
        XCTAssertNil(AppSettings.parseHoldDelayMilliseconds(from: "5000ms"))
        XCTAssertNil(AppSettings.parseHoldDelayMilliseconds(from: "abc"))
    }

    func testNormalisedInputToChordIdUsesSortedKeys() {
        let chords = [
            Chord(id: "a", input: "ba", output: "one"),
            Chord(id: "b", input: "ab", output: "two"),
        ]
        let map = SettingsMigration.normalisedInputToChordId(chords: chords)
        XCTAssertEqual(map["ab"], "b")
    }

    func testMigrateInputBasedStatsMatchesNormalisedInput() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let chord = Chord(id: "chord-1", input: "ba", output: "hello")
        let statsURL = ChordUsageStore.statsFileURL(for: "machine-a", in: root)
        try ChordUsageStore.saveMachineUsage(
            MachineUsageStats(legacyUsageByInput: ["ab": 9]),
            to: statsURL
        )

        XCTAssertTrue(SettingsMigration.migrateInputBasedStatsToChordIds(
            chords: [chord],
            settingsRootDirectory: root
        ))

        let migrated = ChordUsageStore.loadMachineUsage(from: statsURL)
        XCTAssertEqual(migrated?.usageByChordId["chord-1"], 9)
    }

    func testSettingsMigrationSkipsWhenVersionIsCurrent() {
        let settings = AppSettings()
        settings.setMigrationVersion(SettingsMigration.currentMigrationVersion)
        XCTAssertFalse(SettingsMigration.run(on: settings))
    }

    // MARK: - KeyboardInputEngine

    func testKeyboardInputEngineShiftReleaseCyclesCapitalisationMode() {
        let engine = KeyboardInputEngine(appSettings: AppSettings())
        let delegate = KeyboardInputEngineDelegateMock()
        engine.delegate = delegate

        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: .shift))
        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: []))
        XCTAssertEqual(engine.capitalisationMode, .singleCharacter)

        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: .shift))
        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: []))
        XCTAssertEqual(engine.capitalisationMode, .fullCapitalisation)

        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: .shift))
        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: []))
        XCTAssertEqual(engine.capitalisationMode, .off)

        XCTAssertEqual(delegate.modes, [.singleCharacter, .fullCapitalisation, .off])
    }

    func testKeyboardInputEngineShiftReleaseWithInterveningKeyDoesNotCycleCapitalisation() {
        let engine = KeyboardInputEngine(appSettings: AppSettings())
        let delegate = KeyboardInputEngineDelegateMock()
        engine.delegate = delegate

        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: .shift))
        engine.handleKeyDown(Self.keyDownEvent(keyCode: 17, characters: "t")!)
        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: []))

        XCTAssertEqual(engine.capitalisationMode, .off)
        XCTAssertTrue(delegate.modes.isEmpty)
    }

    func testKeyboardInputEngineModifierKeyDownResetsSpacingState() {
        let settings = AppSettings()
        settings.useAccessibilityAPI = false
        let chord = Chord(input: "th", output: "the")
        settings.addChord(chord: chord)

        let engine = KeyboardInputEngine(appSettings: settings)
        engine.handleChordMatch(normalisedInputKey: "ht")
        XCTAssertTrue(engine.owesTrailingSpace)

        engine.handleKeyDown(Self.keyDownEvent(keyCode: 17, characters: "a", modifierFlags: .command)!)
        XCTAssertFalse(engine.owesTrailingSpace)
        XCTAssertEqual(engine.joinedHeldCharacters, "")
    }

    func testKeyboardInputEngineChordMatchSetsOwesTrailingSpaceFromPipe() {
        let settings = AppSettings()
        settings.useAccessibilityAPI = false

        let withoutPipe = Chord(input: "th", output: "the")
        settings.addChord(chord: withoutPipe)
        let withPipe = Chord(input: "ab", output: "a|b")
        settings.addChord(chord: withPipe)

        let engine = KeyboardInputEngine(appSettings: settings)

        engine.handleChordMatch(normalisedInputKey: "ht")
        XCTAssertTrue(engine.owesTrailingSpace)

        engine.handleChordMatch(normalisedInputKey: "ab")
        XCTAssertFalse(engine.owesTrailingSpace)
    }

    func testKeyboardInputEngineOwedSpaceKeyDownSchedulesEchoesBeforeAccumulatingKeys() {
        let settings = AppSettings()
        settings.useAccessibilityAPI = false
        let chord = Chord(input: "th", output: "the")
        settings.addChord(chord: chord)

        let engine = KeyboardInputEngine(appSettings: settings)
        engine.handleChordMatch(normalisedInputKey: "ht")
        XCTAssertTrue(engine.owesTrailingSpace)

        let resolved = chord.resolveReplacement(
            capitalisationMode: .off,
            autoInsertedSpaceBeforeInput: false
        )
        let replacementEchoCount = resolved.syntheticKeyEchoCount(inputDeleteCount: chord.deleteCount)

        for _ in 0..<replacementEchoCount {
            engine.handleKeyDown(Self.keyDownEvent(keyCode: 0, characters: "*")!)
        }

        engine.handleKeyDown(Self.keyDownEvent(keyCode: 4, characters: "h")!)
        XCTAssertEqual(engine.joinedHeldCharacters, "h")

        for _ in 0..<4 {
            engine.handleKeyDown(Self.keyDownEvent(keyCode: 0, characters: "*")!)
            XCTAssertEqual(engine.joinedHeldCharacters, "h")
        }

        engine.handleKeyDown(Self.keyDownEvent(keyCode: 17, characters: "t")!)
        XCTAssertEqual(engine.joinedHeldCharacters, "ht")
    }

    private static func flagsChangedEvent(modifierFlags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.otherEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0
        )!
    }

    private static func keyDownEvent(
        keyCode: UInt16,
        characters: String,
        modifierFlags: NSEvent.ModifierFlags = []
    ) -> NSEvent? {
        let utf16 = Array(characters.utf16)
        guard let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) else {
            return nil
        }
        cgEvent.flags = CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
        cgEvent.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        return NSEvent(cgEvent: cgEvent)
    }
}

private final class KeyboardInputEngineDelegateMock: KeyboardInputEngineDelegate {
    private(set) var modes: [CapitalisationMode] = []

    func keyboardInputEngine(_ engine: KeyboardInputEngine, capitalisationModeDidChange mode: CapitalisationMode) {
        modes.append(mode)
    }
}
