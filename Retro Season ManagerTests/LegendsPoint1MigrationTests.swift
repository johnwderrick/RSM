import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsPoint1MigrationTests: XCTestCase {
    func testLegacyPayloadDefaultsNewFieldsWithoutLosingCards() throws {
        let cardIDs = Array(LegendsCardDatabase.all.prefix(2)).map(\.id)
        let payload: [String: Any] = [
            "clubName": "Legacy FC", "crestShort": "LFC", "crestColorRGB": [0.1, 0.2, 0.3],
            "managerLevel": 1, "managerXP": 0, "coins": 10, "packTokens": 1,
            "division": 10, "teamRating": 0, "ownedCardIDs": cardIDs,
            "activatedCardIDs": [cardIDs[0]], "cardAgeOffsets": [cardIDs[0]: 3],
            "startingXICardIDs": Array(repeating: NSNull(), count: 11),
            "benchCardIDs": Array(repeating: NSNull(), count: 7)
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let profile = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertEqual(profile.ownedCardIDs, Set(cardIDs))
        XCTAssertEqual(profile.cardAgeOffsets[cardIDs[0]], 3)
        XCTAssertTrue(profile.favouriteCardIDs.isEmpty)
        XCTAssertTrue(profile.seasonReports.isEmpty)
    }

    func testCurrentReportRoundTripsExactly() throws {
        let report = LegendsSeasonDevelopmentReport(
            season: 4,
            entries: [LegendsSeasonReportEntry(cardID: "card", playerName: "Player", completedSeason: 4,
                                               ageBefore: 33, ageAfter: 34, overallBefore: 80, overallAfter: 81,
                                               previousStage: "DEVELOPING", newStage: "PRIME",
                                               developmentProfile: .standardDeveloper, improved: true,
                                               stable: false, declined: false, enteredFinalSeason: false,
                                               retired: false, position: .goalkeeper, favourite: true)],
            squadAgeWarning: "warning", positionsNeedingReplacements: ["DEFENDER"],
            signedAverageAgeBefore: 31, signedAverageAgeAfter: 32, createdAt: Date(timeIntervalSince1970: 100), schemaVersion: 1)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(LegendsSeasonDevelopmentReport.self, from: data)
        XCTAssertEqual(decoded, report)
    }
}
