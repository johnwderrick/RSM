import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsPoint2IdentityTests: XCTestCase {
    func testIdentityAndDetailedAttributesAreDeterministicAndBounded() {
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let first = LegendsIdentityEngine.profile(for: card)
        let second = LegendsIdentityEngine.profile(for: card)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.identity.personID, LegendsIdentityEngine.profile(for: LegendsCardDatabase.all.first { $0.id == "miessi-1112" }!).identity.personID)
        for group in LegendsAttributeGroup.allCases {
            for (_, value) in first.attributes.values(in: group) { XCTAssertTrue((0...99).contains(value)) }
        }
    }

    func testSeasonalVariantsRemainDistinctDefinitions() {
        let first = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let second = LegendsCardDatabase.all.first { $0.id == "miessi-1112" }!
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.season, second.season)
    }

    func testConditionIsBoundedAndReturnsFormTowardNeutral() {
        var condition = LegendsPlayerCondition(form: 100, morale: 100, teamwork: 25, fame: 0)
        condition.applyMatch(outcome: .loss)
        XCTAssertEqual(condition.form, 97)
        condition.closeSeason(improved: false, declined: false, appearances: 0)
        XCTAssertLessThan(condition.form, 100)
        XCTAssertTrue((0...100).contains(condition.form))
        XCTAssertTrue((0...100).contains(condition.morale))
        XCTAssertTrue((0...100).contains(condition.teamwork))
    }

    func testDetailedEffectiveValuesRemainBounded() {
        let store = LegendsStore()
        let card = LegendsCardDatabase.all.first!
        let values = store.effectiveDetailedAttributes(for: card)
        for group in LegendsAttributeGroup.allCases {
            for (_, value) in values.values(in: group) { XCTAssertTrue((0...99).contains(value)) }
        }
    }
}
