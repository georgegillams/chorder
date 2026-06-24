//
//  Debug.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 09/04/2025.
//

import Foundation

public func gDebugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if G_DEBUG
    print(items, separator: separator, terminator: terminator)
    #endif
}

public var isGDebugScheme: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("G_DEBUG")
    #else
    false
    #endif
}
