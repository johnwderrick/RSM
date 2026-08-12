//
//  LiveMatch.swift
//  Retro Season Manager
//
//  A minute-by-minute live match engine with real football rules:
//  90 minutes plus stoppage, half-time, goals and penalties, yellow and
//  red cards (and suspensions), five substitutions, stamina, in-match
//  injuries and a manager mentality that trades attack for solidity.
//

import Foundation
import Observation

@MainActor
@Observable
final class LiveMatch {

    // MARK: - Fixed match details

    let fixtureID: UUID
    let homeIndex: Int
    let awayIndex: Int
    let homeName: String
    let awayName: String
    let homeShort: String
    let awayShort: String
    let isUserHome: Bool
    let competition: String
    let dateText: String
    let stadium: String
    let attendance: Int
    let weather: Weather
    /// True when this is a knockout cup tie (a draw goes to penalties).
    let isCup: Bool
    /// The cup tie's id, when `isCup` is true.
    let tieID: UUID?
    /// The user's designated penalty taker, if any.
    let userPenaltyTakerID: UUID?
    /// The user's designated free-kick taker, if any.
    let userFreeKickTakerID: UUID?
    /// Difficulty multiplier applied to the user's team strength.
    let userStrengthMult: Double

    // MARK: - Live state

    private(set) var minute = 0
    private(set) var addedTime = 0
    private(set) var homeGoals = 0
    private(set) var awayGoals = 0
    private(set) var events: [MatchEvent] = []

    /// Bumped the instant a penalty is awarded, before the spot-kick's
    /// outcome is rolled — the UI watches this to flash "PENALTY!"
    /// independently of whether it's then scored or saved.
    private(set) var penaltyAwardedCount = 0

    /// Bumped the instant a player is sent off — the UI watches this to
    /// flash "RED CARD!".
    private(set) var redCardCount = 0

    private(set) var isPaused = true
    private(set) var isFinished = false
    private(set) var isHalfTime = false
    private var halfTimeTaken = false

    /// Live commentary lines, newest last.
    private(set) var commentary: [CommentaryLine] = []

    /// Playback speed multiplier (1×, 2×, 3×).
    var speed: Double = 1

    // Squads on the pitch and on the bench.
    private(set) var homeOnPitch: [PitchPlayer]
    private(set) var awayOnPitch: [PitchPlayer]
    private(set) var homeBench: [Player]
    private(set) var awayBench: [Player]
    private(set) var homeSubsLeft = 5
    private(set) var awaySubsLeft = 5

    // Manager mentality (the user controls their own side).
    var homeMentality: Mentality = .balanced
    var awayMentality: Mentality = .balanced

    /// The user's mid-match tactical instruction.
    var userInstruction: MatchInstruction = .balanced
    /// Momentum as the home side's share (0.5 = even).
    private(set) var momentum: Double = 0.5

    // Live statistics.
    private(set) var homePossession = 50
    private(set) var shots = (home: 0, away: 0)
    private(set) var shotsOnTarget = (home: 0, away: 0)
    private(set) var clearCut = (home: 0, away: 0)
    private(set) var corners = (home: 0, away: 0)
    private(set) var offsides = (home: 0, away: 0)
    private(set) var fouls = (home: 0, away: 0)
    private(set) var teamRating = (home: 6.5, away: 6.5)

    // Persistent outcomes reported back to the league.
    private(set) var homeScorerIDs: [UUID] = []
    private(set) var awayScorerIDs: [UUID] = []
    private(set) var injuredOut: [(side: Side, id: UUID)] = []
    private(set) var sentOff: [(side: Side, id: UUID)] = []

    // Player-rating tracking for the user's side.
    private var userAppeared: [Player] = []
    private var yellowByID: [UUID: Int] = [:]
    private(set) var userPlayerRatings: [(player: Player, rating: Double)] = []
    private(set) var motmName = ""

    var userAppearedIDs: [UUID] { userAppeared.map { $0.id } }
    var userPlayerRatingsByID: [UUID: Double] {
        Dictionary(uniqueKeysWithValues: userPlayerRatings.map { ($0.player.id, $0.rating) })
    }

    private var loopTask: Task<Void, Never>?

    // MARK: - Setup

    /// Designated initialiser used by both league and cup matches.
    init(store: GameStore, homeIndex: Int, awayIndex: Int, date: Date,
         competition: String, isCup: Bool, tieID: UUID?, matchID: UUID) {
        self.fixtureID = matchID
        self.homeIndex = homeIndex
        self.awayIndex = awayIndex
        self.isCup = isCup
        self.tieID = tieID
        self.userPenaltyTakerID = store.penaltyTakerID
        self.userFreeKickTakerID = store.freeKickTakerID
        self.userStrengthMult = store.difficulty.userStrengthMultiplier
        let home = store.clubs[homeIndex]
        let away = store.clubs[awayIndex]
        homeName = home.name
        awayName = away.name
        homeShort = home.shortName
        awayShort = away.shortName
        isUserHome = homeIndex == store.userClubIndex

        let (homeXI, homeSubs) = store.matchLineupAndBench(forClubIndex: homeIndex)
        let (awayXI, awaySubs) = store.matchLineupAndBench(forClubIndex: awayIndex)
        homeOnPitch = homeXI.map { PitchPlayer(player: $0) }
        awayOnPitch = awayXI.map { PitchPlayer(player: $0) }
        homeBench = homeSubs
        awayBench = awaySubs

        let info = store.stadiumInfo(forClubIndex: homeIndex)
        stadium = info.name
        attendance = store.expectedAttendance(homeIndex: homeIndex, awayIndex: awayIndex, isCup: isCup)
        self.competition = competition
        dateText = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()).uppercased()
        let month = Calendar.current.component(.month, from: date)
        weather = Weather.random(forMonth: month)

        homePossession = openingPossession()
        userAppeared = (isUserHome ? homeOnPitch : awayOnPitch).map { $0.player }
    }

    convenience init(store: GameStore, fixture: Fixture) {
        self.init(store: store, homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex,
                  date: store.date(forMatchday: fixture.matchday),
                  competition: "LEAGUE · MATCHDAY \(fixture.matchday)",
                  isCup: false, tieID: nil, matchID: fixture.id)
    }

    convenience init(store: GameStore, knockoutTie tie: CupTie, date: Date,
                     competitionName: String, roundName: String) {
        self.init(store: store, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                  date: date,
                  competition: "\(competitionName.uppercased()) · \(roundName.uppercased())",
                  isCup: true, tieID: tie.id, matchID: tie.id)
    }

    /// The user's side of the match.
    var userSide: Side { isUserHome ? .home : .away }
    var totalMinutes: Int { 90 + addedTime }

    private var minuteLabel: String { minute <= 90 ? "\(minute)" : "90+\(minute - 90)" }
    private func teamName(_ side: Side) -> String { side == .home ? homeName : awayName }

    /// Appends a line of commentary. `side` — when the line is clearly
    /// about one team — lets the UI anchor it to that team's side of the
    /// feed instead of always reading down the middle.
    private func say(_ text: String, side: Side? = nil) {
        commentary.append(CommentaryLine(text: "\(minuteLabel)'  \(text)", side: side))
        if commentary.count > 60 { commentary.removeFirst(commentary.count - 60) }
    }

    /// The mentality of the user's own side (bindable from the match UI).
    var userMentality: Mentality {
        get { isUserHome ? homeMentality : awayMentality }
        set { if isUserHome { homeMentality = newValue } else { awayMentality = newValue } }
    }

    // MARK: - Playback control

    func start() {
        guard loopTask == nil else { return }
        events.append(MatchEvent(minute: 0, side: nil, type: .kickOff, name: "Kick-off", note: nil))
        say("Kick-off at \(stadium). \(homeName) vs \(awayName). \(weather.glyph) \(weather.rawValue.lowercased()) conditions.")
        isPaused = false
        loopTask = Task { [weak self] in await self?.loop() }
    }

    func togglePause() { isPaused.toggle() }

    /// Pauses the simulation.
    func pause() { isPaused = true }

    /// Resumes play, also ending the half-time break if it is active.
    func resume() {
        isHalfTime = false
        isPaused = false
    }

    func setSpeed(_ value: Double) { speed = value }

    /// Fast-forwards the rest of the match with no delay.
    func skipToEnd() {
        isHalfTime = false
        while !isFinished {
            tick()
        }
    }

    /// Advances a single minute without playback delay (used for previews).
    func testAdvanceMinute() {
        isHalfTime = false
        tick()
    }

    private func loop() async {
        while !isFinished {
            if isPaused || isHalfTime {
                try? await Task.sleep(for: .milliseconds(80))
                continue
            }
            tick()
            let perMinute = UInt64(max(60, 700 / max(speed, 0.5)))
            try? await Task.sleep(for: .milliseconds(perMinute))
        }
    }

    // MARK: - Simulation tick (one minute)

    private func tick() {
        guard !isFinished else { return }
        minute += 1

        // Half-time break.
        if minute == 45 && !halfTimeTaken {
            halfTimeTaken = true
            isHalfTime = true
            isPaused = true
            events.append(MatchEvent(minute: 45, side: nil, type: .halfTime, name: "Half-time", note: nil))
            say("Half-time. \(homeShort) \(homeGoals)-\(awayGoals) \(awayShort).")
            runAISubstitutions(forcedAt: false)
        }

        // Set stoppage time when regulation ends.
        if minute == 90 && addedTime == 0 {
            addedTime = Int.random(in: 1...5)
        }

        generateChances()
        handleFoulsAndCards()
        handleMiscEvents()
        drainEnergy()
        recomputeDerivedStats()

        // Occasional AI substitutions in the second half.
        if minute == 60 || minute == 72 {
            runAISubstitutions(forcedAt: false)
        }

        if minute >= totalMinutes {
            finishMatch()
        }
    }

    // MARK: - Chance creation

    private func generateChances() {
        attempt(for: .home)
        attempt(for: .away)
    }

    private func attempt(for side: Side) {
        var attack = attackStrength(side) * mentality(side).attack
        var defence = defenceStrength(side.opposite) * mentality(side.opposite).solidity
        // The user's tactical instruction tweaks their own attack / solidity.
        if side == userSide { attack *= userInstruction.attack }
        if side.opposite == userSide { defence *= userInstruction.solidity }
        let homeBoost = side == .home ? 1.10 : 1.0
        let probability = 0.22 * homeBoost * attack / (attack + defence)

        guard Double.random(in: 0..<1) < probability else { return }
        addShot(side)
        bumpMomentum(toward: side, by: 0.05)
        if Double.random(in: 0..<1) < 0.34 { addCorner(side) }

        if Double.random(in: 0..<1) < 0.40 * weather.accuracyMultiplier {
            addShotOnTarget(side)
            let bigChance = Double.random(in: 0..<1) < 0.28
            if bigChance {
                addClearCut(side)
                say("Big chance for \(teamName(side)) — the keeper stands tall!", side: side)
            }
            // Better finishers convert a higher share of their chances.
            let conversion = 0.21 * (0.7 + finishing(side) / 20 * 0.7)
            let goalProbability = conversion * (bigChance ? 1.7 : 1.0)
            if Double.random(in: 0..<1) < goalProbability {
                scoreGoal(side, penalty: false)
            }
        } else if Double.random(in: 0..<1) < 0.22 {
            addOffside(side)
        }
    }

    private func handleMiscEvents() {
        // An occasional dangerous free-kick.
        if Double.random(in: 0..<1) < 0.02 {
            takeFreeKick(attackStrength(.home) >= attackStrength(.away) ? .home : .away)
        }
        // A rare penalty for the more threatening side.
        if Double.random(in: 0..<1) < 0.006 {
            let side: Side = attackStrength(.home) >= attackStrength(.away) ? .home : .away
            penaltyAwardedCount += 1
            say("PENALTY! \(teamName(side.opposite)) concede a spot-kick.", side: side)
            // 78% of penalties are converted.
            if Double.random(in: 0..<1) < 0.78 {
                scoreGoal(side, penalty: true)
            } else {
                addShotOnTarget(side)
                let takerName = penaltyTaker(side).map { " by \($0.name)" } ?? ""
                say("Penalty saved! The keeper guesses right and denies\(takerName).", side: side)
            }
        }
        // A rare in-match injury.
        if Double.random(in: 0..<1) < 0.004 {
            injureRandom(on: Bool.random() ? .home : .away)
        }
    }

    // MARK: - Fouls, cards and sendings-off

    private func handleFoulsAndCards() {
        for side in [Side.home, Side.away] {
            guard Double.random(in: 0..<1) < 0.16 else { continue }
            foulCount(side, +1)
            let offender = side.opposite
            if Double.random(in: 0..<1) < 0.14 {
                book(offender)
            }
        }
        // A very rare straight red.
        if Double.random(in: 0..<1) < 0.0004 {
            sendOff(Bool.random() ? .home : .away, note: "Straight red")
        }
    }

    private func book(_ side: Side) {
        guard let index = randomOutfieldIndex(side) else { return }
        writePitch(side) { $0[index].yellowCards += 1 }
        let player = pitch(side)[index].player
        yellowByID[player.id, default: 0] += 1
        if pitch(side)[index].yellowCards >= 2 {
            sendOff(side, playerIndex: index, note: "Second yellow")
        } else {
            events.append(MatchEvent(minute: minute, side: side, type: .yellowCard,
                                     name: player.name.uppercased(), note: nil))
            say("🟨 \(player.name) (\(teamName(side))) is booked.", side: side)
        }
    }

    private func sendOff(_ side: Side, note: String) {
        guard let index = randomOutfieldIndex(side) else { return }
        sendOff(side, playerIndex: index, note: note)
    }

    private func sendOff(_ side: Side, playerIndex index: Int, note: String) {
        let player = pitch(side)[index].player
        writePitch(side) { $0[index].onPitch = false }
        sentOff.append((side, player.id))
        events.append(MatchEvent(minute: minute, side: side, type: .redCard,
                                 name: player.name.uppercased(), note: note))
        say("🟥 RED CARD! \(player.name) (\(teamName(side))) is sent off — \(note.lowercased()).", side: side)
        redCardCount += 1
    }

    // MARK: - Goals

    private func scoreGoal(_ side: Side, penalty: Bool) {
        guard let scorer = penalty ? penaltyTaker(side) : weightedScorer(side) else { return }
        recordGoal(side, scorer: scorer, type: penalty ? .penalty : .goal, note: penalty ? "(PEN)" : nil)
    }

    /// Records a goal for a specific scorer (used by open play, pens and FKs).
    private func recordGoal(_ side: Side, scorer: Player, type: MatchEventType, note: String?) {
        if side == .home { homeGoals += 1; homeScorerIDs.append(scorer.id) }
        else { awayGoals += 1; awayScorerIDs.append(scorer.id) }
        events.append(MatchEvent(minute: minute, side: side, type: type,
                                 name: scorer.name.uppercased(), note: note))
        let how = note == "(PEN)" ? " from the spot" : (note == "(FK)" ? " with a free-kick" : "")
        say("⚽︎ GOAL! \(scorer.name) scores\(how) for \(teamName(side))! \(homeShort) \(homeGoals)-\(awayGoals) \(awayShort)", side: side)
        bumpMomentum(toward: side, by: 0.22)
    }

    /// Shifts momentum toward a side, clamped to 0.15…0.85.
    private func bumpMomentum(toward side: Side, by amount: Double) {
        let delta = side == .home ? amount : -amount
        momentum = min(0.85, max(0.15, momentum + delta))
    }

    /// A direct free-kick attempt, taken by the side's designated taker.
    private func takeFreeKick(_ side: Side) {
        addShot(side)
        guard let taker = freeKickTaker(side) else { return }
        guard Double.random(in: 0..<1) < 0.40 else { return }   // on target
        addShotOnTarget(side)
        let shooting = attr(taker, "Shooting")
        let probability = 0.14 + shooting / 20 * 0.22           // ~0.14 … 0.36 of on-target FKs
        if Double.random(in: 0..<1) < probability {
            recordGoal(side, scorer: taker, type: .goal, note: "(FK)")
        }
    }

    /// The side's designated free-kick taker (user's choice, else best shooter).
    private func freeKickTaker(_ side: Side) -> Player? {
        let onField = pitch(side).filter { $0.onPitch }.map { $0.player }
        if side == userSide, let id = userFreeKickTakerID, let taker = onField.first(where: { $0.id == id }) {
            return taker
        }
        return onField.max { attr($0, "Shooting") < attr($1, "Shooting") }
    }

    private func weightedScorer(_ side: Side) -> Player? {
        let squad = pitch(side).filter { $0.onPitch }.map { $0.player }
        guard !squad.isEmpty else { return nil }
        let positionWeight: [Position: Double] = [.forward: 5, .midfielder: 2, .defender: 0.3, .goalkeeper: 0.02]
        // Weight by position and by the player's finishing instinct.
        func weight(_ p: Player) -> Double {
            let finish = attr(p, "Shooting") * 2.5 + Double(p.rating) * 0.3
            return (positionWeight[p.position] ?? 1) * finish
        }
        let total = squad.reduce(0.0) { $0 + weight($1) }
        var roll = Double.random(in: 0..<max(total, 0.001))
        for player in squad {
            let w = weight(player)
            if roll < w { return player }
            roll -= w
        }
        return squad.last
    }

    private func penaltyTaker(_ side: Side) -> Player? {
        let onField = pitch(side).filter { $0.onPitch }.map { $0.player }
        // The user's designated taker steps up if they're on the pitch.
        if side == userSide, let id = userPenaltyTakerID, let taker = onField.first(where: { $0.id == id }) {
            return taker
        }
        return onField.sorted {
            if $0.position == .forward && $1.position != .forward { return true }
            if $1.position == .forward && $0.position != .forward { return false }
            return $0.rating > $1.rating
        }.first
    }

    // MARK: - Substitutions

    /// The user makes a substitution while the match is paused.
    @discardableResult
    func makeUserSub(off: PitchPlayer, on: Player) -> Bool {
        let side = userSide
        guard subsLeft(side) > 0 else { return false }
        guard let index = pitch(side).firstIndex(where: { $0.id == off.id && $0.onPitch }) else { return false }
        guard let benchIndex = bench(side).firstIndex(where: { $0.id == on.id }) else { return false }

        writePitch(side) { $0[index].onPitch = false }
        writeBench(side) { $0.remove(at: benchIndex) }
        writePitch(side) { $0.append(PitchPlayer(player: on, energy: 100)) }
        setSubsLeft(side, subsLeft(side) - 1)
        userAppeared.append(on)
        events.append(MatchEvent(minute: minute, side: side, type: .substitution,
                                 name: "\(surnameOf(on.name)) ▸ \(surnameOf(off.player.name))",
                                 note: nil))
        say("Substitution for \(teamName(side)): \(on.name) on for \(off.player.name).", side: side)
        return true
    }

    /// The user's current on-pitch players, for the subs sheet.
    var userOnPitch: [PitchPlayer] { pitch(userSide).filter { $0.onPitch } }
    var userBench: [Player] { bench(userSide) }
    var userSubsLeft: Int { subsLeft(userSide) }

    private func runAISubstitutions(forcedAt forced: Bool) {
        let side = userSide.opposite
        guard subsLeft(side) > 0, !bench(side).isEmpty else { return }
        // Replace the most tired outfield player with the best bench option.
        let onField = pitch(side).enumerated().filter { $0.element.onPitch && $0.element.player.position != .goalkeeper }
        guard let tired = onField.min(by: { $0.element.energy < $1.element.energy }) else { return }
        guard tired.element.energy < 78 || forced else { return }
        guard let fresh = bench(side).sorted(by: { $0.rating > $1.rating }).first,
              let benchIndex = bench(side).firstIndex(where: { $0.id == fresh.id }) else { return }

        writePitch(side) { $0[tired.offset].onPitch = false }
        writeBench(side) { $0.remove(at: benchIndex) }
        writePitch(side) { $0.append(PitchPlayer(player: fresh, energy: 100)) }
        setSubsLeft(side, subsLeft(side) - 1)
    }

    // MARK: - Injuries

    private func injureRandom(on side: Side) {
        guard let index = randomOutfieldIndex(side) else { return }
        let player = pitch(side)[index].player
        writePitch(side) { $0[index].onPitch = false }
        injuredOut.append((side, player.id))
        events.append(MatchEvent(minute: minute, side: side, type: .injury,
                                 name: player.name.uppercased(), note: "injury"))
        say("💥 \(player.name) (\(teamName(side))) goes down injured and can't continue.", side: side)
        // The AI reacts by using a sub if it can.
        if side == userSide.opposite { runAISubstitutions(forcedAt: true) }
    }

    // MARK: - Strengths & derived stats (attribute-driven)

    private func attr(_ player: Player, _ name: String, _ fallback: Int = 10) -> Double {
        Double(player.attributes[name] ?? fallback)
    }

    private func energyFactor(_ p: PitchPlayer) -> Double { 0.72 + 0.28 * p.energy / 100 }

    /// Happy players perform closer to their rating; unhappy ones undershoot it.
    private func moraleFactor(_ p: PitchPlayer) -> Double { 0.85 + 0.15 * Double(p.player.morale) / 100 }

    /// A player's contribution to creating chances, from their attributes.
    private func attackValue(_ p: PitchPlayer) -> Double {
        let player = p.player
        let base: Double
        switch player.position {
        case .forward:
            base = attr(player, "Shooting") + attr(player, "Pace") + attr(player, "Dribbling") + attr(player, "Positioning")
        case .midfielder:
            base = (attr(player, "Passing") + attr(player, "Vision") + attr(player, "Dribbling")) * 0.85
        case .defender:
            base = (attr(player, "Passing", 8) + attr(player, "Pace", 8)) * 0.35
        case .goalkeeper:
            base = 0
        }
        return base * energyFactor(p) * moraleFactor(p)
    }

    /// A player's contribution to stopping chances, from their attributes.
    private func defenceValue(_ p: PitchPlayer) -> Double {
        let player = p.player
        let base: Double
        switch player.position {
        case .goalkeeper:
            base = attr(player, "Handling") + attr(player, "Reflexes") + attr(player, "Aerial") + attr(player, "Positioning")
        case .defender:
            base = attr(player, "Defending") + attr(player, "Positioning") + attr(player, "Physical")
        case .midfielder:
            base = (attr(player, "Defending", 8) + attr(player, "Positioning", 8)) * 0.6
        case .forward:
            base = attr(player, "Defending", 6) * 0.25
        }
        return base * energyFactor(p) * moraleFactor(p)
    }

    private func attackStrength(_ side: Side) -> Double {
        let total = pitch(side).filter { $0.onPitch }.reduce(0.0) { $0 + attackValue($1) }
        return side == userSide ? total * userStrengthMult : total
    }

    private func defenceStrength(_ side: Side) -> Double {
        let total = pitch(side).filter { $0.onPitch }.reduce(0.0) { $0 + defenceValue($1) }
        return side == userSide ? total * userStrengthMult : total
    }

    /// Average finishing (Shooting) of the attacking players on the pitch,
    /// used to scale how many chances become goals.
    private func finishing(_ side: Side) -> Double {
        let shooters = pitch(side).filter { $0.onPitch && $0.player.position != .goalkeeper && $0.player.position != .defender }
        guard !shooters.isEmpty else { return 10 }
        return shooters.reduce(0.0) { $0 + attr($1.player, "Shooting") } / Double(shooters.count)
    }

    /// Ball-retention rating, driven by midfield passing and vision.
    private func possessionValue(_ side: Side) -> Double {
        pitch(side).filter { $0.onPitch }.reduce(0.0) { total, p in
            switch p.player.position {
            case .midfielder: return total + (attr(p.player, "Passing") + attr(p.player, "Vision")) * energyFactor(p)
            case .defender, .forward: return total + attr(p.player, "Passing", 8) * 0.4 * energyFactor(p)
            case .goalkeeper: return total
            }
        }
    }

    private func openingPossession() -> Int {
        let h = possessionValue(.home)
        let a = possessionValue(.away)
        guard h + a > 0 else { return 50 }
        return min(72, max(28, Int((h / (h + a) * 100).rounded())))
    }

    private func drainEnergy() {
        for side in [Side.home, Side.away] {
            writePitch(side) { players in
                for i in players.indices where players[i].onPitch {
                    players[i].energy = max(20, players[i].energy - Double.random(in: 0.2...0.5))
                }
            }
        }
    }

    private func recomputeDerivedStats() {
        // Possession drifts toward the strength ratio with small jitter.
        let target = openingPossession()
        let jitter = Int.random(in: -2...2)
        homePossession = min(75, max(25, (homePossession + target) / 2 + jitter))

        // Momentum decays back toward even each minute.
        momentum += (0.5 - momentum) * 0.12

        teamRating = (home: rating(for: .home), away: rating(for: .away))
    }

    private func rating(for side: Side) -> Double {
        let scored = side == .home ? homeGoals : awayGoals
        let conceded = side == .home ? awayGoals : homeGoals
        let onTarget = side == .home ? shotsOnTarget.home : shotsOnTarget.away
        let reds = sentOff.filter { $0.side == side }.count
        let value = 6.4 + Double(scored) * 0.4 - Double(conceded) * 0.22
            + Double(onTarget) * 0.03 - Double(reds) * 0.6
        return min(9.9, max(4.0, (value * 10).rounded() / 10))
    }

    // MARK: - Finishing

    private func finishMatch() {
        guard !isFinished else { return }
        isFinished = true
        isPaused = true
        isHalfTime = false
        computeUserRatings()
        say("Full-time! \(homeShort) \(homeGoals)-\(awayGoals) \(awayShort).")
        events.append(MatchEvent(minute: minute, side: nil, type: .fullTime, name: "Full-time", note: nil))
        loopTask?.cancel()
        loopTask = nil
    }

    /// Scores each of the user's players who appeared, and picks a MOTM.
    private func computeUserRatings() {
        let goalIDs = userSide == .home ? homeScorerIDs : awayScorerIDs
        let scored = userSide == .home ? homeGoals : awayGoals
        let conceded = userSide == .home ? awayGoals : homeGoals
        let won = scored > conceded
        let draw = scored == conceded

        var rated: [(player: Player, rating: Double)] = []
        for player in userAppeared {
            let goals = goalIDs.filter { $0 == player.id }.count
            let yellows = yellowByID[player.id] ?? 0
            let red = sentOff.contains { $0.id == player.id } ? 1 : 0
            var value = 6.2 + Double(goals) * 1.1
                + (won ? 0.5 : (draw ? 0.0 : -0.3))
                + Double.random(in: -0.3...0.5)
                - Double(yellows) * 0.3 - Double(red) * 1.5
            if player.position == .goalkeeper && conceded == 0 { value += 0.6 }
            value = min(10.0, max(4.5, (value * 10).rounded() / 10))
            rated.append((player, value))
        }
        userPlayerRatings = rated.sorted { $0.rating > $1.rating }
        motmName = userPlayerRatings.first?.player.name ?? ""
    }

    // MARK: - Side-indexed helpers

    private func pitch(_ side: Side) -> [PitchPlayer] { side == .home ? homeOnPitch : awayOnPitch }
    private func bench(_ side: Side) -> [Player] { side == .home ? homeBench : awayBench }
    private func subsLeft(_ side: Side) -> Int { side == .home ? homeSubsLeft : awaySubsLeft }
    private func mentality(_ side: Side) -> Mentality { side == .home ? homeMentality : awayMentality }

    private func writePitch(_ side: Side, _ change: (inout [PitchPlayer]) -> Void) {
        if side == .home { change(&homeOnPitch) } else { change(&awayOnPitch) }
    }
    private func writeBench(_ side: Side, _ change: (inout [Player]) -> Void) {
        if side == .home { change(&homeBench) } else { change(&awayBench) }
    }
    private func setSubsLeft(_ side: Side, _ value: Int) {
        if side == .home { homeSubsLeft = value } else { awaySubsLeft = value }
    }

    private func randomOutfieldIndex(_ side: Side) -> Int? {
        pitch(side).indices
            .filter { pitch(side)[$0].onPitch && pitch(side)[$0].player.position != .goalkeeper }
            .randomElement()
    }

    private func addShot(_ side: Side) { if side == .home { shots.home += 1 } else { shots.away += 1 } }
    private func addShotOnTarget(_ side: Side) { if side == .home { shotsOnTarget.home += 1 } else { shotsOnTarget.away += 1 } }
    private func addClearCut(_ side: Side) { if side == .home { clearCut.home += 1 } else { clearCut.away += 1 } }
    private func addCorner(_ side: Side) { if side == .home { corners.home += 1 } else { corners.away += 1 } }
    private func addOffside(_ side: Side) { if side == .home { offsides.home += 1 } else { offsides.away += 1 } }
    private func foulCount(_ side: Side, _ delta: Int) { if side == .home { fouls.home += delta } else { fouls.away += delta } }

    private func surnameOf(_ name: String) -> String {
        name.split(separator: " ").last.map(String.init) ?? name
    }
}
