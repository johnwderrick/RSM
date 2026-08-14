//
//  LegendsChemistryTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 6 chemistry model: shared links raise a player's
//  stars, Formation Fit caps or zeroes them when played out of
//  position, and league is derived consistently from club identity.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsChemistryTests: XCTestCase {
    func testLeagueIsDerivedFromClubCountry() {
        let nerazzurri = LegendsCardDatabase.all.first { $0.club == "San Siro Nerazzurri" }!
        let bianconeri = LegendsCardDatabase.all.first { $0.club == "Turin Bianconeri" }!
        XCTAssertEqual(nerazzurri.league, "Italy")
        XCTAssertEqual(bianconeri.league, "Italy")
        XCTAssertEqual(nerazzurri.league, bianconeri.league)
    }

    func testUnmappedClubFallsBackToItsOwnName() {
        // "Portugal" is used as the club for a golden-generation
        // national-side variant card, not a real club — should just
        // fall back to itself rather than crash or return something odd.
        let card = LegendsCardDatabase.all.first { $0.club == "Portugal" }!
        XCTAssertEqual(card.league, "Portugal")
    }
}

@MainActor
final class LegendsStoreChemistryTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        return store
    }

    func testEmptySlotHasZeroChemistry() async {
        let store = await freshStore()
        XCTAssertEqual(store.chemistryStars(forXISlot: 0), 0)
        XCTAssertEqual(store.totalChemistry, 0)
    }

    func testSharedClubAndEraRaiseChemistryAboveAnUnlinkedPair() async {
        let store = await freshStore()
        // Both Bernabéu Whites, both 2000s era. `startingXISlots` only ever
        // produces holding/central/wide-mid/wing roles (never .attackingMid,
        // which `DetailedPosition.expected` doesn't emit), so these two
        // land on the same broad bucket rather than an exact slot match —
        // fine here, since the test only checks the relative effect of
        // sharing a club/era, not exact Formation Fit.
        let zeidan = LegendsCardDatabase.all.first { $0.id == "zeidan-0102" }!  // CAM
        let figaro = LegendsCardDatabase.all.first { $0.id == "figaro-0001" }!  // RW
        let slots = store.startingXISlots
        let midfieldIndices = slots.indices.filter { slots[$0].broad == .midfielder }
        guard midfieldIndices.count >= 2 else { return XCTFail("4-4-2 should have at least 2 midfield slots") }
        let camIndex = midfieldIndices[0]
        let rwIndex = midfieldIndices[1]

        store.assign(cardID: zeidan.id, toXISlot: camIndex)
        store.assign(cardID: figaro.id, toXISlot: rwIndex)
        let linkedStars = store.chemistryStars(forXISlot: camIndex)

        // Replace figaro with an unrelated card (different club/era/nation).
        let unrelated = LegendsCardDatabase.all.first { $0.id == "odusanya-2526" }!  // Future Stars, Highbury, Nigeria
        store.assign(cardID: unrelated.id, toXISlot: rwIndex)
        let unlinkedStars = store.chemistryStars(forXISlot: camIndex)

        XCTAssertGreaterThan(linkedStars, unlinkedStars)
    }

    func testWrongBroadPositionZeroesChemistryRegardlessOfLinks() async {
        let store = await freshStore()
        let slots = store.startingXISlots
        let strikerIndex = slots.firstIndex(where: { $0.broad == .forward })!

        // A goalkeeper forced into a striker slot — badly out of position.
        let keeper = LegendsCardDatabase.all.first { $0.position == .goalkeeper }!
        store.assign(cardID: keeper.id, toXISlot: strikerIndex)

        // Pad the rest of the XI with copies of the keeper's own
        // club/era/nation so linkScore would otherwise be high.
        let sameClubCards = LegendsCardDatabase.all.filter { $0.club == keeper.club && $0.id != keeper.id }
        for (offset, index) in slots.indices.filter({ $0 != strikerIndex }).enumerated() where offset < sameClubCards.count {
            store.assign(cardID: sameClubCards[offset].id, toXISlot: index)
        }

        XCTAssertEqual(store.chemistryStars(forXISlot: strikerIndex), 0)
    }

    func testSameBroadPositionMismatchCapsAtTwoStars() async {
        let store = await freshStore()
        let slots = store.startingXISlots
        // A left-back played at right-back — same broad bucket
        // (defender), wrong exact slot.
        guard let lbIndex = slots.firstIndex(of: .leftBack), let rbIndex = slots.firstIndex(of: .rightBack) else {
            return XCTFail("4-4-2 should have both LB and RB slots")
        }
        let leftBackCard = LegendsCardDatabase.all.first { $0.position == .leftBack }
            ?? LegendsCardDatabase.all.first { $0.position.broad == .defender }!

        // Stack every other slot with the same club to maximize linkScore.
        let sameClub = LegendsCardDatabase.all.filter { $0.club == leftBackCard.club && $0.id != leftBackCard.id }
        for (offset, index) in slots.indices.filter({ $0 != rbIndex }).enumerated() where offset < sameClub.count {
            store.assign(cardID: sameClub[offset].id, toXISlot: index)
        }
        store.assign(cardID: leftBackCard.id, toXISlot: rbIndex)  // played out of its natural LB slot

        XCTAssertLessThanOrEqual(store.chemistryStars(forXISlot: rbIndex), 2)
    }

    func testTotalChemistryIsTheSumOfEveryFilledSlot() async {
        let store = await freshStore()
        let slots = store.startingXISlots
        let sameClubCards = Array(LegendsCardDatabase.all.filter { $0.club == "Old Trafford Reds" }.prefix(3))
        guard sameClubCards.count == 3 else { return XCTFail("Expected at least 3 Old Trafford Reds cards in the database") }
        for (offset, card) in sameClubCards.enumerated() {
            store.assign(cardID: card.id, toXISlot: slots.firstIndex(of: card.position) ?? offset)
        }
        let expectedSum = slots.indices.reduce(0) { $0 + store.chemistryStars(forXISlot: $1) }
        XCTAssertEqual(store.totalChemistry, expectedSum)
        XCTAssertGreaterThan(store.totalChemistry, 0)
    }
}
