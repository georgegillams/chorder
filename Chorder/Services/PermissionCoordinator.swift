//
//  PermissionCoordinator.swift
//  Chorder
//

import AppKit
import ChorderCore
import Foundation

final class PermissionCoordinator {
    private let recheckInterval: TimeInterval = 10
    private var isChecking = false

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

    func beginPermissionChecks(for mechanism: InputMechanism) {
        guard mechanism == .legacyGlobalMonitoring else {
            isChecking = false
            return
        }
        isChecking = true
        checkNextPermission()
    }

    func stopPermissionChecks() {
        isChecking = false
    }

    private func checkNextPermission() {
        guard isChecking else { return }

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
