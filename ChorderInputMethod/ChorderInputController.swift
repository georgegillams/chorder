//
//  ChorderInputController.swift
//  ChorderInputMethod
//

import AppKit
import Foundation
import InputMethodKit

final class ChorderInputController: IMKInputController {
  private static let registry = SharedSettingsChordRegistry()
  private static let sessions = NSMapTable<AnyObject, IMKChordSession>.weakToStrongObjects()

  private var session: IMKChordSession? {
    guard let client = client() else { return nil }
    if let existing = Self.sessions.object(forKey: client as AnyObject) {
      return existing
    }
    let newSession = IMKChordSession(registry: Self.registry)
    newSession.attach(client: client)
    Self.sessions.setObject(newSession, forKey: client as AnyObject)
    return newSession
  }

  override func recognizedEvents(_ sender: Any!) -> Int {
    Int(NSEvent.EventTypeMask([.keyDown, .keyUp, .flagsChanged]).rawValue)
  }

  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event, let client = sender as? (any IMKTextInput) else {
      return false
    }
    Self.registry.forceReload()
    return session?.handle(event: event, client: client) ?? false
  }

  override func activateServer(_ sender: Any!) {
    Self.registry.forceReload()
    super.activateServer(sender)
  }
}
