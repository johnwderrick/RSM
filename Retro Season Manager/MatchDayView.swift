//
//  MatchDayView.swift
//  Retro Season Manager
//
//  Pre-match preparation, the live match screen, and the
//  substitutions sheet.
//

import SwiftUI

// MARK: - Pre-match hub

/// The pre-match hub, redesigned in the accepted Career light-card design
/// language (pale canvas, white cards, ink headings, green accents, gold
/// reserved for genuine emphasis, monospaced figures): a readable,
/// deterministic fixture card leading with the two-club match-up, then
/// form, confirmed lineups, ones to watch, match odds, opponent scouting,
/// and the pending team-talk / press prompts as stacked white cards on one
/// stable vertical scroll container. BACK and KICK OFF sit in a pinned
/// bottom action bar — reachable at every scroll position on compact
/// landscape — so nothing ever clips under the fold.
///
/// Read-only by contract: every value comes straight from the
/// authoritative `GameStore` preview paths (form, `matchXIForPreview`,
/// `outcomeProbabilities`, scouting report) and every action keeps its
/// original store call — `answerTeamTalk`, `answerPress`,
/// `store.atPreMatch = false` for BACK and `beginUserMatch()` for KICK
/// OFF. The live match and post-match screens below in this file are
/// untouched, and nothing here touches match outcomes or simulation
/// rules. The `career.prematch.screen` and `career.match.kickoff`
/// identifiers are kept stable; the redesigned sections add their own
/// `career.prematch.*` selectors for the focused UI tests.
struct PreMatchHubView: View {
    let store: GameStore

    var body: some View {
        ZStack(alignment: .bottom) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if let match = store.nextUserMatchInfo {
                        fixtureCard(for: match)
                    }
                    if let talk = store.pendingTeamTalk {
                        teamTalkCard(talk)
                    }
                    if let question = store.pendingPressQuestion {
                        pressCard(question)
                    }
                    if let opponentIndex = opponentIndex {
                        lineupsCard(opponentIndex: opponentIndex)
                        keyPlayersCard(opponentIndex: opponentIndex)
                        scoutingCard(opponentIndex: opponentIndex)
                    }
                    endAnchor
                }
                .padding(14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier("career.prematch.scroll")

            actionBar
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.screen")
    }

    /// The opponent for the next fixture (the side the user is not).
    private var opponentIndex: Int? {
        guard let match = store.nextUserMatchInfo else { return nil }
        return match.homeIndex == store.userClubIndex ? match.awayIndex : match.homeIndex
    }

    /// Always-visible BACK / KICK OFF bar, pinned above the safe area so
    /// both controls stay reachable at every scroll position — including
    /// compact landscape, where a top-bar placement scrolls away with the
    /// content.
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                store.atPreMatch = false
            } label: {
                Text("BACK")
                    .font(.system(.callout, design: .monospaced).bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(CareerPalette.surface)
                    .foregroundStyle(CareerPalette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("career.prematch.back")

            Button {
                Haptics.impact()
                store.beginUserMatch()
            } label: {
                Text("KICK OFF ▸")
                    .font(.system(.callout, design: .monospaced).bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Retro.gold)
                    .foregroundStyle(Color(red: 0.18, green: 0.12, blue: 0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("career.match.kickoff")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(CareerPalette.canvas.opacity(0.97).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(CareerPalette.line.opacity(0.18)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.actionBar")
    }

    // MARK: Header band

    private var header: some View {
        HStack(spacing: 12) {
            CrestView(shortName: store.userClub.shortName, size: 52, color: store.userColor)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("PRE-MATCH HUB")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.userClub.name) · MATCHDAY \(store.currentMatchday)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.prematch.header")
        .accessibilityLabel("Pre-match hub. \(store.userClub.name), matchday \(store.currentMatchday).")
    }

    // MARK: The fixture — the two clubs lead, everything supports

    private func fixtureCard(for match: UserMatchInfo) -> some View {
        let isHome = match.homeIndex == store.userClubIndex
        let opponentIdx = isHome ? match.awayIndex : match.homeIndex
        let opponent = store.clubs[opponentIdx]
        let ratings = store.starRatings(forClubIndices: [store.userClubIndex, opponentIdx])
        let homeIndex = isHome ? store.userClubIndex : opponentIdx
        let awayIndex = isHome ? opponentIdx : store.userClubIndex
        let isDerby = store.nextMatchIsDerby
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(isDerby ? "⚔️ DERBY DAY" : match.label.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                Spacer()
                Text(isHome ? "HOME" : "AWAY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(CareerPalette.line.opacity(0.12))
                    .clipShape(Capsule())
            }

            // The two clubs: the visual centrepiece of the screen.
            HStack(alignment: .top, spacing: 10) {
                teamBadge(store.userClub.shortName, store.userClub.name,
                          ratings[store.userClubIndex] ?? 1, store.userColor)
                VStack(spacing: 4) {
                    Text(isHome ? "vs" : "@")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(isDerby ? Color(red: 0.95, green: 0.35, blue: 0.35) : CareerPalette.ink)
                    Text(isHome ? "you're at home" : "you're away")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
                teamBadge(opponent.shortName, opponent.name,
                          ratings[opponentIdx] ?? 1, store.color(forClubIndex: opponentIdx))
            }

            if isDerby {
                Text(derbyFlavorText(opponentIndex: opponentIdx))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Text(store.matchAtmosphere(homeIndex: homeIndex, awayIndex: awayIndex))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            formRow(title: "Your form", outcomes: store.recentForm(forClubIndex: store.userClubIndex))
            formRow(title: "\(opponent.shortName) form", outcomes: store.recentForm(forClubIndex: opponentIdx))

            oddsRow(opponentIndex: opponentIdx, isHome: isHome)
        }
        .padding(14)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isDerby ? Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.45) : CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.fixture")
    }

    private func teamBadge(_ short: String, _ name: String, _ stars: Int, _ color: Color) -> some View {
        VStack(spacing: 5) {
            CrestView(shortName: short, size: 48, color: color)
            Text(name)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            StarRatingView(stars: stars)
        }
        .frame(maxWidth: .infinity)
    }

    private func formRow(title: String, outcomes: [MatchOutcome]) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .lineLimit(1)
            Spacer()
            if outcomes.isEmpty {
                Text("No games played yet")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                FormView(outcomes: outcomes)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(outcomes.isEmpty ? "no games played yet" : outcomes.map(\.letter).joined(separator: " "))")
        .accessibilityIdentifier("career.prematch.form.\(slug(title))")
    }

    // MARK: Match odds — the engine's own probability model

    private func oddsRow(opponentIndex: Int, isHome: Bool) -> some View {
        let homeIndex = isHome ? store.userClubIndex : opponentIndex
        let awayIndex = isHome ? opponentIndex : store.userClubIndex
        let probs = store.outcomeProbabilities(homeIndex: homeIndex, awayIndex: awayIndex)
        let userWin = Int(((isHome ? probs.home : probs.away) * 100).rounded())
        let draw = Int((probs.draw * 100).rounded())
        let oppWin = max(0, 100 - userWin - draw)
        let oppShort = store.clubs[opponentIndex].shortName
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("MATCH ODDS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Spacer()
            }
            HStack(spacing: 8) {
                oddsChip("You", userWin, userWin >= oppWin && userWin >= draw)
                oddsChip("Draw", draw, draw > userWin && draw > oppWin)
                oddsChip(oppShort, oppWin, oppWin > userWin && oppWin >= draw)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.odds")
        .accessibilityLabel("Match odds. You \(userWin) percent, draw \(draw) percent, \(oppShort) \(oppWin) percent.")
    }

    private func oddsChip(_ title: String, _ pct: Int, _ favourite: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(pct)%")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(favourite ? CareerPalette.ink : CareerPalette.mutedInk)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(CareerPalette.line.opacity(favourite ? 0.10 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(favourite ? Retro.gold.opacity(0.35) : CareerPalette.line.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.prematch.odds.\(slug(title))")
        .accessibilityLabel("\(title): \(pct) percent\(favourite ? ", favourite" : "")")
    }

    // MARK: Confirmed lineups — read-only, straight from the engine

    /// A read-only confirmed-lineups display — deliberately not the
    /// editable `PitchView` (bound to `store.userStarterIDs`/`slotPins`,
    /// tap-to-edit), just two side-by-side columns built from the exact
    /// XI the match engine itself will field for either side.
    private func lineupsCard(opponentIndex: Int) -> some View {
        let userXI = store.matchXIForPreview(store.userClubIndex).sorted { $0.position.order < $1.position.order }
        let opponentXI = store.matchXIForPreview(opponentIndex).sorted { $0.position.order < $1.position.order }
        return VStack(alignment: .leading, spacing: 10) {
            cardTitle("person.2.fill", "CONFIRMED LINEUPS")
            HStack(alignment: .top, spacing: 16) {
                lineupColumn(store.userClub.shortName, userXI, store.userColor)
                lineupColumn(store.clubs[opponentIndex].shortName, opponentXI,
                             store.color(forClubIndex: opponentIndex))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.lineups")
    }

    private func lineupColumn(_ short: String, _ xi: [Player], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                CrestView(shortName: short, size: 14, color: color)
                Text(short.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityIdentifier("career.prematch.lineup.\(slug(short))")
            ForEach(xi) { player in
                HStack(spacing: 6) {
                    Text(player.careerPositionLabel)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .frame(width: 30, alignment: .leading)
                        .foregroundStyle(CareerPalette.mutedInk)
                    Text(surname(player.name))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Ones to watch

    private func keyPlayersCard(opponentIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("sparkles", "ONES TO WATCH")
            HStack(spacing: 10) {
                if let key = store.keyPlayer(forClubIndex: store.userClubIndex) {
                    keyPlayerCard(key, store.userClub.shortName, store.userColor)
                }
                if let key = store.keyPlayer(forClubIndex: opponentIndex) {
                    keyPlayerCard(key, store.clubs[opponentIndex].shortName,
                                  store.color(forClubIndex: opponentIndex))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.keyPlayers")
    }

    private func keyPlayerCard(_ player: Player, _ clubShort: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(clubShort.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(player.name)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("\(player.rating) OVR")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(CareerPalette.canvas.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Opponent scouting report

    private func scoutingCard(opponentIndex: Int) -> some View {
        let opponent = store.clubs[opponentIndex]
        return VStack(alignment: .leading, spacing: 10) {
            cardTitle("magnifyingglass", opponent.name.uppercased())
            VStack(alignment: .leading, spacing: 7) {
                infoRow("Style", store.playStyle(forClubIndex: opponentIndex))
                infoRow("Formation", store.formationName(forClubIndex: opponentIndex))
                infoRow("Manager", store.manager(forClubIndex: opponentIndex))
                if let key = store.keyPlayer(forClubIndex: opponentIndex) {
                    infoRow("Key player", "\(key.name) (\(key.rating))")
                }
            }
            if let identity = store.clubIdentity(forClubIndex: opponentIndex) {
                Text(identity.flavorText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(CareerPalette.line.opacity(0.18)).frame(height: 1)
            HStack(alignment: .top, spacing: 16) {
                strengthsColumn("STRENGTHS", store.teamStrengths(forClubIndex: opponentIndex), CareerPalette.line)
                strengthsColumn("WEAKNESSES", store.teamWeaknesses(forClubIndex: opponentIndex),
                                Color(red: 0.95, green: 0.35, blue: 0.35))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.scouting")
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private func strengthsColumn(_ title: String, _ items: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Team talk

    private func teamTalkCard(_ question: PressQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("bubble.left.and.bubble.right.fill", "🗣 TEAM TALK")
            Text(question.prompt)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                promptOption(
                    label: option.label,
                    detail: deltasDetail(option),
                    identifier: "career.prematch.talk.\(index)"
                ) {
                    Haptics.tap()
                    store.answerTeamTalk(option)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.gold.opacity(0.35)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.teamTalk")
    }

    // MARK: Press conference

    private func pressCard(_ question: PressQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("mic.fill", "🎙 PRESS CONFERENCE")
            Text(question.prompt)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                promptOption(
                    label: option.label,
                    detail: deltasDetail(option),
                    identifier: "career.prematch.press.\(index)"
                ) {
                    Haptics.tap()
                    store.answerPress(option)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.gold.opacity(0.35)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.prematch.pressCard")
    }

    /// The exact morale/board deltas `answerTeamTalk`/`answerPress` will
    /// apply for this option — the same authoritative numbers, just shown
    /// where they're chosen.
    private func deltasDetail(_ option: PressOption) -> String {
        let morale = "\(option.moraleDelta >= 0 ? "+" : "")\(option.moraleDelta) morale"
        guard option.confidenceDelta != 0 else { return morale }
        return "\(morale) · \(option.confidenceDelta >= 0 ? "+" : "")\(option.confidenceDelta) board"
    }

    /// A team-talk / press answer button: the answer's own label plus the
    /// morale/board deltas it will apply.
    private func promptOption(label: String, detail: String,
                              identifier: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 40)
            .background(CareerPalette.canvas.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    // MARK: Card furniture

    private func cardTitle(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(CareerPalette.line)
            Text(text)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// A deterministic end-of-content anchor — querying it after a scroll
    /// proves the lower cards were actually read (see the UI tests).
    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier("career.prematch.endAnchor")
    }

    /// Identifier slug for fixture-local selectors.
    private func slug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    /// A short flavour line for derby day — quotes the rivalry's own
    /// formation story if it's one that grew organically this career
    /// (see `RivalryPair.formedSeason`/`reason`, item 4), otherwise a
    /// generic line for the scripted real-world derbies.
    private func derbyFlavorText(opponentIndex: Int) -> String {
        let opponentName = store.clubs[opponentIndex].name
        if let pair = store.dynamicRivalries.first(where: { $0.involves(store.userClub.name, opponentName) }),
           let season = pair.formedSeason, let reason = pair.reason {
            return "Rivals since Season \(season)'s \(reason)."
        }
        return "One of the fiercest fixtures in the league."
    }
}

// MARK: - Live match

struct MatchView: View {
    let store: GameStore
    let live: LiveMatch
    @State private var showSubs = false
    @State private var goalFlash = false
    @State private var goalFlashColor = Retro.highlight
    @State private var goalFlashText = "GOAL!"
    @State private var penaltyFlash = false
    @State private var redCardFlash = false
    @State private var eventFlash: MatchFlashKind?
    @State private var interviewAnswered = false
    @State private var shakeTrigger = 0
    @State private var showConfetti = false
    @State private var confettiColors: [Color] = []
    @State private var showKickoffIntro = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Every iPhone in landscape reports compact height; the compact
    /// branches below keep the score, the key stats and every match
    /// control on screen there, instead of squeezing the commentary
    /// feed (and the controls) out of the layout.
    private var compact: Bool { verticalSizeClass == .compact }

    private var userGoals: Int { live.userSide == .home ? live.homeGoals : live.awayGoals }
    private var opponentGoals: Int { live.userSide == .home ? live.awayGoals : live.homeGoals }
    private var userWon: Bool { userGoals > opponentGoals }
    private var userDrew: Bool { userGoals == opponentGoals }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("StadiumBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            Retro.background.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 0) {
                scoreBar
                commentaryFeed
                Divider().overlay(Retro.accent.opacity(0.2))
                statsBlock
                infoRow
                controlBar
            }
            if penaltyFlash { penaltyFlashOverlay }
            if redCardFlash { redCardFlashOverlay }
            if goalFlash { goalFlashOverlay }
            if let eventFlash { MatchFlashOverlay(kind: eventFlash) }
            if showConfetti { PixelConfettiBurst(colors: confettiColors) }
            if live.isHalfTime {
                halfTimeSummaryOverlay
            }
            if live.isFinished {
                fullTimeOverlay
            }
            if showKickoffIntro {
                kickoffIntroOverlay.transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            CRTScanlineOverlay()
        }
        .matchShake(trigger: shakeTrigger)
        .onAppear {
            live.start()
            withAnimation(.easeIn(duration: 0.2)) { showKickoffIntro = true }
            Task {
                try? await Task.sleep(for: .milliseconds(2200))
                withAnimation(.easeOut(duration: 0.4)) { showKickoffIntro = false }
            }
        }
        .onChange(of: live.homeGoals) { _, _ in triggerGoalFlash(side: .home) }
        .onChange(of: live.awayGoals) { _, _ in triggerGoalFlash(side: .away) }
        .onChange(of: live.penaltyAwardedCount) { _, _ in triggerPenaltyFlash() }
        .onChange(of: live.redCardCount) { _, _ in triggerRedCardFlash() }
        .onChange(of: live.yellowCardFlashCount) { _, count in
            guard count > 0 else { return }
            triggerEventFlash(.yellowCard(playerName: live.lastYellowCardPlayerName), holdMillis: 800)
        }
        .onChange(of: live.substitutionFlashCount) { _, count in
            guard count > 0 else { return }
            triggerEventFlash(.substitution(offName: live.lastSubOffName, onName: live.lastSubOnName), holdMillis: 900)
        }
        .onChange(of: live.isHalfTime) { _, isHalfTime in
            guard isHalfTime else { return }
            triggerEventFlash(.halfTime(homeShort: live.homeShort, homeGoals: live.homeGoals,
                                        awayGoals: live.awayGoals, awayShort: live.awayShort))
        }
        .onChange(of: live.injuredOut.count) { _, count in
            guard count > 0, let last = live.injuredOut.last else { return }
            let squad = last.side == .home ? live.homeOnPitch : live.awayOnPitch
            guard let name = squad.first(where: { $0.id == last.id })?.player.name else { return }
            triggerEventFlash(.injury(playerName: name))
        }
        .onChange(of: live.isFinished) { _, finished in
            guard finished else { return }
            if userWon { Haptics.success() } else if userDrew { Haptics.warning() } else { Haptics.error() }
            // A title/promotion clincher on the final day upstages the
            // man-of-the-match flash — one big broadcast climax, not two.
            if let climax = store.climaxFlash(for: live) {
                triggerEventFlash(climax, holdMillis: 3200)
            } else if !live.motmName.isEmpty {
                let rating = live.userPlayerRatings.first?.rating ?? 0
                triggerEventFlash(.playerOfTheMatch(name: live.motmName, rating: rating))
            }
        }
        .sheet(isPresented: $showSubs) { SubsSheet(live: live) }
    }

    /// A quick, punchy stylized flash for match moments that don't have
    /// (and don't need) dedicated bundled art — solid colour, bold text,
    /// same CRT-broadcast timing as the goal/penalty/red-card flashes.
    /// Celebratory moments (promotion/title) also get a screen shake and
    /// a burst of crowd confetti, on top of the longer hold the caller passes.
    private func triggerEventFlash(_ kind: MatchFlashKind, holdMillis: Int = 1200) {
        if kind.isCelebratory {
            Haptics.success()
            shakeTrigger += 1
            confettiColors = [store.userColor, Retro.gold, Retro.accent]
            withAnimation(.easeIn(duration: 0.1)) { showConfetti = true }
        } else {
            Haptics.tap()
        }
        withAnimation(.easeIn(duration: 0.15)) { eventFlash = kind }
        Task {
            try? await Task.sleep(for: .milliseconds(holdMillis))
            withAnimation(.easeOut(duration: 0.3)) { eventFlash = nil }
            if kind.isCelebratory {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation { showConfetti = false }
            }
        }
    }

    private func triggerPenaltyFlash() {
        guard !live.isFinished else { return }
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.15)) { penaltyFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            withAnimation(.easeOut(duration: 0.3)) { penaltyFlash = false }
        }
    }

    private var penaltyFlashOverlay: some View {
        GeometryReader { geo in
            Image("PenaltyAwarded")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .scaleEffect(penaltyFlash ? 1.0 : 0.6)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func triggerRedCardFlash() {
        guard !live.isFinished else { return }
        Haptics.error()
        shakeTrigger += 1
        withAnimation(.easeIn(duration: 0.15)) { redCardFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.easeOut(duration: 0.3)) { redCardFlash = false }
        }
    }

    private var redCardFlashOverlay: some View {
        GeometryReader { geo in
            Image("RedCardFlash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .scaleEffect(redCardFlash ? 1.0 : 0.6)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// A penalty conversion waits for the "PENALTY!" flash to finish
    /// before showing the goal flash, so the two don't collide — an
    /// open-play goal still flashes immediately.
    private func triggerGoalFlash(side: Side) {
        guard !live.isFinished else { return }
        let scoringIndex = side == .home ? live.homeIndex : live.awayIndex
        goalFlashColor = store.color(forClubIndex: scoringIndex)
        goalFlashText = side == live.userSide ? "GOAL!!!" : "GOAL AGAINST"
        let wasPenalty = live.events.last?.type == .penalty
        Task {
            if wasPenalty { try? await Task.sleep(for: .milliseconds(1100)) }
            if side == live.userSide {
                Haptics.success()
                shakeTrigger += 1
                confettiColors = [store.color(forClubIndex: scoringIndex), Retro.gold]
                withAnimation(.easeIn(duration: 0.1)) { showConfetti = true }
            } else {
                Haptics.error()
            }
            withAnimation(.easeIn(duration: 0.15)) { goalFlash = true }
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.4)) { goalFlash = false }
            if side == live.userSide {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { showConfetti = false }
            }
        }
    }

    /// Each side of a goal gets its own full-bleed photo behind the flash
    /// text — the celebration shot when the user scores, the dejected
    /// keeper shot when they concede — instead of one flat colour flash
    /// doing double duty for both.
    private var isUserGoalFlash: Bool { goalFlashText == "GOAL!!!" }

    private var goalFlashOverlay: some View {
        ZStack {
            GeometryReader { geo in
                Image(isUserGoalFlash ? "GoalCelebration" : "GoalAgainst")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            (isUserGoalFlash ? Retro.background : Color.black).opacity(0.30).ignoresSafeArea()
            VStack(spacing: 6) {
                Text("⚽︎")
                    .font(.system(size: 90))
                Text(goalFlashText)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                Text(live.commentary.last?.text ?? "")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .scaleEffect(goalFlash ? 1.0 : 0.6)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// A brief broadcast-style face-off card shown as the match view
    /// appears — crests, competition, stadium and atmosphere — sitting on
    /// top of the ticker for its first couple of seconds, same relationship
    /// every other flash already has to the base layout underneath.
    private var kickoffIntroOverlay: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 14) {
                if store.areRivals(live.homeName, live.awayName) {
                    Text("⚔️ DERBY DAY")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                }
                Text(live.competition.uppercased())
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                HStack(spacing: 24) {
                    CrestView(shortName: live.homeShort, size: 64, color: store.color(forClubIndex: live.homeIndex))
                    Text("VS")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    CrestView(shortName: live.awayShort, size: 64, color: store.color(forClubIndex: live.awayIndex))
                }
                Text(live.stadium)
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(.white)
                Text(store.matchAtmosphere(homeIndex: live.homeIndex, awayIndex: live.awayIndex))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Commentary

    private var commentaryFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(live.commentary.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced)
                                .weight(line.text.contains("GOAL") ? .bold : .regular))
                            .foregroundStyle(commentaryColor(line.text))
                            .multilineTextAlignment(commentaryAlignment(line.side))
                            .frame(maxWidth: .infinity, alignment: commentaryFrameAlignment(line.side))
                            .id(index)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: live.commentary.count) { _, _ in
                withAnimation { proxy.scrollTo(live.commentary.count - 1, anchor: .bottom) }
            }
        }
    }

    /// Home-side commentary reads on the left, away-side on the right —
    /// matching the score bar's own home-first, away-second order — with
    /// neutral lines (kick-off, half-time, full-time) centred.
    private func commentaryFrameAlignment(_ side: Side?) -> Alignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil:   return .center
        }
    }

    private func commentaryAlignment(_ side: Side?) -> TextAlignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil:   return .center
        }
    }

    private func commentaryColor(_ line: String) -> Color {
        if line.contains("GOAL") { return Retro.highlight }
        if line.contains("RED CARD") { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if line.contains("booked") { return Color(red: 0.95, green: 0.85, blue: 0.35) }
        if line.contains("Full-time") || line.contains("Half-time") || line.contains("Kick-off") { return Retro.accent }
        return Retro.text.opacity(0.9)
    }

    // MARK: Score bar

    private var scoreBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text(clockText)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(statusColor)
                    .frame(width: 64, alignment: .leading)
                Spacer()
                HStack(spacing: 10) {
                    Text(live.homeShort)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(live.homeGoals) - \(live.awayGoals)")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .monospacedDigit()
                    Text(live.awayShort)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("career.match.score")
                .accessibilityLabel("\(live.homeName) \(live.homeGoals), \(live.awayName) \(live.awayGoals)")
                Spacer()
                playPauseButton
            }
            progressDots
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
    }

    private var clockText: String {
        if live.isFinished { return "FT" }
        if live.isHalfTime { return "HT" }
        if live.minute <= 90 { return "\(live.minute)'" }
        return "90+\(live.minute - 90)'"
    }

    private var statusColor: Color {
        if live.isFinished { return Retro.highlight }
        if live.isHalfTime { return Retro.highlight }
        return Retro.accent
    }

    private var progressDots: some View {
        let total = 24
        let filled = Int(Double(min(live.minute, live.totalMinutes)) / Double(max(live.totalMinutes, 1)) * Double(total))
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Retro.accent : Retro.text.opacity(0.2))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var playPauseButton: some View {
        let playing = !live.isPaused && !live.isHalfTime && !live.isFinished
        return Button {
            if live.isFinished { return }
            playing ? live.pause() : live.resume()
        } label: {
            Text(live.isFinished ? "FULL TIME" : (playing ? "⏸ PAUSE" : "▶ PLAY"))
                .font(.system(.callout, design: .monospaced).bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(playing ? Retro.highlight : Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(live.isFinished)
        .accessibilityIdentifier("career.match.pause")
    }

    // MARK: Stats

    private var statsBlock: some View {
        VStack(spacing: 8) {
            Text("\(live.stadium) · Att. \(live.attendance.formatted())")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if compact {
                // Phone landscape: the six fixed rows squeezed the
                // commentary feed off-screen entirely. One dense line
                // keeps possession, shots and ratings readable while the
                // feed gets the room; the half-time overlay still shows
                // the full six-row recap from the same `matchStatPairs`.
                compactStatsRow
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(matchStatPairs.enumerated()), id: \.offset) { _, stat in
                        statRow(home: stat.0, label: stat.1, away: stat.2)
                    }
                }
                .accessibilityIdentifier("career.match.stats")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// The condensed always-visible stat line for phone landscape —
    /// purely derived from the same live values the full rows read, no
    /// new engine state.
    private var compactStatsRow: some View {
        let userPoss = live.userSide == .home ? live.homePossession : 100 - live.homePossession
        let pair = live.userSide == .home
            ? (live.shots.home, live.shots.away, live.shotsOnTarget.home, live.shotsOnTarget.away)
            : (live.shots.away, live.shots.home, live.shotsOnTarget.away, live.shotsOnTarget.home)
        let userRating = live.userSide == .home ? live.teamRating.home : live.teamRating.away
        let oppRating = live.userSide == .home ? live.teamRating.away : live.teamRating.home
        return Text("POSS \(userPoss)% · SHOTS \(pair.0) (\(pair.2)) vs \(pair.1) (\(pair.3)) · RAT \(ratingText(userRating)) vs \(ratingText(oppRating))")
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(Retro.text.opacity(0.85))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("career.match.statsLine")
            .accessibilityLabel("You \(pair.0) shots, \(pair.2) on target, possession \(userPoss) percent, team rating \(ratingText(userRating)). Opponent \(pair.1) shots, \(pair.3) on target, rating \(ratingText(oppRating)).")
    }

    /// The live head-to-head stat rows — shared by the always-visible
    /// `statsBlock` and the half-time summary overlay, so the break gets
    /// a real recap of the same numbers rather than duplicated logic.
    private var matchStatPairs: [(String, String, String)] {
        [
            ("\(live.homePossession)%", "POSSESSION", "\(100 - live.homePossession)%"),
            ("\(live.shots.home) (\(live.shotsOnTarget.home))", "SHOTS (ON TGT)", "\(live.shots.away) (\(live.shotsOnTarget.away))"),
            ("\(live.clearCut.home)", "CLEAR CUT", "\(live.clearCut.away)"),
            ("\(live.offsides.home)", "OFFSIDES", "\(live.offsides.away)"),
            (ratingText(live.teamRating.home), "TEAM RATING", ratingText(live.teamRating.away)),
            ("\(live.corners.home)", "CORNERS", "\(live.corners.away)"),
        ]
    }

    /// A short, purely derived read on how the half has gone — scoreline
    /// first, then shot count as a tie-breaker — no new engine state.
    private var halfTimeNarrative: String {
        if userGoals > opponentGoals { return "You're ahead at the break — keep it going." }
        if userGoals < opponentGoals { return "Time for a rethink — you're behind at the break." }
        let userShots = live.userSide == .home ? live.shots.home : live.shots.away
        let opponentShots = live.userSide == .home ? live.shots.away : live.shots.home
        if userShots > opponentShots + 2 { return "You've had the better of it, but the scoreline doesn't show it yet." }
        if opponentShots > userShots + 2 { return "They've had the better chances — tighten up after the break." }
        return "Level at the break — anyone's game."
    }

    private var halfTimeSummaryOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("HALF TIME")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text("\(live.homeName) \(live.homeGoals) - \(live.awayGoals) \(live.awayName)")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .multilineTextAlignment(.center)
                Text(halfTimeNarrative)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Retro.text)
                    .multilineTextAlignment(.center)
                VStack(spacing: 6) {
                    ForEach(Array(matchStatPairs.enumerated()), id: \.offset) { _, stat in
                        statRow(home: stat.0, label: stat.1, away: stat.2)
                    }
                }
                Button {
                    live.resume()
                } label: {
                    Text("CONTINUE TO 2ND HALF ▸")
                        .font(.system(.body, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Retro.accent)
                        .foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(Retro.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(24)
        }
    }

    private func statRow(home: String, label: String, away: String) -> some View {
        HStack {
            Text(home)
                .foregroundStyle(Retro.accent)
                .frame(width: 64, alignment: .leading)
            Spacer()
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
            Spacer()
            Text(away)
                .foregroundStyle(Retro.text)
                .frame(width: 64, alignment: .trailing)
        }
        .font(.system(.callout, design: .monospaced).bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func ratingText(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private var infoRow: some View {
        HStack {
            Text(live.competition)
            Spacer()
            Text("\(live.weather.glyph) \(live.weather.rawValue)")
            Spacer()
            Text(live.dateText)
        }
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(Retro.text.opacity(0.7))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: Controls

    private var controlBar: some View {
        VStack(spacing: 6) {
            momentumBar
            possessionBar
            if compact {
                // Phone landscape: two balanced rows keep every control
                // tappable at ~40pt heights instead of one overstuffed
                // row that clipped the mentality/instruction menus.
                HStack(spacing: 8) {
                    ForEach([1.0, 2.0, 3.0], id: \.self) { value in
                        speedButton(value)
                    }

                    barButton("SKIP") { live.skipToEnd() }

                    Spacer()

                    barButton("SUBS \(live.userSubsLeft)/5") { showSubs = true }
                        .disabled(live.userSubsLeft == 0)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("career.match.controlsRow1")

                HStack(spacing: 8) {
                    Text("MENTALITY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Picker("Mentality", selection: Binding(
                        get: { live.userMentality },
                        set: { live.userMentality = $0 }
                    )) {
                        ForEach(Mentality.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Retro.accent)
                    .accessibilityIdentifier("career.match.mentality")

                    Text("INSTRUCTION")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Picker("Instruction", selection: Binding(
                        get: { live.userInstruction },
                        set: { live.userInstruction = $0 }
                    )) {
                        ForEach(MatchInstruction.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Retro.highlight)
                    .accessibilityIdentifier("career.match.instruction")

                    Spacer()
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("career.match.controlsRow2")
            } else {
                HStack(spacing: 8) {
                    ForEach([1.0, 2.0, 3.0], id: \.self) { value in
                        speedButton(value)
                    }

                    barButton("SKIP") { live.skipToEnd() }

                    Spacer()

                    Picker("Mentality", selection: Binding(
                        get: { live.userMentality },
                        set: { live.userMentality = $0 }
                    )) {
                        ForEach(Mentality.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Retro.accent)
                    .accessibilityIdentifier("career.match.mentality")

                    Picker("Instruction", selection: Binding(
                        get: { live.userInstruction },
                        set: { live.userInstruction = $0 }
                    )) {
                        ForEach(MatchInstruction.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Retro.highlight)
                    .accessibilityIdentifier("career.match.instruction")

                    barButton("SUBS \(live.userSubsLeft)/5") { showSubs = true }
                        .disabled(live.userSubsLeft == 0)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.match.controlBar")
    }

    private func speedButton(_ value: Double) -> some View {
        Button {
            live.setSpeed(value)
        } label: {
            Text("\(Int(value))×")
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(live.speed == value ? Retro.accent : Retro.panel)
                .foregroundStyle(live.speed == value ? Retro.background : Retro.text)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("career.match.speed.\(Int(value))")
        .accessibilityLabel("Speed \(Int(value)) times")
        .accessibilityAddTraits(live.speed == value ? [.isSelected] : [])
    }

    private var possessionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(store.color(forClubIndex: live.homeIndex))
                    .frame(width: geo.size.width * CGFloat(live.homePossession) / 100)
                Rectangle().fill(store.color(forClubIndex: live.awayIndex))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var momentumBar: some View {
        VStack(spacing: 2) {
            HStack {
                Text("MOMENTUM")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
            }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    store.color(forClubIndex: live.homeIndex)
                        .frame(width: geo.size.width * CGFloat(live.momentum))
                    store.color(forClubIndex: live.awayIndex)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }

    private func barButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(title == "SKIP" ? "career.match.skip" : "career.match.bar.\(title)")
    }

    // MARK: Full time

    /// The full-time presentation: one scroll container for the result
    /// story (verdict, score, MOTM, ratings, interview) with CONTINUE
    /// pinned in a footer bar, so the way out is never below the fold on
    /// compact phone landscape. The result, ratings, interview effects
    /// and the `finishLiveMatch()` commit are exactly the pre-existing
    /// production paths — this is a presentation redesign only.
    private var fullTimeOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ScrollView {
                        fullTimeCard
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    }
                }
                fullTimeFooter
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("career.postMatch.screen")
    }

    /// CONTINUE lives outside the scroll container so it stays reachable
    /// at every size class; the commit path is unchanged.
    private var fullTimeFooter: some View {
        VStack(spacing: 0) {
            Divider().overlay(Retro.accent.opacity(0.4))
            Button {
                store.finishLiveMatch()
            } label: {
                Text("CONTINUE ▸")
                    .font(.system(.body, design: .monospaced).bold())
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.vertical, 8)
                    .background(Retro.accent)
                    .foregroundStyle(Retro.background)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("career.postMatch.continue")
        }
        .background(Retro.panel)
    }

    private var fullTimeCard: some View {
        VStack(spacing: 12) {
            Text("FULL TIME")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.8))

            // The verdict leads: outcome word in the result's colour,
            // then the score, so the hierarchy reads result → score → story.
            Text(fullTimeVerdict.title)
                .font(.system(.title, design: .monospaced).bold())
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(fullTimeVerdict.color)
                .foregroundStyle(Retro.background)
                .clipShape(Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("career.postMatch.verdict")
                .accessibilityLabel("\(fullTimeVerdict.title). You \(userWon ? "won" : userDrew ? "drew" : "lost") \(userGoals)-\(opponentGoals) \(userDrew ? "with" : "against") \(live.userSide == .home ? live.awayName : live.homeName)")

            Text("\(live.homeName) \(live.homeGoals) - \(live.awayGoals) \(live.awayName)")
                .font(.system(.title3, design: .monospaced).bold())
                .monospacedDigit()
                .foregroundStyle(Retro.highlight)
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("career.postMatch.score")

            Text(fullTimeVerdict.flavor)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.9))
                .multilineTextAlignment(.center)

            if store.areRivals(live.homeName, live.awayName) {
                Text(userWon ? "Bragging rights are yours." : (userDrew ? "Honours even in the derby." : "A tough day in the derby."))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
            }

            if let motm = live.userPlayerRatings.first, !live.motmName.isEmpty {
                motmCard(name: live.motmName, rating: motm.rating)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("career.postMatch.motm")
                    .accessibilityLabel("Man of the match \(live.motmName), rating \(String(format: "%.1f", motm.rating))")
            }

            Text("YOUR PLAYER RATINGS")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.8))
            // Flat list in the overlay's single scroll container — the
            // old nested ScrollView trapped scrolling on compact phones.
            VStack(spacing: 3) {
                ForEach(Array(live.userPlayerRatings.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(surname(entry.player.name))
                        Spacer()
                        Text(String(format: "%.1f", entry.rating))
                            .foregroundStyle(ratingColor(entry.rating))
                            .bold()
                    }
                    .font(.system(.callout, design: .monospaced))
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("career.postMatch.ratingRow")
                    .accessibilityLabel("\(entry.player.name), rating \(String(format: "%.1f", entry.rating))")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("career.postMatch.ratings")

            if !interviewAnswered {
                let question = store.makePostMatchInterview(won: userWon, draw: userDrew)
                VStack(spacing: 6) {
                    Text("🎙 \(question.prompt)")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        ForEach(question.options) { option in
                            Button {
                                store.answerPress(option, headline: "Post-match interview")
                                interviewAnswered = true
                            } label: {
                                Text(option.label)
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Retro.panel)
                                    .foregroundStyle(Retro.text)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("career.postMatch.interviewOption")
                        }
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("career.postMatch.interview")
            } else {
                Text("🎙 Interview filed.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(Retro.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    /// The result verdict shown above the score — derived purely from the
    /// finished match, mirroring how `finishLiveMatch` classifies it.
    private var fullTimeVerdict: PostMatchVerdict {
        PostMatchVerdict(won: userWon, drew: userDrew)
    }

    /// A small standout card for the Man of the Match — previously a
    /// single plain text line lost above the ratings list.
    private func motmCard(name: String, rating: Double) -> some View {
        HStack(spacing: 10) {
            Text("⭐")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 1) {
                Text("MAN OF THE MATCH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Text(name)
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
            }
            Spacer()
            Text(String(format: "%.1f", rating))
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Retro.gold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.gold.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func ratingColor(_ value: Double) -> Color {
        switch value {
        case 7.5...: return Retro.highlight
        case 6.5..<7.5: return Retro.accent
        default: return Retro.text
        }
    }
}

// MARK: - Substitutions sheet

struct SubsSheet: View {
    let live: LiveMatch
    @Environment(\.dismiss) private var dismiss
    @State private var offID: UUID?
    @State private var onID: UUID?

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SUBSTITUTIONS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Text("\(live.userSubsLeft) remaining")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.highlight)
                }

                HStack(alignment: .top, spacing: 12) {
                    column(title: "OFF (on pitch)", players: live.userOnPitch.map { ($0.player, Int($0.energy)) },
                           selected: offID) { offID = $0 }
                    column(title: "ON (bench)", players: live.userBench.map { ($0, nil) },
                           selected: onID) { onID = $0 }
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Button {
                        if let offID, let onID,
                           let off = live.userOnPitch.first(where: { $0.id == offID }),
                           let on = live.userBench.first(where: { $0.id == onID }) {
                            live.makeUserSub(off: off, on: on)
                            dismiss()
                        }
                    } label: {
                        Text("MAKE SUB")
                            .font(.system(.body, design: .monospaced).bold())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(canSub ? Retro.accent : Retro.panel)
                            .foregroundStyle(canSub ? Retro.background : Retro.text.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSub)
                }
            }
            .padding()
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private var canSub: Bool {
        offID != nil && onID != nil && live.userSubsLeft > 0
    }

    private func column(title: String, players: [(Player, Int?)], selected: UUID?,
                        onSelect: @escaping (UUID) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.85))
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(players, id: \.0.id) { player, energy in
                        Button {
                            onSelect(player.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(player.careerPositionLabel)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .frame(width: 30)
                                    .foregroundStyle(Retro.highlight)
                                Text(surname(player.name))
                                    .lineLimit(1)
                                Spacer()
                                if let energy {
                                    Text("\(energy)%")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(energy < 70 ? Retro.highlight : Retro.text.opacity(0.7))
                                } else {
                                    Text("\(player.rating)")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundStyle(Retro.accent)
                                }
                            }
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selected == player.id ? Retro.token.opacity(0.6) : Retro.panel.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The full-time presentation verdict, shared by the redesigned overlay
/// and its tests. Purely presentational: `finishLiveMatch` classifies the
/// result independently from `won`/`draw`, which this mirrors but never
/// feeds.
enum PostMatchVerdict {
    case win
    case draw
    case loss

    init(won: Bool, drew: Bool) {
        self = won ? .win : (drew ? .draw : .loss)
    }

    var title: String {
        switch self {
        case .win: return "VICTORY"
        case .draw: return "DRAW"
        case .loss: return "DEFEAT"
        }
    }

    /// The verdict's colour, drawn from the brand palette: emerald for the
    /// high, gold for the point earned, warning red for the defeat.
    var color: Color {
        switch self {
        case .win: return Retro.accent
        case .draw: return Retro.highlight
        case .loss: return Retro.warning
        }
    }

    /// A short verdict line under the score.
    var flavor: String {
        switch self {
        case .win: return "A win to celebrate."
        case .draw: return "Honours even."
        case .loss: return "Not our day — regroup and go again."
        }
    }
}
