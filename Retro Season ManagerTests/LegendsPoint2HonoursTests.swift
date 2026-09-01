import XCTest
@testable import Retro_Season_Manager

final class LegendsPoint2HonoursTests: XCTestCase {
    func testHonourAndAwardRecordsPreserveCareerIdentity() throws {
        let honour = LegendsHonour(id: "S1-league-c", season: 1, competitionID: "league", competitionName: "Legends League", type: "CHAMPION", clubName: "RSM Legends FC", cardID: "card", careerID: "career")
        let award = LegendsIndividualAward(id: "S1-top-c", season: 1, type: "TOP SCORER", cardID: "card", careerID: "career", value: 12)
        let career = LegendsPlayerCareer(careerID: "career", cardID: "card", startingAge: 20, startingOverall: 70, potential: 80, peakStartAge: 24, peakEndAge: 30, developmentRate: 5, declineRate: 1, signedSeason: 1, honours: [honour], individualAwards: [award])
        let decoded = try JSONDecoder().decode(LegendsPlayerCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(decoded.honours, [honour])
        XCTAssertEqual(decoded.individualAwards, [award])
        XCTAssertEqual(decoded.honours.first?.careerID, "career")
    }

    func testFameIsBoundedAfterExceptionalMatch() {
        var condition = LegendsPlayerCondition()
        for _ in 0..<100 { condition.applyMatch(outcome: .win, goals: 4, assists: 3, cleanSheet: true) }
        XCTAssertEqual(condition.fame, 100)
        XCTAssertEqual(condition.form, 100)
        XCTAssertEqual(condition.morale, 100)
    }
}
