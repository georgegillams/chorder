//
//  IMKTextInserter.swift
//  ChorderInputMethod
//

import ChorderCore
import Foundation
import InputMethodKit

final class IMKTextInserter: ChordTextOutputting {
  private weak var client: (any IMKTextInput)?

  init(client: any IMKTextInput) {
    self.client = client
  }

  func insertReplacement(chord: Chord, resolved: ResolvedChordReplacement) -> ChordOutputResult {
    guard let client else { return ChordOutputResult(success: false) }

    let outputText = resolved.outputText
    client.insertText(
      outputText,
      replacementRange: NSRange(location: NSNotFound, length: 0)
    )

    return ChordOutputResult(success: true)
  }

  func insertOwedSpace(before character: String) -> ChordOutputResult {
    guard let client else { return ChordOutputResult(success: false) }
    client.insertText(
      " \(character)",
      replacementRange: NSRange(location: NSNotFound, length: 0)
    )
    return ChordOutputResult(success: true)
  }

  func insertBufferedCharacters(_ text: String) -> ChordOutputResult {
    guard let client else { return ChordOutputResult(success: false) }
    client.insertText(
      text,
      replacementRange: NSRange(location: NSNotFound, length: 0)
    )
    return ChordOutputResult(success: true)
  }
}
