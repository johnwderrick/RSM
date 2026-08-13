//
//  LegacyScoringTests.swift
//  Retro Season ManagerTests
//

import XCTest
@testable import Retro_Season_Manager

final class LegacyScoringTests: XCTestCase {
    func testScoreWeighting() {
        // Trophies count for the most (x15), legends next (x10), then a
        // modest per-season credit (x2), with achievement points added flat.
        let score = LegacyScoring.score(trophyCount: 2, seasonsManaged: 10, achievementPoints: 30, legendCount: 1)
        XCTAssertEqual(score, 2 * 15 + 1 * 10 + 10 * 2 + 30)
    }

    func testScoreWithNothingIsZero() {
        XCTAssertEqual(LegacyScoring.score(trophyCount: 0, seasonsManaged: 0, achievementPoints: 0, legendCount: 0), 0)
    }

    func testTierBoundaries() {
        XCTAssertEqual(LegacyTier.forScore(0), .modest)
        XCTAssertEqual(LegacyTier.forScore(49), .modest)
        XCTAssertEqual(LegacyTier.forScore(50), .journeyman)
        XCTAssertEqual(LegacyTier.forScore(149), .journeyman)
        XCTAssertEqual(LegacyTier.forScore(150), .accomplished)
        XCTAssertEqual(LegacyTier.forScore(299), .accomplished)
        XCTAssertEqual(LegacyTier.forScore(300), .distinguished)
        XCTAssertEqual(LegacyTier.forScore(499), .distinguished)
        XCTAssertEqual(LegacyTier.forScore(500), .legend)
        XCTAssertEqual(LegacyTier.forScore(10000), .legend)
    }
}

final class CareerLengthTests: XCTestCase {
    /// A 2000 start runs the full 30 seasons; 2010 and 2020 starts run
    /// proportionally fewer, all converging on the same fixed end year —
    /// the core mechanic behind Legacy Mode's fixed-era career start.
    ///
    /// Exercises the real `maxSeasons` computed property on a live
    /// instance, not just the arithmetic it's defined by — see
    /// `makeTestStore()` for why construction is routed through a `Task`
    /// hop rather than called inline.
    func testMaxSeasonsScalesWithStartYearToAFixedEndYear() async {
        let store = await makeTestStore()
        await MainActor.run {
            store.startYear = 2000
            XCTAssertEqual(store.maxSeasons, 30)
            store.startYear = 2010
            XCTAssertEqual(store.maxSeasons, 20)
            store.startYear = 2020
            XCTAssertEqual(store.maxSeasons, 10)
        }
    }

    @MainActor
    func testAvailableStartYearsAreExactlyTheThreeFixedEras() {
        XCTAssertEqual(GameStore.availableStartYears, [2000, 2010, 2020])
    }
}
