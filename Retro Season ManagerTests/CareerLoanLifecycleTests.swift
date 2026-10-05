import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerLoanLifecycleTests: XCTestCase {
    private func career() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Loan Lifecycle Audit")
        for index in store.clubs.indices {
            store.clubs[index].wageBudget = 1_000_000
            store.clubs[index].transferBudget = 1_000_000
        }
        return store
    }

    private func incoming(_ store: GameStore) throws -> Player {
        var player = GameStore.makePlayer(name: "Loan Audit Incoming", position: .forward, age: 20, rating: 65)
        player.wage = 3
        player.contractYears = 4
        store.clubs[1].players.append(player)
        let target = TransferTarget(player: player, sellingClubIndex: 1, askingPrice: 500)
        store.transferMarket = [target]
        XCTAssertTrue(store.loanIn(target).contains("Loaned"))
        return try XCTUnwrap(store.currentPlayer(player.id))
    }

    private func outgoing(_ store: GameStore, fee: Int = 50) throws -> Player {
        var player = GameStore.makePlayer(name: "Loan Audit Outgoing", position: .forward, age: 20, rating: 65)
        player.wage = 4
        player.contractYears = 4
        store.clubs[store.userClubIndex].players.append(player)
        store.userStarterIDs.insert(player.id)
        store.captainID = player.id
        store.penaltyTakerID = player.id
        for _ in 0..<200 {
            if case .accepted = store.proposeLoanOut(player, toClubIndex: 2, fee: fee) {
                return player
            }
        }
        XCTFail("Affordable loan failed to land within 200 attempts")
        throw NSError(domain: "LoanAudit", code: 1)
    }

    private func locations(_ store: GameStore, _ id: UUID) -> [Int] {
        store.clubs.indices.filter { index in store.clubs[index].players.contains { $0.id == id } }
    }

    func testIncomingLoanSaveReloadAndReturnPreserveParentAndWages() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let wages = store.userClub.wageBill
        let parentWages = store.clubs[1].wageBill
        let player = try incoming(store)
        XCTAssertEqual(store.userClub.wageBill, wages + 3)
        XCTAssertEqual(locations(store, player.id), [store.userClubIndex])
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(reloaded.currentPlayer(player.id)?.onLoanFromClubIndex, 1)
        XCTAssertEqual(reloaded.userClub.wageBill, wages + 3)
        reloaded.returnLoans()
        reloaded.returnLoans()
        XCTAssertEqual(locations(reloaded, player.id), [1])
        XCTAssertEqual(reloaded.clubs[1].players.filter { $0.id == player.id }.count, 1)
        XCTAssertNil(reloaded.clubs[1].players.first { $0.id == player.id }?.onLoanFromClubIndex)
        XCTAssertEqual(reloaded.userClub.wageBill, wages)
        XCTAssertEqual(reloaded.clubs[1].wageBill, parentWages + 3)
    }

    func testOutgoingLoanReloadRecallAndRepeatedRecallAreCoherent() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let wages = store.userClub.wageBill
        let player = try outgoing(store)
        XCTAssertEqual(store.userClub.wageBill, wages)
        XCTAssertFalse(store.userStarterIDs.contains(player.id))
        XCTAssertNotEqual(store.captainID, player.id)
        XCTAssertNotEqual(store.penaltyTakerID, player.id)
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(reloaded.playersOnLoanFromUser().filter { $0.player.id == player.id }.count, 1)
        let budget = reloaded.userClub.transferBudget
        let ledger = reloaded.seasonLedger.map(\.id)
        XCTAssertTrue(reloaded.recallFromLoan(player).contains("recalled"))
        XCTAssertEqual(locations(reloaded, player.id), [reloaded.userClubIndex])
        XCTAssertEqual(reloaded.userClub.wageBill, wages + 4)
        XCTAssertFalse(try XCTUnwrap(reloaded.currentPlayer(player.id)).isOnLoan)
        XCTAssertTrue(reloaded.recallFromLoan(player).contains("isn't out on loan"))
        XCTAssertEqual(reloaded.userClub.players.filter { $0.id == player.id }.count, 1)
        XCTAssertEqual(reloaded.userClub.transferBudget, budget, "Recall does not refund the agreed loan fee")
        XCTAssertEqual(reloaded.seasonLedger.map(\.id), ledger)
    }

    func testRealSeasonRolloverReturnsLoansBeforeContractsAndDevelopment() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let arriving = try incoming(store)
        let leaving = try outgoing(store)
        let season = store.season
        var matchdays = 0
        while !store.isSeasonOver && matchdays < store.totalMatchdays + 5 {
            store.playNextMatchday()
            matchdays += 1
        }
        XCTAssertTrue(store.isSeasonOver, "Loans must survive a completed season before rollover")
        XCTAssertEqual(locations(store, arriving.id), [store.userClubIndex])
        XCTAssertEqual(locations(store, leaving.id), [2])
        XCTAssertTrue(store.userClub.players.first { $0.id == arriving.id }?.isOnLoan == true)
        XCTAssertTrue(store.clubs[2].players.first { $0.id == leaving.id }?.isOnLoan == true)
        store.startNextSeason()
        XCTAssertEqual(store.season, season + 1)
        XCTAssertEqual(locations(store, arriving.id), [1])
        XCTAssertEqual(locations(store, leaving.id), [store.userClubIndex])
        for (id, owner) in [(arriving.id, 1), (leaving.id, store.userClubIndex)] {
            let returned = try XCTUnwrap(store.clubs[owner].players.first { $0.id == id })
            XCTAssertFalse(returned.isOnLoan)
            XCTAssertEqual(returned.age, 21, "Development must run once after return")
            XCTAssertEqual(returned.contractYears, 3, "The parent contract runs down once")
            XCTAssertEqual(store.clubs[owner].players.filter { $0.id == id }.count, 1)
        }
        XCTAssertTrue(store.playersOnLoanFromUser().isEmpty)
        XCTAssertTrue(store.userStarterIDs.isSubset(of: Set(store.userClub.players.map(\.id))))
        XCTAssertFalse(store.userStartingXI().contains { $0.id == arriving.id })
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(locations(reloaded, arriving.id), [1])
        XCTAssertEqual(locations(reloaded, leaving.id), [store.userClubIndex])
    }

    func testLoanedPlayerDoesNotEnterMarketOrWorldScouting() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let player = try outgoing(store)
        // Make the loanee the host's cheapest player: an unfiltered market
        // necessarily lists him among its three surplus players.
        let index = try XCTUnwrap(store.clubs[2].players.firstIndex { $0.id == player.id })
        store.clubs[2].players[index].rating = 1
        store.generateTransferMarket()
        XCTAssertFalse(store.transferMarket.contains { $0.player.id == player.id })
        // Only a borrowed player remains outside the user's squad. Scouting
        // must not invent an offerable ownership claim for his host club.
        for club in store.clubs.indices where club != store.userClubIndex {
            store.clubs[club].players.removeAll { $0.id != player.id }
        }
        store.transferMarket = []
        store.scoutTheWorld(youthOnly: false)
        XCTAssertTrue(store.transferMarket.isEmpty)
        XCTAssertEqual(locations(store, player.id), [2])
    }

    func testIncomingLoaneeDoesNotReceivePermanentSaleOffer() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let player = try incoming(store)
        for index in store.clubs[store.userClubIndex].players.indices {
            store.clubs[store.userClubIndex].players[index].rating = store.clubs[store.userClubIndex].players[index].id == player.id ? 80 : 60
        }
        store.pendingOffers = []
        store.generateOfferForUser()
        XCTAssertTrue(store.pendingOffers.isEmpty, "The borrower must not receive an offer for the parent's player")
    }

    func testLegacyOfferForLoaneeCannotBeAcceptedOrCountered() async throws {
        for counter in [false, true] {
            let store = await career()
            let saveID = try XCTUnwrap(store.currentSaveID)
            defer { GameStore.deleteSave(id: saveID) }
            let player = try incoming(store)
            let offer = TransferOffer(playerID: player.id, playerName: player.name, fromClubIndex: 2,
                                      amount: 500, expiryDate: store.currentDate)
            store.pendingOffers = [offer]
            let budget = store.userClub.transferBudget
            if counter {
                guard case .rejected(let reason, _) = store.counterSellOffer(offer, askingAmount: 500) else {
                    return XCTFail("Borrowed player must not be sold by a counteroffer")
                }
                XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
            } else {
                XCTAssertTrue(store.acceptOffer(offer).lowercased().contains("on loan"))
            }
            XCTAssertEqual(locations(store, player.id), [store.userClubIndex])
            XCTAssertEqual(store.userClub.transferBudget, budget)
        }
    }

    func testBorrowedSquadPlayerCannotBeSoldReleasedOrRenewed() async throws {
        for action in ["sell", "release", "renew"] {
            let store = await career()
            let saveID = try XCTUnwrap(store.currentSaveID)
            defer { GameStore.deleteSave(id: saveID) }
            let player = try incoming(store)
            let index = try XCTUnwrap(store.clubs[store.userClubIndex].players.firstIndex { $0.id == player.id })
            store.clubs[store.userClubIndex].players[index].wantsToLeave = true
            let actual = store.clubs[store.userClubIndex].players[index]
            let budget = store.userClub.transferBudget
            let wage = actual.wage
            switch action {
            case "sell": XCTAssertTrue(store.sellPlayer(actual).lowercased().contains("on loan"))
            case "release": XCTAssertTrue(store.terminateContract(actual).lowercased().contains("on loan"))
            default:
                guard case .rejected(let reason, _) = store.proposeRenewal(actual, wage: store.renewalDemand(actual) * 2,
                                                                        years: 3, signingOnFee: 50) else {
                    return XCTFail("The borrower cannot renew the parent club's contract")
                }
                XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
            }
            XCTAssertEqual(locations(store, player.id), [store.userClubIndex], action)
            XCTAssertEqual(store.userClub.transferBudget, budget, action)
            XCTAssertEqual(store.currentPlayer(player.id)?.wage, wage, action)
            XCTAssertEqual(store.currentPlayer(player.id)?.onLoanFromClubIndex, 1, action)
        }
    }

    func testBorrowedPlayerCannotBeBoughtOrLoanedAgainFromHost() async throws {
        for action in ["search", "buy", "bid", "loan"] {
            let store = await career()
            let saveID = try XCTUnwrap(store.currentSaveID)
            defer { GameStore.deleteSave(id: saveID) }
            let player = try outgoing(store)
            let hosted = try XCTUnwrap(store.clubs[2].players.first { $0.id == player.id })
            let target = TransferTarget(player: hosted, sellingClubIndex: 2, askingPrice: 500)
            // Also models a stale market saved before the ownership fix.
            store.transferMarket = [target]
            let budget = store.userClub.transferBudget
            switch action {
            case "search": XCTAssertTrue(store.signFromSearch(clubIndex: 2, playerID: player.id).lowercased().contains("on loan"))
            case "buy": XCTAssertTrue(store.buyPlayer(target).lowercased().contains("on loan"))
            case "loan": XCTAssertTrue(store.loanIn(target).lowercased().contains("on loan"))
            default:
                guard case .rejected(let reason, _) = store.proposeBid(target, amount: 5_000) else {
                    return XCTFail("The host cannot negotiate a permanent sale")
                }
                XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
            }
            XCTAssertEqual(locations(store, player.id), [2], action)
            XCTAssertEqual(store.clubs[2].players.first { $0.id == player.id }?.onLoanFromClubIndex, store.userClubIndex, action)
            XCTAssertEqual(store.userClub.transferBudget, budget, action)
            XCTAssertTrue(store.pendingTransferDeals.isEmpty, action)
        }
    }

    func testLoaneeCannotBeIncludedAsTransferMakeweight() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let borrowed = try incoming(store)
        let candidate = try XCTUnwrap(store.clubs[2].players.first)
        let target = TransferTarget(player: candidate, sellingClubIndex: 2, askingPrice: 500)
        store.transferMarket = [target]
        guard case .rejected(let reason, _) = store.proposeBid(target, amount: 5_000, includedPlayer: borrowed) else {
            return XCTFail("A borrowed player cannot be included in a permanent swap")
        }
        XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
        XCTAssertEqual(locations(store, borrowed.id), [store.userClubIndex])
        XCTAssertTrue(store.pendingTransferDeals.isEmpty)
    }

    func testLegacyPendingDealCannotFinalizeBorrowedPlayer() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        let player = try outgoing(store)
        let index = try XCTUnwrap(store.clubs[2].players.firstIndex { $0.id == player.id })
        let hosted = store.clubs[2].players.remove(at: index)
        let deal = PendingTransferDeal(id: UUID(), player: hosted, sellingClubIndex: 2,
                                       sellingClubName: store.clubs[2].name, agreedFee: 500,
                                       sellOnPercentage: 0, buyBackFee: 0,
                                       readyDate: store.currentDate, isReady: true)
        store.pendingTransferDeals = [deal]
        let budget = store.userClub.transferBudget
        guard case .rejected(let reason, _) = store.finalizePersonalTerms(deal, wage: store.transferWageDemand(hosted) * 2,
                                                                        years: 3, signingOnFee: 50) else {
            return XCTFail("A legacy borrowed-player deal must not complete as a permanent transfer")
        }
        XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
        XCTAssertEqual(store.userClub.transferBudget, budget)
        XCTAssertEqual(store.pendingTransferDeals.map(\.id), [deal.id])
        // Withdrawal remains the recovery path and preserves the parent.
        store.withdrawPendingDeal(deal)
        XCTAssertEqual(locations(store, player.id), [2])
        XCTAssertEqual(store.clubs[2].players.first { $0.id == player.id }?.onLoanFromClubIndex, store.userClubIndex)
    }

    func testStalePlayerSnapshotCannotSubLoanOrFreeSignBorrowedPlayer() async throws {
        for action in ["subloan", "free"] {
            let store = await career()
            let saveID = try XCTUnwrap(store.currentSaveID)
            defer { GameStore.deleteSave(id: saveID) }
            let borrowed = try incoming(store)
            var stale = borrowed
            stale.onLoanFromClubIndex = nil
            switch action {
            case "subloan":
                guard case .rejected(let reason) = store.proposeLoanOut(stale, toClubIndex: 2) else {
                    return XCTFail("A stale snapshot cannot overwrite the original parent club")
                }
                XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
            default:
                guard case .rejected(let reason, _) = store.signFreeAgent(stale, fromClubIndex: store.userClubIndex,
                                                                        wage: store.freeAgentWageDemand(stale) * 2, years: 3) else {
                    return XCTFail("A stale borrowed-player snapshot cannot be signed as a free agent")
                }
                XCTAssertTrue(reason.lowercased().contains("on loan"), reason)
            }
            XCTAssertEqual(store.currentPlayer(borrowed.id)?.onLoanFromClubIndex, 1)
            XCTAssertEqual(locations(store, borrowed.id), [store.userClubIndex])
        }
    }

    func testAIClubCannotSellItsBorrowedPlayers() async throws {
        let store = await career()
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }
        // Two possible AI clubs, each with a full squad of borrowed players.
        // Any attempted transfer must find no owned player to sell.
        store.clubs = Array(store.clubs.prefix(3))
        for club in [1, 2] {
            for index in store.clubs[club].players.indices {
                store.clubs[club].players[index].onLoanFromClubIndex = store.userClubIndex
            }
        }
        let squads = store.clubs.map { $0.players.map(\.id) }
        let budgets = store.clubs.map(\.transferBudget)
        store.processAITransfer()
        XCTAssertEqual(store.clubs.map { $0.players.map(\.id) }, squads)
        XCTAssertEqual(store.clubs.map(\.transferBudget), budgets)
    }
}
