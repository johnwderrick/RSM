//
//  LegendsManagersAndStadiumsTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 9 Manager/Stadium catalogs and their integration
//  with match strength, chemistry, and Play Match's reward roll.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsManagersAndStadiumsDatabaseTests: XCTestCase {
    func testEveryManagerHasAUniqueID() {
        let ids = LegendsManagerDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryStadiumHasAUniqueID() {
        let ids = LegendsStadiumDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    /// Regression guard: a manager's affinityClub only ever does
    /// anything if some card in the database actually belongs to that
    /// club — same class of bug as the Phase 8 "unreachable challenge"
    /// catch.
    func testEveryManagerAffinityClubExistsInTheCardDatabase() {
        let realClubs = Set(LegendsCardDatabase.all.map(\.club))
        for manager in LegendsManagerDatabase.all {
            XCTAssertTrue(realClubs.contains(manager.affinityClub), "\(manager.id)'s affinity club '\(manager.affinityClub)' has no cards")
        }
    }

    func testEveryStadiumClubExistsInTheCardDatabase() {
        let realClubs = Set(LegendsCardDatabase.all.map(\.club))
        for stadium in LegendsStadiumDatabase.all {
            XCTAssertTrue(realClubs.contains(stadium.club), "\(stadium.id)'s club '\(stadium.club)' has no cards")
        }
    }

    func testEveryBonusIsPositive() {
        for manager in LegendsManagerDatabase.all { XCTAssertGreaterThan(manager.tacticalBonus, 0) }
        for stadium in LegendsStadiumDatabase.all { XCTAssertGreaterThan(stadium.gameplayBonus, 0) }
    }
}

@MainActor
final class LegendsStoreManagersAndStadiumsTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.signAllOwnedCardsForTesting()
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.ownedManagerIDs = []
        store.profile.activeManagerID = nil
        store.profile.ownedStadiumIDs = []
        store.profile.activeStadiumID = nil
        // LegendsStore() loads whatever's actually on disk — the
        // near-certain-win fillStrongXI-style sort below uses
        // effectiveOverall(), which also subtracts an aging penalty, so a
        // real playthrough's cardAgeOffsets otherwise leaks in here.
        store.profile.cardAgeOffsets = [:]
        return store
    }

    func testCannotActivateAnUnownedManager() async {
        let store = await freshStore()
        let manager = LegendsManagerDatabase.all.first!
        store.setActiveManager(manager.id)
        XCTAssertNil(store.profile.activeManagerID)
    }

    func testActivatingAnOwnedManagerSucceeds() async {
        let store = await freshStore()
        let manager = LegendsManagerDatabase.all.first!
        store.profile.ownedManagerIDs.insert(manager.id)
        store.setActiveManager(manager.id)
        XCTAssertEqual(store.profile.activeManagerID, manager.id)
        XCTAssertEqual(store.activeManager?.id, manager.id)
    }

    func testMatchStrengthBonusCombinesManagerAndStadium() async {
        let store = await freshStore()
        XCTAssertEqual(store.matchStrengthBonus, 0)

        let manager = LegendsManagerDatabase.all.first!
        store.profile.ownedManagerIDs.insert(manager.id)
        store.setActiveManager(manager.id)

        let stadium = LegendsStadiumDatabase.all.first!
        store.profile.ownedStadiumIDs.insert(stadium.id)
        store.setActiveStadium(stadium.id)

        XCTAssertEqual(store.matchStrengthBonus, Double(manager.tacticalBonus + stadium.gameplayBonus))
    }

    func testManagerAffinityBoostsChemistryForAMatchingClubCard() async {
        let store = await freshStore()
        let manager = LegendsManagerDatabase.all.first!
        let affinityCard = LegendsCardDatabase.all.first { $0.club == manager.affinityClub }!
        // Use a same-broad-position slot (not necessarily an exact
        // match) so Formation Fit never zeroes this out regardless of
        // the affinity card's specific role.
        let slots = store.startingXISlots
        let slotIndex = slots.firstIndex(of: affinityCard.position) ?? slots.firstIndex { $0.broad == affinityCard.position.broad } ?? 0
        store.assign(cardID: affinityCard.id, toXISlot: slotIndex)

        let starsWithoutManager = store.chemistryStars(forXISlot: slotIndex)

        store.profile.ownedManagerIDs.insert(manager.id)
        store.setActiveManager(manager.id)
        let starsWithManager = store.chemistryStars(forXISlot: slotIndex)

        XCTAssertGreaterThanOrEqual(starsWithManager, starsWithoutManager)
        XCTAssertGreaterThan(starsWithManager, 0, "A lone affinity-club player should get some chemistry credit from their manager")
    }

    func testWinningEnoughMatchesEventuallyGrantsAManagerOrStadium() async {
        let store = await freshStore()
        let slots = store.startingXISlots
        // Only one card per real-ish player at once (LegendsStore+Squad.swift's
        // name-based dedup) — dedupe by name before taking the top N.
        var seenNames = Set<String>()
        let sorted = LegendsCardDatabase.all
            .sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) }
            .filter { seenNames.insert($0.name).inserted }
        for (index, _) in slots.enumerated() {
            store.assign(cardID: sorted[index].id, toXISlot: index)
        }
        store.profile.division = .division10  // weakest opponents, near-certain wins

        var grantedSomething = false
        for _ in 0..<60 {
            guard let summary = store.playMatch() else { break }
            if summary.newManager != nil || summary.newStadium != nil { grantedSomething = true; break }
        }
        XCTAssertTrue(grantedSomething, "Expected at least one Manager/Stadium card within 60 near-certain wins")
    }
}
