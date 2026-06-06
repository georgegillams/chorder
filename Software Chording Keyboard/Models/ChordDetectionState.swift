//
//  ChordDetectionState.swift
//  Software Chording Keyboard
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

    var onChordMatched: ((String) -> Void)?

    func reset() {
        cancelHoldTimer()
        heldKeys.removeAll()
        phase = .idle
    }

    func keyDown(keyCode: UInt16, character: String?, holdDuration: TimeInterval) {
        guard phase != .replacing else { return }
        guard let character, !character.isEmpty else { return }

        // Ignore key repeat while a key stays held.
        if heldKeys.contains(where: { $0.keyCode == keyCode }) {
            return
        }

        heldKeys.append(HeldKey(keyCode: keyCode, character: character))
        updatePhaseAfterHeldKeysChanged()

        if heldKeys.count >= 2 {
            scheduleHoldTimer(holdDuration: holdDuration)
        } else {
            cancelHoldTimer()
        }
    }

    func keyUp(keyCode: UInt16, holdDuration: TimeInterval) {
        guard phase != .replacing else { return }

        heldKeys.removeAll { $0.keyCode == keyCode }
        cancelHoldTimer()
        updatePhaseAfterHeldKeysChanged()

        if heldKeys.count >= 2 {
            scheduleHoldTimer(holdDuration: holdDuration)
        }
    }

    /// Characters joined in key-down order (lowercased), used for hold stability checks.
    func joinedCharactersLowercased() -> String {
        heldKeys.map(\.character).joined().lowercased()
    }

    /// Sorted character key for chord dictionary lookup.
    func normalisedInputKey() -> String {
        Chord.normalisedInputKey(for: joinedCharactersLowercased())
    }

    func beginReplacement() {
        cancelHoldTimer()
        heldKeys.removeAll()
        phase = .replacing
    }

    func finishReplacement() {
        reset()
    }

    /// Called when a hold completed but no configured chord matched.
    func resumeAccumulating() {
        cancelHoldTimer()
        phase = heldKeys.isEmpty ? .idle : .accumulating
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

        // Suppose we have 2 chords that use the same input prefix. eg hi->hi and hid->hid
        // If a user pressed hid together, we shouldn't print "hi" as, even if the snapshot was "hi",
        // by the time the hold duration has passed, the held keys will have changed.
        guard joinedCharactersLowercased() == snapshot else {
            updatePhaseAfterHeldKeysChanged()
            return
        }

        onChordMatched?(normalisedInputKey())
    }
}
