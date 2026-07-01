//
//  InputMethodInstaller.swift
//  Chorder
//

import AppKit
import Carbon
import Foundation

enum InputMethodInstallStatus: Equatable {
  case notInstalled
  case installed
  case enabled
  case active
}

enum InputMethodInstaller {
  private static let inputMethodBundleName = "ChorderInputMethod.app"
  private static let expectedBundleIdentifier = "uk.co.georgegillams.inputmethod.chorder"

  static var userInputMethodsDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Input Methods", isDirectory: true)
  }

  static var installedBundleURL: URL {
    userInputMethodsDirectory.appendingPathComponent(inputMethodBundleName, isDirectory: true)
  }

  static var bundledInputMethodURL: URL? {
    Bundle.main.bundleURL
      .appendingPathComponent("Contents/Library/Input Methods/\(inputMethodBundleName)", isDirectory: true)
  }

  @discardableResult
  static func installFromAppBundleIfNeeded() -> Bool {
    guard let source = bundledInputMethodURL,
          FileManager.default.fileExists(atPath: source.path) else {
      gDebugPrint("InputMethodInstaller: bundled input method not found at \(bundledInputMethodURL?.path ?? "nil")")
      return false
    }

    do {
      try FileManager.default.createDirectory(at: userInputMethodsDirectory, withIntermediateDirectories: true)
      removeLegacyInstallsIfPresent()

      let needsCopy = !FileManager.default.fileExists(atPath: installedBundleURL.path)
        || installedBundleIdentifier != expectedBundleIdentifier

      if needsCopy {
        if FileManager.default.fileExists(atPath: installedBundleURL.path) {
          try FileManager.default.removeItem(at: installedBundleURL)
        }
        try FileManager.default.copyItem(at: source, to: installedBundleURL)
      }

      syncWithTextInputServices()
      return true
    } catch {
      gDebugPrint("InputMethodInstaller: failed to install — \(error)")
      return false
    }
  }

  static func syncWithTextInputServices() {
    registerInstalledInputMethod()
    _ = enableChorderInputSourceIfNeeded()
    ensureListedInEnabledInputSources()
    restartInputMenuAgents()
  }

  static func installStatus() -> InputMethodInstallStatus {
    guard FileManager.default.fileExists(atPath: installedBundleURL.path) else {
      return .notInstalled
    }

    let matching = chorderInputSources()
    guard !matching.isEmpty else {
      return .installed
    }

    let selectable = matching.filter(isSelectCapable(_:))
    guard !selectable.isEmpty else {
      return .installed
    }

    if let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
       selectable.contains(where: { CFEqual($0, current) }) {
      return .active
    }

    if selectable.contains(where: isEnabled(_:)) {
      return .enabled
    }

    return .installed
  }

  static func openKeyboardInputSourcesSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?InputSources")!)
  }

  static func selectChorderInputSource() {
    syncWithTextInputServices()
    guard let match = chorderInputSources().first(where: isSelectCapable(_:)) else {
      gDebugPrint("InputMethodInstaller: no selectable Chorder input source found")
      return
    }
    let status = TISSelectInputSource(match)
    if status != noErr {
      gDebugPrint("InputMethodInstaller: TISSelectInputSource failed — \(status)")
    }
  }

  static func openInstalledInputMethodForApproval() {
    guard FileManager.default.fileExists(atPath: installedBundleURL.path) else { return }
    NSWorkspace.shared.open(installedBundleURL)
  }

  @discardableResult
  private static func enableChorderInputSourceIfNeeded() -> Bool {
    let matching = chorderInputSources()
    guard !matching.isEmpty else { return false }

    let parents = matching.filter { source in
      guard let bundleID = TISGetInputSourceProperty(source, kTISPropertyBundleID) else { return false }
      return Unmanaged<CFString>.fromOpaque(bundleID).takeUnretainedValue() as String == expectedBundleIdentifier
        && !isSelectCapable(source)
    }

    for source in parents + matching where isEnableCapable(source) && !isEnabled(source) {
      let status = TISEnableInputSource(source)
      if status != noErr {
        gDebugPrint("InputMethodInstaller: TISEnableInputSource failed — \(status)")
      }
    }

    return chorderInputSources().contains(where: { isSelectCapable($0) && isEnabled($0) })
  }

  private static func registerInstalledInputMethod() {
    guard FileManager.default.fileExists(atPath: installedBundleURL.path) else { return }
    let status = TISRegisterInputSource(installedBundleURL as CFURL)
    if status != noErr {
      gDebugPrint("InputMethodInstaller: TISRegisterInputSource failed — \(status)")
    }
  }

  private static func removeLegacyInstallsIfPresent() {
    for name in ["ChorderInputMethod.bundle", "ChorderInputMethod.app"] {
      let url = userInputMethodsDirectory.appendingPathComponent(name, isDirectory: true)
      guard FileManager.default.fileExists(atPath: url.path) else { continue }
      if url.lastPathComponent == inputMethodBundleName,
         installedBundleIdentifier == expectedBundleIdentifier {
        continue
      }
      try? FileManager.default.removeItem(at: url)
    }
  }

  private static var installedBundleIdentifier: String? {
    let infoPlist = installedBundleURL.appendingPathComponent("Contents/Info.plist")
    return NSDictionary(contentsOf: infoPlist)?["CFBundleIdentifier"] as? String
  }

  private static func chorderInputSources() -> [TISInputSource] {
    guard let sources = allInstalledInputSources() else { return [] }
    return sources.filter { source in
      guard let id = TISGetInputSourceProperty(source, kTISPropertyBundleID) else { return false }
      let sourceBundleID = Unmanaged<CFString>.fromOpaque(id).takeUnretainedValue() as String
      if sourceBundleID == expectedBundleIdentifier { return true }
      guard let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
      let inputSourceID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
      return inputSourceID.hasPrefix(expectedBundleIdentifier)
    }
  }

  private static func allInstalledInputSources() -> [TISInputSource]? {
    TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource]
  }

  private static func isSelectCapable(_ source: TISInputSource) -> Bool {
    booleanProperty(kTISPropertyInputSourceIsSelectCapable, for: source) == true
  }

  private static func isEnableCapable(_ source: TISInputSource) -> Bool {
    booleanProperty(kTISPropertyInputSourceIsEnableCapable, for: source) == true
  }

  private static func isEnabled(_ source: TISInputSource) -> Bool {
    booleanProperty(kTISPropertyInputSourceIsEnabled, for: source) == true
  }

  private static func booleanProperty(_ key: CFString, for source: TISInputSource) -> Bool? {
    guard let value = TISGetInputSourceProperty(source, key) else { return nil }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
  }

  private static func ensureListedInEnabledInputSources() {
    let prefsURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Preferences/com.apple.HIToolbox.plist")

    guard let data = try? Data(contentsOf: prefsURL),
          var plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
      return
    }

    var sources = plist["AppleEnabledInputSources"] as? [[String: Any]] ?? []
    let alreadyListed = sources.contains { $0["Bundle ID"] as? String == expectedBundleIdentifier }
    guard !alreadyListed else { return }

    sources.append([
      "InputSourceKind": "Non Keyboard Input Method",
      "Bundle ID": expectedBundleIdentifier,
    ])
    plist["AppleEnabledInputSources"] = sources

    guard let updated = try? PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    ) else {
      return
    }

    do {
      try updated.write(to: prefsURL, options: .atomic)
      CFPreferencesAppSynchronize("com.apple.HIToolbox" as CFString)
    } catch {
      gDebugPrint("InputMethodInstaller: failed to update HIToolbox preferences — \(error)")
    }
  }

  private static func restartInputMenuAgents() {
    let agents = ["TextInputMenuAgent", "TextInputSwitcher"]
    for agent in agents {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
      process.arguments = [agent]
      try? process.run()
      process.waitUntilExit()
    }
  }
}
