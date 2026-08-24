//
//  SeasonObjectiveTests.swift
//  Retro Season ManagerTests
//
//  Guards SeasonObjectiveKind's condition evaluation and
//  GameStore+SeasonObjectives' idempotent completion/reward/reset logic.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class SeasonObjectiveTests: XCTestCase {

    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Objective Test")
        return store
    }

    private func setSingleObjective(_ store: GameStore, kind: SeasonObjectiveKind, id: String = "test-objective") {
        store.seasonObjectives = [SeasonObjective(id: id, title: "Test", description: "Test objective", kind: kind)]
        store.completedSeasonObjectiveIDs = []
    }

    func testSetSeasonObjectivesRollsFourUniqueObjectives() async {
        let store = await freshStore()
        XCTAssertEqual(store.seasonObjectives.count, 4)
        XCTAssertEqual(Set(store.seasonObjectives.map(\.id)).count, 4, "Objectives should be distinct")
    }

    func testBeatRivalCompletesOnlyWhenFlagSet() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .beatRival)
        store.rivalWinThisSeason = false
        XCTAssertFalse(store.checkSeasonObjectives())
        store.rivalWinThisSeason = true
        XCTAssertTrue(store.checkSeasonObjectives())
        XCTAssertTrue(store.completedSeasonObjectiveIDs.contains("test-objective"))
    }

    func testAcademyBreakthroughRequiresMinApps() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .academyBreakthrough(minApps: 5))
        guard let playerID = store.userClub.players.first?.id else { return XCTFail("No players") }
        store.youthPromotedThisSeasonIDs = [playerID]
        guard let index = store.clubs[store.userClubIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return XCTFail("Player vanished")
        }
        store.clubs[store.userClubIndex].players[index].apps = 4
        XCTAssertFalse(store.checkSeasonObjectives())
        store.clubs[store.userClubIndex].players[index].apps = 5
        XCTAssertTrue(store.checkSeasonObjectives())
    }

    func testCleanSheetWallSumsPlayerCleanSheets() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .cleanSheetWall(3))
        store.clubs[store.userClubIndex].players[0].cleanSheets = 2
        store.clubs[store.userClubIndex].players[1].cleanSheets = 0
        XCTAssertFalse(store.checkSeasonObjectives())
        store.clubs[store.userClubIndex].players[1].cleanSheets = 1
        XCTAssertTrue(store.checkSeasonObjectives())
    }

    func testFinishAboveClubComparesDivisionTierWhenDifferentAndOnlyEvaluatesAtSeasonEnd() async {
        let store = await freshStore()
        guard let rivalIndex = store.rivalClubIndex else { return XCTFail("No rival resolved") }
        let rivalName = store.clubs[rivalIndex].name
        setSingleObjective(store, kind: .finishAboveClub(clubName: rivalName))
        store.clubs[store.userClubIndex].divisionTier = 0
        store.clubs[rivalIndex].divisionTier = 1
        XCTAssertFalse(store.checkSeasonObjectives(isSeasonEnd: false), "finishAboveClub should never complete mid-season")
        XCTAssertTrue(store.checkSeasonObjectives(isSeasonEnd: true), "A higher division than the rival should count as finishing above")
    }

    func testCupQuarterFinalCompletesOnFlag() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .cupQuarterFinal)
        XCTAssertFalse(store.checkSeasonObjectives())
        store.reachedCupQuarterFinalThisSeason = true
        XCTAssertTrue(store.checkSeasonObjectives())
    }

    func testWageDisciplineComparesWageBillToBudget() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .wageDiscipline)
        let bill = store.userClub.wageBill
        store.clubs[store.userClubIndex].wageBudget = Int(Double(bill) / 0.95) // bill is just over 90% of budget
        XCTAssertFalse(store.checkSeasonObjectives())
        store.clubs[store.userClubIndex].wageBudget = bill * 3 // comfortably under 90%
        XCTAssertTrue(store.checkSeasonObjectives())
    }

    func testSignYoungPlayerCompletesOnFlag() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .signYoungPlayer(maxAge: 21))
        XCTAssertFalse(store.checkSeasonObjectives())
        store.signedYoungPlayerThisSeason = true
        XCTAssertTrue(store.checkSeasonObjectives())
    }

    func testProtectFanFavouriteOnlyEvaluatesAtSeasonEndAndFailsIfSold() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .protectFanFavourite)
        store.soldFanFavouriteThisSeason = true
        XCTAssertFalse(store.checkSeasonObjectives(isSeasonEnd: false))
        XCTAssertFalse(store.checkSeasonObjectives(isSeasonEnd: true))
        store.soldFanFavouriteThisSeason = false
        XCTAssertTrue(store.checkSeasonObjectives(isSeasonEnd: true))
    }

    func testImproveFanConfidenceOnlyEvaluatesAtSeasonEnd() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .improveFanConfidence)
        store.fanConfidenceAtSeasonStart = 60
        store.fanConfidence = 60
        XCTAssertFalse(store.checkSeasonObjectives(isSeasonEnd: true), "Equal confidence shouldn't count as improved")
        store.fanConfidence = 65
        XCTAssertFalse(store.checkSeasonObjectives(isSeasonEnd: false), "Mid-season check shouldn't complete this kind")
        XCTAssertTrue(store.checkSeasonObjectives(isSeasonEnd: true))
    }

    func testHomeUnbeatenRunCompletesAtThreshold() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .homeUnbeatenRun(3))
        store.homeUnbeatenStreak = 2
        XCTAssertFalse(store.checkSeasonObjectives())
        store.homeUnbeatenStreak = 3
        XCTAssertTrue(store.checkSeasonObjectives())
    }

    func testCompletionIsIdempotentAndGrantsRewardsOnlyOnce() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .beatRival)
        store.rivalWinThisSeason = true
        let reputationBefore = store.managerReputation
        let fanConfidenceBefore = store.fanConfidence
        let pointsBefore = store.careerAchievementPoints
        XCTAssertTrue(store.checkSeasonObjectives())
        XCTAssertEqual(store.managerReputation, min(100, reputationBefore + 2))
        XCTAssertEqual(store.fanConfidence, min(100, fanConfidenceBefore + 3))
        XCTAssertEqual(store.careerAchievementPoints, pointsBefore + 1)
        // A second sweep shouldn't re-grant anything.
        XCTAssertFalse(store.checkSeasonObjectives())
        XCTAssertEqual(store.careerAchievementPoints, pointsBefore + 1)
    }

    func testSetSeasonObjectivesResetsCompletionAndTrackingFlags() async {
        let store = await freshStore()
        setSingleObjective(store, kind: .beatRival)
        store.rivalWinThisSeason = true
        XCTAssertTrue(store.checkSeasonObjectives())
        XCTAssertFalse(store.completedSeasonObjectiveIDs.isEmpty)

        store.setSeasonObjectives()
        XCTAssertEqual(store.seasonObjectives.count, 4)
        XCTAssertTrue(store.completedSeasonObjectiveIDs.isEmpty)
        XCTAssertFalse(store.rivalWinThisSeason)
        XCTAssertTrue(store.youthPromotedThisSeasonIDs.isEmpty)
        XCTAssertFalse(store.reachedCupQuarterFinalThisSeason)
        XCTAssertFalse(store.soldFanFavouriteThisSeason)
        XCTAssertFalse(store.signedYoungPlayerThisSeason)
        XCTAssertEqual(store.fanConfidenceAtSeasonStart, store.fanConfidence)
    }
}
