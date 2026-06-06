//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
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
    let machineIdentifier: String
    var settingsFileDirectory: URL?
    var settingsRootDirectory: URL {
        settingsFileDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var statsDirectoryURL: URL {
        ChordUsageStore.statsDirectory(in: settingsRootDirectory)
    }
    var localMachineStatsFileURL: URL {
        ChordUsageStore.statsFileURL(for: machineIdentifier, in: settingsRootDirectory)
    }
    var settingsFileLocation: URL {
        get {
            settingsRootDirectory.appendingPathComponent("software_chording_keyboard_settings.json")
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
        machineIdentifier = MachineIdentifier.current
        gDebugPrint("Machine identifier: \(machineIdentifier)")
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

    public func updateChord(
        id: Chord.ID,
        input: String,
        output: String,
        capitalisationMode: ChordCapitalisationMode,
        spaceBeforeOutputMode: ChordSpaceBeforeOutputMode
    ) {
        guard let index = chords.firstIndex(where: { $0.id == id }) else {
            return
        }
        chords[index].update(
            input: input,
            output: output,
            capitalisationMode: capitalisationMode,
            spaceBeforeOutputMode: spaceBeforeOutputMode
        )
        recalculateAlphabeticalMapping()
        objectWillChange.send()
        writeAppSettingsToFile()
    }

    public func incrementUsage(for chord: Chord) {
        chord.incrementUsageCount(for: machineIdentifier)
        objectWillChange.send()
    }

    func recalculateAlphabeticalMapping() {
        alphabeticalInputOutputMappingDictionary = [:]
        for chord in chords {
            alphabeticalInputOutputMappingDictionary[chord.inputSorted] = chord
        }
    }

    func deserialiseChords(serialisableChords: [SerialisableChord]) -> [Chord] {
        serialisableChords.map { serialisableChord in
            let capitalisationMode = ChordCapitalisationMode(
                rawValue: serialisableChord.capitalisationMode ?? ""
            ) ?? .default
            let spaceBeforeOutputMode = ChordSpaceBeforeOutputMode(
                rawValue: serialisableChord.spaceBeforeOutput ?? ""
            ) ?? .default
            return Chord(
                id: serialisableChord.id,
                input: serialisableChord.input,
                output: serialisableChord.output,
                capitalisationMode: capitalisationMode,
                spaceBeforeOutputMode: spaceBeforeOutputMode
            )
        }
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

    func serialiseChords(chords: [Chord]) -> [SerialisableChord] {
        chords.map { chord in
            SerialisableChord(
                id: chord.id,
                input: chord.input,
                output: chord.output,
                capitalisationMode: chord.capitalisationMode.rawValue,
                spaceBeforeOutput: chord.spaceBeforeOutputMode.rawValue
            )
        }
    }

    func reloadUsageFromStatsDirectory() {
        let usageByMachine = ChordUsageStore.loadAllMachineUsage(from: settingsRootDirectory)
        for chord in chords {
            var usageForChord: [String: Int] = [:]
            for (machineId, usageByChordId) in usageByMachine {
                if let count = usageByChordId[chord.id], count > 0 {
                    usageForChord[machineId] = count
                }
            }
            chord.usageByMachine = usageForChord
        }
        objectWillChange.send()
    }

    func writeLocalMachineStatsFile() {
        var usageByChordId: [String: Int] = [:]
        for chord in chords {
            if let count = chord.usageByMachine[machineIdentifier], count > 0 {
                usageByChordId[chord.id] = count
            }
        }

        let incoming = MachineUsageStats(usageByChordId: usageByChordId)
        let merged = ChordUsageStore.mergedUsageOnDisk(at: localMachineStatsFileURL, with: incoming)

        do {
            try ChordUsageStore.saveMachineUsage(merged, to: localMachineStatsFileURL)
        } catch {
            gDebugPrint("ERROR writing stats file \(error)")
        }
    }

    func getSettingsJsonString() -> String{
        let serialisableSettings = SerialisableAppSettings(
            millisecondsToHold: millisecondsToHoldStr,
            useAccessibilityAPI: useAccessibilityAPI,
            chords: serialiseChords(chords: chords)
        )

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

        let settingsFileChanged = SettingsMigration.run(on: self)
        reloadUsageFromStatsDirectory()
        recalculateAlphabeticalMapping()

        suppressWritingToFile = false
        if settingsFileChanged {
            writeAppSettingsToFile()
        }
        clearDirty()
    }

    /// Reloads settings and usage from disk, for example after iCloud sync from another machine.
    func reloadFromSyncedStorage() {
        guard initialisationComplete else {
            return
        }
        if isDirty {
            writeLocalMachineStatsFile()
            clearDirty()
        }
        gDebugPrint("Reloading settings and usage from synced storage")
        readAppSettingsFromFile()
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
        reloadUsageFromStatsDirectory()
    }

    public func setUsageCountDirty() {
        isDirty = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if(self.isDirty && self.initialisationComplete && !self.suppressWritingToFile) {
                self.writeLocalMachineStatsFile()
                self.clearDirty()
            }
        }
    }

    private func clearDirty() {
        isDirty = false
    }

    /// Writes pending usage stats immediately. Call on app termination before releasing file access.
    public func flushPendingStatsIfNeeded() {
        guard isDirty, initialisationComplete, !suppressWritingToFile else {
            return
        }
        writeLocalMachineStatsFile()
        clearDirty()
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
    var chords: [SerialisableChord]
}

struct SerialisableChord: Codable {
    var id: String
    var input: String
    var output: String
    var capitalisationMode: String?
    var spaceBeforeOutput: String?

    init(
        id: String,
        input: String,
        output: String,
        capitalisationMode: String?,
        spaceBeforeOutput: String? = nil
    ) {
        self.id = id
        self.input = input
        self.output = output
        self.capitalisationMode = capitalisationMode
        self.spaceBeforeOutput = spaceBeforeOutput
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        input = try container.decode(String.self, forKey: .input)
        output = try container.decode(String.self, forKey: .output)
        capitalisationMode = try container.decodeIfPresent(String.self, forKey: .capitalisationMode)
        spaceBeforeOutput = try container.decodeIfPresent(String.self, forKey: .spaceBeforeOutput)
    }
}
