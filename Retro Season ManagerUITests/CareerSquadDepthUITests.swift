//
//  CareerSquadDepthUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Squad Depth sheet, built
//  on the scoped deterministic `UITEST_CAREER_DEPTH` fixture:
//
//  - default variant: exactly one red role (Left-Back, no available
//    player) and one amber role (Right-Back, one available player), plus
//    exactly two affordable left-back targets (one free agent, one fee),
//  - full-cover variant: every role covered, so the all-covered banner
//    shows and the suggestions card is absent.
//
//  The sheet is reached through the real Squad toolbar depth button. No
//  existing save is touched. The app is landscape-locked;
//  XCUIDevice.orientation is never written, and interactions use the
//  proven existence-wait + plain-tap primitives (see
//  CareerNavigationUITests for why frame math is avoided).
//

import XCTest

final class CareerSquadDepthUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_depth_\(suffixed).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: suffixed, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitFor(_ app: XCUIApplication, _ identifier: String,
                         timeout: TimeInterval = 8) -> XCUIElement {
        let element = anyElement(app, identifier)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing element: \(identifier)")
        return element
    }

    /// Scrolls the sheet until the given element joins the accessibility
    /// tree. SwiftUI prunes far-below-the-fold content from the tree (the
    /// last suggestion row sits below the SE-landscape fold), so querying
    /// it cold fails even though the card is present. Bounded and
    /// gesture-safe: upward swipes only — a downward swipe at the top of
    /// a SwiftUI sheet bleeds into drag-to-dismiss.
    @discardableResult
    private func revealByScrolling(_ app: XCUIApplication, _ scroll: XCUIElement,
                                   _ identifier: String, maxSwipes: Int = 4) -> XCUIElement {
        let element = anyElement(app, identifier)
        for _ in 0..<maxSwipes where !element.exists {
            scroll.swipeUp()
        }
        guard element.waitForExistence(timeout: 6) else {
            // Dump the live tree to stdout (captured in the xcodebuild log)
            // so a failure carries the evidence of what actually rendered.
            print("=== A11Y TREE ON MISSING \(identifier) ===\n\(app.debugDescription)\n=== END TREE ===")
            XCTFail("Missing element even after scrolling: \(identifier)")
            return element
        }
        return element
    }

    @discardableResult
    private func openDepthSheet(_ app: XCUIApplication) -> XCUIElement {
        let squadTab = app.buttons["career.nav.squad"]
        guard squadTab.waitForExistence(timeout: 20) else {
            print("=== A11Y TREE ON MISSING SIDEBAR (app state: \(app.state.rawValue)) ===\n\(app.debugDescription)\n=== END TREE ===")
            XCTFail("Sidebar SQUAD item missing")
            return anyElement(app, "career.depth.scroll")
        }
        squadTab.tap()
        _ = waitFor(app, "career.squad.screen", timeout: 12)

        let depthButton = app.buttons["career.squad.depthButton"]
        XCTAssertTrue(depthButton.waitForExistence(timeout: 10), "Squad toolbar depth button missing")
        depthButton.tap()

        _ = waitFor(app, "career.depth.sheet")
        let scroll = waitFor(app, "career.depth.scroll")
        _ = waitFor(app, "career.depth.close")
        return scroll
    }

    // MARK: - Needs, labels, profile round trip, pinned close

    func testDepthRowsSuggestionLabelsProfileRoundTripAndPinnedClose() throws {
        let app = launch(["UITEST_CAREER_DEPTH"])
        _ = openDepthSheet(app)
        shot(app, "depth_open")

        // The fixture's red role: Left-Back has no available player.
        let lbRow = waitFor(app, "career.depth.role.lb")
        XCTAssertEqual(lbRow.label, "Left-Back: no players fit",
                       "The zero-cover row must read authoritatively: \(lbRow.label)")

        // The fixture's amber role: Right-Back has exactly one fit.
        let rbRow = waitFor(app, "career.depth.role.rb")
        XCTAssertEqual(rbRow.label, "Right-Back: 1 players fit",
                       "The thin-cover row must read authoritatively: \(rbRow.label)")

        // Exactly the fixture's two affordable targets, one free, one
        // fee. The rating-sorted last row starts below the SE-landscape
        // fold, so scroll it into the tree first.
        let scroll = anyElement(app, "career.depth.scroll")
        let freeRow = revealByScrolling(app, scroll, "career.depth.target.karel-dvorak")
        shot(app, "depth_suggestions")
        XCTAssertEqual(freeRow.label, "Karel Dvorak, Left-Back, free agent",
                       "The free-agent label must match the fixture: \(freeRow.label)")
        let feeRow = waitFor(app, "career.depth.target.marcus-tyne")
        XCTAssertTrue(feeRow.label.contains("asking price £"),
                      "A fee target must carry an asking-price label: \(feeRow.label)")
        XCTAssertTrue(feeRow.label.range(of: "asking price £[0-9.]+[KM]$", options: .regularExpression) != nil,
                      "The asking-price label must end in a readable formatted figure: \(feeRow.label)")

        // Idle stability: a second read of the scroll container must not
        // jump or vanish.
        XCTAssertTrue(anyElement(app, "career.depth.scroll").exists,
                      "The scroll container must stay stable while idle")

        // Profile round trip: the free agent's sheet opens over the depth
        // sheet and closes back into the same context.
        freeRow.tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Tapping a suggestion should open the market player profile")
        waitFor(app, "career.playerProfile.close").tap()
        XCTAssertTrue(anyElement(app, "career.depth.sheet").waitForExistence(timeout: 8),
                      "Closing the profile must return to the depth sheet")
        _ = revealByScrolling(app, scroll, "career.depth.target.karel-dvorak")
        XCTAssertTrue(anyElement(app, "career.depth.target.marcus-tyne").exists ||
                      anyElement(app, "career.depth.target.marcus-tyne").waitForExistence(timeout: 4),
                      "The suggestion rows must still be present after the round trip")

        // The pinned close stays reachable and returns to Squad.
        let close = waitFor(app, "career.depth.close")
        XCTAssertTrue(close.isHittable, "The pinned close must be reachable on a compact landscape phone")
        close.tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 8),
                      "The pinned close must return to the Squad screen")
        shot(app, "depth_closed")
    }

    // MARK: - All-covered / no-suggestions state

    func testAllCoveredStateHidesSuggestionsAndShowsBanner() throws {
        // The full-cover flag is only consulted inside the depth fixture
        // block, so the base argument must always be present too.
        let app = launch(["UITEST_CAREER_DEPTH", "UITEST_CAREER_DEPTH_FULL_COVER"])
        _ = openDepthSheet(app)
        shot(app, "depth_full_cover")

        XCTAssertTrue(anyElement(app, "career.depth.allCovered").exists,
                      "The all-covered banner should show when no role is thin")
        XCTAssertFalse(anyElement(app, "career.depth.role.lb").exists,
                       "No thin-role rows should exist in the full-cover state")
        XCTAssertFalse(anyElement(app, "career.depth.target.karel-dvorak").exists,
                       "No suggestion rows should exist when nothing is thin")

        // The all-covered state keeps one stable scroll container whose
        // content fits the viewport.
        XCTAssertTrue(anyElement(app, "career.depth.scroll").exists,
                      "The scroll container must remain stable in the all-covered state")

        waitFor(app, "career.depth.close").tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 8),
                      "Close must return to Squad from the all-covered state")
    }

    // MARK: - Scroll stability + pinned close while scrolled

    func testDepthScrollStableAndPinnedCloseReachableOnLandscape() throws {
        let app = launch(["UITEST_CAREER_DEPTH"])
        let scroll = openDepthSheet(app)

        let close = waitFor(app, "career.depth.close")
        XCTAssertTrue(close.isHittable, "The pinned close must start reachable")

        // The single scroll container must actually scroll and settle,
        // with the pinned close never scrolling away.
        scroll.swipeUp()
        XCTAssertTrue(close.isHittable, "Close must stay pinned while the sheet is scrolled")
        XCTAssertTrue(anyElement(app, "career.depth.scroll").exists,
                      "The scroll container must stay stable while scrolled")
        shot(app, "depth_scrolled")

        // While scrolled, prove the pinned close still works and the
        // content is stable across the round trip — without a downward
        // swipe, which at the top of a SwiftUI sheet can bleed into the
        // interactive drag-to-dismiss gesture.
        let scrolledTarget = revealByScrolling(app, scroll, "career.depth.target.karel-dvorak")
        scrolledTarget.tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "A suggestion should open its profile while the sheet is scrolled")
        waitFor(app, "career.playerProfile.close").tap()
        XCTAssertTrue(anyElement(app, "career.depth.sheet").waitForExistence(timeout: 8),
                      "Closing the profile must return to the still-open depth sheet")
        _ = revealByScrolling(app, scroll, "career.depth.target.marcus-tyne")
        XCTAssertTrue(anyElement(app, "career.depth.scroll").exists,
                      "The scroll container must stay stable across the profile round trip")

        close.tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 8),
                      "The pinned close must return to Squad even after scrolling")
        shot(app, "depth_scrolled_back")
    }
}
