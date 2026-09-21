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
}
