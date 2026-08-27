import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsRetirementTimingTests: XCTestCase {
    private func store() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        store.profile.ownedCardIDs = []
        store.profile.activatedCardIDs = []
        store.profile.playerCareers = [:]
        store.profile.ownedPlayerRecords = [:]
        store.profile.legendsHall = []
        store.profile.cardAgeOffsets = [:]
        store.profile.matchesPlayedThisSeason = 0
        return store
    }

    func testBeforeFinalSeasonRolloverKeepsPlayerActiveAndEntersFinalSeason() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.intendedRetirementAge = 35
        store.profile.playerCareers[card.id] = career
        store.profile.cardAgeOffsets[card.id] = 33 - card.age
        store.migrateOwnedPlayerRecords()
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1

        let result = store.advanceSeasonIfNeeded()

        XCTAssertNotNil(result)
        XCTAssertTrue(store.profile.ownedCardIDs.contains(card.id))
        XCTAssertNotNil(store.profile.playerCareers[card.id])
        XCTAssertEqual(store.effectiveAge(for: card), 34)
        XCTAssertTrue(store.isFinalSeason(card))
        XCTAssertEqual(result?.retirementAnnouncements.map(\.id), [card.id])
        XCTAssertTrue(result?.developmentReview[card.id]?.reason.contains("Final Season") == true)
        XCTAssertTrue(store.profile.legendsHall.isEmpty)
    }

    func testFinalSeasonRetiresAtTargetAndArchiveIsIdempotent() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.intendedRetirementAge = 35
        store.profile.playerCareers[card.id] = career
        store.profile.cardAgeOffsets[card.id] = 34 - card.age
        store.migrateOwnedPlayerRecords()
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1

        let result = store.advanceSeasonIfNeeded()

        XCTAssertEqual(result?.retiredCards.map(\.id), [card.id])
        XCTAssertEqual(store.profile.legendsHall.filter { $0.cardID == card.id }.count, 1)
        XCTAssertEqual(store.profile.legendsHall.first?.finalAge, 35)
        XCTAssertNil(store.profile.playerCareers[card.id])
        XCTAssertFalse(store.profile.ownedCardIDs.contains(card.id))
        XCTAssertNil(store.profile.startingXICardIDs.first ?? nil)
        XCTAssertNil(store.profile.captainCardID)
    }

    func testUnsignedPlayerNeverGetsFinalSeason() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        store.profile.ownedCardIDs = [card.id]
        XCTAssertFalse(store.isFinalSeason(card))
        XCTAssertNil(store.profile.playerCareers[card.id])
    }

    func testRetirementTargetRoundTripsWithoutRerolling() throws {
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let original = LegendsStore.makeCareerState(for: card, signedSeason: 4)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegendsPlayerCareer.self, from: data)
        XCTAssertEqual(decoded.intendedRetirementAge, original.intendedRetirementAge)
        XCTAssertEqual(decoded.lifecycleProfile, original.lifecycleProfile)
    }

    func testMigratedLegacyCareerGetsGraceBeyondGeneratedTarget() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        let legacy = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        store.profile.playerCareers[card.id] = LegendsPlayerCareer(
            careerID: legacy.careerID, cardID: legacy.cardID, startingAge: legacy.startingAge,
            startingOverall: legacy.startingOverall, potential: legacy.potential,
            peakStartAge: legacy.peakStartAge, peakEndAge: legacy.peakEndAge,
            developmentRate: legacy.developmentRate, declineRate: legacy.declineRate,
            signedSeason: legacy.signedSeason)
        store.profile.cardAgeOffsets[card.id] = 30 - card.age
        let before = store.effectiveAge(for: card)
        store.migrateLegacyCareerStates()
        XCTAssertEqual(store.profile.playerCareers[card.id]?.intendedRetirementAge, before + 1)
        XCTAssertEqual(store.effectiveAge(for: card), before)
        XCTAssertFalse(store.profile.legendsHall.contains { $0.cardID == card.id })
    }
}
