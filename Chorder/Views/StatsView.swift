//
//  StatsView.swift
//  Chorder
//

import SwiftUI
import components_swiftUI

private struct StatsMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Semantic.Colors.textOnColor.opacity(0.95))
                .shadow(color: Semantic.Colors.shadowColor, radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Semantic.Colors.textOnColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Semantic.Colors.textOnColor.opacity(0.95))

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Semantic.Colors.textOnColor.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(gradient)
                .shadow(color: Semantic.Colors.shadowColor, radius: 10, y: 6)
        )
    }
}

struct StatsView: View {
    @ObservedObject var appModel: AppModel

    private var totals: ChordUsageSummary.Totals {
        ChordUsageSummary.totals(for: appModel.appSettings.chords)
    }

    private var formattedChordCount: String {
        NumberFormatter.localizedString(from: NSNumber(value: totals.totalChordsEntered), number: .decimal)
    }

    private var formattedCharactersSaved: String {
        let prefix = totals.totalCharactersSaved >= 0 ? "" : "−"
        let magnitude = abs(totals.totalCharactersSaved)
        return prefix + NumberFormatter.localizedString(from: NSNumber(value: magnitude), number: .decimal)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                if totals.totalChordsEntered == 0 {
                    emptyState
                } else {
                    metricsGrid
                    celebrationBanner
                }

                footnote
            }
            .padding(32)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(statsBackground)
    }

    private var statsBackground: some View {
        LinearGradient(
            colors: [
                Semantic.Colors.primaryColorLight.opacity(0.45),
                Semantic.Colors.backgroundColor,
                Semantic.Colors.primaryColorTransparent
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var celebrationAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Semantic.Colors.linkColor,
                Semantic.Colors.tagPhotographyBackground,
                Semantic.Colors.segmentedControlSelectedColor
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Semantic.Colors.tagTechBackground)
                Image(systemName: "party.popper.fill")
                    .font(.title)
                    .foregroundStyle(celebrationAccentGradient)
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Semantic.Colors.tagTechBackground)
            }

            Text("Your chording wins")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Semantic.Colors.notBlack)

            Text("Every chord represents keystrokes you never had to type.")
                .font(.subheadline)
                .foregroundStyle(Semantic.Colors.textDisabled)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: 18)],
            spacing: 18
        ) {
            StatsMetricCard(
                title: "Chords entered",
                value: formattedChordCount,
                subtitle: "Successful chord replacements",
                systemImage: "hand.tap.fill",
                gradient: LinearGradient(
                    colors: [Semantic.Colors.cardHighlightBackground, Semantic.Colors.primaryColorReallyDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            StatsMetricCard(
                title: "Characters saved",
                value: formattedCharactersSaved,
                subtitle: "Output length minus chord input",
                systemImage: "character.cursor.ibeam",
                gradient: LinearGradient(
                    colors: [Semantic.Colors.statusSuccess, Semantic.Colors.ctaColorActive],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            StatsMetricCard(
                title: "Time saved",
                value: ChordUsageSummary.formattedTimeSaved(totals.estimatedTimeSavedSeconds),
                subtitle: "At ~\(Int(ChordUsageSummary.averageSecondsPerTypedCharacter * 1000)) ms per character",
                systemImage: "clock.badge.checkmark.fill",
                gradient: LinearGradient(
                    colors: [Semantic.Colors.tagPhotographyBackground, Semantic.Colors.statusDestructive],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var celebrationBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(Semantic.Colors.tagTechBackground)

            VStack(alignment: .leading, spacing: 6) {
                Text(celebrationMessage)
                    .font(.headline)
                    .foregroundStyle(Semantic.Colors.notBlack)

                Text("Keep chording — those saved seconds add up fast.")
                    .font(.subheadline)
                    .foregroundStyle(Semantic.Colors.textDisabled)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Semantic.Colors.backgroundColorElevated.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Semantic.Colors.linkColor.opacity(0.5),
                                    Semantic.Colors.tagPhotographyBackground.opacity(0.5),
                                    Semantic.Colors.segmentedControlSelectedColor.opacity(0.5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    private var celebrationMessage: String {
        switch totals.totalChordsEntered {
        case 1:
            return "Your first chord is in the books!"
        case 2...49:
            return "You're building a great chording habit."
        case 50...499:
            return "Impressive — your fingers are flying!"
        default:
            return "Chord warrior! You've saved serious typing time."
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Semantic.Colors.segmentedControlSelectedColor, Semantic.Colors.primaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("No chords yet")
                .font(.headline)
                .foregroundStyle(Semantic.Colors.notBlack)

            Text("Use a chord in any app and your stats will appear here — colourful celebrations included.")
                .font(.subheadline)
                .foregroundStyle(Semantic.Colors.textDisabled)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Semantic.Colors.backgroundColorElevated.opacity(0.65))
        )
    }

    private var footnote: some View {
        Text(
            "Stats combine usage across all machines synced to your settings folder. "
            + "Time saved assumes average typing speed of about 40 words per minute."
        )
        .font(.callout)
        .foregroundStyle(Semantic.Colors.textDisabled)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 560)
    }
}
