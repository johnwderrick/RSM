import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsOwnedPlayersTests: XCTestCase {
    private func freshStore() -> LegendsStore {
        let store = LegendsStore()
        store.profile = .starter()
        store.profile.managerProfile = nil
        store.migrateLegacyCareerStates()
        store.migrateOwnedPlayerRecords()
        return store
    }

    private func addUnsignedCard(to store: LegendsStore) -> LegendsCard {
        let card = LegendsCardDatabase.all.first { !store.profile.ownedCardIDs.contains($0.id) }!
        store.profile.ownedCardIDs.insert(card.id)
        store.migrateOwnedPlayerRecords()
        return card
    }

    func testStarterMigrationCreatesOneRecordPerOwnedCard() {
        let store = freshStore()
        XCTAssertEqual(store.profile.ownedPlayerRecords.count, store.profile.ownedCardIDs.count)
        XCTAssertEqual(store.profile.ownedPlayerRecords.values.filter { $0.state == .signed }.count, store.profile.startingXICardIDs.compactMap { $0 }.count + store.profile.benchCardIDs.compactMap { $0 }.count)
        XCTAssertEqual(Set(store.profile.ownedPlayerRecords.values.map(\.playerDefinitionID)), store.profile.ownedCardIDs)
    }

    func testSigningCreatesActiveReserveWithoutChangingSquadAssignment() {
        let store = freshStore()
        let card = addUnsignedCard(to: store)
        XCTAssertTrue(store.signPlayer(cardID: card.id))
        store.moveToReserves(cardID: card.id)
        XCTAssertTrue(store.isSigned(card))
        XCTAssertEqual(store.assignment(for: card), .reserves)
        XCTAssertNotNil(store.careerState(for: card))
    }

    func testUnsignedPlayerCannotBeSelectedUntilSigned() {
        let store = freshStore()
        let card = addUnsignedCard(to: store)
        store.assign(cardID: card.id, toXISlot: 0)
        XCTAssertFalse(store.profile.startingXICardIDs.contains(card.id))
    }

    func testMoveToReservesNeverFreezesCareer() {
        let store = freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.startingXICardIDs.contains($0.id) }!
        XCTAssertTrue(store.isSigned(card))
        store.moveToReserves(cardID: card.id)
        XCTAssertTrue(store.isSigned(card))
        XCTAssertEqual(store.assignment(for: card), .reserves)
        XCTAssertFalse(store.profile.startingXICardIDs.contains(card.id))
        XCTAssertFalse(store.profile.benchCardIDs.contains(card.id))
    }

    func testRepeatedAssignmentsDoNotDuplicateCareerIDOrCardReference() {
        let store = freshStore()
        let card = LegendsCardDatabase.all.first { store.profile.ownedCardIDs.contains($0.id) }!
        store.assign(cardID: card.id, toXISlot: 0)
        store.assign(cardID: card.id, toBenchSlot: 0)
        let refs = store.profile.startingXICardIDs.compactMap { $0 } + store.profile.benchCardIDs.compactMap { $0 }
        XCTAssertEqual(refs.filter { $0 == card.id }.count, 1)
        XCTAssertEqual(store.profile.ownedPlayerRecords.values.filter { $0.playerDefinitionID == card.id }.count, 1)
    }

    func testSignedReservesAgeAndUnsignedPlayersRemainFrozen() {
        let store = freshStore()
        let active = LegendsCardDatabase.all.first { store.profile.startingXICardIDs.contains($0.id) }!
        let unsigned = addUnsignedCard(to: store)
        let activeAge = store.effectiveAge(for: active)
        let unsignedAge = store.effectiveAge(for: unsigned)
        store.moveToReserves(cardID: active.id)
        for _ in 0..<LegendsStore.matchesPerSeason { _ = store.advanceSeasonIfNeeded() }
        XCTAssertGreaterThanOrEqual(store.effectiveAge(for: active), activeAge + 1)
        XCTAssertEqual(store.effectiveAge(for: unsigned), unsignedAge)
    }
}
