//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation

class AppSettings {
    var chords: [Chord]
    
    @Published var millisecondsToHold: String

    
    init() {
        // TODO: Read from file
        chords = [
            Chord(input: "th", output : "the"),
            Chord(input: "cn", output: "const"),
            Chord(input: "ne", output:"new"),
            Chord(input: "rt", output: "return"),
            Chord(input: "sck", output: "software chording keyboard"),
            Chord(input: "typ", output: "Typeform"),
            Chord(input: "typw", output: "typeform.com"),
            Chord(input: "ge", output: "georgegillams.co.uk"),
            Chord(input: "fn", output: "const | = () => {}"),
            Chord(input: "ty", output: "type"),
            Chord(input: "at", output: "at"),
            Chord(input: "sp", output: "speed"),
            Chord(input: "of", output: "of"),
            Chord(input: "tho", output: "thought"),
            Chord(input: "bet", output: "better"),
            Chord(input: "st", output: "stronger"),
            Chord(input: "fas", output: "faster"),
            Chord(input: "yh", output: "yeah"),
            Chord(input: "tnk", output: "thanks"),
            Chord(input: "alr", output: "already"),
            Chord(input: "fn2", output: "const | = () => {\\|}"),
            Chord(input: "fn3", output: "const \\| = (*) => {|}"),
            Chord(input: "ni", output: "nice"),
            Chord(input: "ye", output: "yes"),
            Chord(input: "se", output: "see"),
            Chord(input: "yo", output: "you"),
            Chord(input: "hv", output: "have"),
            Chord(input: "cd", output: "code"),
            Chord(input: "in", output: "in")
        ]
        millisecondsToHold = "60ms"
    }
}
