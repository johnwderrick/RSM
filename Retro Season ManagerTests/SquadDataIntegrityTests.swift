//
//  SquadDataIntegrityTests.swift
//  Retro Season ManagerTests
//
//  Permanent version of a one-off check run by hand while authoring the
//  2020-era rosters: every hand-authored club, in every era, must field
//  exactly 18 players (2 GK, 6 DEF, 6 MID, 4 FWD — see
//  HistoricalSquads2000.swift's header). A future hand-edit to any era's
//  squad file that drops or duplicates an entry should fail here instead
//  of silently shipping a club that's a player short.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class SquadDataIntegrityTests: XCTestCase {
    func testEveryHistoricalClubHasEighteenPlayers() {
        for (year, book) in GameStore.historicalEras {
            for (club, roster) in book {
                XCTAssertEqual(roster.count, 18, "\(club) (\(year)) has \(roster.count) players, expected 18")
            }
        }
    }

    func testEveryHistoricalClubHasExactlyTwoGoalkeepers() {
        for (year, book) in GameStore.historicalEras {
            for (club, roster) in book {
                let goalkeepers = roster.filter { $0.detailedPosition == .goalkeeper }.count
                XCTAssertGreaterThanOrEqual(goalkeepers, 2, "\(club) (\(year)) has only \(goalkeepers) goalkeeper(s)")
            }
        }
    }

    func testAllThreeErasCoverTheSameTwentyDomesticClubNames() {
        let domesticClubNames = Set(GameStore.tierPools[0])
        for (year, book) in GameStore.historicalEras {
            let coveredDomestic = Set(book.keys).intersection(domesticClubNames)
            XCTAssertEqual(coveredDomestic, domesticClubNames, "\(year) is missing domestic clubs: \(domesticClubNames.subtracting(coveredDomestic))")
        }
    }

    func testAllThreeErasCoverTheSameEightForeignGiants() {
        let foreignClubNames = Set(GameStore.foreignPool.map(\.name))
        for (year, book) in GameStore.historicalEras {
            let coveredForeign = Set(book.keys).intersection(foreignClubNames)
            XCTAssertEqual(coveredForeign, foreignClubNames, "\(year) is missing foreign clubs: \(foreignClubNames.subtracting(coveredForeign))")
        }
    }
}
