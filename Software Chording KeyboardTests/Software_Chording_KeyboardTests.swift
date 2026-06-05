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
            capitalisationMode: "default"
        )
        let json = String(data: try JSONEncoder().encode(chord), encoding: .utf8)!
        XCTAssertFalse(json.contains("usage"))
        XCTAssertFalse(json.contains("usageCount"))
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

}
