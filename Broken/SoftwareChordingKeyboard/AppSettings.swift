//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation

class AppSettings {
    var inputOutputMappingDictionary: [String: String]
    let millisecondsToHold: Double
    
    init() {
        // TODO: Read from file
        inputOutputMappingDictionary = [
            "th" : "the",
            "cn": "const",
            "ne":"new",
            "rt": "return",
            "sck": "software chording keyboard",
            "typ": "Typeform",
            "typw": "typeform.com",
            "ge": "georgegillams.co.uk",
            "fn": "const | = () => {}",
            "ty": "type",
            "at": "at",
            "sp": "speed",
            "of": "of",
            "tho": "thought",
            "et": "better",
            "st": "stronger",
            "fas": "faster",
            "yh": "yeah",
            "tnk": "thanks",
            "alr": "already",
            "fn2": "const | = () => {\\|}",
            "fn3": "const \\| = (*) => {|}",
            "ni": "nice"
        ]
        millisecondsToHold = 60
    }
}
