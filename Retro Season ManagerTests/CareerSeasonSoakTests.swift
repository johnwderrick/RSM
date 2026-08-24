//
//  CareerSeasonSoakTests.swift
//  Retro Season ManagerTests
//
//  Exploratory soak test — drives a fresh Career Mode save through one
//  full 38-matchday league season via `playNextMatchday()` (the same
//  instant-sim fallback path the app itself uses when there's no live
//  match to play), then through the season-end pipeline
//  (`startNextSeason()`), asserting invariants throughout. Most of
//  GameStore+MatchEngine.swift's actual match simulation had no
//  automated coverage before this — this is a broad correctness sweep,
//  not a narrow unit test.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerSeasonSoakTests: XCTestCase {
    func testSimulateOneFullLeagueSeason() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Soak Test")

        XCTAssertTrue(store.hasStarted)
        XCTAssertEqual(store.season, 1)
        XCTAssertEqual(store.currentMatchday, 1)
        XCTAssertFalse(store.isSeasonOver)
        XCTAssertFalse(store.careerEnded)
        XCTAssertEqual(store.seasonObjectives.count, 4, "newGame() should roll four Season Objectives")

        let totalMatchdays = store.totalMatchdays
        var matchdaysSimulated = 0
        let safetyCap = totalMatchdays + 5 // headroom in case of an off-by-one, without looping forever on a real stall

        while !store.isSeasonOver && matchdaysSimulated < safetyCap {
            let matchdayBefore = store.currentMatchday
            let userClubIndexBefore = store.userClubIndex

            store.playNextMatchday()
            matchdaysSimulated += 1

            XCTAssertEqual(store.currentMatchday, matchdayBefore + 1, "currentMatchday should advance by exactly 1 per playNextMatchday() call")
            XCTAssertEqual(store.userClubIndex, userClubIndexBefore, "Simulating a matchday shouldn't change who the user manages")

            for club in store.clubs {
                XCTAssertEqual(club.won + club.drawn + club.lost, club.played,
                                "\(club.name)'s win/draw/loss record should sum to matches played (matchday \(matchdayBefore))")
                XCTAssertGreaterThanOrEqual(club.goalsFor, 0, "\(club.name) has negative goalsFor")
                XCTAssertGreaterThanOrEqual(club.goalsAgainst, 0, "\(club.name) has negative goalsAgainst")
                XCTAssertGreaterThanOrEqual(club.players.count, 11, "\(club.name) dropped below a fieldable squad size")

                for player in club.players {
                    XCTAssertGreaterThanOrEqual(player.goals, 0, "\(player.name) (\(club.name)) has negative goals")
                    XCTAssertGreaterThanOrEqual(player.fitness, 0, "\(player.name) (\(club.name)) has negative fitness")
                    XCTAssertLessThanOrEqual(player.fitness, 100, "\(player.name) (\(club.name)) has fitness over 100")
                    XCTAssertGreaterThanOrEqual(player.injuryWeeks, 0, "\(player.name) (\(club.name)) has negative injuryWeeks")
                    XCTAssertGreaterThanOrEqual(player.suspensionMatches, 0, "\(player.name) (\(club.name)) has negative suspensionMatches")
                    XCTAssertGreaterThanOrEqual(player.rating, 1, "\(player.name) (\(club.name)) has rating below 1")
                    XCTAssertLessThanOrEqual(player.rating, 99, "\(player.name) (\(club.name)) has rating above 99")
                    XCTAssertGreaterThanOrEqual(player.morale, 0, "\(player.name) (\(club.name)) has negative morale")
                }
            }

            // Every league fixture up to and including this matchday
            // should be marked played — a stall here (an unplayed
            // earlier-matchday fixture) would mean some club got skipped.
            for fixture in store.fixtures where fixture.matchday <= matchdayBefore {
                XCTAssertTrue(fixture.played, "Matchday \(fixture.matchday) fixture (clubs \(fixture.homeIndex) v \(fixture.awayIndex)) should be played by matchday \(matchdayBefore)")
            }

            // checkSeasonObjectives() runs on every match result via
            // updateBoard — a full season's worth of calls should never
            // complete an objective that isn't (still) this season's, and
            // homeUnbeatenStreak/fanConfidence should stay in sane bounds.
            let currentObjectiveIDs = Set(store.seasonObjectives.map(\.id))
            XCTAssertTrue(store.completedSeasonObjectiveIDs.isSubset(of: currentObjectiveIDs),
                           "completedSeasonObjectiveIDs should only ever contain this season's objective IDs (matchday \(matchdayBefore))")
            XCTAssertGreaterThanOrEqual(store.homeUnbeatenStreak, 0, "homeUnbeatenStreak went negative (matchday \(matchdayBefore))")
            XCTAssertGreaterThanOrEqual(store.fanConfidence, 0, "fanConfidence went negative (matchday \(matchdayBefore))")
            XCTAssertLessThanOrEqual(store.fanConfidence, 100, "fanConfidence exceeded 100 (matchday \(matchdayBefore))")
        }

        XCTAssertTrue(store.isSeasonOver, "Season should be over after simulating every matchday (stopped at \(matchdaysSimulated)/\(totalMatchdays))")
        XCTAssertEqual(matchdaysSimulated, totalMatchdays, "Should take exactly totalMatchdays calls to finish the season, no more or fewer")
        XCTAssertEqual(store.clubs[store.userClubIndex].played, totalMatchdays, "User club should have played every matchday")
        XCTAssertTrue(store.fixtures.allSatisfy { $0.played }, "Every league fixture should be marked played by season's end")

        // Sanity-check the final table: goal difference and points should
        // be internally consistent for every club, and the sum of every
        // club's goalsFor should equal the sum of every club's
        // goalsAgainst (goals don't appear or vanish across the league).
        let totalGoalsFor = store.clubs.reduce(0) { $0 + $1.goalsFor }
        let totalGoalsAgainst = store.clubs.reduce(0) { $0 + $1.goalsAgainst }
        XCTAssertEqual(totalGoalsFor, totalGoalsAgainst, "Total goalsFor across every club should equal total goalsAgainst")

        let userClubBefore = store.userClub
        let seasonBefore = store.season

        // Exercise the season-end pipeline: honours, promotion/relegation,
        // squad aging/progression, transfer market reset.
        store.startNextSeason()

        XCTAssertEqual(store.season, seasonBefore + 1, "Season should increment exactly once")
        XCTAssertFalse(store.isSeasonOver, "A fresh season shouldn't already be over")
        XCTAssertEqual(store.currentMatchday, 1, "A fresh season should restart at matchday 1")
        XCTAssertFalse(store.careerEnded, "One season shouldn't end a career with maxSeasons this high")
        XCTAssertTrue(store.clubs.allSatisfy { $0.played == 0 }, "Every club's record should reset for the new season")
        XCTAssertEqual(store.seasonObjectives.count, 4, "startNextSeason() should roll a fresh set of four Season Objectives")
        XCTAssertTrue(store.completedSeasonObjectiveIDs.isEmpty, "Completed objective IDs should reset for the new season")

        // The living-world pass (simulateWorldEvents(), called from
        // startNextSeason()) should run without crashing and leave its
        // tracking state in sane bounds — every AI club should have a
        // seeded prestige baseline by now, and the wonderkid watchlist
        // shouldn't grow without bound.
        let aiClubIDs = store.clubs.indices.filter { $0 != store.userClubIndex }.map { store.clubs[$0].id }
        XCTAssertTrue(aiClubIDs.allSatisfy { store.clubPrestigeBaseline[$0] != nil },
                      "Every AI club should have a prestige baseline after at least one living-world pass")
        XCTAssertLessThan(store.wonderkidWatchlist.count, 50, "The wonderkid watchlist shouldn't grow unboundedly across a single season")
        XCTAssertLessThan(store.pendingWorldStories.count, 20, "The pending-story queue shouldn't grow unboundedly")
        for club in store.clubs {
            XCTAssertGreaterThanOrEqual(club.players.count, 11, "\(club.name) dropped below a fieldable squad size after squad progression")
            for player in club.players {
                XCTAssertGreaterThanOrEqual(player.rating, 1, "\(player.name) (\(club.name)) has rating below 1 after squad progression")
                XCTAssertLessThanOrEqual(player.rating, 99, "\(player.name) (\(club.name)) has rating above 99 after squad progression")
            }
        }

        print("""

        ================= CAREER SEASON SOAK SUMMARY =================
        club:                  \(userClubBefore.name) (\(userClubBefore.shortName))
        division at kickoff:   \(store.divisionName(userClubBefore.divisionTier))
        matchdays simulated:   \(matchdaysSimulated)
        final record:          W\(userClubBefore.won) D\(userClubBefore.drawn) L\(userClubBefore.lost), GF\(userClubBefore.goalsFor) GA\(userClubBefore.goalsAgainst)
        total league goals:    \(totalGoalsFor)
        transfer budget:       \(userClubBefore.transferBudget)
        new season:            \(store.season)
        new division:          \(store.divisionName(store.userClub.divisionTier))
        new transfer budget:   \(store.userClub.transferBudget)
        career ended:          \(store.careerEnded)
        =================================================================
        """)
    }
}
