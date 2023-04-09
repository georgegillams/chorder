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


        enum InputType {
        case chord
            case character
            case space
            case unknown
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
    var lastKeydown: Int64 = 0
    var lastInputType: InputType = .unknown
    
    /* Constants */
    let backspaceKeyCode = CGKeyCode(51)
    let leftKeyCode = CGKeyCode(123)
    let rightKeyCode = CGKeyCode(124)
    
    func keyDownHandler (event: NSEvent) {
        // if the key presses are being sent by this app, we'll ignore them
        if(ignorekeyPresses > 0) {
            ignorekeyPresses -= 1
            return
        }
        
        let eventKey = event.keyCode
        let character = event.characters
        print("eventKey \(eventKey) character \(character)")
        
        //  Ignore space and backspace and clear inputCharacters
        if (eventKey == 49 || eventKey == 51) {
            inputCharacters.removeAllObjects()
            lastInputType = .unknown
            return
        }
        
        inputCharacters.add(character)
        lastKeydown = Int64(Date.now.timeIntervalSince1970 * 1000)
        
        
        var inputKeysString = inputCharacters.componentsJoined(by: "")

//          if(                                                                                  ) {
 //            needsSpaceNext =  false
//            ignorekeyPresses = 3
//            pressKey(keyCode: leftKeyCode)
//            typeText(text: " " )
//            pressKey(keyCode: rightKeyCode)
//          }
 
            
        print("inputKeysString \(inputKeysString)")
        
        print("appModel.appSettings.millisecondsToHold \(appModel.millisecondsToHold)")
        DispatchQueue.main.asyncAfter(deadline: .now() + (appModel.millisecondsToHold/1000)) {
            var inputKeysStringAfterDelay = self.inputCharacters.componentsJoined(by: "")
            print("inputKeysStringAfterDelay \(inputKeysStringAfterDelay)")
            
            if(inputKeysStringAfterDelay.count < 2) {
                // TODO: if(self.lastInputType == .chord && inputKeysString IS NOT PUNCTUATION) {
                if(self.lastInputType == .chord) {
                    self.ignorekeyPresses = 3
                    self.pressKey(keyCode: self.leftKeyCode)
                    self.typeText(text: " " )
                    self.pressKey(keyCode: self.rightKeyCode)
                }
                self.lastInputType = .character
            }
            
            if( inputKeysString == " ") {
                self.lastInputType = .space
            }
            
            if(inputKeysString == inputKeysStringAfterDelay) {
                let chord = self.appModel.alphabeticalInputOutputMappingDictionary[String(inputKeysString.sorted())]
                if(chord == nil) {
                    return
                }
                self.inputCharacters.removeAllObjects()
                
                let outputKeysString = chord!.output
                
                self.replaceCharacters(chord: chord!, includeSpace: self.lastInputType == .chord || self.lastInputType == .character)
                self.lastInputType = .chord
            }
        }
    }
    
    func keyUpHandler (event: NSEvent) {
        let character = event.characters
        inputCharacters.remove(character)
    }
    
    func replaceCharacters(chord: Chord, includeSpace: Bool) {
        //        var outputString = chord.output
        //        if (includeSpace) {
        //            outputString = " " + outputString
        //        }
        
        //        var outputChars = Array(chord.output)
        
        //        print("outputKeysString \(outputChars)")
        //
        //        var outputStrings = outputChars.map { String($0) }
        //        print("outputStrings \(outputStrings)")
        //        var outputKeyCodes = outputStrings.map { CGKeyCode(character: $0) ?? CGKeyCode(0) }
        //        print("outputKeyCodes \(outputKeyCodes)")
        
        // We only need to ignore 1 keypress per output chunk, as we're sending all the text from each chunk in one event
        ignorekeyPresses = chord.input.count + chord.outputChunks.count + chord.pipeNegativePosition
        
        // clear characters originally typed
        for _ in 0..<chord.deleteCount {
            pressKey(keyCode: backspaceKeyCode)
        }
        
        // enter replacement characters
        for i in 0..<chord.outputChunks.count {
            var outputString = chord.outputChunks[i]
            if (i == 0 && includeSpace) {
                outputString = " " + outputString
            }
            typeText(text: outputString)
        }
        
        // Press left to get cursor to correct position
        for _ in 0..<chord.pipeNegativePosition {
            pressKey(keyCode: leftKeyCode)
        }
    }
    
    func pressKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        eventDown?.post(tap: .cghidEventTap)
    }
    
    func typeText(text: String) {
        let utf16Chars = Array(text.utf16)
        print("utf16Chars \(utf16Chars)")
        
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
        appModel.reloadAppSettings()
        createStatusBarButton()
        
        // TODO: REMOVE:
//        showSettingsWindow()
        
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
        settingsWindow = nil
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
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
