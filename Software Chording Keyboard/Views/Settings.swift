//
//  Settings.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 05/04/2023.
//

import SwiftUI

struct SettingsView: View {
    var delegate: AppDelegate = NSApp.delegate as! AppDelegate
    @ObservedObject var appModel: AppModel
    @State private var selectedChords = Set<Chord.ID>()
    @State private var creatingChord = false
    @State private var newChordInput = ""
    @State private var newChordOutput = ""


    init(appModel: AppModel) {
        self.appModel = appModel
    }

    var body: some View {
        ZStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 40) {
                // Statistics
                // Chords
                VStack(alignment: .leading) {
                    Text("Chords").font(.headline)
                    VStack(alignment: .leading, spacing: 0) {
                        Table(appModel.appSettings.chords, selection: $selectedChords) {
                            TableColumn("Input combination", value: \.input)
                            TableColumn("Output", value: \.output)
                        }
                        HStack(spacing:0) {
                            Button(action: {
                                creatingChord = true
                            }) {
                                Text("+").font(.title2)
                            }.buttonStyle(.borderless).frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                            Button(action: {
                                appModel.appSettings.removeChords(chords: selectedChords)
                                selectedChords.removeAll()
                            }) {
                                Text("-").font(.title2)
                            }.buttonStyle(.borderless).frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20).disabled(selectedChords.isEmpty)
                            Spacer()
                        }.padding(.horizontal, 8).padding(.vertical, 4).frame(minWidth: 10, maxWidth: .infinity).background(.background)
                    }.cornerRadius(6)
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
                    }
                }
                // Configuration
                VStack(alignment: .leading) {
                    Text("Configuration").font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Settings backup location")
                            Text("Choose a place for settings to be backed up inside a Cloud folder (eg iCloud/Dropbox to ensure they’re never lost!").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            delegate.appModel.appSettings.chooseBackupSettingsFileLocation()
                        }) {
                            Text("Choose backup location").font(Font.caption)
                        }
                    }
                }
                // Contact
            }.padding(.all, 8).padding(.bottom, 20).blur(radius: creatingChord ? 50 : 0.0)
            if(creatingChord) {
                VStack(alignment: .leading) {
                    Text("New chord").font(.headline)
                    Text("Chord input")
                    TextField("Chord input", text: $newChordInput)
                    Text("Chord output")
                    TextField("Chord output", text: $newChordOutput)
                    Text("Tip: Put a | (pipe) character inside the chord output to place the cursor there after replacement is done.\nIf you want the output text to contain a | (pipe) then escape it by entering a backslash before: \\" + "|").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Spacer()
                        Button(action: {
                            creatingChord = false
                            newChordInput = ""
                            newChordOutput = ""
                        }) {
                            Text("Cancel").font(Font.caption)
                        }
                        Button(action: {
                            creatingChord = false
                            appModel.appSettings.addChord(chord: Chord(input: newChordInput, output: newChordOutput))
                            newChordInput = ""
                            newChordOutput = ""
                        }) {
                            Text("Save").font(Font.caption)
                        }
                    }
                }.padding(20).background(.background).cornerRadius(6).padding(20).frame(maxWidth: 340)
            }
        }.frame(minWidth: 400, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity, alignment: .center)
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appModel: AppModel())
    }
}


