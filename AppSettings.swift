//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation
import SwiftUI

class AppSettings {
    private var initComplete: Bool = false

    /* Raw settings */
    private(set) public var chords: [Chord]
    @Published public var millisecondsToHoldStr: String {
        didSet {
            millisecondsToHold = Double(millisecondsToHoldStr.replacingOccurrences(of: "ms", with: "")) ?? millisecondsToHold
            writeAppSettingsToFile()
        }
    }
    
    /* Calculated */
    private(set) public var millisecondsToHold: Double
    private(set) public var alphabeticalInputOutputMappingDictionary: [String: Chord] = [:]

    /* Storage */
    var bookmarks = [URL: Data]()
    var bookmarksPath: String{
        get {
            var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
            url = url.appendingPathComponent("Bookmarks.dict")
            return url.path
        }
    }
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
        chords = []
        millisecondsToHoldStr = "60ms"
        millisecondsToHold = 60

        loadSecureBookmarks()
        readAppSettingsFromFile()
        initComplete = true
    }
    
    public func addChord(chord: Chord) {
        chords.append(chord)
        recalculateAlphabeticalMapping()
        writeAppSettingsToFile()
    }
    
    public func removeChords(chords: Set<Chord.ID>) {
        self.chords.removeAll(where: { chords.contains($0.id) })
        recalculateAlphabeticalMapping()
        writeAppSettingsToFile()
    }
    
    public func recalculateAppSettings () {
        recalculateAlphabeticalMapping()
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
            chords.append(Chord(input: serialisableChord["input"] ?? "", output: serialisableChord["output"] ?? ""))
        }
        return chords
    }

    func parseSettingsFromJson(json: String) {
        let jsonDecoder = JSONDecoder()
        let jsonData = json.data(using: .utf8)!
        do {
            let serialisableSettings = try jsonDecoder.decode(SerialisableAppSettings.self, from: jsonData)
            millisecondsToHoldStr = serialisableSettings.millisecondsToHold
            chords = deserialiseChords(serialisableChords: serialisableSettings.chords)
            recalculateAlphabeticalMapping()
        } catch {
            print("Error deserialising data \(error)")
        }
    }

    func serialiseChords(chords: [Chord]) -> [[String: String]] {
        var serialisableChords: [[String: String]] = []
        for chord in chords {
            serialisableChords.append(["input": chord.input, "output": chord.output])
        }
        return serialisableChords
    }

    func getSettingsJsonString() -> String{
        let serialisableSettings = SerialisableAppSettings(millisecondsToHold: millisecondsToHoldStr, chords: serialiseChords(chords: chords) )

        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(serialisableSettings)
            let json = String(data: jsonData, encoding: String.Encoding.utf8) ?? ""
            return json
        } catch {
            print("Error serialising data \(error)")
            return ""
        }
    }

    func writeAppSettingsToFile() {
        if(!initComplete) {
            return
        }

        let jsonString = getSettingsJsonString()

        do {
            try jsonString.write(to: settingsFileLocation,
                                 atomically: true,
                                 encoding: .utf8)
        }catch {
            // Handle error
            print("ERROR \(error)")
        }
    }
    
    func readAppSettingsFromFile() {
        if (FileManager.default.fileExists(atPath: settingsFileLocation.path)) {
            do {
                let json = try String(contentsOf: settingsFileLocation, encoding: .utf8)
                parseSettingsFromJson(json: json)
            } catch {
                print("ERROR \(error)")
            }
        }

        recalculateAppSettings()
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
                // TODO: If there is a settings file there already, ask if we should read it or overwrite it.
                writeAppSettingsToFile()
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    func updateSettingsLocation(newLocation: URL) {
        settingsFileDirectory = newLocation

        do
        {
            let data = try newLocation.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[newLocation] = data
            NSKeyedArchiver.archiveRootObject(bookmarks, toFile: bookmarksPath)
        }
        catch
        {
            Swift.print ("Error storing bookmarks")
        }
        writeAppSettingsToFile()
    }

    func loadSecureBookmarks() {
        if (!FileManager.default.fileExists(atPath: bookmarksPath)) {
            return
        }

        bookmarks = NSKeyedUnarchiver.unarchiveObject(withFile: bookmarksPath) as! [URL: Data]
        for bookmark in bookmarks
        {
            let restoredUrl: URL?
            var isStale = false

            Swift.print ("Restoring \(bookmark.key)")
            do
            {
                restoredUrl = try URL.init(resolvingBookmarkData: bookmark.value, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            }
            catch
            {
                Swift.print ("Error restoring bookmarks")
                restoredUrl = nil
            }

            if let url = restoredUrl
            {
                if isStale
                {
                    Swift.print ("URL is stale")
                }
                else
                {
                    if !url.startAccessingSecurityScopedResource()
                    {
                        Swift.print ("Couldn't access: \(url.path)")
                    }
                    settingsFileDirectory = url
                }
            }

        }
    }

    public func closeSettingsFileAccess() {
        if let directoryUrl = settingsFileDirectory {
            directoryUrl.stopAccessingSecurityScopedResource()
        }
    }
}

struct SerialisableAppSettings: Codable {
    var millisecondsToHold: String
    var chords: [[String: String]]
}
