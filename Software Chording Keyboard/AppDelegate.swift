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
 - [ ] If the last 2 chords form a chained chord, the previous input and new input are removed and all replaced with the chained chord.
 - [ ] Share more code between AX and CGEvent paths
 - [ ] **Full code/system review**

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
class AppDelegate: NSObject, NSApplicationDelegate,NSWindowDelegate {
    /* Application */
    let appModel = AppModel()

    /* UI */
    var windowsOpen = 0
    var statusBarItem: NSStatusItem!
    var settingsWindow: NSWindow? = nil
    var settingsUI: SettingsView? = nil

    private let syncedStorageReloadInterval: TimeInterval = 30 * 60
    private var syncedStorageReloadTimer: Timer?
    private var workspaceWakeObserver: NSObjectProtocol?

    /* Typing */

    // TODO: Can we replace ignoreKeyPresses with mode = "Working". If Working, ignore.
    var ignorekeyPresses = 0
    var inputCharacters = NSMutableArray()
    var owedSpace = false
    var autoInsertedSpaceBeforeCurrentInput = false
    var shiftPressedDown = false
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
            autoInsertedSpaceBeforeCurrentInput = false


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
            autoInsertedSpaceBeforeCurrentInput = false
            return
        }

        // If navigating through text, clear everything
        if (eventKey == KeyboardConstants.leftEventKey || eventKey == KeyboardConstants.rightEventKey) {
            capitalisationMode = .off
            inputCharacters.removeAllObjects()
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = false
            return
        }

        if(KeyboardConstants.skipPrecedingSpaceCharacters.contains(character ?? "")){
            if(owedSpace){
                gDebugPrint("Dropping owed space due to punctuation!")
            }
            owedSpace = false;
        }


        gDebugPrint("owedSpace \(owedSpace)")
        gDebugPrint("char \(character)")

        if(owedSpace){
            owedSpace = false
            autoInsertedSpaceBeforeCurrentInput = true

            gDebugPrint("ADDING SPACE")
            self.ignorekeyPresses += 2
            // Note: We don't need to set any ignored key-presses, as backpace and space are already ignored
            self.pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
            self.typeText(text: " \(character ?? "")" )
        }

//        self.charactersTypedSinceSpaceOwed += 1

        inputCharacters.add(character)
        gDebugPrint("inputCharacters \(inputCharacters)")

        if (inputCharacters.count <= 1){
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
                    self.appModel.appSettings.incrementUsage(for: chord!)
                    self.appModel.appSettings.setUsageCountDirty()
                    self.capitalisationMode = .off
//                    self.charactersTypedSinceSpaceOwed = 0
                }
            }
        }
    }

    func keyUpHandler (event: NSEvent) {
        let character = event.characters

        self.inputCharacters.remove(character)
        gDebugPrint("inputCharacters \(self.inputCharacters)")
    }


    private func finalizeChordMatch(chord: Chord) {
        autoInsertedSpaceBeforeCurrentInput = false
        owedSpace = !chord.hasPipe
    }

    func replaceCharacters(chord: Chord) {
        let resolved = chord.resolveReplacement(
            capitalisationMode: calculatedCapitalisationMode,
            autoInsertedSpaceBeforeInput: autoInsertedSpaceBeforeCurrentInput
        )
        let outputSegments = resolved.segments
        let pipeLeftCount = resolved.leftArrowCount

        if appModel.appSettings.useAccessibilityAPI && replaceCharactersViaAX(chord: chord, resolved: resolved) {
            gDebugPrint("replaced via AX")
            finalizeChordMatch(chord: chord)
            return
        }

        gDebugPrint("AX replacement failed, falling back to CGEvent")

        // CGEvent fallback: type a bonus *, backspace over the chord input + bonus char, then type the output.
        // The bonus * works around autocomplete fields (eg browser URL bars) where the first backspace
        // would otherwise dismiss the highlighted suggestion rather than deleting the last typed char.

        // We only need to ignore 1 keypress per output chunk, as we're sending all the text from each chunk in one event.
        // We add 2 extras as we type and remove a bonus * character.
        ignorekeyPresses += chord.input.count + outputSegments.count + pipeLeftCount + resolved.backspacesBeforeOutput + 2

        typeText(text: "*")

        // Clear characters originally typed. +1 so that we include the bonus character above.
        for _ in 0..<chord.deleteCount + 1 {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }

        for _ in 0..<resolved.backspacesBeforeOutput {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }

        // Enter replacement characters.
        for outputString in outputSegments {
            typeText(text: outputString)
        }
        gDebugPrint("typed \(outputSegments)")

        // Press left to get cursor to correct position.
        for _ in 0..<pipeLeftCount {
            pressKey(keyCode: KeyboardConstants.leftKeyCode)
        }

        finalizeChordMatch(chord: chord)
    }

    // Attempts to replace the chord input with the chord output by directly manipulating the focused
    // text field via the Accessibility API. Returns true on success, false if any AX call fails
    // (in which case the caller should fall back to the CGEvent approach).
    //
    // This approach avoids posting any synthetic key events, so ignorekeyPresses is not touched.
    // It does not work in Electron apps (Slack, VS Code, Discord) or browser URL bars, where the
    // AX text tree either isn't exposed or doesn't support attribute writes.
    func replaceCharactersViaAX(chord: Chord, resolved: ResolvedChordReplacement) -> Bool {
        // Skip apps whose kAXSelectedTextAttribute write is known to be broken
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           axIncompatibleAppBundleIDs.contains(bundleID) {
            gDebugPrint("AX: skipping for AX-incompatible app \(bundleID)")
            return false
        }

        let axUiElement = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axUiElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success else {
            gDebugPrint("AX: failed to get focused element")
            return false
        }
        let focused = focusedRef as! AXUIElement

        // Read cursor range (location = insertion point, length = selection size).
        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef else {
            gDebugPrint("AX: failed to read kAXSelectedTextRangeAttribute")
            return false
        }
        var cursorRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cursorRange) else {
            gDebugPrint("AX: failed to extract CFRange from cursor range value")
            return false
        }
        gDebugPrint("AX: cursorRange location=\(cursorRange.location) length=\(cursorRange.length)")

        // Bail out early if the focused element doesn't support writing kAXSelectedTextAttribute.
        // This catches terminal emulators (eg iTerm2, Terminal.app) whose text areas expose a
        // readable AX tree but don't accept text writes — the terminal input is driven by the PTY,
        // not by AX attribute writes. Without this check the code reaches the selection-setting step,
        // which visibly selects text in the terminal, and then the write fails; the selection is left
        // active when the CGEvent fallback runs, causing it to replace the wrong text.
        var isTextWritable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &isTextWritable) == .success,
              isTextWritable.boolValue else {
            gDebugPrint("AX: kAXSelectedTextAttribute is not writable, bailing")
            return false
        }

        // Ensure there are enough characters before the cursor to cover the chord input.
        let inputCount = chord.input.count
        let leadingSpaceDeletionCount = resolved.backspacesBeforeOutput
        guard cursorRange.location >= inputCount + leadingSpaceDeletionCount else {
            gDebugPrint("AX: cursor location \(cursorRange.location) < inputCount \(inputCount) + leadingSpaceDeletionCount \(leadingSpaceDeletionCount), bailing")
            return false
        }

        // Read the full field value and verify the characters immediately before the cursor
        // (sorted, case-insensitive) match the chord input. This guards against edge cases where
        // the cursor has moved or the field contents don't match what was typed.
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueRef) == .success,
              let fieldValue = valueRef as? String else {
            gDebugPrint("AX: failed to read kAXValueAttribute")
            return false
        }
        let nsField = fieldValue as NSString
        gDebugPrint("AX: fieldValue length=\(nsField.length) value=\(nsField)")
        guard cursorRange.location <= nsField.length else {
            gDebugPrint("AX: cursorRange.location \(cursorRange.location) > fieldValue.length \(nsField.length), bailing")
            return false
        }

        var startIndex = cursorRange.location - inputCount
        if leadingSpaceDeletionCount > 0 {
            startIndex -= leadingSpaceDeletionCount
            guard startIndex >= 0 else {
                gDebugPrint("AX: leading space deletion would underflow field, bailing")
                return false
            }
            let leadingCharacter = nsField.substring(with: NSRange(location: startIndex, length: 1))
            guard leadingCharacter == " " else {
                gDebugPrint("AX: expected leading space at \(startIndex), found '\(leadingCharacter)', bailing")
                return false
            }
        }
        gDebugPrint("AX: inputCount=\(inputCount) startIndex=\(startIndex) leadingSpaceDeletionCount=\(leadingSpaceDeletionCount)")

        let inputStartIndex = startIndex + leadingSpaceDeletionCount
        let charsBeforeCursor = nsField.substring(with: NSRange(location: inputStartIndex, length: inputCount)).lowercased()
        gDebugPrint("AX: charsBeforeCursor='\(charsBeforeCursor)' chordInput='\(chord.input.lowercased())'")
        guard String(charsBeforeCursor.sorted()) == String(chord.input.lowercased().sorted()) else {
            gDebugPrint("AX: charsBeforeCursor sorted '\(String(charsBeforeCursor.sorted()))' != chord input sorted '\(String(chord.input.lowercased().sorted()))', bailing")
            return false
        }

        // Select the chord input characters and any forward selection (eg an autocomplete suggestion)
        // in a single range, so they are replaced by one write below.
        //
        // Using two separate writes — one to clear the suggestion, one to insert the output — causes
        // a timing problem: the first write fires an AX notification that the target app (eg a browser)
        // processes asynchronously. By the time the app acts on it, the second write has already
        // landed, producing garbled results. A single selection + single write avoids that race.
        var selectRange = CFRange(
            location: startIndex,
            length: inputCount + leadingSpaceDeletionCount + cursorRange.length
        )
        gDebugPrint("AX: setting selectRange location=\(selectRange.location) length=\(selectRange.length)")
        guard let selectAXVal = AXValueCreate(.cfRange, &selectRange) else { return false }
        guard AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, selectAXVal) == .success else {
            gDebugPrint("AX: failed to set selectRange")
            return false
        }

        // Verify the selection landed correctly before making any destructive write.
        // Some apps (eg Firefox URL bar) report cursor/selection ranges that don't accurately map to
        // character positions in the field value, so selectRange can end up covering characters
        // before the chord. Reading back the actual selected text lets us catch that mismatch and
        // restore the original cursor position before bailing out.
        var selectedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
              let selectedText = selectedRef as? String else {
            gDebugPrint("AX: failed to read back kAXSelectedTextAttribute after selection, restoring cursor")
            var orig = cursorRange
            if let origAXVal = AXValueCreate(.cfRange, &orig) {
                AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, origAXVal)
            }
            return false
        }
        gDebugPrint("AX: selectedText after selection='\(selectedText)'")
        let selectedPrefix = String(selectedText.dropFirst(leadingSpaceDeletionCount).prefix(inputCount)).lowercased()
        gDebugPrint("AX: selectedPrefix='\(selectedPrefix)' expected sorted='\(String(chord.input.lowercased().sorted()))'")
        guard String(selectedPrefix.sorted()) == String(chord.input.lowercased().sorted()) else {
            gDebugPrint("AX: selection verification failed, restoring cursor and bailing")
            var orig = cursorRange
            if let origAXVal = AXValueCreate(.cfRange, &orig) {
                AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, origAXVal)
            }
            return false
        }

        let outputSegments = resolved.segments
        let pipeLeftCount = resolved.leftArrowCount
        let output = outputSegments.joined()

        gDebugPrint("AX: writing output='\(output)'")
        // Replace the selection with the output.
        guard AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, output as CFTypeRef) == .success else {
            gDebugPrint("AX: write failed")
            return false
        }

        // Log the field state immediately after the write to help diagnose post-write anomalies
        // (eg browsers re-evaluating the URL, cursor jumping, autocomplete interference).
        if let postValueRef = { var r: AnyObject?; AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &r); return r }() as? String {
            gDebugPrint("AX: fieldValue after write='\(postValueRef)'")
        }
        var postRangeRef: AnyObject?
        if AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &postRangeRef) == .success,
           let postRangeValue = postRangeRef {
            var postRange = CFRange(location: 0, length: 0)
            if AXValueGetValue(postRangeValue as! AXValue, .cfRange, &postRange) {
                gDebugPrint("AX: cursorRange after write location=\(postRange.location) length=\(postRange.length)")
            }
        }

        // Reposition the cursor for the | pipe marker (pipeLeftCount chars from the end of output).
        if pipeLeftCount > 0 {
            var afterRangeRef: AnyObject?
            if AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &afterRangeRef) == .success,
               let afterRangeValue = afterRangeRef {
                var afterRange = CFRange(location: 0, length: 0)
                if AXValueGetValue(afterRangeValue as! AXValue, .cfRange, &afterRange) {
                    let insertionEnd = afterRange.location + afterRange.length
                    let finalLoc = max(0, insertionEnd - pipeLeftCount)
                    var finalRange = CFRange(location: finalLoc, length: 0)
                    if let finalAXVal = AXValueCreate(.cfRange, &finalRange) {
                        AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, finalAXVal)
                    }
                }
            }
        }

        return true
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

    // MARK: - Permission Checking Methods

    public func hasInputMonitoringPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        }
        return true // Assume granted on older macOS versions
    }

    func requestInputMonitoringPermission() {
        if #available(macOS 10.15, *) {
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
    }

    public func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrustedWithOptions(nil)
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openInputMonitoringSettings() {
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring")!)
        }
    }

    public func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: - Main Permission Flow

    func checkInputAccess() {
        let hasInputMonitoringPermission = hasInputMonitoringPermission()
        gDebugPrint("Input monitoring access: \(hasInputMonitoringPermission)")

        if(!hasInputMonitoringPermission) {
            requestInputMonitoringPermission()
            //  Wait for permissions to change and re-check
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.checkInputAccess()
            }

        // Return so that we only check one permission at a time
            return
        }


        let hasAccessibilityPermission = hasAccessibilityPermission()
        gDebugPrint("Accessibility access: \(hasAccessibilityPermission)")

        if(!hasAccessibilityPermission) {
            requestAccessibilityPermission()
            //  Wait for permissions to change and re-check
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.checkInputAccess()
            }

            // Return so that we only check one permission at a time
            return
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateActivationPolicy()

        checkInputAccess()
        createStatusBarButton()

        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flagsChangedHandler)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyDownHandler)
        NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: keyUpHandler)

        if ProcessInfo.processInfo.arguments.contains("G_DEBUG") {
            showSettingsWindow()
        }

        startSyncedStorageReloadSchedule()
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

    private let settingsWindowDefaultSize = NSSize(width: 1200, height: 720)
    private let settingsWindowMinimumSize = NSSize(width: 920, height: 450)

    @objc func showSettingsWindow () {
        windowsOpen += 1
        updateActivationPolicy()

        settingsUI = SettingsView(appModel: appModel)

        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: settingsWindowDefaultSize),
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
        window.contentMinSize = settingsWindowMinimumSize
        window.delegate = self

        let hostingController = NSHostingController(rootView: settingsUI!)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.minSize]
        }
        window.contentViewController = hostingController
        window.setContentSize(settingsWindowDefaultSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc func openMenu() {
        let versionNsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
        let version = versionNsObject as! String
        let menu = NSMenu()
        //        menu.addItem(withTitle: "About \(getTargetName())", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Preferences", action: #selector(showSettingsWindow), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Send me feedback", action: #selector(openFeedback), keyEquivalent: "")
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
        stopSyncedStorageReloadSchedule()
        appModel.appSettings.closeSettingsFileAccess()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func getTargetName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
    }
}
