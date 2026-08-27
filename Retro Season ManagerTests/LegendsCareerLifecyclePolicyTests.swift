import XCTest
@testable import Retro_Season_Manager

final class LegendsCareerLifecyclePolicyTests: XCTestCase {
    func testProfileAssignmentIsDeterministic() {
        for card in LegendsCardDatabase.all {
            XCTAssertEqual(LegendsCareerLifecyclePolicy.profile(for: card.id),
                           LegendsCareerLifecyclePolicy.profile(for: card.id))
        }
    }

    func testRetirementTargetIsStableAndPositionAware() {
        guard let outfield = LegendsCardDatabase.all.first(where: { $0.position.broad != .goalkeeper }),
              let goalkeeper = LegendsCardDatabase.all.first(where: { $0.position.broad == .goalkeeper }) else {
            return XCTFail("Expected both an outfield player and goalkeeper")
        }
        let profile = LegendsCareerLifecyclePolicy.profile(for: outfield.id)
        let first = LegendsCareerLifecyclePolicy.retirementAge(for: outfield.id, position: outfield.position, profile: profile)
        let second = LegendsCareerLifecyclePolicy.retirementAge(for: outfield.id, position: outfield.position, profile: profile)
        XCTAssertEqual(first, second)
        XCTAssertGreaterThanOrEqual(LegendsCareerLifecyclePolicy.retirementAge(for: goalkeeper.id, position: goalkeeper.position, profile: .standardDeveloper), 36)
    }

    func testCareerBackfillsProfileAndRetirementTarget() {
        guard let card = LegendsCardDatabase.all.first else { return XCTFail("Expected card") }
        let state = LegendsStore.makeCareerState(for: card, signedSeason: 4)
        XCTAssertEqual(state.lifecycleProfile, LegendsCareerLifecyclePolicy.profile(for: card.id))
        XCTAssertGreaterThanOrEqual(state.intendedRetirementAge, 35)
        XCTAssertEqual(state.signedSeason, 4)
    }
}
