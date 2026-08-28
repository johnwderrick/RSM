import XCTest
@testable import Retro_Season_Manager

final class LegendsPoint2MatchSelectorsTests: XCTestCase {
    func testPassingSelectorRewardsPassingAndVision() {
        var weak = LegendsDetailedAttributes.zero
        weak.passing = 40; weak.vision = 40; weak.decisions = 40; weak.firstTouch = 40
        var strong = weak
        strong.passing = 90; strong.vision = 90; strong.decisions = 90
        XCTAssertGreaterThan(LegendsMatchSelectors.passing(strong), LegendsMatchSelectors.passing(weak))
    }

    func testShootingSelectorRewardsFinishingAndComposure() {
        var weak = LegendsDetailedAttributes.zero
        weak.finishing = 40; weak.composure = 40; weak.longShots = 40; weak.firstTouch = 40
        var strong = weak
        strong.finishing = 90; strong.composure = 90
        XCTAssertGreaterThan(LegendsMatchSelectors.shooting(strong), LegendsMatchSelectors.shooting(weak))
    }

    func testGoalkeeperSelectorUsesGoalkeepingAttributes() {
        var weak = LegendsDetailedAttributes.zero
        weak.reflexes = 40; weak.handling = 40; weak.goalkeeperPositioning = 40; weak.oneOnOnes = 40
        var strong = weak
        strong.reflexes = 95; strong.handling = 95; strong.goalkeeperPositioning = 95; strong.oneOnOnes = 95
        XCTAssertGreaterThan(LegendsMatchSelectors.goalkeeper(strong), LegendsMatchSelectors.goalkeeper(weak))
    }

    func testSelectorsAreClamped() {
        var attributes = LegendsDetailedAttributes.zero
        attributes.finishing = 99; attributes.composure = 99; attributes.longShots = 99; attributes.firstTouch = 99
        XCTAssertLessThanOrEqual(LegendsMatchSelectors.shooting(attributes, pressure: 200), 99)
        XCTAssertGreaterThanOrEqual(LegendsMatchSelectors.shooting(attributes, pressure: 200), 0)
    }
}
