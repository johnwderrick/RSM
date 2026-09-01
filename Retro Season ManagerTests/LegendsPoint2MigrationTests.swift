import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsPoint2MigrationTests: XCTestCase {
    private let card = LegendsCardDatabase.all.first { $0.position.broad != .goalkeeper }!

    /// Builds a current-format profile payload with a signed career carrying
    /// Point 2 data, then strips every Point 2 field to simulate a pre-Point 2
    /// save: no identity profiles, no condition, no honours, no awards.
    private func legacyProfileData() throws -> Data {
        var profile = LegendsProfile.starter()
        profile.ownedCardIDs = [card.id]
        profile.activatedCardIDs = [card.id]
        profile.cardAgeOffsets = [card.id: 3]
        let career = LegendsStore.makeCareerState(for: card, signedSeason: 2)
        var migrated = career
        migrated.condition = LegendsPlayerCondition(form: 71, morale: 64, teamwork: 40, fame: 9)
        migrated.honours = [LegendsHonour(id: "H-1", season: 2, competitionID: "legends.division.5",
                                          competitionName: "DIVISION 5 TITLE", type: "LEAGUE CHAMPION",
                                          clubName: profile.clubName, cardID: card.id, careerID: career.careerID)]
        migrated.individualAwards = [LegendsIndividualAward(id: "A-1", season: 2, type: "TOP SCORER",
                                                            cardID: card.id, careerID: career.careerID, value: 12)]
        profile.playerCareers = [card.id: migrated]
        let data = try JSONEncoder().encode(profile)

        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "playerIdentityProfiles")
        var careers = object["playerCareers"] as! [String: Any]
        for (key, value) in careers {
            var careerDict = value as! [String: Any]
            careerDict.removeValue(forKey: "condition")
            careerDict.removeValue(forKey: "honours")
            careerDict.removeValue(forKey: "individualAwards")
            careerDict.removeValue(forKey: "identitySnapshot")
            careers[key] = careerDict
        }
        object["playerCareers"] = careers
        return try JSONSerialization.data(withJSONObject: object)
    }

    // MARK: - Legacy career payload

    func testLegacyPayloadRestoresNeutralConditionAndEmptyAchievements() throws {
        let profile = try JSONDecoder().decode(LegendsProfile.self, from: try legacyProfileData())

        // No card, ID or age loss during migration.
        XCTAssertEqual(profile.ownedCardIDs, Set([card.id]))
        XCTAssertEqual(profile.activatedCardIDs, Set([card.id]))
        XCTAssertEqual(profile.cardAgeOffsets[card.id], 3)

        // Documented neutral defaults for missing Point 2 fields.
        let career = profile.playerCareers[card.id]
        XCTAssertNotNil(career)
        XCTAssertEqual(career?.condition, LegendsPlayerCondition())
        XCTAssertEqual(career?.condition.form, 50)
        XCTAssertEqual(career?.condition.morale, 50)
        XCTAssertEqual(career?.condition.teamwork, 25)
        XCTAssertEqual(career?.condition.fame, 0)
        XCTAssertEqual(career?.honours, [])
        XCTAssertEqual(career?.individualAwards, [])

        // Lifecycle backfill is deterministic: the decoded target matches a
        // fresh generation from the same card identity.
        XCTAssertEqual(career?.intendedRetirementAge,
                       LegendsStore.makeCareerState(for: card, signedSeason: 2).intendedRetirementAge)
    }

    func testRepeatedLegacyDecodingIsStableAndNeverMutatesCareers() throws {
        let data = try legacyProfileData()
        let first = try JSONDecoder().decode(LegendsProfile.self, from: data)
        let second = try JSONDecoder().decode(LegendsProfile.self, from: data)

        // Decoding alone never ages, retires, or generates achievements.
        XCTAssertEqual(first.cardAgeOffsets[card.id], 3)
        XCTAssertEqual(second.cardAgeOffsets[card.id], first.cardAgeOffsets[card.id])
        XCTAssertTrue(first.legendsHall.isEmpty, "Decoding must not create retirement records")
        XCTAssertNotNil(first.playerCareers[card.id], "Decoding must not retire signed players")
        XCTAssertEqual(first.playerCareers[card.id]?.honours ?? [], [], "Decoding must not generate achievements")
        XCTAssertEqual(first.playerCareers[card.id]?.condition, second.playerCareers[card.id]?.condition)
    }

    func testMissingIdentityProfilesGenerateDeterministicallyThenPersist() async throws {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        store.profile.playerIdentityProfiles = [:]

        let first = store.ensureIdentityProfile(for: card)
        let second = store.ensureIdentityProfile(for: card)
        XCTAssertEqual(first, second, "Identity resolution must be deterministic")
        XCTAssertNotNil(store.profile.playerIdentityProfiles[card.id], "Generated identity must persist")

        // Persisting and reloading keeps the identity stable — repeated
        // decoding never rerolls a person's foot, archetype or attributes.
        let data = try JSONEncoder().encode(store.profile)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertEqual(decoded.playerIdentityProfiles[card.id], first)
        let reencoded = try JSONEncoder().encode(decoded)
        let decodedAgain = try JSONDecoder().decode(LegendsProfile.self, from: reencoded)
        XCTAssertEqual(decodedAgain.playerIdentityProfiles[card.id], first)
    }

    // MARK: - Legacy Alumni payload

    func testLegacyHallEntryDecodesWithSafeDefaults() throws {
        let entry = LegendsHallEntry(id: "career-1", cardID: "card-1", playerName: "Veteran Keeper",
                                     position: .goalkeeper, nation: "RSM", startingAge: 24,
                                     startingOverall: 78, highestOverall: 84, finalAge: 36,
                                     appearances: 300, goals: 0, assists: 1, cleanSheets: 90,
                                     seasonsAtClub: 12, signedSeason: 1, retiredSeason: 13)
        let data = try JSONEncoder().encode(entry)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for key in ["finalOverall", "trophies", "milestones", "isClubLegend", "legacyScore",
                    "careerHistory", "identityProfile", "finalCondition", "honours", "individualAwards"] {
            object.removeValue(forKey: key)
        }
        let legacy = try JSONDecoder().decode(LegendsHallEntry.self,
                                              from: try JSONSerialization.data(withJSONObject: object))

        XCTAssertEqual(legacy.finalCondition, LegendsPlayerCondition())
        XCTAssertTrue(legacy.honours.isEmpty)
        XCTAssertTrue(legacy.individualAwards.isEmpty)
        XCTAssertNil(legacy.identityProfile)
        XCTAssertEqual(legacy.appearances, 300)
        XCTAssertEqual(legacy.finalAge, 36)
        XCTAssertEqual(legacy.cleanSheets, 90)
    }

    // MARK: - Current-format round trip

    func testCurrentFormatCareerRoundTripsExactly() throws {
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 3)
        career.condition = LegendsPlayerCondition(form: 88, morale: 70, teamwork: 61, fame: 42)
        career.honours = [LegendsHonour(id: "H-S3-division", season: 3, competitionID: "legends.division.5",
                                        competitionName: "DIVISION 5 TITLE", type: "LEAGUE CHAMPION",
                                        clubName: "RSM Legends FC", cardID: card.id, careerID: career.careerID)]
        career.individualAwards = [LegendsIndividualAward(id: "A-S3-TOPSCORER", season: 3, type: "TOP SCORER",
                                                          cardID: card.id, careerID: career.careerID, value: 14)]
        career.identitySnapshot = LegendsIdentityEngine.profile(for: card)

        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(LegendsPlayerCareer.self, from: data)
        XCTAssertEqual(decoded, career)
        XCTAssertEqual(decoded.condition.fame, 42)
        XCTAssertEqual(decoded.honours.first?.careerID, career.careerID)
        XCTAssertEqual(decoded.individualAwards.first?.value, 14)
        XCTAssertEqual(decoded.identitySnapshot, career.identitySnapshot)
    }

    func testCurrentFormatProfileRoundTripsExactly() throws {
        var profile = LegendsProfile.starter()
        profile.ownedCardIDs = [card.id]
        profile.activatedCardIDs = [card.id]
        profile.cardAgeOffsets = [card.id: 5]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.condition = LegendsPlayerCondition(form: 66, morale: 58, teamwork: 33, fame: 12)
        career.honours = [LegendsHonour(id: "H-S1", season: 1, competitionID: "legends.division.5",
                                        competitionName: "DIVISION 5 TITLE", type: "LEAGUE CHAMPION",
                                        clubName: profile.clubName, cardID: card.id, careerID: career.careerID)]
        profile.playerCareers = [card.id: career]
        profile.playerIdentityProfiles = [card.id: LegendsIdentityEngine.profile(for: card)]
        profile.legendsHall = [LegendsHallEntry(id: "old-career", cardID: "old-card", playerName: "Old Legend",
                                                position: .striker, nation: "RSM", startingAge: 22,
                                                startingOverall: 75, highestOverall: 86, finalAge: 35,
                                                appearances: 280, goals: 150, assists: 60, cleanSheets: 0,
                                                seasonsAtClub: 13, signedSeason: 1, retiredSeason: 14,
                                                finalCondition: LegendsPlayerCondition(form: 40, morale: 55, teamwork: 90, fame: 88),
                                                honours: [LegendsHonour(id: "H-old", season: 9, competitionID: "legends.division.4",
                                                                        competitionName: "DIVISION 4 TITLE", type: "LEAGUE CHAMPION",
                                                                        clubName: profile.clubName, cardID: "old-card", careerID: "old-career")])]

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        let reencoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as! NSDictionary,
                       try JSONSerialization.jsonObject(with: reencoded) as! NSDictionary,
                       "Current-format saves must round-trip exactly")

        // No decode-time retirement for the overdue player either.
        XCTAssertTrue(decoded.legendsHall.count == 1, "The pre-existing Alumni entry survives; no new records appear")
        XCTAssertEqual(decoded.playerCareers[card.id]?.condition.fame, 12)
        XCTAssertEqual(decoded.cardAgeOffsets[card.id], 5)
    }

    // MARK: - Award-then-retire ordering with an overdue save

    func testOverdueSignedPlayerReceivesGraceTargetNotDecodeTimeRetirement() async {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        // A pre-Point 1 career carries the legacy sentinel target; the save's
        // effective age is far beyond any generated target, so migration must
        // grant one final season of grace — never retire during load.
        var legacy = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        legacy.intendedRetirementAge = LegendsStore.retirementAge
        store.profile.playerCareers[card.id] = legacy
        store.profile.cardAgeOffsets = [card.id: 45 - card.age]
        store.migrateLegacyCareerStates()

        let state = store.profile.playerCareers[card.id]
        XCTAssertNotNil(state, "Migration must preserve the signed career")
        XCTAssertEqual(store.effectiveAge(for: card), 45)
        XCTAssertEqual(state?.intendedRetirementAge, 46, "Overdue players receive current age + 1 grace")
        XCTAssertTrue(store.profile.legendsHall.isEmpty, "No retirement record is created during migration")
        XCTAssertTrue(store.isFinalSeason(card), "The grace season is the player's Final Season")
        XCTAssertFalse(store.profile.ownedCardIDs.isEmpty, "Migration never removes cards")
    }
}
