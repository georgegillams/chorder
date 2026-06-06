//
//  AccessibilityReplacementVerification.swift
//  Software Chording Keyboard
//

import Foundation

enum AccessibilityReplacementVerification {
    enum VerificationFailure: Error, CustomStringConvertible, Equatable {
        case cursorTooEarly(cursorLocation: Int, inputCount: Int, leadingSpaceDeletionCount: Int)
        case cursorPastFieldEnd(cursorLocation: Int, fieldLength: Int)
        case leadingSpaceDeletionUnderflow
        case expectedLeadingSpace(at: Int, found: String)
        case inputMismatch(found: String, expected: String)
        case selectedTextMismatch(found: String, expected: String)

        var description: String {
            switch self {
            case let .cursorTooEarly(cursorLocation, inputCount, leadingSpaceDeletionCount):
                let required = inputCount + leadingSpaceDeletionCount
                return "cursor at \(cursorLocation) is before chord input (need location ≥ \(required) for input '\(inputCount) chars' + \(leadingSpaceDeletionCount) leading-space deletion(s))"
            case let .cursorPastFieldEnd(cursorLocation, fieldLength):
                return "cursor at \(cursorLocation) is past end of field (length \(fieldLength))"
            case .leadingSpaceDeletionUnderflow:
                return "leading-space deletion would read before start of field"
            case let .expectedLeadingSpace(at, found):
                return "expected space at index \(at), found '\(found)'"
            case let .inputMismatch(found, expected):
                return "text before cursor '\(found)' does not match chord input '\(expected)' (order-independent compare failed)"
            case let .selectedTextMismatch(found, expected):
                return "selected text prefix '\(found)' does not match chord input '\(expected)' after selection"
            }
        }
    }

    struct VerifiedSelection {
        let selectRange: CFRange
        let startIndex: Int
    }

    static func sortedInputMatches(_ fieldChars: String, chordInput: String) -> Bool {
        String(fieldChars.lowercased().sorted()) == String(chordInput.lowercased().sorted())
    }

    /// Validates field text around the cursor and returns the AX selection range to replace.
    static func verifiedSelection(
        fieldValue: String,
        cursorRange: CFRange,
        chordInput: String,
        leadingSpaceDeletionCount: Int
    ) -> Result<VerifiedSelection, VerificationFailure> {
        let inputCount = chordInput.count
        let expectedInput = chordInput.lowercased()
        guard cursorRange.location >= inputCount + leadingSpaceDeletionCount else {
            return .failure(.cursorTooEarly(
                cursorLocation: cursorRange.location,
                inputCount: inputCount,
                leadingSpaceDeletionCount: leadingSpaceDeletionCount
            ))
        }

        let nsField = fieldValue as NSString
        guard cursorRange.location <= nsField.length else {
            return .failure(.cursorPastFieldEnd(
                cursorLocation: cursorRange.location,
                fieldLength: nsField.length
            ))
        }

        var startIndex = cursorRange.location - inputCount
        if leadingSpaceDeletionCount > 0 {
            startIndex -= leadingSpaceDeletionCount
            guard startIndex >= 0 else {
                return .failure(.leadingSpaceDeletionUnderflow)
            }
            let leadingCharacter = nsField.substring(with: NSRange(location: startIndex, length: 1))
            guard leadingCharacter == " " else {
                return .failure(.expectedLeadingSpace(at: startIndex, found: leadingCharacter))
            }
        }

        let inputStartIndex = startIndex + leadingSpaceDeletionCount
        let charsBeforeCursor = nsField.substring(with: NSRange(location: inputStartIndex, length: inputCount))
        guard sortedInputMatches(charsBeforeCursor, chordInput: chordInput) else {
            return .failure(.inputMismatch(found: charsBeforeCursor, expected: expectedInput))
        }

        let selectRange = CFRange(
            location: startIndex,
            length: inputCount + leadingSpaceDeletionCount + cursorRange.length
        )
        return .success(VerifiedSelection(selectRange: selectRange, startIndex: startIndex))
    }

    static func verifySelectedText(
        _ selectedText: String,
        chordInput: String,
        leadingSpaceDeletionCount: Int
    ) -> Result<Void, VerificationFailure> {
        let inputCount = chordInput.count
        let selectedPrefix = String(selectedText.dropFirst(leadingSpaceDeletionCount).prefix(inputCount))
        guard sortedInputMatches(selectedPrefix, chordInput: chordInput) else {
            return .failure(.selectedTextMismatch(
                found: selectedPrefix,
                expected: chordInput.lowercased()
            ))
        }
        return .success(())
    }

    static func pipeCursorLocation(afterInsertionEnd: Int, leftArrowCount: Int) -> Int {
        max(0, afterInsertionEnd - leftArrowCount)
    }
}
