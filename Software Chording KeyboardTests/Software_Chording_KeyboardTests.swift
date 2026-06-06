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
        XCTAssertTrue(pipedDefaultChord.wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: true))
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
        XCTAssertEqual(verified.selectRange.location, 0)
        XCTAssertEqual(verified.selectRange.length, 3)
    }

    func testAccessibilityReplacementVerificationRejectsMissingLeadingSpace() {
        guard case .failure(.expectedLeadingSpace(at: 0, found: "x")) = AccessibilityReplacementVerification.verifiedSelection(
            fieldValue: "xth",
            cursorRange: CFRange(location: 3, length: 0),
            chordInput: "th",
            leadingSpaceDeletionCount: 1
        ) else {
            return XCTFail("expected expectedLeadingSpace failure")
        }
    }

    func testAccessibilityReplacementVerificationSelectedTextPrefix() {
        guard case .success = AccessibilityReplacementVerification.verifySelectedText(
            " th",
            chordInput: "th",
            leadingSpaceDeletionCount: 1
        ) else {
            return XCTFail("expected success")
        }
        guard case .failure(.selectedTextMismatch(found: "to", expected: "th")) =
            AccessibilityReplacementVerification.verifySelectedText(
                " to",
                chordInput: "th",
                leadingSpaceDeletionCount: 1
            )
        else {
            return XCTFail("expected selectedTextMismatch failure")
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
        let settings = Self.makeTestSettings()
        settings.setMigrationVersion(SettingsMigration.currentMigrationVersion)
        XCTAssertFalse(SettingsMigration.run(on: settings))
    }

    // MARK: - KeyboardInputEngine

    func testKeyboardInputEngineShiftReleaseCyclesCapitalisationMode() {
        let engine = KeyboardInputEngine(appSettings: Self.makeTestSettings())
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
        let engine = KeyboardInputEngine(appSettings: Self.makeTestSettings())
        let delegate = KeyboardInputEngineDelegateMock()
        engine.delegate = delegate

        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: .shift))
        engine.handleKeyDown(Self.keyDownEvent(keyCode: 17, characters: "t")!)
        engine.handleFlagsChanged(Self.flagsChangedEvent(modifierFlags: []))

        XCTAssertEqual(engine.capitalisationMode, .off)
        XCTAssertTrue(delegate.modes.isEmpty)
    }

    func testKeyboardInputEngineModifierKeyDownResetsSpacingState() {
        let settings = Self.makeTestSettings()
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
        let settings = Self.makeTestSettings()
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
        let settings = Self.makeTestSettings()
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

    // MARK: - OutputPlaceholderExpansion

    func testOutputPlaceholderExpansionLeavesPlainTextUnchanged() {
        XCTAssertEqual(OutputPlaceholderExpansion.expand("hello world"), "hello world")
    }

    func testOutputPlaceholderExpansionReplacesDateTokens() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 5
        components.hour = 14
        components.minute = 30
        let reference = Calendar.current.date(from: components)!

        XCTAssertEqual(
            OutputPlaceholderExpansion.expand("Today is {{yyyy-MM-dd}}", referenceDate: reference),
            "Today is 2026-06-05"
        )
    }

    func testOutputPlaceholderExpansionReplacesMultipleTokens() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 2
        let reference = Calendar.current.date(from: components)!

        XCTAssertEqual(
            OutputPlaceholderExpansion.expand("{{yyyy}}/{{MM}}", referenceDate: reference),
            "2026/01"
        )
    }

    // MARK: - Chord typing segments and decomposition

    func testDecomposedOutputSplitsAtCursorPipe() {
        let result = Chord.decomposedOutput(for: "hel|lo")
        XCTAssertEqual(result.beforeCursor, "hel")
        XCTAssertEqual(result.afterCursor, "lo")
        XCTAssertTrue(result.hasPipe)
        XCTAssertFalse(result.invalid)
    }

    func testDecomposedOutputTreatsEscapedPipeAsLiteral() {
        let result = Chord.decomposedOutput(for: "a\\|b")
        XCTAssertEqual(result.beforeCursor, "a|b")
        XCTAssertEqual(result.afterCursor, "")
        XCTAssertFalse(result.hasPipe)
        XCTAssertFalse(result.invalid)
    }

    func testResolveTypingSegmentsSetsLeftArrowCountFromPipeSuffix() {
        let chord = Chord(input: "ab", output: "hel|lo")
        let (segments, leftArrowCount) = chord.resolveTypingSegments()
        XCTAssertEqual(segments.joined(), "hello")
        XCTAssertEqual(leftArrowCount, 2)
    }

    func testResolveTypingSegmentsExpandsPlaceholders() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 5
        let reference = Calendar.current.date(from: components)!

        let chord = Chord(input: "ab", output: "{{yyyy}}")
        let (segments, _) = chord.resolveTypingSegments(referenceDate: reference)
        XCTAssertEqual(segments.joined(), "2026")
    }

    func testResolveTypingSegmentsAppliesSingleCharacterCapitalisation() {
        let chord = Chord(input: "ab", output: "hello")
        let (segments, _) = chord.resolveTypingSegments(capitalisationMode: .singleCharacter)
        XCTAssertEqual(segments.joined(), "Hello")
    }

    func testResolveTypingSegmentsAppliesFullCapitalisation() {
        let chord = Chord(input: "ab", output: "hello")
        let (segments, _) = chord.resolveTypingSegments(capitalisationMode: .fullCapitalisation)
        XCTAssertEqual(segments.joined(), "HELLO")
    }

    func testResolveTypingSegmentsAlwaysOriginalCaseIgnoresEngineCapitalisation() {
        let chord = Chord(
            input: "ab",
            output: "HeLLo",
            capitalisationMode: .alwaysOriginalCase
        )
        let (segments, _) = chord.resolveTypingSegments(capitalisationMode: .fullCapitalisation)
        XCTAssertEqual(segments.joined(), "HeLLo")
    }

    func testStringChunkedSplitsLongOutputIntoSegments() {
        let long = String(repeating: "a", count: 25)
        XCTAssertEqual(long.chunked(into: 10).count, 3)
        XCTAssertEqual(long.chunked(into: 10).joined(), long)
    }

    // MARK: - AccessibilityReplacementVerification (additional failures)

    func testAccessibilityReplacementVerificationRejectsCursorTooEarly() {
        guard case .failure(.cursorTooEarly(cursorLocation: 1, inputCount: 2, leadingSpaceDeletionCount: 0)) =
            AccessibilityReplacementVerification.verifiedSelection(
                fieldValue: "th",
                cursorRange: CFRange(location: 1, length: 0),
                chordInput: "th",
                leadingSpaceDeletionCount: 0
            )
        else {
            return XCTFail("expected cursorTooEarly failure")
        }
    }

    func testAccessibilityReplacementVerificationRejectsCursorPastFieldEnd() {
        guard case .failure(.cursorPastFieldEnd(cursorLocation: 5, fieldLength: 2)) =
            AccessibilityReplacementVerification.verifiedSelection(
                fieldValue: "th",
                cursorRange: CFRange(location: 5, length: 0),
                chordInput: "th",
                leadingSpaceDeletionCount: 0
            )
        else {
            return XCTFail("expected cursorPastFieldEnd failure")
        }
    }

    func testAccessibilityReplacementVerificationRejectsLeadingSpaceDeletionUnderflow() {
        guard case .failure(.cursorTooEarly(cursorLocation: 2, inputCount: 2, leadingSpaceDeletionCount: 1)) =
            AccessibilityReplacementVerification.verifiedSelection(
                fieldValue: "th",
                cursorRange: CFRange(location: 2, length: 0),
                chordInput: "th",
                leadingSpaceDeletionCount: 1
            )
        else {
            return XCTFail("expected cursorTooEarly failure when leading-space deletion would underflow")
        }
    }

    func testAccessibilityReplacementVerificationRejectsInputMismatch() {
        guard case .failure(.inputMismatch(found: "to", expected: "th")) =
            AccessibilityReplacementVerification.verifiedSelection(
                fieldValue: "to",
                cursorRange: CFRange(location: 2, length: 0),
                chordInput: "th",
                leadingSpaceDeletionCount: 0
            )
        else {
            return XCTFail("expected inputMismatch failure")
        }
    }

    // MARK: - AppSettings

    func testAppSettingsDetectsDuplicateNormalisedInputKeys() {
        let settings = Self.makeTestSettings()
        settings.parseSettingsFromJson(json: """
        { "millisecondsToHold": "100ms", "chords": [] }
        """)
        settings.addChord(chord: Chord(id: "a", input: "ab", output: "one"))
        settings.addChord(chord: Chord(id: "b", input: "ba", output: "two"))
        XCTAssertEqual(settings.duplicateNormalisedInputKeys, ["ab"])
        XCTAssertEqual(settings.alphabeticalInputOutputMappingDictionary["ab"]?.id, "b")
    }

    func testAppSettingsParseSettingsFromJson() {
        let settings = Self.makeTestSettings()
        settings.parseSettingsFromJson(json: """
        {
          "millisecondsToHold": "150ms",
          "useAccessibilityAPI": false,
          "chords": [
            {
              "id": "chord-1",
              "input": "th",
              "output": "the",
              "capitalisationMode": "alwaysOriginalCase",
              "spaceBeforeOutput": "never"
            }
          ]
        }
        """)
        XCTAssertEqual(settings.millisecondsToHoldStr, "150ms")
        XCTAssertEqual(settings.millisecondsToHold, 150)
        XCTAssertFalse(settings.useAccessibilityAPI)
        XCTAssertEqual(settings.chords.count, 1)
        XCTAssertEqual(settings.chords.first?.capitalisationMode, .alwaysOriginalCase)
        XCTAssertEqual(settings.chords.first?.spaceBeforeOutputMode, .never)
    }

    func testAppSettingsSerialiseAndParseRoundTripOmitsUsage() throws {
        let settings = Self.makeTestSettings()
        settings.parseSettingsFromJson(json: """
        {
          "millisecondsToHold": "100ms",
          "chords": [
            {
              "id": "chord-1",
              "input": "th",
              "output": "the"
            }
          ]
        }
        """)
        settings.chords.first?.incrementUsageCount(for: "machine-a")

        let json = settings.getSettingsJsonString()
        XCTAssertFalse(json.contains("usage"))
        XCTAssertFalse(json.contains("usageCount"))

        let reparsed = Self.makeTestSettings()
        reparsed.parseSettingsFromJson(json: json)
        XCTAssertEqual(reparsed.chords.first?.input, "th")
        XCTAssertEqual(reparsed.chords.first?.totalUsageCount, 0)
    }

    // MARK: - ChordUsageStore

    func testMachineUsageStatsDecodesLegacyUsageByInputKey() throws {
        let json = """
        {
          "usageByInput": {
            "abc": 5
          }
        }
        """
        let stats = try JSONDecoder().decode(MachineUsageStats.self, from: Data(json.utf8))
        XCTAssertTrue(stats.hasLegacyInputKeys)
        XCTAssertEqual(stats.legacyUsageByInput["abc"], 5)
    }

    func testChordUsageStoreMergedUsageOnDiskKeepsHighestCount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = ChordUsageStore.statsFileURL(for: "machine-a", in: root)
        try ChordUsageStore.saveMachineUsage(
            MachineUsageStats(usageByChordId: ["chord-1": 3]),
            to: fileURL
        )

        let merged = ChordUsageStore.mergedUsageOnDisk(
            at: fileURL,
            with: MachineUsageStats(usageByChordId: ["chord-1": 7, "chord-2": 1])
        )
        XCTAssertEqual(merged.usageByChordId["chord-1"], 7)
        XCTAssertEqual(merged.usageByChordId["chord-2"], 1)
    }

    // MARK: - ChordPracticeSelection

    func testChordPracticeSelectionPrefersLowUsageChords() {
        let low = Chord(input: "ab", output: "alpha", usageByMachine: ["m": 0])
        let high = Chord(input: "cd", output: "beta", usageByMachine: ["m": 100])
        var lowPicks = 0
        for _ in 0..<200 {
            if ChordPracticeSelection.pick(from: [low, high])?.id == low.id {
                lowPicks += 1
            }
        }
        XCTAssertGreaterThan(lowPicks, 120)
    }

    func testChordPracticeSelectionDisplayOutputExpandsPlaceholdersAndRemovesPipe() {
        let chord = Chord(input: "dt", output: "on {{yyyy}}|day")
        let display = chord.displayOutput(referenceDate: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(display, "on 1970day")
    }

    func testChordUsageSummaryTotalsAggregateAcrossChordsAndMachines() {
        let referenceDate = Date(timeIntervalSince1970: 0)
        let chords = [
            Chord(input: "th", output: "the", usageByMachine: ["machine-a": 10, "machine-b": 5]),
            Chord(input: "ab", output: "alpha", usageByMachine: ["machine-a": 2]),
            Chord(input: "xy", output: "x", usageByMachine: ["machine-a": 4]),
        ]

        let totals = ChordUsageSummary.totals(for: chords, referenceDate: referenceDate)

        XCTAssertEqual(totals.totalChordsEntered, 21)
        XCTAssertEqual(totals.totalCharactersSaved, 17)
        XCTAssertEqual(totals.estimatedTimeSavedSeconds, 4.25, accuracy: 0.001)
    }

    func testChordUsageSummaryFormattedTimeSaved() {
        XCTAssertEqual(ChordUsageSummary.formattedTimeSaved(0), "0 seconds")
        XCTAssertEqual(ChordUsageSummary.formattedTimeSaved(45), "45 seconds")
        XCTAssertEqual(ChordUsageSummary.formattedTimeSaved(90), "1 minute 30 seconds")
        XCTAssertEqual(ChordUsageSummary.formattedTimeSaved(3600), "1 hour")
        XCTAssertEqual(ChordUsageSummary.formattedTimeSaved(5400), "1 hour 30 minutes")
    }

    func testPracticeChordMonitorDetectsTargetChordHold() {
        let chord = Chord(input: "th", output: "the")
        let monitor = PracticeChordMonitor()
        let success = expectation(description: "practice chord success")
        monitor.onSuccess = { success.fulfill() }
        monitor.start(targetChord: chord, holdDurationMilliseconds: 50)

        guard let tDown = Self.keyDownEvent(keyCode: 17, characters: "t"),
              let hDown = Self.keyDownEvent(keyCode: 4, characters: "h") else {
            XCTFail("Failed to create key events")
            return
        }

        monitor.handleKeyDownForTesting(tDown)
        monitor.handleKeyDownForTesting(hDown)

        wait(for: [success], timeout: 1.0)
        monitor.stop()
    }

    func testPracticeChordMonitorIgnoresWrongChordHold() {
        let chord = Chord(input: "th", output: "the")
        let monitor = PracticeChordMonitor()
        let success = expectation(description: "practice chord success")
        success.isInverted = true
        monitor.onSuccess = { success.fulfill() }
        monitor.start(targetChord: chord, holdDurationMilliseconds: 50)

        guard let aDown = Self.keyDownEvent(keyCode: 0, characters: "a"),
              let bDown = Self.keyDownEvent(keyCode: 11, characters: "b") else {
            XCTFail("Failed to create key events")
            return
        }

        monitor.handleKeyDownForTesting(aDown)
        monitor.handleKeyDownForTesting(bDown)

        wait(for: [success], timeout: 0.2)
        monitor.stop()
    }

    // MARK: - TextReplacer

    func testTextReplacerInsertOwedSpaceBeforeReturnsEchoCount() {
        XCTAssertEqual(TextReplacer().insertOwedSpaceBefore(character: "a"), 4)
    }

    func testTextReplacerReplaceViaSyntheticKeysReturnsEchoCount() {
        let chord = Chord(input: "th", output: "the")
        let resolved = chord.resolveReplacement(autoInsertedSpaceBeforeInput: false)
        let echoCount = TextReplacer().replaceViaSyntheticKeys(chord: chord, resolved: resolved)
        XCTAssertEqual(echoCount, resolved.syntheticKeyEchoCount(inputDeleteCount: chord.deleteCount))
    }

    private static func makeTestSettings() -> AppSettings {
        AppSettings.makeForTesting()
    }

    private static func flagsChangedEvent(modifierFlags: NSEvent.ModifierFlags) -> NSEvent {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true)!
        cgEvent.type = .flagsChanged
        cgEvent.flags = CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
        return NSEvent(cgEvent: cgEvent)!
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
