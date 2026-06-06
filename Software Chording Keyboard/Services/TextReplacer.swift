//
//  TextReplacer.swift
//  Software Chording Keyboard
//

import AppKit
import Foundation

struct TextReplacer {
    func pressKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        eventDown?.post(tap: .cghidEventTap)
        let eventUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        eventUp?.post(tap: .cghidEventTap)
    }

    func typeText(_ text: String) {
        let utf16Chars = Array(text.utf16)

        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true)
        event1?.flags = .maskNonCoalesced
        event1?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        event1?.post(tap: .cghidEventTap)

        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false)
        event2?.flags = .maskNonCoalesced
        event2?.post(tap: .cghidEventTap)
    }

    /// Backspace then type " {character}" for owed-space insertion.
    /// Returns the number of monitor callbacks to ignore.
    func insertOwedSpaceBefore(character: String) -> Int {
        pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        typeText(" \(character)")
        // pressKey posts keyDown + keyUp; typeText posts keyDown + keyUp.
        return 4
    }

    /// Replaces chord input via synthetic key events. Returns the number of monitor callbacks to ignore.
    func replaceViaSyntheticKeys(chord: Chord, resolved: ResolvedChordReplacement) -> Int {
        let outputSegments = resolved.segments
        let pipeLeftCount = resolved.leftArrowCount

        // pressKey posts keyDown + keyUp; typeText posts keyDown + keyUp per chunk.
        // We add 2 extras for the bonus * typeText (down + up).
        let syntheticKeyPressCount = chord.deleteCount + 1 + resolved.backspacesBeforeOutput + pipeLeftCount
        let ignoreCount = (2 * syntheticKeyPressCount) + (2 * outputSegments.count) + 2

        typeText("*")

        for _ in 0..<chord.deleteCount + 1 {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }

        for _ in 0..<resolved.backspacesBeforeOutput {
            pressKey(keyCode: KeyboardConstants.backspaceKeyCode)
        }

        for outputString in outputSegments {
            typeText(outputString)
        }
        gDebugPrint("typed \(outputSegments)")

        for _ in 0..<pipeLeftCount {
            pressKey(keyCode: KeyboardConstants.leftKeyCode)
        }

        return ignoreCount
    }

    /// Attempts to replace the chord input with the chord output via the Accessibility API.
    /// Returns true on success, false if any AX call fails (caller should fall back to synthetic keys).
    func replaceViaAccessibility(chord: Chord, resolved: ResolvedChordReplacement) -> Bool {
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

        var isTextWritable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &isTextWritable) == .success,
              isTextWritable.boolValue else {
            gDebugPrint("AX: kAXSelectedTextAttribute is not writable, bailing")
            return false
        }

        let inputCount = chord.input.count
        let leadingSpaceDeletionCount = resolved.backspacesBeforeOutput
        guard cursorRange.location >= inputCount + leadingSpaceDeletionCount else {
            gDebugPrint("AX: cursor location \(cursorRange.location) < inputCount \(inputCount) + leadingSpaceDeletionCount \(leadingSpaceDeletionCount), bailing")
            return false
        }

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

        var selectedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
              let selectedText = selectedRef as? String else {
            gDebugPrint("AX: failed to read back kAXSelectedTextAttribute after selection, restoring cursor")
            restoreCursor(focused: focused, cursorRange: cursorRange)
            return false
        }
        gDebugPrint("AX: selectedText after selection='\(selectedText)'")
        let selectedPrefix = String(selectedText.dropFirst(leadingSpaceDeletionCount).prefix(inputCount)).lowercased()
        gDebugPrint("AX: selectedPrefix='\(selectedPrefix)' expected sorted='\(String(chord.input.lowercased().sorted()))'")
        guard String(selectedPrefix.sorted()) == String(chord.input.lowercased().sorted()) else {
            gDebugPrint("AX: selection verification failed, restoring cursor and bailing")
            restoreCursor(focused: focused, cursorRange: cursorRange)
            return false
        }

        let outputSegments = resolved.segments
        let pipeLeftCount = resolved.leftArrowCount
        let output = outputSegments.joined()

        gDebugPrint("AX: writing output='\(output)'")
        guard AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, output as CFTypeRef) == .success else {
            gDebugPrint("AX: write failed, restoring cursor")
            restoreCursor(focused: focused, cursorRange: cursorRange)
            return false
        }

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

    private func restoreCursor(focused: AXUIElement, cursorRange: CFRange) {
        var orig = cursorRange
        if let origAXVal = AXValueCreate(.cfRange, &orig) {
            AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, origAXVal)
        }
    }
}
