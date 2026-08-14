import XCTest
@testable import Retro_Season_Manager

/// `checkTransferGenius` is `private` to `GameStore+Transfers.swift`.
/// Rather than loosening it purely for testing, these tests go through
/// `sellPlayer(_:)` — the real (internal) entry point that calls it —
/// the same "test the public behavior, not the implementation" approach
/// as `NewspaperClassifierTests`.
final class TransferGeniusTests: XCTestCase {
    /// A squad large enough, and deep enough at one position, that
    /// `sellPlayer`'s "keep at least 16 players" / "keep enough cover"
    /// guards never trip while selling several players one at a time.
    private func setupStore(playerCount: Int = 25) async -> (store: GameStore, players: [Player]) {
        let store = await makeTestStore()
        let players = await MainActor.run {
            (0..<playerCount).map { i in
                GameStore.makePlayer(name: "Player \(i)", position: .defender, detailedPosition: .centreBack, age: 25, rating: 70)
            }
        }
        await MainActor.run {
            store.clubs = [Club(name: "Test Club", shortName: "TST", players: players)]
            store.userClubIndex = 0
            // The transfer window is date-driven (deadline day is 31 March
            // of the season after it opens) — pin `currentDate` well inside
            // it rather than relying on whatever "today" happens to be.
            store.currentDate = store.seasonStartDate.addingTimeInterval(86400 * 30)
        }
        return (store, players)
    }

    /// Records a prior signing at a fraction of the player's current
    /// value, so selling at market rate (90% of value) clears the "sold
    /// for ≥1.8x what was paid" bar comfortably.
    private func recordProfitableSigning(_ store: GameStore, player: Player) async {
        await MainActor.run {
            let boughtFee = player.value / 4
            store.transferHistory.append(TransferHistoryEntry(date: store.currentDate, playerName: player.name,
                                                               action: "Signed", otherClub: "Some Club", fee: boughtFee))
        }
    }

    func testFourProfitableSalesDoNotUnlockTransferGeniusYet() async {
        let (store, players) = await setupStore()
        for player in players.prefix(4) {
            await recordProfitableSigning(store, player: player)
            await MainActor.run { _ = store.sellPlayer(player) }
        }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertFalse(unlocked.contains(.transferGenius))
    }

    func testFiveProfitableSalesUnlockTransferGenius() async {
        let (store, players) = await setupStore()
        for player in players.prefix(5) {
            await recordProfitableSigning(store, player: player)
            await MainActor.run { _ = store.sellPlayer(player) }
        }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertTrue(unlocked.contains(.transferGenius))
    }

    func testSellingAtBreakEvenNeverCountsAsProfitable() async {
        // Selling for roughly what was paid — well under the 1.8x bar —
        // should never accumulate toward the achievement, no matter how
        // many times it happens.
        let (store, players) = await setupStore()
        for player in players.prefix(6) {
            await MainActor.run {
                store.transferHistory.append(TransferHistoryEntry(date: store.currentDate, playerName: player.name,
                                                                   action: "Signed", otherClub: "Some Club", fee: player.value))
            }
            await MainActor.run { _ = store.sellPlayer(player) }
        }
        let unlocked = await MainActor.run { store.unlockedAchievements }
        XCTAssertFalse(unlocked.contains(.transferGenius))
    }
}
