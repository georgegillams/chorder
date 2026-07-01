//
//  KeyboardInputEngine.swift
//  Chorder
//

import AppKit
import ChorderCore
import Foundation

protocol KeyboardInputEngineDelegate: AnyObject {
  func keyboardInputEngine(_ engine: KeyboardInputEngine, capitalisationModeDidChange mode: CapitalisationMode)
}

/// Legacy global-monitor keyboard input adapter.
final class KeyboardInputEngine: ChordInputCoordinatorDelegate {
  weak var delegate: KeyboardInputEngineDelegate?

  private let coordinator: ChordInputCoordinator

  var calculatedCapitalisationMode: CapitalisationMode {
    coordinator.calculatedCapitalisationMode
  }

  var capitalisationMode: CapitalisationMode {
    coordinator.capitalisationMode
  }

  var owesTrailingSpace: Bool { coordinator.owesTrailingSpace }
  var joinedHeldCharacters: String { coordinator.joinedHeldCharacters }

  init(appSettings: AppSettings) {
    let registry = AppSettingsChordRegistry(appSettings: appSettings)
    let output = LegacyTextOutputter { appSettings.useAccessibilityAPI }
    coordinator = ChordInputCoordinator(
      registry: registry,
      output: output,
      mode: .legacyPassThrough
    )
    coordinator.delegate = self
  }

  func handleFlagsChanged(_ event: NSEvent) {
    if event.modifierFlags.contains(.shift) {
      coordinator.handleShiftPressed()
    } else {
      coordinator.handleShiftReleased()
    }
    gDebugPrint("shift pressed")
  }

  func handleKeyDown(_ event: NSEvent) {
    let modifiers = NSEventModifierFlagsProxy(rawValue: event.modifierFlags.rawValue)
    coordinator.handleLegacyKeyDown(
      keyCode: event.keyCode,
      character: event.characters,
      modifiers: modifiers
    )
    gDebugPrint("chordDetection joined \(coordinator.joinedHeldCharacters)")
  }

  func handleKeyUp(_ event: NSEvent) {
    coordinator.handleLegacyKeyUp(keyCode: event.keyCode)
    gDebugPrint("chordDetection joined \(coordinator.joinedHeldCharacters)")
  }

  func handleChordMatch(normalisedInputKey: String) {
    coordinator.simulateChordMatch(normalisedInputKey: normalisedInputKey)
  }

  func chordInputCoordinator(_ coordinator: ChordInputCoordinator, capitalisationModeDidChange mode: CapitalisationMode) {
    delegate?.keyboardInputEngine(self, capitalisationModeDidChange: mode)
  }
}
