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
 Lifecycles:
 - When a key is pressed, we add the key to the list of currently pressed keys.
 - When a key is released, we remove it from the list of currently pressed keys.
 
 - If our pressed keys buffer matches one of the chords, then we'll wait the chord hold timespan.
 - After this time has passed no keys have been added or removed, then we proceed to replace the entered characters with the replacement text.
 - At this stage, a space is added then removed (this way if the user has just started a new sentence with a chord, then the system will capitailise it).
 
 - When a key is  pressed, we check to see if a space is owed. If a space is owed, and this is the first key to be pressed, we go back and add the space before the just-typed-character.
 */

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
    
    func keyDownHandler (event: NSEvent) {
        print("ignorekeyPresses \(ignorekeyPresses)")
        // if the key presses are being sent by this app, we'll ignore them
        if(ignorekeyPresses > 0) {
            ignorekeyPresses -= 1
            return
        }
        
        // Ignore if any modifier keys are held
        if(event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)
           || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.function)) {
            return
        }
        
        
        let eventKey = event.keyCode
        let character = event.characters
        //        print("eventKey \(eventKey) character \(character)")
        
        //  Ignore space and backspace and clea
        inputCharacters
        if (eventKey == KeyboardConstants.spaceEventKey || eventKey == KeyboardConstants.backspaceEventKey) {
            //            inputCharacters.removeAllObjects()
            owedSpace = false
            return
        }
        
        if (eventKey == KeyboardConstants.leftEventKey || eventKey == KeyboardConstants.rightEventKey || eventKey == KeyboardConstants.spaceEventKey) {
            owedSpace = false
            return
        }
        
        print("owedSpace \(owedSpace)")
        print("char \(character)")
        let inputEmpty = inputCharacters.count == 0
        
        // TODO: Could it help to check if `inputEmpty` here?
        if( owedSpace){
            if(self.aboutToRemoveSpace){
                print("SUPPRESSING SPACE REMOVAL")
                self.owedSpace = false
                self.aboutToRemoveSpace = false
            }else{
                print("ADDING SPACE")
                
                owedSpace = false
                //            Note: We don't need to set any ignored key-presses, as left, right and space are already ignored
                self.pressKey(keyCode: KeyboardConstants.leftKeyCode)
                //            }
                self.typeText(text: " " )
                //            for _ in 0..<self.charactersTypedSinceSpaceOwed {
                self.pressKey(keyCode: KeyboardConstants.rightKeyCode)
            }
        }
        
        self.charactersTypedSinceSpaceOwed += 1
        
        inputCharacters.add(character)
        print ("inputCharacters \(inputCharacters)")
        
        if (inputCharacters.count < 2){
            return
        }
        
        let inputKeysString = inputCharacters.componentsJoined(by: "")
        
        print("inputKeysString \(inputKeysString)")
        
        let chord = self.appModel.appSettings.alphabeticalInputOutputMappingDictionary[String(inputKeysString.sorted())]
        
        if(chord != nil) {
            DispatchQueue.main.asyncAfter(deadline: .now() + (appModel.appSettings.millisecondsToHold/1000)) {
                let inputKeysStringAfterDelay = self.inputCharacters.componentsJoined(by: "")
                //                print("inputKeysStringAfterDelay \(inputKeysStringAfterDelay)")
                
                if(inputKeysString == inputKeysStringAfterDelay) {
//                    self.inputCharacters.removeAllObjects()
                    
                    self.replaceCharacters(chord: chord!)
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
        //        TODO: Added 1 at end for backspace
        ignorekeyPresses += chord.input.count + chord.outputChunks.count + chord.pipeNegativePosition
        
        // clear characters originally typed
        for _ in 0..<chord.deleteCount {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }
        
        // enter replacement characters
        for i in 0..<chord.outputChunks.count {
            var outputString = chord.outputChunks[i]
//            if (i == 0 && includeSpace) {
//                outputString = " " + outputString
//            }
            if (i == chord.outputChunks.count - 1 && !chord.hasPipe) {
                outputString = outputString + " "
            }
            typeText(text: outputString)
        }
        print("typed \(chord.outputChunks)")
        if(!chord.hasPipe){
            
        self.aboutToRemoveSpace = true
        // TODO: Fix this
        //        pressKey(keyCode: KeyboardConstants.spaceKeyCode)
        DispatchQueue.main.asyncAfter(deadline: .now() +  500/1000) {
            if(self.aboutToRemoveSpace){
                self.aboutToRemoveSpace = false
                self.ignorekeyPresses += 1
                print("Press backspaces")
                self.pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
            }
        }
        }
        
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
