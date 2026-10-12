//
//  CareerSeasonFlowTests.swift
//  Retro Season ManagerTests
//
//  Pins the season-end invariants the review screen and the next-season
//  handoff depend on, using the same real-engine path as the UI fixture:
//  a full season played through playNextMatchday() with the final matchday
//  committed through the live-match path (which is what fires
//  recordSeasonHonours() and the job-offer pipeline), then exactly one
//  startNextSeason() rollover.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerSeasonFlowTests: XCTestCase {

    /// The season-end fixture must leave a coherent review state: season
    /// over, a crowned champion, a complete final table, awards data and
    /// end-of-season job offers — all from the real pipeline.
    func testSeasonEndFixtureProducesCoherentReviewState() async {
        let store = await makeTestStore()
        store.prepareCareerSeasonEndFixtureForDebug()

        XCTAssertTrue(store.isSeasonOver, "The fixture must park at season's end")
        XCTAssertFalse(store.careerEnded)
        XCTAssertFalse(store.wasSacked, "The fixture manager must survive the review")
        XCTAssertEqual(store.clubs[store.userClubIndex].played, store.totalMatchdays,
                       "The user's club must have played the full season")

        let table = store.userTable()
        XCTAssertEqual(table.count, 20, "The final table must be complete")
        if let champion = store.champion {
            XCTAssertEqual(champion.id, table.first?.id,
                           "The champion must be the top of the authoritative final table")
            XCTAssertEqual(champion.id, store.userTable().first?.id)
        } else {
            XCTFail("A completed season must have a champion")
        }

        XCTAssertNotNil(store.goldenBoot(), "The awards card needs a Golden Boot")
        XCTAssertNotNil(store.playerOfSeason(), "The awards card needs a Player of the Season")
        XCTAssertNotNil(store.userTopScorer(), "The awards card needs a Top Scorer")
        XCTAssertFalse(store.pendingJobOffers.isEmpty,
                       "The review must advertise end-of-season job offers")
        XCTAssertTrue(store.fixtures.allSatisfy { $0.played },
                      "Every league fixture must be played at season's end")
    }

    /// Starting the next season must advance exactly once through the
    /// existing single-fire path: new matchday 1, clean records, fresh
    /// objectives and budgets, honours banked, and no second increment.
    func testStartNextSeasonAdvancesExactlyOnce() async {
        let store = await makeTestStore()
        store.prepareCareerSeasonEndFixtureForDebug()

        let seasonBefore = store.season
        let matchdayBefore = store.currentMatchday
        let honoursBefore = store.careerHonours.count
        XCTAssertTrue(store.isSeasonOver)

        store.startNextSeason()

        XCTAssertEqual(store.season, seasonBefore + 1, "Season must advance exactly once")
        XCTAssertFalse(store.isSeasonOver, "A fresh season must not already be over")
        XCTAssertEqual(store.currentMatchday, 1, "A fresh season restarts at matchday 1")
        XCTAssertEqual(matchdayBefore, store.totalMatchdays + 1,
                       "The rollover must start from the finished season (the live finish " +
                       "leaves the counter just past the final matchday, which is what " +
                       "isSeasonOver reads)")
        XCTAssertTrue(store.clubs.allSatisfy { $0.played == 0 },
                      "Every club's record must reset for the new season")
        XCTAssertEqual(store.seasonObjectives.count, 4, "A fresh set of season objectives is rolled")
        XCTAssertTrue(store.completedSeasonObjectiveIDs.isEmpty,
                      "Completed objective IDs reset for the new season")
        XCTAssertGreaterThanOrEqual(store.careerHonours.count, honoursBefore,
                                    "Banked honours must never be lost by the rollover")
        XCTAssertGreaterThan(store.userClub.transferBudget, 0,
                             "The new season must open with a fresh transfer budget")
        XCTAssertTrue(store.pendingJobOffers.isEmpty,
                      "The rollover clears any unaccepted offers with the new campaign")
        XCTAssertFalse(store.careerEnded, "One rollover must not end the career")
    }

    /// Replays the real season-end transition twice. Only the completed
    /// season may age the roster; the second queued request after rollover
    /// must be rejected before it ages or advances anyone again.
    func testRepeatedSeasonRolloverDoesNotAgeOrAdvanceTwice() async throws {
        let store = await makeTestStore()
        store.prepareCareerSeasonEndFixtureForDebug()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let userClubID = store.userClub.id

        let player = try XCTUnwrap(store.userClub.players.first)
        let playerIndex = try XCTUnwrap(store.userClub.players.firstIndex { $0.id == player.id })
        store.clubs[store.userClubIndex].players[playerIndex].age = 20
        let startingSeason = store.season

        store.startNextSeason()

        XCTAssertEqual(store.season, startingSeason + 1)
        XCTAssertEqual(store.currentPlayer(player.id)?.age, 21)
        let committedPlayers = store.userClub.players

        let relaunched = await makeTestStore()
        XCTAssertTrue(relaunched.loadSavedGame(id: saveID))
        XCTAssertEqual(relaunched.season, startingSeason + 1)
        XCTAssertEqual(relaunched.currentPlayer(player.id)?.age, 21,
                       "The committed age must survive a real save/reload")
        XCTAssertEqual(relaunched.userClub.id, userClubID)
        XCTAssertEqual(relaunched.clubs.first(where: { $0.id == userClubID })?.players.map(\.id),
                       committedPlayers.map(\.id),
                       "Save/reload must preserve the authoritative developed roster")

        // The first transition has reset the completed-season flag. Calling
        // the store API again must be a no-op rather than another season roll.
        store.startNextSeason()
        XCTAssertEqual(store.season, startingSeason + 1,
                       "A second request without a completed season must not advance")
        XCTAssertEqual(store.currentPlayer(player.id)?.age, 21,
                       "The same career season must not age a player twice")
    }

    /// Age 37 always retires at the next rollover (the code retires every
    /// player at 38), independent of the early-retirement probability band.
    /// The removed player must no longer be selected, hold a squad role, or
    /// reappear in the next transfer market or after loading the save.
    func testMandatoryRetirementRemovesPlayerAndReferencesOnRollover() async throws {
        let store = await makeTestStore()
        store.prepareCareerSeasonEndFixtureForDebug()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let userClubID = store.userClub.id

        let retiree = try XCTUnwrap(store.userClub.players.first)
        let index = try XCTUnwrap(store.userClub.players.firstIndex { $0.id == retiree.id })
        store.clubs[store.userClubIndex].players[index].age = 37
        store.userStarterIDs.insert(retiree.id)
        store.captainID = retiree.id
        store.penaltyTakerID = retiree.id
        store.freeKickTakerID = retiree.id
        store.cornerTakerID = retiree.id

        store.startNextSeason()

        XCTAssertFalse(store.clubs.contains { $0.players.contains { $0.id == retiree.id } },
                       "A player reaching age 38 is removed from all active squads")
        XCTAssertNotEqual(store.captainID, retiree.id)
        XCTAssertNotEqual(store.penaltyTakerID, retiree.id)
        XCTAssertNotEqual(store.freeKickTakerID, retiree.id)
        XCTAssertNotEqual(store.cornerTakerID, retiree.id)
        XCTAssertFalse(store.transferMarket.contains { $0.player.id == retiree.id },
                       "Retirees must not be regenerated as available transfer targets")

        let relaunched = await makeTestStore()
        XCTAssertTrue(relaunched.loadSavedGame(id: saveID))
        XCTAssertFalse(relaunched.clubs.contains { $0.players.contains { $0.id == retiree.id } },
                       "A retired player must stay out of the roster after a real reload")
        XCTAssertNil(relaunched.currentPlayer(retiree.id))
        XCTAssertNotNil(relaunched.clubs.first(where: { $0.id == userClubID }),
                        "Reload must preserve the club's identity even if league realignment moved it")
        XCTAssertFalse(relaunched.userStarterIDs.contains(retiree.id))
        XCTAssertFalse(relaunched.transferMarket.contains { $0.player.id == retiree.id })
    }

    /// The standings card's data source must stay the authoritative league
    /// table: strictly ordered by points, with goal difference as the
    /// tie-break, so position-keyed rows always mean what they say.
    func testFinalTableIsStrictlyOrdered() async {
        let store = await makeTestStore()
        store.prepareCareerSeasonEndFixtureForDebug()

        let table = store.userTable()
        for index in 1..<table.count {
            let above = table[index - 1]
            let current = table[index]
            let aboveRecord = (above.points, above.goalsFor - above.goalsAgainst)
            let currentRecord = (current.points, current.goalsFor - current.goalsAgainst)
            XCTAssertTrue(aboveRecord >= currentRecord,
                          "Row \(index) (\(current.name)) must not outrank row \(index - 1) (\(above.name))")
            XCTAssertNotEqual(above.id, current.id, "Every final-table row must be a distinct club")
        }
    }
}
