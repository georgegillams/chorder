//
//  OutputPlaceholderExpansion.swift
//  SoftwareChordingKeyboard
//

import Foundation

/// Expands `{{…}}` segments using `DateFormatter` / ICU date field symbols (e.g. `yyyy`, `MM`, `dd`, `HH`, `mm`, `E`, `zzz`).
/// See Unicode TR35 date field symbols for the full set supported by Apple’s formatter.
enum OutputPlaceholderExpansion {
    private static let tokenRegex = try! NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#, options: [])

    static func expand(_ string: String, referenceDate: Date = Date()) -> String {
        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = tokenRegex.matches(in: string, options: [], range: fullRange)
        guard !matches.isEmpty else { return string }

        var result = string
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            var inner = nsString.substring(with: match.range(at: 1))
            if inner.isEmpty { continue }

            let replacement = formatICUDatePattern(inner, date: referenceDate)
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    private static func formatICUDatePattern(_ pattern: String, date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.calendar = .current
        df.dateFormat = pattern
        return df.string(from: date)
    }
}
