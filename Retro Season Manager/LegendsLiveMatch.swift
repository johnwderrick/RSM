//
//  LegendsLiveMatch.swift
//  Retro Season Manager
//
//  A minute-by-minute live match engine for RSM Legends, mirroring
//  Career Mode's LiveMatch.swift structurally (tick loop, pause/speed,
//  mentality/instruction, substitutions, commentary, momentum) but
//  scaled to what Legends actually has: one aggregate card per Starting
//  XI slot instead of full Player objects, no opponent roster (a
//  generated LegendsOpponent has no bench to sub from or fatigue to
//  track), and no cards/injuries/weather (Legends has no underlying
//  data for any of those yet).
//
//  Rather than a full chance-generation model, each minute rolls two
//  independent Bernoulli trials — one per side — using
//  `p = 2.7 * ratio / 90`. Summing ~90 independent low-probability
//  trials approximates a Poisson(2.7*ratio) distribution, so this stays
//  tuned to the same "2.7 goals per game" constant
//  LegendsMatchEngine.simulate(...) already uses, while letting a
//  mid-match mentality/instruction change genuinely shift the odds for
//  every remaining minute — unlike pre-computing the final score and
//  just animating it, which would make mid-match changes cosmetic only.
//

import Foundation
import Observation

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

    init(store: LegendsStore, opponent: LegendsOpponent) {
        self.store = store
        self.opponent = opponent
        self.slots = store.startingXISlots
        self.onPitchCardIDs = store.profile.startingXICardIDs
        self.energyBySlot = Array(repeating: 100.0, count: slots.count)
        self.benchCardIDs = store.profile.benchCardIDs.compactMap { $0 }
        self.userMentality = store.profile.preferredMentality
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

    // MARK: - Tick

    private func tick() {
        guard !isFinished else { return }
        minute += 1

        if minute == 45 && !halfTimeTaken {
            halfTimeTaken = true
            isHalfTime = true
            isPaused = true
            say("Half-time.")
            SoundManager.shared.play(.whistleHalfTime)
            return
        }

        if minute == 90 && addedTime == 0 {
            addedTime = min(6, 1 + secondHalfEventCount / 2 + Int.random(in: 0...1))
        }

        decayEnergy()
        rollGoalChances()
        recomputeMomentum()

        if minute >= totalMinutes {
            finishMatch()
        }
    }

    private func decayEnergy() {
        for index in energyBySlot.indices where onPitchCardIDs[index] != nil {
            energyBySlot[index] = max(20, energyBySlot[index] - Double.random(in: 0.2...0.5))
        }
    }

    /// Independent attack/defence ratios (see file header) rather than
    /// one shared ratio — lets mentality/instruction bite on "how often
    /// do I score" and "how often do I concede" separately.
    private func rollGoalChances() {
        let liveAttack = energyWeightedAverage { $0.broad == .midfielder || $0.broad == .forward }
        let liveDefence = energyWeightedAverage { $0 == .goalkeeper || $0.broad == .defender }
        let oppRating = Double(opponent.rating)

        let effectiveAttack = max(liveAttack * userMentality.attack * userInstruction.attack, 1)
        let effectiveDefence = max(liveDefence * userMentality.solidity * userInstruction.solidity, 1)

        let userRatio = effectiveAttack / (effectiveAttack + oppRating)
        let opponentRatio = oppRating / (oppRating + effectiveDefence)

        let pUser = 2.7 * userRatio / 90
        let pOpponent = 2.7 * opponentRatio / 90

        if Double.random(in: 0..<1) < pUser {
            scoreGoal(forUser: true)
        } else if Double.random(in: 0..<1) < 0.025 {
            say("Big chance for \(store.profile.clubName) — just wide!", side: .home)
            bumpMomentum(towardUser: true, by: 0.05)
        }

        if Double.random(in: 0..<1) < pOpponent {
            scoreGoal(forUser: false)
        } else if Double.random(in: 0..<1) < 0.025 {
            say("\(opponent.name) go close, but it drifts past the post.", side: .away)
            bumpMomentum(towardUser: false, by: 0.05)
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

    private func scoreGoal(forUser: Bool) {
        if forUser {
            teamGoals += 1
            let scorer = weightedScorer()
            if let scorer { scorerCardIDs.append(scorer.id) }
            let scorerText = scorer.map { " \($0.name)!" } ?? ""
            say("⚽︎ GOAL!\(scorerText) \(store.profile.clubName) \(teamGoals)-\(opponentGoals) \(opponent.name)", side: .home)
            bumpMomentum(towardUser: true, by: 0.22)
            SoundManager.shared.play(.goalCrowd)
        } else {
            opponentGoals += 1
            say("⚽︎ GOAL! \(opponent.name) \(opponentGoals)-\(teamGoals) \(store.profile.clubName)", side: .away)
            bumpMomentum(towardUser: false, by: 0.22)
        }
        if minute > 45 { secondHalfEventCount += 1 }
    }

    /// Forward-heaviest, matching Career's `attributeGoals` shape —
    /// weighted by each card's own `shooting` and overall rather than a
    /// second attribute system Legends doesn't have.
    private func weightedScorer() -> LegendsCard? {
        let onPitch = userOnPitchCards
        guard !onPitch.isEmpty else { return nil }
        func weight(_ card: LegendsCard) -> Double {
            let positionWeight: Double
            switch card.position.broad {
            case .forward: positionWeight = 5
            case .midfielder: positionWeight = 2
            case .defender: positionWeight = 0.3
            case .goalkeeper: positionWeight = 0.02
            }
            return positionWeight * (Double(card.shooting) * 2.5 + Double(store.effectiveOverall(for: card)) * 0.3)
        }
        let totalWeight = onPitch.reduce(0.0) { $0 + weight($1) }
        guard totalWeight > 0 else { return onPitch.randomElement() }
        var roll = Double.random(in: 0..<totalWeight)
        for card in onPitch {
            roll -= weight(card)
            if roll < 0 { return card }
        }
        return onPitch.last
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
