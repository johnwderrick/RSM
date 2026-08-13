import XCTest
@testable import Retro_Season_Manager

/// `ClubNegotiationStance` is a pure enum with no dependency on a live
/// `GameStore` — these run as plain synchronous tests.
final class NegotiationFormulaTests: XCTestCase {
    func testHardnessMultiplierOrdering() {
        // Desperate clubs should be the easiest to deal with, difficult
        // clubs the hardest, balanced sitting at exactly neutral (1.0).
        XCTAssertEqual(ClubNegotiationStance.balanced.hardnessMultiplier, 1.0)
        XCTAssertLessThan(ClubNegotiationStance.desperate.hardnessMultiplier, ClubNegotiationStance.flexible.hardnessMultiplier)
        XCTAssertLessThan(ClubNegotiationStance.flexible.hardnessMultiplier, ClubNegotiationStance.balanced.hardnessMultiplier)
        XCTAssertLessThan(ClubNegotiationStance.balanced.hardnessMultiplier, ClubNegotiationStance.protective.hardnessMultiplier)
        XCTAssertLessThan(ClubNegotiationStance.protective.hardnessMultiplier, ClubNegotiationStance.difficult.hardnessMultiplier)
    }

    func testStarPlayerHardnessOnlyAppliesToProtectiveClubsWithGenuineStars() {
        // The extra resistance is deliberately narrow: protective stance
        // AND a rating ≥ 80. Every other combination should be neutral.
        XCTAssertEqual(ClubNegotiationStance.protective.starPlayerHardness(rating: 80), 1.25)
        XCTAssertEqual(ClubNegotiationStance.protective.starPlayerHardness(rating: 99), 1.25)
        XCTAssertEqual(ClubNegotiationStance.protective.starPlayerHardness(rating: 79), 1.0)
        XCTAssertEqual(ClubNegotiationStance.difficult.starPlayerHardness(rating: 90), 1.0)
        XCTAssertEqual(ClubNegotiationStance.balanced.starPlayerHardness(rating: 90), 1.0)
    }

    func testEveryStanceHasADisplayLabel() {
        for stance in ClubNegotiationStance.allCases {
            XCTAssertFalse(stance.displayLabel.isEmpty)
        }
    }
}
