//
//  Debug.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 09/04/2025.
//

public func gDebugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    print(items, separator: separator, terminator: terminator)
    #endif
}
