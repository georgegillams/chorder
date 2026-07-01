import Foundation

public enum ChordCapitalisationMode: String, CaseIterable, Identifiable, Hashable, Codable {
  case `default`
  case alwaysOriginalCase

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .default:
      return "Default"
    case .alwaysOriginalCase:
      return "Always original case"
    }
  }
}

public enum ChordSpaceBeforeOutputMode: String, CaseIterable, Identifiable, Hashable, Codable {
  case `default`
  case always
  case never

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .default:
      return "Default"
    case .always:
      return "Always"
    case .never:
      return "Never"
    }
  }
}

extension String {
  public func capitalizeFirstLetter() -> String {
    prefix(1).uppercased() + lowercased().dropFirst()
  }

  public func chunked(into size: Int) -> [String] {
    stride(from: 0, to: count, by: size).map {
      String(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: min($0 + size, count))])
    }
  }
}

let specialChars = "*&^%$£@!#~`()[]{}<>?/;:.,-_=+)1234567890"
let maximumOutputChunkLength = 10

public enum SpaceBeforeOutputCorrection {
  case none
  case removeAutoInsertedSpace
  case prependSpaceToOutput
}

public struct ResolvedChordReplacement {
  public let segments: [String]
  public let leftArrowCount: Int
  public let backspacesBeforeOutput: Int

  public var outputText: String { segments.joined() }

  public init(segments: [String], leftArrowCount: Int, backspacesBeforeOutput: Int) {
    self.segments = segments
    self.leftArrowCount = leftArrowCount
    self.backspacesBeforeOutput = backspacesBeforeOutput
  }

  public func syntheticKeyEchoCount(inputDeleteCount: Int) -> Int {
    let syntheticKeyPressCount = inputDeleteCount + 1 + backspacesBeforeOutput + leftArrowCount
    return (2 * syntheticKeyPressCount) + (2 * segments.count) + 2
  }
}
