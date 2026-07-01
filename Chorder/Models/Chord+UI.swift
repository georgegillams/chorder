//
//  Chord+UI.swift
//  Chorder
//

import ChorderCore
import Foundation

extension ChordCapitalisationMode {
  var optionsSymbolName: String? {
    switch self {
    case .default:
      return nil
    case .alwaysOriginalCase:
      return "textformat.abc"
    }
  }

  var optionsTooltip: String? {
    switch self {
    case .default:
      return nil
    case .alwaysOriginalCase:
      return "Capitalisation: Always original case"
    }
  }
}

extension ChordSpaceBeforeOutputMode {
  var optionsSymbolName: String? {
    switch self {
    case .default:
      return nil
    case .always:
      return "space"
    case .never:
      return "arrow.left.to.line.compact"
    }
  }

  var optionsTooltip: String? {
    switch self {
    case .default:
      return nil
    case .always:
      return "Space before output: Always"
    case .never:
      return "Space before output: Never"
    }
  }
}
