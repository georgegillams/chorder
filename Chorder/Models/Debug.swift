//
//  Debug.swift
//  Chorder
//
//  Created by George Gillams on 09/04/2025.
//

import Foundation

public func gDebugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    guard isGDebugScheme else { return }
    let message = items.map { "\($0)" }.joined(separator: separator)
    print(message, terminator: terminator)
    #endif
}

public var isGDebugScheme: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("G_DEBUG")
    #else
    false
    #endif
}
