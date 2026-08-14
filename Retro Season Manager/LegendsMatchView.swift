//
//  LegendsMatchView.swift
//  Retro Season Manager
//
//  Play Match (Phase 7) — a deliberately short presentation per the
//  doc ("Shorter presentation. Faster progression."): no live
//  minute-by-minute ticker, just a brief search beat and the result.
//
//  Phase 10 polish: reuses LiveMatch's own sound-cue vocabulary
//  (whistleKickOff/whistleFullTime/goalCrowd/promotion/trophyLift)
//  rather than inventing new cues, and adds an entrance animation plus
//  outcome-specific haptics for the result reveal.
//

import SwiftUI

struct LegendsMatchView: View {
    let store: LegendsStore
    var onBack: () -> Void

    @State private var isSimulating = false
    @State private var summary: LegendsMatchOutcomeSummary? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                Spacer()
                if let summary {
                    resultPanel(summary)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if isSimulating {
                    searchingPanel
                } else if store.currentTeamRating > 0 {
                    readyPanel
                } else {
                    notReadyPanel
                }
                Spacer()
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            Button {
                Haptics.tap()
                onBack()
            } label: {
                Text("‹ Back")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
            }
            .buttonStyle(PressableButtonStyle())
            Spacer()
            Text("PLAY MATCH")
                .font(.system(.headline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Spacer()
            Color.clear.frame(width: 60)
        }
        .padding(.top, 12)
    }

    private var notReadyPanel: some View {
        Panel(title: "SQUAD NOT READY") {
            Text("Fill every Starting XI slot in the Squad screen before you can play a match.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 420)
    }

    private var readyPanel: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(store.profile.division.displayName.uppercased())
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .tracking(2)
                Text("\(store.profile.divisionWins)/\(LegendsStore.winsToPromote) WINS TO PROMOTION")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
            }

            Panel(title: "YOUR TEAM") {
                HStack {
                    Text(store.profile.clubName)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Text("\(store.currentTeamRating) OVR")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                }
            }
            .frame(maxWidth: 380)

            Button {
                Haptics.tap()
                SoundManager.shared.play(.whistleKickOff)
                isSimulating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    let result = store.playMatch()
                    announceResult(result)
                    withAnimation(.spring(duration: 0.5)) {
                        summary = result
                        isSimulating = false
                    }
                }
            } label: {
                Text("KICK OFF")
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 14)
                    .background(Retro.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    /// Sound + haptic cues for a just-finished match, played once right
    /// as the result becomes available — mirrors LiveMatch's own
    /// full-time/goal cues rather than a new vocabulary.
    private func announceResult(_ summary: LegendsMatchOutcomeSummary?) {
        guard let summary else { return }
        if summary.result.teamGoals > 0 { SoundManager.shared.play(.goalCrowd) }
        SoundManager.shared.play(.whistleFullTime)
        switch summary.result.outcome {
        case .win: Haptics.success()
        case .draw: Haptics.tap()
        case .loss: Haptics.warning()
        }
        if summary.promoted { SoundManager.shared.play(.promotion) }
        if summary.leveledUp || summary.newManager != nil || summary.newStadium != nil || !summary.completedChallenges.isEmpty {
            SoundManager.shared.play(.trophyLift)
        }
        if let retiredCount = summary.seasonAdvance?.retiredCards.count, retiredCount > 0 {
            SoundManager.shared.play(.redCard)
        }
    }

    private var searchingPanel: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Retro.accent)
            Text("Finding an opponent…")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
    }

    private func resultPanel(_ summary: LegendsMatchOutcomeSummary) -> some View {
        VStack(spacing: 16) {
            Text(summary.result.outcome.label)
                .font(.system(.largeTitle, design: .monospaced).bold())
                .foregroundStyle(outcomeColor(summary.result.outcome))

            Text("\(store.profile.clubName)  \(summary.result.teamGoals) – \(summary.result.opponentGoals)  \(summary.opponent.name)")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .multilineTextAlignment(.center)

            Text("Opponent rating \(summary.opponent.rating)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))

            Panel(title: "REWARDS") {
                VStack(alignment: .leading, spacing: 6) {
                    rewardRow("Coins", "+\(summary.coinsEarned)")
                    if summary.tokensEarned > 0 { rewardRow("Pack Tokens", "+\(summary.tokensEarned)") }
                    rewardRow("Manager XP", "+\(summary.xpEarned)")
                }
            }
            .frame(maxWidth: 380)

            if !summary.completedChallenges.isEmpty {
                Panel(title: "CHALLENGES COMPLETE") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summary.completedChallenges, id: \.challenge.id) { completion in
                            Text("✓ \(completion.challenge.title)")
                                .font(.system(.footnote, design: .monospaced).bold())
                                .foregroundStyle(Retro.emerald)
                        }
                    }
                }
                .frame(maxWidth: 380)
            }

            if let seasonAdvance = summary.seasonAdvance {
                Panel(title: "SEASON \(seasonAdvance.newSeason) BEGINS") {
                    if seasonAdvance.retiredCards.isEmpty {
                        Text("Every card in your collection is a year older.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("These players have retired — replace them in Squad:")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.85))
                            ForEach(seasonAdvance.retiredCards, id: \.id) { card in
                                Text("• \(card.name) (\(store.effectiveAge(for: card)))")
                                    .font(.system(.footnote, design: .monospaced).bold())
                                    .foregroundStyle(Retro.warning)
                            }
                        }
                    }
                }
                .frame(maxWidth: 380)
            }

            if let newManager = summary.newManager {
                Text("NEW MANAGER: \(newManager.name.uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.gold)
            }
            if let newStadium = summary.newStadium {
                Text("NEW STADIUM: \(newStadium.name.uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.gold)
            }
            if summary.leveledUp {
                Text("MANAGER LEVEL UP → \(store.profile.managerLevel)")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.gold)
            }
            if summary.promoted {
                Text("PROMOTED TO \(summary.newDivision.displayName.uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.emerald)
            }

            HStack(spacing: 12) {
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.25)) { self.summary = nil }
                } label: {
                    Text("Play Again")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Retro.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("Back to Home")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func rewardRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
    }

    private func outcomeColor(_ outcome: LegendsMatchOutcome) -> Color {
        switch outcome {
        case .win: return Retro.emerald
        case .draw: return Retro.gold
        case .loss: return Retro.warning
        }
    }
}
