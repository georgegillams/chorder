//
//  ChordPracticeSelection.swift
//  Software Chording Keyboard
//

import AppKit
import Foundation

enum ChordPracticeSelection {
    /// Picks a chord at random, weighted toward lower usage counts.
    static func pick(from chords: [Chord], excludingId: Chord.ID? = nil) -> Chord? {
        let pool = chords.filter { $0.id != excludingId }
        guard !pool.isEmpty else { return nil }

        let weights = pool.map { chord in
            1.0 / Double(chord.totalUsageCount + 1)
        }
        let totalWeight = weights.reduce(0, +)
        var roll = Double.random(in: 0..<totalWeight)

        for (chord, weight) in zip(pool, weights) {
            roll -= weight
            if roll <= 0 {
                return chord
            }
        }

        return pool.last
    }

    /// Resolved output text shown in practice (placeholders expanded, pipe removed).
    static func displayOutput(for chord: Chord, referenceDate: Date = Date()) -> String {
        let (segments, _) = chord.resolveTypingSegments(referenceDate: referenceDate)
        return segments.joined()
    }

}

enum PracticeFeedbackSound {
    static func playSuccess() {
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}
