//
//  ChordDetectionState.swift
//  Chorder
//

import Foundation

struct HeldKey: Equatable {
    let keyCode: UInt16
    let character: String
}

enum ChordDetectionPhase: Equatable {
    case idle
    case accumulating
    case holdPending(joinedSnapshot: String)
    case replacing
}

/// Tracks simultaneously held keys and debounces chord hold timing.
final class ChordDetectionState {
    private(set) var phase: ChordDetectionPhase = .idle
    private var heldKeys: [HeldKey] = []
    private var holdWorkItem: DispatchWorkItem?
    /// Synthetic key events (CGEvent) echoed back through global monitors.
    private var pendingEchoes = 0

    var onChordMatched: ((String) -> Void)?
    /// Check against configured chords (sorted input key). Wired once at launch; registry
    /// is rebuilt in AppSettings when chords load or change.
    var isRegisteredChord: ((String) -> Bool)?

    func reset() {
        cancelHoldTimer()
        heldKeys.removeAll()
        pendingEchoes = 0
        phase = .idle
        gDebugPrint("ChordDetectionState: reset")
    }

    /// Registers monitor callbacks to skip after posting synthetic key events.
    func scheduleEchoes(_ count: Int) {
        pendingEchoes += count
        gDebugPrint("ChordDetectionState: scheduleEchoes count=\(count) pending=\(pendingEchoes)")
    }

    /// Returns true when this monitor callback should be ignored (synthetic echo).
    func consumeEchoIfPending() -> Bool {
        guard pendingEchoes > 0 else { return false }
        pendingEchoes -= 1
        gDebugPrint("ChordDetectionState: consumeEcho remaining=\(pendingEchoes)")
        if pendingEchoes == 0, phase == .replacing {
            finishReplacement()
        }
        return true
    }

    /// Completes replacement immediately when no synthetic echoes are still in flight.
    func endReplacementIfNoPendingEchoes() {
        guard phase == .replacing, pendingEchoes == 0 else { return }
        finishReplacement()
    }

    func keyDown(keyCode: UInt16, character: String?, holdDuration: TimeInterval) {
        guard phase != .replacing else {
            gDebugPrint("ChordDetectionState: keyDown ignored while replacing keyCode=\(keyCode)")
            return
        }
        guard let character, !character.isEmpty else {
            gDebugPrint("ChordDetectionState: keyDown ignored empty character keyCode=\(keyCode)")
            return
        }

        if heldKeys.contains(where: { $0.keyCode == keyCode }) {
            gDebugPrint("ChordDetectionState: keyDown ignored repeat keyCode=\(keyCode)")
            return
        }

        heldKeys.append(HeldKey(keyCode: keyCode, character: character))
        updatePhaseAfterHeldKeysChanged()
        gDebugPrint("ChordDetectionState: keyDown keyCode=\(keyCode) char=\(character) held=\(joinedCharactersLowercased()) phase=\(phase)")

        if heldKeys.count >= 2 {
            scheduleHoldTimer(holdDuration: holdDuration)
        } else {
            cancelHoldTimer()
        }
    }

    func keyUp(keyCode: UInt16, holdDuration: TimeInterval) {
        guard phase != .replacing else {
            gDebugPrint("ChordDetectionState: keyUp ignored while replacing keyCode=\(keyCode)")
            return
        }

        heldKeys.removeAll { $0.keyCode == keyCode }
        cancelHoldTimer()
        updatePhaseAfterHeldKeysChanged()
        gDebugPrint("ChordDetectionState: keyUp keyCode=\(keyCode) held=\(joinedCharactersLowercased()) phase=\(phase)")
    }

    func joinedCharactersLowercased() -> String {
        heldKeys.map(\.character).joined().lowercased()
    }

    func normalisedInputKey() -> String {
        Chord.normalisedInputKey(for: joinedCharactersLowercased())
    }

    func beginReplacement() {
        cancelHoldTimer()
        heldKeys.removeAll()
        phase = .replacing
        gDebugPrint("ChordDetectionState: beginReplacement")
    }

    func finishReplacement() {
        reset()
    }

    func resumeAccumulating() {
        cancelHoldTimer()
        phase = heldKeys.isEmpty ? .idle : .accumulating
        gDebugPrint("ChordDetectionState: resumeAccumulating phase=\(phase)")
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
        gDebugPrint("ChordDetectionState: scheduling hold snapshot=\(snapshot) duration=\(holdDuration)s")

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
        guard case .holdPending = phase else {
            gDebugPrint("ChordDetectionState: evaluateHold skipped phase=\(phase)")
            return
        }

        let current = joinedCharactersLowercased()
        guard current == snapshot else {
            gDebugPrint("ChordDetectionState: evaluateHold snapshot mismatch snapshot=\(snapshot) current=\(current)")
            updatePhaseAfterHeldKeysChanged()
            return
        }

        let normalisedKey = normalisedInputKey()
        let registered = isRegisteredChord?(normalisedKey) ?? false
        gDebugPrint("ChordDetectionState: evaluateHold normalisedKey=\(normalisedKey) registered=\(registered)")

        guard registered else {
            gDebugPrint("ChordDetectionState: evaluateHold no registered chord for \(normalisedKey)")
            updatePhaseAfterHeldKeysChanged()
            return
        }

        gDebugPrint("ChordDetectionState: evaluateHold matched \(normalisedKey)")
        onChordMatched?(normalisedKey)
    }
}
