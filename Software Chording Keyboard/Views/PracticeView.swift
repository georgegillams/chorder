//
//  PracticeView.swift
//  Software Chording Keyboard
//

import SwiftUI

private struct PracticeInputHint: View {
    let chordInput: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.secondary)
                .onHover { isHovered = $0 }

            if isHovered {
                Text(chordInput)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hint")
        .accessibilityValue(isHovered ? chordInput : "Hover to reveal chord input")
    }
}

struct PracticeView: View {
    private static let successDisplayDuration: TimeInterval = 1.5

    @ObservedObject var appModel: AppModel
    let isActive: Bool
    @StateObject private var monitor = PracticeChordMonitor()
    @State private var currentChord: Chord?
    @State private var lastChordedOutput = ""
    @State private var showDeleteConfirmation = false
    @State private var successAdvanceToken = 0

    private var chords: [Chord] {
        appModel.appSettings.chords
    }

    private var targetOutput: String {
        guard let currentChord else { return "" }
        return currentChord.displayOutput
    }

    var body: some View {
        Group {
            if chords.isEmpty {
                emptyState
            } else if let currentChord {
                practiceContent(for: currentChord)
            } else {
                ProgressView()
                    .onAppear { pickNextChord() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if currentChord == nil, !chords.isEmpty {
                pickNextChord()
            }
            updateMonitoring()
        }
        .onDisappear {
            successAdvanceToken += 1
            monitor.stop()
        }
        .onChange(of: isActive) { _ in
            updateMonitoring()
        }
        .onChange(of: currentChord?.id) { _ in
            updateMonitoring()
        }
        .onChange(of: chords.count) { newCount in
            if newCount == 0 {
                currentChord = nil
                lastChordedOutput = ""
                monitor.stop()
            } else if currentChord == nil {
                pickNextChord()
            }
        }
        .onChange(of: appModel.appSettings.millisecondsToHold) { _ in
            updateMonitoring()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No chords to practise")
                .font(.headline)
            Text("Add some chords first, then come back to practise the ones you use least.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding()
    }

    private func practiceContent(for chord: Chord) -> some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text(isShowingSuccess ? "You produced" : "Chord this output")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(isShowingSuccess ? lastChordedOutput : targetOutput)
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520)
                    .foregroundColor(isShowingSuccess ? .green : .primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Practise here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    PracticeInputHint(chordInput: chord.input)
                }

                practiceCaptureArea
            }
            .frame(maxWidth: 420)

            if chord.totalUsageCount == 0 {
                Text("Never used — good candidate to learn")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Used \(chord.totalUsageCount) time\(chord.totalUsageCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button("Delete this chord", role: .destructive) {
                showDeleteConfirmation = true
            }
            .buttonStyle(.borderless)
            .confirmationDialog(
                deleteConfirmationTitle(for: chord),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteCurrentChord()
                }
            } message: {
                Text("This chord will be removed from your configuration. This action cannot be undone.")
            }

            Spacer(minLength: 0)
        }
        .padding(32)
        .id(chord.id)
    }

    private var isShowingSuccess: Bool {
        !lastChordedOutput.isEmpty
    }

    private func deleteConfirmationTitle(for chord: Chord) -> String {
        "Delete “\(chord.input) → \(chord.output)”?"
    }

    private var practiceCaptureArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isShowingSuccess {
                Label("Chord matched", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else if monitor.heldCharacters.isEmpty {
                Text("Hold the chord keys together…")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else {
                Text(monitor.heldCharacters)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chord practice area")
        .accessibilityValue(
            lastChordedOutput.isEmpty
                ? (monitor.heldCharacters.isEmpty ? "Waiting for chord" : monitor.heldCharacters)
                : lastChordedOutput
        )
    }

    private func updateMonitoring() {
        guard isActive, let chord = currentChord else {
            monitor.stop()
            return
        }

        monitor.onSuccess = {
            handleSuccess()
        }
        monitor.start(
            targetChord: chord,
            holdDurationMilliseconds: appModel.appSettings.millisecondsToHold
        )
    }

    private func handleSuccess() {
        guard let currentChord else { return }

        monitor.stop()
        lastChordedOutput = currentChord.displayOutput
        PracticeFeedbackSound.playSuccess()

        let previousId = currentChord.id
        successAdvanceToken += 1
        let token = successAdvanceToken
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.successDisplayDuration) {
            guard token == successAdvanceToken else { return }
            lastChordedOutput = ""
            pickNextChord(excludingId: previousId)
            updateMonitoring()
        }
    }

    private func deleteCurrentChord() {
        guard let chord = currentChord else { return }

        successAdvanceToken += 1
        monitor.stop()
        lastChordedOutput = ""
        appModel.appSettings.removeChords(chords: [chord.id])

        if chords.isEmpty {
            currentChord = nil
        } else {
            pickNextChord()
            updateMonitoring()
        }
    }

    private func pickNextChord(excludingId: Chord.ID? = nil) {
        currentChord = ChordPracticeSelection.pick(from: chords, excludingId: excludingId)
            ?? ChordPracticeSelection.pick(from: chords)
    }
}
