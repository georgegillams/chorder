import Foundation

public struct ChordOutputResult {
  public let success: Bool
  /// Synthetic monitor callbacks to ignore (legacy CGEvent path only).
  public let legacyEchoCount: Int

  public init(success: Bool, legacyEchoCount: Int = 0) {
    self.success = success
    self.legacyEchoCount = legacyEchoCount
  }
}

public protocol ChordTextOutputting: AnyObject {
  func insertReplacement(chord: Chord, resolved: ResolvedChordReplacement) -> ChordOutputResult
  func insertOwedSpace(before character: String) -> ChordOutputResult
  /// Insert buffered characters when chord input was consumed but did not match.
  func insertBufferedCharacters(_ text: String) -> ChordOutputResult
}

public protocol ChordRegistryProviding: AnyObject {
  var holdDuration: TimeInterval { get }
  func chord(forNormalisedInputKey key: String) -> Chord?
  func recordUsage(for chord: Chord)
}

public protocol ChordInputCoordinatorDelegate: AnyObject {
  func chordInputCoordinator(_ coordinator: ChordInputCoordinator, capitalisationModeDidChange mode: CapitalisationMode)
}
