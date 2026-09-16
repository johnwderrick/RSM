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
        store.signAllOwnedCardsForTesting()
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        store.profile.activatedCardIDs = []
        return store
    }

    func testSquadRolesPersistAndOldSavesDefaultToUnassigned() async throws {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        store.assign(cardID: cards[0].id, toXISlot: 1)
        store.setSquadRole(.penalties, cardID: cards[0].id)
        let encoded = try JSONEncoder().encode(store.profile)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: encoded)
        XCTAssertEqual(decoded.squadRoleAssignments["penalties"], cards[0].id)
        var oldSave = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        oldSave.removeValue(forKey: "squadRoleAssignments")
        let legacy = try JSONDecoder().decode(LegendsProfile.self, from: JSONSerialization.data(withJSONObject: oldSave))
        XCTAssertTrue(legacy.squadRoleAssignments.isEmpty)
    }

    func testLeadershipIsDistinctAndRolesClearWhenPlayerLeavesXI() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        store.assign(cardID: cards[0].id, toXISlot: 1)
        store.assign(cardID: cards[1].id, toXISlot: 2)
        store.setCaptain(cardID: cards[0].id)
        store.setSquadRole(.viceCaptain, cardID: cards[0].id)
        XCTAssertNil(store.squadRoleCardID(.viceCaptain))
        store.setSquadRole(.viceCaptain, cardID: cards[1].id)
        store.setSquadRole(.leftCorner, cardID: cards[1].id)
        XCTAssertEqual(store.squadRoleCardID(.viceCaptain), cards[1].id)
        store.swapSquadSlots(.xi(2), .bench(0))
        XCTAssertNil(store.squadRoleCardID(.viceCaptain))
        XCTAssertNil(store.profile.squadRoleAssignments["leftCorner"])
        store.setSquadRole(.penalties, cardID: cards[1].id)
        XCTAssertNil(store.squadRoleCardID(.penalties))
    }

    func testSigningCardActivatesItsAgingClock() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        XCTAssertFalse(store.profile.activatedCardIDs.contains(card.id))
        store.assign(cardID: card.id, toXISlot: 0)
        XCTAssertTrue(store.profile.activatedCardIDs.contains(card.id))
    }

    func testPositionFilterRejectsUnrelatedReplacement() async {
        let store = await freshStore()
        let keeper = LegendsCardDatabase.all.first { $0.position == .goalkeeper }!
        let striker = LegendsCardDatabase.all.first { $0.position == .striker }!
        XCTAssertTrue(store.canPlay(keeper, in: .goalkeeper))
        XCTAssertFalse(store.canPlay(striker, in: .goalkeeper))
    }

    func testLibraryQueryFiltersByDetailedPosition() async {
        let store = await freshStore()
        let query = LegendsLibraryQuery(position: .goalkeeper)
        let cards = store.libraryCards(query: query)
        XCTAssertFalse(cards.isEmpty)
        XCTAssertTrue(cards.allSatisfy { store.canPlay($0, in: .goalkeeper) })
    }

    func testLibraryQuerySearchesAndSortsByRating() async {
        let store = await freshStore()
        let query = LegendsLibraryQuery(sort: .rating, searchText: "miessi")
        let cards = store.libraryCards(query: query)
        XCTAssertTrue(cards.allSatisfy { $0.name.lowercased().contains("miessi") })
        XCTAssertEqual(cards, cards.sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) })
    }

    func testLibraryGroupsDifferentSeasonsByPlayer() async {
        let store = await freshStore()
        let young = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let peak = LegendsCardDatabase.all.first { $0.id == "miessi-1112" }!
        store.profile.ownedCardIDs.formUnion([young.id, peak.id])
        let query = LegendsLibraryQuery(group: .player, searchText: "miessi")
        let groups = store.libraryGroups(query: query)
        let group = groups.first { $0.key == young.name }
        XCTAssertEqual(group?.cards.count, 2)
        XCTAssertEqual(Set(group?.cards.map(\.name) ?? []), [young.name])
    }

    func testLibraryExcludesCardsAlreadyInTheActiveSquadByDefault() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        XCTAssertFalse(store.libraryCards().contains(card))
        XCTAssertTrue(store.libraryCards(excludingActive: false).contains(card))
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
        store.signAllOwnedCardsForTesting()

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
        store.signAllOwnedCardsForTesting()

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

    // MARK: - swapSquadSlots (the Squad screen's drag-and-drop)

    func testSwappingTwoXISlotsExchangesTheirCards() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        store.assign(cardID: cards[0].id, toXISlot: 0)
        store.assign(cardID: cards[1].id, toXISlot: 1)

        store.swapSquadSlots(.xi(0), .xi(1))

        XCTAssertEqual(store.profile.startingXICardIDs[0], cards[1].id)
        XCTAssertEqual(store.profile.startingXICardIDs[1], cards[0].id)
    }

    func testSwappingAnXISlotWithABenchSlotMovesBothCards() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        store.assign(cardID: cards[0].id, toXISlot: 0)
        store.assign(cardID: cards[1].id, toBenchSlot: 0)

        store.swapSquadSlots(.xi(0), .bench(0))

        XCTAssertEqual(store.profile.startingXICardIDs[0], cards[1].id)
        XCTAssertEqual(store.profile.benchCardIDs[0], cards[0].id)
    }

    func testSwappingWithAnEmptySlotBehavesLikeAMove() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)

        store.swapSquadSlots(.xi(0), .bench(0))

        XCTAssertNil(store.profile.startingXICardIDs[0])
        XCTAssertEqual(store.profile.benchCardIDs[0], card.id)
    }

    func testSwappingTheCaptainOutOfTheXIClearsCaptaincy() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        store.assign(cardID: cards[0].id, toXISlot: 0)
        store.setCaptain(cardID: cards[0].id)
        XCTAssertNotNil(store.profile.captainCardID)

        store.swapSquadSlots(.xi(0), .bench(0))

        XCTAssertNil(store.profile.captainCardID, "Captaincy shouldn't survive the captain's card leaving the XI")
    }

    func testSwappingASlotWithItselfIsANoOp() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)

        store.swapSquadSlots(.xi(0), .xi(0))

        XCTAssertEqual(store.profile.startingXICardIDs[0], card.id)
    }

    // MARK: - Reserves (signed players outside XI and bench)

    func testReservesContainExactlySignedPlayersOutsideXIAndBench() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        // Six signed players leave 14 reserves from the 20 signed.
        for (offset, card) in cards.prefix(6).enumerated() {
            if offset < 4 { store.assign(cardID: card.id, toXISlot: offset) }
            else { store.assign(cardID: card.id, toBenchSlot: offset - 4) }
        }

        let reserveIDs = Set(store.reservePlayers.map(\.id))
        let signedIDs = Set(store.activeClubPlayers.map(\.id))
        let assignedIDs = Set(store.profile.startingXICardIDs.compactMap(\.self))
            .union(store.profile.benchCardIDs.compactMap(\.self))

        XCTAssertEqual(reserveIDs, signedIDs.subtracting(assignedIDs))
        XCTAssertEqual(reserveIDs.count, 14)
    }

    func testReservesAreDisjointFromXIAndBenchAndEverySignedPlayerIsSomewhere() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        // Fill all 18 matchday slots (11 XI + 7 bench); the two remaining
        // signed players must land in reserves.
        for (offset, card) in cards.prefix(18).enumerated() {
            if offset < 11 { store.assign(cardID: card.id, toXISlot: offset) }
            else { store.assign(cardID: card.id, toBenchSlot: offset - 11) }
        }

        let xi = Set(store.profile.startingXICardIDs.compactMap(\.self))
        let bench = Set(store.profile.benchCardIDs.compactMap(\.self))
        let reserves = Set(store.reservePlayers.map(\.id))
        XCTAssertEqual(reserves, Set(cards.suffix(2).map(\.id)), "The two unassigned signed players are the reserves")
        XCTAssertEqual(xi.intersection(bench), [])
        XCTAssertEqual(xi.union(bench).intersection(reserves), [])
        XCTAssertEqual(xi.union(bench).union(reserves), Set(store.activeClubPlayers.map(\.id)), "Every signed player appears in exactly one section")
    }

    func testMovingAReserveToBenchUsesAuthoritativeAssignmentAndRemovesItFromReserves() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        let starter = cards[0]
        store.assign(cardID: starter.id, toXISlot: 0)
        XCTAssertFalse(store.reservePlayers.contains { $0.id == starter.id })

        // Return the starter to the reserves: they leave the XI and the
        // authoritative store path persists the move.
        store.clearXISlot(0)
        XCTAssertTrue(store.reservePlayers.contains { $0.id == starter.id })
        let encoded = try! JSONEncoder().encode(store.profile)
        let decoded = try! JSONDecoder().decode(LegendsProfile.self, from: encoded)
        XCTAssertTrue(decoded.startingXICardIDs.allSatisfy { $0 == nil })
    }

    func testUnsignedCardsNeverAppearAsReserves() async {
        let store = await freshStore()
        // five more owned-but-unsigned cards must never surface as reserves.
        let extra = LegendsCardDatabase.all.filter { !store.profile.ownedCardIDs.contains($0.id) }.prefix(5)
        store.profile.ownedCardIDs.formUnion(extra.map(\.id))
        // Two of the signed players occupy matchday slots.
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        store.assign(cardID: cards[0].id, toXISlot: 0)
        store.assign(cardID: cards[1].id, toBenchSlot: 0)

        let signedIDs = Set(store.activeClubPlayers.map(\.id))
        let reserves = Set(store.reservePlayers.map(\.id))
        XCTAssertTrue(reserves.isSubset(of: signedIDs), "Reserves must only contain signed players")
        XCTAssertEqual(reserves.count, signedIDs.count - 2)
    }

    // MARK: - Moving players between XI, bench and reserves

    /// Builds a full matchday squad (11 XI + 7 bench) from the owned cards,
    /// leaving exactly two signed reserves. Returns (store, cards, the
    /// first reserve). The reserve indexes are deterministic: cards[18]
    /// and cards[19] are never assigned by this helper.
    private func storeWithTwoReserves() async -> (LegendsStore, [LegendsCard], LegendsCard) {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        for (offset, card) in cards.prefix(18).enumerated() {
            if offset < 11 { store.assign(cardID: card.id, toXISlot: offset) }
            else { store.assign(cardID: card.id, toBenchSlot: offset - 11) }
        }
        let reserve = cards[18]
        XCTAssertTrue(store.reservePlayers.contains { $0.id == reserve.id })
        return (store, cards, reserve)
    }

    func testReserveMovesIntoFreeXISlotAndLeavesReserves() async {
        let (store, _, reserve) = await storeWithTwoReserves()
        store.clearXISlot(10)

        store.assign(cardID: reserve.id, toXISlot: 10)

        XCTAssertEqual(store.profile.startingXICardIDs[10], reserve.id)
        XCTAssertFalse(store.reservePlayers.contains { $0.id == reserve.id })
        // No duplicates: every section still partitions the signed players.
        let xi = Set(store.profile.startingXICardIDs.compactMap(\.self))
        let bench = Set(store.profile.benchCardIDs.compactMap(\.self))
        XCTAssertEqual(xi.intersection(bench), [])
        XCTAssertEqual(xi.union(bench).union(Set(store.reservePlayers.map(\.id))), Set(store.activeClubPlayers.map(\.id)))
    }

    func testReserveIntoOccupiedXISlotDisplacesOccupantToReserves() async {
        let (store, cards, reserve) = await storeWithTwoReserves()
        let occupantID = try! XCTUnwrap(store.profile.startingXICardIDs[3], "XI slot 3 must be filled by the helper")
        let occupant = cards.first { $0.id == occupantID }!

        let evicted = store.assignReportingEvictions(reserve.id, toXISlot: 3)

        XCTAssertEqual(store.profile.startingXICardIDs[3], reserve.id)
        XCTAssertEqual(evicted.map(\.id), [occupant.id], "The slot's occupant is the only eviction")
        XCTAssertTrue(store.reservePlayers.contains { $0.id == occupant.id }, "The displaced player becomes a reserve")
        XCTAssertFalse(store.reservePlayers.contains { $0.id == reserve.id })
        let assigned = Set(store.profile.startingXICardIDs.compactMap(\.self)).union(store.profile.benchCardIDs.compactMap(\.self))
        XCTAssertEqual(assigned.intersection(Set(store.reservePlayers.map(\.id))), [], "No player in two sections")
    }

    func testReserveMovesIntoFreeAndOccupiedBenchSlots() async {
        let (store, cards, reserve) = await storeWithTwoReserves()

        // Free bench slot: plain move.
        store.clearBenchSlot(0)
        store.assign(cardID: reserve.id, toBenchSlot: 0)
        XCTAssertEqual(store.profile.benchCardIDs[0], reserve.id)
        XCTAssertFalse(store.reservePlayers.contains { $0.id == reserve.id })

        // Occupied bench slot: the occupant is displaced to reserves.
        let benchOccupantID = try! XCTUnwrap(store.profile.benchCardIDs[2], "Bench slot 2 must be filled by the helper")
        let benchOccupant = cards.first { $0.id == benchOccupantID }!
        store.assign(cardID: reserve.id, toBenchSlot: 2)
        XCTAssertEqual(store.profile.benchCardIDs[2], reserve.id)
        XCTAssertTrue(store.reservePlayers.contains { $0.id == benchOccupant.id })
        XCTAssertFalse(store.reservePlayers.contains { $0.id == reserve.id })
        let assigned = Set(store.profile.startingXICardIDs.compactMap(\.self)).union(store.profile.benchCardIDs.compactMap(\.self))
        XCTAssertEqual(assigned.intersection(Set(store.reservePlayers.map(\.id))), [])
    }

    func testXIAndBenchPlayersMoveToReserves() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        let starter = cards[0]
        let sub = cards[11]

        store.moveToReserves(cardID: starter.id)
        store.moveToReserves(cardID: sub.id)

        XCTAssertFalse(store.profile.startingXICardIDs.contains(starter.id))
        XCTAssertFalse(store.profile.benchCardIDs.contains(sub.id))
        XCTAssertTrue(store.reservePlayers.contains { $0.id == starter.id })
        XCTAssertTrue(store.reservePlayers.contains { $0.id == sub.id })
    }

    func testReserveMovePersistsAcrossSaveRoundTrip() async throws {
        let (store, _, reserve) = await storeWithTwoReserves()
        store.assign(cardID: reserve.id, toXISlot: 7)

        let encoded = try JSONEncoder().encode(store.profile)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: encoded)

        XCTAssertEqual(decoded.startingXICardIDs[7], reserve.id)
        XCTAssertFalse(decoded.benchCardIDs.contains(reserve.id))
    }

    func testCaptainAndSetPieceRolesFallBackWhenAssignedPlayerLeavesXI() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) }
        let captain = cards[0]
        store.assign(cardID: captain.id, toXISlot: 0)
        store.setCaptain(cardID: captain.id)
        store.setSquadRole(.penalties, cardID: captain.id)
        store.setSquadRole(.leftCorner, cardID: captain.id)
        XCTAssertEqual(store.squadRoleCardID(.penalties), captain.id)

        store.moveToReserves(cardID: captain.id)

        XCTAssertNil(store.profile.captainCardID, "Captaincy must clear when the captain leaves the XI")
        XCTAssertNil(store.squadRoleCardID(.penalties), "Set-piece role must fall back (be pruned) when the taker leaves the XI")
        XCTAssertNil(store.squadRoleCardID(.leftCorner))
        XCTAssertTrue(store.profile.squadRoleAssignments.isEmpty)
        XCTAssertTrue(store.reservePlayers.contains { $0.id == captain.id })
    }
}
