//
//  Settings.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 05/04/2023.
//

import SwiftUI
import LaunchAtLogin

private extension Font {
    static let settingsSecondary = Font.callout
    static let settingsHint = Font.footnote
}

private enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    case chords
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chords:
            return "Chords"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chords:
            return "list.bullet.rectangle"
        case .settings:
            return "gearshape"
        }
    }
}

private enum ChordEditorContext: Identifiable {
    case create
    case edit(Chord.ID)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let chordID):
            return "edit-\(chordID)"
        }
    }

    var title: String {
        switch self {
        case .create:
            return "New chord"
        case .edit:
            return "Edit chord"
        }
    }
}

private struct ChordEditorSheet: View {
    let context: ChordEditorContext
    @Binding var input: String
    @Binding var output: String
    @Binding var capitalisationMode: ChordCapitalisationMode
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showOutputTips = false

    private enum Field {
        case input
        case output
    }

    private var tipText: String {
        "Put a | (pipe) character inside the chord output to place the cursor there after replacement is done.\n\nIf you want the output text to contain a | (pipe) instead of moving the cursor there, escape it with a backslash: \\|\n\nUse {{date}} placeholders for the current date/time, for example {{yyyy}}, {{MM/dd/yyyy}}, or {{HH:mm}}. Tokens follow Apple's ICU date patterns (e.g. d and dd for day of month, E for weekday; yyyy for calendar year). A lone {{YYYY}} is treated as calendar year."
    }

    private var outputTipsButton: some View {
        Button {
            showOutputTips.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Output tips")
        .accessibilityLabel("Show output tips")
        .popover(isPresented: $showOutputTips, arrowEdge: .bottom) {
            ScrollView {
                Text(tipText)
                    .font(.settingsHint)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 320, alignment: .leading)
            .padding()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(context.title)
                .font(.headline)

            Form {
                TextField("Chord input", text: $input)
                    .focused($focusedField, equals: .input)
                LabeledContent {
                    TextField("", text: $output)
                        .focused($focusedField, equals: .output)
                } label: {
                    HStack(spacing: 4) {
                        Text("Chord output")
                        outputTipsButton
                    }
                }
                Picker("Capitalisation", selection: $capitalisationMode) {
                    ForEach(ChordCapitalisationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, -20)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedField = .input
        }
        .onExitCommand {
            onCancel()
        }
    }
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
    @State private var selectedSidebarItem: SettingsSidebarItem? = .chords

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

    private func backupLocationDisplayName(for directory: URL) -> String {
        let path = directory.path
        if path.contains("com~apple~CloudDocs") {
            return "iCloud Drive/\(directory.lastPathComponent)"
        }
        let abbreviated = (path as NSString).abbreviatingWithTildeInPath
        if abbreviated.count <= 36 {
            return abbreviated
        }
        return "~/…/\(directory.lastPathComponent)"
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
                .font(.settingsSecondary)
                .foregroundColor(.secondary)
                .environment(\.openURL, OpenURLAction { _ in
                    revealSettingsFileInFinder()
                    return .handled
                })
        } else {
            Text(plain)
                .font(.settingsSecondary)
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
        NavigationSplitView {
            List(SettingsSidebarItem.allCases, selection: $selectedSidebarItem) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                switch selectedSidebarItem {
                case .chords:
                    chordsPanel
                case .settings:
                    generalSettingsPanel
                case .none:
                    VStack(spacing: 12) {
                        Image(systemName: "sidebar.left")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Select a section")
                            .font(.headline)
                        Text("Choose Chords or Settings from the sidebar.")
                            .font(.settingsSecondary)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: 720,
            idealWidth: 960,
            maxWidth: .infinity,
            minHeight: 500,
            idealHeight: 720,
            maxHeight: .infinity
        )
        .sheet(item: $chordEditorContext) { context in
            ChordEditorSheet(
                context: context,
                input: $chordFormInput,
                output: $chordFormOutput,
                capitalisationMode: $chordFormCapitalisationMode,
                onSave: saveChordEditor,
                onCancel: dismissChordEditor
            )
        }
    }

    private var chordsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showFilterInput {
                HStack {
                    TextField("Filter chords...", text: $filterString)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFilterInput = false
                            filterString = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 0) {
                Table(filteredChords, selection: $selectedChords, sortOrder: $sortOrder) {
                    TableColumn("Input combination", value: \.input)
                    TableColumn("Output", value: \.output)
                    TableColumn("Capitalisation") { chord in
                        Text(chord.capitalisationMode.tableLabel)
                    }
                            TableColumn("Usage", value: \.usageCountForSorting) { chord in
                                Text(chord.totalUsageCount == 0 ? "-" : String(chord.totalUsageCount))
                            }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: sortOrder) { newSortOrder in
                    if let newComparator = newSortOrder.first,
                       newComparator.keyPath == \Chord.usageCountForSorting,
                       newComparator.order == .forward {
                        let wasUsageSorted = previousSortOrder.first?.keyPath == \Chord.usageCountForSorting
                        if !wasUsageSorted {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sortOrder = [KeyPathComparator(\Chord.usageCountForSorting, order: .reverse)]
                            }
                        }
                    }
                    previousSortOrder = newSortOrder
                }

                HStack(spacing: 0) {
                    Button(action: openCreateChordEditor) {
                        Text("+").font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                    Button(action: {
                        appModel.appSettings.removeChords(chords: selectedChords)
                        selectedChords.removeAll()
                    }) {
                        Text("-").font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                    .disabled(selectedChords.isEmpty)
                    Button(action: editSelectedChord) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                    .disabled(selectedChords.count != 1)
                    .accessibilityLabel("Edit")
                    .help("Edit")
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(.background)
            }
            .cornerRadius(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            configFileEditTip
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Chords")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilterInput.toggle()
                        if !showFilterInput {
                            filterString = ""
                        }
                    }
                }) {
                    Image(systemName: showFilterInput ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter chords")
                .help("Filter chords")
            }

            if hasCustomSorting {
                ToolbarItem(placement: .automatic) {
                    Button("Reset sorting") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortOrder = []
                            previousSortOrder = []
                        }
                    }
                    .help("Reset table sorting")
                }
            }
        }
    }

    private func settingsRowLabel(title: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(hint)
                .font(.settingsHint)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var generalSettingsPanel: some View {
        Form {
            Section {
                LabeledContent {
                    TextField("", text: $appModel.appSettings.millisecondsToHoldStr)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Milliseconds")
                } label: {
                    settingsRowLabel(
                        title: "Chord hold delay",
                        hint: "Must be smaller than the key repeat delay in your system settings, otherwise chords will not work properly."
                    )
                }
                Toggle(isOn: $appModel.appSettings.useAccessibilityAPI) {
                    settingsRowLabel(
                        title: "Use Accessibility API for replacement",
                        hint: "When enabled, chords are replaced by directly editing the focused text field via the Accessibility API — no synthetic key events are posted. Falls back to keystroke simulation automatically for apps that don't support it (eg Electron apps, and Terminal)."
                    )
                }
            } header: {
                Text("Input")
            }

            Section {
                Toggle(isOn: $isChecked) {
                    settingsRowLabel(
                        title: "Launch at log in",
                        hint: "Automatically start this app when you login so that you're always ready to get chording!"
                    )
                }
                .onChange(of: isChecked) { value in
                    LaunchAtLogin.isEnabled = value
                }

                LabeledContent {
                    HStack(spacing: 12) {
                        if let backupLocation = appModel.appSettings.settingsFileDirectory {
                            Button(action: revealSettingsFileInFinder) {
                                Text(backupLocationDisplayName(for: backupLocation))
                            }
                            .buttonStyle(.link)

                            Button("Change…") {
                                delegate.appModel.appSettings.chooseBackupSettingsFileLocation()
                            }
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                            Button("Choose…") {
                                delegate.appModel.appSettings.chooseBackupSettingsFileLocation()
                            }
                        }
                    }
                } label: {
                    settingsRowLabel(
                        title: "Backup location",
                        hint: "Choose a place for settings to be backed up inside a Cloud folder (eg iCloud/Dropbox) to ensure they're never lost."
                    )
                }
            } header: {
                Text("Configuration")
            }



            Section {
                permissionRow(
                    title: "Input monitoring",
                    hasPermission: delegate.hasInputMonitoringPermission(),
                    grantAction: {
                        delegate.requestInputMonitoringPermission()
                        delegate.openInputMonitoringSettings()
                    },
                    openSettingsAction: delegate.openInputMonitoringSettings
                )

                permissionRow(
                    title: "Accessibility",
                    hasPermission: delegate.hasAccessibilityPermission(),
                    grantAction: {
                        delegate.requestAccessibilityPermission()
                        delegate.openAccessibilitySettings()
                    },
                    openSettingsAction: delegate.openAccessibilitySettings
                )
            } header: {
                Text("Permissions")
                Text("For \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "this app") to work, it needs permission to monitor your keyboard and type for you.")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func permissionRow(
        title: String,
        hasPermission: Bool,
        grantAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Text(hasPermission ? "OK" : "Lacking permissions")
                .font(.settingsSecondary)
                .foregroundColor(hasPermission ? .green : .red)
            Spacer()
            if !hasPermission {
                Button("Grant permission", action: grantAction)
            }
            Button("Open settings", action: openSettingsAction)
        }
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appModel: AppModel())
    }
}


