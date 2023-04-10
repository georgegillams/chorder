//
//  AppModel.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 06/04/2023.
//

import Foundation

class AppModel: ObservableObject {
    var appSettings = AppSettings()
    var alphabeticalInputOutputMappingDictionary: [String: Chord] = [:]
    var millisecondsToHold: Double {
        get {
            return Double(appSettings.millisecondsToHold.replacingOccurrences(of: "ms", with: "")) ?? 0
        }
    } 
    
    public func addChord(chord: Chord) {
        appSettings.chords.append(chord)
        createAlphabeticalMapping()
        // Write settings to file
    }
    
    public func removeChords(chords: Set<Chord.ID>) {
        appSettings.chords.removeAll(where: { chords.contains($0.id) })
        createAlphabeticalMapping()
        // Write settings to file
    }
    
    public func reloadAppSettings () {
        createAlphabeticalMapping()
    }
    
    func createAlphabeticalMapping() {
        alphabeticalInputOutputMappingDictionary = [:]
        for chord in appSettings.chords {
            alphabeticalInputOutputMappingDictionary[chord.inputSorted] = chord
        }
    }
    
}
