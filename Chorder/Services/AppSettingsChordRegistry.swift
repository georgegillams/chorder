//
//  AppSettingsChordRegistry.swift
//  Chorder
//

import ChorderCore
import Foundation

final class AppSettingsChordRegistry: ChordRegistryProviding {
  private let appSettings: AppSettings

  init(appSettings: AppSettings) {
    self.appSettings = appSettings
  }

  var holdDuration: TimeInterval {
    appSettings.millisecondsToHold / 1000
  }

  func chord(forNormalisedInputKey key: String) -> Chord? {
    appSettings.alphabeticalInputOutputMappingDictionary[key]
  }

  func recordUsage(for chord: Chord) {
    appSettings.incrementUsage(for: chord)
  }
}
