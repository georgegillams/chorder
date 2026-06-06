//
//  Software_Chording_KeyboardTests.swift
//  Software Chording KeyboardTests
//
//  Created by George Gillams on 05/04/2023.
//

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

}
