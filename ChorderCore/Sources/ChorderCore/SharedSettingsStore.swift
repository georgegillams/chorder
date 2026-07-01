import Foundation

public struct SharedChordSettings: Codable, Equatable {
  public var migrationVersion: Int?
  public var millisecondsToHold: String
  public var useAccessibilityAPI: Bool?
  public var inputMechanism: String?
  public var chords: [SharedSerialisableChord]

  public init(
    migrationVersion: Int? = nil,
    millisecondsToHold: String,
    useAccessibilityAPI: Bool? = nil,
    inputMechanism: String? = nil,
    chords: [SharedSerialisableChord]
  ) {
    self.migrationVersion = migrationVersion
    self.millisecondsToHold = millisecondsToHold
    self.useAccessibilityAPI = useAccessibilityAPI
    self.inputMechanism = inputMechanism
    self.chords = chords
  }
}

public struct SharedSerialisableChord: Codable, Equatable {
  public var id: String
  public var input: String
  public var output: String
  public var capitalisationMode: String?
  public var spaceBeforeOutput: String?
  public var deleted: Bool?

  public init(
    id: String,
    input: String,
    output: String,
    capitalisationMode: String? = nil,
    spaceBeforeOutput: String? = nil,
    deleted: Bool? = nil
  ) {
    self.id = id
    self.input = input
    self.output = output
    self.capitalisationMode = capitalisationMode
    self.spaceBeforeOutput = spaceBeforeOutput
    self.deleted = deleted
  }
}

public enum SharedSettingsStore {
  public static let appGroupIdentifier = "group.uk.co.georgegillams.chorder"
  public static let settingsFileName = "chorder_settings.json"

  public static var appGroupContainerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
  }

  public static var sharedSettingsFileURL: URL? {
    appGroupContainerURL?.appendingPathComponent(settingsFileName)
  }

  @discardableResult
  public static func syncSettingsJSON(_ json: String) -> Bool {
    guard let url = sharedSettingsFileURL else { return false }
    do {
      try json.write(to: url, atomically: true, encoding: .utf8)
      return true
    } catch {
      ChorderCoreLogging.log("SharedSettingsStore sync failed: \(error)")
      return false
    }
  }

  public static func loadSettings() -> SharedChordSettings? {
    guard let url = sharedSettingsFileURL,
          let data = try? Data(contentsOf: url) else {
      return nil
    }
    return try? JSONDecoder().decode(SharedChordSettings.self, from: data)
  }

  public static func parseHoldDelayMilliseconds(from string: String) -> Double? {
    let trimmed = string
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "ms", with: "", options: .caseInsensitive)
    guard let value = Double(trimmed), value >= 10, value <= 2000 else {
      return nil
    }
    return value
  }

  public static func chordLookup(from settings: SharedChordSettings) -> [String: Chord] {
    var dictionary: [String: Chord] = [:]
    for serialisable in settings.chords {
      if serialisable.deleted == true { continue }
      let capitalisationMode = ChordCapitalisationMode(rawValue: serialisable.capitalisationMode ?? "") ?? .default
      let spaceBeforeOutputMode = ChordSpaceBeforeOutputMode(rawValue: serialisable.spaceBeforeOutput ?? "") ?? .default
      let chord = Chord(
        id: serialisable.id,
        input: serialisable.input,
        output: serialisable.output,
        capitalisationMode: capitalisationMode,
        spaceBeforeOutputMode: spaceBeforeOutputMode,
        deleted: false
      )
      dictionary[chord.inputSorted] = chord
    }
    return dictionary
  }
}
