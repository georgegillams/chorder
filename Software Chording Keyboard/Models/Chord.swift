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

    /// SF Symbol for the chords table Options column; nil when default.
    var optionsSymbolName: String? {
        switch self {
        case .default:
            return nil
        case .alwaysOriginalCase:
            return "textformat.abc"
        }
    }

    /// Tooltip for the chords table Options column; nil when default.
    var optionsTooltip: String? {
        switch self {
        case .default:
            return nil
        case .alwaysOriginalCase:
            return "Capitalisation: Always original case"
        }
    }
}

enum ChordSpaceBeforeOutputMode: String, CaseIterable, Identifiable, Hashable {
    case `default`
    case always
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .always:
            return "Always"
        case .never:
            return "Never"
        }
    }

    /// SF Symbol for the chords table Options column; nil when default.
    var optionsSymbolName: String? {
        switch self {
        case .default:
            return nil
        case .always:
            return "space"
        case .never:
            return "arrow.left.to.line.compact"
        }
    }

    /// Tooltip for the chords table Options column; nil when default.
    var optionsTooltip: String? {
        switch self {
        case .default:
            return nil
        case .always:
            return "Space before output: Always"
        case .never:
            return "Space before output: Never"
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

enum SpaceBeforeOutputCorrection {
    case none
    case removeAutoInsertedSpace
    case prependSpaceToOutput
}

struct ResolvedChordReplacement {
    let segments: [String]
    let leftArrowCount: Int
    /// Extra backspaces before typing output, to remove an auto-inserted leading space.
    let backspacesBeforeOutput: Int
}

class Chord: Identifiable, ObservableObject {
    let id: String
    @Published var input: String
    static func normalisedInputKey(for input: String) -> String {
        String(input.lowercased().sorted())
    }

    var inputSorted: String {
        Self.normalisedInputKey(for: input)
    }
    @Published var output: String
    @Published var capitalisationMode: ChordCapitalisationMode
    @Published var spaceBeforeOutputMode: ChordSpaceBeforeOutputMode
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
        capitalisationMode: ChordCapitalisationMode = .default,
        spaceBeforeOutputMode: ChordSpaceBeforeOutputMode = .default
    ) {
        // NOTE: input and output strings should be unmodified, as these will be saved to settings file and re-read when the app is started.
        self.id = id
        self.input = input
        self.output = output
        self.usageByMachine = usageByMachine
        self.capitalisationMode = capitalisationMode
        self.spaceBeforeOutputMode = spaceBeforeOutputMode
        rebuildDerivedState()
    }

    func update(
        input: String,
        output: String,
        capitalisationMode: ChordCapitalisationMode,
        spaceBeforeOutputMode: ChordSpaceBeforeOutputMode
    ) {
        self.input = input
        self.output = output
        self.capitalisationMode = capitalisationMode
        self.spaceBeforeOutputMode = spaceBeforeOutputMode
        rebuildDerivedState()
    }

    /// Whether this chord wants a leading space when it is the chord being typed.
    /// For `default`, pass whether global auto-space actually ran before this input.
    func wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: Bool) -> Bool {
        switch spaceBeforeOutputMode {
        case .default:
            return autoInsertedSpaceBeforeInput && !hasPipe
        case .always:
            return true
        case .never:
            return false
        }
    }

    static func spaceBeforeOutputCorrection(
        autoInserted: Bool,
        wantsSpace: Bool
    ) -> SpaceBeforeOutputCorrection {
        switch (autoInserted, wantsSpace) {
        case (true, false):
            return .removeAutoInsertedSpace
        case (false, true):
            return .prependSpaceToOutput
        default:
            return .none
        }
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

    /// Resolves replacement output and any space-before-output correction for the matched chord.
    func resolveReplacement(
        referenceDate: Date = Date(),
        capitalisationMode: CapitalisationMode = .off,
        autoInsertedSpaceBeforeInput: Bool
    ) -> ResolvedChordReplacement {
        let (segments, leftArrowCount) = resolveTypingSegments(
            referenceDate: referenceDate,
            capitalisationMode: capitalisationMode
        )
        let wantsSpace = wantsSpaceBeforeInputWhenTyped(
            autoInsertedSpaceBeforeInput: autoInsertedSpaceBeforeInput
        )
        let correction = Self.spaceBeforeOutputCorrection(
            autoInserted: autoInsertedSpaceBeforeInput,
            wantsSpace: wantsSpace
        )

        var resolvedSegments = segments
        var backspacesBeforeOutput = 0

        switch correction {
        case .none:
            break
        case .prependSpaceToOutput:
            if resolvedSegments.isEmpty {
                resolvedSegments = [" "]
            } else {
                resolvedSegments[0] = " " + resolvedSegments[0]
            }
        case .removeAutoInsertedSpace:
            backspacesBeforeOutput = 1
        }

        return ResolvedChordReplacement(
            segments: resolvedSegments,
            leftArrowCount: leftArrowCount,
            backspacesBeforeOutput: backspacesBeforeOutput
        )
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
