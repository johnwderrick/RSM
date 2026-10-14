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

    private func offer(forClubIndex index: Int, in store: GameStore) -> JobOffer {
        JobOffer(clubIndex: index, clubName: store.clubs[index].name,
                 divisionName: store.divisionName(store.clubs[index].divisionTier),
                 prestige: store.clubs[index].prestige,
                 transferBudget: store.clubs[index].transferBudget,
                 expectedObjective: store.previewObjective(forClubIndex: index))
    }

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

    func testFourthDivisionMidTableObjectiveEndsAtMidTableBoundary() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Board Boundary Audit")
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }

        let fourthDivision = store.clubs.indices.filter { store.clubs[$0].divisionTier == 3 }
        let userIndex = try XCTUnwrap(fourthDivision.first)
        store.userClubIndex = userIndex
        store.boardObjective = "Avoid relegation"

        func setUserRank(_ rank: Int) {
            let others = fourthDivision.filter { $0 != userIndex }
            for index in fourthDivision {
                store.clubs[index].won = 0
                store.clubs[index].drawn = 0
            }
            for (offset, index) in others.prefix(rank - 1).enumerated() {
                store.clubs[index].won = 40 - offset
            }
            store.clubs[userIndex].won = 20
            for (offset, index) in others.dropFirst(rank - 1).enumerated() {
                store.clubs[index].won = 19 - offset
            }
        }

        setUserRank(17)
        XCTAssertEqual(store.userPosition, 17)
        XCTAssertTrue(store.objectiveMet(),
                      "The last position outside relegation satisfies the fourth division's safe-finish objective")

        setUserRank(18)
        XCTAssertEqual(store.userPosition, 18)
        XCTAssertFalse(store.objectiveMet(), "The bottom three must miss the safe-finish objective")
    }

    func testQuickSimFinalMatchdayRecordsHonoursExactlyOnce() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Quick Sim Audit")
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let finishedSeason = store.season

        while !store.isSeasonOver { store.playNextMatchday() }

        XCTAssertEqual(store.history.filter { $0.season == finishedSeason }.count, 1,
                       "Quick-sim completion must record one SeasonRecord")
        XCTAssertEqual(store.lastHonourSeason, finishedSeason,
                       "Quick-sim completion must run the season-end board/honours pipeline")
        let honourCount = store.careerHonours.count
        let completedIDs = store.completedSeasonObjectiveIDs
        store.recordSeasonHonours()
        XCTAssertEqual(store.completedSeasonObjectiveIDs, completedIDs,
                       "Repeating the season-end commit must not grant board rewards a second time")
        XCTAssertEqual(store.history.filter { $0.season == finishedSeason }.count, 1,
                       "The live/calendar/rollover re-check must not duplicate the review")
        XCTAssertEqual(store.careerHonours.count, honourCount,
                       "Honours must remain idempotent across result paths")
    }

    func testJobOfferAcceptanceIsSingleChoiceValidatedAndSaved() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Job Offer Audit")
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        store.currentMatchday = store.totalMatchdays + 1
        store.wasSacked = true

        let destinations = store.clubs.indices.filter {
            $0 != store.userClubIndex && store.clubs[$0].divisionTier < 4
        }
        let first = offer(forClubIndex: destinations[0], in: store)
        let second = offer(forClubIndex: destinations[1], in: store)
        store.pendingJobOffers = [first, second]
        XCTAssertTrue(store.persist(), "The pending review fixture must be saved before acceptance")

        store.acceptJobOffer(first)
        XCTAssertEqual(store.pendingClubSwitch, first.clubIndex)

        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertTrue(reloaded.wasSacked, "Sacking state must survive a review relaunch")
        XCTAssertEqual(reloaded.pendingJobOffers.map(\.id), [first.id, second.id],
                       "The pending choices must survive a review relaunch")
        XCTAssertEqual(reloaded.pendingClubSwitch, first.clubIndex,
                       "Accepting a job must checkpoint the move before leaving the review")

        reloaded.acceptJobOffer(second)
        XCTAssertEqual(reloaded.pendingClubSwitch, first.clubIndex,
                       "A second acceptance must not replace the manager's chosen destination")
        let forged = JobOffer(clubIndex: first.clubIndex, clubName: second.clubName,
                              divisionName: second.divisionName, prestige: second.prestige,
                              transferBudget: second.transferBudget,
                              expectedObjective: second.expectedObjective)
        reloaded.acceptJobOffer(forged)
        XCTAssertEqual(reloaded.pendingClubSwitch, first.clubIndex,
                       "A stale/mismatched club identity must not redirect an accepted move")
    }

    func testAcceptedJobHandoffUsesPromotedClubForNewSeasonState() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Club Handoff Audit")
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        store.currentMatchday = store.totalMatchdays + 1
        let previousClubIndex = store.userClubIndex
        let previousClubName = store.userClub.name

        let destinationIndex = try XCTUnwrap(store.clubs.indices.first {
            $0 != previousClubIndex && store.clubs[$0].divisionTier == 1
        })
        let destinationID = store.clubs[destinationIndex].id
        let destinationName = store.clubs[destinationIndex].name
        let offer = offer(forClubIndex: destinationIndex, in: store)
        store.pendingJobOffers = [offer]

        // Make the destination the unambiguous automatic-promotion winner.
        for index in store.clubs.indices where store.clubs[index].divisionTier == 1 {
            store.clubs[index].played = store.totalMatchdays
            store.clubs[index].won = 0
            store.clubs[index].drawn = 0
            store.clubs[index].lost = store.totalMatchdays
            store.clubs[index].goalsFor = 0
            store.clubs[index].goalsAgainst = 0
        }
        store.clubs[destinationIndex].won = store.totalMatchdays
        store.clubs[destinationIndex].lost = 0
        store.clubs[destinationIndex].goalsFor = 100

        // Exercise the same ownership return performed before the handoff.
        var returningLoanee = try XCTUnwrap(store.clubs[destinationIndex].players.first)
        store.clubs[destinationIndex].players.removeFirst()
        returningLoanee.onLoanFromClubIndex = destinationIndex
        store.clubs[previousClubIndex].players.append(returningLoanee)
        let returningLoaneeID = returningLoanee.id

        store.boardConfidence = 80
        store.managerContractYears = 3
        store.careerRecordByClub[previousClubName] = ClubCareerRecord(wins: 3, losses: 2)
        store.recordSeasonHonours()
        XCTAssertEqual(store.history.last?.userClub, previousClubName)
        store.pendingJobOffers = [offer]
        store.captainID = try XCTUnwrap(store.userClub.players.first?.id)
        store.acceptJobOffer(offer)
        store.startNextSeason()

        XCTAssertEqual(store.userClub.id, destinationID,
                       "The accepted offer must follow the destination club through promotion")
        XCTAssertEqual(store.userClub.divisionTier, 0,
                       "The destination's promotion must be applied before the manager takes over")
        XCTAssertEqual(store.userClub.name, destinationName)
        XCTAssertEqual(store.news.first(where: { $0.title == "New chapter" })?.body,
                       "You are the new manager of \(destinationName).",
                       "The handoff news must name the destination rather than expose interpolation text")
        XCTAssertFalse(store.careerRecordByClub.keys.contains(destinationName),
                       "The new manager's record must not appear until the destination plays a match")
        XCTAssertEqual(store.careerRecordByClub[previousClubName]?.wins, 3,
                       "Completed obligations and results stay attached to the previous club")
        XCTAssertEqual(store.careerRecordByClub[previousClubName]?.losses, 2)
        let outgoingRecord = try XCTUnwrap(store.careerRecordByClub[previousClubName])
        XCTAssertEqual(outgoingRecord.goalsFor, 0)
        XCTAssertEqual(outgoingRecord.goalsAgainst, 0)
        XCTAssertTrue(store.userStarterIDs.isSubset(of: Set(store.userClub.players.map(\.id))),
                      "The starting XI must be rebuilt from the destination squad")
        XCTAssertTrue([store.captainID, store.penaltyTakerID, store.freeKickTakerID, store.cornerTakerID]
            .compactMap { $0 }.allSatisfy { id in store.userClub.players.contains { $0.id == id } },
                      "Every squad role must refer to a destination player")
        XCTAssertEqual(store.clubs[store.userClubIndex].transferBudget, store.userClub.transferBudget)
        XCTAssertTrue((2...4).contains(store.managerContractYears),
                      "The new club must receive a fresh manager contract")
        XCTAssertNil(store.pendingClubSwitch)
        XCTAssertTrue(store.pendingJobOffers.isEmpty)
        XCTAssertFalse(store.wasSacked)
        XCTAssertEqual(store.clubs[destinationIndex].players.filter { $0.id == returningLoaneeID }.count, 1)
        XCTAssertFalse(store.clubs[destinationIndex].players.first { $0.id == returningLoaneeID }?.isOnLoan ?? true,
                       "The previous club's loan must return to its actual parent before handoff")
        XCTAssertFalse(store.clubs[previousClubIndex].players.contains { $0.id == returningLoaneeID })
        XCTAssertTrue(store.friendlyFixtures.allSatisfy {
            $0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex
        }, "The new season's friendlies must belong to the destination club")

        let destinationMatchIndex = try XCTUnwrap(store.fixtures.firstIndex {
            !$0.played && ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
        })
        let beforeDestinationRecord = store.careerRecordByClub[destinationName] ?? ClubCareerRecord()
        let destinationMatchday = store.fixtures[destinationMatchIndex].matchday
        store.currentMatchday = destinationMatchday
        store.currentDate = store.date(forMatchday: destinationMatchday)
        store.beginUserMatch()
        let destinationLive = try XCTUnwrap(store.live)
        destinationLive.skipToEnd()
        let userGoals = destinationLive.userSide == .home ? destinationLive.homeGoals : destinationLive.awayGoals
        let opponentGoals = destinationLive.userSide == .home ? destinationLive.awayGoals : destinationLive.homeGoals
        store.finishLiveMatch()
        XCTAssertTrue(store.persist(), "Persist after the post-handoff result before loading a fresh store")
        XCTAssertEqual(store.careerRecordByClub[previousClubName]?.wins, 3,
                       "New-club match attribution must not mutate the outgoing club record")
        XCTAssertEqual(store.careerRecordByClub[destinationName]?.matches, beforeDestinationRecord.matches + 1,
                       "The destination must receive the manager's first record at that club")
        XCTAssertEqual(store.careerRecordByClub[destinationName]?.wins, beforeDestinationRecord.wins +
                       (userGoals > opponentGoals ? 1 : 0))
        XCTAssertEqual(store.careerRecordByClub[destinationName]?.goalsFor, beforeDestinationRecord.goalsFor + userGoals)
        XCTAssertEqual(store.careerRecordByClub[destinationName]?.goalsAgainst, beforeDestinationRecord.goalsAgainst + opponentGoals)

        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(reloaded.userClub.id, destinationID,
                       "The completed club change must survive a fresh-store reload")
        XCTAssertEqual(reloaded.managerContractYears, store.managerContractYears)
        XCTAssertEqual(reloaded.userClub.players.map(\.id), store.userClub.players.map(\.id))
        XCTAssertEqual(reloaded.careerRecordByClub, store.careerRecordByClub,
                       "Active multi-club match records must survive a real save/reload")
        XCTAssertEqual(reloaded.history.map { ($0.season, $0.userClub, $0.userDivision, $0.userPosition) }.map { "\($0.0)|\($0.1)|\($0.2)|\($0.3)" },
                       store.history.map { "\($0.season)|\($0.userClub)|\($0.userDivision)|\($0.userPosition)" },
                       "Season identity, division and finish must survive a real save/reload")
        XCTAssertEqual(reloaded.careerHonours, store.careerHonours)
    }

    func testFinalSeasonSackingDoesNotDemandAnImpossibleNewJob() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: GameStore.careerEndYear - 1,
                      managerName: "Final Season Board Audit")
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        store.currentMatchday = store.totalMatchdays + 1
        store.boardConfidence = 0

        store.recordSeasonHonours()

        XCTAssertTrue(store.isFinalSeason)
        XCTAssertTrue(store.wasSacked, "The board verdict still records final-season sacking")
        XCTAssertTrue(store.pendingJobOffers.isEmpty,
                      "A career ending after this review must not offer an unusable next-club move")
        store.endCareer()
        XCTAssertTrue(store.careerEnded,
                      "A sacked manager must be able to finish the final season without an impossible job choice")
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
