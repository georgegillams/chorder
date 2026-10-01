//
//  Settings.swift
//  Chorder
//
//  Created by George Gillams on 05/04/2023.
//

import AppKit
import SwiftUI
import LaunchAtLogin

extension Font {
    static let settingsSecondary = Font.callout
    static let settingsHint = Font.footnote
}

/// Permission and system actions required by the settings UI.
protocol SettingsActions {
    func hasInputMonitoringPermission() -> Bool
    func requestInputMonitoringPermission()
    func openInputMonitoringSettings()
    func hasAccessibilityPermission() -> Bool
    func requestAccessibilityPermission()
    func openAccessibilitySettings()
    func openFeedback()
}

private enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    case chords
    case practice
    case stats
    case help
    case settings
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chords:
            return "Chords"
        case .practice:
            return "Practice"
        case .stats:
            return "Stats"
        case .help:
            return "How to use"
        case .settings:
            return "Settings"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .chords:
            return "list.bullet.rectangle"
        case .practice:
            return "repeat.circle"
        case .stats:
            return "chart.bar"
        case .help:
            return "questionmark.circle"
        case .settings:
            return "gearshape"
        case .about:
            return "info.circle"
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
    @Binding var spaceBeforeOutputMode: ChordSpaceBeforeOutputMode
    @Binding var spaceAfterOutputMode: ChordSpaceAfterOutputMode
    @Binding var showInputConflictConfirmation: Bool
    let inputConflictTitle: String
    let inputConflictMessage: String
    let onSave: () -> Void
    let onReplaceConflict: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showOutputTips = false

    private enum Field {
        case input
        case output
    }

    private var canSave: Bool {
        input.count >= 2
            && !output.isEmpty
            && Chord.isValidOutput(output)
            && !Chord.hasDuplicateInputLetters(input)
    }

    private var inputValidationMessage: String? {
        if Chord.hasDuplicateInputLetters(input) {
            return "Each letter in the input must be a different key (duplicate letters cannot be held together)."
        }
        guard !input.isEmpty, input.count < 2 else {
            return nil
        }
        return "Input must be at least 2 characters (chords use simultaneous key holds)."
    }

    private var outputValidationMessage: String? {
        if output.isEmpty {
            return nil
        }
        guard !Chord.isValidOutput(output) else {
            return nil
        }
        return "Output can contain at most one | (pipe) for cursor placement. Escape extra pipes with \\|."
    }

    private var tipText: String {
        "Put a | (pipe) character inside the chord output to place the cursor there after replacement is done.\n\nIf you want the output text to contain a | (pipe) instead of moving the cursor there, escape it with a backslash: \\|\n\nUse {{date}} placeholders for the current date/time, for example {{yyyy}}, {{MM/dd/yyyy}}, or {{HH:mm}}. Tokens follow Apple's ICU date patterns (e.g. d and dd for day of month, E for weekday; yyyy for calendar year). A lone {{YYYY}} is treated as calendar year.\n\nUse {{uuid}} or {{UUID}} for a random UUID (lowercase or uppercase)."
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
            VStack(alignment: .leading, spacing: 6) {
                Text(context.title)
                    .font(.headline)

                if case .create = context {
                    Text("💡 Tip: Hold option (⌥) and click the menu item to quickly add a new chord")
                        .font(.settingsSecondary)
                        .foregroundColor(.secondary)
                }
            }

            Form {
                TextField("Chord input", text: $input)
                    .focused($focusedField, equals: .input)
                if let inputValidationMessage {
                    Text(inputValidationMessage)
                        .font(.settingsHint)
                        .foregroundColor(.red)
                }
                LabeledContent {
                    TextField("", text: $output)
                        .focused($focusedField, equals: .output)
                } label: {
                    HStack(spacing: 4) {
                        Text("Chord output")
                        outputTipsButton
                    }
                }
                if let outputValidationMessage {
                    Text(outputValidationMessage)
                        .font(.settingsHint)
                        .foregroundColor(.red)
                }
                Picker("Capitalisation", selection: $capitalisationMode) {
                    ForEach(ChordCapitalisationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Picker("Space before output", selection: $spaceBeforeOutputMode) {
                    ForEach(ChordSpaceBeforeOutputMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Picker("Space after output", selection: $spaceAfterOutputMode) {
                    ForEach(ChordSpaceAfterOutputMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            .formStyle(.grouped)
            .defaultFocus($focusedField, .input)
            .padding(.horizontal, -20)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!canSave)
                    .confirmationDialog(
                        inputConflictTitle,
                        isPresented: $showInputConflictConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Replace", action: onReplaceConflict)
                    } message: {
                        Text(inputConflictMessage)
                    }
            }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .input
            }
        }
        .onExitCommand {
            onCancel()
        }
    }
}

private struct ChordOptionsCell: View {
    @ObservedObject var chord: Chord

    var body: some View {
        HStack(spacing: 6) {
            if let symbol = chord.capitalisationMode.optionsSymbolName,
               let tooltip = chord.capitalisationMode.optionsTooltip {
                Image(systemName: symbol)
                    .help(tooltip)
                    .accessibilityLabel(tooltip)
            }
            if let symbol = chord.spaceBeforeOutputMode.optionsSymbolName,
               let tooltip = chord.spaceBeforeOutputMode.optionsTooltip {
                Image(systemName: symbol)
                    .help(tooltip)
                    .accessibilityLabel(tooltip)
            }
            if let symbol = chord.spaceAfterOutputMode.optionsSymbolName,
               let tooltip = chord.spaceAfterOutputMode.optionsTooltip {
                Image(systemName: symbol)
                    .help(tooltip)
                    .accessibilityLabel(tooltip)
            }
        }
        .font(.caption)
    }
}

private struct ChordInputCombinationCell: View {
    let input: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(input.enumerated()), id: \.offset) { index, character in
                if index > 0 {
                    Text("+")
                        .opacity(0.7)
                }
                Text(String(character))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(minWidth: 24, minHeight: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.35))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(input)
    }
}

/// Observes double-clicks on the underlying `NSTableView` without intercepting single clicks.
private struct TableDoubleClickHandler: NSViewRepresentable {
    let onDoubleClick: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDoubleClick: onDoubleClick)
    }

    func makeNSView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: InstallerView, context: Context) {
        context.coordinator.onDoubleClick = onDoubleClick
        nsView.coordinator = context.coordinator
        nsView.installIfNeeded()
    }

    static func dismantleNSView(_ nsView: InstallerView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        var onDoubleClick: (Int) -> Void
        private var monitor: Any?
        private weak var tableView: NSTableView?

        init(onDoubleClick: @escaping (Int) -> Void) {
            self.onDoubleClick = onDoubleClick
        }

        func startMonitoring(tableView: NSTableView) {
            guard self.tableView !== tableView else {
                return
            }
            stopMonitoring()
            self.tableView = tableView
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, let tableView = self.tableView else {
                    return event
                }
                guard event.clickCount == 2, event.window === tableView.window else {
                    return event
                }
                let point = tableView.convert(event.locationInWindow, from: nil)
                guard tableView.bounds.contains(point) else {
                    return event
                }
                let row = tableView.row(at: point)
                guard row >= 0 else {
                    return event
                }
                self.onDoubleClick(row)
                return event
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            tableView = nil
        }

        deinit {
            stopMonitoring()
        }
    }

    final class InstallerView: NSView {
        weak var coordinator: Coordinator?
        private weak var installedTableView: NSTableView?
        private var installAttempts = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installIfNeeded()
        }

        func installIfNeeded() {
            guard installedTableView == nil, let coordinator else {
                return
            }
            guard installAttempts < 20 else {
                return
            }
            installAttempts += 1

            guard let tableView = findTableView() else {
                DispatchQueue.main.async { [weak self] in
                    self?.installIfNeeded()
                }
                return
            }

            installedTableView = tableView
            coordinator.startMonitoring(tableView: tableView)
        }

        private func findTableView() -> NSTableView? {
            var current: NSView? = self
            while let view = current {
                if let tableView = searchForTableView(in: view) {
                    return tableView
                }
                current = view.superview
            }
            return nil
        }

        private func searchForTableView(in view: NSView) -> NSTableView? {
            if let tableView = view as? NSTableView {
                return tableView
            }
            for subview in view.subviews {
                if let tableView = searchForTableView(in: subview) {
                    return tableView
                }
            }
            return nil
        }
    }
}

struct SettingsView: View {
    let settingsActions: SettingsActions
    @ObservedObject var appModel: AppModel
    @State private var selectedChords = Set<Chord.ID>()
    @State private var chordEditorContext: ChordEditorContext?
    @State private var chordFormInput = ""
    @State private var chordFormOutput = ""
    @State private var chordFormCapitalisationMode: ChordCapitalisationMode = .default
    @State private var chordFormSpaceBeforeOutputMode: ChordSpaceBeforeOutputMode = .default
    @State private var chordFormSpaceAfterOutputMode: ChordSpaceAfterOutputMode = .default
    @State private var isChecked = false
    @State private var showFilterInput = false
    @State private var filterString = ""
    @FocusState private var isFilterFieldFocused: Bool
    @State private var sortOrder: [KeyPathComparator<Chord>] = []
    @State private var previousSortOrder: [KeyPathComparator<Chord>] = []
    @State private var selectedSidebarItem: SettingsSidebarItem = .chords
    @State private var showDeleteChordsConfirmation = false
    @State private var showChordInputConflictConfirmation = false
    @State private var conflictingChordForSave: Chord?
    private let openCreateChordOnAppear: Bool

    init(appModel: AppModel, settingsActions: SettingsActions, openCreateChordOnAppear: Bool = false) {
        self.appModel = appModel
        self.settingsActions = settingsActions
        self.openCreateChordOnAppear = openCreateChordOnAppear
    }

    private var millisecondsToHoldStrBinding: Binding<String> {
        Binding(
            get: { appModel.appSettings.millisecondsToHoldStr },
            set: { appModel.appSettings.millisecondsToHoldStr = $0 }
        )
    }

    private var useAccessibilityAPIBinding: Binding<Bool> {
        Binding(
            get: { appModel.appSettings.useAccessibilityAPI },
            set: { appModel.appSettings.useAccessibilityAPI = $0 }
        )
    }

    // Computed property to check if custom sorting is active
    private var hasCustomSorting: Bool {
        return !sortOrder.isEmpty
    }

    var filteredChords: [Chord] {
        var chords = appModel.appSettings.activeChords

        // Apply filtering
        if !filterString.isEmpty {
            let filterText = filterString.lowercased()
            chords = chords.filter { chord in
                // Check if output contains the filter text
                let outputMatches = chord.output.lowercased().contains(filterText)

                // Check if input (sorted alphabetically) matches the filter (sorted alphabetically)
                let sortedInput = Chord.normalisedInputKey(for: chord.input)
                let sortedFilter = Chord.normalisedInputKey(for: filterText)
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
        chordFormSpaceBeforeOutputMode = .default
        chordFormSpaceAfterOutputMode = .default
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
        chordFormSpaceBeforeOutputMode = chord.spaceBeforeOutputMode
        chordFormSpaceAfterOutputMode = chord.spaceAfterOutputMode
        chordEditorContext = .edit(id)
    }

    private func editSelectedChord() {
        guard let id = selectedChords.first, selectedChords.count == 1 else {
            return
        }
        openEditChordEditor(for: id)
    }

    private var deleteChordsConfirmationTitle: String {
        if selectedChords.count == 1,
           let chord = appModel.appSettings.chords.first(where: { selectedChords.contains($0.id) }) {
            return "Delete “\(chord.input) → \(chord.output)”?"
        }
        return "Delete \(selectedChords.count) chords?"
    }

    private var deleteChordsConfirmationMessage: String {
        if selectedChords.count == 1 {
            return "This chord will be removed from your configuration. This action cannot be undone."
        }
        return "These chords will be removed from your configuration. This action cannot be undone."
    }

    private func deleteSelectedChords() {
        appModel.appSettings.removeChords(chords: selectedChords)
        selectedChords.removeAll()
    }

    private func dismissChordEditor() {
        chordEditorContext = nil
        chordFormInput = ""
        chordFormOutput = ""
        chordFormCapitalisationMode = .default
        chordFormSpaceBeforeOutputMode = .default
        chordFormSpaceAfterOutputMode = .default
        conflictingChordForSave = nil
        showChordInputConflictConfirmation = false
    }

    private func revealSettingsFileInFinder() {
        guard let directory = appModel.appSettings.settingsFileDirectory else {
            return
        }
        let settingsFilePath = appModel.appSettings.settingsFileLocation.path
        NSWorkspace.shared.selectFile(settingsFilePath, inFileViewerRootedAtPath: directory.path)
    }

    private static let settingsTabURL = URL(string: "chording-keyboard://settings-tab")!
    private static let configFileURL = URL(string: "chording-keyboard://config-file")!

    private func handleSettingsViewLink(_ url: URL) -> OpenURLAction.Result {
        if url == Self.settingsTabURL {
            selectedSidebarItem = .settings
            return .handled
        }
        if url == Self.configFileURL {
            revealSettingsFileInFinder()
            return .handled
        }
        return .systemAction
    }

    private func linkOccurrences(in attributed: inout AttributedString, phrase: String, url: URL) {
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: phrase) {
            attributed[range].link = url
            attributed[range].foregroundColor = .accentColor
            attributed[range].underlineStyle = .single
            searchStart = range.upperBound
        }
    }

    private func attributedHint(_ plain: String, linkSettingsTab: Bool = false, linkConfigFile: Bool = false) -> AttributedString {
        var attributed = AttributedString(plain)
        if linkSettingsTab {
            if attributed.range(of: "Settings tab") != nil {
                linkOccurrences(in: &attributed, phrase: "Settings tab", url: Self.settingsTabURL)
            } else {
                linkOccurrences(in: &attributed, phrase: "Settings", url: Self.settingsTabURL)
            }
        }
        if linkConfigFile {
            linkOccurrences(in: &attributed, phrase: "config file", url: Self.configFileURL)
        }
        return attributed
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

    private func attributedConfigFileEditTip(plain: String) -> AttributedString {
        attributedHint(plain, linkConfigFile: true)
    }

    @ViewBuilder
    private var configFileEditTip: some View {
        let plain = "💡 Tip: If you want to make lots of changes, you can edit your config file directly then restart the app. Just be careful! It's worth creating a backup of your config file first!"
        if appModel.appSettings.settingsFileDirectory != nil {
            Text(attributedConfigFileEditTip(plain: plain))
                .font(.settingsSecondary)
                .foregroundColor(.secondary)
        } else {
            Text(plain)
                .font(.settingsSecondary)
                .foregroundColor(.secondary)
        }
    }

    private var chordEditorExcludingID: Chord.ID? {
        if case .edit(let id) = chordEditorContext {
            return id
        }
        return nil
    }

    private var chordInputConflictTitle: String {
        "Replace existing chord?"
    }

    private var chordInputConflictMessage: String {
        guard let conflict = conflictingChordForSave else {
            return ""
        }
        return "Another chord already uses this input combination (\(conflict.input) → \(conflict.output)). Replace it with what you entered, or cancel to keep editing."
    }

    private func conflictingChord(for input: String, excludingId: Chord.ID?) -> Chord? {
        let key = Chord.normalisedInputKey(for: input)
        guard !key.isEmpty else {
            return nil
        }
        return appModel.appSettings.activeChords.first { chord in
            if chord.id == excludingId {
                return false
            }
            return Chord.normalisedInputKey(for: chord.input) == key
        }
    }

    private func commitChordEditor(replacingExistingId existingId: Chord.ID?) {
        switch chordEditorContext {
        case .create:
            if let existingId {
                appModel.appSettings.updateChord(
                    id: existingId,
                    input: chordFormInput,
                    output: chordFormOutput,
                    capitalisationMode: chordFormCapitalisationMode,
                    spaceBeforeOutputMode: chordFormSpaceBeforeOutputMode,
                    spaceAfterOutputMode: chordFormSpaceAfterOutputMode
                )
            } else {
                appModel.appSettings.addChord(chord: Chord(
                    input: chordFormInput,
                    output: chordFormOutput,
                    capitalisationMode: chordFormCapitalisationMode,
                    spaceBeforeOutputMode: chordFormSpaceBeforeOutputMode,
                    spaceAfterOutputMode: chordFormSpaceAfterOutputMode
                ))
            }
        case .edit(let editingId):
            let targetId = existingId ?? editingId
            appModel.appSettings.updateChord(
                id: targetId,
                input: chordFormInput,
                output: chordFormOutput,
                capitalisationMode: chordFormCapitalisationMode,
                spaceBeforeOutputMode: chordFormSpaceBeforeOutputMode,
                spaceAfterOutputMode: chordFormSpaceAfterOutputMode
            )
        case nil:
            return
        }
        conflictingChordForSave = nil
        dismissChordEditor()
    }

    private func saveChordEditor() {
        guard chordFormInput.count >= 2,
              !chordFormOutput.isEmpty,
              Chord.isValidOutput(chordFormOutput),
              !Chord.hasDuplicateInputLetters(chordFormInput) else {
            return
        }
        if let conflict = conflictingChord(for: chordFormInput, excludingId: chordEditorExcludingID) {
            conflictingChordForSave = conflict
            showChordInputConflictConfirmation = true
            return
        }
        commitChordEditor(replacingExistingId: nil)
    }

    private func replaceConflictingChord() {
        guard let conflict = conflictingChordForSave else {
            return
        }
        guard chordFormInput.count >= 2,
              !chordFormOutput.isEmpty,
              Chord.isValidOutput(chordFormOutput),
              !Chord.hasDuplicateInputLetters(chordFormInput) else {
            return
        }
        commitChordEditor(replacingExistingId: conflict.id)
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
                case .practice:
                    PracticeView(
                        appModel: appModel,
                        isActive: chordEditorContext == nil
                    )
                case .stats:
                    StatsView(appModel: appModel)
                case .help:
                    helpPanel
                case .settings:
                    generalSettingsPanel
                case .about:
                    aboutPanel
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
                spaceBeforeOutputMode: $chordFormSpaceBeforeOutputMode,
                spaceAfterOutputMode: $chordFormSpaceAfterOutputMode,
                showInputConflictConfirmation: $showChordInputConflictConfirmation,
                inputConflictTitle: chordInputConflictTitle,
                inputConflictMessage: chordInputConflictMessage,
                onSave: saveChordEditor,
                onReplaceConflict: replaceConflictingChord,
                onCancel: dismissChordEditor
            )
        }
        .onAppear {
            if openCreateChordOnAppear {
                DispatchQueue.main.async {
                    openCreateChordEditor()
                }
            }
        }
        .environment(\.openURL, OpenURLAction(handler: handleSettingsViewLink))
    }

    private var duplicateNormalisedInputsWarning: some View {
        let keys = appModel.appSettings.duplicateNormalisedInputKeys.joined(separator: ", ")
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Multiple chords share the same input combination (\(keys)). Only the last entry in your settings file is used for each.")
                .font(.settingsHint)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
    }

    private var chordsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !appModel.appSettings.duplicateNormalisedInputKeys.isEmpty {
                duplicateNormalisedInputsWarning
            }

            if showFilterInput {
                HStack {
                    TextField("Filter chords...", text: $filterString)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFilterFieldFocused)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFilterInput = false
                            filterString = ""
                            isFilterFieldFocused = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.async {
                        isFilterFieldFocused = true
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Table(filteredChords, selection: $selectedChords, sortOrder: $sortOrder) {
                    TableColumn("Input combination", value: \.input) { chord in
                        ChordInputCombinationCell(input: chord.input)
                    }
                    TableColumn("Output", value: \.output) { chord in
                        Text(chord.output)
                    }
                    TableColumn("Settings") { chord in
                        ChordOptionsCell(chord: chord)
                    }
                    .width(min: 48, ideal: 64)
                    TableColumn("Usage", value: \.usageCountForSorting) { chord in
                        Text(chord.totalUsageCount == 0 ? "-" : String(chord.totalUsageCount))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    TableDoubleClickHandler { row in
                        guard filteredChords.indices.contains(row) else {
                            return
                        }
                        openEditChordEditor(for: filteredChords[row].id)
                    }
                }
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
                    .accessibilityLabel("Add chord")
                    Button(action: {
                        showDeleteChordsConfirmation = true
                    }) {
                        Text("-").font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 20, maxWidth: 20, minHeight: 20, maxHeight: 20)
                    .accessibilityLabel("Delete selected chords")
                    .disabled(selectedChords.isEmpty)
                    .confirmationDialog(
                        deleteChordsConfirmationTitle,
                        isPresented: $showDeleteChordsConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive, action: deleteSelectedChords)
                    } message: {
                        Text(deleteChordsConfirmationMessage)
                    }
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
        .onChange(of: showFilterInput) { isShowing in
            if isShowing {
                DispatchQueue.main.async {
                    isFilterFieldFocused = true
                }
            } else {
                isFilterFieldFocused = false
            }
        }
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
        settingsRowLabel(title: title, hint: AttributedString(hint))
    }

    private func settingsRowLabel(title: String, hint: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(hint)
                .font(.settingsHint)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var helpPanel: some View {
        Form {
            Section {
                settingsRowLabel(
                    title: "Quickly add a chord",
                    hint: "Option-click the menu bar icon to open the new-chord dialog in one step, without opening the menu first."
                )
            } header: {
                Text("Shortcuts")
            }

            Section {
                settingsRowLabel(
                    title: "Chords don't work in this window",
                    hint: "Typing chords inside this preferences window is not supported. Chords only work in other apps while \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "this app") is running in the background."
                )
                settingsRowLabel(
                    title: "Hold keys together",
                    hint: attributedHint(
                        "Press and hold the keys in a chord for the hold delay (see Settings), then release. If you release too quickly, the chord won't trigger. When a shorter chord shares keys with a longer one (eg th and thi), the shorter chord fires if you hold long enough before adding the extra key.",
                        linkSettingsTab: true
                    )
                )
                settingsRowLabel(
                    title: "Capitalisation mode",
                    hint: "Tap Shift (press and release without typing anything else) to cycle through off, first-letter capitalised, and full capitalisation. The menu bar icon shows the current mode."
                )
            } header: {
                Text("Using the app")
            }

            Section {
                settingsRowLabel(
                    title: "Cursor placement",
                    hint: "Put a | (pipe) in a chord's output to place the cursor there after replacement. Escape a literal pipe with \\|."
                )
                settingsRowLabel(
                    title: "Date placeholders",
                    hint: "Use {{date}} tokens in output, for example {{yyyy}}, {{MM/dd/yyyy}}, or {{HH:mm}}."
                )
                settingsRowLabel(
                    title: "UUID placeholders",
                    hint: "Use {{uuid}} or {{UUID}} in output for a random UUID (lowercase or uppercase)."
                )
                settingsRowLabel(
                    title: "Bulk editing",
                    hint: appModel.appSettings.settingsFileDirectory != nil
                        ? attributedHint(
                            "For large changes, you can edit the config file directly and restart the app.",
                            linkConfigFile: true
                        )
                        : AttributedString("For large changes, you can edit the config file directly and restart the app. Back up your config file first.")
                )
            } header: {
                Text("Chord output tips")
            }

            Section {
                settingsRowLabel(
                    title: "Permissions",
                    hint: attributedHint(
                        "The app needs Input Monitoring and Accessibility permissions to detect chords and type for you. Grant these in the Settings tab if prompted.",
                        linkSettingsTab: true
                    )
                )
            } header: {
                Text("Setup")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("How to use Chorder")
    }

    private var aboutPanel: some View {
        VStack(spacing: 16) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            Text(Bundle.main.appDisplayName)
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(Bundle.main.appVersion)")
                .font(.body)
                .foregroundColor(.secondary)

            if Bundle.main.isLocalDevelopment {
                Text("Local development build")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Button("Provide feedback", action: settingsActions.openFeedback)
                .buttonStyle(.link)
                .font(.body)
                .padding(.top, 4)

            Text("Made with ❤️ by [George Gillams](https://www.georgegillams.co.uk/?utm_source=chorder)")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
    }

    private var holdDelayValidationMessage: String? {
        guard !appModel.appSettings.millisecondsToHoldStr.isEmpty,
              AppSettings.parseHoldDelayMilliseconds(from: appModel.appSettings.millisecondsToHoldStr) == nil else {
            return nil
        }
        return "Enter a value between \(Int(AppSettings.minimumHoldMilliseconds)) and \(Int(AppSettings.maximumHoldMilliseconds)) milliseconds."
    }

    private var generalSettingsPanel: some View {
        Form {
            Section {
                LabeledContent {
                    TextField("", text: millisecondsToHoldStrBinding)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Chord hold delay in milliseconds")
                } label: {
                    settingsRowLabel(
                        title: "Chord hold delay",
                        hint: "Must be between \(Int(AppSettings.minimumHoldMilliseconds)) and \(Int(AppSettings.maximumHoldMilliseconds)) ms, and smaller than the key repeat delay in your system settings."
                    )
                }
                if let holdDelayValidationMessage {
                    Text(holdDelayValidationMessage)
                        .font(.settingsHint)
                        .foregroundColor(.red)
                }
                if !Bundle.main.isAppSandboxed {
                    Toggle(isOn: useAccessibilityAPIBinding) {
                        settingsRowLabel(
                            title: "Use Accessibility API for replacement",
                            hint: "When enabled, chords are replaced by directly editing the focused text field via the Accessibility API — no synthetic key events are posted. Falls back to keystroke simulation automatically for apps that don't support it (eg Electron apps, and Terminal)."
                        )
                    }
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
                                appModel.appSettings.chooseBackupSettingsFileLocation()
                            }
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                            Button("Choose…") {
                                appModel.appSettings.chooseBackupSettingsFileLocation()
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
                    hasPermission: settingsActions.hasInputMonitoringPermission(),
                    grantAction: {
                        settingsActions.requestInputMonitoringPermission()
                        settingsActions.openInputMonitoringSettings()
                    },
                    openSettingsAction: settingsActions.openInputMonitoringSettings
                )

                permissionRow(
                    title: "Accessibility",
                    hasPermission: settingsActions.hasAccessibilityPermission(),
                    grantAction: {
                        settingsActions.requestAccessibilityPermission()
                        settingsActions.openAccessibilitySettings()
                    },
                    openSettingsAction: settingsActions.openAccessibilitySettings
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(hasPermission ? "permission granted" : "permission missing")")
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appModel: AppModel(), settingsActions: PermissionCoordinator())
    }
}


