//
//  MatchDayView.swift
//  Retro Season Manager
//
//  Pre-match preparation, the live match screen, and the
//  substitutions sheet.
//

import SwiftUI

// MARK: - Pre-match hub

struct PreMatchHubView: View {
    let store: GameStore

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(Retro.accent.opacity(0.25)).frame(height: 1)
                if let match = store.nextUserMatchInfo {
                    content(for: match)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CrestView(shortName: store.userClub.shortName, size: 34, color: store.userColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.userClub.name)
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(store.userColor)
                Text("Pre-Match Hub")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            Spacer()
            Button { store.atPreMatch = false } label: {
                Text("BACK")
                    .font(.system(.callout, design: .monospaced).bold())
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Retro.panel).foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            Button { store.beginUserMatch() } label: {
                Text("KICK OFF ▸")
                    .font(.system(.callout, design: .monospaced).bold())
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Retro.highlight).foregroundStyle(Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func content(for match: UserMatchInfo) -> some View {
        let isHome = match.homeIndex == store.userClubIndex
        let opponentIndex = isHome ? match.awayIndex : match.homeIndex
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(match.label.uppercased())
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(match.isCup ? Retro.highlight : Retro.accent)
                    .padding(.horizontal, 14)
                if let talk = store.pendingTeamTalk {
                    teamTalkPanel(talk).padding(.horizontal, 14)
                }
                if let question = store.pendingPressQuestion {
                    pressPanel(question).padding(.horizontal, 14)
                }
                HStack(alignment: .top, spacing: 14) {
                    // Left: the match-up, your form, and the broadcast-style extras.
                    VStack(spacing: 14) {
                        matchupPanel(opponentIndex: opponentIndex, isHome: isHome)
                        keyPlayersPanel(opponentIndex: opponentIndex)
                        lineupsPanel(opponentIndex: opponentIndex)
                        predictionPanel(opponentIndex: opponentIndex, isHome: isHome)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    // Right: opponent scouting report.
                    opponentPanel(opponentIndex: opponentIndex)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 12)
        }
    }

    private func matchupPanel(opponentIndex: Int, isHome: Bool) -> some View {
        let opponent = store.clubs[opponentIndex]
        let ratings = store.starRatings(forClubIndices: [store.userClubIndex, opponentIndex])
        let homeIndex = isHome ? store.userClubIndex : opponentIndex
        let awayIndex = isHome ? opponentIndex : store.userClubIndex
        return Panel(title: store.nextMatchIsDerby ? "⚔️ DERBY DAY" : "THE FIXTURE") {
            VStack(spacing: 10) {
                if store.nextMatchIsDerby {
                    Text(derbyFlavorText(opponentIndex: opponentIndex))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.highlight)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                HStack {
                    teamBadge(store.userClub.shortName, store.userClub.name, ratings[store.userClubIndex] ?? 1, store.userColor)
                    Text(isHome ? "vs" : "@")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    teamBadge(opponent.shortName, opponent.name, ratings[opponentIndex] ?? 1, store.color(forClubIndex: opponentIndex))
                }
                Text(store.matchAtmosphere(homeIndex: homeIndex, awayIndex: awayIndex))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                HStack {
                    Text("Your form")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                    FormView(outcomes: store.recentForm(forClubIndex: store.userClubIndex))
                }
                HStack {
                    Text("\(opponent.shortName) form")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                    FormView(outcomes: store.recentForm(forClubIndex: opponentIndex))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(store.nextMatchIsDerby ? Retro.highlight.opacity(0.6) : Color.clear, lineWidth: 2)
        )
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

    private func keyPlayersPanel(opponentIndex: Int) -> some View {
        Panel(title: "ONES TO WATCH") {
            HStack(spacing: 16) {
                if let key = store.keyPlayer(forClubIndex: store.userClubIndex) {
                    keyPlayerCard(key, store.userClub.shortName, store.userColor)
                }
                if let key = store.keyPlayer(forClubIndex: opponentIndex) {
                    keyPlayerCard(key, store.clubs[opponentIndex].shortName, store.color(forClubIndex: opponentIndex))
                }
            }
        }
    }

    private func keyPlayerCard(_ player: Player, _ clubShort: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(clubShort.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(player.name)
                .font(.system(.footnote, design: .monospaced).bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("\(player.rating) OVR")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// A read-only confirmed-lineups display — deliberately not the
    /// editable `PitchView` (bound to `store.userStarterIDs`/`slotPins`,
    /// tap-to-edit), just a simple two-column list built from the exact
    /// XI the match engine itself will field for either side.
    private func lineupsPanel(opponentIndex: Int) -> some View {
        let userXI = store.matchXIForPreview(store.userClubIndex).sorted { $0.position.order < $1.position.order }
        let opponentXI = store.matchXIForPreview(opponentIndex).sorted { $0.position.order < $1.position.order }
        return Panel(title: "CONFIRMED LINEUPS") {
            HStack(alignment: .top, spacing: 16) {
                lineupColumn(store.userClub.shortName, userXI)
                lineupColumn(store.clubs[opponentIndex].shortName, opponentXI)
            }
        }
    }

    private func lineupColumn(_ short: String, _ xi: [Player]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(short.uppercased())
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            ForEach(xi) { player in
                HStack(spacing: 6) {
                    Text(player.position.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .frame(width: 28, alignment: .leading)
                        .foregroundStyle(Retro.highlight)
                    Text(surname(player.name))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func teamBadge(_ short: String, _ name: String, _ stars: Int, _ color: Color = Retro.accent) -> some View {
        VStack(spacing: 4) {
            CrestView(shortName: short, size: 44, color: color)
            Text(name)
                .font(.system(.caption, design: .monospaced).bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
            StarRatingView(stars: stars)
        }
        .frame(maxWidth: .infinity)
    }

    private func predictionPanel(opponentIndex: Int, isHome: Bool) -> some View {
        let homeIndex = isHome ? store.userClubIndex : opponentIndex
        let awayIndex = isHome ? opponentIndex : store.userClubIndex
        let probs = store.outcomeProbabilities(homeIndex: homeIndex, awayIndex: awayIndex)
        let userWin = Int(((isHome ? probs.home : probs.away) * 100).rounded())
        let draw = Int((probs.draw * 100).rounded())
        let oppWin = max(0, 100 - userWin - draw)
        return Panel(title: "MATCH ODDS") {
            HStack {
                oddsChip("You", userWin, userWin >= oppWin && userWin >= draw)
                oddsChip("Draw", draw, draw > userWin && draw > oppWin)
                oddsChip(store.clubs[opponentIndex].shortName, oppWin, oppWin > userWin && oppWin >= draw)
            }
        }
    }

    private func oddsChip(_ title: String, _ pct: Int, _ favourite: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(.caption2, design: .monospaced)).lineLimit(1)
            Text("\(pct)%")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(favourite ? Retro.highlight : Retro.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Retro.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func opponentPanel(opponentIndex: Int) -> some View {
        let opponent = store.clubs[opponentIndex]
        return Panel(title: opponent.name.uppercased()) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Style", store.playStyle(forClubIndex: opponentIndex))
                infoRow("Formation", store.formationName(forClubIndex: opponentIndex))
                infoRow("Manager", store.manager(forClubIndex: opponentIndex))
                if let key = store.keyPlayer(forClubIndex: opponentIndex) {
                    infoRow("Key player", "\(key.name) (\(key.rating))")
                }
                if let identity = store.clubIdentity(forClubIndex: opponentIndex) {
                    Text(identity.flavorText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().overlay(Retro.accent.opacity(0.2))
                HStack(alignment: .top, spacing: 16) {
                    strengthsColumn("STRENGTHS", store.teamStrengths(forClubIndex: opponentIndex), Retro.accent)
                    strengthsColumn("WEAKNESSES", store.teamWeaknesses(forClubIndex: opponentIndex), Retro.highlight)
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            Text(value).bold()
        }
        .font(.system(.callout, design: .monospaced))
    }

    private func teamTalkPanel(_ question: PressQuestion) -> some View {
        Panel(title: "🗣 TEAM TALK") {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.prompt)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(question.options) { option in
                    Button { store.answerTeamTalk(option) } label: {
                        Text(option.label)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Retro.panel)
                            .foregroundStyle(Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pressPanel(_ question: PressQuestion) -> some View {
        Panel(title: "🎙 PRESS CONFERENCE") {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.prompt)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(question.options) { option in
                    Button { store.answerPress(option) } label: {
                        Text(option.label)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Retro.panel)
                            .foregroundStyle(Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func strengthsColumn(_ title: String, _ items: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.system(.footnote, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text(live.homeShort).fontWeight(.bold)
                    Text("\(live.homeGoals) - \(live.awayGoals)")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text(live.awayShort).fontWeight(.bold)
                }
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
    }

    // MARK: Stats

    private var statsBlock: some View {
        VStack(spacing: 8) {
            Text("\(live.stadium) · Att. \(live.attendance.formatted())")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))

            VStack(spacing: 6) {
                ForEach(Array(matchStatPairs.enumerated()), id: \.offset) { _, stat in
                    statRow(home: stat.0, label: stat.1, away: stat.2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 3.0], id: \.self) { value in
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

                Picker("Instruction", selection: Binding(
                    get: { live.userInstruction },
                    set: { live.userInstruction = $0 }
                )) {
                    ForEach(MatchInstruction.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Retro.highlight)

                barButton("SUBS \(live.userSubsLeft)/5") { showSubs = true }
                    .disabled(live.userSubsLeft == 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
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
    }

    // MARK: Full time

    private var fullTimeOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            GeometryReader { geo in
                ScrollView {
                    fullTimeCard
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
    }

    private var fullTimeCard: some View {
        VStack(spacing: 12) {
            Text("FULL TIME")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Text("\(live.homeName) \(live.homeGoals) - \(live.awayGoals) \(live.awayName)")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
                .multilineTextAlignment(.center)

            if store.areRivals(live.homeName, live.awayName) {
                Text(userWon ? "Bragging rights are yours." : (userDrew ? "Honours even in the derby." : "A tough day in the derby."))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
            }

            if let motm = live.userPlayerRatings.first, !live.motmName.isEmpty {
                motmCard(name: live.motmName, rating: motm.rating)
            }

            Text("YOUR PLAYER RATINGS")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.8))
            ScrollView {
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
                    }
                }
            }
            .frame(maxHeight: 130)

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
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                store.finishLiveMatch()
            } label: {
                Text("CONTINUE ▸")
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
                                Text(player.position.rawValue)
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

