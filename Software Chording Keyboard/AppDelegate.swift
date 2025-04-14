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
 - [ ] When the user selects a config file location that already has config, they are asked if they want to read it or overwrite it.

 ## Customisation
 - [x] A user can add and remove chords from the UI.
 - [x] A user can set the chord hold duration.

 ## System
 - [x] The app can auto-start with the system.

 ## Statistics
 - [ ] The app records statistics about chords used and missed, and persists these to file periodically.
 - [ ] The app can show a user their statistics.

 ## UI
 - [ ] The current capitalisation mode is reflected in the menu-bar icon.
 - [ ] Permissions issues are reflected in the menu.
 - [ ] The UI represents both single and chained chords.
 - [ ] The UI prevents adding conflicting chords.
 - [ ] Onboarding flow for permissions + tutorial

 ## Features

 - [ ] Support modifiers - eg press cmd before chord for plural, press option before chord for `ing`



 # Lifecycles

 ## Basics
 - [x] When a key is pressed, we add the key to the list of currently pressed keys.
 - [x] When a key is released, we remove it from the list of currently pressed keys.
 - [x] When a key is pressed, we trigger a delay for the chord hold timespan. If after this time, the same combination of keys is pressed, we consider this a chord.
 - [ ] When a chord is detected, it is added to the chord history. At this point, if the chord matches one of our config, the letters typed are removed and the chord output typed.
 - [ ] If the last 2 chords form a chained chord, the previous input and new input are removed and all replaced with the chained chord.

 ## Spaces
 - [x] If a chord is entered, we enter space-owed mode.
 - [x] When a key is pressed, if a space is owed, and this is the first key to be pressed, we go back and add the space before the just-typed-character. Space-owed is then off.
 - [x] If the user presses backspace, space, punctuation etc, then space-owed is set off.

 ## Capitalisation
 - [x] When the shift key is pressed down and then released (without any other key-presses in between), we toggle capitalisation mode.
 - [x] If the shift key is pressed and released, we enter first-capitalisation mode, where the first character will be capitalised on chord entry.
 - [x] If the shift key is pressed and released again, we enter full-capitalisation mode, where the whole chord will be capitalised on chord entry.
 - [x] If the shift key is pressed and released a third time, capitalisation mode is turned off.
 - [x] After a chord is entered, capitalisation mode is turned off.
 - [x] When backspace, esc, etc are pressed, capitalisation mode is turned off.
 */

extension String {
    func capitalizeFirstLetter() -> String {
        return prefix(1).uppercased() + self.lowercased().dropFirst()
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate,NSWindowDelegate {
    /* Application */
    let appModel = AppModel()

    /* UI */
    var windowsOpen = 0
    var statusBarItem: NSStatusItem!
    var settingsWindow: NSWindow? = nil
    var settingsUI: SettingsView? = nil
    var aboutUI: AboutView? = nil

    /* Typing */

    // TODO: Can we replace ignoreKeyPresses with mode = "Working". If Working, ignore.
    var ignorekeyPresses = 0
    var inputCharacters = NSMutableArray()
    var charactersTypedSinceSpaceOwed = 0
    var owedSpace = false
    var aboutToRemoveSpace = false
    var shiftPressedDown = false {
        didSet {
            updateMenuBarIcon()
        }
    }
    var capitalisationMode = CapitalisationMode.off {
        didSet {
            updateMenuBarIcon()
        }
    }
    var calculatedCapitalisationMode: CapitalisationMode {
        get {
            if(shiftPressedDown){
                return .fullCapitalisation
            }
            return capitalisationMode
        }
    }
    var otherKeysPressedDuringShift = false

    func flagsChangedHandler (event: NSEvent) {
        // This is fired whenever shift is toggled, but we have to track its state ourselves
        if(event.modifierFlags.contains(.shift)){
            // Shift has been pressed
            shiftPressedDown = true
        } else if(shiftPressedDown) {
            // Shift has been released
            shiftPressedDown = false

            // Remove all characters. There's a strange issue where, sometimes, after shift is released, the characters typed with shift pressed (eg @) remain in the input characters array.
            // This solves it by clearning input letters when shift is released.
            inputCharacters.removeAllObjects()


            // If characters were entered while holding shift, then we'll assume the intent of holding shift was to capitalise those letters, and not to turn on capitilisation mode
            if(otherKeysPressedDuringShift){
                otherKeysPressedDuringShift = false
                capitalisationMode = .off
                return
            }

            // When shift is released again, but only if no other keys have been pressed in the meantime.
            switch capitalisationMode {
            case .off:
                capitalisationMode = .singleCharacter
                break
            case .singleCharacter:
                capitalisationMode = .fullCapitalisation
                break
            case .fullCapitalisation:
                capitalisationMode = .off
                break
            }
        }
        gDebugPrint("shift pressed \(shiftPressedDown)")
    }

    func keyDownHandler (event: NSEvent) {
        // if the key presses are being sent by this app, we'll ignore them
        if(ignorekeyPresses > 0) {
            ignorekeyPresses -= 1
            gDebugPrint("ignorekeyPresses \(ignorekeyPresses)")
            return
        }

        let eventKey = event.keyCode
        let character = event.characters
        gDebugPrint("eventKey \(eventKey) character \(character)")

        // Ignore if any modifier keys are held
        if(event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)
           || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.function)) {
            return
        }


        if(shiftPressedDown) {
            gDebugPrint("Other keys pressed during shift")
            otherKeysPressedDuringShift = true
        }

        //  Ignore space and backspace and clear inputCharacters
        if (eventKey == KeyboardConstants.spaceEventKey || eventKey == KeyboardConstants.tabEventKey || eventKey == KeyboardConstants.backspaceEventKey || eventKey == KeyboardConstants.returnEventKey || eventKey == KeyboardConstants.escapeEventKey) {
            capitalisationMode = .off
            inputCharacters.removeAllObjects()
            owedSpace = false
            return
        }

        if (eventKey == KeyboardConstants.leftEventKey || eventKey == KeyboardConstants.rightEventKey) {
            capitalisationMode = .off
            inputCharacters.removeAllObjects()
            owedSpace = false
            return
        }

        if(KeyboardConstants.skipPreceedingSpaceCharacters.contains(character ?? "")){
            if(owedSpace){
                gDebugPrint("DROPPING OWED SPACE DUE TO PUNCTUATION!")
            }
            owedSpace = false;
        }


        gDebugPrint("owedSpace \(owedSpace)")
        gDebugPrint("char \(character)")
        let inputEmpty = inputCharacters.count == 0

        if(owedSpace){
            owedSpace = false

            gDebugPrint("ADDING SPACE")
            self.ignorekeyPresses += 2
            // Note: We don't need to set any ignored key-presses, as backpace and space are already ignored
            self.pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
            self.typeText(text: " \(character ?? "")" )
        }

        self.charactersTypedSinceSpaceOwed += 1

        inputCharacters.add(character)
        gDebugPrint("inputCharacters \(inputCharacters)")

        if (inputCharacters.count < 2){
            return
        }

        let inputKeysString = inputCharacters.componentsJoined(by: "").lowercased()

        gDebugPrint("inputKeysString \(inputKeysString)")

        DispatchQueue.main.asyncAfter(deadline: .now() + (appModel.appSettings.millisecondsToHold/1000)) {
            let inputKeysStringAfterDelay = self.inputCharacters.componentsJoined(by: "").lowercased()
            gDebugPrint("inputKeysStringAfterDelay \(inputKeysStringAfterDelay)")

            // Suppose we have 2 chords that use the same input. eg hi->hi and hid->hid
            // If a user pressed hid together, we shouldn't print "hi" as, even if the inputKeysString was "hi", by the time the hold duration has passed, the inputKeys will have changed.
            if(inputKeysString == inputKeysStringAfterDelay) {
                let chord = self.appModel.appSettings.alphabeticalInputOutputMappingDictionary[String(inputKeysString.sorted())]

                if(chord != nil) {
                    gDebugPrint("** Matched chord: \(chord?.input)")
                    // self.inputCharacters.removeAllObjects()

                    self.replaceCharacters(chord: chord!)
                    self.capitalisationMode = .off
                    self.owedSpace = !chord!.hasPipe
                    self.charactersTypedSinceSpaceOwed = 0
                }
            }
        }
    }

    func keyUpHandler (event: NSEvent) {
        let eventKey = event.keyCode
        let character = event.characters

        self.inputCharacters.remove(character)
        gDebugPrint("inputCharacters \(self.inputCharacters)")
    }


    func replaceCharacters(chord: Chord) {
        //        let selectedText = getSelectedText()
        //        gDebugPrint("* selectedText \(selectedText)")

        // TODO: Why we type the bonus character:
        // TODO: This doesn't work in inputs with autosuggest (eg browser URL bars). When the user starts typing, the input shows additonal characters that are hightlighted. The first backspace removes the highlighted suggestion text instead of the latest typed character.
        // If we didn't have a sandboxed app, we could check for highlighted text. If we want our app to be sandboxed we need an alternative solution.
        // We could hack this using `cut`. ie save current clipboard, cut selected text, restore old clipboard value, then proceed.

        // We only need to ignore 1 keypress per output chunk, as we're sending all the text from each chunk in one event
        // We add 2 extras as we type and remove a bonus character
        ignorekeyPresses += chord.input.count + chord.outputChunks.count + chord.pipeNegativePosition + 2

        typeText(text: "*")

        // clear characters originally typed. +1 so that we include the bonus character above
        for _ in 0..<chord.deleteCount + 1 {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }

        // enter replacement characters
        for i in 0..<chord.outputChunks.count {
            var outputString = chord.outputChunks[i]
            switch calculatedCapitalisationMode {
            case .singleCharacter:
                if(i == 0){
                    outputString = outputString.capitalizeFirstLetter()
                }
                break
            case .fullCapitalisation:
                outputString = outputString.uppercased()
                break
            default:
                break
            }

            typeText(text: outputString)
        }
        gDebugPrint("typed \(chord.outputChunks)")

        // Press left to get cursor to correct position
        for _ in 0..<chord.pipeNegativePosition {
            pressKey(keyCode: KeyboardConstants.leftKeyCode)
        }
    }

    func pressKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        eventDown?.post(tap: .cghidEventTap)
    }

    func typeText(text: String) {
        let utf16Chars = Array(text.utf16)

        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true);
        event1?.flags = .maskNonCoalesced
        event1?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        event1?.post(tap: .cghidEventTap)

        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false);
        event2?.flags = .maskNonCoalesced
        event2?.post(tap: .cghidEventTap)
    }

    func checkInputAccess() {
        if #available(macOS 10.15, *) {
            // request "Input Monitoring"
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            // request "Accessibility"
            IOHIDRequestAccess(kIOHIDRequestTypePostEvent)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
            let accessEnabled = AXIsProcessTrustedWithOptions(options)

            if !accessEnabled {
                gDebugPrint("No access")
                self.checkInputAccess()
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateActivationPolicy()

        checkInputAccess()
        createStatusBarButton()

        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flagsChangedHandler)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyDownHandler)
        NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: keyUpHandler)
    }

    func createStatusBarButton () {
        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = statusBarItem.button {
            // Set menubar icon
            updateMenuBarIcon()
            // Re-arrange status bar icon position
            button.imagePosition = NSControl.ImagePosition.imageOnly
            // Set font
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: NSFont.Weight.light)
            // Register click action
            // See Functions file
            button.action = #selector(statusBarButtonPress(_:))
            // Dispatch click states
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func getSelectedText() -> String? {
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        //            let selectedText = self.getSelectedText()
        //            gDebugPrint("** selectedText \(selectedText)")
        //        }
        let systemWideElement = AXUIElementCreateSystemWide()
        gDebugPrint("* systemWideElement \(systemWideElement)")

        var selectedTextValue: AnyObject?
        let errorCode = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &selectedTextValue)
        gDebugPrint("* errorCode \(errorCode)")

        if errorCode == .success {
            let selectedTextElement = selectedTextValue as! AXUIElement
            var selectedText: AnyObject?
            gDebugPrint("* selectedText \(selectedText)")
            let textErrorCode = AXUIElementCopyAttributeValue(selectedTextElement, kAXSelectedTextAttribute as CFString, &selectedText)

            if textErrorCode == .success, let selectedTextString = selectedText as? String {
                return selectedTextString
            } else {
                return nil
                gDebugPrint("* selectedText nil")
            }
        } else {
            return nil
            gDebugPrint("* selectedText nil")
        }

    }

    func updateMenuBarIcon() {
        let accessibilityDescription = "\(getTargetName()) Preferences"

        switch calculatedCapitalisationMode {
        case .off:
            statusBarItem.button?.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: accessibilityDescription)
        case .singleCharacter:
            statusBarItem.button?.image = NSImage(systemSymbolName: "shift", accessibilityDescription: accessibilityDescription)
        case .fullCapitalisation:
            statusBarItem.button?.image = NSImage(systemSymbolName: "shift.fill", accessibilityDescription: accessibilityDescription)
        }
    }

    @objc func statusBarButtonPress(_ sender: AnyObject?) {
        openMenu()
    }

    @objc func showSettingsWindow () {
        windowsOpen += 1
        updateActivationPolicy()

        settingsUI = SettingsView(appModel: appModel)
        if(settingsWindow == nil) {
            settingsWindow = NSWindow(contentRect: NSMakeRect(0, 0, 300, 500), styleMask: [.closable, .titled, .resizable], backing: .buffered, defer: false)
        }

        if let window = settingsWindow {
            window.isReleasedWhenClosed = false
            window.contentView?.wantsLayer = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .visible
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.contentViewController = NSHostingController(rootView: settingsUI)
            window.delegate = self
            window.center()
        }
    }

    @objc func openMenu() {
        let versionNsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
        let version = versionNsObject as! String
        let menu = NSMenu()
        //        menu.addItem(withTitle: "About \(getTargetName())", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Preferences", action: #selector(showSettingsWindow), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Send me feedback", action: #selector(openFeedback), keyEquivalent: "")
        menu.addItem(withTitle: "Buy me a coffee", action: #selector(openCoffee), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "\(getTargetName()) \(version)", action: nil, keyEquivalent: ""))
        menu.addItem(withTitle: "Quit \(getTargetName())", action: #selector(quit), keyEquivalent: "q")

        statusBarItem.menu = menu
        statusBarItem.button?.performClick(nil)
        statusBarItem.menu = nil
    }

    @objc func openFeedback() {
        if let url = URL(string: "https://www.georgegillams.co.uk/contact") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openCoffee() {
        if let url = URL(string: "https://www.georgegillams.co.uk/coffee") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quit() {
        NSApp.terminate(self)
    }

    func windowWillClose(_ notification: Notification) {
        windowsOpen -= 1
        updateActivationPolicy()
        if(notification.object as? NSWindow == settingsWindow) {
            settingsWindow = nil
            settingsUI = nil
        }
    }

    func updateActivationPolicy() {
        if (windowsOpen > 0) {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.prohibited)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        appModel.appSettings.closeSettingsFileAccess()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func getTargetName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
    }
}
