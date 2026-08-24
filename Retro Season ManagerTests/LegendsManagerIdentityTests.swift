import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsManagerIdentityTests: XCTestCase {
    func testExactlyFiveArchetypesHaveDistinctIdentityData() {
        XCTAssertEqual(LegendsManagerArchetype.allCases.count, 5)
        XCTAssertEqual(Set(LegendsManagerArchetype.allCases.map(\.nickname)).count, 5)
        XCTAssertEqual(Set(LegendsManagerArchetype.allCases.map(\.trait)).count, 5)
        XCTAssertTrue(LegendsManagerArchetype.allCases.allSatisfy { !$0.description.isEmpty && !$0.formation.isEmpty })
    }

    func testNamesAcceptUnicodeApostrophesAndHyphensButRejectBlankOrPunctuation() {
        XCTAssertTrue(LegendsManagerIdentityValidation.validName("  José  "))
        XCTAssertTrue(LegendsManagerIdentityValidation.validName("O'Neill"))
        XCTAssertTrue(LegendsManagerIdentityValidation.validName("Anne-Marie"))
        XCTAssertEqual(LegendsManagerIdentityValidation.cleanName("  Anne   Marie "), "Anne Marie")
        XCTAssertFalse(LegendsManagerIdentityValidation.validName("   "))
        XCTAssertFalse(LegendsManagerIdentityValidation.validName("James!"))
    }

    func testManagerProfileRoundTripsWithoutDuplicatingLevelAndXP() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var profile = LegendsManagerProfile(firstName: "Alex", surname: "Morgan-Son", nationalityCode: "Scotland", dateOfBirth: date, archetype: .maverick)
        profile.reputation = 42
        profile.earnedNicknames.insert(.entertainer)
        profile.activeNickname = .entertainer
        profile.careerStats.matches = 12
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(LegendsManagerProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
        XCTAssertEqual(decoded.archetype, .maverick)
        XCTAssertEqual(decoded.activeNickname, .entertainer)
    }

    func testNewStarterProfileNeedsIdentityButKeepsLegendsStateSeparate() throws {
        let starter = LegendsProfile.starter()
        XCTAssertNil(starter.managerProfile)
        XCTAssertEqual(starter.managerLevel, 1)
        XCTAssertEqual(starter.coins, 500)
        let data = try JSONEncoder().encode(starter)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertNil(decoded.managerProfile)
        XCTAssertEqual(decoded.ownedCardIDs, starter.ownedCardIDs)
    }

    func testManagerAgeAndDateBounds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let age38 = calendar.date(from: DateComponents(year: 1988, month: 1, day: 1))!
        let age29 = calendar.date(from: DateComponents(year: 1997, month: 1, day: 1))!
        let age71 = calendar.date(from: DateComponents(year: 1955, month: 1, day: 1))!
        XCTAssertTrue(LegendsManagerIdentityValidation.validDateOfBirth(age38, now: now, calendar: calendar))
        XCTAssertFalse(LegendsManagerIdentityValidation.validDateOfBirth(age29, now: now, calendar: calendar))
        XCTAssertFalse(LegendsManagerIdentityValidation.validDateOfBirth(age71, now: now, calendar: calendar))
        XCTAssertEqual(LegendsManagerProfile(firstName: "A", surname: "B", nationalityCode: "England", dateOfBirth: age38, archetype: .architect).age(referenceDate: now, calendar: calendar), 38)
    }
}
