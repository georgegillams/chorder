//
//  IMKChordSession.swift
//  ChorderInputMethod
//

import AppKit
import ChorderCore
import Foundation
import InputMethodKit

final class IMKChordSession {
  private let registry: SharedSettingsChordRegistry
  private var coordinator: ChordInputCoordinator?
  private weak var client: IMKTextInput?

  init(registry: SharedSettingsChordRegistry) {
    self.registry = registry
  }

  func attach(client: IMKTextInput) {
    self.client = client
    let inserter = IMKTextInserter(client: client)
    coordinator = ChordInputCoordinator(
      registry: registry,
      output: inserter,
      mode: .inputMethodConsume
    )
  }

  func handle(event: NSEvent, client: IMKTextInput) -> Bool {
    guard let coordinator else { return false }

    switch event.type {
    case .flagsChanged:
      if event.modifierFlags.contains(.shift) {
        coordinator.handleShiftPressed()
      } else {
        coordinator.handleShiftReleased()
      }
      return false

    case .keyDown:
      let modifiers = NSEventModifierFlagsProxy(rawValue: event.modifierFlags.rawValue)
      let result = coordinator.handleIMKKeyDown(
        keyCode: event.keyCode,
        character: event.characters,
        modifiers: modifiers
      )
      return result == .consume

    case .keyUp:
      let result = coordinator.handleIMKKeyUp(keyCode: event.keyCode)
      switch result {
      case .consume:
        return true
      case .passThrough:
        return false
      case .flushBuffered(let text):
        _ = IMKTextInserter(client: client).insertBufferedCharacters(text)
        return true
      }

    default:
      return false
    }
  }
}
