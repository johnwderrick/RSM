//
//  CupCelebrationTests.swift
//  Retro Season ManagerTests
//
//  Item 5 of the improvement directive fixed a real gap: mid-season cup
//  wins previously got no celebration UI at all — the achievement unlock
//  (and the AchievementUnlockOverlay it drives) only ever fired later,
//  batched at season end. These tests guard the fix: winning a cup final
//  now unlocks immediately, at the moment concludeCupRound() crowns the
//  winner, not only from season-end recordSeasonHonours().
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CupCelebrationTests: XCTestCase {

    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Cup Celebration Test")
        return store
    }

    func testWinningTheDomesticCupFinalUnlocksImmediately() async {
        let store = await freshStore()
        let opponentIndex = store.clubs.indices.first { $0 != store.userClubIndex }!
        XCTAssertFalse(store.unlockedAchievements.contains(.cupWinner))
        XCTAssertNil(store.pendingAchievementCelebration)

        // A single remaining tie, already resolved in the user's favour —
        // concludeCupRound() should crown them champion and celebrate
        // right here, without needing recordSeasonHonours()/season end.
        store.cupTies = [CupTie(round: 6, homeIndex: store.userClubIndex, awayIndex: opponentIndex,
                                 played: true, winnerIndex: store.userClubIndex)]
        store.concludeCupRound()

        XCTAssertTrue(store.unlockedAchievements.contains(.cupWinner),
                      "Lifting the cup should unlock .cupWinner immediately")
        XCTAssertEqual(store.pendingAchievementCelebration, .cupWinner,
                       "The trophy-lift celebration overlay should be queued the instant the cup is won")
    }

    func testLosingTheCupFinalNeverUnlocksCupWinner() async {
        let store = await freshStore()
        let opponentIndex = store.clubs.indices.first { $0 != store.userClubIndex }!
        store.cupTies = [CupTie(round: 6, homeIndex: store.userClubIndex, awayIndex: opponentIndex,
                                 played: true, winnerIndex: opponentIndex)]
        store.concludeCupRound()

        XCTAssertFalse(store.unlockedAchievements.contains(.cupWinner))
        XCTAssertNil(store.pendingAchievementCelebration)
    }

    func testSeasonEndUnlockAfterAnEarlierCupWinIsIdempotent() async {
        let store = await freshStore()
        let opponentIndex = store.clubs.indices.first { $0 != store.userClubIndex }!
        store.cupTies = [CupTie(round: 6, homeIndex: store.userClubIndex, awayIndex: opponentIndex,
                                 played: true, winnerIndex: store.userClubIndex)]
        store.concludeCupRound()
        let pointsAfterCupWin = store.careerAchievementPoints

        // recordSeasonHonours() re-checks the same condition at season
        // end regardless of when the cup was actually won — unlock(_:)'s
        // own idempotency guard must make that a no-op, not a double award.
        store.unlock(.cupWinner)

        XCTAssertEqual(store.careerAchievementPoints, pointsAfterCupWin,
                       "A repeat unlock of an already-unlocked achievement must not award points again")
    }
}
