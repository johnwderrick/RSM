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
    private var isolatedRoot: URL!

    override func setUp() {
        super.setUp()
        isolatedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("LiveMatchReview-\(UUID().uuidString)")
        SaveSlots.useIsolatedRootForTesting(isolatedRoot)
        LegacyArchive.useIsolatedRootForTesting(isolatedRoot.appendingPathComponent("legacy"))
    }

    override func tearDown() {
        SaveSlots.useIsolatedRootForTesting(nil)
        LegacyArchive.useIsolatedRootForTesting(nil)
        if testRun?.failureCount == 0 { try? FileManager.default.removeItem(at: isolatedRoot) }
        super.tearDown()
    }
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

    // MARK: - Full-time participation credit (audit)

    /// A 2010 save whose user club holds a round-1 cup tie, so the real
    /// cup finishers have a tie to commit.
    private func cupStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2010, managerName: "Audit")
        return store
    }

    private func goalsByID(_ store: GameStore) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: store.clubs[store.userClubIndex].players.map { ($0.id, $0.goals) })
    }

    private func appsByID(_ store: GameStore) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: store.clubs[store.userClubIndex].players.map { ($0.id, $0.apps) })
    }

    func testLeagueLiveFullTimeCreditsEachUserScorerExactlyOnce() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        let userSide: Side = match.isUserHome ? .home : .away
        match.testScoreGoal(userSide)
        match.testScoreGoal(userSide)
        match.testFinishNow()
        let scorerIDs = userSide == .home ? match.homeScorerIDs : match.awayScorerIDs
        let before = goalsByID(store)

        store.live = match
        store.finishLiveMatch()
        XCTAssertNil(store.live)
        for player in store.clubs[store.userClubIndex].players {
            let expected = before[player.id, default: 0] + scorerIDs.filter { $0 == player.id }.count
            XCTAssertEqual(player.goals, expected, "\(player.name) goals should rise by exactly their live goals")
        }
    }

    func testLiveCupTieFullTimeCreditsUserScorersExactlyOnce() async {
        let store = await cupStore()
        guard let tie = store.nextUserCupTie else { return XCTFail("Expected a round-1 user cup tie") }
        let match = LiveMatch(store: store, knockoutTie: tie, date: store.cupRoundDate(tie.round),
                              competitionName: GameStore.cupName, roundName: "Round 1")
        let userSide: Side = match.isUserHome ? .home : .away
        let otherSide: Side = match.isUserHome ? .away : .home
        match.testScoreGoal(userSide)
        match.testScoreGoal(userSide)
        match.testScoreGoal(otherSide)
        match.testFinishNow()
        let scorerIDs = userSide == .home ? match.homeScorerIDs : match.awayScorerIDs
        let before = Dictionary(uniqueKeysWithValues: store.userClub.players.map { ($0.id, $0.cupGoals) })

        store.live = match
        store.finishLiveMatch()
        XCTAssertNil(store.live)
        for player in store.clubs[store.userClubIndex].players {
            let expected = before[player.id, default: 0] + scorerIDs.filter { $0 == player.id }.count
            XCTAssertEqual(player.cupGoals, expected, "Live cup goals must reach \(player.name)'s career total")
        }
    }

    func testLiveCupGoalsDoNotChangeLeagueGoldenBootTotals() async throws {
        let store = await cupStore()
        let tie = try XCTUnwrap(store.nextUserCupTie)
        let match = LiveMatch(store: store, knockoutTie: tie, date: store.cupRoundDate(tie.round),
                              competitionName: GameStore.cupName, roundName: "Round 1")
        match.testScoreGoal(match.userSide)
        match.testFinishNow()
        let scorerID = try XCTUnwrap((match.isUserHome ? match.homeScorerIDs : match.awayScorerIDs).first)
        let before = try XCTUnwrap(store.userClub.players.first { $0.id == scorerID }).goals
        store.live = match
        store.finishLiveMatch()
        let after = try XCTUnwrap(store.userClub.players.first { $0.id == scorerID }).goals
        XCTAssertEqual(after, before,
                       "Cup goals must not enter Player.goals: goldenBoot/topScorers use this league-goal field")
    }

    func testCupGoalsRoundTripDefaultForOldSavesAndReset() async throws {
        let store = await cupStore()
        let index = store.clubs[store.userClubIndex].players.startIndex
        store.clubs[store.userClubIndex].players[index].goals = 2
        store.clubs[store.userClubIndex].players[index].cupGoals = 3
        let player = store.userClub.players[index]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(player)) as? [String: Any])
        json.removeValue(forKey: "cupGoals")
        let old = try JSONDecoder().decode(Player.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.goals, 2)
        XCTAssertEqual(old.cupGoals, 0)
        store.persist()
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertEqual(reloaded.userClub.players[index].cupGoals, 3)
        XCTAssertEqual(reloaded.userClub.players[index].totalGoals, 5)
        var club = reloaded.userClub
        club.resetSeason()
        XCTAssertEqual(club.players[index].totalGoals, 0)
    }

    func testSeasonHonoursAccumulatesCupOnlyScorerOnce() async {
        let store = await cupStore()
        let index = store.clubs[store.userClubIndex].players.startIndex
        store.clubs[store.userClubIndex].players[index].goals = 0
        store.clubs[store.userClubIndex].players[index].cupGoals = 3
        let name = store.userClub.players[index].name
        let before = store.allTimeScorers[name, default: 0]
        store.recordSeasonHonours()
        XCTAssertEqual(store.allTimeScorers[name], before + 3)
        store.recordSeasonHonours()
        XCTAssertEqual(store.allTimeScorers[name], before + 3)
    }

    func testEveryLiveCupRouteKeepsGoalsOutOfLeagueStandings() async throws {
        for competition in 0..<6 {
            let store = await cupStore()
            let user = store.userClubIndex
            let other = try XCTUnwrap(store.clubs.indices.first { $0 != user })
            let tie = CupTie(round: 1, homeIndex: user, awayIndex: other)
            switch competition {
            case 0: store.cupTies = [tie]
            case 1: store.leagueCupTies = [tie]
            case 2: store.euroTies = [tie]
            case 3: store.uefaCupTies = [tie]
            case 4: store.communityShieldTie = tie
            default: store.uefaSuperCupTie = tie
            }
            let match = LiveMatch(store: store, knockoutTie: tie, date: store.currentDate,
                                  competitionName: "Audit cup", roundName: "Final")
            match.testScoreGoal(.home)
            match.testScoreGoal(.away)
            match.testFinishNow()
            let before = Dictionary(uniqueKeysWithValues: [user, other].flatMap { store.clubs[$0].players }.map { ($0.id, ($0.goals, $0.cupGoals)) })
            store.live = match
            store.finishLiveMatch()
            for club in [user, other] {
                for player in store.clubs[club].players {
                    let scored = (match.homeScorerIDs + match.awayScorerIDs).filter { $0 == player.id }.count
                    XCTAssertEqual(player.goals, before[player.id]?.0, "League goals changed in cup route \(competition)")
                    XCTAssertEqual(player.cupGoals, (before[player.id]?.1 ?? 0) + scored, "Cup route \(competition)")
                }
            }
        }
    }

    func testUefaSuperCupLiveFullTimeAppliesPlayerEffects() async {
        let store = await cupStore()
        let userIndex = store.userClubIndex
        let otherIndex = (0..<store.clubs.count).first { $0 != userIndex }!
        let tie = CupTie(round: 1, homeIndex: userIndex, awayIndex: otherIndex)
        store.uefaSuperCupTie = tie
        let match = LiveMatch(store: store, knockoutTie: tie, date: store.uefaSuperCupDate(),
                              competitionName: GameStore.uefaSuperCupName, roundName: "Final")
        match.skipToEnd()
        let appearedIDs = match.userAppearedIDs
        XCTAssertFalse(appearedIDs.isEmpty)
        let before = appsByID(store)

        store.live = match
        store.finishLiveMatch()
        XCTAssertNil(store.live)
        for id in appearedIDs {
            XCTAssertEqual(store.clubs[userIndex].players.first { $0.id == id }?.apps,
                           (before[id] ?? 0) + 1, "A live Super Cup appearance must be recorded once")
        }
    }

    func testLeagueLiveFullTimeAppliesMatchFitnessToParticipantsOnly() async {
        let store = await freshStore()
        for i in store.clubs[store.userClubIndex].players.indices {
            store.clubs[store.userClubIndex].players[i].fitness = 100
        }
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        match.skipToEnd()
        let appeared = Set(match.userAppearedIDs)

        store.live = match
        store.finishLiveMatch()
        for player in store.clubs[store.userClubIndex].players {
            if appeared.contains(player.id) {
                XCTAssertLessThan(player.fitness, 100, "\(player.name) played a live league match and must lose fitness like a quick-sim match")
            } else {
                XCTAssertEqual(player.fitness, 100, "\(player.name) did not play and must keep full fitness")
            }
        }
    }

    func testSubstitutesAreCreditedOnlyIfTheyTookThePitchAndRepeatTapsSpendNothing() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        guard let off = match.userOnPitch.first, let on = match.userBench.first else {
            return XCTFail("Expected an on-pitch starter and a bench player")
        }
        XCTAssertTrue(match.makeUserSub(off: off, on: on))
        XCTAssertFalse(match.makeUserSub(off: off, on: on), "A repeated tap must not reapply the same substitution")
        XCTAssertEqual(match.userSubsLeft, 4, "A repeated tap must spend exactly one allowance")
        let unused = match.userBench.map { $0.id }
        XCTAssertFalse(unused.isEmpty, "Some bench players should remain unused")
        let before = appsByID(store)

        match.skipToEnd()
        store.live = match
        store.finishLiveMatch()
        let clubPlayers = store.clubs[store.userClubIndex].players
        XCTAssertEqual(clubPlayers.first { $0.id == on.id }?.apps, (before[on.id] ?? 0) + 1, "The substitute who came on is credited once")
        XCTAssertEqual(clubPlayers.first { $0.id == off.player.id }?.apps, (before[off.player.id] ?? 0) + 1, "The starter who was substituted off keeps his appearance")
        for id in unused {
            XCTAssertEqual(clubPlayers.first { $0.id == id }?.apps, before[id], "An unused substitute must not be credited an appearance")
        }
    }

    func testRepeatedFullTimeDeliveryDoesNotDuplicateCareerTotals() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        match.skipToEnd()

        store.live = match
        store.finishLiveMatch()
        let appsAfterFirst = appsByID(store)
        let goalsAfterFirst = goalsByID(store)
        let newsAfterFirst = store.news.count

        store.finishLiveMatch()
        XCTAssertEqual(appsByID(store), appsAfterFirst, "A second full-time call must not add appearances")
        XCTAssertEqual(goalsByID(store), goalsAfterFirst, "A second full-time call must not add goals")
        XCTAssertEqual(store.news.count, newsAfterFirst, "A second full-time call must not post news again")
    }

    // MARK: - Stale completion (audit)

    /// Played-state and table numbers, so a replayed completion that
    /// re-applies a result is caught even when player stats don't move.
    private func tableSnapshot(_ store: GameStore) -> [Int] {
        store.clubs.flatMap { [$0.played, $0.won, $0.drawn, $0.goalsFor, $0.goalsAgainst] }
    }

    func testStaleLeagueLiveMatchCannotReapplyAFinishedFixture() async {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        match.skipToEnd()

        store.live = match
        store.finishLiveMatch()
        let fixtureIndex = store.fixtures.firstIndex { $0.id == match.fixtureID }
        XCTAssertEqual(fixtureIndex.map { store.fixtures[$0].played }, true)
        let appsAfterFirst = appsByID(store)
        let goalsAfterFirst = goalsByID(store)
        let tableAfterFirst = tableSnapshot(store)
        let matchdayAfterFirst = store.currentMatchday
        let newsAfterFirst = store.news.count

        // A stale LiveMatch for the same fixture is handed back to the store.
        store.live = match
        store.finishLiveMatch()
        XCTAssertEqual(store.currentMatchday, matchdayAfterFirst, "A stale league completion must not advance the matchday")
        XCTAssertEqual(appsByID(store), appsAfterFirst, "A stale league completion must not add appearances")
        XCTAssertEqual(goalsByID(store), goalsAfterFirst, "A stale league completion must not add goals")
        XCTAssertEqual(tableSnapshot(store), tableAfterFirst, "A stale league completion must not count the result twice")
        XCTAssertEqual(store.news.count, newsAfterFirst, "A stale league completion must not post news again")
    }

    func testStaleCupCompletionCannotReplayRoundOrEffectsOnAnyRoute() async throws {
        for competition in 0..<6 {
            let store = await cupStore()
            let user = store.userClubIndex
            let other = try XCTUnwrap(store.clubs.indices.first { $0 != user })
            let tie = CupTie(round: 1, homeIndex: user, awayIndex: other)
            switch competition {
            case 0: store.cupTies = [tie]
            case 1: store.leagueCupTies = [tie]
            case 2: store.euroTies = [tie]
            case 3: store.uefaCupTies = [tie]
            case 4: store.communityShieldTie = tie
            default: store.uefaSuperCupTie = tie
            }
            let match = LiveMatch(store: store, knockoutTie: tie, date: store.currentDate,
                                  competitionName: "Audit cup", roundName: "Final")
            match.testScoreGoal(match.userSide)
            match.testScoreGoal(match.userSide)
            match.testFinishNow()

            store.live = match
            store.finishLiveMatch()
            let appsAfterFirst = appsByID(store)
            let cupGoalsAfterFirst = Dictionary(uniqueKeysWithValues: store.userClub.players.map { ($0.id, $0.cupGoals) })
            let roundAfterFirst = store.cupRound
            let tiesAfterFirst = store.cupTies.map { [$0.homeGoals, $0.awayGoals, $0.winnerIndex, $0.round] }
            let newsAfterFirst = store.news.count

            store.live = match
            store.finishLiveMatch()
            XCTAssertEqual(appsByID(store), appsAfterFirst, "Route \(competition): a stale cup completion must not add appearances")
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: store.userClub.players.map { ($0.id, $0.cupGoals) }), cupGoalsAfterFirst,
                           "Route \(competition): a stale cup completion must not add cup goals")
            XCTAssertEqual(store.cupRound, roundAfterFirst, "Route \(competition): a stale completion must not advance the round again")
            XCTAssertEqual(store.cupTies.map { [$0.homeGoals, $0.awayGoals, $0.winnerIndex, $0.round] }, tiesAfterFirst,
                           "Route \(competition): a stale completion must not rewrite the bracket")
            XCTAssertEqual(store.news.count, newsAfterFirst, "Route \(competition): a stale completion must not post news again")
        }
    }
    /// Compare the entire persisted model, including all teams, brackets,
    /// prizes, ledger, ratings, fitness and disciplinary state.
    private func completionSnapshot(_ store: GameStore) throws -> Data {
        XCTAssertTrue(store.persist())
        let id = try XCTUnwrap(store.currentSaveID)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: SaveSlots.fileURL(for: id)))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    func testStaleCupCompletionAfterRoundReplacementIsANoOp() async throws {
        for competition in 0..<4 {
            let store = await cupStore()
            let user = store.userClubIndex
            let others = Array(store.clubs.indices.filter { $0 != user }.prefix(3))
            let tie = CupTie(round: 1, homeIndex: user, awayIndex: others[0])
            let otherTie = CupTie(round: 1, homeIndex: others[1], awayIndex: others[2])
            switch competition {
            case 0: store.cupRound = 1; store.cupTies = [tie, otherTie]
            case 1: store.leagueCupRound = 1; store.leagueCupTies = [tie, otherTie]
            case 2: store.euroRound = 1; store.euroTies = [tie, otherTie]
            default: store.uefaCupRound = 1; store.uefaCupTies = [tie, otherTie]
            }
            let match = LiveMatch(store: store, knockoutTie: tie, date: store.currentDate,
                                  competitionName: "Audit cup", roundName: "Semi-final")
            match.testScoreGoal(match.userSide)
            match.testFinishNow()
            store.live = match
            store.finishLiveMatch()
            let currentTies = [store.cupTies, store.leagueCupTies, store.euroTies, store.uefaCupTies][competition]
            XCTAssertFalse(currentTies.contains { $0.id == tie.id }, "Must exercise a replaced round")
            XCTAssertTrue(currentTies.contains { !$0.played }, "The next round must still be waiting")
            let before = try completionSnapshot(store)
            store.live = match
            store.finishLiveMatch()
            XCTAssertNil(store.live)
            XCTAssertEqual(try completionSnapshot(store), before, "Route \(competition): an obsolete tie must not affect any saved state")
        }
    }

    func testStaleLeagueCompletionAfterReloadIsANoOp() async throws {
        let store = await freshStore()
        let match = makeMatch(store, userLevel: 80, opponentLevel: 80)
        match.testFinishNow()
        store.live = match
        store.finishLiveMatch()
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertFalse(reloaded.fixtures.contains { $0.id == match.fixtureID }, "Reload regenerates transient fixture IDs")
        let before = try completionSnapshot(reloaded)
        reloaded.live = match
        reloaded.finishLiveMatch()
        XCTAssertNil(reloaded.live)
        XCTAssertEqual(try completionSnapshot(reloaded), before)
    }

    func testUnregisteredCupCompletionIsANoOp() async throws {
        let store = await cupStore()
        let other = try XCTUnwrap(store.clubs.indices.first { $0 != store.userClubIndex })
        let tie = CupTie(round: 1, homeIndex: store.userClubIndex, awayIndex: other)
        let match = LiveMatch(store: store, knockoutTie: tie, date: store.currentDate,
                              competitionName: "Obsolete cup", roundName: "Final")
        match.testFinishNow()
        let before = try completionSnapshot(store)
        store.live = match
        store.finishLiveMatch()
        XCTAssertNil(store.live)
        XCTAssertEqual(try completionSnapshot(store), before)
    }

    func testMismatchedAndFutureLeagueCompletionsAreNoOps() async throws {
        for future in [false, true] {
            let store = await freshStore()
            let fixture = try XCTUnwrap(store.fixtures.first {
                ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
                    && (future ? $0.matchday > store.currentMatchday : $0.matchday == store.currentMatchday)
            })
            let actualOpponent = fixture.homeIndex == store.userClubIndex ? fixture.awayIndex : fixture.homeIndex
            let wrongOpponent = try XCTUnwrap(store.clubs.indices.first { $0 != store.userClubIndex && $0 != actualOpponent })
            let match = future ? LiveMatch(store: store, fixture: fixture)
                : LiveMatch(store: store, homeIndex: store.userClubIndex, awayIndex: wrongOpponent,
                            date: store.currentDate, competition: "League", isCup: false,
                            tieID: nil, matchID: fixture.id)
            match.testFinishNow()
            let before = try completionSnapshot(store)
            store.live = match
            store.finishLiveMatch()
            XCTAssertNil(store.live)
            XCTAssertEqual(try completionSnapshot(store), before, future ? "Future fixture" : "Wrong opponent")
        }
    }

}
