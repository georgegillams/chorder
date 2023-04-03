//
//  AppDelegate.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 03/04/2023.
//

import Foundation
import AppKit
import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let appSettings = AppSettings()
    
    var alphabeticalInputOutputMappingDictionary: [String: Chord] = [:]
    
    var ignorekeyPresses = 0
    var inputCharacters = NSMutableArray()
    var lastKeydown: Int64 = 0
    var needsSpaceNext = false
    let millisecondsTollerance = 75
    
    let backspaceKeyCode = CGKeyCode(51)
    let leftKey = CGKeyCode(123)
    
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
            needsSpaceNext = false
            return
        }
        
        inputCharacters.add(character)
        lastKeydown = Int64(Date.now.timeIntervalSince1970 * 1000)
        
        var inputKeysString = inputCharacters.componentsJoined(by: "")
        
        print("inputKeysString \(inputKeysString)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (appSettings.millisecondsToHold/1000)) {
            var inputKeysStringAfterDelay = self.inputCharacters.componentsJoined(by: "")
            print("inputKeysStringAfterDelay \(inputKeysStringAfterDelay)")
            
            if(inputKeysString == inputKeysStringAfterDelay) {
                
                let chord = self.alphabeticalInputOutputMappingDictionary[String(inputKeysString.sorted())]
                if(chord == nil) {
                    return
                }
                self.inputCharacters.removeAllObjects()
                
                let outputKeysString = chord!.output
                
                self.replaceCharacters(chord: chord!, includeSpace: self.needsSpaceNext)
                self.needsSpaceNext = chord!.pipeNegativePosition == 0
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
            pressKey(keyCode: leftKey)
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
    
    func reloadAppSettings () {
        createAlphabeticalMapping()
    }
    
    func createAlphabeticalMapping() {
        alphabeticalInputOutputMappingDictionary = [:]
        for (key, value) in appSettings.inputOutputMappingDictionary {
            let sortedKey = String(key.sorted())
            alphabeticalInputOutputMappingDictionary[sortedKey] = Chord(input: key, output: value)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkInputAccess()
        reloadAppSettings()
        
        let contentUI = ContentView()
        let appWindow = NSWindow(contentRect: NSMakeRect(200, 200, 800, 500), styleMask: [.closable, .titled, .resizable], backing: .buffered, defer: false)
        
//        if let window = appWindow {
            appWindow.contentView?.wantsLayer = true
            appWindow.titlebarAppearsTransparent = true
            appWindow.titleVisibility = .visible
            appWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
            appWindow.standardWindowButton(.zoomButton)?.isHidden = true
            appWindow.makeKeyAndOrderFront(appWindow)
            appWindow.level = .floating
            appWindow.contentViewController = NSHostingController(rootView: contentUI)
//        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyDownHandler)
        NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: keyUpHandler)
    }
}
