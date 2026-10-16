//
//  TransfersFixtureTests.swift
//  Retro Season ManagerTests
//
//  Verifies the DEBUG UI-test Transfers fixture against the real store:
//  the seeded shortlist must resolve through `shortlistedResults` (the
//  same path the Transfer Centre's SHORTLIST tab renders), and the
//  incoming-offer fixture must produce a live offer.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class TransfersFixtureTests: XCTestCase {
    private var isolatedRoot: URL!

    override func setUp() {
        super.setUp()
        isolatedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("TransferCompletion-\(UUID().uuidString)")
        SaveSlots.useIsolatedRootForTesting(isolatedRoot)
    }

    override func tearDown() {
        SaveSlots.useIsolatedRootForTesting(nil)
        try? FileManager.default.removeItem(at: isolatedRoot)
        super.tearDown()
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    func testTransfersFixtureShortlistResolvesThroughStoreQuery() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()

        XCTAssertEqual(store.shortlistedPlayerIDs.count, 1, "Fixture should seed exactly one shortlist entry")
        let resolved = store.shortlistedResults
        XCTAssertEqual(resolved.count, 1,
                       "The seeded shortlist entry must resolve through shortlistedResults — the SHORTLIST tab renders this exact query")
        XCTAssertEqual(store.pendingOffers.count, 1, "Fixture should seed one incoming offer")
        XCTAssertTrue(store.transferMarket.contains { $0.player.name == "Bjorn Freehold" },
                      "Fixture should give one free agent the deterministic searchable name")
    }

    func testShortlistedFreeAgentResolvesThroughStoreQuery() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()

        // Shortlist a free agent (sellingClubIndex == nil) through the real
        // toggle path. His player record lives only in the transfer market —
        // he's attached to no club — and he must still resolve on the
        // SHORTLIST tab's query.
        guard let freeAgent = store.transferMarket.first(where: { $0.sellingClubIndex == nil }) else {
            return XCTFail("Fixture market should contain at least one free agent")
        }
        XCTAssertFalse(store.clubs.contains { club in club.players.contains { $0.id == freeAgent.player.id } },
                       "Precondition: a free agent is attached to no club")
        store.toggleShortlist(freeAgent.player.id)

        let resolved = store.shortlistedResults.first { $0.player.id == freeAgent.player.id }
        XCTAssertNotNil(resolved, "A shortlisted free agent must resolve through shortlistedResults")
        XCTAssertNil(resolved?.clubIndex, "Free agents carry a nil club index — never a fabricated club slot")

        // Toggling again removes him cleanly.
        store.toggleShortlist(freeAgent.player.id)
        XCTAssertFalse(store.shortlistedResults.contains { $0.player.id == freeAgent.player.id },
                       "Removing the shortlist entry must drop the free agent again")
    }

    func testTransfersFixtureShortlistResolvesAfterReload() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()
        let saveID = store.currentSaveID
        XCTAssertNotNil(saveID, "Fixture career should have a save ID")
        guard let unwrappedSaveID = saveID else { return }

        // Simulate a relaunch: decode the save the fixture just wrote into a
        // fresh store, then re-run the fixture's ensure step exactly as the
        // app's launch path does.
        let reloaded = await Task { @MainActor in GameStore() }.value
        let loaded = reloaded.loadSavedGame(id: unwrappedSaveID)
        XCTAssertTrue(loaded, "The fixture's save should reload")
        reloaded.ensureTransfersFixtureStateForDebug()

        XCTAssertEqual(reloaded.shortlistedPlayerIDs.count, 1)
        XCTAssertEqual(reloaded.shortlistedResults.count, 1,
                       "After a simulated relaunch + ensure, the shortlist must still resolve")
    }

    func testNegotiationFixtureTargetIsDeterministicallyAccepted() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()

        guard let target = store.transferMarket.first(where: { $0.player.name == "Marcus Bidwell" }) else {
            return XCTFail("Fixture should seed the deterministic negotiation target (Marcus Bidwell)")
        }
        XCTAssertNotNil(target.sellingClubIndex, "The negotiation target must be club-listed")

        // The bid sheet's opening offer is 0.85 × asking — already above
        // the flexible seller's 0.8 accept threshold, so the FIRST offer
        // must be accepted. The result is a pending deal, not a completed
        // transfer: the player leaves the seller and the market, but the
        // budget is untouched until personal terms succeed.
        let budgetBefore = store.userClub.transferBudget
        let sellerIndex = target.sellingClubIndex!
        let outcome = store.proposeBid(target, amount: Int(Double(target.askingPrice) * 0.85))

        guard case .accepted(let message) = outcome else {
            return XCTFail("Opening offer to a flexible seller must be accepted, got: \(outcome)")
        }
        XCTAssertTrue(message.contains("Fee of"), "Acceptance should announce the agreed fee")
        XCTAssertEqual(store.pendingTransferDeals.count, 1, "Acceptance creates exactly one pending deal")
        XCTAssertFalse(store.transferMarket.contains { $0.player.id == target.player.id }, "The target leaves the market")
        XCTAssertFalse(store.clubs[sellerIndex].players.contains { $0.id == target.player.id },
                       "The player leaves the selling club")
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore,
                       "Fee acceptance must NOT deduct the budget — money moves only at personal terms")

        // Personal terms are not ready yet (medical clock, 1–3 days).
        let deal = store.pendingTransferDeals[0]
        XCTAssertFalse(deal.isReady, "A fresh deal must still be in medical/paperwork")
        guard case .rejected = store.finalizePersonalTerms(deal, wage: store.transferWageDemand(deal.player), years: 3) else {
            return XCTFail("finalizePersonalTerms must refuse a deal that isn't ready — no early completion path")
        }
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore, "Still no deduction")
        XCTAssertEqual(store.pendingTransferDeals.count, 1, "The deal survives the premature attempt")

        // Run the medical clock through the authoritative daily check:
        // move the calendar past the deal's readyDate exactly as a normal
        // day advance would, then let checkPendingTransferDeals() mark it.
        store.currentDate = Calendar.current.date(byAdding: .day, value: 4, to: deal.readyDate) ?? deal.readyDate
        store.checkPendingTransferDeals()
        XCTAssertTrue(store.pendingTransferDeals[0].isReady, "The deal must be ready after the medical window")

        // Settle terms at exactly the demand — acceptance is probabilistic,
        // so accept EITHER outcome but assert the invariants that hold for
        // both: at most one deduction, at most one completion, no dupes.
        let result = store.finalizePersonalTerms(store.pendingTransferDeals[0],
                                                 wage: store.transferWageDemand(deal.player), years: 3)
        switch result {
        case .accepted:
            XCTAssertEqual(store.pendingTransferDeals.count, 0, "A completed deal is removed exactly once")
            XCTAssertEqual(store.userClub.transferBudget, budgetBefore - deal.agreedFee,
                           "Exactly one deduction of the agreed fee")
            XCTAssertEqual(store.userClub.players.filter { $0.id == deal.player.id }.count, 1,
                           "The signed player appears exactly once in the squad")
            XCTAssertFalse(store.clubs[deal.sellingClubIndex].players.contains { $0.id == deal.player.id },
                           "The seller no longer holds the player")
        case .rejected:
            XCTAssertEqual(store.pendingTransferDeals.count, 1, "A terms rejection leaves the deal open to retry")
            XCTAssertEqual(store.userClub.transferBudget, budgetBefore, "A rejection deducts nothing")
            XCTAssertEqual(store.userClub.players.filter { $0.id == deal.player.id }.count, 0,
                           "No player is duplicated on a rejection")
        }
    }

    /// A fee agreed on deadline day has a 1–3 day medical clock, so its
    /// personal terms can fall due after the window has shut. Completing it
    /// then would sign a player outside the window.
    func testPersonalTermsCannotCompleteAfterTransferWindowCloses() async throws {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()
        guard let target = store.transferMarket.first(where: { $0.player.name == "Marcus Bidwell" }) else {
            return XCTFail("Fixture should seed the negotiation target")
        }
        guard case .accepted = store.proposeBid(target, amount: Int(Double(target.askingPrice) * 0.85)) else {
            return XCTFail("Opening offer to the flexible seller must be accepted")
        }
        let budgetBefore = store.userClub.transferBudget
        let deal = store.pendingTransferDeals[0]

        // Run the clock past the deadline and past the medical window.
        let dayAfterDeadline = Calendar.current.date(byAdding: .day, value: 1, to: store.transferDeadlineDate)
            ?? store.transferDeadlineDate
        store.currentDate = max(dayAfterDeadline, deal.readyDate)
        store.checkPendingTransferDeals()
        XCTAssertFalse(store.transferWindowOpen, "Precondition: the clock has run past the transfer deadline")
        XCTAssertTrue(store.pendingTransferDeals[0].isReady)

        let clubsBefore = try encoded(store.clubs)
        let ledgerBefore = try encoded(store.seasonLedger)
        guard case .rejected(let reason, _) = store.finalizePersonalTerms(store.pendingTransferDeals[0],
                                                           wage: store.transferWageDemand(deal.player), years: 3) else {
            return XCTFail("Personal terms must not complete a signing once the transfer window is closed")
        }
        XCTAssertTrue(reason.contains("transfer window has closed"), reason)
        XCTAssertEqual(try encoded(store.clubs), clubsBefore, "Neither club's money or players may change")
        XCTAssertEqual(try encoded(store.seasonLedger), ledgerBefore, "A rejected deal must not book money")
        XCTAssertEqual(store.pendingTransferDeals.count, 1, "The deal stays open for withdrawal")
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore, "Nothing is paid for an out-of-window signing")
        XCTAssertFalse(store.userClub.players.contains { $0.id == deal.player.id })
        XCTAssertTrue(store.persist())
        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertEqual(reloaded.pendingTransferDeals.map(\.id), [deal.id])
        _ = reloaded.withdrawPendingDeal(reloaded.pendingTransferDeals[0])
        XCTAssertTrue(reloaded.pendingTransferDeals.isEmpty)
        XCTAssertEqual(reloaded.clubs[deal.sellingClubIndex].players.filter { $0.id == deal.player.id }.count, 1)
        XCTAssertEqual(reloaded.userClub.transferBudget, budgetBefore)
        XCTAssertEqual(try encoded(reloaded.seasonLedger), ledgerBefore)
        _ = reloaded.withdrawPendingDeal(deal)
        XCTAssertEqual(reloaded.clubs.flatMap(\.players).filter { $0.id == deal.player.id }.count, 1)
    }

    /// A makeweight can be sold or otherwise leave the squad between the bid
    /// and personal terms. Completing the deal then would quietly drop the
    /// makeweight the seller was promised, so the deal must be refused.
    func testMakeweightGoneBeforePersonalTermsBlocksCompletion() async throws {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()
        guard let target = store.transferMarket.first(where: { $0.player.name == "Marcus Bidwell" }) else {
            return XCTFail("Fixture should seed the negotiation target")
        }
        guard let makeweight = store.userClub.players.first(where: { !$0.isOnLoan }) else {
            return XCTFail("Fixture club should have a non-loan player to offer as a makeweight")
        }
        guard case .accepted = store.proposeBid(target, amount: Int(Double(target.askingPrice) * 0.85),
                                                includedPlayer: makeweight) else {
            return XCTFail("Opening offer with a makeweight to the flexible seller must be accepted")
        }
        let deal = store.pendingTransferDeals[0]
        let budgetBefore = store.userClub.transferBudget

        // The makeweight leaves the squad before terms are settled.
        let destination = try XCTUnwrap(store.clubs.indices.first {
            $0 != store.userClubIndex && $0 != deal.sellingClubIndex
        })
        store.clubs[store.userClubIndex].players.removeAll { $0.id == makeweight.id }
        store.clubs[destination].players.append(makeweight)
        store.currentDate = deal.readyDate
        store.checkPendingTransferDeals()

        let clubsBefore = try encoded(store.clubs)
        let ledgerBefore = try encoded(store.seasonLedger)
        guard case .rejected(let reason, _) = store.finalizePersonalTerms(store.pendingTransferDeals[0],
                                                           wage: store.transferWageDemand(deal.player), years: 3) else {
            return XCTFail("A deal whose agreed makeweight has left the squad must not complete silently")
        }
        XCTAssertTrue(reason.contains("is no longer at"), reason)
        XCTAssertEqual(try encoded(store.clubs), clubsBefore, "Neither club's money or players may change")
        XCTAssertEqual(try encoded(store.seasonLedger), ledgerBefore, "A rejected deal must not book money")
        XCTAssertEqual(store.pendingTransferDeals.count, 1, "The deal stays open so the user can withdraw it")
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore, "No fee is paid on the refused deal")
        XCTAssertFalse(store.userClub.players.contains { $0.id == deal.player.id })
        XCTAssertTrue(store.persist())
        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertEqual(reloaded.pendingTransferDeals.map(\.id), [deal.id])
        _ = reloaded.withdrawPendingDeal(reloaded.pendingTransferDeals[0])
        XCTAssertTrue(reloaded.pendingTransferDeals.isEmpty)
        XCTAssertEqual(reloaded.clubs[deal.sellingClubIndex].players.filter { $0.id == deal.player.id }.count, 1)
        XCTAssertEqual(reloaded.userClub.transferBudget, budgetBefore)
        XCTAssertEqual(try encoded(reloaded.seasonLedger), ledgerBefore)
        _ = reloaded.withdrawPendingDeal(deal)
        XCTAssertEqual(reloaded.clubs.flatMap(\.players).filter { $0.id == deal.player.id }.count, 1)
    }

    func testIncomingSaleAndAcceptedCounterCannotCompleteAfterWindowCloses() async throws {
        for counter in [false, true] {
            let store = await Task { @MainActor in GameStore() }.value
            store.prepareCareerTransfersFixtureForDebug()
            let player = try XCTUnwrap(store.userClub.players.first { candidate in
                !candidate.isOnLoan && store.userClub.players.filter { $0.position == candidate.position }.count
                    > (candidate.position == .goalkeeper ? 2 : 3)
            })
            let buyer = try XCTUnwrap(store.clubs.indices.first { $0 != store.userClubIndex })
            store.clubs[buyer].transferBudget = 100_000
            store.currentDate = try XCTUnwrap(GameStore.calendar.date(byAdding: .day, value: 1, to: store.transferDeadlineDate))
            let offer = TransferOffer(playerID: player.id, playerName: player.name, fromClubIndex: buyer,
                amount: 1, expiryDate: try XCTUnwrap(GameStore.calendar.date(byAdding: .day, value: 6, to: store.currentDate)))
            store.pendingOffers = [offer]
            let clubsBefore = try encoded(store.clubs)
            let ledgerBefore = try encoded(store.seasonLedger)
            let message: String
            if counter {
                guard case .rejected(let reason, _) = store.counterSellOffer(offer, askingAmount: 1) else {
                    XCTFail("An accepted counter must not complete a sale outside the window")
                    continue
                }
                message = reason
            } else {
                message = store.acceptOffer(offer)
            }
            XCTAssertTrue(message.contains("transfer window is closed"), message)
            XCTAssertEqual(try encoded(store.clubs), clubsBefore)
            XCTAssertEqual(try encoded(store.seasonLedger), ledgerBefore)
            XCTAssertEqual(store.pendingOffers.map(\.id), [offer.id])
        }
    }

    /// An AI club's bid was checked for affordability when it was generated,
    /// but its budget can fall before the user accepts. Accepting must not
    /// pay the user a fee the buyer cannot cover.
    func testOfferCannotCompleteWhenBuyerCannotAffordIt() async throws {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerTransfersFixtureForDebug()
        let candidates = store.userClub.players.filter { !$0.isOnLoan }
        guard let player = candidates.first(where: { candidate in
            store.userClub.players.filter { $0.position == candidate.position }.count
                > (candidate.position == .goalkeeper ? 2 : 3)
        }), store.userClub.players.count > 15 else {
            return XCTFail("Fixture squad should have a player who can be sold")
        }
        guard let buyerIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex && store.clubs[$0].divisionTier < 4 }) else {
            return XCTFail("Fixture should include a rival club")
        }
        store.clubs[buyerIndex].transferBudget = 0
        let offer = TransferOffer(playerID: player.id, playerName: player.name, fromClubIndex: buyerIndex,
                                  amount: 5_000,
                                  expiryDate: Calendar.current.date(byAdding: .day, value: 6, to: store.currentDate) ?? store.currentDate)
        store.pendingOffers = [offer]
        let budgetBefore = store.userClub.transferBudget

        let clubsBefore = try encoded(store.clubs)
        let ledgerBefore = try encoded(store.seasonLedger)
        let message = store.acceptOffer(offer)
        XCTAssertTrue(message.contains("can no longer afford"), message)
        XCTAssertEqual(try encoded(store.clubs), clubsBefore)
        XCTAssertEqual(try encoded(store.seasonLedger), ledgerBefore)
        XCTAssertEqual(store.pendingOffers.map(\.id), [offer.id])

        XCTAssertFalse(message.hasPrefix("Sold"), "A buyer who cannot afford the bid must not complete the sale: \(message)")
        XCTAssertTrue(store.userClub.players.contains { $0.id == player.id }, "The player stays with the user")
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore, "No money is created for the user")
    }
}
