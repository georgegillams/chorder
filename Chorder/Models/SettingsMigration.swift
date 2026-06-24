//
//  SettingsMigration.swift
//  Chorder
//
//  Created by George Gillams on 05/06/2026.
//

import Foundation

enum SettingsMigration {
    static let currentMigrationVersion = 1

    @discardableResult
    static func run(on appSettings: AppSettings) -> Bool {
        guard appSettings.migrationVersion < currentMigrationVersion else {
            return false
        }

        var settingsFileChanged = false

        if appSettings.migrationVersion < 1 {
            settingsFileChanged = migrateEmbeddedUsageFromSettings(on: appSettings) || settingsFileChanged
            settingsFileChanged = persistMissingChordIdsIfNeeded(on: appSettings) || settingsFileChanged
            settingsFileChanged = migrateInputBasedStatsToChordIds(on: appSettings) || settingsFileChanged
        }

        return settingsFileChanged
    }

    /// Moves usage embedded in the settings JSON into per-machine stats files keyed by chord ID.
    @discardableResult
    static func migrateEmbeddedUsageFromSettings(on appSettings: AppSettings) -> Bool {
        guard let settings = loadLegacySettings(from: appSettings.settingsFileLocation) else {
            return false
        }

        var migrated = false
        for serialisableChord in settings.chords {
            guard let usageByMachine = serialisableChord.resolvedUsage, !usageByMachine.isEmpty else {
                continue
            }
            guard let chord = appSettings.matchingChord(
                input: serialisableChord.input,
                output: serialisableChord.output
            ) else {
                continue
            }

            var chordMigrationSucceeded = true
            for (machineId, count) in usageByMachine where count > 0 {
                let fileURL = ChordUsageStore.statsFileURL(
                    for: machineId,
                    in: appSettings.settingsRootDirectory
                )
                let incoming = MachineUsageStats(usageByChordId: [chord.id: count])
                let merged = ChordUsageStore.mergedUsageOnDisk(at: fileURL, with: incoming)
                do {
                    try ChordUsageStore.saveMachineUsage(merged, to: fileURL)
                } catch {
                    gDebugPrint("ERROR migrating embedded settings usage \(error)")
                    chordMigrationSucceeded = false
                }
            }
            if chordMigrationSucceeded {
                migrated = true
            }
        }

        return migrated
    }

    /// Persists chord IDs for chords that were loaded without one.
    @discardableResult
    static func persistMissingChordIdsIfNeeded(on appSettings: AppSettings) -> Bool {
        guard let settings = loadLegacySettings(from: appSettings.settingsFileLocation) else {
            return false
        }
        return settings.chords.contains(where: { $0.id == nil })
    }

    /// Converts legacy stats files keyed by chord input to chord ID keys.
    @discardableResult
    static func migrateInputBasedStatsToChordIds(on appSettings: AppSettings) -> Bool {
        migrateInputBasedStatsToChordIds(
            chords: appSettings.chords,
            settingsRootDirectory: appSettings.settingsRootDirectory
        )
    }

    @discardableResult
    static func migrateInputBasedStatsToChordIds(
        chords: [Chord],
        settingsRootDirectory: URL
    ) -> Bool {
        let inputToChordId = normalisedInputToChordId(chords: chords)
        guard !inputToChordId.isEmpty else {
            return false
        }

        let statsDirectory = ChordUsageStore.statsDirectory(in: settingsRootDirectory)
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: statsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        var migrated = false
        for fileURL in fileURLs where fileURL.pathExtension == ChordUsageStore.fileExtension {
            guard let stats = ChordUsageStore.loadMachineUsage(from: fileURL) else {
                continue
            }
            guard stats.hasLegacyInputKeys else {
                continue
            }

            var usageByChordId = stats.usageByChordId
            for (input, count) in stats.legacyUsageByInput where count > 0 {
                let normalisedKey = Chord.normalisedInputKey(for: input)
                guard let chordId = inputToChordId[normalisedKey] ?? inputToChordId[input] else {
                    continue
                }
                usageByChordId[chordId] = max(usageByChordId[chordId] ?? 0, count)
            }

            do {
                try ChordUsageStore.saveMachineUsage(
                    MachineUsageStats(usageByChordId: usageByChordId),
                    to: fileURL
                )
                migrated = true
            } catch {
                gDebugPrint("ERROR migrating input-based stats \(error)")
            }
        }

        return migrated
    }

    static func normalisedInputToChordId(chords: [Chord]) -> [String: String] {
        var map: [String: String] = [:]
        for chord in chords {
            let key = chord.inputSorted
            if map[key] != nil {
                gDebugPrint(
                    "Warning: stats migration duplicate normalised input '\(key)' — "
                    + "using chord id \(chord.id)"
                )
            }
            map[key] = chord.id
        }
        return map
    }

    private static func loadLegacySettings(from url: URL) -> LegacySerialisableAppSettings? {
        guard FileManager.default.fileExists(atPath: url.path),
              let json = try? String(contentsOf: url, encoding: .utf8),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(LegacySerialisableAppSettings.self, from: data)
    }
}

struct LegacySerialisableAppSettings: Decodable {
    var chords: [LegacySerialisableChord]
}

struct LegacySerialisableChord: Decodable {
    var id: String?
    var input: String
    var output: String
    var usage: [String: Int]?
    var usageCount: String?

    enum CodingKeys: String, CodingKey {
        case id
        case input
        case output
        case usage
        case usageCount
    }

    var resolvedUsage: [String: Int]? {
        if let usage, !usage.isEmpty {
            return usage
        }
        if let usageCount, let count = Int(usageCount), count > 0 {
            return [Chord.legacyUsageMachineKey: count]
        }
        return nil
    }
}

extension AppSettings {
    func matchingChord(input: String, output: String) -> Chord? {
        let normalisedKey = Chord.normalisedInputKey(for: input)
        return chords.first {
            $0.inputSorted == normalisedKey && $0.output == output
        }
    }
}
