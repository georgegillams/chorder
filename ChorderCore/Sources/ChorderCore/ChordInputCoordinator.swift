import Foundation

public enum ChordInputMode {
  case legacyPassThrough
  case inputMethodConsume
}

/// Orchestrates chord detection, spacing, capitalisation, and replacement output.
public final class ChordInputCoordinator {
  public weak var delegate: ChordInputCoordinatorDelegate?

  private let registry: ChordRegistryProviding
  private let output: ChordTextOutputting
  private let mode: ChordInputMode
  private let chordDetection = ChordDetectionState()

  private var owedSpace = false
  private var autoInsertedSpaceBeforeCurrentInput = false
  private var shiftPressedDown = false
  public private(set) var capitalisationMode = CapitalisationMode.off
  private var otherKeysPressedDuringShift = false

  public var calculatedCapitalisationMode: CapitalisationMode {
    if shiftPressedDown {
      return .fullCapitalisation
    }
    return capitalisationMode
  }

  public var owesTrailingSpace: Bool { owedSpace }
  public var joinedHeldCharacters: String { chordDetection.joinedCharactersLowercased() }
  public var isAccumulatingChordInput: Bool { chordDetection.isAccumulatingChordInput }

  public init(registry: ChordRegistryProviding, output: ChordTextOutputting, mode: ChordInputMode) {
    self.registry = registry
    self.output = output
    self.mode = mode

    chordDetection.onChordMatched = { [weak self] normalisedInputKey in
      self?.handleChordMatch(normalisedInputKey: normalisedInputKey)
    }
    chordDetection.isRegisteredChord = { [weak self] normalisedKey in
      self?.registry.chord(forNormalisedInputKey: normalisedKey) != nil
    }
  }

  // MARK: - Flags (shift capitalisation)

  public func handleShiftPressed() {
    shiftPressedDown = true
  }

  public func handleShiftReleased() {
    guard shiftPressedDown else { return }
    shiftPressedDown = false
    chordDetection.reset()
    autoInsertedSpaceBeforeCurrentInput = false

    if otherKeysPressedDuringShift {
      otherKeysPressedDuringShift = false
      setCapitalisationMode(.off)
      return
    }

    switch capitalisationMode {
    case .off:
      setCapitalisationMode(.singleCharacter)
    case .singleCharacter:
      setCapitalisationMode(.fullCapitalisation)
    case .fullCapitalisation:
      setCapitalisationMode(.off)
    }
  }

  // MARK: - Legacy path (keys pass through to target app)

  public func handleLegacyKeyDown(keyCode: UInt16, character: String?, modifiers: NSEventModifierFlagsProxy) {
    if modifiers.containsCommandOrOptionOrControlOrFunction {
      resetChordInputState()
      return
    }

    if chordDetection.consumeEchoIfPending() {
      return
    }

    if shiftPressedDown {
      otherKeysPressedDuringShift = true
    }

    if isResetKey(keyCode) {
      resetChordInputState()
      return
    }

    if SharedKeyboardConstants.skipPrecedingSpaceCharacters.contains(character ?? "") {
      owedSpace = false
    }

    if owedSpace {
      owedSpace = false
      autoInsertedSpaceBeforeCurrentInput = true
      let result = output.insertOwedSpace(before: character ?? "")
      chordDetection.scheduleEchoes(result.legacyEchoCount)
    }

    chordDetection.keyDown(
      keyCode: keyCode,
      character: character,
      holdDuration: registry.holdDuration
    )
  }

  public func handleLegacyKeyUp(keyCode: UInt16) {
    if chordDetection.consumeEchoIfPending() {
      return
    }
    chordDetection.keyUp(keyCode: keyCode, holdDuration: registry.holdDuration)
  }

  // MARK: - IMK path (consume chord keys before they reach client)

  public enum IMKKeyDownResult {
    case consume
    case passThrough
  }

  public func handleIMKKeyDown(keyCode: UInt16, character: String?, modifiers: NSEventModifierFlagsProxy) -> IMKKeyDownResult {
    if modifiers.containsCommandOrOptionOrControlOrFunction {
      resetChordInputState()
      return .passThrough
    }

    if shiftPressedDown {
      otherKeysPressedDuringShift = true
    }

    if isResetKey(keyCode) {
      resetChordInputState()
      return .passThrough
    }

    if SharedKeyboardConstants.skipPrecedingSpaceCharacters.contains(character ?? "") {
      owedSpace = false
    }

    if owedSpace {
      owedSpace = false
      autoInsertedSpaceBeforeCurrentInput = true
      _ = output.insertOwedSpace(before: character ?? "")
    }

    guard let character, !character.isEmpty else {
      return .passThrough
    }

    chordDetection.keyDown(
      keyCode: keyCode,
      character: character,
      holdDuration: registry.holdDuration
    )
    return .consume
  }

  public enum IMKKeyUpResult {
    case consume
    case passThrough
    case flushBuffered(String)
  }

  public func handleIMKKeyUp(keyCode: UInt16) -> IMKKeyUpResult {
    let wasAccumulating = chordDetection.isAccumulatingChordInput
    let bufferedBeforeRelease = chordDetection.joinedCharacters()

    chordDetection.keyUp(keyCode: keyCode, holdDuration: registry.holdDuration)

    guard wasAccumulating else {
      return .passThrough
    }

    if !chordDetection.isAccumulatingChordInput, !bufferedBeforeRelease.isEmpty {
      return .flushBuffered(bufferedBeforeRelease)
    }

    return .consume
  }

  // MARK: - Chord match

  public func simulateChordMatch(normalisedInputKey: String) {
    handleChordMatch(normalisedInputKey: normalisedInputKey)
  }

  private func handleChordMatch(normalisedInputKey: String) {
    guard let chord = registry.chord(forNormalisedInputKey: normalisedInputKey) else {
      chordDetection.resumeAccumulating()
      return
    }

    chordDetection.beginReplacement()
    replaceCharacters(chord: chord)
    registry.recordUsage(for: chord)
    setCapitalisationMode(.off)
    chordDetection.endReplacementIfNoPendingEchoes()
  }

  private func replaceCharacters(chord: Chord) {
    let resolved = chord.resolveReplacement(
      capitalisationMode: calculatedCapitalisationMode,
      autoInsertedSpaceBeforeInput: autoInsertedSpaceBeforeCurrentInput
    )

    let result = output.insertReplacement(chord: chord, resolved: resolved)
    if mode == .legacyPassThrough, result.legacyEchoCount > 0 {
      chordDetection.scheduleEchoes(result.legacyEchoCount)
    }
    updatePostReplacementSpacingState(for: chord)
  }

  private func updatePostReplacementSpacingState(for chord: Chord) {
    autoInsertedSpaceBeforeCurrentInput = false
    owedSpace = !chord.hasPipe
  }

  private func resetChordInputState() {
    setCapitalisationMode(.off)
    chordDetection.reset()
    owedSpace = false
    autoInsertedSpaceBeforeCurrentInput = false
  }

  private func setCapitalisationMode(_ mode: CapitalisationMode) {
    guard capitalisationMode != mode else { return }
    capitalisationMode = mode
    delegate?.chordInputCoordinator(self, capitalisationModeDidChange: mode)
  }

  private func isResetKey(_ keyCode: UInt16) -> Bool {
    keyCode == SharedKeyboardConstants.spaceEventKey
      || keyCode == SharedKeyboardConstants.tabEventKey
      || keyCode == SharedKeyboardConstants.backspaceEventKey
      || keyCode == SharedKeyboardConstants.returnEventKey
      || keyCode == SharedKeyboardConstants.escapeEventKey
      || keyCode == SharedKeyboardConstants.leftEventKey
      || keyCode == SharedKeyboardConstants.rightEventKey
  }
}

/// Lightweight modifier flags without importing AppKit in ChorderCore.
public struct NSEventModifierFlagsProxy: OptionSet {
  public let rawValue: UInt

  public init(rawValue: UInt) {
    self.rawValue = rawValue
  }

  public static let shift = NSEventModifierFlagsProxy(rawValue: 1 << 17)
  public static let command = NSEventModifierFlagsProxy(rawValue: 1 << 20)
  public static let option = NSEventModifierFlagsProxy(rawValue: 1 << 19)
  public static let control = NSEventModifierFlagsProxy(rawValue: 1 << 18)
  public static let function = NSEventModifierFlagsProxy(rawValue: 1 << 23)

  public var containsCommandOrOptionOrControlOrFunction: Bool {
    contains(.command) || contains(.option) || contains(.control) || contains(.function)
  }
}
