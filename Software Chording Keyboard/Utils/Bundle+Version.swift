//
//  Bundle+Version.swift
//  Software Chording Keyboard
//

import Foundation

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    var appDisplayName: String {
        (infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (infoDictionary?["CFBundleName"] as? String)
            ?? menuProductName
    }

    var feedbackURL: URL {
        URL(string: "https://www.georgegillams.co.uk/chorder-feedback")!
    }

    /// True for debug builds run from Xcode (distinct bundle ID and menu label).
    var isLocalDevelopment: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Marketing name used in menu bar items (not the local build suffix).
    var menuProductName: String {
        "Software Chording Keyboard"
    }

    /// Shown in the menu bar build line.
    var menuBuildLabel: String {
        isLocalDevelopment ? "local development" : appVersion
    }
}
