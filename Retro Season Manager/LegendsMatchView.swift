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

/// Validates the persisted squad before the live-match engine is created.
/// Older saves can contain short arrays, stale card IDs or duplicate slot
/// assignments; rejecting those states here avoids an apparent no-op/crash
/// when KICK OFF tries to build the pitch simulation.
@MainActor
enum LegendsMatchLaunchValidator {
    static func issue(in store: LegendsStore) -> String? {
        let slots = store.startingXISlots
        let savedXI = store.profile.startingXICardIDs

        guard savedXI.count == slots.count else {
            return "Your saved Starting XI is incomplete. Open Squad and fill all eleven positions."
        }

        let cardIDs = savedXI.compactMap { $0 }
        guard cardIDs.count == slots.count else {
            return "Fill every Starting XI slot in the Squad screen before starting a match."
        }
        guard Set(cardIDs).count == cardIDs.count else {
            return "A player is assigned to more than one Starting XI slot. Re-select the duplicated player in Squad."
        }

        for cardID in cardIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else {
                return "Your Starting XI contains an unavailable player. Replace them in Squad."
            }
            guard store.isSigned(card) else {
                return "Every Starting XI player must be signed before starting a match."
            }
        }
        return nil
    }
}

struct LegendsMatchView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var liveMatch: LegendsLiveMatch? = nil
    @State private var summary: LegendsMatchOutcomeSummary? = nil
    @State private var launchError: String? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            if let liveMatch {
                LegendsLiveMatchView(store: store, live: liveMatch,
                                     onFinished: {
                    let result = store.applyMatchOutcome(opponent: liveMatch.opponent, result: liveMatch.result)
                    announceResult(result)
                    withAnimation(.spring(duration: 0.5)) {
                        summary = result
                        self.liveMatch = nil
                    }
                },
                                     onAbandoned: {
                    // A forfeit: the standard 0–3 registered defeat,
                    // regardless of the scoreline at the moment of
                    // abandonment — an abandon is always a loss, never a
                    // way to salvage a draw from a losing position.
                    let result = store.applyMatchOutcome(opponent: liveMatch.opponent,
                                                         result: LegendsMatchEngine.Result(teamGoals: 0, opponentGoals: 3))
                    announceResult(result)
                    withAnimation(.spring(duration: 0.5)) {
                        summary = result
                        self.liveMatch = nil
                    }
                })
            } else {
                LegendsMenuShell(store: store, title: "PLAY MATCH", subtitle: store.profile.division.displayName, icon: "soccerball", accent: LegendsPalette.green, onBack: onBack, currentNav: .home, onNavigate: onNavigate) {
                    if let summary {
                        resultPanel(summary)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else if LegendsMatchLaunchValidator.issue(in: store) == nil {
                        readyPanel
                    } else {
                        notReadyPanel
                    }
                }
            }
        }
        .alert("Unable to start match", isPresented: Binding(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("OK", role: .cancel) { launchError = nil }
        } message: {
            Text(launchError ?? "Check your Starting XI and try again.")
        }
    }


    private var notReadyPanel: some View {
        Panel(title: "SQUAD NOT READY") {
            Text(LegendsMatchLaunchValidator.issue(in: store)
                 ?? "Fill every Starting XI slot in the Squad screen before you can play a match.")
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
                Text("\(store.divisionFixturesRemaining) FIXTURES REMAIN · RANK TOP 2 TO PROMOTE")
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
                launchMatch()
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
            .accessibilityIdentifier("legends.match.kickoff")
        }
    }

    private func launchMatch() {
        if let issue = LegendsMatchLaunchValidator.issue(in: store) {
            launchError = issue
            return
        }
        Haptics.tap()
        store.prepareIdentityProfilesForMatch()
        let opponent = store.scheduledOpponent()
        liveMatch = LegendsLiveMatch(store: store, opponent: opponent)
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

            if let seasonAdvance = summary.seasonAdvance, !seasonAdvance.developmentReview.isEmpty {
                Panel(title: "SEASON DEVELOPMENT REVIEW") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(seasonAdvance.developmentReview.values.sorted { $0.playerName < $1.playerName }, id: \.cardID) { entry in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 4) {
                                        Text(entry.playerName)
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text)
                                            .lineLimit(1)
                                        Text(entry.overallDelta >= 0 ? "+\(entry.overallDelta)" : "\(entry.overallDelta)")
                                            .font(.system(.caption, design: .monospaced))
                                            .fontWeight(.black)
                                            .foregroundStyle(entry.overallDelta > 0 ? Retro.emerald : (entry.overallDelta < 0 ? Retro.warning : Retro.gold))
                                    }
                                    Text("\(entry.appearances) APP · \(entry.reason)")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(Retro.text.opacity(0.6))
                                        .lineLimit(2)
                                        .frame(width: 150, alignment: .leading)
                                }
                                .padding(8)
                                .background(Retro.panel.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .frame(maxWidth: 520)
            }

            if let seasonAdvance = summary.seasonAdvance {
                Panel(title: "SEASON \(seasonAdvance.newSeason) BEGINS") {
                    if !seasonAdvance.retirementAnnouncements.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RETIREMENT ANNOUNCEMENT")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundStyle(Retro.gold)
                            ForEach(seasonAdvance.retirementAnnouncements, id: \.id) { card in
                                Text("\(card.name) has announced that this will be their final season.")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.85))
                            }
                        }
                    }
                    if seasonAdvance.retiredCards.isEmpty && seasonAdvance.retirementAnnouncements.isEmpty {
                        Text("Every signed career is a year older. Collection players remain frozen.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    } else if !seasonAdvance.retiredCards.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CAREER COMPLETE — these players are now in Legends Hall:")
                                .font(.system(.footnote, design: .monospaced).bold())
                                .foregroundStyle(Retro.warning)
                            ForEach(seasonAdvance.retiredCards, id: \.id) { card in
                                Text("• \(card.name) · final age \(seasonAdvance.retiredAges[card.id] ?? LegendsStore.retirementAge)")
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
            if let divisionResult = summary.divisionSeasonResult {
                Panel(title: divisionResult.outcome.displayName) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finished \(divisionResult.finalRank)/\(divisionResult.totalTeams) in Season \(divisionResult.season).")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                        rewardRow("Season coins", "+\(divisionResult.reward.coins)")
                        rewardRow("Season tokens", "+\(divisionResult.reward.tokens)")
                        rewardRow("Season XP", "+\(divisionResult.reward.managerXP)")
                        Text("Next: \(divisionResult.newDivision.displayName)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(divisionResult.outcome == .relegated ? Retro.warning : Retro.emerald)
                    }
                }
                .frame(maxWidth: 380)
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
