//
//  Constants.swift
//  Chorder
//

import Cocoa
import ChorderCore
import Foundation
import AppKit
import SwiftUI

@_exported import enum ChorderCore.CapitalisationMode

// Bundle identifiers of apps whose kAXSelectedTextAttribute write implementation is known to be
// broken — the write returns success but silently discards the output and corrupts the field.
let axIncompatibleAppBundleIDs: Set<String> = [
    "org.mozilla.firefox",
    "org.mozilla.nightly",
    "org.mozilla.firefoxdeveloperedition",
]

class KeyboardConstants {
    static let spaceEventKey = SharedKeyboardConstants.spaceEventKey
    static let spaceKeyCode = CGKeyCode(spaceEventKey)
    static let tabEventKey = SharedKeyboardConstants.tabEventKey
    static let tabKeyCode = CGKeyCode(tabEventKey)
    static let backspaceEventKey = SharedKeyboardConstants.backspaceEventKey
    static let backspaceKeyCode = CGKeyCode(backspaceEventKey)
    static let escapeEventKey = SharedKeyboardConstants.escapeEventKey
    static let escapeKeyCode = CGKeyCode(escapeEventKey)
    static let leftEventKey = SharedKeyboardConstants.leftEventKey
    static let leftKeyCode = CGKeyCode(leftEventKey)
    static let rightEventKey = SharedKeyboardConstants.rightEventKey
    static let rightKeyCode = CGKeyCode(rightEventKey)
    static let returnEventKey = SharedKeyboardConstants.returnEventKey
    static let returnKeyCode = CGKeyCode(returnEventKey)
    static let fullStopEventKey = 47
    static let fullStopKeyCode = CGKeyCode(fullStopEventKey)
    static let shiftEventKey = 52
    static let shiftKeyCode = CGKeyCode(shiftEventKey)
    static let deleteEventKey = 127
    static let deleteKeyCode = CGKeyCode(deleteEventKey)
    static let skipPrecedingSpaceCharacters = SharedKeyboardConstants.skipPrecedingSpaceCharacters
}
