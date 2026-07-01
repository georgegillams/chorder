import Combine
import Foundation

/// A chord definition. Update through registry APIs so lookups stay in sync.
public final class Chord: Identifiable, ObservableObject {
  public let id: String
  @Published public var input: String
  @Published public var output: String
  @Published public var capitalisationMode: ChordCapitalisationMode
  @Published public var spaceBeforeOutputMode: ChordSpaceBeforeOutputMode
  @Published public var usageByMachine: [String: Int]
  @Published public var deleted: Bool

  public static let legacyUsageMachineKey = "legacy"

  public static func normalisedInputKey(for input: String) -> String {
    String(input.lowercased().sorted())
  }

  public static func hasDuplicateInputLetters(_ input: String) -> Bool {
    let lower = input.lowercased()
    return Set(lower).count != lower.count
  }

  public var inputSorted: String {
    Self.normalisedInputKey(for: input)
  }

  public var totalUsageCount: Int {
    usageByMachine.values.reduce(0, +)
  }

  public var usageCount: Int? {
    totalUsageCount == 0 ? nil : totalUsageCount
  }

  public var deleteCount = 0
  public var outputChunks: [String] = []
  public var pipeNegativePosition = 0
  public var hasPipe = false

  public var hasInvalidOutput: Bool {
    Self.decomposedOutput(for: output).invalid
  }

  public static func isValidOutput(_ rawOutput: String) -> Bool {
    !decomposedOutput(for: rawOutput).invalid
  }

  public var usageCountForSorting: Int {
    totalUsageCount
  }

  public init(
    id: String = UUID().uuidString,
    input: String,
    output: String,
    usageByMachine: [String: Int] = [:],
    capitalisationMode: ChordCapitalisationMode = .default,
    spaceBeforeOutputMode: ChordSpaceBeforeOutputMode = .default,
    deleted: Bool = false
  ) {
    self.id = id
    self.input = input
    self.output = output
    self.usageByMachine = usageByMachine
    self.capitalisationMode = capitalisationMode
    self.spaceBeforeOutputMode = spaceBeforeOutputMode
    self.deleted = deleted
    rebuildDerivedState()
  }

  public func update(
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

  public func wantsSpaceBeforeInputWhenTyped(autoInsertedSpaceBeforeInput: Bool) -> Bool {
    switch spaceBeforeOutputMode {
    case .default:
      return autoInsertedSpaceBeforeInput
    case .always:
      return true
    case .never:
      return false
    }
  }

  public static func spaceBeforeOutputCorrection(
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
      ChorderCoreLogging.log("Error: Chord output has more than one pipe")
      deleteCount = input.count
      outputChunks = []
      return
    }

    let outputWithPipes = decomposed.beforeCursor + decomposed.afterCursor
    deleteCount = input.count
    outputChunks = outputWithPipes.chunked(into: maximumOutputChunkLength)
    pipeNegativePosition = decomposed.hasPipe ? decomposed.afterCursor.count : 0
    hasPipe = decomposed.hasPipe
  }

  public static func decomposedOutput(for rawOutput: String) -> (beforeCursor: String, afterCursor: String, hasPipe: Bool, invalid: Bool) {
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

  public func resolveTypingSegments(
    referenceDate: Date = Date(),
    capitalisationMode: CapitalisationMode = .off
  ) -> (segments: [String], leftArrowCount: Int) {
    let effectiveCapitalisationMode: CapitalisationMode =
      self.capitalisationMode == .alwaysOriginalCase ? .off : capitalisationMode

    let decomposed = Self.decomposedOutput(for: output)
    if decomposed.invalid {
      return ([], 0)
    }
    let before = OutputPlaceholderExpansion.expand(decomposed.beforeCursor, referenceDate: referenceDate)
    let after = OutputPlaceholderExpansion.expand(decomposed.afterCursor, referenceDate: referenceDate)
    let merged = before + after
    let segments = merged.chunked(into: maximumOutputChunkLength)
    return (Self.capitalisedSegments(segments, mode: effectiveCapitalisationMode), after.count)
  }

  public var displayOutput: String {
    displayOutput(referenceDate: Date())
  }

  public func displayOutput(referenceDate: Date) -> String {
    let (segments, _) = resolveTypingSegments(referenceDate: referenceDate)
    return segments.joined()
  }

  public func resolveReplacement(
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
    for char in specialChars {
      if !rawOutput.contains(String(char)) {
        return String(char)
      }
    }
    return "*"
  }

  public func incrementUsageCount(for machineId: String) {
    usageByMachine[machineId, default: 0] += 1
  }

  public static func mergedUsage(_ existing: [String: Int], _ incoming: [String: Int]) -> [String: Int] {
    var merged = existing
    for (machineId, count) in incoming {
      merged[machineId] = max(merged[machineId] ?? 0, count)
    }
    return merged
  }
}
