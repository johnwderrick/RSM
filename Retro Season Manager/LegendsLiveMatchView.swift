//
//  LegendsLiveMatchView.swift
//  Retro Season Manager
//
//  The live match presentation for RSM Legends' full-parity match
//  engine (LegendsLiveMatch.swift) — mirrors MatchDayView.swift's
//  MatchView/SubsSheet composition (fixed score bar, flexible main
//  content, fixed control bar) restyled with Legends' own Retro chrome.
//  Reuses Career Mode's stadium background art and match "flash screen"
//  overlays (MatchFlashOverlay, PixelConfettiBurst, CRTScanlineOverlay,
//  matchShake) directly — all pure views with zero GameStore coupling.
//  Penalty/red-card flashes are intentionally not ported: this engine
//  only ever produces goal/half-time/full-time/sub events, so there's no
//  trigger for them.
//
//  The animated 2D pitch (`LegendsPitchCanvas`, LegendsLiveMatchPitchView.swift)
//  is the *default* main content as of Phase 6 of the 2D match simulator
//  — it used to live behind a "2D" debug button opening a separate sheet;
//  now this view owns the `LegendsMatchSimulation` driving it directly,
//  keeps its `speedMultiplier` in lockstep with `live.speed`/`isPaused`
//  so the pitch speeds up and freezes exactly in step with the
//  commentary, and forwards goal/big-chance commentary lines into
//  `simulation.triggerAttack(forUser:scored:)` plus substitutions into
//  `simulation.applySubstitution(...)` — so the pitch dots track the
//  real XI as it changes, not just the kickoff snapshot. The text
//  commentary feed is still one tap away via the control bar's toggle,
//  just no longer the default.
//

import SwiftUI

struct LegendsLiveMatchView: View {
    let store: LegendsStore
    let live: LegendsLiveMatch
    var onFinished: () -> Void
    /// Invoked when the player abandons the match early — the parent
    /// records a forfeit loss (see `abandonMatch()`), as opposed to
    /// `onFinished`, which carries the real result.
    var onAbandoned: () -> Void

    @State private var simulation: LegendsMatchSimulation
    @State private var showSubs = false
    @State private var showAbandonConfirm = false
    /// Which main content the score bar sits above — the animated pitch
    /// by default, or the scrolling text commentary one tap away.
    @State private var showCommentary = false
    /// The `id` of the newest commentary line already forwarded to the
    /// pitch — the anchor `reactToLatestCommentary` diffs against, so a
    /// tick that appends two lines (a goal and a big chance in the same
    /// minute) forwards *both* rather than only the newest. Compared by
    /// stable id rather than index because the feed is trimmed to 60
    /// lines from the front, which would otherwise shift indices.
    @State private var lastHandledCommentaryID: UUID?
    @State private var hasFinishedHandoff = false

    @State private var goalFlash = false
    @State private var isUserGoalFlash = true
    @State private var goalFlashText = "GOAL!"
    @State private var eventFlash: MatchFlashKind? = nil
    @State private var shakeTrigger = 0
    @State private var showConfetti = false
    @State private var confettiColors: [Color] = []

    private var userColor: Color { Color(rgb: store.profile.crestColorRGB) }

    init(store: LegendsStore, live: LegendsLiveMatch, onFinished: @escaping () -> Void, onAbandoned: @escaping () -> Void) {
        self.store = store
        self.live = live
        self.onFinished = onFinished
        self.onAbandoned = onAbandoned

        let userSlots: [(role: DetailedPosition, id: String, name: String)] = Array(
            zip(store.startingXISlots, live.onPitchCardIDs).enumerated()
        ).map { index, pair in
            let (role, cardID) = pair
            let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            return (role, cardID ?? "user-slot-\(index)", card?.name ?? "—")
        }
        // Point 2: hand the sim each on-pitch card's *effective* detailed
        // attributes (base + condition modifier, the same values the live
        // engine selects with) keyed by slot id, so the 2D runner/marker
        // casting selects on real player quality.
        let userDetailedAttributes: [String: LegendsDetailedAttributes] = userSlots.reduce(into: [:]) { result, slot in
            // A malformed legacy XI must never trap the view transition.
            // LegendsLiveMatch already normalizes duplicates, but keeping
            // dictionary construction defensive makes this initializer safe
            // even when it is exercised independently in previews/tests.
            guard result[slot.id] == nil,
                  let card = LegendsCardDatabase.all.first(where: { $0.id == slot.id }) else {
                return
            }
            result[slot.id] = store.effectiveDetailedAttributes(for: card)
        }
        let opponentRoster = LegendsOpponentRoster.generateRoster(for: live.opponent)
        _simulation = State(initialValue: LegendsMatchSimulation(
            userSlots: userSlots,
            userFormation: store.formation,
            opponentFormation: opponentRoster.formation,
            opponentPlayers: opponentRoster.players,
            userDetailedAttributes: userDetailedAttributes
        ))
    }

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
                if showCommentary {
                    commentaryFeed
                } else {
                    pitchContent
                }
                Divider().background(Retro.accent.opacity(0.2))
                controlBar
            }

            if goalFlash { goalFlashOverlay }
            if let eventFlash { MatchFlashOverlay(kind: eventFlash) }
            if showConfetti { PixelConfettiBurst(colors: confettiColors) }
            if live.isFinished { fullTimeOverlay }
            CRTScanlineOverlay()
        }
        .matchShake(trigger: shakeTrigger)
        .onAppear {
            live.start()
            simulation.speedMultiplier = live.isPaused ? 0 : live.speed
            simulation.start()
        }
        .onDisappear {
            live.stop()
            simulation.stop()
        }
        .onChange(of: live.teamGoals) { _, _ in triggerGoalFlash(isUser: true) }
        .onChange(of: live.opponentGoals) { _, _ in triggerGoalFlash(isUser: false) }
        .onChange(of: live.isHalfTime) { _, isHalfTime in if isHalfTime { triggerHalfTimeFlash() } }
        .onChange(of: live.isFinished) { _, finished in if finished { triggerFullTimeConfettiIfWon() } }
        .onChange(of: live.speed) { _, newSpeed in simulation.speedMultiplier = live.isPaused ? 0 : newSpeed }
        .onChange(of: live.isPaused) { _, isPaused in simulation.speedMultiplier = isPaused ? 0 : live.speed }
        .onChange(of: live.commentary.count) { _, _ in reactToLatestCommentary() }
        .onChange(of: live.onPitchCardIDs) { oldIDs, newIDs in
            applyPitchSubstitutions(from: oldIDs, to: newIDs)
        }
        .sheet(isPresented: $showSubs) {
            LegendsSubsSheet(live: live)
        }
        .alert("Abandon match?", isPresented: $showAbandonConfirm) {
            Button("Keep playing", role: .cancel) {}
            Button("Abandon — counts as a 0–3 loss", role: .destructive) {
                abandonMatch()
            }
        } message: {
            Text("The match will end immediately and be recorded as a defeat.")
        }
    }

    /// Ends the match early: stops the engine's live loop and the pitch
    /// simulation (both tasks cancelled cleanly, nothing else ticks), then
    /// hands off so the parent can record a forfeit loss. Guarded by
    /// `hasFinishedHandoff` so a double-tap can't apply the outcome twice.
    private func abandonMatch() {
        guard !hasFinishedHandoff else { return }
        hasFinishedHandoff = true
        Haptics.warning()
        live.stop()
        simulation.stop()
        onAbandoned()
    }

    private var pitchContent: some View {
        LegendsPitchCanvas(simulation: simulation, userColor: userColor, opponentColor: opponentBadgeColor,
                           userName: store.profile.clubName, opponentName: live.opponent.name)
            .padding(.horizontal)
            .padding(.vertical, 6)
    }

    /// Reads every commentary line appended since the last one this
    /// method handled and, for each that's a goal or a big chance, fires
    /// the matching attack sequence on the pitch — diffing against
    /// `lastHandledCommentaryID` rather than only reading `.last`, since
    /// `LegendsLiveMatch` can append two lines in one tick (each side is
    /// rolled independently) and the second would otherwise hide the
    /// first. Both sides now share the one "Big chance for X — the keeper
    /// stands tall!" template (matching Career Mode's own big-chance line
    /// in `LiveMatch.swift`) — a Legends near-miss is a save, not a
    /// wayward shot, so `triggerAttack`'s `scored: false` path can send
    /// the shot at the keeper rather than off into space. Everything else
    /// — kick-off, half-time, substitutions (always `side: .home`
    /// regardless of which team subs, since only the user has a bench to
    /// draw from) — is deliberately ignored by keying off the exact
    /// templates `LegendsLiveMatch.rollGoalChances()`/`scoreGoal(forUser:)`
    /// use, rather than just checking `side != nil`.
    private func reactToLatestCommentary() {
        let lines = live.commentary
        // The anchor may have been trimmed off the front of the 60-line
        // cap if a large batch of lines landed at once — in that case
        // everything still present is unhandled, so start from the top.
        let startIndex: Int
        if let anchor = lastHandledCommentaryID, let index = lines.firstIndex(where: { $0.id == anchor }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        guard startIndex < lines.count else { return }
        for line in lines[startIndex...] {
            guard let side = line.side else { continue }
            let forUser = side == .home
            if line.text.contains("⚽︎ GOAL") {
                simulation.triggerAttack(forUser: forUser, scored: true)
            } else if line.text.contains("Big chance for") {
                simulation.triggerAttack(forUser: forUser, scored: false)
            }
        }
        lastHandledCommentaryID = lines.last?.id
    }

    /// Syncs the pitch's user dots with a substitution: `makeUserSub`
    /// swaps one slot of `onPitchCardIDs` in place, so diff the old/new
    /// lists and hand each changed slot to
    /// `simulation.applySubstitution` — the departing card's dot becomes
    /// the incoming card (id + name) right where it stands, and the sim
    /// releases any active run override the departing player held.
    private func applyPitchSubstitutions(from oldIDs: [String?], to newIDs: [String?]) {
        guard newIDs.count == oldIDs.count else { return }
        for index in newIDs.indices where oldIDs[index] != newIDs[index] {
            let cardID = newIDs[index]
            let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            simulation.applySubstitution(slotIndex: index,
                                         cardID: cardID ?? "user-slot-\(index)",
                                         name: card?.name ?? "—",
                                         replacementDetailed: card.map { store.effectiveDetailedAttributes(for: $0) })
        }
    }

    // MARK: - Flash overlays (goal / half-time / confetti / scanline)

    private func triggerGoalFlash(isUser: Bool) {
        isUserGoalFlash = isUser
        goalFlashText = isUser ? "GOAL!!!" : "GOAL AGAINST"
        if isUser {
            Haptics.success()
            shakeTrigger += 1
            confettiColors = [userColor, Retro.gold, Retro.accent]
            withAnimation(.easeIn(duration: 0.1)) { showConfetti = true }
        } else {
            Haptics.error()
        }
        withAnimation(.easeIn(duration: 0.15)) { goalFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.4)) { goalFlash = false }
            if isUser {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { showConfetti = false }
            }
        }
    }

    private var goalFlashOverlay: some View {
        ZStack {
            Image(isUserGoalFlash ? "GoalCelebration" : "GoalAgainst")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            (isUserGoalFlash ? Retro.background : Color.black).opacity(0.30).ignoresSafeArea()
            VStack(spacing: 6) {
                Text("⚽︎").font(.system(size: 40))
                Text(goalFlashText)
                    .font(.system(.title, design: .monospaced).bold())
                    .foregroundStyle(.white)
                if let last = live.commentary.last {
                    Text(last.text)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            }
        }
        .scaleEffect(goalFlash ? 1.0 : 0.6)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func triggerHalfTimeFlash() {
        let awayShort = String(live.opponent.name.prefix(3)).uppercased()
        let kind = MatchFlashKind.halfTime(homeShort: store.profile.crestShort, homeGoals: live.teamGoals,
                                            awayGoals: live.opponentGoals, awayShort: awayShort)
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.15)) { eventFlash = kind }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeOut(duration: 0.3)) { eventFlash = nil }
        }
    }

    private func triggerFullTimeConfettiIfWon() {
        guard live.teamGoals > live.opponentGoals else { return }
        Haptics.success()
        confettiColors = [userColor, Retro.gold, Retro.accent]
        withAnimation(.easeIn(duration: 0.1)) { showConfetti = true }
    }

    // MARK: - Score bar

    private var opponentBadgeColor: Color {
        Color.distinctOpponentColor(seed: live.opponent.name, awayFromHue: Color.hue01(ofRGB: store.profile.crestColorRGB))
    }

    private var clockText: String {
        if live.isFinished { return "FT" }
        if live.isHalfTime { return "HT" }
        if live.minute > 90 { return "90+\(live.minute - 90)'" }
        return "\(live.minute)'"
    }

    private var scoreBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                CrestView(shortName: store.profile.crestShort, size: 34, color: Color(rgb: store.profile.crestColorRGB))
                Text(store.profile.clubName)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .lineLimit(1)

                Spacer()

                VStack(spacing: 2) {
                    Text("\(live.teamGoals) – \(live.opponentGoals)")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text(clockText)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.7))
                }

                Spacer()

                Text(live.opponent.name)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .lineLimit(1)
                ClubBadgeView(name: live.opponent.name, shortName: String(live.opponent.name.prefix(3)).uppercased(),
                              size: 34, primaryColor: opponentBadgeColor)

                playPauseButton
                abandonButton
            }

            minuteProgress
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
    }

    private var abandonButton: some View {
        Button {
            Haptics.tap()
            showAbandonConfirm = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(live.isFinished ? Retro.text.opacity(0.3) : Retro.warning)
                .frame(width: 32, height: 32)
                .background(Retro.background.opacity(0.6))
                .clipShape(Circle())
                .accessibilityLabel("Abandon match")
        }
        .buttonStyle(.plain)
        .disabled(live.isFinished)
    }

    private var playPauseButton: some View {
        Button {
            Haptics.tap()
            live.togglePause()
        } label: {
            Text(live.isFinished ? "FT" : (live.isPaused ? "▶" : "⏸"))
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(live.isFinished ? Retro.text.opacity(0.4) : (live.isPaused ? Retro.accent : Retro.highlight))
                .frame(width: 32, height: 32)
                .background(Retro.background.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(live.isFinished)
    }

    private var minuteProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Retro.background.opacity(0.5))
                Capsule().fill(Retro.accent)
                    .frame(width: geo.size.width * CGFloat(min(live.minute, live.totalMinutes)) / CGFloat(max(live.totalMinutes, 1)))
            }
        }
        .frame(height: 3)
    }

    // MARK: - Commentary feed

    private var commentaryFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(live.commentary.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(.footnote, design: .monospaced).weight(line.text.contains("GOAL") ? .bold : .regular))
                            .foregroundStyle(commentaryColor(line.text))
                            .multilineTextAlignment(commentaryAlignment(line.side))
                            .frame(maxWidth: .infinity, alignment: commentaryFrameAlignment(line.side))
                            .id(index)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: live.commentary.count) { _, _ in
                withAnimation { proxy.scrollTo(live.commentary.count - 1, anchor: .bottom) }
            }
        }
    }

    private func commentaryColor(_ text: String) -> Color {
        if text.contains("GOAL") { return Retro.highlight }
        if text.contains("Full-time") || text.contains("Half-time") || text.contains("Kick-off") { return Retro.accent }
        return Retro.text.opacity(0.9)
    }

    private func commentaryAlignment(_ side: Side?) -> TextAlignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil: return .center
        }
    }

    private func commentaryFrameAlignment(_ side: Side?) -> Alignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil: return .center
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        VStack(spacing: 8) {
            momentumBar

            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 3.0], id: \.self) { value in
                    Button {
                        Haptics.tap()
                        live.setSpeed(value)
                    } label: {
                        Text("\(Int(value))×")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(live.speed == value ? Retro.background : Retro.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(live.speed == value ? Retro.accent : Retro.background.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Button {
                    Haptics.tap()
                    live.skipToEnd()
                } label: {
                    Text("SKIP")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Retro.warning)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())

                Spacer()

                Picker("Mentality", selection: Binding(get: { live.userMentality }, set: { live.userMentality = $0 })) {
                    ForEach(Mentality.allCases) { mentality in
                        Text(mentality.rawValue).tag(mentality)
                    }
                }
                .pickerStyle(.menu)
                .tint(Retro.accent)

                Picker("Instruction", selection: Binding(get: { live.userInstruction }, set: { live.userInstruction = $0 })) {
                    ForEach(MatchInstruction.allCases) { instruction in
                        Text(instruction.rawValue).tag(instruction)
                    }
                }
                .pickerStyle(.menu)
                .tint(Retro.highlight)

                Button {
                    Haptics.tap()
                    showSubs = true
                } label: {
                    Text("SUBS \(live.subsLeft)/5")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(live.subsLeft == 0 ? Retro.text.opacity(0.4) : Retro.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Retro.background.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(live.subsLeft == 0)

                Button {
                    Haptics.tap()
                    showCommentary.toggle()
                } label: {
                    Text(showCommentary ? "2D" : "TEXT")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Retro.background.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Retro.panel)
    }

    private var momentumBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                Capsule().fill(Retro.accent.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(live.momentum))
                Capsule().fill(Retro.text.opacity(0.3))
            }
        }
        .frame(height: 4)
    }

    // MARK: - Full time

    private var fullTimeOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            Panel(title: "FULL TIME") {
                VStack(spacing: 14) {
                    Text("\(store.profile.clubName)  \(live.teamGoals) – \(live.opponentGoals)  \(live.opponent.name)")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .multilineTextAlignment(.center)

                    Button {
                        guard !hasFinishedHandoff else { return }
                        hasFinishedHandoff = true
                        Haptics.tap()
                        onFinished()
                    } label: {
                        Text("CONTINUE ▸")
                            .font(.system(.headline, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                            .frame(maxWidth: 220)
                            .padding(.vertical, 12)
                            .background(Retro.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(hasFinishedHandoff)
                }
            }
            .frame(maxWidth: 380)
        }
    }
}

private struct LegendsSubsSheet: View {
    let live: LegendsLiveMatch
    @Environment(\.dismiss) private var dismiss

    @State private var offCardID: String? = nil
    @State private var onCardID: String? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SUBSTITUTIONS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Text("\(live.subsLeft) remaining")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.top, 16)

                HStack(alignment: .top, spacing: 12) {
                    column(title: "OFF (on pitch)", cards: live.userOnPitchCards, selected: $offCardID)
                    column(title: "ON (bench)", cards: live.userBenchCards, selected: $onCardID)
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(PressableButtonStyle())
                        .foregroundStyle(Retro.text)

                    Button {
                        guard let off = offCardID, let on = onCardID else { return }
                        Haptics.tap()
                        if live.makeUserSub(offCardID: off, onCardID: on) { dismiss() }
                    } label: {
                        Text("MAKE SUB")
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background((offCardID != nil && onCardID != nil && live.subsLeft > 0) ? Retro.accent : Retro.text.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(offCardID == nil || onCardID == nil || live.subsLeft == 0)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }

    private func column(title: String, cards: [LegendsCard], selected: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(cards) { card in
                        Button {
                            Haptics.tap()
                            selected.wrappedValue = card.id
                        } label: {
                            HStack {
                                Circle().fill(card.rarity.tint).frame(width: 8, height: 8)
                                Text(card.name)
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(8)
                            .background(selected.wrappedValue == card.id ? Retro.accent.opacity(0.3) : Retro.panel.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .frame(maxWidth: .infinity)
    }
}
