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
 - [ ] The UI represents single and chained chords.
 - [ ] The UI prevents adding conflicting chords.
 
 

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
 - [ ] If the user presses backspace, space, punctuation etc, then space-owed is set off.
 
 ## Capitalisation
 - [x] When the shift key is pressed down and then released (without any other key-presses in between, we toggle capitalisation mode.
 - [x] If the shift key is pressed and released, we enter first-capitalisation mode, where the first character will be capitalised on chord entry.
 - [x] If the shift key is pressed and released again, we enter full-capitalisation mode, where the whole chord will be capitalised on chord entry.
 - [x] If the shift key is pressed and released a third time, capitalisation mode is turned off.
 - [x] After a chord is entered, capitalisation mode is turned off.
 - [x] When backspace, esc, etc are pressed capitalisation mode is turned off.
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
    var ignorekeyPresses = 0
    var inputCharacters = NSMutableArray()
    var charactersTypedSinceSpaceOwed = 0
    var owedSpace = false
    var aboutToRemoveSpace = false
    var shiftPressedDown = false
    var capitalisationMode = CapitalisationMode.off
    
    func flagsChangedHandler (event: NSEvent) {
        if(event.modifierFlags.contains(.shift)){
            shiftPressedDown = true
        } else if(shiftPressedDown) {
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
    }
    
    func keyDownHandler (event: NSEvent) {
        // if the key presses are being sent by this app, we'll ignore them
        if(ignorekeyPresses > 0) {
            ignorekeyPresses -= 1
            print("ignorekeyPresses \(ignorekeyPresses)")
            return
        }
        
        let eventKey = event.keyCode
        let character = event.characters
        print("eventKey \(eventKey) character \(character)")
        
        shiftPressedDown = false
        
        
        
        
        // Ignore if any modifier keys are held
        if(event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)
           || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.function)) {
            return
        }
        
        
        //  Ignore space and backspace and clear inputCharacters
        if (eventKey == KeyboardConstants.spaceEventKey || eventKey == KeyboardConstants.backspaceEventKey || eventKey == KeyboardConstants.returnEventKey || eventKey == KeyboardConstants.fullStopEventKey) {
            capitalisationMode = .off
            inputCharacters.removeAllObjects()
            owedSpace = false
            return
        }
        
        if (eventKey == KeyboardConstants.leftEventKey || eventKey == KeyboardConstants.rightEventKey) {
            owedSpace = false
            return
        }
        
        print("owedSpace \(owedSpace)")
        print("char \(character)")
        let inputEmpty = inputCharacters.count == 0
        
        // TODO: Could it help to check if `inputEmpty` here?
        if( owedSpace){
            print("ADDING SPACE")
            self.ignorekeyPresses += 3
            owedSpace = false
            //            Note: We don't need to set any ignored key-presses, as left, right and space are already ignored
            self.pressKey(keyCode: KeyboardConstants.leftKeyCode)
            //            }
            self.typeText(text: " " )
            //            for _ in 0..<self.charactersTypedSinceSpaceOwed {
            self.pressKey(keyCode: KeyboardConstants.rightKeyCode)
        }
        
        self.charactersTypedSinceSpaceOwed += 1
        
        inputCharacters.add(character)
        print ("inputCharacters \(inputCharacters)")
        
        if (inputCharacters.count < 2){
            return
        }
        
        let inputKeysString = inputCharacters.componentsJoined(by: "")
        
        print("inputKeysString \(inputKeysString)")
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (appModel.appSettings.millisecondsToHold/1000)) {
            let inputKeysStringAfterDelay = self.inputCharacters.componentsJoined(by: "")
            //                print("inputKeysStringAfterDelay \(inputKeysStringAfterDelay)")
            
            if(inputKeysString == inputKeysStringAfterDelay) {
                let chord = self.appModel.appSettings.alphabeticalInputOutputMappingDictionary[String(inputKeysString.sorted())]
                
                if(chord != nil) {
                    //                    self.inputCharacters.removeAllObjects()
                    
                    self.replaceCharacters(chord: chord!)
                    self.capitalisationMode = .off
                    self.owedSpace = !chord!.hasPipe
                    self.charactersTypedSinceSpaceOwed = 0
                }
            }
        }
    }
    
    func keyUpHandler (event: NSEvent) {
        let character = event.characters
        inputCharacters.remove(character)
        
        //        let inputKeysString = inputCharacters.componentsJoined(by: "")
        //        let inputEmpty = inputKeysString.count == 0
        //        if(inputEmpty && owedSpace && charactersTypedSinceSpaceOwed > 0) {
        //            self.owedSpace = false
        //            self.ignorekeyPresses = self.charactersTypedSinceSpaceOwed * 2 + 1
        //            for _ in 0..<self.charactersTypedSinceSpaceOwed {
        //                self.pressKey(keyCode: KeyboardConstants.leftKeyCode)
        //            }
        //            self.typeText(text: " " )
        //            for _ in 0..<self.charactersTypedSinceSpaceOwed {
        //                self.pressKey(keyCode: KeyboardConstants.rightKeyCode)
        //            }
        //        }
    }
    
    
    func replaceCharacters(chord: Chord) {
        // We only need to ignore 1 keypress per output chunk, as we're sending all the text from each chunk in one event
        ignorekeyPresses += chord.input.count + chord.outputChunks.count + chord.pipeNegativePosition
        
        // clear characters originally typed
        for _ in 0..<chord.deleteCount {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }
        
        // enter replacement characters
        for i in 0..<chord.outputChunks.count {
            var outputString = chord.outputChunks[i]
            switch capitalisationMode {
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
            //            if (i == 0 && includeSpace) {
            //                outputString = " " + outputString
            //            }
            //            if (i == chord.outputChunks.count - 1 && !chord.hasPipe) {
            //                outputString = outputString + " "
            //            }
            typeText(text: outputString)
        }
        print("typed \(chord.outputChunks)")
        //        if(!chord.hasPipe){
        //
        //            // TODO: Fix this
        //            //        pressKey(keyCode: KeyboardConstants.spaceKeyCode)
        //            DispatchQueue.main.asyncAfter(deadline: .now() +  500/1000) {
        //                if(self.aboutToRemoveSpace){
        //                    self.aboutToRemoveSpace = false
        //                    self.ignorekeyPresses += 1
        //                    print("Press backspaces")
        //                    self.pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        //                }
        //            }
        //        }
        
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
        
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Access Not Enabled")
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
            button.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "Software Chording Keyboard Preferences")
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
        //        menu.addItem(withTitle: "About Software Chording Keyboard", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Preferences", action: #selector(showSettingsWindow), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Send me feedback", action: #selector(openFeedback), keyEquivalent: "")
        menu.addItem(withTitle: "Buy me a coffee", action: #selector(openCoffee), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Software Chording Keyboard \(version)", action: nil, keyEquivalent: ""))
        menu.addItem(withTitle: "Quit Software Chording Keyboard", action: #selector(quit), keyEquivalent: "q")
        
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
}
