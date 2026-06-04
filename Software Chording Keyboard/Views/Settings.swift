//
//  Settings.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 05/04/2023.
//

import SwiftUI
import LaunchAtLogin

private enum ChordEditorContext {
    case create
    case edit(Chord.ID)
}

struct SettingsView: View {
    var delegate: AppDelegate = NSApp.delegate as! AppDelegate
    @ObservedObject var appModel: AppModel
    @State private var selectedChords = Set<Chord.ID>()
    @State private var chordEditorContext: ChordEditorContext?
    @State private var chordFormInput = ""
    @State private var chordFormOutput = ""
    @State private var chordFormCapitalisationMode: ChordCapitalisationMode = .default
    @State private var isChecked = false
    @State private var showFilterInput = false
    @State private var filterString = ""
    @State private var sortOrder: [KeyPathComparator<Chord>] = []
    @State private var previousSortOrder: [KeyPathComparator<Chord>] = []


    init(appModel: AppModel) {
        self.appModel = appModel
    }

    // Computed property to check if custom sorting is active
    private var hasCustomSorting: Bool {
        return !sortOrder.isEmpty
    }

    var filteredChords: [Chord] {
        var chords = appModel.appSettings.chords

        // Apply filtering
        if !filterString.isEmpty {
            let filterText = filterString.lowercased()
            chords = chords.filter { chord in
                // Check if output contains the filter text
                let outputMatches = chord.output.lowercased().contains(filterText)

                // Check if input (sorted alphabetically) matches the filter (sorted alphabetically)
                let sortedInput = String(chord.input.lowercased().sorted())
                let sortedFilter = String(filterText.sorted())
                let inputMatches = sortedInput.contains(sortedFilter)

                return outputMatches || inputMatches
            }
        }

        // Apply sorting based on sortOrder
        if !sortOrder.isEmpty {
            chords.sort(using: sortOrder)
        }

        return chords
    }

    private var isChordEditorPresented: Bool {
        chordEditorContext != nil
    }

    private var chordEditorTitle: String {
        switch chordEditorContext {
        case .create, nil:
            return "New chord"
        case .edit:
            return "Edit chord"
        }
    }

    private func openCreateChordEditor() {
        chordFormInput = ""
        chordFormOutput = ""
        chordFormCapitalisationMode = .default
        chordEditorContext = .create
    }

    private func openEditChordEditor(for id: Chord.ID) {
        guard let chord = appModel.appSettings.chords.first(where: { $0.id == id }) else {
            return
        }
        selectedChords = [id]
        chordFormInput = chord.input
        chordFormOutput = chord.output
        chordFormCapitalisationMode = chord.capitalisationMode
        chordEditorContext = .edit(id)
    }

    private func editSelectedChord() {
        guard let id = selectedChords.first, selectedChords.count == 1 else {
            return
        }
        openEditChordEditor(for: id)
    }

    private func dismissChordEditor() {
        chordEditorContext = nil
        chordFormInput = ""
        chordFormOutput = ""
        chordFormCapitalisationMode = .default
    }

    private func revealSettingsFileInFinder() {
        guard let directory = appModel.appSettings.settingsFileDirectory else {
            return
        }
        let settingsFilePath = appModel.appSettings.settingsFileLocation.path
        NSWorkspace.shared.selectFile(settingsFilePath, inFileViewerRootedAtPath: directory.path)
    }

    private func attributedConfigFileEditTip(plain: String, backupLocation: URL) -> AttributedString {
        var attributed = AttributedString(plain)
        if let range = attributed.range(of: "your config") {
            attributed[range].link = backupLocation
            attributed[range].foregroundColor = .accentColor
            attributed[range].underlineStyle = .single
        }
        return attributed
    }

    @ViewBuilder
    private var configFileEditTip: some View {
        let plain = "💡 Tip: If you want to make lots of changes, you can edit your config file directly then reload the app. Just be careful! It's worth creating a backup of your config file first!"
        if let backupLocation = appModel.appSettings.settingsFileDirectory {
            Text(attributedConfigFileEditTip(plain: plain, backupLocation: backupLocation))
                .font(.caption)
                .foregroundColor(.secondary)
                .environment(\.openURL, OpenURLAction { _ in
                    revealSettingsFileInFinder()
                    return .handled
                })
        } else {
            Text(plain)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func saveChordEditor() {
        switch chordEditorContext {
        case .create:
            appModel.appSettings.addChord(chord: Chord(
                input: chordFormInput,
                output: chordFormOutput,
                capitalisationMode: chordFormCapitalisationMode
            ))
        case .edit(let id):
            appModel.appSettings.updateChord(
                id: id,
                input: chordFormInput,
                output: chordFormOutput,
                capitalisationMode: chordFormCapitalisationMode
            )
        case nil:
            return
        }
        dismissChordEditor()
    }

    var body: some View {
        ZStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 40) {
                // TODO: Statistics

                // Chords
                VStack(alignment: .leading) {
                    // Title and Filter UI on same line
                    HStack {
                        Text("Chords").font(.headline)

                        Spacer()

                        if showFilterInput {
                            TextField("Filter chords...", text: $filterString)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }


                        // We can add esc and cmd+f keyboard shortcuts to toggle the filter input
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFilterInput.toggle()
                                if !showFilterInput {
                                    filterString = ""
                                }
                            }
                        }) {
                            Image(systemName: showFilterInput ? "xmark.circle" : "line.3.horizontal.decrease.circle")
                                .foregroundColor(showFilterInput ? .accentColor : .secondary)
                        }.padding(.leading, 4)
                            .buttonStyle(.plain)
                            .accessibilityLabel("filter")
                            .help("Filter chords")

                        // Reset sorting button - shown when custom sorting is active
                        if hasCustomSorting {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    sortOrder = []
                                    previousSortOrder = []
                                }
                            }) {
                                Text("Reset sorting")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Reset table sorting")
                            .padding(.leading, 4)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(minHeight: 22)
                    .padding(.bottom, 4)



                    VStack(alignment: .leading, spacing: 0) {
                        Table(filteredChords, selection: $selectedChords, sortOrder: $sortOrder) {
                            TableColumn("Input combination", value: \.input)
                            TableColumn("Output", value: \.output)
                            TableColumn("Capitalisation") { chord in
                                Text(chord.capitalisationMode.tableLabel)
                            }
                            TableColumn("Usage", value: \.usageCountForSorting) { chord in
                                Text(chord.usageCount == nil || chord.usageCount == 0 ? "-" : String(chord.usageCount!))
                            }
                        }
                        .onChange(of: sortOrder) { newSortOrder in
                            // Handle special case: first click on Usage should cause sorting in descending (high to low) order
                            if let newComparator = newSortOrder.first,
                               newComparator.keyPath == \Chord.usageCountForSorting,
                               newComparator.order == .forward {
                                // Check if we're switching from no sort or different column to Usage
                                let wasUsageSorted = previousSortOrder.first?.keyPath == \Chord.usageCountForSorting
                                if !wasUsageSorted {
                                    // Override to descending for first Usage click
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        sortOrder = [KeyPathComparator(\Chord.usageCountForSorting, order: .reverse)]
                                    }
                                }
                            }
                            // Update previous sort order for next time
                            previousSortOrder = newSortOrder
                        }
                        HStack(spacing:0) {
                            Button(action: openCreateChordEditor) {
                                Text("+").font(.title2)
                            }.buttonStyle(.borderless).frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                            Button(action: {
                                appModel.appSettings.removeChords(chords: selectedChords)
                                selectedChords.removeAll()
                            }) {
                                Text("-").font(.title2)
                            }.buttonStyle(.borderless).frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20).disabled(selectedChords.isEmpty)
                            Button(action: editSelectedChord) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                            .disabled(selectedChords.count != 1)
                            .accessibilityLabel("Edit")
                            .help("Edit")
                            Spacer()
                        }.padding(.horizontal, 8).padding(.vertical, 4).frame(minWidth: 10, maxWidth: .infinity).background(.background)
                    }.cornerRadius(8)
                    configFileEditTip
                }

                // Input
                VStack(alignment: .leading) {
                    Text("Input").font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Chord hold delay")
                            Text("Note they delay in ms must be smaller than the key repeat delay in your system settings, otherwise the chords will not work properly.").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        TextField("Chord hold delay", text: $appModel.appSettings.millisecondsToHoldStr).textFieldStyle(.plain).padding(.vertical, 6).padding(.horizontal, 4).background(.background).cornerRadius(6).frame(maxWidth: 60).multilineTextAlignment(.center)
                    }.padding(.bottom, 8)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Use Accessibility API for replacement")
                            Text("When enabled, chords are replaced by directly editing the focused text field via the Accessibility API — no synthetic key events are posted. Falls back to keystroke simulation automatically for apps that don't support it (eg Electron apps, and Terminal).").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle(isOn: $appModel.appSettings.useAccessibilityAPI) {}.toggleStyle(.switch)
                    }
                }

                // Configuration
                VStack(alignment: .leading) {
                    Text("Configuration").font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Launch at log in")
                            Text("Automatically start this app when you login so that you're always ready to get chording!").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle(isOn: $isChecked) {}.toggleStyle(.switch).onChange(of: isChecked){ value in
                            LaunchAtLogin.isEnabled = value
                        }
                    }.padding(.bottom, 8)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Settings backup location")
                            Text("Choose a place for settings to be backed up inside a Cloud folder (eg iCloud/Dropbox to ensure they're never lost!").font(.caption).foregroundColor(.secondary)

                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Spacer()
                        Button(action: {
                            delegate.appModel.appSettings.chooseBackupSettingsFileLocation()
                        }) {
                            Text(appModel.appSettings.settingsFileDirectory != nil ? "Change backup location" : "Choose backup location").font(Font.caption)
                        }

                    }
                    if let backupLocation = appModel.appSettings.settingsFileDirectory {
                        Button(action: revealSettingsFileInFinder) {
                            Text("Current location: \(backupLocation.path)")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)

                    }
                }

                // Permissions
                VStack(alignment: .leading) {
                    Text("Permissions").font(.headline)
                    Text("For \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "this app") to work, it needs permission to monitor your keyboard and type for you.").font(.caption).foregroundColor(.secondary).padding(.bottom, 8)

                    // Input Monitoring
                    HStack {
                        HStack {
                            Text("Input monitoring")
                            Text(delegate.hasInputMonitoringPermission() ? "OK" : "Lacking permissions").font(.caption).foregroundColor(delegate.hasInputMonitoringPermission() ? .green : .red)
                        }
                        Spacer()
                        if !delegate.hasInputMonitoringPermission() {
                            Button(action: {
                                delegate.requestInputMonitoringPermission()
                                delegate.openInputMonitoringSettings()
                            }) {
                                Text("Grant permission").font(Font.caption)
                            }
                        }
                        Button(action: {
                            delegate.openInputMonitoringSettings()
                        }) {
                            Text("Open settings").font(Font.caption)
                        }
                    }.padding(.bottom, 8)

                    // Accessibility
                    HStack {
                        HStack {
                            Text("Accessibility")
                            Text(delegate.hasAccessibilityPermission() ? "OK" : "Lacking permissions").font(.caption).foregroundColor(delegate.hasAccessibilityPermission() ? .green : .red)
                        }
                        Spacer()
                        if !delegate.hasAccessibilityPermission() {
                            Button(action: {
                                delegate.requestAccessibilityPermission()
                                delegate.openAccessibilitySettings()
                            }) {
                                Text("Grant permission").font(Font.caption)
                            }
                        }
                        Button(action: {
                            delegate.openAccessibilitySettings()
                        }) {
                            Text("Open settings").font(Font.caption)
                        }
                    }
                }
            }.padding(.all, 8).padding(.bottom, 20).blur(radius: isChordEditorPresented ? 50 : 0.0)

            if isChordEditorPresented {
                VStack(alignment: .leading) {
                    Text(chordEditorTitle).font(.headline).padding(.bottom,8)
                    Text("Chord input")
                    TextField("Chord input", text: $chordFormInput).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary, lineWidth: 0.1)).padding(.bottom,8)
                    Text("Chord output")
                    TextField("Chord output", text: $chordFormOutput).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary, lineWidth: 0.1)).padding(.bottom,8)
                    Picker("Capitalisation", selection: $chordFormCapitalisationMode) {
                        ForEach(ChordCapitalisationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.bottom, 8)
                    Text("Tip: Put a | (pipe) character inside the chord output to place the cursor there after replacement is done.\nIf you want the output text to contain a | (pipe) instead of moving the cursor there, then escape it by entering a backslash before: \\" + "|" + "\nUse {{date}} placeholders for the current date/time, for example {{yyyy}}, {{MM/dd/yyyy}}, or {{HH:mm}}. Tokens follow Apple’s ICU date patterns (e.g. d and dd for day of month, E for weekday; yyyy for calendar year). A lone {{YYYY}} is treated as calendar year.").font(.caption).foregroundColor(.secondary).padding(.bottom,8)
                    HStack {
                        Spacer()
                        Button(action: dismissChordEditor) {
                            Text("Cancel").font(Font.caption)
                        }
                        Button(action: saveChordEditor) {
                            Text("Save").font(Font.caption)
                        }
                    }
                }.padding(20).background(.background).cornerRadius(6).padding(20).frame(maxWidth: 340)
            }
        }.frame(minWidth: 640, maxWidth: .infinity, minHeight: 800, maxHeight: .infinity, alignment: .center)

    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appModel: AppModel())
    }
}


