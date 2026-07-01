//
//  LegacyTextOutputter.swift
//  Chorder
//

import AppKit
import ChorderCore
import Foundation

/// Legacy text output via Accessibility API or synthetic CGEvent keystrokes.
final class LegacyTextOutputter: ChordTextOutputting {
  private let textReplacer = TextReplacer()
  private let useAccessibilityAPI: () -> Bool

  init(useAccessibilityAPI: @escaping () -> Bool) {
    self.useAccessibilityAPI = useAccessibilityAPI
  }

  func insertReplacement(chord: Chord, resolved: ResolvedChordReplacement) -> ChordOutputResult {
    if useAccessibilityAPI(), !Bundle.main.isAppSandboxed {
      if textReplacer.replaceViaAccessibility(chord: chord, resolved: resolved) {
        return ChordOutputResult(success: true)
      }
    }

    let echoCount = textReplacer.replaceViaSyntheticKeys(chord: chord, resolved: resolved)
    return ChordOutputResult(success: true, legacyEchoCount: echoCount)
  }

  func insertOwedSpace(before character: String) -> ChordOutputResult {
    let echoCount = textReplacer.insertOwedSpaceBefore(character: character)
    return ChordOutputResult(success: true, legacyEchoCount: echoCount)
  }

  func insertBufferedCharacters(_ text: String) -> ChordOutputResult {
    textReplacer.typeText(text)
    return ChordOutputResult(success: true, legacyEchoCount: 2)
  }
}
