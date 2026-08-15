//
//  LegendsSquadTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 5 Squad Builder invariants: a card can never occupy
//  two slots at once, the captain must be a Starting XI player, and
//  team rating only counts a fully-set XI.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsSquadTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        // Unique by name, not just the first 20 ids — several early cards
        // in the database are different seasons of the same player (e.g.
        // two "E. Cantina" cards), and only one card per player is allowed
        // in the squad at once (LegendsStore+Squad.swift), so a handful of
        // these tests fill multiple slots at a time and need real variety.
        var seenNames = Set<String>()
        let uniqueCards = LegendsCardDatabase.all.filter { seenNames.insert($0.name).inserted }
        store.profile.ownedCardIDs = Set(uniqueCards.prefix(20).map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        return store
    }

    func testStartingXISlotCountMatchesFormation() async {
        let store = await freshStore()
        let f = Formation.all.first { $0.name == "4-3-3" }!
        store.setFormation(f.name)
        XCTAssertEqual(store.startingXISlots.count, 1 + f.defenders + f.midfielders + f.forwards)
        XCTAssertEqual(store.profile.startingXICardIDs.count, store.startingXISlots.count)
    }

    func testAssigningACardRemovesItFromItsPreviousSlot() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        XCTAssertEqual(store.profile.startingXICardIDs[0], card.id)

        store.assign(cardID: card.id, toXISlot: 1)
        XCTAssertNil(store.profile.startingXICardIDs[0], "Card should have moved out of slot 0")
        XCTAssertEqual(store.profile.startingXICardIDs[1], card.id)
    }

    func testAssigningACardFromXIToBenchClearsTheXISlot() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        store.assign(cardID: card.id, toBenchSlot: 0)
        XCTAssertNil(store.profile.startingXICardIDs[0])
        XCTAssertEqual(store.profile.benchCardIDs[0], card.id)
    }

    func testCannotAssignACardThatIsNotOwned() async {
        let store = await freshStore()
        let unowned = LegendsCardDatabase.all.first { !store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: unowned.id, toXISlot: 0)
        XCTAssertNil(store.profile.startingXICardIDs[0])
    }

    func testCaptainMustBeInStartingXI() async {
        let store = await freshStore()
        let inXI = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        let onBench = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) && $0.id != inXI.id }!
        store.assign(cardID: inXI.id, toXISlot: 0)
        store.assign(cardID: onBench.id, toBenchSlot: 0)

        store.setCaptain(cardID: onBench.id)
        XCTAssertNil(store.profile.captainCardID, "A bench player should never be accepted as captain")

        store.setCaptain(cardID: inXI.id)
        XCTAssertEqual(store.profile.captainCardID, inXI.id)
    }

    func testClearingTheCaptainsXISlotClearsTheCaptaincy() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        store.setCaptain(cardID: card.id)
        store.clearXISlot(0)
        XCTAssertNil(store.profile.captainCardID)
    }

    func testTeamRatingIsZeroUntilTheWholeXIIsFilled() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        XCTAssertEqual(store.currentTeamRating, 0)
    }

    func testTeamRatingAveragesTheFullXI() async {
        let store = await freshStore()
        let ownedCards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        let slots = store.startingXISlots
        for i in 0..<slots.count {
            store.assign(cardID: ownedCards[i % ownedCards.count].id, toXISlot: i)
        }
        let expected = Int((Double((0..<slots.count).reduce(0) { $0 + store.effectiveOverall(for: ownedCards[$1 % ownedCards.count]) }) / Double(slots.count)).rounded())
        XCTAssertEqual(store.currentTeamRating, expected)
        XCTAssertGreaterThan(store.currentTeamRating, 0)
    }

    func testAttackAndDefenceRatingAreZeroUntilTheWholeXIIsFilled() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        XCTAssertEqual(store.attackRating, 0)
        XCTAssertEqual(store.defenceRating, 0)
    }

    func testAttackRatingOnlyCountsMidfieldAndForwardSlots() async {
        let store = await freshStore()
        let ownedCards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        let slots = store.startingXISlots
        for i in 0..<slots.count {
            store.assign(cardID: ownedCards[i % ownedCards.count].id, toXISlot: i)
        }
        let attackIndices = slots.indices.filter { slots[$0].broad == .midfielder || slots[$0].broad == .forward }
        XCTAssertFalse(attackIndices.isEmpty, "4-4-2 should have at least one midfield/forward slot")
        let expected = Int((Double(attackIndices.reduce(0) { $0 + store.effectiveOverall(for: ownedCards[$1 % ownedCards.count]) })
                             / Double(attackIndices.count)).rounded())
        XCTAssertEqual(store.attackRating, expected)
    }

    func testDefenceRatingOnlyCountsGoalkeeperAndDefenderSlots() async {
        let store = await freshStore()
        let ownedCards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        let slots = store.startingXISlots
        for i in 0..<slots.count {
            store.assign(cardID: ownedCards[i % ownedCards.count].id, toXISlot: i)
        }
        let defenceIndices = slots.indices.filter { slots[$0] == .goalkeeper || slots[$0].broad == .defender }
        XCTAssertFalse(defenceIndices.isEmpty, "4-4-2 should have at least one goalkeeper/defender slot")
        let expected = Int((Double(defenceIndices.reduce(0) { $0 + store.effectiveOverall(for: ownedCards[$1 % ownedCards.count]) })
                             / Double(defenceIndices.count)).rounded())
        XCTAssertEqual(store.defenceRating, expected)
    }

    func testOnlyOneCardPerPlayerAllowedInTheSquadAtOnce() async {
        let store = await freshStore()
        // Two different seasons of the same person — same `name`.
        let young = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let peak = LegendsCardDatabase.all.first { $0.id == "miessi-1112" }!
        XCTAssertEqual(young.name, peak.name)
        store.profile.ownedCardIDs.insert(peak.id)

        store.assign(cardID: young.id, toXISlot: 0)
        store.assign(cardID: peak.id, toBenchSlot: 0)
        XCTAssertNil(store.profile.startingXICardIDs[0], "Fielding a second version of the same player should bump the first out of the XI")
        XCTAssertEqual(store.profile.benchCardIDs[0], peak.id)
    }

    func testFieldingASecondVersionOfTheCaptainClearsCaptaincy() async {
        let store = await freshStore()
        let young = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let peak = LegendsCardDatabase.all.first { $0.id == "miessi-1112" }!
        store.profile.ownedCardIDs.insert(peak.id)

        store.assign(cardID: young.id, toXISlot: 0)
        store.setCaptain(cardID: young.id)
        store.assign(cardID: peak.id, toXISlot: 1)

        XCTAssertNil(store.profile.captainCardID, "The old version's captaincy shouldn't survive it being bumped from the XI")
        XCTAssertEqual(store.profile.startingXICardIDs[1], peak.id)
    }

    func testShrinkingFormationMovesOverflowToBenchInsteadOfDroppingIt() async {
        let store = await freshStore()
        let ownedCards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        // 4-2-4 has more slots than 4-4-2; fill it, then switch down.
        store.setFormation("4-2-4")
        let bigSlotCount = store.startingXISlots.count
        for i in 0..<bigSlotCount {
            store.assign(cardID: ownedCards[i % ownedCards.count].id, toXISlot: i)
        }
        let allAssignedBefore = Set(store.profile.startingXICardIDs.compactMap { $0 })

        store.setFormation("4-4-2")

        let stillAssigned = Set(store.profile.startingXICardIDs.compactMap { $0 } + store.profile.benchCardIDs.compactMap { $0 })
        XCTAssertEqual(allAssignedBefore, stillAssigned, "Every card should still be in the squad (XI or bench) after shrinking the formation")
    }
}
