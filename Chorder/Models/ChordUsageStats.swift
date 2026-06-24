//
//  ChordUsageStats.swift
//  Chorder
//
//  Created by George Gillams on 05/06/2026.
//

import Foundation

struct MachineUsageStats: Codable, Equatable {
    var usageByChordId: [String: Int]
    var legacyUsageByInput: [String: Int]

    init(usageByChordId: [String: Int] = [:], legacyUsageByInput: [String: Int] = [:]) {
        self.usageByChordId = usageByChordId
        self.legacyUsageByInput = legacyUsageByInput
    }

    var hasLegacyInputKeys: Bool {
        !legacyUsageByInput.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case usageByChordId
        case usageByInput
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usageByChordId = try container.decodeIfPresent([String: Int].self, forKey: .usageByChordId) ?? [:]
        legacyUsageByInput = try container.decodeIfPresent([String: Int].self, forKey: .usageByInput) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !usageByChordId.isEmpty {
            try container.encode(usageByChordId, forKey: .usageByChordId)
        }
        if !legacyUsageByInput.isEmpty {
            try container.encode(legacyUsageByInput, forKey: .usageByInput)
        }
    }
}

enum ChordUsageStore {
    static let statsDirectoryName = "stats"
    static let fileExtension = "json"

    static func statsDirectory(in settingsRootDirectory: URL) -> URL {
        settingsRootDirectory.appendingPathComponent(statsDirectoryName, isDirectory: true)
    }

    static func statsFileURL(for machineId: String, in settingsRootDirectory: URL) -> URL {
        statsDirectory(in: settingsRootDirectory)
            .appendingPathComponent(safeFileName(for: machineId))
            .appendingPathExtension(fileExtension)
    }

    static func loadMachineUsage(from fileURL: URL) -> MachineUsageStats? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(MachineUsageStats.self, from: data)
    }

    static func saveMachineUsage(_ stats: MachineUsageStats, to fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(stats)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Returns usage keyed by machine identifier, then chord ID.
    static func loadAllMachineUsage(from settingsRootDirectory: URL) -> [String: [String: Int]] {
        let statsDirectory = statsDirectory(in: settingsRootDirectory)
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: statsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return [:]
        }

        var usageByMachine: [String: [String: Int]] = [:]
        for fileURL in fileURLs where fileURL.pathExtension == fileExtension {
            guard let stats = loadMachineUsage(from: fileURL) else {
                continue
            }
            let machineId = fileURL.deletingPathExtension().lastPathComponent
            usageByMachine[machineId] = Chord.mergedUsage(
                usageByMachine[machineId] ?? [:],
                stats.usageByChordId
            )
        }
        return usageByMachine
    }

    static func mergedUsageOnDisk(at fileURL: URL, with incoming: MachineUsageStats) -> MachineUsageStats {
        let existing = loadMachineUsage(from: fileURL) ?? MachineUsageStats()
        return MachineUsageStats(
            usageByChordId: Chord.mergedUsage(existing.usageByChordId, incoming.usageByChordId)
        )
    }

    private static func safeFileName(for machineId: String) -> String {
        machineId.replacingOccurrences(of: "/", with: "_")
    }
}

/// Aggregated usage metrics shown on the Stats tab.
enum ChordUsageSummary {
    /// Average time to type one character (~40 WPM, ~5 characters per word).
    static let averageSecondsPerTypedCharacter = 0.25

    struct Totals: Equatable {
        let totalChordsEntered: Int
        let totalCharactersSaved: Int
        let estimatedTimeSavedSeconds: TimeInterval
    }

    static func charactersSavedPerUse(for chord: Chord, referenceDate: Date = Date()) -> Int {
        let outputLength = chord.displayOutput(referenceDate: referenceDate).count
        return outputLength - chord.input.count
    }

    static func totals(for chords: [Chord], referenceDate: Date = Date()) -> Totals {
        var totalChordsEntered = 0
        var totalCharactersSaved = 0

        for chord in chords {
            let uses = chord.totalUsageCount
            guard uses > 0 else { continue }
            totalChordsEntered += uses
            totalCharactersSaved += charactersSavedPerUse(for: chord, referenceDate: referenceDate) * uses
        }

        let estimatedTimeSavedSeconds =
            TimeInterval(totalCharactersSaved) * averageSecondsPerTypedCharacter

        return Totals(
            totalChordsEntered: totalChordsEntered,
            totalCharactersSaved: totalCharactersSaved,
            estimatedTimeSavedSeconds: estimatedTimeSavedSeconds
        )
    }

    static func formattedTimeSaved(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        if totalSeconds < 60 {
            return "\(totalSeconds) second\(totalSeconds == 1 ? "" : "s")"
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s")"
            }
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }

        if remainingSeconds > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") \(remainingSeconds) second\(remainingSeconds == 1 ? "" : "s")"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}
