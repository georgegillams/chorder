//
//  AppDelegate.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Cocoa
import Foundation
import AppKit
import SwiftUI

/*

 # App features

 ## Persistence
 - [x] When the app is first started, if a config file is set, it loads settings from this file.
 - [x] When the app is first started, if not, the default config is used.
 - [?] When the user selects a config file location that already has config, they are asked if they want to read it or overwrite it.

 ## Customisation
 - [x] A user can add and remove chords from the UI.
 - [x] A user can set the chord hold duration.

 ## System
 - [x] The app can auto-start with the system.

 ## Statistics
 - [x] The app records statistics about chords used and missed, and persists these to file periodically.
 - [x] The app can show a user their statistics.
 - [x] The app periodically reloads settings and usage data, in case they have changed on another machine
       - On wake
       - Every 30 minutes
 - [x] Debounce usage writes to file to prevent excessive cloud storage usage

 ## UI
 - [x] The current capitalisation mode is reflected in the menu-bar icon.
 - [x] Permissions issues are reflected in the menu.
 - [ ] The UI represents both single and chained chords.
 - [x] The UI prevents adding conflicting chords.
 - [ ] Onboarding flow for permissions + tutorial

 ## Features

 - [ ] Support modifiers - eg press cmd before chord for plural, press option before chord for `ing`
 - [ ] Cloud backup

 # Lifecycles

 ## Basics
 - [x] When a key is pressed, we add the key to the list of currently pressed keys.
 - [x] When a key is released, we remove it from the list of currently pressed keys.
 - [x] When a key is pressed, we trigger a delay for the chord hold timespan. If after this time, the same combination of keys is pressed, we consider this a chord.
 - [ ] When a chord is detected, it is added to the chord history. At this point, if the chord matches one of our config, the letters typed are removed and the chord output typed.
 - [ ] Support Chained chords — if the last two chords form a chained chord, remove both inputs and replace with the chained output.
 - [x] Share replacement code between AX and CGEvent paths (`TextReplacer`)

 ## Spaces
 - [x] If a chord is entered, we enter space-owed mode.
 - [x] When a key is pressed, if a space is owed, and this is the first key to be pressed, we go back and add the space before the just-typed-character. Space-owed is then off.
 - [x] If the user presses backspace, space, punctuation etc, then space-owed is set off.
 - [x] Chord space setting - default/always-space/never-space

 ## Capitalisation
 - [x] When the shift key is pressed down and then released (without any other key-presses in between), we toggle capitalisation mode.
 - [x] If the shift key is pressed and released, we enter first-capitalisation mode, where the first character will be capitalised on chord entry.
 - [x] If the shift key is pressed and released again, we enter full-capitalisation mode, where the whole chord will be capitalised on chord entry.
 - [x] If the shift key is pressed and released a third time, capitalisation mode is turned off.
 - [x] After a chord is entered, capitalisation mode is turned off.
 - [x] When backspace, esc, etc are pressed, capitalisation mode is turned off.
 */

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let appModel = AppModel()
    let permissionCoordinator = PermissionCoordinator()
    lazy var keyboardEngine = KeyboardInputEngine(appSettings: appModel.appSettings)

    var windowsOpen = 0
    var statusBarItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var settingsUI: SettingsView?

    private let syncedStorageReloadInterval: TimeInterval = 30 * 60
    private var syncedStorageReloadTimer: Timer?
    private var workspaceWakeObserver: NSObjectProtocol?
    private var globalEventMonitors: [Any] = []
    private var didShowGlobalMonitorFailureAlert = false

    // MARK: - Permission Checking Methods

    public func hasInputMonitoringPermission() -> Bool {
        permissionCoordinator.hasInputMonitoringPermission()
    }

    func requestInputMonitoringPermission() {
        permissionCoordinator.requestInputMonitoringPermission()
    }

    public func hasAccessibilityPermission() -> Bool {
        permissionCoordinator.hasAccessibilityPermission()
    }

    func requestAccessibilityPermission() {
        permissionCoordinator.requestAccessibilityPermission()
    }

    public func openInputMonitoringSettings() {
        permissionCoordinator.openInputMonitoringSettings()
    }

    public func openAccessibilitySettings() {
        permissionCoordinator.openAccessibilitySettings()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateActivationPolicy()

        keyboardEngine.delegate = self

        permissionCoordinator.beginPermissionChecks()
        createStatusBarButton()
        registerGlobalEventMonitors()

        if ProcessInfo.processInfo.arguments.contains("G_DEBUG") {
            showSettingsWindow()
        }

        startSyncedStorageReloadSchedule()
    }

    private func registerGlobalEventMonitors() {
        let monitors: [Any?] = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.keyboardEngine.handleFlagsChanged(event)
            },
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.keyboardEngine.handleKeyDown(event)
            },
            NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
                self?.keyboardEngine.handleKeyUp(event)
            },
        ]
        globalEventMonitors = monitors.compactMap { $0 }

        if globalEventMonitors.count < monitors.count {
            showGlobalMonitorRegistrationFailureAlert()
        }
    }

    private func showGlobalMonitorRegistrationFailureAlert() {
        guard !didShowGlobalMonitorFailureAlert else {
            return
        }
        didShowGlobalMonitorFailureAlert = true

        let alert = NSAlert()
        alert.messageText = "Keyboard monitoring unavailable"
        alert.informativeText = """
            \(getTargetName()) could not register global keyboard monitors. \
            Chord detection will not work until Input Monitoring permission is granted in System Settings.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Input Monitoring Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            openInputMonitoringSettings()
        }
    }

    private func startSyncedStorageReloadSchedule() {
        syncedStorageReloadTimer = Timer.scheduledTimer(
            withTimeInterval: syncedStorageReloadInterval,
            repeats: true
        ) { [weak self] _ in
            self?.reloadSyncedSettingsAndUsage()
        }

        workspaceWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSyncedSettingsAndUsage()
        }
    }

    private func stopSyncedStorageReloadSchedule() {
        syncedStorageReloadTimer?.invalidate()
        syncedStorageReloadTimer = nil
        if let workspaceWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceWakeObserver)
            self.workspaceWakeObserver = nil
        }
    }

    private func reloadSyncedSettingsAndUsage() {
        appModel.appSettings.reloadFromSyncedStorage()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        stopSyncedStorageReloadSchedule()
        appModel.appSettings.flushPendingStatsIfNeeded()
        appModel.appSettings.closeSettingsFileAccess()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func getTargetName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
    }
}

extension AppDelegate: SettingsActions {}

extension AppDelegate: KeyboardInputEngineDelegate {
    func keyboardInputEngine(_ engine: KeyboardInputEngine, capitalisationModeDidChange mode: CapitalisationMode) {
        updateMenuBarIcon()
    }
}
