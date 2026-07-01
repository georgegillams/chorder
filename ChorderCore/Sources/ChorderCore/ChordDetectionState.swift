import Foundation

public struct HeldKey: Equatable {
  public let keyCode: UInt16
  public let character: String

  public init(keyCode: UInt16, character: String) {
    self.keyCode = keyCode
    self.character = character
  }
}

public enum ChordDetectionPhase: Equatable {
  case idle
  case accumulating
  case holdPending(joinedSnapshot: String)
  case replacing
}

/// Tracks simultaneously held keys and debounces chord hold timing.
public final class ChordDetectionState {
  public private(set) var phase: ChordDetectionPhase = .idle
  private var heldKeys: [HeldKey] = []
  private var holdWorkItem: DispatchWorkItem?
  private var pendingEchoes = 0

  public var onChordMatched: ((String) -> Void)?
  public var isRegisteredChord: ((String) -> Bool)?

  public init() {}

  public func reset() {
    cancelHoldTimer()
    heldKeys.removeAll()
    pendingEchoes = 0
    phase = .idle
    ChorderCoreLogging.log("ChordDetectionState: reset")
  }

  public func scheduleEchoes(_ count: Int) {
    pendingEchoes += count
    ChorderCoreLogging.log("ChordDetectionState: scheduleEchoes count=\(count) pending=\(pendingEchoes)")
  }

  public func consumeEchoIfPending() -> Bool {
    guard pendingEchoes > 0 else { return false }
    pendingEchoes -= 1
    ChorderCoreLogging.log("ChordDetectionState: consumeEcho remaining=\(pendingEchoes)")
    if pendingEchoes == 0, phase == .replacing {
      finishReplacement()
    }
    return true
  }

  public func endReplacementIfNoPendingEchoes() {
    guard phase == .replacing, pendingEchoes == 0 else { return }
    finishReplacement()
  }

  public func keyDown(keyCode: UInt16, character: String?, holdDuration: TimeInterval) {
    guard phase != .replacing else { return }
    guard let character, !character.isEmpty else { return }
    if heldKeys.contains(where: { $0.keyCode == keyCode }) { return }

    heldKeys.append(HeldKey(keyCode: keyCode, character: character))
    updatePhaseAfterHeldKeysChanged()

    if heldKeys.count >= 2 {
      scheduleHoldTimer(holdDuration: holdDuration)
    } else {
      cancelHoldTimer()
    }
  }

  public func keyUp(keyCode: UInt16, holdDuration: TimeInterval) {
    guard phase != .replacing else { return }

    heldKeys.removeAll { $0.keyCode == keyCode }
    cancelHoldTimer()
    updatePhaseAfterHeldKeysChanged()
  }

  public func joinedCharactersLowercased() -> String {
    heldKeys.map(\.character).joined().lowercased()
  }

  public func joinedCharacters() -> String {
    heldKeys.map(\.character).joined()
  }

  public func normalisedInputKey() -> String {
    Chord.normalisedInputKey(for: joinedCharactersLowercased())
  }

  public func beginReplacement() {
    cancelHoldTimer()
    heldKeys.removeAll()
    phase = .replacing
    ChorderCoreLogging.log("ChordDetectionState: beginReplacement")
  }

  public func finishReplacement() {
    reset()
  }

  public func resumeAccumulating() {
    cancelHoldTimer()
    phase = heldKeys.isEmpty ? .idle : .accumulating
    ChorderCoreLogging.log("ChordDetectionState: resumeAccumulating phase=\(phase)")
  }

  public var isAccumulatingChordInput: Bool {
    !heldKeys.isEmpty && phase != .replacing
  }

  private func updatePhaseAfterHeldKeysChanged() {
    if heldKeys.isEmpty {
      phase = .idle
    } else if case .holdPending = phase {
      phase = .accumulating
    } else {
      phase = .accumulating
    }
  }

  private func scheduleHoldTimer(holdDuration: TimeInterval) {
    cancelHoldTimer()

    let snapshot = joinedCharactersLowercased()
    phase = .holdPending(joinedSnapshot: snapshot)

    let work = DispatchWorkItem { [weak self] in
      self?.evaluateHold(snapshot: snapshot)
    }
    holdWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
  }

  private func cancelHoldTimer() {
    holdWorkItem?.cancel()
    holdWorkItem = nil
  }

  private func evaluateHold(snapshot: String) {
    guard case .holdPending = phase else { return }

    let current = joinedCharactersLowercased()
    guard current == snapshot else {
      updatePhaseAfterHeldKeysChanged()
      return
    }

    let normalisedKey = normalisedInputKey()
    let registered = isRegisteredChord?(normalisedKey) ?? false
    guard registered else {
      updatePhaseAfterHeldKeysChanged()
      return
    }

    onChordMatched?(normalisedKey)
  }
}
