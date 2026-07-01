//
//  SharedSettingsChordRegistry.swift
//  ChorderInputMethod
//

import ChorderCore
import Foundation

final class SharedSettingsChordRegistry: ChordRegistryProviding {
  private var cachedSettings: SharedChordSettings?
  private var chordLookup: [String: Chord] = [:]
  private var lastLoadedAt: Date = .distantPast
  private let reloadInterval: TimeInterval = 5

  var holdDuration: TimeInterval {
    reloadIfNeeded()
    if let settings = cachedSettings,
       let ms = SharedSettingsStore.parseHoldDelayMilliseconds(from: settings.millisecondsToHold) {
      return ms / 1000
    }
    return 0.1
  }

  func chord(forNormalisedInputKey key: String) -> Chord? {
    reloadIfNeeded()
    return chordLookup[key]
  }

  func recordUsage(for chord: Chord) {
    // Usage stats are recorded by the menu-bar settings app.
  }

  func reloadIfNeeded() {
    let now = Date()
    guard now.timeIntervalSince(lastLoadedAt) >= reloadInterval else { return }
    lastLoadedAt = now
    guard let settings = SharedSettingsStore.loadSettings() else { return }
    cachedSettings = settings
    chordLookup = SharedSettingsStore.chordLookup(from: settings)
  }

  func forceReload() {
    lastLoadedAt = .distantPast
    reloadIfNeeded()
  }
}
