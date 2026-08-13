import XCTest
@testable import Retro_Season_Manager

final class AchievementThresholdTests: XCTestCase {
    private func store(wins: Int, draws: Int = 0, losses: Int = 0) async -> GameStore {
        let store = await makeTestStore()
        await MainActor.run {
            // `unlock(_:)` builds a context string via `userClub` (=
            // `clubs[userClubIndex]`) regardless of which achievement
            // fired, so every scenario needs at least one club present.
            store.clubs = [Club(name: "Test Club", shortName: "TST", players: [])]
            store.userClubIndex = 0
            var record = ClubCareerRecord()
            record.wins = wins
            record.draws = draws
            record.losses = losses
            store.careerRecordByClub = ["Test Club": record]
        }
        return store
    }

    func testNoMilestonesBelowFifty() async {
        let store = await store(wins: 49)
        await MainActor.run { store.checkWinMilestones() }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertFalse(unlocked.contains(.wins50))
    }

    func testFiftyWinsUnlocksWins50Only() async {
        let store = await store(wins: 50)
        await MainActor.run { store.checkWinMilestones() }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertTrue(unlocked.contains(.wins50))
        XCTAssertFalse(unlocked.contains(.wins100))
        XCTAssertFalse(unlocked.contains(.wins200))
    }

    func testTwoHundredWinsUnlocksEveryLowerWinMilestoneToo() async {
        // Each threshold is checked independently against the same running
        // total, not exclusively — crossing 200 should also register 50
        // and 100, the same way a save loaded mid-career would.
        let store = await store(wins: 200)
        await MainActor.run { store.checkWinMilestones() }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertTrue(unlocked.contains(.wins50))
        XCTAssertTrue(unlocked.contains(.wins100))
        XCTAssertTrue(unlocked.contains(.wins200))
    }

    func testThousandMatchesMilestoneCountsDrawsAndLossesToo() async {
        // 1000 total matches, deliberately with wins alone under every win
        // threshold — matches1000 must fire from the combined total, not
        // from wins() being high.
        let store = await store(wins: 10, draws: 490, losses: 500)
        await MainActor.run { store.checkWinMilestones() }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertTrue(unlocked.contains(.matches1000))
        XCTAssertFalse(unlocked.contains(.wins50))
    }

    func testUnlockingIsIdempotent() async {
        // Calling the check twice (as a real career does, after every
        // result) must not double-count or throw — `unlock(_:)` guards on
        // `Set.insert`, this just confirms that holds from the outside too.
        let store = await store(wins: 50)
        await MainActor.run {
            store.checkWinMilestones()
            store.checkWinMilestones()
        }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertTrue(unlocked.contains(.wins50))
    }
}
