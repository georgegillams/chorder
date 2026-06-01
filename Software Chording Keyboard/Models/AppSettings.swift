//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation
import SwiftUI

class AppSettings {
    private var initialisationComplete: Bool = false
    private var suppressWritingToFile: Bool = false
    @Published private(set) public var isDirty: Bool = false

    /* Raw settings */
    @Published private(set) public var chords: [Chord] {
        didSet {
            recalculateAlphabeticalMapping()
            writeAppSettingsToFile()
        }
    }
    @Published public var millisecondsToHoldStr: String {
        didSet {
            millisecondsToHold = Double(millisecondsToHoldStr.replacingOccurrences(of: "ms", with: "")) ?? millisecondsToHold
            writeAppSettingsToFile()
        }
    }
    @Published public var useAccessibilityAPI: Bool {
        didSet {
            writeAppSettingsToFile()
        }
    }

    /* Calculated */
    private(set) public var millisecondsToHold: Double
    private(set) public var alphabeticalInputOutputMappingDictionary: [String: Chord] = [:]

    /* Storage */
    var bookmarks: BookMarks
    var settingsFileDirectory: URL?
    var settingsFileLocation: URL {
        get {
            if let directory = settingsFileDirectory {
                return directory.appendingPathComponent("software_chording_keyboard_settings.json")
            }

            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("software_chording_keyboard_settings.json")
        }
    }

    init() {
        // default values - overwritten by readAppSettingsFromFile() below
        chords = []
        millisecondsToHoldStr = "100ms"
        millisecondsToHold = 100
        useAccessibilityAPI = true
        // end of default values

        settingsFileDirectory = UserDefaults.standard.url(forKey: "settingsFileDirectory")
        gDebugPrint("User defaults settingsFileDirectory: \(settingsFileDirectory)")
        bookmarks = BookMarks.restore() ?? BookMarks(data: [:])
        readAppSettingsFromFile()
        initialisationComplete = true
    }

    public func addChord(chord: Chord) {
        chords.append(chord)
    }

    public func removeChords(chords: Set<Chord.ID>) {
        self.chords.removeAll(where: { chords.contains($0.id) })
    }

    func recalculateAlphabeticalMapping() {
        alphabeticalInputOutputMappingDictionary = [:]
        for chord in chords {
            alphabeticalInputOutputMappingDictionary[chord.inputSorted] = chord
        }
    }

    func deserialiseChords(serialisableChords: [[String: String]]) -> [Chord] {
        var chords: [Chord] = []
        for serialisableChord in serialisableChords {
            chords.append(Chord(input: serialisableChord["input"] ?? "", output: serialisableChord["output"] ?? "",
                                usageCount: Int(serialisableChord["usageCount"] ?? "0")
                               ))
        }
        return chords
    }

    func parseSettingsFromJson(json: String) {
        let jsonDecoder = JSONDecoder()
        let jsonData = json.data(using: .utf8)!
        do {
            let serialisableSettings = try jsonDecoder.decode(SerialisableAppSettings.self, from: jsonData)
            millisecondsToHoldStr = serialisableSettings.millisecondsToHold
            useAccessibilityAPI = serialisableSettings.useAccessibilityAPI ?? true
            chords = deserialiseChords(serialisableChords: serialisableSettings.chords)
        } catch {
            gDebugPrint("Error deserialising data \(error)")
        }
    }

    func serialiseChords(chords: [Chord]) -> [[String: String]] {
        var serialisableChords: [[String: String]] = []
        for chord in chords {
            serialisableChords.append(["input": chord.input, "output": chord.output, "usageCount": String(chord.usageCount ?? 0)])
        }
        return serialisableChords
    }

    func getSettingsJsonString() -> String{
        let serialisableSettings = SerialisableAppSettings(millisecondsToHold: millisecondsToHoldStr, useAccessibilityAPI: useAccessibilityAPI, chords: serialiseChords(chords: chords))

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try jsonEncoder.encode(serialisableSettings)
            let json = String(data: jsonData, encoding: String.Encoding.utf8) ?? ""
            return json
        } catch {
            gDebugPrint("Error serialising data \(error)")
            return ""
        }
    }

    // TODO: Would be nice if this first re-reads usage numbers, and only overwrites if greater than existing value.
    // TODO: That way, across multiple devices, usage won't get lost.
    func writeAppSettingsToFile() {
        if(!initialisationComplete || suppressWritingToFile) {
            return
        }

        let jsonString = getSettingsJsonString()

        do {
            try jsonString.write(to: settingsFileLocation,
                                 atomically: true,
                                 encoding: .utf8)
            clearDirty()
        }catch {
            // Handle error
            gDebugPrint("ERROR \(error)")
        }
    }

    func readAppSettingsFromFile() {
        // While we read values from file and we're setting them, suppress re-writing to the file again
        suppressWritingToFile = true

        if (FileManager.default.fileExists(atPath: settingsFileLocation.path)) {
            do {
                let json = try String(contentsOf: settingsFileLocation, encoding: .utf8)
                parseSettingsFromJson(json: json)
            } catch {
                gDebugPrint("ERROR \(error)")
            }
        }

        recalculateAlphabeticalMapping()

        suppressWritingToFile = false
        clearDirty()
    }

    func chooseBackupSettingsFileLocation() {
        let dialog = NSOpenPanel();
        dialog.title                   = "Choose settings location";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = true;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        dialog.allowedContentTypes = [.directory]

        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url

            if (result != nil) {
                let path = result!.path
                updateSettingsLocation(newLocation: URL(fileURLWithPath: path))
                if(FileManager.default.fileExists(atPath: settingsFileLocation.path)) {
                    let alert = NSAlert()
                    alert.messageText = "Settings file already exists. Do you want to overwrite it, or read from it?"
                    alert.addButton(withTitle: "Overwrite")
                    alert.addButton(withTitle: "Read from existing file")
                    let modalResult = alert.runModal()
                    if (modalResult == NSApplication.ModalResponse.alertFirstButtonReturn) {
                        writeAppSettingsToFile()
                    } else {
                        readAppSettingsFromFile()
                    }
                } else {
                    writeAppSettingsToFile()
                }
            } 
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    func updateSettingsLocation(newLocation: URL) {
        settingsFileDirectory = newLocation
        UserDefaults.standard.set(newLocation, forKey: "settingsFileDirectory")
        bookmarks.store(url: newLocation)
    }

    public func setDirty() {
        isDirty = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if(self.isDirty && self.initialisationComplete && !self.suppressWritingToFile) {
                self.writeAppSettingsToFile()
                self.clearDirty()
            }
        }
    }

    private func clearDirty() {
        isDirty = false
    }

    public func closeSettingsFileAccess() {
        if let directoryUrl = settingsFileDirectory {
            directoryUrl.stopAccessingSecurityScopedResource()
        }
    }
}

struct SerialisableAppSettings: Codable {
    var millisecondsToHold: String
    var useAccessibilityAPI: Bool?  // optional so existing settings files without the key default to true
    var chords: [[String: String]]
}
