//
//  LegendsLiveMatchTests.swift
//  Retro Season ManagerTests
//
//  Guards LegendsLiveMatch's engine math (goal-rate math, energy decay,
//  substitutions, momentum, scorer weighting, the finish condition) —
//  driven entirely through `testAdvanceMinute()`/`skipToEnd()`, never
//  the real async `start()` loop, so these stay fully synchronous.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsLiveMatchTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = 0
        store.profile.cardUpgrades = [:]
        store.profile.duplicateProgress = [:]
        store.profile.preferredMentality = .balanced
        // LegendsStore() loads whatever's actually on disk — the
        // strong-vs-weak goal-rate comparisons below depend on
        // effectiveOverall() being predictable, and it also subtracts an
        // aging penalty, so a real playthrough's cardAgeOffsets otherwise
        // leaks into these statistical tests.
        store.profile.cardAgeOffsets = [:]
        return store
    }

    /// Fills the XI with the N unique-named cards a `sorted`-and-deduped
    /// list starts with, then fills the bench with the next few — mirrors
    /// the same "one card per real-ish player" dedup other Legends test
    /// files already work around (LegendsMatchTests.swift's `fillStrongXI`).
    private func fillSquad(_ store: LegendsStore, preferring sorted: [LegendsCard]) {
        var seenNames = Set<String>()
        let unique = sorted.filter { seenNames.insert($0.name).inserted }
        let slots = store.startingXISlots
        for i in 0..<slots.count {
            store.assign(cardID: unique[i].id, toXISlot: i)
        }
        for i in 0..<min(LegendsStore.benchSize, unique.count - slots.count) {
            store.assign(cardID: unique[slots.count + i].id, toBenchSlot: i)
        }
    }

    private func strongestXI(_ store: LegendsStore) {
        fillSquad(store, preferring: LegendsCardDatabase.all.sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) })
    }

    private func weakestXI(_ store: LegendsStore) {
        fillSquad(store, preferring: LegendsCardDatabase.all.sorted { store.effectiveOverall(for: $0) < store.effectiveOverall(for: $1) })
    }

    private func averageGoals(trials: Int, setup: (LegendsStore) -> Void, configure: (LegendsLiveMatch) -> Void = { _ in }) async -> Double {
        var total = 0
        for _ in 0..<trials {
            let store = await freshStore()
            setup(store)
            let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
            configure(live)
            live.skipToEnd()
            total += live.teamGoals
        }
        return Double(total) / Double(trials)
    }

    /// Runs `trials` *paired* matches — trial `i` feeds `setupA` and
    /// `setupB` the identical seeded roll sequence
    /// (`SeededGenerator(seed: "pair-\(i)")`), so up until whatever
    /// they're being compared on first causes the two matches to
    /// diverge, both see exactly the same rolls. That cancels out
    /// ordinary match-to-match Poisson noise and leaves (mostly) just the
    /// effect being tested, so a genuinely small effect — a single
    /// manager's few-point flat bonus, say — becomes statistically
    /// reliable at a few hundred trials instead of the tens of thousands
    /// `averageGoals`'s independent-samples comparison would need. See
    /// `LegendsLiveMatch.rng` for the injection point this relies on.
    private func pairedAverageGoalsDelta(trials: Int, setupA: (LegendsStore) -> Void, setupB: (LegendsStore) -> Void) async -> Double {
        var totalDelta = 0
        for i in 0..<trials {
            let storeA = await freshStore()
            setupA(storeA)
            let liveA = LegendsLiveMatch(store: storeA, opponent: LegendsOpponent(name: "Rival XI", rating: 60),
                                          rng: SeededGenerator(seed: "pair-\(i)"))
            liveA.skipToEnd()

            let storeB = await freshStore()
            setupB(storeB)
            let liveB = LegendsLiveMatch(store: storeB, opponent: LegendsOpponent(name: "Rival XI", rating: 60),
                                          rng: SeededGenerator(seed: "pair-\(i)"))
            liveB.skipToEnd()

            totalDelta += liveA.teamGoals - liveB.teamGoals
        }
        return Double(totalDelta) / Double(trials)
    }

    // These are statistical comparisons over independent Bernoulli trials
    // per minute — with means this small (~1.5-2 goals/match) the
    // standard error at a few hundred trials is close enough to the true
    // gap between groups that 150 trials flaked once in testing. 800
    // trials brings the standard error well below the gap being tested
    // for, at a runtime cost of well under a second per test.
    private let statisticalTrialCount = 1200

    // The manager/stadium comparison has a much smaller effect size than
    // the three tests above sharing `statisticalTrialCount` (a single
    // manager+stadium bonus is a few flat points against an attack rating
    // in the 80s-90s), which made it flake even at 2400 independent-sample
    // trials (bumped 800→1200 during the item 10 polish pass, then flaked
    // again 2-of-3 runs at 1200, then 1-of-3 at 2400 — the math says a
    // reliable independent-samples version of this test would need
    // somewhere north of 10,000 trials per side, several minutes just for
    // this one test). It now runs as *paired* trials instead
    // (`pairedAverageGoalsDelta`, same seeded roll sequence on both sides
    // of each pair), which cancels out the match-to-match noise doing the
    // damage rather than trying to out-sample it — paired trials ran green
    // 4/4 at 2400 (vs. flaking repeatedly at 2400 unpaired), then 5/5 at
    // this trimmed-down count, so this has real margin, not just luck.
    private let managerStadiumTrialCount = 500

    func testGoalRateIncreasesWithStrongerAttackRating() async {
        let strongAvg = await averageGoals(trials: statisticalTrialCount) { self.strongestXI($0) }
        let weakAvg = await averageGoals(trials: statisticalTrialCount) { self.weakestXI($0) }
        XCTAssertGreaterThan(strongAvg, weakAvg, "A far stronger XI should average more goals across many matches")
    }

    func testAttackingMentalityScoresMoreThanDefensiveMentalityOnAverage() async {
        let attackingAvg = await averageGoals(trials: statisticalTrialCount, setup: { self.strongestXI($0) }, configure: { $0.userMentality = .attacking })
        let defensiveAvg = await averageGoals(trials: statisticalTrialCount, setup: { self.strongestXI($0) }, configure: { $0.userMentality = .defensive })
        XCTAssertGreaterThan(attackingAvg, defensiveAvg, "Attacking mentality should out-score defensive mentality on average, not just cosmetically")
    }

    func testPushForwardInstructionIncreasesGoalsIndependentlyOfMentality() async {
        let pushAvg = await averageGoals(trials: statisticalTrialCount, setup: { self.strongestXI($0) }, configure: { $0.userInstruction = .pushForward })
        let containAvg = await averageGoals(trials: statisticalTrialCount, setup: { self.strongestXI($0) }, configure: { $0.userInstruction = .containment })
        XCTAssertGreaterThan(pushAvg, containAvg, "Push Forward should out-score Containment on average, independent of mentality")
    }

    /// Regression guard for a real gap: managers/stadiums/chemistry used
    /// to only affect the old instant-sim engine, never the live engine a
    /// real player actually plays through — see `strengthBonus` in
    /// `LegendsLiveMatch.swift`.
    func testActiveManagerAndStadiumIncreaseGoalsOnAverage() async {
        func withManagerAndStadium(_ store: LegendsStore) {
            strongestXI(store)
            let manager = LegendsManagerDatabase.all.first!
            store.profile.ownedManagerIDs = [manager.id]
            store.setActiveManager(manager.id)
            let stadium = LegendsStadiumDatabase.all.first!
            store.profile.ownedStadiumIDs = [stadium.id]
            store.setActiveStadium(stadium.id)
        }
        func withoutManagerOrStadium(_ store: LegendsStore) {
            strongestXI(store)
            store.profile.ownedManagerIDs = []
            store.profile.activeManagerID = nil
            store.profile.ownedStadiumIDs = []
            store.profile.activeStadiumID = nil
        }

        // A single manager's tactical bonus plus a stadium's gameplay
        // bonus is a small flat add-on (a few points) against an attack
        // rating in the 80s-90s — independent-samples averaging needs
        // tens of thousands of trials to see that reliably through
        // ordinary match-to-match noise (confirmed: 2400 trials still
        // flaked). Paired trials cancel that noise out instead.
        let avgDelta = await pairedAverageGoalsDelta(trials: managerStadiumTrialCount,
                                                      setupA: withManagerAndStadium, setupB: withoutManagerOrStadium)
        XCTAssertGreaterThan(avgDelta, 0, "An active manager and stadium should raise the live match's average goals, not just the retired instant-sim path's")
    }

    func testEnergyDecaysEachMinuteForOnPitchSlotsOnly() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        let startingEnergy = live.energyBySlot

        for _ in 0..<10 { live.testAdvanceMinute() }

        for i in live.energyBySlot.indices {
            XCTAssertLessThanOrEqual(live.energyBySlot[i], startingEnergy[i], "Energy should never increase on its own")
            XCTAssertGreaterThanOrEqual(live.energyBySlot[i], 20, "Energy should be floored at 20")
        }
        XCTAssertTrue(live.energyBySlot.contains { $0 < 100 }, "At least one slot should have decayed after 10 minutes")
    }

    func testSubstitutionResetsSlotEnergyAndDecrementsSubsLeft() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        for _ in 0..<20 { live.testAdvanceMinute() }

        let offCardID = live.onPitchCardIDs[0]!
        let onCardID = live.benchCardIDs.first!
        let subsBefore = live.subsLeft

        let succeeded = live.makeUserSub(offCardID: offCardID, onCardID: onCardID)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(live.onPitchCardIDs[0], onCardID)
        XCTAssertEqual(live.energyBySlot[0], 100)
        XCTAssertEqual(live.subsLeft, subsBefore - 1)
        XCTAssertFalse(live.benchCardIDs.contains(onCardID), "The subbed-on card should leave the bench pool")
        XCTAssertFalse(live.benchCardIDs.contains(offCardID), "A subbed-off card doesn't return to the bench, same as real football")
    }

    func testSubstitutionFailsOnceSubsAreExhausted() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))

        for i in 0..<5 {
            let off = live.onPitchCardIDs[i]!
            let on = live.benchCardIDs.first!
            XCTAssertTrue(live.makeUserSub(offCardID: off, onCardID: on))
        }
        XCTAssertEqual(live.subsLeft, 0)

        let off = live.onPitchCardIDs[5]!
        let on = live.benchCardIDs.first ?? "nonexistent"
        XCTAssertFalse(live.makeUserSub(offCardID: off, onCardID: on))
    }

    func testSubstitutionFailsForACardNotOnTheBench() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        let off = live.onPitchCardIDs[0]!
        XCTAssertFalse(live.makeUserSub(offCardID: off, onCardID: "not-a-real-card-id"))
        XCTAssertEqual(live.onPitchCardIDs[0], off, "A failed sub shouldn't mutate the pitch")
    }

    func testMatchFinishesExactlyAtNinetyPlusAddedTime() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        live.skipToEnd()

        XCTAssertTrue(live.isFinished)
        XCTAssertEqual(live.minute, live.totalMinutes)
        let goalsAtFinish = (live.teamGoals, live.opponentGoals)
        live.testAdvanceMinute()
        XCTAssertEqual(live.teamGoals, goalsAtFinish.0, "A finished match shouldn't keep ticking")
        XCTAssertEqual(live.opponentGoals, goalsAtFinish.1)
    }

    func testHalfTimePausesPlayAtMinuteFortyFive() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        for _ in 0..<45 { live.testAdvanceMinute() }
        XCTAssertTrue(live.isHalfTime)
        XCTAssertTrue(live.isPaused)
        XCTAssertEqual(live.minute, 45)
    }

    func testResultBridgeReflectsAccumulatedGoals() async {
        let store = await freshStore()
        strongestXI(store)
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        live.skipToEnd()
        XCTAssertEqual(live.result.teamGoals, live.teamGoals)
        XCTAssertEqual(live.result.opponentGoals, live.opponentGoals)
    }

    func testScorerSelectionIsWeightedTowardAttackingPositions() async {
        let store = await freshStore()
        // A forward-heavy pool (every slot filled with the same striker's
        // teammates skewed toward attackers isn't representative — instead
        // just use the strongest XI, which is dominated by Icon/Legend
        // attackers in the current database, and confirm scorers skew that way.
        strongestXI(store)
        var forwardOrMidGoals = 0
        var totalGoals = 0
        for _ in 0..<40 {
            let trialStore = await freshStore()
            strongestXI(trialStore)
            let live = LegendsLiveMatch(store: trialStore, opponent: LegendsOpponent(name: "Rival XI", rating: 40))
            live.skipToEnd()
            for scorerID in live.scorerCardIDs {
                totalGoals += 1
                if let card = LegendsCardDatabase.all.first(where: { $0.id == scorerID }),
                   card.position.broad == .forward || card.position.broad == .midfielder {
                    forwardOrMidGoals += 1
                }
            }
        }
        guard totalGoals > 0 else { return XCTFail("Expected at least some goals across 40 near-certain-win trials") }
        XCTAssertGreaterThan(Double(forwardOrMidGoals) / Double(totalGoals), 0.8,
                              "Scorers should overwhelmingly be midfielders/forwards, not defenders or the goalkeeper")
    }

    /// `stop()` is the abandon path — it must cancel the real async loop
    /// so no further minutes tick, and leave the engine paused. This is
    /// the one test here that drives the live `start()` loop rather than
    /// `testAdvanceMinute()`, since it's specifically about that loop's
    /// teardown. Speed is set to 3× first so a *live* (uncancelled) loop
    /// would tick roughly every ~230ms — comfortably inside the sleep
    /// below — making a stopped engine's silence a meaningful signal.
    func testStopCancelsTheLiveLoopSoAnAbandonedMatchGoesQuiet() async {
        let store = await freshStore()
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        live.setSpeed(3)
        live.start()
        try? await Task.sleep(for: .milliseconds(150))
        live.stop()
        let minuteAtStop = live.minute
        XCTAssertTrue(live.isPaused, "stop() should leave the engine paused")

        try? await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(live.minute, minuteAtStop,
                       "No further minutes should tick after stop() — the live loop must be cancelled, not just paused")
    }
}
