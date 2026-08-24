//
//  LegendsMatchTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 7 match engine's math and LegendsStore+Match's
//  reward/promotion bookkeeping.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsMatchEngineTests: XCTestCase {
    func testGoalsAreNeverNegative() {
        for _ in 0..<200 {
            let result = LegendsMatchEngine.simulate(teamRating: 70, opponentRating: 70, chemistryBonus: 0)
            XCTAssertGreaterThanOrEqual(result.teamGoals, 0)
            XCTAssertGreaterThanOrEqual(result.opponentGoals, 0)
        }
    }

    func testOutcomeMatchesTheScoreline() {
        XCTAssertEqual(LegendsMatchEngine.Result(teamGoals: 2, opponentGoals: 1).outcome, .win)
        XCTAssertEqual(LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 1).outcome, .draw)
        XCTAssertEqual(LegendsMatchEngine.Result(teamGoals: 0, opponentGoals: 2).outcome, .loss)
    }

    func testAStrongerTeamWinsMoreOftenOverManyMatches() {
        var strongWins = 0
        let trials = 300
        for _ in 0..<trials {
            let result = LegendsMatchEngine.simulate(teamRating: 90, opponentRating: 40, chemistryBonus: 0)
            if result.outcome == .win { strongWins += 1 }
        }
        // Not a tight bound — this only guards against the ratio math
        // being inverted or the strength gap having no effect at all.
        XCTAssertGreaterThan(strongWins, trials / 2)
    }
}

@MainActor
final class LegendsStoreMatchTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        store.profile.coins = 0
        store.profile.packTokens = 0
        store.profile.managerLevel = 1
        store.profile.managerXP = 0
        store.profile.division = .division10
        store.profile.divisionWins = 0
        // LegendsStore() loads whatever's actually on disk (e.g. from a
        // manual Simulator run) — season state isn't reset by any of the
        // fields above, so a real playthrough's currentSeason/
        // matchesPlayedThisSeason otherwise leaks into season-advance tests.
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = 0
        store.profile.cardAgeOffsets = [:]
        store.profile.divisionTable = []
        store.profile.divisionSchedule = []
        store.profile.divisionSeason = 1
        store.profile.lastDivisionSeasonResult = nil
        store.profile.activatedCardIDs = []
        store.profile.completedPermanentChallengeIDs = []
        store.profile.completedDailyChallengeIDs = []
        store.profile.completedWeeklyChallengeIDs = Set(LegendsChallengeDatabase.all.filter { $0.cadence == .weekly }.map(\.id))
        store.profile.completedDailyChallengeIDs = Set(LegendsChallengeDatabase.all.filter { $0.cadence == .daily }.map(\.id))
        store.profile.completedPermanentChallengeIDs = Set(LegendsChallengeDatabase.all.filter { $0.cadence == .permanent }.map(\.id))
        return store
    }

    /// Fills the Starting XI with the highest-overall owned cards
    /// (icons/legends), giving a near-certain win against a Division 10
    /// opponent so promotion tests converge reliably without needing a
    /// seeded RNG.
    private func fillStrongXI(_ store: LegendsStore) {
        let slots = store.startingXISlots
        // Only one card per real-ish player is allowed in the squad at
        // once (LegendsStore+Squad.swift's name-based dedup) — several of
        // the highest-overall cards are different seasons of the same
        // player (e.g. two "E. Nascimento" cards), so sort first and then
        // take the first card per distinct name, not just the top N ids.
        var seenNames = Set<String>()
        let sorted = LegendsCardDatabase.all
            .sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) }
            .filter { seenNames.insert($0.name).inserted }
        for (index, _) in slots.enumerated() {
            store.assign(cardID: sorted[index].id, toXISlot: index)
        }
    }

    func testDivisionScheduleIsACompleteHomeAndAwayRoundRobin() async {
        let store = await freshStore()
        store.ensureDivisionSchedule()
        XCTAssertEqual(store.profile.divisionSchedule.count, 56)
        XCTAssertEqual(Set(store.profile.divisionSchedule.map(\.round)).count, 14)
        XCTAssertEqual(store.divisionMatchCount, 14)

        var pairings = Set<String>()
        for fixture in store.profile.divisionSchedule {
            XCTAssertNotEqual(fixture.homeTeamID, fixture.awayTeamID)
            pairings.insert("\(fixture.homeTeamID)|\(fixture.awayTeamID)")
        }
        XCTAssertEqual(pairings.count, 56)
        for home in store.profile.divisionTable.map(\.id) {
            for away in store.profile.divisionTable.map(\.id) where home != away {
                XCTAssertTrue(pairings.contains("\(home)|\(away)"))
            }
        }
    }

    func testScheduledOpponentIsTheNextUnplayedHomeOrAwayFixture() async {
        let store = await freshStore()
        store.ensureDivisionSchedule()
        guard let fixture = store.nextDivisionFixture else { return XCTFail("Expected a next fixture") }
        let opponent = store.scheduledOpponent()
        XCTAssertEqual(opponent.fixtureID, fixture.id)
        XCTAssertTrue(opponent.name == fixture.homeTeamID || opponent.name == fixture.awayTeamID)
        XCTAssertNotEqual(opponent.name, store.profile.clubName)
    }

    func testScheduledMatchClosesItsRoundAndUpdatesTheTableOnce() async {
        let store = await freshStore()
        store.ensureDivisionSchedule()
        guard let fixture = store.nextDivisionFixture else { return XCTFail("Expected a next fixture") }
        let opponent = store.scheduledOpponent()
        let before = store.divisionStandings().reduce(0) { $0 + $1.played }
        _ = store.applyMatchOutcome(opponent: opponent, result: LegendsMatchEngine.Result(teamGoals: 2, opponentGoals: 1))
        let after = store.divisionStandings().reduce(0) { $0 + $1.played }
        XCTAssertEqual(after - before, 8, "One completed round should record all four fixtures")
        XCTAssertTrue(store.profile.divisionSchedule.filter { $0.round == fixture.round }.allSatisfy(\.isPlayed))
        XCTAssertEqual(store.divisionMatchesPlayed, 1)
        XCTAssertEqual(store.profile.divisionSchedule.filter { $0.homeTeamID == store.profile.clubName || $0.awayTeamID == store.profile.clubName }.filter(\.isPlayed).count, 1)
    }

    func testCompletingAllScheduledFixturesSettlesSeasonAndStartsTheNextOne() async {
        let store = await freshStore()
        store.ensureDivisionSchedule()
        let initialSeason = store.profile.divisionSeason
        var completedSeason: LegendsMatchOutcomeSummary?

        for _ in 0..<store.divisionMatchCount {
            let opponent = store.scheduledOpponent()
            guard opponent.fixtureID != nil else {
                return XCTFail("Expected every scheduled match to have an opponent")
            }
            let summary = store.applyMatchOutcome(opponent: opponent,
                                                  result: LegendsMatchEngine.Result(teamGoals: 4, opponentGoals: 0))
            if summary.divisionSeasonResult != nil {
                completedSeason = summary
            }
        }

        XCTAssertNotNil(completedSeason?.divisionSeasonResult)
        XCTAssertEqual(store.profile.divisionSeason, initialSeason + 1)
        XCTAssertEqual(store.divisionMatchesPlayed, 0)
        XCTAssertEqual(store.divisionFixturesRemaining, store.divisionMatchCount)
        let reward = completedSeason!.divisionSeasonResult!.reward
        XCTAssertGreaterThanOrEqual(reward.coins, 50)
        XCTAssertEqual(store.profile.lastDivisionSeasonResult?.season, initialSeason)
    }

    func testSeasonOutcomePromotesAndRelegatesAtTheCorrectRanks() {
        XCTAssertEqual(LegendsStore.seasonOutcome(finalRank: 1, totalTeams: 8, division: .division5).outcome, .champion)
        XCTAssertEqual(LegendsStore.seasonOutcome(finalRank: 2, totalTeams: 8, division: .division5).outcome, .promoted)
        XCTAssertEqual(LegendsStore.seasonOutcome(finalRank: 7, totalTeams: 8, division: .division5).outcome, .relegated)
        XCTAssertEqual(LegendsStore.seasonOutcome(finalRank: 8, totalTeams: 8, division: .division10).outcome, .retained)
    }

    func testSeasonRewardValuesReflectTheFinalOutcome() {
        XCTAssertEqual(LegendsStore.seasonReward(for: .champion), LegendsSeasonReward(coins: 300, tokens: 3, managerXP: 100))
        XCTAssertEqual(LegendsStore.seasonReward(for: .promoted), LegendsSeasonReward(coins: 220, tokens: 2, managerXP: 80))
        XCTAssertEqual(LegendsStore.seasonReward(for: .retained), LegendsSeasonReward(coins: 100, tokens: 1, managerXP: 40))
        XCTAssertEqual(LegendsStore.seasonReward(for: .relegated), LegendsSeasonReward(coins: 50, tokens: 0, managerXP: 20))
    }

    func testDivisionBoundariesPreventPromotionPastWorldLeagueAndRelegationPastDivisionTen() async {
        let store = await freshStore()
        store.profile.division = .worldLeague
        XCTAssertEqual(LegendsStore.nextDivision(after: .worldLeague), .worldLeague)
        store.profile.division = .division10
        XCTAssertEqual(LegendsStore.previousDivision(after: .division10), .division10)
    }

    func testDivisionTableRecordsTheUserMatch() async {
        let store = await freshStore()
        let before = store.divisionStandings().first { $0.id == store.profile.clubName }!
        store.recordDivisionMatch(teamGoals: 3, opponentGoals: 1, opponentName: "Northstar Athletic")
        let standings = store.divisionStandings()
        let user = standings.first { $0.id == store.profile.clubName }!
        XCTAssertEqual(user.played, before.played + 1)
        XCTAssertEqual(user.won, before.won + 1)
        XCTAssertEqual(user.points, before.points + 3)
        XCTAssertEqual(user.goalDifference, before.goalDifference + 2)
    }

    func testOpponentComesFromTheDivisionTable() async {
        let store = await freshStore()
        store.ensureDivisionTable()
        let opponent = store.generateOpponent()
        XCTAssertTrue(store.divisionStandings().contains { $0.name == opponent.name })
        XCTAssertNotEqual(opponent.name, store.profile.clubName)
    }

    func testPlayMatchReturnsNilWithoutACompleteSquad() async {
        let store = await freshStore()
        XCTAssertNil(store.playMatch())
    }

    func testPlayMatchGrantsRewardsMatchingItsOwnOutcome() async {
        let store = await freshStore()
        fillStrongXI(store)
        guard let summary = store.playMatch() else { return XCTFail("Expected a match result with a full XI") }

        let (expectedCoins, expectedTokens, expectedXP): (Int, Int, Int)
        switch summary.result.outcome {
        case .win: (expectedCoins, expectedTokens, expectedXP) = (50, 1, 30)
        case .draw: (expectedCoins, expectedTokens, expectedXP) = (20, 0, 10)
        case .loss: (expectedCoins, expectedTokens, expectedXP) = (10, 0, 5)
        }
        XCTAssertEqual(summary.coinsEarned, expectedCoins)
        XCTAssertEqual(summary.tokensEarned, expectedTokens)
        XCTAssertEqual(summary.xpEarned, expectedXP)
        XCTAssertEqual(store.profile.coins, expectedCoins)
        XCTAssertEqual(store.profile.packTokens, expectedTokens)
    }

    func testManagerLevelsUpWhenXPCrossesTheThreshold() async {
        let store = await freshStore()
        fillStrongXI(store)
        store.profile.managerXP = 95  // threshold at level 1 is 100
        let summary = store.playMatch()
        guard let summary else { return XCTFail("Expected a match result") }
        if summary.xpEarned >= 5 {
            XCTAssertTrue(summary.leveledUp)
            XCTAssertEqual(store.profile.managerLevel, 2)
            XCTAssertLessThan(store.profile.managerXP, 100)
        }
    }

    func testEnoughWinsPromoteTheDivision() async {
        let store = await freshStore()
        fillStrongXI(store)
        let startingDivision = store.profile.division
        var promoted = false
        for _ in 0..<40 {
            guard let summary = store.playMatch() else { break }
            if summary.promoted { promoted = true; break }
        }
        XCTAssertTrue(promoted, "A strongly favoured team should be promoted well within 40 attempts")
        XCTAssertNotEqual(store.profile.division, startingDivision)
        XCTAssertLessThan(store.profile.division.rawValue, startingDivision.rawValue)
    }

    func testOpponentRatingScalesWithDivision() async {
        let store = await freshStore()
        store.profile.division = .worldLeague
        let worldLeagueRatings = (0..<20).map { _ in store.generateOpponent().rating }
        store.profile.division = .division10
        let division10Ratings = (0..<20).map { _ in store.generateOpponent().rating }

        let avgWorld = Double(worldLeagueRatings.reduce(0, +)) / Double(worldLeagueRatings.count)
        let avgDiv10 = Double(division10Ratings.reduce(0, +)) / Double(division10Ratings.count)
        XCTAssertGreaterThan(avgWorld, avgDiv10)
    }

    // MARK: - applyMatchOutcome (the seam a live match's finish calls into)

    func testApplyMatchOutcomeGrantsTheSameRewardsAsPlayMatchForAnEquivalentResult() async {
        let store = await freshStore()
        let opponent = LegendsOpponent(name: "Rival XI", rating: 50)
        let win = LegendsMatchEngine.Result(teamGoals: 2, opponentGoals: 0)
        let summary = store.applyMatchOutcome(opponent: opponent, result: win)

        XCTAssertEqual(summary.coinsEarned, 50)
        XCTAssertEqual(summary.tokensEarned, 1)
        XCTAssertEqual(summary.xpEarned, 30)
        XCTAssertEqual(store.profile.coins, 50)
        XCTAssertEqual(store.profile.packTokens, 1)
        XCTAssertEqual(store.profile.divisionWins, 1)
    }

    func testApplyMatchOutcomeAdvancesSeasonExactlyOnceRegardlessOfCaller() async {
        let store = await freshStore()
        let opponent = LegendsOpponent(name: "Rival XI", rating: 50)
        let draw = LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 1)
        for _ in 0..<LegendsStore.matchesPerSeason {
            _ = store.applyMatchOutcome(opponent: opponent, result: draw)
        }
        XCTAssertEqual(store.profile.currentSeason, 2, "Exactly one season advance per matchesPerSeason calls, not per tick")
    }
}
