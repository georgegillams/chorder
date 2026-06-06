//
//  PracticeChordMonitor.swift
//  Software Chording Keyboard
//

import AppKit
import Combine
import Foundation

/// Captures local keyboard events so chord holds can be practised inside the app window.
final class PracticeChordMonitor: ObservableObject {
    @Published private(set) var heldCharacters = ""

    private let chordDetection = ChordDetectionState()
    private var localMonitors: [Any] = []
    private var targetNormalisedInput = ""
    private var holdDuration: TimeInterval = 0
    var onSuccess: (() -> Void)?

    deinit {
        stop()
    }

    func start(targetChord: Chord, holdDurationMilliseconds: Double) {
        stop()

        targetNormalisedInput = Chord.normalisedInputKey(for: targetChord.input)
        holdDuration = holdDurationMilliseconds / 1000

        chordDetection.onChordMatched = { [weak self] normalisedKey in
            self?.handleChordMatched(normalisedKey)
        }
        chordDetection.isRegisteredChord = { [weak self] key in
            key == self?.targetNormalisedInput
        }

        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.shouldCapture(event) else { return event }
            self.handleKeyDown(event)
            return nil
        }
        let keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return event }
            guard self.shouldCapture(event) else { return event }
            self.handleKeyUp(event)
            return nil
        }

        localMonitors = [keyDownMonitor, keyUpMonitor].compactMap { $0 }
    }

    func stop() {
        for monitor in localMonitors {
            NSEvent.removeMonitor(monitor)
        }
        localMonitors = []
        chordDetection.reset()
        heldCharacters = ""
    }

    private func shouldCapture(_ event: NSEvent) -> Bool {
        !event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.option)
            && !event.modifierFlags.contains(.control)
            && !event.modifierFlags.contains(.function)
    }

    private func handleKeyDown(_ event: NSEvent) {
        let eventKey = event.keyCode

        if eventKey == KeyboardConstants.spaceEventKey
            || eventKey == KeyboardConstants.tabEventKey
            || eventKey == KeyboardConstants.backspaceEventKey
            || eventKey == KeyboardConstants.returnEventKey
            || eventKey == KeyboardConstants.escapeEventKey
            || eventKey == KeyboardConstants.leftEventKey
            || eventKey == KeyboardConstants.rightEventKey {
            chordDetection.reset()
            updateHeldCharacters()
            return
        }

        chordDetection.keyDown(
            keyCode: eventKey,
            character: event.characters,
            holdDuration: holdDuration
        )
        updateHeldCharacters()
    }

    private func handleKeyUp(_ event: NSEvent) {
        chordDetection.keyUp(
            keyCode: event.keyCode,
            holdDuration: holdDuration
        )
        updateHeldCharacters()
    }

    private func handleChordMatched(_ normalisedKey: String) {
        guard normalisedKey == targetNormalisedInput else { return }

        chordDetection.beginReplacement()
        chordDetection.endReplacementIfNoPendingEchoes()
        heldCharacters = ""
        onSuccess?()
    }

    private func updateHeldCharacters() {
        heldCharacters = chordDetection.joinedCharactersLowercased()
    }
}

#if DEBUG
extension PracticeChordMonitor {
    func handleKeyDownForTesting(_ event: NSEvent) {
        handleKeyDown(event)
    }
}
#endif
