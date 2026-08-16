//
//  LegendsMatchView.swift
//  Retro Season Manager
//
//  Play Match — kicks off a real live match (LegendsLiveMatch.swift /
//  LegendsLiveMatchView.swift): minute-by-minute, commentary, mid-match
//  mentality/instruction/substitutions. The pre-match "ready" panel and
//  the post-match result panel below are unchanged from the original
//  instant-result version; only what happens in between changed.
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

    @State private var liveMatch: LegendsLiveMatch? = nil
    @State private var summary: LegendsMatchOutcomeSummary? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            if let liveMatch {
                LegendsLiveMatchView(store: store, live: liveMatch) {
                    let result = store.applyMatchOutcome(opponent: liveMatch.opponent, result: liveMatch.result)
                    announceResult(result)
                    withAnimation(.spring(duration: 0.5)) {
                        summary = result
                        self.liveMatch = nil
                    }
                }
            } else {
                VStack(spacing: 18) {
                    header
                    Spacer()
                    if let summary {
                        resultPanel(summary)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
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
    }

    private var header: some View {
        HStack {
            LegendsBackButton(action: onBack)
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
                liveMatch = LegendsLiveMatch(store: store, opponent: store.generateOpponent())
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
    /// as the result becomes available. The in-match whistle/goal cues
    /// already played live during `LegendsLiveMatchView` — this only
    /// covers what's genuinely new information at this point: the
    /// outcome haptic and any reward/promotion/retirement flourishes.
    private func announceResult(_ summary: LegendsMatchOutcomeSummary) {
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
                            HStack {
                                Text("✓ \(completion.challenge.title)")
                                    .font(.system(.footnote, design: .monospaced).bold())
                                    .foregroundStyle(Retro.emerald)
                                Spacer()
                                Text(challengeRewardText(completion.challenge))
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.highlight)
                            }
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

            Button {
                Haptics.tap()
                onBack()
            } label: {
                Text("Back to Home")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Retro.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressableButtonStyle())
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

    /// Challenge coin/token payouts land straight in `profile.coins`/
    /// `packTokens` (`LegendsStore+Challenges.swift`'s `grant(_:)`) — not
    /// folded into `summary.coinsEarned`/`tokensEarned`, which only cover
    /// the base match-outcome reward. Surfacing them here so the total on
    /// screen actually matches what the player's balance just gained.
    private func challengeRewardText(_ challenge: LegendsChallenge) -> String {
        var parts: [String] = []
        if challenge.coinReward > 0 { parts.append("+\(challenge.coinReward) coins") }
        if challenge.tokenReward > 0 { parts.append("+\(challenge.tokenReward) tokens") }
        return parts.joined(separator: ", ")
    }

    private func outcomeColor(_ outcome: LegendsMatchOutcome) -> Color {
        switch outcome {
        case .win: return Retro.emerald
        case .draw: return Retro.gold
        case .loss: return Retro.warning
        }
    }
}
