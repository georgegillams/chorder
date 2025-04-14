//
//  Constants.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 10/04/2023.
//

import Cocoa
import Foundation
import AppKit
import SwiftUI

enum CapitalisationMode {
    case off, singleCharacter, fullCapitalisation
}

class KeyboardConstants {
    static let spaceEventKey = 49
    static let spaceKeyCode = CGKeyCode(spaceEventKey)
    static let tabEventKey = 48
    static let tabKeyCode = CGKeyCode(tabEventKey)
    static let backspaceEventKey = 51
    static let backspaceKeyCode = CGKeyCode(backspaceEventKey)
    static let escapeEventKey = 53
    static let escapeKeyCode = CGKeyCode(escapeEventKey)
    static let leftEventKey = 123
    static let leftKeyCode = CGKeyCode(leftEventKey)
    static let rightEventKey = 124
    static let rightKeyCode = CGKeyCode(rightEventKey)
    static let returnEventKey = 36
    static let returnKeyCode = CGKeyCode(returnEventKey)
    static let fullStopEventKey = 47
    static let fullStopKeyCode = CGKeyCode(returnEventKey)
    static let shiftEventKey = 52
    static let shiftKeyCode = CGKeyCode(shiftEventKey)
    static let deleteEventKey = 127
    static let deleteKeyCode = CGKeyCode(deleteEventKey)
    static let skipPreceedingSpaceCharacters = ["!", "@", "%", "*", ")", "_", "-", "=", "+", "`", "~", "|", "\\", "/", ":", ";", ">", "?", ",", ".", "&", "#"]
}
