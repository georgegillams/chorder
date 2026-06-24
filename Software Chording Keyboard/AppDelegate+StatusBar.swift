//
//  AppDelegate+StatusBar.swift
//  Software Chording Keyboard
//

import AppKit
import SwiftUI

extension AppDelegate {
    private static let settingsWindowDefaultSize = NSSize(width: 1200, height: 720)
    private static let settingsWindowMinimumSize = NSSize(width: 920, height: 450)

    func createStatusBarButton() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = statusBarItem.button {
            updateMenuBarIcon()
            button.imagePosition = NSControl.ImagePosition.imageOnly
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: NSFont.Weight.light)
            button.action = #selector(statusBarButtonPress(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func updateMenuBarIcon() {
        let accessibilityDescription = "\(getTargetName()) Preferences"

        switch keyboardEngine.calculatedCapitalisationMode {
        case .off:
            statusBarItem.button?.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: accessibilityDescription)
        case .singleCharacter:
            statusBarItem.button?.image = NSImage(systemSymbolName: "shift", accessibilityDescription: accessibilityDescription)
        case .fullCapitalisation:
            statusBarItem.button?.image = NSImage(systemSymbolName: "shift.fill", accessibilityDescription: accessibilityDescription)
        }
    }

    @objc func statusBarButtonPress(_ sender: AnyObject?) {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            showSettingsWindowWithNewChord()
            return
        }
        openMenu()
    }

    @objc func showSettingsWindow() {
        presentSettingsWindow(openCreateChord: false)
    }

    @objc func showSettingsWindowWithNewChord() {
        presentSettingsWindow(openCreateChord: true)
    }

    func presentSettingsWindow(openCreateChord: Bool) {
        windowsOpen += 1
        updateActivationPolicy()

        settingsUI = SettingsView(
            appModel: appModel,
            settingsActions: self,
            openCreateChordOnAppear: openCreateChord
        )

        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.settingsWindowDefaultSize),
                styleMask: [.closable, .titled, .resizable],
                backing: .buffered,
                defer: false
            )
        }

        guard let window = settingsWindow else {
            return
        }

        window.isReleasedWhenClosed = false
        window.contentView?.wantsLayer = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentMinSize = Self.settingsWindowMinimumSize
        window.delegate = self

        let hostingController = NSHostingController(rootView: settingsUI!)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.minSize]
        }
        window.contentViewController = hostingController
        window.setContentSize(Self.settingsWindowDefaultSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openMenu() {
        let buildLabel = Bundle.main.menuBuildLabel
        let productName = Bundle.main.menuProductName
        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences", action: #selector(showSettingsWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Add Chord…", action: #selector(showSettingsWindowWithNewChord), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Send me feedback", action: #selector(openFeedback), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "\(productName) \(buildLabel)", action: nil, keyEquivalent: ""))
        menu.addItem(withTitle: "Quit \(productName)", action: #selector(quit), keyEquivalent: "q")

        statusBarItem.menu = menu
        statusBarItem.button?.performClick(nil)
        statusBarItem.menu = nil
    }

    @objc func openFeedback() {
        NSWorkspace.shared.open(Bundle.main.feedbackURL)
    }

    @objc func quit() {
        NSApp.terminate(self)
    }

    func windowWillClose(_ notification: Notification) {
        windowsOpen -= 1
        updateActivationPolicy()
        if notification.object as? NSWindow == settingsWindow {
            settingsWindow = nil
            settingsUI = nil
        }
    }

    func updateActivationPolicy() {
        if windowsOpen > 0 {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.prohibited)
        }
    }
}
