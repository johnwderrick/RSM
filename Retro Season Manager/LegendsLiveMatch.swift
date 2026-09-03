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
    enum Outcome: Equatable { case goal, saved }
    enum Channel: Equatable { case left, right }

    let id: String
    let minute: Int
    let side: Side
    let outcome: Outcome
    let channel: Channel
    let creatorID: String?
    let creatorName: String?
    let shooterID: String
    let shooterName: String
    let markerID: String?
    let markerName: String?
    let goalkeeperID: String?
    let goalkeeperName: String?
    let expectedGoals: Double

    var scored: Bool { outcome == .goal }
    var isUserEvent: Bool { side == .home }
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
        isPaused = true
    }

    func skipToEnd() {
        isHalfTime = false
        isPaused = false
        while !isFinished { tick() }
    }

    /// Synchronous single-minute advance, no delay — the async-free path
    /// unit tests drive instead of the real `Task`-based loop in `start()`.
    func testAdvanceMinute() {
        isHalfTime = false
        tick()
    }

    private func loop() async {
        // `Task.isCancelled` matters as much as `isFinished`: `stop()`
        // (the abandon path) cancels the task, and without checking it
        // here the loop would keep sleeping forever in the paused branch
        // — `try?` swallows the cancellation error — leaking the engine.
        while !isFinished && !Task.isCancelled {
            if isPaused || isHalfTime {
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
        rollGoalChances()
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
        let event = LegendsMatchEvent(
            id: "M\(minute)-E\(eventSequence)", minute: minute,
            side: forUser ? .home : .away,
            outcome: scored ? .goal : .saved,
            channel: eventSequence.isMultiple(of: 2) ? .right : .left,
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
            let keeper = event.goalkeeperName.map { " — \($0) saves!" } ?? " — the keeper stands tall!"
            say("Big chance for \(forUser ? store.profile.clubName : opponent.name): \(attacker.name) shoots\(keeper)", side: event.side)
            bumpMomentum(towardUser: forUser, by: 0.05)
        }
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
            say("⚽︎ GOAL! \(event.shooterName)!\(assist) \(store.profile.clubName) \(teamGoals)-\(opponentGoals) \(opponent.name)", side: .home)
            bumpMomentum(towardUser: true, by: 0.22)
            SoundManager.shared.play(.goalCrowd)
        } else {
            opponentGoals += 1
            let assist = event.creatorName.map { " (assist: \($0))" } ?? ""
            say("⚽︎ GOAL! \(event.shooterName)!\(assist) \(opponent.name) \(opponentGoals)-\(teamGoals) \(store.profile.clubName)", side: .away)
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
