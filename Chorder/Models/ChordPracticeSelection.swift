//
//  ChordPracticeSelection.swift
//  Chorder
//

import AppKit
import Foundation

enum ChordPracticeSelection {
    /// Picks a chord at random, weighted toward lower usage counts.
    static func pick(from chords: [Chord], excludingId: Chord.ID? = nil) -> Chord? {
        let pool = chords.filter { $0.id != excludingId }
        guard !pool.isEmpty else { return nil }

        // Less-used chords get higher weight (e.g. usage 0 → 1.0, usage 9 → 0.1).
        let weights = pool.map { chord in
            1.0 / Double(chord.totalUsageCount + 1)
        }
        // reduce(0, +) sums the array: starts at 0, then adds each weight.
        let totalWeight = weights.reduce(0, +)
        var roll = Double.random(in: 0..<totalWeight)

        // zip pairs pool[i] with weights[i] so we can walk chords alongside their weights.
        for (chord, weight) in zip(pool, weights) {
            roll -= weight
            if roll <= 0 {
                return chord
            }
        }

        return pool.last
    }

}

enum PracticeFeedbackSound {
    static func playSuccess() {
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}
