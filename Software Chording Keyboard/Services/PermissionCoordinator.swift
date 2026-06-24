//
//  PermissionCoordinator.swift
//  Software Chording Keyboard
//

import AppKit
import Foundation

final class PermissionCoordinator {
    private let recheckInterval: TimeInterval = 10

    func hasInputMonitoringPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        }
        return true
    }

    func requestInputMonitoringPermission() {
        if #available(macOS 10.15, *) {
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
    }

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openInputMonitoringSettings() {
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring")!)
        }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openFeedback() {
        NSWorkspace.shared.open(Bundle.main.feedbackURL)
    }

    func beginPermissionChecks() {
        checkNextPermission()
    }

    // Recursively requests each permission, until all required permissions are available
    private func checkNextPermission() {
        let hasInputMonitoringPermission = hasInputMonitoringPermission()
        gDebugPrint("Input monitoring access: \(hasInputMonitoringPermission)")

        if !hasInputMonitoringPermission {
            requestInputMonitoringPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + recheckInterval) { [weak self] in
                self?.checkNextPermission()
            }
            return
        }

        let hasAccessibilityPermission = hasAccessibilityPermission()
        gDebugPrint("Accessibility access: \(hasAccessibilityPermission)")

        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + recheckInterval) { [weak self] in
                self?.checkNextPermission()
            }
        }
    }
}

extension PermissionCoordinator: SettingsActions {}
