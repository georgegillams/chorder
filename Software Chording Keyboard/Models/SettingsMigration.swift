//
//  SettingsMigration.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 05/06/2026.
//

import Foundation

enum SettingsMigration {
    @discardableResult
    static func run(on appSettings: AppSettings) -> Bool {
        var settingsFileChanged = false

        settingsFileChanged = migrateEmbeddedUsageFromSettings(on: appSettings) || settingsFileChanged
        settingsFileChanged = persistMissingChordIdsIfNeeded(on: appSettings) || settingsFileChanged
        settingsFileChanged = migrateInputBasedStatsToChordIds(on: appSettings) || settingsFileChanged

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
                }
            }
            migrated = true
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
        let inputToChordId = Dictionary(uniqueKeysWithValues: chords.map { ($0.input, $0.id) })
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
                guard let chordId = inputToChordId[input] else {
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

private extension AppSettings {
    func matchingChord(input: String, output: String) -> Chord? {
        chords.first { $0.input == input && $0.output == output }
    }
}
