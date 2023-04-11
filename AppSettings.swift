//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation
import SwiftUI

class AppSettings {
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
        // TODO: Remove this once read from file
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
        millisecondsToHoldStr = "60ms"
        millisecondsToHold = 60
        // TODO: End remove

        loadSecureBookmarks()
        readAppSettingsFromFile()
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

    func parseSettingsFromJson(json: String) {
        let jsonDecoder = JSONDecoder()
        let jsonData = json.data(using: .utf8)!
        do {
        let serialisableSettings = try jsonDecoder.decode(SerialisableAppSettings.self, from: jsonData)
        millisecondsToHoldStr = serialisableSettings.millisecondsToHold
        } catch {
            print("Error deserialising data \(error)")
        }
    }

    func getSettingsJsonString() -> String{
        let serialisableSettings = SerialisableAppSettings(millisecondsToHold: millisecondsToHoldStr)

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
}
