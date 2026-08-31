//
//  FanEngagementTests.swift
//  Retro Season ManagerTests
//
//  Guards item 9 of the improvement directive: fan polls, fan campaigns,
//  the youth-debut moment, identity-aware transfer reactions, and
//  attendance-trend accumulation.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class FanEngagementTests: XCTestCase {

    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Fan Engagement Test")
        return store
    }

    // MARK: - Fan polls

    func testFanPollEventuallyNamesThePlayerOfTheSeason() async {
        let store = await freshStore()
        guard let index = store.clubs[store.userClubIndex].players.indices.first else {
            return XCTFail("Expected a squad")
        }
        // The only candidate that can clear the `apps >= 5` gate.
        store.clubs[store.userClubIndex].players[index].apps = 10
        store.clubs[store.userClubIndex].players[index].ratingPoints = 90
        let standoutName = store.clubs[store.userClubIndex].players[index].name

        for _ in 0..<60 { store.checkFanPoll() }
        XCTAssertTrue(store.news.contains { $0.title == "Fan poll" && $0.body.contains(standoutName) })
    }

    func testFanPollEventuallyNamesTheRival() async {
        let store = await freshStore()
        guard let rivalIndex = store.rivalClubIndex else {
            return XCTFail("Expected a resolvable rival — rivalClubIndex always falls back to one")
        }
        let rivalName = store.clubs[rivalIndex].name

        for _ in 0..<60 { store.checkFanPoll() }
        XCTAssertTrue(store.news.contains { $0.title == "Fan poll" && $0.body.contains(rivalName) })
    }

    // MARK: - Fan campaigns

    func testFanCampaignOnlyFiresBelowThePatienceThresholdAndOnlyOnceASeason() async {
        let store = await freshStore()
        store.fanPatience = 50
        store.checkFanCampaign()
        XCTAssertFalse(store.news.contains { $0.title == "Fan campaign" }, "Patience isn't low enough yet")

        store.fanPatience = 20
        store.checkFanCampaign()
        XCTAssertTrue(store.news.contains { $0.title == "Fan campaign" })
        let countAfterFirst = store.news.filter { $0.title == "Fan campaign" }.count

        store.checkFanCampaign()
        XCTAssertEqual(store.news.filter { $0.title == "Fan campaign" }.count, countAfterFirst,
                       "Shouldn't fire a second time in the same season")
    }

    // MARK: - Youth blooding

    func testYouthBloodingFiresOnceForAnAcademyPlayersFirstStart() async {
        let store = await freshStore()
        guard let index = store.clubs[store.userClubIndex].players.firstIndex(where: { $0.position == .midfielder }) else {
            return XCTFail("Expected a midfielder in the starting squad")
        }
        store.clubs[store.userClubIndex].players[index].isAcademyProduct = true
        store.clubs[store.userClubIndex].players[index].age = 18
        let playerID = store.clubs[store.userClubIndex].players[index].id
        store.autoPickLineup()
        if !store.userStarterIDs.contains(playerID) {
            guard let selectedMidfielderID = store.userClub.players.first(where: {
                $0.position == .midfielder && store.userStarterIDs.contains($0.id)
            })?.id else {
                return XCTFail("Expected an auto-picked midfielder to replace")
            }
            store.userStarterIDs.remove(selectedMidfielderID)
            store.userStarterIDs.insert(playerID)
        }
        XCTAssertTrue(store.userStartingXI().contains { $0.id == playerID },
                      "The fixture must put the academy player in a valid starting XI")

        store.checkYouthBlooding()

        XCTAssertTrue(store.bloodedYouthIDs.contains(playerID))
        XCTAssertTrue(store.news.contains { $0.title == "Academy debut" })
        let countAfterFirst = store.news.filter { $0.title == "Academy debut" }.count

        store.checkYouthBlooding()
        XCTAssertEqual(store.news.filter { $0.title == "Academy debut" }.count, countAfterFirst,
                       "Shouldn't fire a second time for the same player")
    }

    // MARK: - Identity-aware transfer reactions

    func testFinancialPowerhouseToleratesABiggerOverpayThanCrisisClub() async {
        let store = await freshStore()
        guard let player = store.clubs[store.userClubIndex].players.first(where: { $0.value > 0 }) else {
            return XCTFail("Expected a valued player")
        }
        let fee = Int(Double(player.value) * 1.45) // above the default/crisis thresholds, below the powerhouse one

        store.clubIdentities[store.userClubIndex] = .financialPowerhouse
        store.fanConfidence = 60
        store.reactToUserSigning(player, fee: fee)
        XCTAssertEqual(store.fanConfidence, 60, "Financial Powerhouse fans shouldn't blink at this fee")

        store.clubIdentities[store.userClubIndex] = .crisisClub
        store.fanConfidence = 60
        store.reactToUserSigning(player, fee: fee)
        XCTAssertLessThan(store.fanConfidence, 60, "Crisis Club fans should react to the very same fee")
    }

    // MARK: - Attendance trend

    func testAttendanceAveragesAndResetsAtSeasonRollover() async {
        let store = await freshStore()
        XCTAssertTrue(store.attendanceHistory.isEmpty)

        store.seasonAttendanceTotal = 30_000
        store.seasonHomeMatchesPlayed = 3
        store.setSeasonObjectives() // the exact function that banks + resets these each season rollover

        XCTAssertEqual(store.attendanceHistory, [10_000])
        XCTAssertEqual(store.seasonAttendanceTotal, 0)
        XCTAssertEqual(store.seasonHomeMatchesPlayed, 0)
    }
}
