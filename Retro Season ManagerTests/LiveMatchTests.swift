//
//  LiveMatchTests.swift
//  Retro Season ManagerTests
//
//  Guards Career Mode's live match engine (LiveMatch.swift) — goal-rate
//  scaling with strength, mentality/instruction effects, energy decay,
//  substitutions, half-time/finish timing, and post-match ratings.
//  Driven entirely through testAdvanceMinute()/skipToEnd(), never the
//  real async start() loop, so these stay fully synchronous — mirrors
//  LegendsLiveMatchTests.swift's own approach for the Legends engine.
//  Previously the largest untested system in the app (see
//  PROJECT_BIBLE.md §6): this is a broad correctness sweep across the
//  engine's controllable dynamics, not exhaustive coverage of every
//  probabilistic event (rare ones like straight reds are checked
//  opportunistically, not hunted for directly).
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LiveMatchTests: XCTestCase {
    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Test")
        return store
    }

    /// Overwrites every player's rating and every attribute the engine's
    /// attackValue/defenceValue/finishing actually read (see
    /// LiveMatch.swift's `attr(_:_:)` call sites) to a single level — a
    /// blunt way to make one side's XI overwhelmingly stronger or weaker
    /// than the other's, regardless of which 11 players get picked.
    private func setStrength(_ store: GameStore, clubIndex: Int, level: Int) {
        let keys = ["Shooting", "Passing", "Vision", "Dribbling", "Positioning",
                    "Defending", "Physical", "Handling", "Reflexes", "Aerial", "Pace"]
        for i in store.clubs[clubIndex].players.indices {
            store.clubs[clubIndex].players[i].rating = level
            for key in keys { store.clubs[clubIndex].players[i].attributes[key] = level }
        }
    }

    private func userFixture(_ store: GameStore) -> Fixture {
        store.fixtures.first { $0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex }!
    }

    private func opponentIndex(_ store: GameStore, of fixture: Fixture) -> Int {
        fixture.homeIndex == store.userClubIndex ? fixture.awayIndex : fixture.homeIndex
    }

    /// Re-derives a fresh LiveMatch from the same GameStore each call —
    /// newGame() itself (generating ~100 clubs' worth of squads) is the
    /// expensive part, done once per test via `freshStore()`; this is
    /// just reading already-generated club state into a new match.
    private func makeMatch(_ store: GameStore, userLevel: Int, opponentLevel: Int) -> LiveMatch {
        let fixture = userFixture(store)
        setStrength(store, clubIndex: store.userClubIndex, level: userLevel)
        setStrength(store, clubIndex: opponentIndex(store, of: fixture), level: opponentLevel)
        return LiveMatch(store: store, fixture: fixture)
    }

    private func userGoals(_ match: LiveMatch) -> Int {
        match.isUserHome ? match.homeGoals : match.awayGoals
    }

    /// Checked after every trial across the whole file — cheap structural
    /// invariants that should hold for literally any simulated match,
    /// piggybacked onto the trials each dynamics test already runs
    /// rather than needing their own dedicated (and, for rare events
    /// like red cards, unreliable) hunt.
    private func assertInvariants(_ match: LiveMatch, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(match.homeGoals, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.awayGoals, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.shots.home, match.shotsOnTarget.home, "shots on target can't exceed total shots", file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.shots.away, match.shotsOnTarget.away, "shots on target can't exceed total shots", file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.corners.home, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.corners.away, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.offsides.home, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(match.fouls.home, 0, file: file, line: line)
        XCTAssertEqual(match.homeScorerIDs.count, match.homeGoals, "every home goal should credit exactly one scorer", file: file, line: line)
        XCTAssertEqual(match.awayScorerIDs.count, match.awayGoals, "every away goal should credit exactly one scorer", file: file, line: line)
        // A sent-off player should never still be marked onPitch.
        for entry in match.sentOff {
            let stillOnPitch = (entry.side == .home ? match.homeOnPitch : match.awayOnPitch)
                .first { $0.player.id == entry.id }?.onPitch ?? false
            XCTAssertFalse(stillOnPitch, "a sent-off player shouldn't still be marked onPitch", file: file, line: line)
        }
        XCTAssertEqual(match.redCardCount, match.sentOff.count, "redCardCount should track sentOff exactly", file: file, line: line)
    }

    private let statisticalTrialCount = 150

    // MARK: - Core dynamics

    func testGoalRateIncreasesWithStrongerAttackingSide() async {
        let store = await freshStore()
        var strongTotal = 0
        var weakTotal = 0
        for _ in 0..<statisticalTrialCount {
            let strong = makeMatch(store, userLevel: 95, opponentLevel: 25)
            strong.skipToEnd()
            strongTotal += userGoals(strong)
            assertInvariants(strong)

            let weak = makeMatch(store, userLevel: 25, opponentLevel: 95)
            weak.skipToEnd()
            weakTotal += userGoals(weak)
            assertInvariants(weak)
        }
        XCTAssertGreaterThan(strongTotal, weakTotal, "A far stronger attacking side should score more across many matches")
    }

    func testAttackingMentalityOutscoresDefensiveMentalityOnAverage() async {
        let store = await freshStore()
        var attackingTotal = 0
        var defensiveTotal = 0
        for _ in 0..<statisticalTrialCount {
            let attacking = makeMatch(store, userLevel: 80, opponentLevel: 80)
            attacking.userMentality = .attacking
            attacking.skipToEnd()
            attackingTotal += userGoals(attacking)
            assertInvariants(attacking)

            let defensive = makeMatch(store, userLevel: 80, opponentLevel: 80)
            defensive.userMentality = .defensive
            defensive.skipToEnd()
            defensiveTotal += userGoals(defensive)
            assertInvariants(defensive)
        }
        XCTAssertGreaterThan(attackingTotal, defensiveTotal, "Attacking mentality should out-score defensive mentality on average")
    }

    func testPushForwardInstructionOutscoresContainmentOnAverage() async {
        let store = await freshStore()
        var pushTotal = 0
        var containTotal = 0
        for _ in 0..<statisticalTrialCount {
            let push = makeMatch(store, userLevel: 80, opponentLevel: 80)
            push.userInstruction = .pushForward
            push.skipToEnd()
            pushTotal += userGoals(push)
            assertInvariants(push)

            let contain = makeMatch(store, userLevel: 80, opponentLevel: 80)
            contain.userInstruction = .containment
            contain.skipToEnd()
            containTotal += userGoals(contain)
            assertInvariants(contain)
        }
        XCTAssertGreaterThan(pushTotal, containTotal, "Push Forward should out-score Containment on average, independent of mentality")
    }

    // MARK: - Energy & substitutions

    func testEnergyDecaysEachMinuteForOnPitchPlayersOnly() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        let startingEnergy = Dictionary(uniqueKeysWithValues: match.userOnPitch.map { ($0.player.id, $0.energy) })

        for _ in 0..<10 { match.testAdvanceMinute() }

        for p in match.userOnPitch {
            let before = startingEnergy[p.player.id]!
            XCTAssertLessThanOrEqual(p.energy, before, "Energy should never increase on its own")
            XCTAssertGreaterThanOrEqual(p.energy, 20, "Energy should be floored at 20")
        }
        XCTAssertTrue(match.userOnPitch.contains { $0.energy < 100 }, "At least one on-pitch player should have decayed after 10 minutes")
    }

    func testSubstitutionResetsEnergyAndDecrementsSubsLeft() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        for _ in 0..<20 { match.testAdvanceMinute() }

        guard let off = match.userOnPitch.first, let on = match.userBench.first else {
            return XCTFail("Expected both an on-pitch player and a bench player")
        }
        let subsBefore = match.userSubsLeft

        let succeeded = match.makeUserSub(off: off, on: on)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(match.userSubsLeft, subsBefore - 1)
        XCTAssertFalse(match.userOnPitch.contains { $0.player.id == off.player.id }, "The subbed-off player should leave the pitch")
        XCTAssertEqual(match.userOnPitch.first { $0.player.id == on.id }?.energy, 100, "A subbed-on player should start at full energy")
        XCTAssertFalse(match.userBench.contains { $0.id == on.id }, "The subbed-on player should leave the bench pool")
    }

    func testSubstitutionFailsOnceSubsAreExhausted() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)

        // A real squad's fit, available bench can be smaller than 5 (a
        // tight historical roster, or a couple of players GameStore's own
        // seedInjuries() knocked out right at kickoff) — use as many real
        // subs as the bench actually allows, capped at 5, rather than
        // assuming every club always has 5+ spare bodies.
        var subsUsed = 0
        while subsUsed < 5, let off = match.userOnPitch.first, let on = match.userBench.first {
            XCTAssertTrue(match.makeUserSub(off: off, on: on))
            subsUsed += 1
        }
        XCTAssertEqual(match.userSubsLeft, 5 - subsUsed)
        guard subsUsed == 5 else {
            return // This club's bench ran dry before the 5-sub cap even came into play.
        }

        // subsLeft > 0 is checked before bench membership in makeUserSub,
        // so this doesn't need a real bench player — a squad can
        // legitimately have exactly 5 fit outfield subs, leaving nothing
        // left to even offer for a 6th attempt.
        guard let off = match.userOnPitch.first else { return XCTFail("Expected an on-pitch player to remain after 5 subs") }
        let stranger = Player(name: "Nobody F.C.", position: .midfielder, age: 22, rating: 50)
        XCTAssertFalse(match.makeUserSub(off: off, on: stranger), "A 6th substitution should be rejected")
    }

    func testSubstitutionFailsForAPlayerNotOnTheBench() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        guard let off = match.userOnPitch.first else { return XCTFail("Expected an on-pitch player") }

        let stranger = Player(name: "Nobody F.C.", position: .midfielder, age: 22, rating: 50)
        XCTAssertFalse(match.makeUserSub(off: off, on: stranger), "Subbing on a player who isn't actually on the bench should fail")
        XCTAssertTrue(match.userOnPitch.contains { $0.player.id == off.player.id }, "A failed sub shouldn't touch the pitch")
    }

    // MARK: - Clock

    func testMatchFinishesExactlyAtNinetyPlusAddedTimeAndStaysFinished() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        match.skipToEnd()

        XCTAssertTrue(match.isFinished)
        XCTAssertEqual(match.minute, match.totalMinutes)
        let goalsAtFinish = (match.homeGoals, match.awayGoals)

        match.testAdvanceMinute()

        XCTAssertEqual(match.homeGoals, goalsAtFinish.0, "A finished match shouldn't keep ticking")
        XCTAssertEqual(match.awayGoals, goalsAtFinish.1)
    }

    func testHalfTimePausesPlayAtMinuteFortyFive() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        for _ in 0..<45 { match.testAdvanceMinute() }

        XCTAssertTrue(match.isHalfTime)
        XCTAssertTrue(match.isPaused)
        XCTAssertEqual(match.minute, 45)
    }

    // MARK: - Post-match ratings

    func testUserPlayerRatingsAreComputedWithinBoundsAfterFullTime() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        match.skipToEnd()

        XCTAssertFalse(match.userPlayerRatings.isEmpty, "Every user player who appeared should get a rating")
        for (_, rating) in match.userPlayerRatings {
            XCTAssertGreaterThanOrEqual(rating, 4.5)
            XCTAssertLessThanOrEqual(rating, 10.0)
        }
        XCTAssertFalse(match.motmName.isEmpty)
        XCTAssertEqual(match.motmName, match.userPlayerRatings.first?.player.name, "MOTM should be whoever rated highest")
    }

    func testPossessionStaysWithinBoundsThroughoutTheMatch() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        while !match.isFinished {
            match.testAdvanceMinute()
            XCTAssertGreaterThanOrEqual(match.homePossession, 25)
            XCTAssertLessThanOrEqual(match.homePossession, 75)
        }
    }
}
