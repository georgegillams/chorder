//
//  TextReplacer.swift
//  Chorder
//

import AppKit
import ChorderCore
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
        let ignoreCount = resolved.syntheticKeyEchoCount(inputDeleteCount: chord.deleteCount)

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

        for _ in 0..<resolved.leftArrowCount {
            pressKey(keyCode: KeyboardConstants.leftKeyCode)
        }

        return ignoreCount
    }

    /// Attempts to replace the chord input with the chord output via the Accessibility API.
    /// Returns true on success, false if any AX call fails (caller should fall back to synthetic keys).
    /// Reasons this could fail:
    /// - Sandboxed app
    /// - Current app is broken with AX, and put in exclude list (eg Firefox)
    /// - Current app doesn't report focused element or cursor position (eg Electron apps)
    /// - Current app is not writable via AX (eg Terminal)
    func replaceViaAccessibility(chord: Chord, resolved: ResolvedChordReplacement) -> Bool {
        gDebugPrint("AX: attempting replacement for chord '\(chord.input)' → '\(resolved.outputText)'")

        // 1. Skip known-broken apps, then locate the focused text field.
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           axIncompatibleAppBundleIDs.contains(bundleID) {
            return axFail("app '\(bundleID)' is on the AX-incompatible list (known broken kAXSelectedTextAttribute writes)")
        }

        let axUiElement = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axUiElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success else {
            return axFail("could not read kAXFocusedUIElementAttribute (no focused element or accessibility permission issue)")
        }
        let focused = focusedRef as! AXUIElement

        // 2. Check replacement feasibility — need a cursor position and a writable selected-text attribute.
        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef else {
            return axFail("could not read kAXSelectedTextRangeAttribute from focused element")
        }
        var cursorRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cursorRange) else {
            return axFail("kAXSelectedTextRangeAttribute value is not a CFRange")
        }
        gDebugPrint("AX: cursorRange location=\(cursorRange.location) length=\(cursorRange.length)")

        var isTextWritable: DarwinBoolean = false
        let writableStatus = AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &isTextWritable)
        guard writableStatus == .success else {
            return axFail("could not query whether kAXSelectedTextAttribute is settable (AX status \(writableStatus.rawValue))")
        }
        guard isTextWritable.boolValue else {
            return axFail("kAXSelectedTextAttribute is not writable on focused element (secure field, read-only control, or unsupported editor)")
        }

        let leadingSpaceDeletionCount = resolved.backspacesBeforeOutput
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueRef) == .success else {
            return axFail("could not read kAXValueAttribute from focused element")
        }
        guard let fieldValue = valueRef as? String else {
            return axFail("kAXValueAttribute is not a String (got \(type(of: valueRef)))")
        }
        gDebugPrint("AX: fieldValue length=\((fieldValue as NSString).length) value='\(fieldValue)'")

        // 3. Confirm the chord input (and any leading space to remove) sits immediately before the cursor, then compute the range we intend to select.
        let verified: AccessibilityReplacementVerification.VerifiedSelection
        switch AccessibilityReplacementVerification.verifiedSelection(
            fieldValue: fieldValue,
            cursorRange: cursorRange,
            chordInput: chord.input,
            leadingSpaceDeletionCount: leadingSpaceDeletionCount
        ) {
        case let .failure(reason):
            return axFail(reason.description)
        case let .success(selection):
            verified = selection
            gDebugPrint("AX: verified selection startIndex=\(verified.startIndex) selectRange location=\(verified.selectRange.location) length=\(verified.selectRange.length)")
        }

        var selectRange = verified.selectRange
        guard let selectAXVal = AXValueCreate(.cfRange, &selectRange) else {
            return axFail("could not create AXValue for selectRange location=\(verified.selectRange.location) length=\(verified.selectRange.length)")
        }
        guard AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, selectAXVal) == .success else {
            return axFail("could not set kAXSelectedTextRangeAttribute to location=\(verified.selectRange.location) length=\(verified.selectRange.length)")
        }

        var selectedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
              let selectedText = selectedRef as? String else {
            restoreCursor(focused: focused, cursorRange: cursorRange)
            return axFail("could not read kAXSelectedTextAttribute after setting selection range; cursor restored")
        }
        gDebugPrint("AX: selectedText after selection='\(selectedText)'")

        // 4. Read back what AX actually selected; abort and restore the cursor if it does not match the chord input we expected.
        switch AccessibilityReplacementVerification.verifySelectedText(
            selectedText,
            chordInput: chord.input,
            leadingSpaceDeletionCount: leadingSpaceDeletionCount
        ) {
        case let .failure(reason):
            restoreCursor(focused: focused, cursorRange: cursorRange)
            return axFail("\(reason.description); cursor restored")
        case .success:
            break
        }

        // 5. Overwrite the verified selection with the chord output.
        let output = resolved.outputText
        gDebugPrint("AX: writing output='\(output)'")
        guard AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, output as CFTypeRef) == .success else {
            restoreCursor(focused: focused, cursorRange: cursorRange)
            return axFail("kAXSelectedTextAttribute write rejected; cursor restored")
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

        if resolved.leftArrowCount > 0 {
            var afterRangeRef: AnyObject?
            guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &afterRangeRef) == .success,
                  let afterRangeValue = afterRangeRef else {
                gDebugPrint("AX: warning — could not read cursor range for pipe repositioning (output written successfully)")
                gDebugPrint("AX: replacement succeeded for chord '\(chord.input)' → '\(output)'")
                return true
            }
            var afterRange = CFRange(location: 0, length: 0)
            guard AXValueGetValue(afterRangeValue as! AXValue, .cfRange, &afterRange) else {
                gDebugPrint("AX: warning — post-write cursor range is not a CFRange; pipe cursor not repositioned")
                gDebugPrint("AX: replacement succeeded for chord '\(chord.input)' → '\(output)'")
                return true
            }
            let insertionEnd = afterRange.location + afterRange.length
            let finalLoc = AccessibilityReplacementVerification.pipeCursorLocation(
                afterInsertionEnd: insertionEnd,
                leftArrowCount: resolved.leftArrowCount
            )
            var finalRange = CFRange(location: finalLoc, length: 0)
            guard let finalAXVal = AXValueCreate(.cfRange, &finalRange) else {
                gDebugPrint("AX: warning — could not create AXValue for pipe cursor at \(finalLoc)")
                gDebugPrint("AX: replacement succeeded for chord '\(chord.input)' → '\(output)'")
                return true
            }
            guard AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, finalAXVal) == .success else {
                gDebugPrint("AX: warning — could not reposition cursor for pipe (target location \(finalLoc), leftArrowCount \(resolved.leftArrowCount))")
                gDebugPrint("AX: replacement succeeded for chord '\(chord.input)' → '\(output)'")
                return true
            }
            gDebugPrint("AX: pipe cursor repositioned to location \(finalLoc) (leftArrowCount \(resolved.leftArrowCount))")
        }

        gDebugPrint("AX: replacement succeeded for chord '\(chord.input)' → '\(output)'")
        return true
    }

    private func axFail(_ reason: String) -> Bool {
        gDebugPrint("AX: failed — \(reason); falling back to CGEvent")
        return false
    }

    private func restoreCursor(focused: AXUIElement, cursorRange: CFRange) {
        var orig = cursorRange
        if let origAXVal = AXValueCreate(.cfRange, &orig) {
            AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, origAXVal)
        }
    }
}
