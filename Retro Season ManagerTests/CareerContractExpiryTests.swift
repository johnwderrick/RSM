import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerContractExpiryTests: XCTestCase {
    private func career() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Contract Expiry Audit")
        store.clubs[store.userClubIndex].wageBudget = 1_000_000
        store.clubs[store.userClubIndex].transferBudget = 1_000_000
        return store
    }

    private func expiredPlayer(_ store: GameStore) -> Player {
        var player = GameStore.makePlayer(name: "Expiry Audit Player", position: .forward, age: 24, rating: 65)
        player.contractYears = 0
        player.wage = 3
        store.clubs[1].players.append(player)
        return player
    }

    private func sign(_ store: GameStore, _ player: Player, from club: Int?) throws {
        for _ in 0..<50 {
            if case .accepted = store.signFreeAgent(player, fromClubIndex: club, wage: 100, years: 3, signingOnFee: 25) { return }
        }
        XCTFail("An affordable, generous offer did not land within 50 attempts")
        throw NSError(domain: "ContractExpiryAudit", code: 1)
    }

    private func assertRejected(_ store: GameStore, _ player: Player, from club: Int?, file: StaticString = #filePath, line: UInt = #line) {
        let squad = store.userClub.players.map(\.id)
        let budget = store.userClub.transferBudget
        let wages = store.userClub.wageBill
        let ledger = store.seasonLedger.map(\.id)
        for _ in 0..<10 {
            guard case .rejected = store.signFreeAgent(player, fromClubIndex: club, wage: 100, years: 3, signingOnFee: 25) else {
                return XCTFail("Unavailable player must not sign", file: file, line: line)
            }
        }
        XCTAssertEqual(store.userClub.players.map(\.id), squad, file: file, line: line)
        XCTAssertEqual(store.userClub.transferBudget, budget, file: file, line: line)
        XCTAssertEqual(store.userClub.wageBill, wages, file: file, line: line)
        XCTAssertEqual(store.seasonLedger.map(\.id), ledger, file: file, line: line)
    }

    func testSeasonRolloverAutoRenewalPreservesPlayerAndSelectionOnReload() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        var player = GameStore.makePlayer(name: "Renewal Audit Player", position: .forward, age: 20, rating: 65)
        player.contractYears = 1
        player.wage = 3
        store.clubs[store.userClubIndex].players.append(player)
        store.captainID = player.id
        store.userStarterIDs.insert(player.id)
        var matchdays = 0
        while !store.isSeasonOver && matchdays < store.totalMatchdays + 5 {
            store.playNextMatchday()
            matchdays += 1
        }
        XCTAssertTrue(store.isSeasonOver)
        let season = store.season
        store.startNextSeason()
        XCTAssertEqual(store.season, season + 1)
        let renewed = try XCTUnwrap(store.currentPlayer(player.id))
        XCTAssertGreaterThan(renewed.contractYears, 0, "Existing expiry policy auto-renews")
        XCTAssertEqual(renewed.wage, playerWage(rating: renewed.rating, age: renewed.age, startYear: store.startYear),
                       "Rollover retains the existing development wage recalculation")
        XCTAssertEqual(renewed.age, 21)
        XCTAssertEqual(store.userClub.players.filter { $0.id == player.id }.count, 1)
        XCTAssertEqual(store.captainID, player.id)
        XCTAssertTrue(store.userStarterIDs.isSubset(of: Set(store.userClub.players.map(\.id))))
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(reloaded.currentPlayer(player.id)?.contractYears, renewed.contractYears)
        XCTAssertEqual(reloaded.userClub.wageBill, store.userClub.wageBill)
        XCTAssertEqual(reloaded.captainID, player.id)
    }

    func testExpiredClubPlayerSignsWithOneFinancialEffectAndReloads() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let player = expiredPlayer(store)
        let squadCount = store.userClub.players.count
        let wages = store.userClub.wageBill
        let sellerWages = store.clubs[1].wageBill
        let budget = store.userClub.transferBudget
        let ledger = store.seasonLedger.reduce(0) { $0 + $1.amount }
        try sign(store, player, from: 1)
        XCTAssertEqual(store.userClub.players.count, squadCount + 1)
        XCTAssertEqual(store.userClub.wageBill, wages + 100)
        XCTAssertEqual(store.clubs[1].wageBill, sellerWages - player.wage)
        XCTAssertFalse(store.clubs[1].players.contains { $0.id == player.id })
        XCTAssertEqual(store.currentPlayer(player.id)?.contractYears, 3)
        XCTAssertEqual(store.userClub.transferBudget, budget - 25)
        XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledger, -25)
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(reloaded.userClub.players.filter { $0.id == player.id }.count, 1)
        XCTAssertEqual(reloaded.userClub.wageBill, wages + 100)
        XCTAssertEqual(reloaded.currentPlayer(player.id)?.wage, 100)
        XCTAssertEqual(reloaded.currentPlayer(player.id)?.contractYears, 3)
        assertRejected(reloaded, player, from: 1)
    }

    func testMarketFreeAgentCannotSignTwiceOrLoseShortlistIdentity() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let target = try XCTUnwrap(store.transferMarket.first { $0.sellingClubIndex == nil })
        store.shortlistedPlayerIDs.insert(target.player.id)
        store.persist()
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        try sign(reloaded, target.player, from: nil)
        XCTAssertFalse(reloaded.transferMarket.contains { $0.player.id == target.player.id })
        XCTAssertEqual(reloaded.shortlistedResults.filter { $0.player.id == target.player.id }.count, 1)
        XCTAssertEqual(reloaded.shortlistedResults.first { $0.player.id == target.player.id }?.clubIndex, reloaded.userClubIndex)
        assertRejected(reloaded, target.player, from: nil)
    }

    func testRemovedMarketTargetCannotBeSignedFromStaleProfile() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let target = try XCTUnwrap(store.transferMarket.first { $0.sellingClubIndex == nil })
        store.transferMarket.removeAll { $0.player.id == target.player.id }
        assertRejected(store, target.player, from: nil)
    }

    func testLiveContractCannotBeBypassedWithExpiredSnapshotOrNilClub() async throws {
        for nilClub in [false, true] {
            let store = await career()
            let saveID = try XCTUnwrap(store.currentSaveID)
            defer { GameStore.deleteSave(id: saveID) }
            let player = expiredPlayer(store)
            let index = try XCTUnwrap(store.clubs[1].players.firstIndex { $0.id == player.id })
            store.clubs[1].players[index].contractYears = 4
            assertRejected(store, player, from: nilClub ? nil : 1)
            XCTAssertEqual(store.clubs[1].players.first { $0.id == player.id }?.contractYears, 4)
        }
    }

    func testPlayerMovedToAnotherClubCannotSignFromOldClubSnapshot() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let player = expiredPlayer(store)
        store.clubs[1].players.removeAll { $0.id == player.id }
        store.clubs[2].players.append(player)
        assertRejected(store, player, from: 1)
        XCTAssertEqual(store.clubs[2].players.filter { $0.id == player.id }.count, 1)
    }

    func testFreeSigningUsesCurrentPlayerRecordAndClearsOldTransferRequest() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let player = expiredPlayer(store)
        let index = try XCTUnwrap(store.clubs[1].players.firstIndex { $0.id == player.id })
        store.clubs[1].players[index].age = 25
        store.clubs[1].players[index].rating = 68
        store.clubs[1].players[index].wantsToLeave = true
        try sign(store, player, from: 1)
        let signed = try XCTUnwrap(store.currentPlayer(player.id))
        XCTAssertEqual(signed.age, 25)
        XCTAssertEqual(signed.rating, 68)
        XCTAssertFalse(signed.wantsToLeave, "A new contract resolves the old club's transfer request")
    }
}
