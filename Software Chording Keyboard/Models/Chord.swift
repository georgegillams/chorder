//
//  Chord.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation

enum ChordCapitalisationMode: String, CaseIterable, Identifiable, Hashable {
    case `default`
    case alwaysOriginalCase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .alwaysOriginalCase:
            return "Always original case"
        }
    }

    /// Label shown in the chords table (`default` is blank).
    var tableLabel: String {
        switch self {
        case .default:
            return ""
        case .alwaysOriginalCase:
            return "Fixed"
        }
    }
}

extension String {
    func capitalizeFirstLetter() -> String {
        prefix(1).uppercased() + lowercased().dropFirst()
    }
}

let SPECIAL_CHARS = "*&^%$£@!#~`()[]{}<>?/;:.,-_=+)1234567890"

let maximumOutputChunkLength = 10

class Chord: Identifiable, ObservableObject {
    let id: String
    @Published var input: String
    var inputSorted: String {
        get {
            return String(input.sorted())
        }
    }
    @Published var output: String
    @Published var capitalisationMode: ChordCapitalisationMode
    @Published var usageByMachine: [String: Int]

    static let legacyUsageMachineKey = "legacy"

    /// Sum of usage counts across all machines.
    var totalUsageCount: Int {
        usageByMachine.values.reduce(0, +)
    }

    /// Total usage for UI display; nil when zero.
    var usageCount: Int? {
        totalUsageCount == 0 ? nil : totalUsageCount
    }

    // These values are calculated when the chord definition changes.
    var deleteCount = 0
    var outputChunks: [String] = []
    var pipeNegativePosition = 0
    var hasPipe = false

    // Computed property for sorting
    var usageCountForSorting: Int {
        totalUsageCount
    }

    init(
        id: String = UUID().uuidString,
        input: String,
        output: String,
        usageByMachine: [String: Int] = [:],
        capitalisationMode: ChordCapitalisationMode = .default
    ) {
        // NOTE: input and output strings should be unmodified, as these will be saved to settings file and re-read when the app is started.
        self.id = id
        self.input = input
        self.output = output
        self.usageByMachine = usageByMachine
        self.capitalisationMode = capitalisationMode
        rebuildDerivedState()
    }

    func update(input: String, output: String, capitalisationMode: ChordCapitalisationMode) {
        self.input = input
        self.output = output
        self.capitalisationMode = capitalisationMode
        rebuildDerivedState()
    }

    private func rebuildDerivedState() {
        pipeNegativePosition = 0
        hasPipe = false

        let decomposed = Self.decomposedOutput(for: output)
        if decomposed.invalid {
            gDebugPrint("Error: Chord output has more than one pipe")
            deleteCount = input.count
            return
        }

        let outputWithPipes = decomposed.beforeCursor + decomposed.afterCursor

        deleteCount = input.count
        outputChunks = outputWithPipes.chunked(into: maximumOutputChunkLength)
        pipeNegativePosition = decomposed.hasPipe ? decomposed.afterCursor.count : 0
        hasPipe = decomposed.hasPipe
    }

    /// Splits raw chord output into typed segments before and after the cursor pipe (`\|` is a literal pipe).
    static func decomposedOutput(for rawOutput: String) -> (beforeCursor: String, afterCursor: String, hasPipe: Bool, invalid: Bool) {
        let escapedPipePlaceholder = Self.placeholderCharacterAvoidingCollision(with: rawOutput)
        let escapedOutput = rawOutput.replacingOccurrences(of: "\\|", with: escapedPipePlaceholder)

        if escapedOutput.components(separatedBy: "|").count > 2 {
            return ("", "", false, true)
        }

        guard let pipeIndex = escapedOutput.firstIndex(of: "|") else {
            let typed = escapedOutput.replacingOccurrences(of: escapedPipePlaceholder, with: "|")
            return (typed, "", false, false)
        }

        let before = String(escapedOutput[..<pipeIndex]).replacingOccurrences(of: escapedPipePlaceholder, with: "|")
        let after = String(escapedOutput[escapedOutput.index(after: pipeIndex)...]).replacingOccurrences(of: escapedPipePlaceholder, with: "|")
        return (before, after, true, false)
    }

    /// Text to type and how many left-arrow presses follow, after expanding `{{date}}` tokens at fire time.
    func resolveTypingSegments(
        referenceDate: Date = Date(),
        capitalisationMode: CapitalisationMode = .off
    ) -> (segments: [String], leftArrowCount: Int) {
        let effectiveCapitalisationMode: CapitalisationMode =
            self.capitalisationMode == .alwaysOriginalCase ? .off : capitalisationMode

        let decomposed = Self.decomposedOutput(for: output)
        if decomposed.invalid {
            return (Self.capitalisedSegments(outputChunks, mode: effectiveCapitalisationMode), pipeNegativePosition)
        }
        let before = OutputPlaceholderExpansion.expand(decomposed.beforeCursor, referenceDate: referenceDate)
        let after = OutputPlaceholderExpansion.expand(decomposed.afterCursor, referenceDate: referenceDate)
        let merged = before + after
        let segments = merged.chunked(into: maximumOutputChunkLength)
        return (Self.capitalisedSegments(segments, mode: effectiveCapitalisationMode), after.count)
    }

    private static func capitalisedSegments(_ segments: [String], mode: CapitalisationMode) -> [String] {
        segments.enumerated().map { index, segment in
            switch mode {
            case .singleCharacter:
                return index == 0 ? segment.capitalizeFirstLetter() : segment
            case .fullCapitalisation:
                return segment.uppercased()
            case .off:
                return segment
            }
        }
    }

    private static func placeholderCharacterAvoidingCollision(with rawOutput: String) -> String {
        for char in SPECIAL_CHARS {
            if !rawOutput.contains(String(char)) {
                return String(char)
            }
        }
        return "*"
    }

    func incrementUsageCount(for machineId: String) {
        usageByMachine[machineId, default: 0] += 1
    }

    static func mergedUsage(_ existing: [String: Int], _ incoming: [String: Int]) -> [String: Int] {
        var merged = existing
        for (machineId, count) in incoming {
            merged[machineId] = max(merged[machineId] ?? 0, count)
        }
        return merged
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            String(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: min($0 + size, count))])
        }
    }
}
