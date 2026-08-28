import XCTest
@testable import Retro_Season_Manager

final class LegendsPoint2ConditionTests: XCTestCase {
    func testMatchAndSeasonConditionProgressionIsBounded() {
        var condition = LegendsPlayerCondition(form: 50, morale: 50, teamwork: 25, fame: 0)
        condition.applyMatch(outcome: .win, goals: 2, assists: 1, cleanSheet: true)
        XCTAssertGreaterThan(condition.form, 50)
        XCTAssertGreaterThan(condition.morale, 50)
        XCTAssertGreaterThan(condition.teamwork, 25)
        XCTAssertGreaterThan(condition.fame, 0)
        condition.closeSeason(improved: true, declined: false, appearances: 14)
        XCTAssertTrue((0...100).contains(condition.form))
        XCTAssertTrue((0...100).contains(condition.morale))
        XCTAssertTrue((0...100).contains(condition.teamwork))
        XCTAssertTrue((0...100).contains(condition.fame))
    }

    func testMissingConditionDecodesToNeutralDefaults() throws {
        let json = #"{"careerID":"c","cardID":"x","startingAge":20,"startingOverall":70}"#.data(using: .utf8)!
        let career = try JSONDecoder().decode(LegendsPlayerCareer.self, from: json)
        XCTAssertEqual(career.condition, LegendsPlayerCondition())
        XCTAssertEqual(career.honours, [])
        XCTAssertEqual(career.individualAwards, [])
    }

    func testConditionRoundTrips() throws {
        var career = LegendsPlayerCareer(cardID: "x", startingAge: 20, startingOverall: 70, potential: 80, peakStartAge: 24, peakEndAge: 30, developmentRate: 5, declineRate: 1, signedSeason: 1)
        career.condition = LegendsPlayerCondition(form: 73, morale: 61, teamwork: 48, fame: 22)
        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(LegendsPlayerCareer.self, from: data)
        XCTAssertEqual(decoded.condition, career.condition)
    }
}
