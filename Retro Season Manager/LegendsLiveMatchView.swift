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
//  commentary, and forwards authoritative match events into
//  `simulation.trigger(_:)` plus substitutions into
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
    /// The newest authoritative match event already forwarded to the pitch.
    /// Event IDs are stable and ordered, so two chances produced in one
    /// engine tick are both animated without parsing presentation strings.
    @State private var lastHandledEventID: String?
    @State private var hasFinishedHandoff = false

    /// Set only when the 2D ball reaches the scripted goal waypoint. This
    /// keeps the scorer card locked to the visible finish rather than the
    /// earlier score mutation in the authoritative engine.
    @State private var goalFlashEvent: LegendsMatchEvent?
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
        let matchSimulation = LegendsMatchSimulation(
            userSlots: userSlots,
            userFormation: store.formation,
            opponentFormation: opponentRoster.formation,
            opponentPlayers: opponentRoster.players,
            userDetailedAttributes: userDetailedAttributes,
            userMentality: live.userMentality,
            userInstruction: live.userInstruction
        )
        matchSimulation.onEventPresentationCompleted = { eventID in
            live.complete2DPresentation(for: eventID)
        }
        _simulation = State(initialValue: matchSimulation)
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

            if let goalFlashEvent { goalCardOverlay(for: goalFlashEvent) }
            if let eventFlash { MatchFlashOverlay(kind: eventFlash) }
            if showConfetti { PixelConfettiBurst(colors: confettiColors) }
            if live.isFinished { fullTimeOverlay }
            CRTScanlineOverlay()
        }
        .matchShake(trigger: shakeTrigger)
        .onAppear {
            simulation.onGoalPresented = { event in
                triggerGoalCard(for: event)
            }
            live.start()
            simulation.speedMultiplier = live.isPaused ? 0 : live.speed
            simulation.start()
        }
        .onDisappear {
            simulation.onGoalPresented = nil
            live.stop()
            simulation.stop()
        }
        .onChange(of: live.isHalfTime) { _, isHalfTime in if isHalfTime { triggerHalfTimeFlash() } }
        .onChange(of: live.isFinished) { _, finished in if finished { triggerFullTimeConfettiIfWon() } }
        .onChange(of: live.speed) { _, newSpeed in simulation.speedMultiplier = live.isPaused ? 0 : newSpeed }
        .onChange(of: live.isPaused) { _, isPaused in simulation.speedMultiplier = isPaused ? 0 : live.speed }
        .onChange(of: live.userMentality) { _, mentality in simulation.userMentality = mentality }
        .onChange(of: live.userInstruction) { _, instruction in simulation.userInstruction = instruction }
        .onChange(of: live.events.count) { _, _ in reactToLatestEvents() }
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

    /// Forwards immutable engine events to the visual layer. The renderer
    /// receives the exact creator, shooter, marker, keeper, flank and outcome
    /// chosen by `LegendsLiveMatch`; it never infers gameplay from commentary.
    private func reactToLatestEvents() {
        let events = live.events
        let startIndex: Int
        if let anchor = lastHandledEventID, let index = events.firstIndex(where: { $0.id == anchor }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        guard startIndex < events.count else { return }
        for event in events[startIndex...] {
            live.begin2DPresentation(for: event.id)
            simulation.trigger(event)
        }
        lastHandledEventID = events.last?.id
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

    private func triggerGoalCard(for event: LegendsMatchEvent) {
        guard event.scored else { return }
        if event.isUserEvent {
            Haptics.success()
            shakeTrigger += 1
            confettiColors = [userColor, Retro.gold, Retro.accent]
            withAnimation(.easeIn(duration: 0.1)) { showConfetti = true }
        } else {
            Haptics.error()
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            goalFlashEvent = event
        }
        let eventID = event.id
        Task {
            try? await Task.sleep(for: .milliseconds(1650))
            guard goalFlashEvent?.id == eventID else { return }
            withAnimation(.easeOut(duration: 0.3)) { goalFlashEvent = nil }
            if event.isUserEvent {
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation { showConfetti = false }
            }
        }
    }

    /// A compact Legends-style scorer card for goals by either team. The
    /// opponent uses the same deterministic portrait pool as owned cards,
    /// so both sides receive a real face without needing licensed imagery
    /// or a full-screen GoalCelebration/GoalAgainst takeover.
    private func goalCardOverlay(for event: LegendsMatchEvent) -> some View {
        let card = LegendsCardDatabase.all.first { $0.id == event.shooterID }
        let simulatedPlayer = simulation.players.first { $0.id == event.shooterID }
        let position = card?.position.broad ?? simulatedPlayer?.role.broad
        let accent = event.isUserEvent ? userColor : opponentBadgeColor
        let teamName = event.isUserEvent ? store.profile.clubName : live.opponent.name

        return HStack(spacing: 14) {
            PlayerPortraitView(
                name: event.shooterName,
                position: position,
                nation: card?.nation,
                size: 76
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(accent, lineWidth: 3))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.isUserEvent ? "GOAL!" : "GOAL AGAINST")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(event.isUserEvent ? Retro.gold : Retro.warning)
                    .tracking(1.5)
                Text(event.shooterName)
                    .font(.system(.title3, design: .monospaced).weight(.black))
                    .foregroundStyle(Retro.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(event.minute)'  ·  \(teamName.uppercased())")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Retro.text.opacity(0.68))
                    .lineLimit(1)
                if let creator = event.creatorName, creator != event.shooterName {
                    Text("ASSIST  \(creator.uppercased())")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 330, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Retro.panel, accent.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.isUserEvent ? "Goal" : "Goal against"), \(event.shooterName), \(event.minute) minutes")
        .accessibilityIdentifier("legends.goal.scorerCard")
        .allowsHitTesting(false)
        .transition(.scale(scale: 0.78).combined(with: .opacity))
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
