//
//  LegendsPackTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 4 pack database and pull/duplicate/upgrade logic —
//  every pack must have a non-empty pool that can actually satisfy its
//  own guarantee, and opening a pack must behave correctly around
//  affordability, duplicates and the upgrade cap.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsPackTests: XCTestCase {
    func testEveryPackHasANonEmptyPool() {
        for pack in LegendsPackDatabase.all {
            let eligible = LegendsCardDatabase.all.filter(pack.pool)
            XCTAssertFalse(eligible.isEmpty, "\(pack.id) has no eligible cards")
        }
    }

    func testEveryPacksGuaranteeIsAchievableFromItsOwnPool() {
        for pack in LegendsPackDatabase.all {
            let eligible = LegendsCardDatabase.all.filter(pack.pool)
            let canMeetGuarantee = eligible.contains { $0.rarity.tier >= pack.guaranteedMinTier }
            XCTAssertTrue(canMeetGuarantee, "\(pack.id)'s pool can never satisfy its guaranteedMinTier of \(pack.guaranteedMinTier)")
        }
    }

    func testEveryPackHasANonNegativeCost() {
        for pack in LegendsPackDatabase.all {
            XCTAssertGreaterThanOrEqual(pack.cost, 0, "\(pack.id) has a negative cost")
        }
    }

    func testEveryPackHasDistinctArtwork() {
        let artworkNames = LegendsPackDatabase.all.map(\.artworkAssetName)
        XCTAssertEqual(artworkNames.count, Set(artworkNames).count)
        XCTAssertFalse(artworkNames.contains(where: \.isEmpty))
    }
}

@MainActor
final class LegendsStorePackOpeningTests: XCTestCase {
    // Constructing LegendsStore() directly inside a sync @MainActor test
    // method hits the same malloc double-free documented for GameStore
    // in memory/rsm_infra_and_known_issues.md — turns out it isn't
    // specific to GameStore's large property count (LegendsStore has
    // just one stored property); routing through a real Task hop avoids
    // it here too. See makeTestStore() in GameStoreTestSupport.swift.
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.coins = 100_000
        store.profile.packTokens = 1_000
        store.profile.ownedCardIDs = []
        store.profile.duplicateProgress = [:]
        store.profile.cardUpgrades = [:]
        // LegendsStore() loads whatever's actually on disk (e.g. from a
        // manual Simulator run, or an earlier test class in the same
        // xcodebuild test invocation that signed/played this exact card
        // and persisted the result to the same shared on-disk profile) —
        // effectiveOverall() also folds in aging penalty, development
        // bonus and form boost, so leftover cardAgeOffsets *or* a
        // leftover playerCareers entry for this card otherwise leaks into
        // "does effectiveOverall equal overall+upgrade" checks. Clearing
        // cardAgeOffsets alone isn't enough: agingPenalty(for:) and
        // formBoost(for:) both read profile.playerCareers[card.id]
        // directly, with no activatedCardIDs gate the way
        // developmentBonus(for:) has.
        store.profile.cardAgeOffsets = [:]
        store.profile.playerCareers = [:]
        store.profile.activatedCardIDs = []
        store.profile.pendingPackID = nil
        store.profile.pendingPackCardIDs = []
        store.profile.hasClaimedStarterPack = false
        return store
    }

    func testOpeningAPackDeductsItsCost() async throws {
        let store = await freshStore()
        let pack = LegendsPackDatabase.all.first { $0.id == "bronze" }!
        let before = store.profile.coins
        _ = try store.openPack(pack)
        XCTAssertEqual(store.profile.coins, before - pack.cost)
    }

    func testOpeningAPackWithInsufficientFundsThrows() async {
        let store = await freshStore()
        store.profile.coins = 0
        store.profile.packTokens = 0
        let pack = LegendsPackDatabase.all.first { $0.id == "gold" }!
        XCTAssertThrowsError(try store.openPack(pack))
    }

    func testPullsMeetTheGuaranteedMinimumTier() async throws {
        let store = await freshStore()
        let pack = LegendsPackDatabase.all.first { $0.id == "icons" }!
        let results = try store.openPack(pack)
        XCTAssertTrue(results.contains { $0.card.rarity.tier >= pack.guaranteedMinTier })
    }

    func testThirdDuplicateGrantsAnUpgrade() async throws {
        let store = await freshStore()
        let pack = LegendsPackDatabase.all.first { $0.id == "icons" }!
        // Icons pool is tiny, so repeated pulls are guaranteed to produce
        // duplicates within a handful of opens.
        for _ in 0..<20 { _ = try store.openPack(pack) }
        XCTAssertFalse(store.profile.cardUpgrades.isEmpty, "Expected at least one card to reach 3 duplicates and upgrade")
        for (_, level) in store.profile.cardUpgrades {
            XCTAssertLessThanOrEqual(level, LegendsStore.maxCardUpgrade)
        }
    }

    func testEffectiveOverallReflectsUpgradesAndIsCapped() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first!
        store.profile.cardUpgrades[card.id] = LegendsStore.maxCardUpgrade
        XCTAssertEqual(store.effectiveOverall(for: card), min(99, card.overall + LegendsStore.maxCardUpgrade))
    }

    func testPreparedPackAddsOnlyTheChosenCardToTheLibrary() async throws {
        let store = await freshStore()
        let pack = LegendsPackDatabase.all.first { $0.id == "bronze" }!
        let candidates = try store.preparePack(pack)
        XCTAssertEqual(candidates.count, pack.cardCount)
        XCTAssertTrue(store.profile.ownedCardIDs.isEmpty)

        let chosen = try store.claimPreparedPack(at: 1)

        XCTAssertEqual(store.profile.ownedCardIDs, [chosen.card.id])
        XCTAssertNil(store.profile.pendingPackID)
        XCTAssertTrue(store.profile.pendingPackCardIDs.isEmpty)
    }

    func testCannotOpenAnotherPackWhileChoosing() async throws {
        let store = await freshStore()
        let first = LegendsPackDatabase.all.first { $0.id == "bronze" }!
        let second = LegendsPackDatabase.all.first { $0.id == "silver" }!
        _ = try store.preparePack(first)
        XCTAssertThrowsError(try store.preparePack(second)) { error in
            XCTAssertEqual(error as? LegendsPackError, .pendingSelection)
        }
    }

    func testStarterPackCanOnlyBeClaimedOnce() async throws {
        let store = await freshStore()
        let starter = LegendsPackDatabase.all.first { $0.id == "starter" }!
        XCTAssertFalse(store.profile.hasClaimedStarterPack)

        _ = try store.openPack(starter)
        XCTAssertTrue(store.profile.hasClaimedStarterPack)

        XCTAssertThrowsError(try store.openPack(starter)) { error in
            XCTAssertEqual(error as? LegendsPackError, .alreadyClaimed)
        }
    }

    func testClaimingTheStarterPackDoesNotBlockOtherPacks() async throws {
        let store = await freshStore()
        let starter = LegendsPackDatabase.all.first { $0.id == "starter" }!
        let bronze = LegendsPackDatabase.all.first { $0.id == "bronze" }!
        _ = try store.openPack(starter)
        XCTAssertNoThrow(try store.openPack(bronze))
    }
}
