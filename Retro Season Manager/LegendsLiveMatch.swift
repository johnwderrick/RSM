//
//  LegendsLiveMatch.swift
//  Retro Season Manager
//
//  A minute-by-minute live match engine for RSM Legends, mirroring
//  Career Mode's LiveMatch.swift structurally (tick loop, pause/speed,
//  mentality/instruction, substitutions, commentary, momentum) but
//  scaled to what Legends actually has: one aggregate card per Starting
//  XI slot instead of full Player objects, and no cards/injuries/weather
//  (Legends has no underlying data for those yet).
//
//  Goal resolution is two-stage, not a single coin flip. Each minute
//  rolls two independent Bernoulli trials — one per side — using
//  `p = chanceRatePerGame * ratio / 90` to decide whether that side
//  creates a genuine attacking chance this minute (unchanged in shape
//  from the engine's original single-roll design, so mid-match
//  mentality/instruction changes still genuinely shift the odds for
//  every remaining minute rather than only cosmetically animating a
//  pre-computed result). A fired chance is then *resolved* for real
//  against the opposing side's actual players — a weighted-random
//  attacker (by shooting/dribbling/pace/overall) against a weighted-
//  random defender plus the defending side's goalkeeper (by
//  defending/physical/overall) — via `resolveChance`/
//  `conversionProbability`, using a deterministic synthetic opponent
//  roster (`LegendsOpponentRoster`, full attributes). The two stages
//  together still land near the same "~2.7 goals per game" baseline
//  `LegendsMatchEngine.simulate(...)` targets, but the outcome is now
//  attribute-grounded instead of an abstract single-roll coin flip, and
//  the scorer is simply whoever took the shot — no second, unrelated
//  dice roll after the goal is already decided.
//

import Foundation
import Observation

/// One authoritative attacking event produced by the match engine. Score,
/// commentary, career statistics and the 2D renderer all consume this exact
/// record; none of those layers is allowed to select participants again.
struct LegendsMatchEvent: Identifiable, Equatable {
    enum Outcome: Equatable {
        case goal
        case saved
        case blocked
        case missed
        case woodwork
        case foul
        case offside
        case throwIn
        case tackled
        case cleared
    }
    enum Channel: Equatable { case left, right }
    enum AttackPattern: String, CaseIterable, Equatable {
        case wideCross
        case cutback
        case centralCombination
        case counterAttack
        case longShot
    }

    let id: String
    let minute: Int
    let side: Side
    let outcome: Outcome
    let channel: Channel
    let attackPattern: AttackPattern
    let creatorID: String?
    let creatorName: String?
    let shooterID: String
    let shooterName: String
    let markerID: String?
    let markerName: String?
    let goalkeeperID: String?
    let goalkeeperName: String?
    let expectedGoals: Double

    init(
        id: String, minute: Int, side: Side, outcome: Outcome, channel: Channel,
        attackPattern: AttackPattern = .wideCross,
        creatorID: String?, creatorName: String?, shooterID: String, shooterName: String,
        markerID: String?, markerName: String?, goalkeeperID: String?, goalkeeperName: String?,
        expectedGoals: Double
    ) {
        self.id = id
        self.minute = minute
        self.side = side
        self.outcome = outcome
        self.channel = channel
        self.attackPattern = attackPattern
        self.creatorID = creatorID
        self.creatorName = creatorName
        self.shooterID = shooterID
        self.shooterName = shooterName
        self.markerID = markerID
        self.markerName = markerName
        self.goalkeeperID = goalkeeperID
        self.goalkeeperName = goalkeeperName
        self.expectedGoals = expectedGoals
    }

    var scored: Bool { outcome == .goal }
    var isUserEvent: Bool { side == .home }
    var isShotEvent: Bool {
        switch outcome {
        case .goal, .saved, .blocked, .missed, .woodwork: return true
        case .foul, .offside, .throwIn, .tackled, .cleared: return false
        }
    }
    var presentationScript: LegendsMatchPresentationScript {
        LegendsMatchPresentationScript(event: self)
    }
}

enum LegendsPresentationAction: Equatable {
    case carry
    case pass
    case cross
    case cutback
    case throughBall
    case shoot
    case goal
    case save
    case block
    case miss
    case woodwork
    case foul
    case offside
    case throwIn
    case tackle
    case clearance
}

enum LegendsPresentationZone: Equatable {
    case centre
    case leftBuildUp
    case rightBuildUp
    case leftChannel
    case rightChannel
    case leftByline
    case rightByline
    case edgeOfBox
    case penaltyArea
    case leftGoal
    case rightGoal
    case leftOfGoal
    case rightOfGoal
    case leftPost
    case rightPost
    case leftCorner
    case rightCorner
}

struct LegendsPresentationBeat: Equatable {
    let action: LegendsPresentationAction
    let actorID: String?
    let actorName: String
    let receiverID: String?
    let receiverName: String?
    let zone: LegendsPresentationZone
    let text: String
}

enum LegendsMatchRestart: Equatable {
    case kickoff(team: Side)
    case goalkeeperPossession(team: Side)
    case goalKick(team: Side)
    case corner(team: Side, channel: LegendsMatchEvent.Channel)
    case freeKick(team: Side, channel: LegendsMatchEvent.Channel)
    case throwIn(team: Side, channel: LegendsMatchEvent.Channel)
    case openPlay(team: Side, channel: LegendsMatchEvent.Channel)
}

/// One immutable description of what happened in an authoritative chance.
/// Both the text commentary and the 2D pitch consume this object, so names,
/// actions, flank, outcome and participants cannot drift apart.
struct LegendsMatchPresentationScript: Equatable {
    let eventID: String
    let side: Side
    let outcome: LegendsMatchEvent.Outcome
    let channel: LegendsMatchEvent.Channel
    let attackPattern: LegendsMatchEvent.AttackPattern
    let creatorID: String?
    let shooterID: String
    let markerID: String?
    let goalkeeperID: String?
    let beats: [LegendsPresentationBeat]
    let restart: LegendsMatchRestart

    init(event: LegendsMatchEvent) {
        eventID = event.id
        side = event.side
        outcome = event.outcome
        channel = event.channel
        attackPattern = event.attackPattern
        creatorID = event.creatorID
        shooterID = event.shooterID
        markerID = event.markerID
        goalkeeperID = event.goalkeeperID

        let beatCreatorID = event.creatorID ?? event.shooterID
        let creator = event.creatorName ?? event.shooterName
        let flank = event.channel == .left ? "left" : "right"
        let buildUpZone: LegendsPresentationZone = event.channel == .left ? .leftBuildUp : .rightBuildUp
        let channelZone: LegendsPresentationZone = event.channel == .left ? .leftChannel : .rightChannel
        let bylineZone: LegendsPresentationZone = event.channel == .left ? .leftByline : .rightByline
        let defendingTeam = event.side.opposite
        var scriptedBeats: [LegendsPresentationBeat] = []

        switch event.attackPattern {
        case .wideCross:
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: channelZone,
                                       text: "\(creator) carries down the \(flank) flank."))
            scriptedBeats.append(.init(action: .cross, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .penaltyArea,
                                       text: "\(creator) crosses towards \(event.shooterName)."))
        case .cutback:
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: bylineZone,
                                       text: "\(creator) reaches the byline on the \(flank)."))
            scriptedBeats.append(.init(action: .cutback, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .edgeOfBox,
                                       text: "\(creator) cuts the ball back to \(event.shooterName)."))
        case .centralCombination:
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: .centre,
                                       text: "\(creator) drives through the centre."))
            scriptedBeats.append(.init(action: .pass, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .edgeOfBox,
                                       text: "\(creator) combines with \(event.shooterName) at the edge of the box."))
        case .counterAttack:
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: buildUpZone,
                                       text: "\(creator) leads a quick counter through the \(flank) channel."))
            scriptedBeats.append(.init(action: .throughBall, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .penaltyArea,
                                       text: "\(creator) releases \(event.shooterName) into space."))
        case .longShot:
            scriptedBeats.append(.init(action: .pass, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .edgeOfBox,
                                       text: "\(creator) works the ball into central space for \(event.shooterName)."))
        }

        let pressure = event.markerName.map { " under pressure from \($0)" } ?? ""
        if event.isShotEvent {
            scriptedBeats.append(.init(action: .shoot, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil,
                                       zone: event.attackPattern == .longShot ? .edgeOfBox : .penaltyArea,
                                       text: "\(event.shooterName) shoots\(pressure)."))
        }
        switch event.outcome {
        case .goal:
            let keeper = event.goalkeeperName.map { " beyond \($0)" } ?? ""
            let goalZone: LegendsPresentationZone = event.channel == .left ? .rightGoal : .leftGoal
            scriptedBeats.append(.init(action: .goal, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: event.goalkeeperID, receiverName: event.goalkeeperName,
                                       zone: goalZone,
                                       text: "The shot flies\(keeper) and into the net!"))
            restart = .kickoff(team: defendingTeam)
        case .saved:
            let keeper = event.goalkeeperName ?? "The goalkeeper"
            let saveZone: LegendsPresentationZone = event.channel == .left ? .leftGoal : .rightGoal
            scriptedBeats.append(.init(action: .save, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: event.goalkeeperID, receiverName: event.goalkeeperName,
                                       zone: saveZone,
                                       text: "\(keeper) gets across and saves."))
            restart = .goalkeeperPossession(team: defendingTeam)
        case .blocked:
            let marker = event.markerName ?? "The defender"
            scriptedBeats.append(.init(action: .block, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: event.markerID, receiverName: event.markerName,
                                       zone: .penaltyArea,
                                       text: "\(marker) throws himself in the way and makes the block."))
            restart = .corner(team: event.side, channel: event.channel)
        case .missed:
            scriptedBeats.append(.init(action: .miss, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil,
                                       zone: event.channel == .left ? .rightOfGoal : .leftOfGoal,
                                       text: "The effort flashes wide of the far post."))
            restart = .goalKick(team: defendingTeam)
        case .woodwork:
            scriptedBeats.append(.init(action: .woodwork, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil,
                                       zone: event.channel == .left ? .rightPost : .leftPost,
                                       text: "The ball crashes against the post!"))
            restart = .goalKick(team: defendingTeam)
        case .foul:
            let marker = event.markerName ?? "The defender"
            scriptedBeats = [.init(action: .foul, actorID: event.markerID, actorName: marker,
                                   receiverID: event.shooterID, receiverName: event.shooterName,
                                   zone: channelZone,
                                   text: "\(marker) brings down \(event.shooterName) in the \(flank) channel.")]
            restart = .freeKick(team: event.side, channel: event.channel)
        case .offside:
            scriptedBeats = [.init(action: .offside, actorID: event.shooterID, actorName: event.shooterName,
                                   receiverID: event.creatorID, receiverName: event.creatorName,
                                   zone: .penaltyArea,
                                   text: "\(event.shooterName) goes too early and is caught offside.")]
            restart = .freeKick(team: defendingTeam, channel: event.channel)
        case .throwIn:
            scriptedBeats = [.init(action: .throwIn, actorID: beatCreatorID, actorName: creator,
                                   receiverID: event.shooterID, receiverName: event.shooterName,
                                   zone: channelZone,
                                   text: "\(creator) takes the throw-in towards \(event.shooterName).")]
            restart = .throwIn(team: event.side, channel: event.channel)
        case .tackled:
            let marker = event.markerName ?? "The defender"
            scriptedBeats = [.init(action: .tackle, actorID: event.markerID, actorName: marker,
                                   receiverID: event.shooterID, receiverName: event.shooterName,
                                   zone: channelZone,
                                   text: "\(marker) times the tackle on \(event.shooterName) and wins possession.")]
            restart = .openPlay(team: defendingTeam, channel: event.channel)
        case .cleared:
            let marker = event.markerName ?? "The defender"
            scriptedBeats = [.init(action: .clearance, actorID: event.markerID, actorName: marker,
                                   receiverID: nil, receiverName: nil,
                                   zone: channelZone,
                                   text: "\(marker) reads the danger and clears towards the \(flank) touchline.")]
            restart = .throwIn(team: event.side, channel: event.channel)
        }
        beats = scriptedBeats
    }

    var detailedText: String {
        beats.map(\.text).joined(separator: " ")
    }
}

@MainActor
@Observable
final class LegendsLiveMatch {
    let opponent: LegendsOpponent
    private let store: LegendsStore
    /// Snapshot of `store.startingXISlots` at kickoff — formation can't
    /// change mid-match, so this never needs to be resized.
    private let slots: [DetailedPosition]

    private(set) var minute = 0
    private(set) var addedTime = 0
    private(set) var teamGoals = 0
    private(set) var opponentGoals = 0
    private(set) var commentary: [CommentaryLine] = []
    private(set) var events: [LegendsMatchEvent] = []
    private(set) var isPaused = true
    private(set) var isHalfTime = false
    private(set) var isFinished = false
    private var halfTimeTaken = false
    var speed: Double = 1

    /// Seeded from `store.profile.preferredMentality` at kickoff, then
    /// freely editable mid-match — Career Mode allows the same.
    var userMentality: Mentality
    var userInstruction: MatchInstruction = .balanced

    private(set) var subsLeft = 5
    /// Indexed identically to `slots` — the card currently occupying
    /// that Starting XI slot, or nil if it was never filled (shouldn't
    /// happen for a match that was allowed to kick off, but defensive).
    private(set) var onPitchCardIDs: [String?]
    /// Kickoff XI and real minutes played are snapshotted by the engine so
    /// post-match statistics include substitutes without treating them as
    /// starters or giving every participant an automatic 90 minutes.
    private(set) var startingCardIDs: [String]
    private(set) var minutesPlayedByCardID: [String: Int]
    /// Parallel to `onPitchCardIDs` — 0...100, decays each minute for a
    /// filled slot, reset to 100 by a substitution into that slot.
    private(set) var energyBySlot: [Double]
    private(set) var benchCardIDs: [String]

    /// Home-relative, 0.5 = even. Cosmetic (not fed back into goal
    /// probability), same shape as Career's own momentum.
    private(set) var momentum: Double = 0.5
    private(set) var scorerCardIDs: [String] = []
    private(set) var substitutionFlashCount = 0
    private(set) var lastSubOffName = ""
    private(set) var lastSubOnName = ""

    private var loopTask: Task<Void, Never>?
    /// Engine events currently being presented by the 2D pitch. The match
    /// clock waits while this set is non-empty, keeping commentary, actors
    /// and the visible ball sequence on the same authoritative event.
    private var presentationEventIDs: Set<String> = []
    var isAwaiting2DPresentation: Bool { !presentationEventIDs.isEmpty }
    /// Goals/subs after minute 45 — drives stoppage time, a cheap echo
    /// of Career's event-counted approach without needing cards/injuries.
    private var secondHalfEventCount = 0
    private var eventSequence = 0

    /// Manager/stadium tactical+gameplay bonus plus a chemistry nudge,
    /// snapshotted once at kickoff — mirrors the shape of the old instant-
    /// sim engine's `chemistryBonus = totalChemistry * 0.3 +
    /// matchStrengthBonus` (`LegendsMatchEngine.swift`/
    /// `LegendsStore+ManagersAndStadiums.swift`), which this live engine
    /// had never actually picked up despite being the only match path a
    /// real player ever sees — managers, stadiums and chemistry were
    /// dead weight here until now. Snapshotted rather than read live so a
    /// manager/stadium change can't retroactively skew an in-progress
    /// match (not that the live screen currently offers a way to change
    /// either mid-match anyway).
    private let strengthBonus: Double

    /// Synthesized opponent XI (id/name/position + full attribute set),
    /// generated once at kickoff from the same deterministic roster the
    /// cosmetic 2D pitch already draws its 11 dots from
    /// (`LegendsOpponentRoster.swift`) — reused here so the score engine
    /// finally has real attributes to resolve a shot against instead of
    /// a single flat `opponent.rating` number. Pure/deterministic on
    /// `opponent.name`, no RNG draw, so constructing it doesn't perturb
    /// `rng`'s sequence (matters for `pairedAverageGoalsDelta`'s seeded
    /// A/B pairing in the tests).
    private let opponentRoster: (formation: Formation, slots: [DetailedPosition], players: [SyntheticOpponentPlayer])
    private let incidentScheduleOffset: Int

    /// Defaults to the system generator in production; tests can inject a
    /// seeded one (e.g. `SeededGenerator`) to run two matches through the
    /// *same* sequence of rolls and isolate the effect of a single input
    /// (mentality, a manager bonus, ...) from ordinary match-to-match
    /// variance — see `LegendsLiveMatchTests.pairedAverageGoalsDelta`.
    private var rng: any RandomNumberGenerator

    init(store: LegendsStore, opponent: LegendsOpponent, rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.store = store
        self.opponent = opponent

        // Treat persisted squad arrays as untrusted legacy input. Older or
        // interrupted saves can contain the wrong number of slots, stale IDs
        // or the same card more than once. Normalize to the current formation
        // so every parallel live-match array has exactly the same safe length.
        let slotSnapshot = store.startingXISlots
        self.slots = slotSnapshot
        let savedXI = store.profile.startingXICardIDs
        var usedCardIDs = Set<String>()
        let normalizedXI: [String?] = (0..<slotSnapshot.count).map { index in
            guard savedXI.indices.contains(index),
                  let cardID = savedXI[index],
                  !usedCardIDs.contains(cardID),
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
                  store.isSigned(card) else {
                return nil
            }
            usedCardIDs.insert(cardID)
            return cardID
        }
        self.onPitchCardIDs = normalizedXI
        self.startingCardIDs = normalizedXI.compactMap { $0 }
        self.minutesPlayedByCardID = Dictionary(uniqueKeysWithValues: normalizedXI.compactMap { $0 }.map { ($0, 0) })
        self.energyBySlot = Array(repeating: 100.0, count: slotSnapshot.count)

        var usedBenchIDs = Set<String>()
        self.benchCardIDs = store.profile.benchCardIDs.compactMap { cardID in
            guard let cardID,
                  !usedCardIDs.contains(cardID),
                  usedBenchIDs.insert(cardID).inserted,
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
                  store.isSigned(card) else {
                return nil
            }
            return cardID
        }

        self.userMentality = store.profile.preferredMentality
        self.strengthBonus = store.matchStrengthBonus + Double(store.totalChemistry) * 0.3
        self.opponentRoster = LegendsOpponentRoster.generateRoster(for: opponent)
        self.incidentScheduleOffset = opponent.name.utf8.reduce(0) { partial, byte in
            (partial &* 31 &+ Int(byte)) % 97
        } % 7
        self.rng = rng
    }

    var totalMinutes: Int { 90 + addedTime }
    var result: LegendsMatchEngine.Result { LegendsMatchEngine.Result(teamGoals: teamGoals, opponentGoals: opponentGoals) }

    var userOnPitchCards: [LegendsCard] {
        onPitchCardIDs.compactMap { $0 }.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
    }
    var userBenchCards: [LegendsCard] {
        benchCardIDs.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
    }

    // MARK: - Playback controls

    func start() {
        guard loopTask == nil else { return }
        say("Kick-off!")
        SoundManager.shared.play(.whistleKickOff)
        isPaused = false
        loopTask = Task { [weak self] in await self?.loop() }
    }

    func togglePause() { isPaused ? resume() : pause() }
    func pause() { isPaused = true }
    func resume() { isPaused = false; isHalfTime = false }
    func setSpeed(_ value: Double) { speed = value }

    /// Stops the live loop immediately — the "abandon match" path. The
    /// normal full-time flow ends the loop naturally via `isFinished`; an
    /// abandoned match never gets there, so the background task is
    /// cancelled outright and the engine is left paused so nothing can
    /// tick on. The result is not computed here — the caller records the
    /// forfeit loss itself.
    func stop() {
        loopTask?.cancel()
        loopTask = nil
        presentationEventIDs.removeAll()
        isPaused = true
    }

    func skipToEnd() {
        presentationEventIDs.removeAll()
        isHalfTime = false
        isPaused = false
        while !isFinished { tick() }
    }

    /// Synchronous single-minute advance, no delay — the async-free path
    /// unit tests drive instead of the real `Task`-based loop in `start()`.
    func testAdvanceMinute() {
        guard !isAwaiting2DPresentation else { return }
        isHalfTime = false
        tick()
    }

    func begin2DPresentation(for eventID: String) {
        presentationEventIDs.insert(eventID)
    }

    func complete2DPresentation(for eventID: String) {
        presentationEventIDs.remove(eventID)
    }

    private func loop() async {
        // `Task.isCancelled` matters as much as `isFinished`: `stop()`
        // (the abandon path) cancels the task, and without checking it
        // here the loop would keep sleeping forever in the paused branch
        // — `try?` swallows the cancellation error — leaking the engine.
        while !isFinished && !Task.isCancelled {
            if isPaused || isHalfTime || isAwaiting2DPresentation {
                try? await Task.sleep(for: .milliseconds(80))
                continue
            }
            tick()
            let perMinute = UInt64(max(60, 700 / max(speed, 0.5)))
            try? await Task.sleep(for: .milliseconds(perMinute))
        }
    }

    // MARK: - Tick

    private func tick() {
        guard !isFinished else { return }
        minute += 1
        recordPlayedMinute()

        if minute == 45 && !halfTimeTaken {
            halfTimeTaken = true
            isHalfTime = true
            isPaused = true
            say("Half-time.")
            SoundManager.shared.play(.whistleHalfTime)
            return
        }

        if minute == 90 && addedTime == 0 {
            addedTime = min(6, 1 + secondHalfEventCount / 2 + Int.random(in: 0...1, using: &rng))
        }

        decayEnergy()
        let eventCountBeforeMinute = events.count
        rollGoalChances()
        if events.count == eventCountBeforeMinute {
            createScheduledIncidentIfNeeded()
        }
        recomputeMomentum()

        if minute >= totalMinutes {
            finishMatch()
        }
    }

    private func recordPlayedMinute() {
        // Career statistics use regulation minutes. Stoppage time is real
        // match time but does not turn a full appearance into 91–96 minutes.
        guard minute <= 90 else { return }
        for cardID in onPitchCardIDs.compactMap({ $0 }) {
            minutesPlayedByCardID[cardID, default: 0] += 1
        }
    }

    private func decayEnergy() {
        for index in energyBySlot.indices where onPitchCardIDs[index] != nil {
            energyBySlot[index] = max(20, energyBySlot[index] - Double.random(in: 0.2...0.5, using: &rng))
        }
    }

    /// Independent attack/defence ratios (see file header) rather than
    /// one shared ratio — lets mentality/instruction bite on "how often
    /// do I create a chance" and "how often I concede one" separately. A
    /// hit here used to *be* the goal directly; now it's a genuine
    /// attacking opportunity, resolved for real against the opposing
    /// side's actual players in `resolveChance`.
    private func rollGoalChances() {
        // The bonus applies symmetrically to attack and defence, matching
        // how the old instant-sim engine's single `chemistryBonus` term
        // boosted the team's overall competitiveness (it fed one shared
        // teamRating that decided both scoring and conceding odds via the
        // same ratio) rather than favoring one side of the ball.
        let liveAttack = energyWeightedAverage { $0.broad == .midfielder || $0.broad == .forward } + strengthBonus
        let liveDefence = energyWeightedAverage { $0 == .goalkeeper || $0.broad == .defender } + strengthBonus
        let oppRating = Double(opponent.rating)

        let effectiveAttack = max(liveAttack * userMentality.attack * userInstruction.attack, 1)
        let effectiveDefence = max(liveDefence * userMentality.solidity * userInstruction.solidity, 1)

        let userChanceRatio = effectiveAttack / (effectiveAttack + oppRating)
        let opponentChanceRatio = oppRating / (oppRating + effectiveDefence)

        let pUserChance = Self.chanceRatePerGame * userChanceRatio / 90
        let pOpponentChance = Self.chanceRatePerGame * opponentChanceRatio / 90

        if Double.random(in: 0..<1, using: &rng) < pUserChance {
            resolveChance(forUser: true)
        }
        if Double.random(in: 0..<1, using: &rng) < pOpponentChance {
            resolveChance(forUser: false)
        }
    }

    private func energyWeightedAverage(where matchesSlot: (DetailedPosition) -> Bool) -> Double {
        var total = 0.0
        var count = 0
        for (index, slot) in slots.enumerated() where matchesSlot(slot) {
            guard let cardID = onPitchCardIDs[index],
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { continue }
            let energyFactor = 0.72 + 0.28 * energyBySlot[index] / 100
            total += Double(store.effectiveOverall(for: card)) * energyFactor
            count += 1
        }
        guard count > 0 else { return 1 }
        return total / Double(count)
    }

    // MARK: - Shot resolution

    /// A single real player's shot-relevant numbers, resolved once per
    /// fired chance — works uniformly for a user `LegendsCard` or an
    /// opponent `SyntheticOpponentPlayer`. Not `private`: exposed
    /// (module-internal, via `@testable import`) so tests can exercise
    /// `conversionProbability` directly, without the statistical noise
    /// and dilution of proving an attribute's effect indirectly through
    /// a full paired-trial match simulation.
    struct ShotContestant {
        let id: String
        let name: String
        let shooting: Int
        let dribbling: Int
        let pace: Int
        let overall: Int
    }

    struct DefenseContestant {
        let defending: Int
        let physical: Int
        let keeperOverall: Int
    }

    private struct DefenseSelection {
        let contestant: DefenseContestant
        let markerID: String?
        let markerName: String?
        let goalkeeperID: String?
        let goalkeeperName: String?
    }

    /// Chances/game at exact parity between the two ratios above — the
    /// replacement for the old flat `2.7` (see file header): `2.7` used
    /// to be the *goal* rate directly; this is the *chance* rate, scaled
    /// up so that once `baseConversion` (below) is applied at parity the
    /// combined-team average lands back near the same ~2.7 goals/game.
    private static let chanceRatePerGame = 7.5

    private static let baseConversion = 0.35
    private static let conversionFloor = 0.05
    private static let conversionCeiling = 0.75

    /// One fired attacking chance, resolved for real: a weighted-random
    /// attacker against a weighted-random defender plus the defending
    /// side's goalkeeper, using actual `LegendsCard`/`SyntheticOpponentPlayer`
    /// attributes instead of a single blended `overall` and a pre-decided
    /// coin flip. The attacker who takes the shot is credited as scorer
    /// directly — no second, unrelated dice roll the way the old
    /// `weightedScorer()` ran *after* the goal was already decided.
    private func resolveChance(forUser: Bool) {
        let attacker: ShotContestant
        let energyFactor: Double
        let creator: (id: String, name: String)?
        let defense: DefenseSelection
        if forUser {
            guard let picked = pickUserAttacker() else { return }
            (attacker, energyFactor) = picked
            creator = pickUserCreator(excluding: attacker.id)
            defense = opponentDefenseSelection()
        } else {
            attacker = pickOpponentAttacker()
            energyFactor = 1.0 // no fatigue system for the synthetic opponent roster
            creator = pickOpponentCreator(excluding: attacker.id)
            defense = userDefenseSelection()
        }

        let pConvert = conversionProbability(attacker: attacker, defense: defense.contestant, energyFactor: energyFactor)
        let scored = Double.random(in: 0..<1, using: &rng) < pConvert
        eventSequence += 1
        let outcome: LegendsMatchEvent.Outcome = scored
            ? .goal
            : nonScoringOutcome(attacker: attacker, defense: defense.contestant)
        let event = LegendsMatchEvent(
            id: "M\(minute)-E\(eventSequence)", minute: minute,
            side: forUser ? .home : .away,
            outcome: outcome,
            channel: eventSequence.isMultiple(of: 2) ? .right : .left,
            attackPattern: attackPattern(forUser: forUser, shooterID: attacker.id, creatorID: creator?.id),
            creatorID: creator?.id, creatorName: creator?.name,
            shooterID: attacker.id, shooterName: attacker.name,
            markerID: defense.markerID, markerName: defense.markerName,
            goalkeeperID: defense.goalkeeperID, goalkeeperName: defense.goalkeeperName,
            expectedGoals: pConvert
        )
        events.append(event)
        if scored {
            scoreGoal(event)
        } else {
            say("Big chance for \(forUser ? store.profile.clubName : opponent.name). \(event.presentationScript.detailedText)", side: event.side)
            bumpMomentum(towardUser: forUser, by: 0.05)
        }
    }

    /// Varies the visible resolution of a chance without changing whether it
    /// became a goal. This consumes no additional RNG, so the established
    /// score-rate balance and seeded match results remain unchanged.
    private func nonScoringOutcome(attacker: ShotContestant,
                                   defense: DefenseContestant) -> LegendsMatchEvent.Outcome {
        let selector = (minute * 7 + eventSequence * 11 + attacker.shooting
                        + defense.defending + defense.keeperOverall) % 10
        switch selector {
        case 0, 1: return .blocked
        case 2, 3, 4: return .missed
        case 5: return .woodwork
        default: return .saved
        }
    }

    /// Adds a small, deterministic number of non-shot incidents to a match.
    /// These moments do not alter the score calculation and use no random
    /// draws; they exist so commentary and the pitch can show the same foul,
    /// offside or throw-in instead of filling every gap with generic motion.
    private func createScheduledIncidentIfNeeded() {
        let outcome: LegendsMatchEvent.Outcome
        let scheduledMinute = minute + incidentScheduleOffset
        if scheduledMinute.isMultiple(of: 29) {
            outcome = .throwIn
        } else if scheduledMinute.isMultiple(of: 37) {
            outcome = .foul
        } else if scheduledMinute.isMultiple(of: 43) {
            outcome = .offside
        } else if scheduledMinute.isMultiple(of: 47) {
            outcome = .tackled
        } else if scheduledMinute.isMultiple(of: 53) {
            outcome = .cleared
        } else {
            return
        }

        let forUser = (minute / 10).isMultiple(of: 2)
        let attackers = incidentParticipants(forUser: forUser)
        let defenders = incidentParticipants(forUser: !forUser)
        guard !attackers.isEmpty, !defenders.isEmpty else { return }
        let actor = attackers[minute % attackers.count]
        let supporting = attackers[(minute + 3) % attackers.count]
        let defender = defenders[(minute + 5) % defenders.count]
        let channel: LegendsMatchEvent.Channel = minute.isMultiple(of: 2) ? .right : .left

        eventSequence += 1
        let event = LegendsMatchEvent(
            id: "M\(minute)-E\(eventSequence)", minute: minute,
            side: forUser ? .home : .away,
            outcome: outcome, channel: channel,
            attackPattern: outcome == .offside ? .counterAttack : .wideCross,
            creatorID: supporting.id, creatorName: supporting.name,
            shooterID: actor.id, shooterName: actor.name,
            markerID: defender.id, markerName: defender.name,
            goalkeeperID: nil, goalkeeperName: nil,
            expectedGoals: 0
        )
        events.append(event)
        say(event.presentationScript.detailedText, side: event.side)
    }

    private func incidentParticipants(forUser: Bool) -> [(id: String, name: String)] {
        if forUser {
            return onPitchCardIDs.enumerated().compactMap { index, cardID in
                guard slots.indices.contains(index), slots[index].broad != .goalkeeper,
                      let cardID,
                      let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else {
                    return nil
                }
                return (card.id, card.name)
            }
        }
        return opponentRoster.players
            .filter { $0.position.broad != .goalkeeper }
            .map { (id: $0.id, name: $0.name) }
    }

    /// Chooses a plausible route from the selected players and match context.
    /// This is intentionally deterministic and consumes no extra RNG draw, so
    /// adding visual variety cannot change later score rolls in the same match.
    private func attackPattern(forUser: Bool, shooterID: String, creatorID: String?) -> LegendsMatchEvent.AttackPattern {
        let shooterPosition: DetailedPosition? = forUser
            ? LegendsCardDatabase.all.first(where: { $0.id == shooterID })?.position
            : opponentRoster.players.first(where: { $0.id == shooterID })?.position
        let creatorPosition: DetailedPosition? = creatorID.flatMap { id in
            forUser
                ? LegendsCardDatabase.all.first(where: { $0.id == id })?.position
                : opponentRoster.players.first(where: { $0.id == id })?.position
        }
        let selector = (minute + eventSequence * 7) % 10
        if shooterPosition?.broad == .midfielder && selector <= 2 { return .longShot }
        if let creatorPosition, [.leftWing, .rightWing, .leftMid, .rightMid, .leftBack, .rightBack].contains(creatorPosition) {
            return selector.isMultiple(of: 2) ? .wideCross : .cutback
        }
        if selector == 3 || selector == 8 { return .counterAttack }
        if selector <= 5 { return .centralCombination }
        return selector.isMultiple(of: 2) ? .wideCross : .cutback
    }

    private func attackerPower(_ a: ShotContestant, energyFactor: Double) -> Double {
        (Double(a.shooting) * 1.6 + Double(a.dribbling) * 0.9 + Double(a.pace) * 0.5 + Double(a.overall) * 0.4) * energyFactor
    }

    private func defensePower(_ d: DefenseContestant) -> Double {
        Double(d.defending) * 1.3 + Double(d.physical) * 0.9 + Double(d.keeperOverall) * 1.1
    }

    func conversionProbability(attacker: ShotContestant, defense: DefenseContestant, energyFactor: Double) -> Double {
        let ap = attackerPower(attacker, energyFactor: energyFactor)
        let dp = defensePower(defense)
        let shotQuality = ap / (ap + dp) // 0...1, 0.5 at parity
        let raw = Self.baseConversion * (shotQuality / 0.5)
        return min(Self.conversionCeiling, max(Self.conversionFloor, raw))
    }

    private func positionWeight(_ broad: Position) -> Double {
        switch broad {
        case .forward: return 5
        case .midfielder: return 2
        case .defender: return 0.3
        case .goalkeeper: return 0.02
        }
    }

    /// Forward-heaviest, same shape the old `weightedScorer()` used —
    /// extended to read `dribbling`/`pace` alongside `shooting`/`overall`
    /// now that a real shot-quality contest exists to feed them into.
    private func pickUserAttacker() -> (ShotContestant, energyFactor: Double)? {
        let candidates: [(index: Int, card: LegendsCard)] = slots.indices.compactMap { index in
            guard let cardID = onPitchCardIDs[index],
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { return nil }
            return (index, card)
        }
        guard !candidates.isEmpty else { return nil }
        func weight(_ card: LegendsCard) -> Double {
            positionWeight(card.position.broad) * (Double(card.shooting) * 2.5 + Double(store.effectiveOverall(for: card)) * 0.3)
        }
        let totalWeight = candidates.reduce(0.0) { $0 + weight($1.card) }
        let picked: (index: Int, card: LegendsCard)
        if totalWeight > 0 {
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            picked = candidates.first { roll -= weight($0.card); return roll < 0 } ?? candidates[candidates.count - 1]
        } else {
            picked = candidates[Int.random(in: 0..<candidates.count, using: &rng)]
        }
        let energyFactor = 0.72 + 0.28 * energyBySlot[picked.index] / 100
        let detailed = store.effectiveDetailedAttributes(for: picked.card)
        let contestant = ShotContestant(id: picked.card.id, name: picked.card.name, shooting: LegendsMatchSelectors.shooting(detailed),
                                         dribbling: LegendsMatchSelectors.dribbling(detailed), pace: detailed.sprintSpeed,
                                         overall: store.effectiveOverall(for: picked.card))
        return (contestant, energyFactor)
    }

    private func pickOpponentAttacker() -> ShotContestant {
        let players = opponentRoster.players
        func weight(_ player: SyntheticOpponentPlayer) -> Double {
            positionWeight(player.position.broad) * (Double(player.shooting) * 2.5 + Double(player.overall) * 0.3)
        }
        let totalWeight = players.reduce(0.0) { $0 + weight($1) }
        let picked: SyntheticOpponentPlayer
        if totalWeight > 0 {
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            picked = players.first { roll -= weight($0); return roll < 0 } ?? players[players.count - 1]
        } else {
            picked = players[Int.random(in: 0..<players.count, using: &rng)]
        }
        return ShotContestant(id: picked.id, name: picked.name, shooting: picked.shooting,
                               dribbling: picked.dribbling, pace: picked.pace, overall: picked.overall)
    }

    private func pickUserCreator(excluding shooterID: String) -> (id: String, name: String)? {
        let candidates = onPitchCardIDs.compactMap { $0 }.filter { $0 != shooterID }.compactMap { id in
            LegendsCardDatabase.all.first { $0.id == id }
        }
        let preferred = candidates.filter { $0.position.broad == .midfielder || $0.position.broad == .forward }
        let pool = preferred.isEmpty ? candidates : preferred
        return pool.max { lhs, rhs in
            let left = store.effectiveDetailedAttributes(for: lhs)
            let right = store.effectiveDetailedAttributes(for: rhs)
            let leftScore = LegendsMatchSelectors.chanceCreation(left) + LegendsMatchSelectors.passing(left)
            let rightScore = LegendsMatchSelectors.chanceCreation(right) + LegendsMatchSelectors.passing(right)
            return leftScore == rightScore ? lhs.id > rhs.id : leftScore < rightScore
        }.map { ($0.id, $0.name) }
    }

    private func pickOpponentCreator(excluding shooterID: String) -> (id: String, name: String)? {
        let candidates = opponentRoster.players.filter { $0.id != shooterID }
        let preferred = candidates.filter { $0.position.broad == .midfielder || $0.position.broad == .forward }
        let pool = preferred.isEmpty ? candidates : preferred
        return pool.max { lhs, rhs in
            let leftScore = LegendsMatchSelectors.chanceCreation(lhs.detailed) + LegendsMatchSelectors.passing(lhs.detailed)
            let rightScore = LegendsMatchSelectors.chanceCreation(rhs.detailed) + LegendsMatchSelectors.passing(rhs.detailed)
            return leftScore == rightScore ? lhs.id > rhs.id : leftScore < rightScore
        }.map { ($0.id, $0.name) }
    }

    /// Weighted toward the on-pitch defenders' average, plus the user's
    /// actual on-pitch goalkeeper standing in for shot-stopping.
    private func userDefenseSelection() -> DefenseSelection {
        let outfield: [LegendsCard] = slots.indices.compactMap { index in
            guard slots[index].broad != .goalkeeper, let cardID = onPitchCardIDs[index] else { return nil }
            return LegendsCardDatabase.all.first { $0.id == cardID }
        }
        let defenders = outfield.filter { $0.position.broad == .defender }
        let pool = defenders.isEmpty ? outfield : defenders
        let marker = pool.max { lhs, rhs in
            let left = LegendsMatchSelectors.defending(store.effectiveDetailedAttributes(for: lhs))
            let right = LegendsMatchSelectors.defending(store.effectiveDetailedAttributes(for: rhs))
            return left == right ? lhs.id > rhs.id : left < right
        }
        let keeper: LegendsCard? = slots.indices.compactMap { index -> LegendsCard? in
            guard slots[index] == .goalkeeper, let cardID = onPitchCardIDs[index] else { return nil }
            return LegendsCardDatabase.all.first { $0.id == cardID }
        }.first
        let markerAttributes = marker.map { store.effectiveDetailedAttributes(for: $0) }
        let keeperOverall = keeper.map { card in
            let keeper = LegendsMatchSelectors.goalkeeper(store.effectiveDetailedAttributes(for: card))
            return Int((Double(store.effectiveOverall(for: card)) * 0.7 + Double(keeper) * 0.3).rounded())
        } ?? opponent.rating
        return DefenseSelection(
            contestant: DefenseContestant(
                defending: markerAttributes.map { LegendsMatchSelectors.defending($0) } ?? opponent.rating,
                physical: markerAttributes?.strength ?? opponent.rating,
                keeperOverall: keeperOverall
            ),
            markerID: marker?.id, markerName: marker?.name,
            goalkeeperID: keeper?.id, goalkeeperName: keeper?.name
        )
    }

    private func opponentDefenseSelection() -> DefenseSelection {
        let defenders = opponentRoster.players.filter { $0.position.broad == .defender }
        let outfield = opponentRoster.players.filter { $0.position.broad != .goalkeeper }
        let pool = defenders.isEmpty ? outfield : defenders
        let marker = pool.max { lhs, rhs in
            let left = LegendsMatchSelectors.defending(lhs.detailed)
            let right = LegendsMatchSelectors.defending(rhs.detailed)
            return left == right ? lhs.id > rhs.id : left < right
        }
        let keeper = opponentRoster.players.first { $0.position == .goalkeeper }
        return DefenseSelection(
            contestant: DefenseContestant(
                defending: marker.map { LegendsMatchSelectors.defending($0.detailed) } ?? opponent.rating,
                physical: marker?.physical ?? opponent.rating,
                keeperOverall: keeper.map { LegendsMatchSelectors.goalkeeper($0.detailed) } ?? opponent.rating
            ),
            markerID: marker?.id, markerName: marker?.name,
            goalkeeperID: keeper?.id, goalkeeperName: keeper?.name
        )
    }

    /// `scorerCardID` is only ever supplied for the user side —
    /// `scorerCardIDs` is user-scoped bookkeeping (nothing in the UI
    /// reads an opponent-side equivalent), while `scorerName` names
    /// whoever actually took the shot on both sides, finally giving
    /// opponent goals a named scorer in commentary — they previously had
    /// none at all.
    private func scoreGoal(_ event: LegendsMatchEvent) {
        if event.isUserEvent {
            teamGoals += 1
            scorerCardIDs.append(event.shooterID)
            let assist = event.creatorName.map { " (assist: \($0))" } ?? ""
            say("⚽︎ GOAL! \(event.shooterName)!\(assist) \(event.presentationScript.detailedText) \(store.profile.clubName) \(teamGoals)-\(opponentGoals) \(opponent.name)", side: .home)
            bumpMomentum(towardUser: true, by: 0.22)
            SoundManager.shared.play(.goalCrowd)
        } else {
            opponentGoals += 1
            let assist = event.creatorName.map { " (assist: \($0))" } ?? ""
            say("⚽︎ GOAL! \(event.shooterName)!\(assist) \(event.presentationScript.detailedText) \(opponent.name) \(opponentGoals)-\(teamGoals) \(store.profile.clubName)", side: .away)
            bumpMomentum(towardUser: false, by: 0.22)
        }
        if minute > 45 { secondHalfEventCount += 1 }
    }

    private func bumpMomentum(towardUser: Bool, by amount: Double) {
        let delta = towardUser ? amount : -amount
        momentum = min(0.85, max(0.15, momentum + delta))
    }

    private func recomputeMomentum() {
        momentum += (0.5 - momentum) * 0.12
    }

    private func finishMatch() {
        isFinished = true
        isPaused = true
        say("Full-time! \(store.profile.clubName) \(teamGoals)-\(opponentGoals) \(opponent.name)")
        SoundManager.shared.play(.whistleFullTime)
    }

    // MARK: - Substitutions

    /// No position-legality rule (matches Career): `off` just needs to be
    /// currently on the pitch, `on` currently on the bench. A subbed-off
    /// card doesn't return to the bench — same as real football, once
    /// they're off, they're out for the rest of the match.
    @discardableResult
    func makeUserSub(offCardID: String, onCardID: String) -> Bool {
        guard subsLeft > 0 else { return false }
        guard let slotIndex = onPitchCardIDs.firstIndex(of: offCardID) else { return false }
        guard let benchIndex = benchCardIDs.firstIndex(of: onCardID) else { return false }

        let offName = LegendsCardDatabase.all.first { $0.id == offCardID }?.name ?? ""
        let onName = LegendsCardDatabase.all.first { $0.id == onCardID }?.name ?? ""

        onPitchCardIDs[slotIndex] = onCardID
        minutesPlayedByCardID[onCardID, default: 0] = 0
        energyBySlot[slotIndex] = 100
        benchCardIDs.remove(at: benchIndex)

        subsLeft -= 1
        substitutionFlashCount += 1
        lastSubOffName = offName
        lastSubOnName = onName
        say("🔄 \(onName) replaces \(offName).", side: .home)
        SoundManager.shared.play(.substitution)
        if minute > 45 { secondHalfEventCount += 1 }
        return true
    }

    // MARK: - Commentary

    private func say(_ text: String, side: Side? = nil) {
        let label = minute > 90 ? "90+\(minute - 90)" : "\(minute)"
        commentary.append(CommentaryLine(text: "\(label)'  \(text)", side: side))
        if commentary.count > 60 { commentary.removeFirst(commentary.count - 60) }
    }
}
