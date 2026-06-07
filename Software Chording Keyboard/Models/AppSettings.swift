//
//  AppSettings.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let minimumHoldMilliseconds: Double = 10
    static let maximumHoldMilliseconds: Double = 2000

    private var initialisationComplete: Bool = false
    private var suppressWritingToFile: Bool = false
    private var statsWriteWorkItem: DispatchWorkItem?
    private(set) var migrationVersion: Int = 0
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
            if let parsed = Self.parseHoldDelayMilliseconds(from: millisecondsToHoldStr) {
                millisecondsToHold = parsed
            }
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
    /// Normalised input keys that map to more than one chord in the settings file (last chord wins at runtime).
    @Published private(set) public var duplicateNormalisedInputKeys: [String] = []

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

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func makeForTesting() -> AppSettings {
        AppSettings(settingsFileDirectoryOverride: isolatedUnitTestSettingsDirectory(uniquePerInstance: true))
    }

    static func isolatedUnitTestSettingsDirectory(uniquePerInstance: Bool) -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("software-chording-keyboard-unit-tests", isDirectory: true)
        let directoryName = uniquePerInstance
            ? UUID().uuidString
            : String(ProcessInfo.processInfo.processIdentifier)
        let root = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    init(settingsFileDirectoryOverride: URL? = nil) {
        // default values - overwritten by readAppSettingsFromFile() below
        chords = []
        millisecondsToHoldStr = "100ms"
        millisecondsToHold = 100
        useAccessibilityAPI = true
        // end of default values

        machineIdentifier = MachineIdentifier.current
        gDebugPrint("Machine identifier: \(machineIdentifier)")

        if let settingsFileDirectoryOverride {
            settingsFileDirectory = settingsFileDirectoryOverride
            bookmarks = BookMarks(data: [:])
        } else if Self.isRunningUnitTests {
            settingsFileDirectory = Self.isolatedUnitTestSettingsDirectory(uniquePerInstance: false)
            bookmarks = BookMarks(data: [:])
            gDebugPrint("Using isolated unit-test settings directory: \(settingsFileDirectory!)")
        } else {
            settingsFileDirectory = UserDefaults.standard.url(forKey: "settingsFileDirectory")
            gDebugPrint("User defaults settingsFileDirectory: \(settingsFileDirectory)")
            bookmarks = BookMarks.restore() ?? BookMarks(data: [:])
            reconcileSettingsDirectoryWithBookmarks()
        }

        readAppSettingsFromFile()
        initialisationComplete = true
    }

    func setMigrationVersion(_ version: Int) {
        migrationVersion = version
    }

    func reconcileSettingsDirectoryWithBookmarks() {
        if let bookmarkURL = bookmarks.storedDirectoryURL {
            if settingsFileDirectory != bookmarkURL {
                settingsFileDirectory = bookmarkURL
                UserDefaults.standard.set(bookmarkURL, forKey: "settingsFileDirectory")
            }
            return
        }

        if let settingsFileDirectory {
            bookmarks.store(url: settingsFileDirectory)
        }
    }

    static func parseHoldDelayMilliseconds(from string: String) -> Double? {
        let trimmed = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "ms", with: "", options: .caseInsensitive)
        guard let value = Double(trimmed),
              value >= minimumHoldMilliseconds,
              value <= maximumHoldMilliseconds else {
            return nil
        }
        return value
    }

    public func addChord(chord: Chord) {
        chords.append(chord)
    }

    public var activeChords: [Chord] {
        chords.filter { !$0.deleted }
    }

    public func removeChords(chords ids: Set<Chord.ID>) {
        for index in chords.indices where ids.contains(chords[index].id) {
            chords[index].deleted = true
        }
        recalculateAlphabeticalMapping()
        objectWillChange.send()
        writeAppSettingsToFile()
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
        var duplicateKeys: [String] = []

        for chord in activeChords {
            let key = chord.inputSorted
            if let existing = alphabeticalInputOutputMappingDictionary[key] {
                duplicateKeys.append(key)
                gDebugPrint(
                    "Warning: duplicate normalised chord input '\(key)' — "
                    + "using '\(chord.input)' (id: \(chord.id)), "
                    + "shadowing '\(existing.input)' (id: \(existing.id))"
                )
            }
            alphabeticalInputOutputMappingDictionary[key] = chord
        }

        duplicateNormalisedInputKeys = Array(Set(duplicateKeys)).sorted()
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
                spaceBeforeOutputMode: spaceBeforeOutputMode,
                deleted: serialisableChord.deleted ?? false
            )
        }
    }

    func parseSettingsFromJson(json: String) {
        guard let jsonData = json.data(using: .utf8) else {
            SettingsAlerts.showSettingsLoadFailure("The settings file is not valid UTF-8 text.")
            return
        }

        let jsonDecoder = JSONDecoder()
        do {
            let serialisableSettings = try jsonDecoder.decode(SerialisableAppSettings.self, from: jsonData)
            migrationVersion = serialisableSettings.migrationVersion ?? 0
            millisecondsToHoldStr = serialisableSettings.millisecondsToHold
            if let parsed = Self.parseHoldDelayMilliseconds(from: serialisableSettings.millisecondsToHold) {
                millisecondsToHold = parsed
            }
            useAccessibilityAPI = serialisableSettings.useAccessibilityAPI ?? true
            chords = deserialiseChords(serialisableChords: serialisableSettings.chords)
        } catch {
            gDebugPrint("Error deserialising data \(error)")
            SettingsAlerts.showSettingsLoadFailure(error.localizedDescription)
        }
    }

    func serialiseChords(chords: [Chord]) -> [SerialisableChord] {
        chords.map { chord in
            SerialisableChord(
                id: chord.id,
                input: chord.input,
                output: chord.output,
                capitalisationMode: chord.capitalisationMode.rawValue,
                spaceBeforeOutput: chord.spaceBeforeOutputMode.rawValue,
                deleted: chord.deleted ? true : nil
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
            migrationVersion: migrationVersion,
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
        } catch {
            gDebugPrint("ERROR \(error)")
            SettingsAlerts.showSettingsSaveFailure(error.localizedDescription)
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
                SettingsAlerts.showSettingsLoadFailure(error.localizedDescription)
            }
        }

        let settingsFileChanged = SettingsMigration.run(on: self)
        reloadUsageFromStatsDirectory()
        recalculateAlphabeticalMapping()

        suppressWritingToFile = false
        if settingsFileChanged {
            setMigrationVersion(SettingsMigration.currentMigrationVersion)
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
            if let result = dialog.url {
                updateSettingsLocation(newLocation: result)
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
        statsWriteWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isDirty,
                  self.initialisationComplete,
                  !self.suppressWritingToFile else {
                return
            }
            self.writeLocalMachineStatsFile()
            self.clearDirty()
        }
        statsWriteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
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
    var migrationVersion: Int?
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
    var deleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case input
        case output
        case capitalisationMode
        case spaceBeforeOutput
        case deleted
    }

    init(
        id: String,
        input: String,
        output: String,
        capitalisationMode: String?,
        spaceBeforeOutput: String? = nil,
        deleted: Bool? = nil
    ) {
        self.id = id
        self.input = input
        self.output = output
        self.capitalisationMode = capitalisationMode
        self.spaceBeforeOutput = spaceBeforeOutput
        self.deleted = deleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        input = try container.decode(String.self, forKey: .input)
        output = try container.decode(String.self, forKey: .output)
        capitalisationMode = try container.decodeIfPresent(String.self, forKey: .capitalisationMode)
        spaceBeforeOutput = try container.decodeIfPresent(String.self, forKey: .spaceBeforeOutput)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(input, forKey: .input)
        try container.encode(output, forKey: .output)
        try container.encodeIfPresent(capitalisationMode, forKey: .capitalisationMode)
        try container.encodeIfPresent(spaceBeforeOutput, forKey: .spaceBeforeOutput)
        if deleted == true {
            try container.encode(true, forKey: .deleted)
        }
    }
}

enum SettingsAlerts {
    static func showSettingsLoadFailure(_ message: String) {
        present(
            title: "Could not load settings",
            message: message,
            style: .warning
        )
    }

    static func showSettingsSaveFailure(_ message: String) {
        present(
            title: "Could not save settings",
            message: message,
            style: .warning
        )
    }

    private static func present(title: String, message: String, style: NSAlert.Style) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            gDebugPrint("Settings alert suppressed during tests: \(title) — \(message)")
            return
        }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
