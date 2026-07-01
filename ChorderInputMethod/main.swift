//
//  main.swift
//  ChorderInputMethod
//

import Cocoa
import InputMethodKit

private extension Bundle {
  var inputMethodConnectionName: String {
    guard let name = infoDictionary?["InputMethodConnectionName"] as? String else {
      fatalError("InputMethodConnectionName missing from Info.plist")
    }
    return name
  }
}

let bundle = Bundle.main
guard let bundleIdentifier = bundle.bundleIdentifier else {
  fatalError("Bundle identifier missing")
}

_ = IMKServer(
  name: bundle.inputMethodConnectionName,
  bundleIdentifier: bundleIdentifier
)

RunLoop.current.run()
