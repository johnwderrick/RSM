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
        return store
    }

    /// Fills the Starting XI with the highest-overall owned cards
    /// (icons/legends), giving a near-certain win against a Division 10
    /// opponent so promotion tests converge reliably without needing a
    /// seeded RNG.
    private func fillStrongXI(_ store: LegendsStore) {
        let slots = store.startingXISlots
        let sorted = LegendsCardDatabase.all.sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) }
        for (index, _) in slots.enumerated() {
            store.assign(cardID: sorted[index].id, toXISlot: index)
        }
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
}
