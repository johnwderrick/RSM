//
//  ContractSheetsTests.swift
//  Retro Season Manager
//
//  Focused store-level coverage behind the redesigned contract and
//  confirmation sheets: the deterministic sheets fixture, the validation
//  the sheets must surface (budget guards), exact-once financial effects,
//  cancel-changes-nothing guarantees, and duplicate-submission safety.
//
//  Note on determinism: the negotiation acceptance rolls are clamped to
//  [0.03, 0.97] — never fully certain — so acceptance-path tests offer
//  far above demand (chance ≈ 0.97) and retry a bounded number of times;
//  each retry only nudges morale, and the assertions cover the
//  exactly-once effects the sheets must guarantee.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class ContractSheetsTests: XCTestCase {

    // MARK: - Career nationality regression

    func testKnownCareerStarsUseTheirAuthoritativeNationalities() {
        // The full catalogue lives in PlayerNationalityTests; here we pin
        // the seven headline stars the contract sheets surface.
        let expected = [
            "Cristiano Renaldo": "Portugal",
            "Lionel Mesi": "Argentina",
            "Gareth Baile": "Wales",
            "Eden Hazzard": "Belgium",
            "Neymar Souza": "Brazil",
            "Kylian Mbape": "France",
            "Robert Lewandowsky": "Poland",
        ]
        for (name, nationality) in expected {
            XCTAssertEqual(GameStore.knownPlayerNationalities[name], nationality, name)
            let player = GameStore.makePlayer(name: name, position: .forward,
                                              age: 26, rating: 90)
            XCTAssertEqual(player.nationality, nationality, name)
        }
    }

    func testKnownNationalityRepairPreservesIdentityAndUnknownPlayers() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Nationality Tester")
        var known = GameStore.makePlayer(name: "Cristiano Renaldo", position: .forward,
                                         age: 26, rating: 94)
        known.nationality = "England"
        let knownID = known.id
        store.clubs[0].players[0] = known
        let unknownID = store.clubs[0].players[1].id
        store.clubs[0].players[1].nationality = "Japan"

        XCTAssertTrue(store.repairKnownPlayerNationalities())
        XCTAssertEqual(store.clubs[0].players[0].id, knownID)
        XCTAssertEqual(store.clubs[0].players[0].nationality, "Portugal")
        XCTAssertEqual(store.clubs[0].players[1].id, unknownID)
        XCTAssertEqual(store.clubs[0].players[1].nationality, "Japan")
        XCTAssertFalse(store.repairKnownPlayerNationalities(),
                       "The exact-name repair must be idempotent")
    }

    func testDecoderMarksOnlyMissingNationalityForMigration() throws {
        var player = GameStore.makePlayer(name: "Saved English Player", position: .defender,
                                          age: 25, rating: 70)
        player.nationality = "England"
        let completeData = try JSONEncoder().encode(player)
        let complete = try JSONDecoder().decode(Player.self, from: completeData)
        XCTAssertEqual(complete.nationality, "England")
        XCTAssertFalse(complete.nationalityNeedsMigration,
                       "A nationality genuinely saved as England must be preserved")

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: completeData) as? [String: Any])
        legacyObject.removeValue(forKey: "nationality")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(Player.self, from: legacyData)
        XCTAssertTrue(legacy.nationalityNeedsMigration,
                      "Only an absent legacy field should be eligible for repair")
    }

    func testMissingLegacyNationalityIsFilledButSavedEnglandIsPreserved() async throws {
        var source = GameStore.makePlayer(name: "Legacy Fictional Player", position: .midfielder,
                                          age: 24, rating: 68)
        source.nationality = "England"
        let encoded = try JSONEncoder().encode(source)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "nationality")
        let legacy = try JSONDecoder().decode(
            Player.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Migration Tester")
        store.clubs[0].players[0] = legacy
        var savedEnglish = GameStore.makePlayer(name: "Saved English Player", position: .defender,
                                                age: 25, rating: 70)
        savedEnglish.nationality = "England"
        store.clubs[0].players[1] = savedEnglish
        store.transferMarket = [
            TransferTarget(player: legacy, sellingClubIndex: 0, askingPrice: 1_000),
        ]

        XCTAssertTrue(store.repairKnownPlayerNationalities())
        XCTAssertFalse(store.clubs[0].players[0].nationalityNeedsMigration)
        // The migrated nationality comes from the random pool (or England).
        XCTAssertTrue(GameStore.nationalityPool.contains(store.clubs[0].players[0].nationality)
                      || store.clubs[0].players[0].nationality == "England")
        XCTAssertEqual(store.transferMarket[0].player.nationality,
                       store.clubs[0].players[0].nationality,
                       "Copies of the same player must receive the same repaired nationality")
        XCTAssertEqual(store.clubs[0].players[1].nationality, "England",
                       "A nationality that existed in the save must remain untouched")
    }

    /// A fresh store with the deterministic sheets fixture loaded.
    private func freshFixture() async -> GameStore {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerSheetsFixtureForDebug()
        return store
    }

    // MARK: - Fixture shape

    func testSheetsFixtureProvidesAllSheetStates() async {
        let store = await freshFixture()

        // Danny Draper: the renewal candidate, with real wage headroom.
        let draper = store.userClub.players.first { $0.name == "Danny Draper" }
        XCTAssertNotNil(draper)
        XCTAssertEqual(draper?.contractYears, 1)
        XCTAssertEqual(draper?.wage, 900)
        if let draper {
            let demand = store.renewalDemand(draper)
            let projectedBill = store.userClub.wageBill - draper.wage + demand
            XCTAssertLessThanOrEqual(projectedBill, store.userClub.wageBudget,
                                     "A demand-level renewal must fit the wage budget deterministically")
        }

        // Sammy Stalwart: releasable (unsettled veteran), severance affordable.
        let stalwart = store.userClub.players.first { $0.name == "Sammy Stalwart" }
        XCTAssertNotNil(stalwart)
        if let stalwart {
            XCTAssertTrue(store.canTerminateContract(stalwart))
            let severance = max(50, stalwart.wage * 4)
            XCTAssertGreaterThanOrEqual(store.userClub.transferBudget, severance,
                                        "Severance must be affordable in the fixture")
        }

        // Ivan Ongo: a pending deal created through the real bid path.
        let ongo = store.pendingTransferDeals.first { $0.player.name == "Ivan Ongo" }
        if ongo == nil {
            let market = store.transferMarket
            let named = market.first { $0.player.name == "Ivan Ongo" }
            XCTFail("DIAG market=\(market.count) ivanInMarket=\(named != nil) " +
                    "ivanSelling=\(named?.sellingClubIndex.map(String.init) ?? "nil") " +
                    "stances=\(store.clubNegotiationStances.count) " +
                    "windowOpen=\(store.transferWindowOpen) " +
                    "squad=\(store.userClub.players.count) " +
                    "budget=\(store.userClub.transferBudget) " +
                    "pending=\(store.pendingTransferDeals.count)")
            return
        }
        XCTAssertNotNil(ongo, "The fixture must create a pending deal through the real bid path")
    }

    // MARK: - Renewal: validation the sheet must surface

    func testRenewalRejectsWhenWageBreaksWageBudget() async {
        let store = await freshFixture()
        guard let draper = store.userClub.players.first(where: { $0.name == "Danny Draper" }) else {
            return XCTFail("Fixture must contain Danny Draper")
        }
        let budgetBefore = store.userClub.transferBudget
        let yearsBefore = draper.contractYears
        let wageBefore = draper.wage

        // A wage so large the projected bill must break the wage budget.
        let outcome = store.proposeRenewal(draper, wage: 5_000, years: 3, releaseClause: nil, signingOnFee: 0)
        guard case .rejected(let reason, _) = outcome else {
            return XCTFail("A wage that breaks the wage budget must be rejected")
        }
        XCTAssertTrue(reason.contains("wage budget"), "Reason should name the wage budget: \(reason)")

        // A rejected offer changes nothing financial or contractual.
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore)
        let unchanged = store.userClub.players.first { $0.id == draper.id }
        XCTAssertEqual(unchanged?.contractYears, yearsBefore)
        XCTAssertEqual(unchanged?.wage, wageBefore)
    }

    func testRenewalRejectsWhenSigningOnFeeExceedsTransferBudget() async {
        let store = await freshFixture()
        guard let draper = store.userClub.players.first(where: { $0.name == "Danny Draper" }) else {
            return XCTFail("Fixture must contain Danny Draper")
        }
        let demand = store.renewalDemand(draper)
        let budgetBefore = store.userClub.transferBudget

        let outcome = store.proposeRenewal(draper, wage: demand, years: 3,
                                           releaseClause: nil, signingOnFee: budgetBefore + 1)
        guard case .rejected(let reason, _) = outcome else {
            return XCTFail("An over-budget signing-on fee must be rejected")
        }
        XCTAssertTrue(reason.contains("transfer budget"), "Reason should name the transfer budget: \(reason)")
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore,
                       "A rejected offer must not touch the budget")
    }

    // MARK: - Renewal: exact-once effects on acceptance

    func testAcceptedRenewalAppliesTermsExactlyOnce() async {
        let store = await freshFixture()
        guard var draper = store.userClub.players.first(where: { $0.name == "Danny Draper" }) else {
            return XCTFail("Fixture must contain Danny Draper")
        }
        let squadBefore = store.userClub.players.count
        let budgetBefore = store.userClub.transferBudget
        let demand = store.renewalDemand(draper)

        // Offer double the demand: acceptance chance is clamped at 0.97,
        // so a bounded retry makes acceptance all but certain.
        var outcome = store.proposeRenewal(draper, wage: demand * 2, years: 3, releaseClause: nil, signingOnFee: 0)
        var attempts = 1
        while case .rejected = outcome, attempts < 50 {
            outcome = store.proposeRenewal(draper, wage: demand * 2, years: 3, releaseClause: nil, signingOnFee: 0)
            attempts += 1
        }
        guard case .accepted = outcome else {
            return XCTFail("A double-demand renewal did not land within 50 attempts")
        }

        // The squad player was updated in place — new terms exactly once,
        // no duplicated player entry, no fee deducted (none was offered).
        draper = store.userClub.players.first { $0.name == "Danny Draper" }!
        XCTAssertEqual(draper.contractYears, 3)
        XCTAssertEqual(draper.wage, demand * 2)
        XCTAssertEqual(store.userClub.players.filter { $0.name == "Danny Draper" }.count, 1)
        XCTAssertEqual(store.userClub.players.count, squadBefore)
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore)
    }

    func testRenewalWithSigningOnFeeDeductsExactlyOnce() async {
        let store = await freshFixture()
        guard let draper = store.userClub.players.first(where: { $0.name == "Danny Draper" }) else {
            return XCTFail("Fixture must contain Danny Draper")
        }
        let demand = store.renewalDemand(draper)
        let fee = 50
        let budgetBefore = store.userClub.transferBudget
        let ledgerBefore = store.seasonLedger.reduce(0) { $0 + $1.amount }

        var outcome = store.proposeRenewal(draper, wage: demand * 2, years: 2, releaseClause: nil, signingOnFee: fee)
        var attempts = 1
        while case .rejected = outcome, attempts < 50 {
            outcome = store.proposeRenewal(draper, wage: demand * 2, years: 2, releaseClause: nil, signingOnFee: fee)
            attempts += 1
        }
        guard case .accepted = outcome else {
            return XCTFail("A double-demand renewal did not land within 50 attempts")
        }
        // Rejected attempts never deduct; the single acceptance deducts
        // the signing-on fee exactly once.
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore - fee)
        XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledgerBefore, -fee,
                       "The finance ledger must include the entire accepted signing-on fee")
    }

    // MARK: - Release: exact-once, validation

    func testReleaseConfirmationAppliesSeveranceExactlyOnce() async {
        let store = await freshFixture()
        guard let stalwart = store.userClub.players.first(where: { $0.name == "Sammy Stalwart" }) else {
            return XCTFail("Fixture must contain Sammy Stalwart")
        }
        let squadBefore = store.userClub.players.count
        let budgetBefore = store.userClub.transferBudget
        let expectedSeverance = max(50, stalwart.wage * 4)

        let message = store.terminateContract(stalwart)
        XCTAssertTrue(message.contains("released"), "Unexpected result: \(message)")

        // Exactly one player removed, exactly one severance deducted.
        XCTAssertEqual(store.userClub.players.count, squadBefore - 1)
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore - expectedSeverance)
        XCTAssertFalse(store.userClub.players.contains { $0.id == stalwart.id })
        XCTAssertEqual(store.transferHistory.filter { $0.playerName == "Sammy Stalwart" && $0.action == "Released" }.count, 1,
                       "The release must be recorded in transfer history exactly once")
    }

    func testReleaseRefusesBelowSquadMinimum() async {
        let store = await freshFixture()
        guard let stalwart = store.userClub.players.first(where: { $0.name == "Sammy Stalwart" }) else {
            return XCTFail("Fixture must contain Sammy Stalwart")
        }
        // Shrink the squad to the guard's threshold: with 15 or fewer
        // players the release must refuse and change nothing.
        store.clubs[store.userClubIndex].players.removeAll { $0.id != stalwart.id }
        let budgetBefore = store.userClub.transferBudget

        let message = store.terminateContract(stalwart)
        XCTAssertTrue(message.contains("at least 16"), "Unexpected result: \(message)")
        XCTAssertEqual(store.userClub.players.count, 1,
                       "A refused release must not change the squad")
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore,
                       "A refused release must not deduct severance")
    }

    func testReleaseRefusesForContentPlayer() async {
        let store = await freshFixture()
        // A happy, non-veteran player cannot be released at all.
        guard let content = store.userClub.players.first(where: { !$0.wantsToLeave && $0.age < 33 }) else {
            return XCTFail("The fixture squad should contain a content, non-veteran player")
        }
        let squadBefore = store.userClub.players.count
        let budgetBefore = store.userClub.transferBudget

        let message = store.terminateContract(content)
        XCTAssertTrue(message.contains("no interest in leaving"), "Unexpected result: \(message)")
        XCTAssertEqual(store.userClub.players.count, squadBefore)
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore)
    }

    // MARK: - Withdrawal: exact-once, cancel-safe

    func testWithdrawalReturnsPlayerAndRemovesDealExactlyOnce() async {
        let store = await freshFixture()
        guard let deal = store.pendingTransferDeals.first(where: { $0.player.name == "Ivan Ongo" }) else {
            return XCTFail("Fixture must contain the Ivan Ongo pending deal")
        }
        let dealsBefore = store.pendingTransferDeals.count

        let message = store.withdrawPendingDeal(deal)
        XCTAssertTrue(message.contains("broken off"), "Unexpected result: \(message)")
        XCTAssertEqual(store.pendingTransferDeals.count, dealsBefore - 1)

        // The player returned to the selling club exactly once.
        let seller = store.clubs[deal.sellingClubIndex]
        XCTAssertEqual(seller.players.filter { $0.id == deal.player.id }.count, 1,
                       "The returned player must appear exactly once at the selling club")

        // Withdrawing again is a safe no-op.
        let secondMessage = store.withdrawPendingDeal(deal)
        XCTAssertTrue(secondMessage.contains("no longer on the table"))
        XCTAssertEqual(store.pendingTransferDeals.count, dealsBefore - 1)
        XCTAssertEqual(seller.players.filter { $0.id == deal.player.id }.count, 1,
                       "A repeated withdrawal must not duplicate the player")
    }

    /// Cancel-safety: dismissing the confirmation sheet must not call the
    /// store at all, so the pending deal, budgets and squad are untouched.
    /// This pins the state the UI test's cancel leg compares against.
    func testCancelLeavesAllPendingStateIntact() async {
        let store = await freshFixture()
        let dealsBefore = store.pendingTransferDeals
        let budgetBefore = store.userClub.transferBudget
        let squadBefore = store.userClub.players.map(\.id)

        // (No store call — exactly what the sheet's Cancel does.)
        XCTAssertEqual(store.pendingTransferDeals.map(\.id), dealsBefore.map(\.id))
        XCTAssertEqual(store.userClub.transferBudget, budgetBefore)
        XCTAssertEqual(store.userClub.players.map(\.id), squadBefore)
    }

    // MARK: - Free agent signing validation

    func testFreeAgentWageAboveBudgetRejectedDeterministically() async {
        let store = await freshFixture()
        guard let sellerIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex && !store.clubs[$0].players.isEmpty }),
              var candidate = store.clubs[sellerIndex].players.first else {
            return XCTFail("The fixture must contain another club with players")
        }
        candidate.contractYears = 0
        store.clubs[sellerIndex].players[0].contractYears = 0
        let squadBefore = store.userClub.players.count

        // A wage equal to the whole wage budget must break it.
        let outcome = store.signFreeAgent(candidate, fromClubIndex: sellerIndex,
                                          wage: store.userClub.wageBudget, years: 3, signingOnFee: 0)
        guard case .rejected(let reason, _) = outcome else {
            return XCTFail("A wage that breaks the wage budget must be rejected")
        }
        XCTAssertTrue(reason.contains("wage budget"), "Reason should name the wage budget: \(reason)")
        XCTAssertEqual(store.userClub.players.count, squadBefore)
        // The candidate stays at the selling club.
        XCTAssertEqual(store.clubs[sellerIndex].players.filter { $0.id == candidate.id }.count, 1)
    }

    func testFreeAgentSigningAppliesTermsExactlyOnce() async {
        let store = await freshFixture()
        guard let sellerIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex && !store.clubs[$0].players.isEmpty }),
              var candidate = store.clubs[sellerIndex].players.first else {
            return XCTFail("The fixture must contain another club with players")
        }
        candidate.contractYears = 0
        store.clubs[sellerIndex].players[0].contractYears = 0
        // Make acceptance near-certain: double the demand.
        let demand = store.freeAgentWageDemand(candidate)
        let squadBefore = store.userClub.players.count
        let sellerCountBefore = store.clubs[sellerIndex].players.count

        var outcome = store.signFreeAgent(candidate, fromClubIndex: sellerIndex,
                                          wage: demand * 2, years: 3, signingOnFee: 0)
        var attempts = 1
        while case .rejected = outcome, attempts < 50 {
            outcome = store.signFreeAgent(candidate, fromClubIndex: sellerIndex,
                                          wage: demand * 2, years: 3, signingOnFee: 0)
            attempts += 1
        }
        guard case .accepted = outcome else {
            return XCTFail("A double-demand free-agent offer did not land within 50 attempts")
        }

        candidate = store.userClub.players.first { $0.id == candidate.id }!
        XCTAssertEqual(candidate.wage, demand * 2)
        XCTAssertEqual(candidate.contractYears, 3)
        XCTAssertEqual(store.userClub.players.count, squadBefore + 1,
                       "The signed player joins the squad exactly once")
        XCTAssertEqual(store.clubs[sellerIndex].players.count, sellerCountBefore - 1,
                       "The selling club loses the player exactly once")
    }

    // MARK: - Finance audit: ledger reconciliation and rejected spending

    func testFreeAgentSigningFeeReconcilesWithLedger() async {
        let store = await freshFixture()
        guard let seller = store.clubs.indices.first(where: { $0 != store.userClubIndex && !store.clubs[$0].players.isEmpty }),
              var player = store.clubs[seller].players.first else {
            return XCTFail("Fixture must contain a free-agent candidate")
        }
        player.contractYears = 0
        store.clubs[seller].players[0].contractYears = 0
        let budgetBefore = store.userClub.transferBudget
        let ledgerBefore = store.seasonLedger.reduce(0) { $0 + $1.amount }
        let fee = 50
        let wage = store.freeAgentWageDemand(player) * 2
        for _ in 0..<50 {
            if case .accepted = store.signFreeAgent(player, fromClubIndex: seller, wage: wage, years: 3, signingOnFee: fee) {
                XCTAssertEqual(store.userClub.transferBudget, budgetBefore - fee)
                XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledgerBefore, -fee)
                XCTAssertEqual(store.seasonLedger.first?.category, "Signing-on fee")
                XCTAssertTrue(store.seasonLedger.first?.detail.contains(player.name) == true)
                return
            }
            XCTAssertEqual(store.userClub.transferBudget, budgetBefore, "A rejected negotiation must not spend money")
            XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount }, ledgerBefore)
        }
        XCTFail("Free-agent signing did not land within 50 attempts")
    }

    func testPersonalTermsFeesReconcileAndRepeatedSubmissionCannotSpendAgain() async {
        let store = await freshFixture()
        store.fastForwardPendingDealReadinessForDebug()
        guard let deal = store.pendingTransferDeals.first(where: { $0.player.name == "Ivan Ongo" && $0.isReady }) else {
            return XCTFail("Fixture must contain a ready Ivan Ongo deal")
        }
        let budgetBefore = store.userClub.transferBudget
        let sellerBudgetBefore = store.clubs[deal.sellingClubIndex].transferBudget
        let ledgerBefore = store.seasonLedger.reduce(0) { $0 + $1.amount }
        let fee = 50
        let wage = store.transferWageDemand(deal.player) * 2
        for _ in 0..<50 {
            if case .accepted = store.finalizePersonalTerms(deal, wage: wage, years: 3, signingOnFee: fee) {
                XCTAssertEqual(store.userClub.transferBudget, budgetBefore - deal.agreedFee - fee)
                XCTAssertEqual(store.clubs[deal.sellingClubIndex].transferBudget, sellerBudgetBefore + deal.agreedFee,
                               "The player bonus belongs in spending, not in the seller's transfer proceeds")
                XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledgerBefore, -deal.agreedFee - fee)
                XCTAssertEqual(store.seasonLedger.filter { $0.category == "Signing-on fee" }.count, 1)
                let entries = store.seasonLedger.map(\.id)
                let budget = store.userClub.transferBudget
                guard case .rejected = store.finalizePersonalTerms(deal, wage: wage, years: 3, signingOnFee: fee) else {
                    return XCTFail("A completed deal must reject repeated submission")
                }
                XCTAssertEqual(store.userClub.transferBudget, budget)
                XCTAssertEqual(store.seasonLedger.map(\.id), entries)
                return
            }
            XCTAssertEqual(store.userClub.transferBudget, budgetBefore)
            XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount }, ledgerBefore)
        }
        XCTFail("Personal terms did not land within 50 attempts")
    }

    func testLoanInRejectsWageOverBudgetWithoutMovingPlayerOrMoney() async {
        let store = await freshFixture()
        guard let target = store.transferMarket.first(where: { target in
            guard let seller = target.sellingClubIndex else { return false }
            return target.player.wage > 0 && store.clubs[seller].players.contains { $0.id == target.player.id }
        }), let seller = target.sellingClubIndex else {
            return XCTFail("Fixture must contain an available loan target")
        }
        store.clubs[store.userClubIndex].wageBudget = store.userClub.wageBill + target.player.wage - 1
        let budget = store.userClub.transferBudget
        let wages = store.userClub.wageBill
        let players = store.userClub.players.map(\.id)
        let sellerPlayers = store.clubs[seller].players.map(\.id)
        let market = store.transferMarket.map(\.id)
        let ledger = store.seasonLedger.map(\.id)
        let result = store.loanIn(target)
        XCTAssertTrue(result.contains("Wage budget"), result)
        XCTAssertEqual(store.userClub.wageBill, wages)
        XCTAssertEqual(store.userClub.players.map(\.id), players)
        XCTAssertEqual(store.clubs[seller].players.map(\.id), sellerPlayers)
        XCTAssertEqual(store.transferMarket.map(\.id), market)
        XCTAssertEqual(store.userClub.transferBudget, budget)
        XCTAssertEqual(store.seasonLedger.map(\.id), ledger)
    }

    func testLoanInAtExactWageHeadroomSucceedsWithoutTransferFee() async {
        let store = await freshFixture()
        guard let target = store.transferMarket.first(where: { target in
            guard let seller = target.sellingClubIndex else { return false }
            return target.player.wage > 0 && store.clubs[seller].players.contains { $0.id == target.player.id }
        }) else { return XCTFail("Fixture must contain an available loan target") }
        store.clubs[store.userClubIndex].wageBudget = store.userClub.wageBill + target.player.wage
        let budget = store.userClub.transferBudget
        let ledger = store.seasonLedger.map(\.id)
        XCTAssertTrue(store.loanIn(target).contains("Loaned"))
        XCTAssertEqual(store.userClub.wageBill, store.userClub.wageBudget)
        XCTAssertEqual(store.userClub.players.filter { $0.id == target.player.id }.count, 1)
        XCTAssertEqual(store.userClub.transferBudget, budget)
        XCTAssertEqual(store.seasonLedger.map(\.id), ledger)
        let players = store.userClub.players.map(\.id)
        XCTAssertTrue(store.loanIn(target).contains("no longer available"))
        XCTAssertEqual(store.userClub.players.map(\.id), players)
        XCTAssertEqual(store.userClub.transferBudget, budget)
    }

    func testLoanFeeReconcilesAndRepeatedSubmissionCannotCollectAgain() async {
        let store = await freshFixture()
        guard let player = store.userClub.players.first(where: { !$0.isOnLoan }),
              let host = store.clubs.indices.first(where: { $0 != store.userClubIndex && store.clubs[$0].players.count < 30 }) else {
            return XCTFail("Fixture must contain a loan player and destination")
        }
        store.clubs[host].wageBudget = store.clubs[host].wageBill + player.wage + 1
        store.clubs[host].transferBudget = 50
        let budget = store.userClub.transferBudget
        let ledger = store.seasonLedger.reduce(0) { $0 + $1.amount }
        for _ in 0..<200 {
            if case .accepted = store.proposeLoanOut(player, toClubIndex: host, fee: 50) {
                XCTAssertEqual(store.userClub.transferBudget, budget + 50)
                XCTAssertEqual(store.clubs[host].transferBudget, 0)
                XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledger, 50)
                let entries = store.seasonLedger.map(\.id)
                guard case .rejected = store.proposeLoanOut(player, toClubIndex: host, fee: 50) else {
                    return XCTFail("The same player cannot be loaned out twice")
                }
                XCTAssertEqual(store.userClub.transferBudget, budget + 50)
                XCTAssertEqual(store.seasonLedger.map(\.id), entries)
                return
            }
            XCTAssertEqual(store.userClub.transferBudget, budget)
            XCTAssertEqual(store.clubs[host].transferBudget, 50)
            XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount }, ledger)
        }
        XCTFail("Loan did not land within 200 attempts")
    }

    func testUnaffordablePersonalTermsAndWithdrawalPreserveFinances() async {
        let store = await freshFixture()
        store.fastForwardPendingDealReadinessForDebug()
        guard let deal = store.pendingTransferDeals.first(where: { $0.player.name == "Ivan Ongo" }) else {
            return XCTFail("Fixture must contain a pending deal")
        }
        let budget = store.userClub.transferBudget
        let ledger = store.seasonLedger.map(\.id)
        let sellerBudget = store.clubs[deal.sellingClubIndex].transferBudget
        guard case .rejected = store.finalizePersonalTerms(deal, wage: store.transferWageDemand(deal.player), years: 3,
                                                          signingOnFee: budget + 1) else {
            return XCTFail("Unaffordable terms must be rejected")
        }
        XCTAssertEqual(store.userClub.transferBudget, budget)
        XCTAssertEqual(store.seasonLedger.map(\.id), ledger)
        store.withdrawPendingDeal(deal)
        XCTAssertEqual(store.userClub.transferBudget, budget)
        XCTAssertEqual(store.clubs[deal.sellingClubIndex].transferBudget, sellerBudget)
        XCTAssertEqual(store.seasonLedger.map(\.id), ledger)
    }

    func testAcceptedSigningFeeAndLedgerSurviveRealSaveReload() async {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Finance Audit Tester")
        guard let saveID = store.currentSaveID, let player = store.userClub.players.first else {
            return XCTFail("New career must create a save and squad")
        }
        defer { GameStore.deleteSave(id: saveID) }
        let wage = store.renewalDemand(player) * 2
        store.clubs[store.userClubIndex].wageBudget = store.userClub.wageBill + wage
        store.clubs[store.userClubIndex].transferBudget = 100
        for _ in 0..<50 {
            if case .accepted = store.proposeRenewal(player, wage: wage, years: 3, signingOnFee: 50) {
                let reloaded = await makeTestStore()
                XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
                XCTAssertEqual(reloaded.userClub.transferBudget, 50)
                XCTAssertEqual(reloaded.seasonLedger.map(\.id), store.seasonLedger.map(\.id))
                XCTAssertEqual(reloaded.seasonLedger.first?.category, "Signing-on fee")
                XCTAssertEqual(reloaded.seasonLedger.first?.amount, -50)
                return
            }
        }
        XCTFail("Renewal did not land within 50 attempts")
    }

    func testCompetitionPrizeIncomeIsRecordedOnlyForUserClub() async {
        let store = await freshFixture()
        let opponent = store.clubs.indices.first { $0 != store.userClubIndex }!
        for winner in [store.userClubIndex, opponent] {
            let tie = CupTie(round: 6, homeIndex: store.userClubIndex, awayIndex: opponent,
                             played: true, winnerIndex: winner)
            let finals: [(String, Int, () -> Void)] = [
                ("Domestic cup", 1_300, { store.cupTies = [tie]; store.concludeCupRound() }),
                ("League trophy", 700, { store.leagueCupTies = [tie]; store.concludeLeagueCupRound() }),
                ("Continental cup", 6_500, { store.euroTies = [tie]; store.concludeEuroRound() }),
                ("UEFA cup", 3_500, { store.uefaCupTies = [tie]; store.concludeUefaCupRound() }),
                ("Community shield", 300, {
                    // A real one-off tie is unplayed when it resolves; handing
                    // the resolve an already-played tie is now (correctly) a
                    // no-op so a paid one-off can never pay twice.
                    store.communityShieldTie = CupTie(round: 0, homeIndex: store.userClubIndex, awayIndex: opponent)
                    store.resolveCommunityShield(homeGoals: winner == store.userClubIndex ? 2 : 0,
                                                 awayGoals: winner == store.userClubIndex ? 0 : 2)
                })
            ]
            for (name, prize, resolve) in finals {
                let budget = store.userClub.transferBudget
                let ledger = store.seasonLedger.reduce(0) { $0 + $1.amount }
                let expected = winner == store.userClubIndex ? prize : 0
                resolve()
                XCTAssertEqual(store.userClub.transferBudget - budget, expected, name)
                XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledger, expected, name)
            }
        }
    }

    func testEveryFacilityChargesQuotedCostAndRefusesUnaffordableOrMaxedUpgrade() async {
        let store = await freshFixture()
        for kind in FacilityKind.allCases {
            // Each purchase gets exactly its quoted budget. A second tap cannot
            // afford the next level, and must leave both money and ledger intact.
            for _ in 0..<5 {
                guard let cost = store.facilityUpgradeCost(kind, forClubIndex: store.userClubIndex) else { break }
                let level = kind.level(in: store.userClub)
                store.clubs[store.userClubIndex].transferBudget = cost - 1
                let entries = store.seasonLedger.map(\.id)
                store.investInFacility(kind)
                XCTAssertEqual(kind.level(in: store.userClub), level, kind.rawValue)
                XCTAssertEqual(store.userClub.transferBudget, cost - 1, kind.rawValue)
                XCTAssertEqual(store.seasonLedger.map(\.id), entries)
                store.clubs[store.userClubIndex].transferBudget = cost
                let ledgerBefore = store.seasonLedger.reduce(0) { $0 + $1.amount }
                store.investInFacility(kind)
                XCTAssertEqual(kind.level(in: store.userClub), level + 1, kind.rawValue)
                XCTAssertEqual(store.userClub.transferBudget, 0, kind.rawValue)
                XCTAssertEqual(store.seasonLedger.reduce(0) { $0 + $1.amount } - ledgerBefore, -cost, kind.rawValue)
            }
            let entries = store.seasonLedger.map(\.id)
            store.clubs[store.userClubIndex].transferBudget = 1_000_000
            store.investInFacility(kind)
            XCTAssertEqual(kind.level(in: store.userClub), 5, kind.rawValue)
            XCTAssertEqual(store.userClub.transferBudget, 1_000_000, kind.rawValue)
            XCTAssertEqual(store.seasonLedger.map(\.id), entries)
        }
    }
}
