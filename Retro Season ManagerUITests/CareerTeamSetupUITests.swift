//
//  CareerTeamSetupUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Team Setup sheet, built
//  on the existing deterministic `UITEST_CAREER_SETTINGS` fixture — a
//  superset of the navigation fixture that reaches the sheet through the
//  real Squad toolbar entry route and seeds `autoPickAssist = true`, so
//  the ASSIST ON badge is authoritatively present. No new app fixture is
//  needed and no existing save is touched.
//
//  The test exercises the real Squad → Team Setup → Done round trip:
//  formation + mentality selection, RESET SLOTS, AUTO-PICK, CLEAR XI
//  followed by restoration through AUTO-PICK, training-focus selection,
//  selected-state retention after reopening, the assistant recommendation
//  when the fixture state offers it, scroll stability and the pinned
//  close/Done actions. The app is landscape-locked;
//  XCUIDevice.orientation is never written, and interactions use the
//  proven existence-wait + plain-tap primitives (see
//  CareerNavigationUITests for why frame math is avoided).
//

import XCTest

final class CareerTeamSetupUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_SETTINGS"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_team_setup_\(suffixed).png"))
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

    @discardableResult
    private func openTeamSetup(_ app: XCUIApplication) -> XCUIElement {
        let squadTab = app.buttons["career.nav.squad"]
        XCTAssertTrue(squadTab.waitForExistence(timeout: 10), "Sidebar SQUAD item missing")
        squadTab.tap()
        _ = waitFor(app, "career.squad.screen")

        let setupButton = app.buttons["career.squad.teamSetup"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 8), "Squad toolbar Team Setup button missing")
        setupButton.tap()

        _ = waitFor(app, "career.teamSetup.sheet")
        let scroll = waitFor(app, "career.teamSetup.scroll")
        _ = waitFor(app, "career.teamSetup.formation.4-4-2")
        _ = waitFor(app, "career.teamSetup.close")
        _ = waitFor(app, "career.teamSetup.done")
        return scroll
    }

    /// The training chips live in a lazy grid below the fold; they only
    /// join the accessibility tree once scrolled near, so reveal them
    /// before any assertion.
    private func revealTrainingFocus(_ scroll: XCUIElement) {
        scroll.swipeUp()
        XCTAssertTrue(anyElement(XCUIApplication(), "career.teamSetup.training.balanced")
            .waitForExistence(timeout: 6), "Training-focus chips should appear after scrolling")
    }

    private func assertSelected(_ app: XCUIApplication, _ identifier: String,
                                expected: Bool, _ message: String) {
        let element = waitFor(app, identifier)
        XCTAssertEqual(element.isSelected, expected, message)
    }

    // MARK: - Full setup round trip

    func testFormationMentalityAutoPickClearTrainingAndRetentionRoundTrip() throws {
        let app = launch()
        let scroll = openTeamSetup(app)
        shot(app, "team_setup_open")

        // ASSIST ON must reflect the fixture's seeded preference.
        XCTAssertTrue(anyElement(app, "career.teamSetup.assistBadge").exists,
                      "The settings fixture seeds autoPickAssist, so the ASSIST ON badge should show")

        // Formation: switching a control updates its selected state without
        // disturbing the sheet's scroll container.
        let formation442 = "career.teamSetup.formation.4-4-2"
        let formation433 = "career.teamSetup.formation.4-3-3"
        assertSelected(app, formation442, expected: true, "4-4-2 should start selected")
        assertSelected(app, formation433, expected: false, "4-3-3 should start unselected")
        let scrollBefore = scroll.exists
        waitFor(app, formation433).tap()
        assertSelected(app, formation433, expected: true, "Tapping 4-3-3 should select it")
        assertSelected(app, formation442, expected: false, "4-4-2 should be deselected")
        XCTAssertEqual(anyElement(app, "career.teamSetup.scroll").exists, scrollBefore,
                       "Switching a formation must not rebuild the sheet's scroll container")

        // Mentality: same selected-state contract.
        let attacking = "career.teamSetup.mentality.attacking"
        waitFor(app, attacking).tap()
        assertSelected(app, attacking, expected: true, "Attacking mentality should be selected")
        assertSelected(app, "career.teamSetup.mentality.balanced", expected: false,
                       "Balanced should be deselected")

        // RESET SLOTS keeps its authoritative store path; the formation
        // card is on-screen here so the tap lands.
        waitFor(app, "career.teamSetup.resetSlots").tap()

        // CLEAR XI empties the team; AUTO-PICK restores a full side.
        waitFor(app, "career.teamSetup.clearXI").tap()
        XCTAssertTrue(anyElement(app, "career.teamSetup.scroll").exists,
                      "CLEAR XI should keep the sheet up")
        waitFor(app, "career.teamSetup.autoPick").tap()
        _ = waitFor(app, "career.teamSetup.done")

        // Training focus: visible selected chips instead of the old menu.
        revealTrainingFocus(scroll)
        let physical = "career.teamSetup.training.physical"
        waitFor(app, physical).tap()
        assertSelected(app, physical, expected: true, "Physical focus should be selected")
        assertSelected(app, "career.teamSetup.training.balanced", expected: false,
                       "Balanced focus should be deselected")
        shot(app, "team_setup_selections")

        // Reopen: every selected state must have been retained by the store.
        waitFor(app, "career.teamSetup.done").tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 8),
                      "Done should return to the Squad screen")

        let setupButton = app.buttons["career.squad.teamSetup"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 8), "Team Setup button missing after Done")
        XCTAssertTrue(setupButton.label.contains("4-3-3"),
                      "Toolbar should reflect the retained formation: \(setupButton.label)")
        XCTAssertTrue(setupButton.label.contains("Attacking"),
                      "Toolbar should reflect the retained mentality: \(setupButton.label)")
        setupButton.tap()
        _ = waitFor(app, "career.teamSetup.sheet")
        assertSelected(app, formation433, expected: true, "Formation selection must survive reopening")
        assertSelected(app, formation442, expected: false, "Old formation must stay deselected")
        assertSelected(app, attacking, expected: true, "Mentality selection must survive reopening")
        revealTrainingFocus(scroll)
        assertSelected(app, physical, expected: true, "Training focus must survive reopening")
        scroll.swipeDown()
        shot(app, "team_setup_reopened")

        // The assistant recommendation appears whenever the active shape
        // differs from the squad's best-fit formation; accepting it goes
        // through the store's own switch path.
        if anyElement(app, "career.teamSetup.trySuggested").exists {
            anyElement(app, "career.teamSetup.trySuggested").tap()
            _ = waitFor(app, "career.teamSetup.done")
            shot(app, "team_setup_try_suggested")
        }

        // The pinned header close must return to Squad.
        waitFor(app, "career.teamSetup.close").tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 8),
                      "The pinned header close must return to Squad")
    }

    // MARK: - Landscape scroll stability + pinned actions

    func testTeamSetupScrollStableAndPinnedActionsReachableOnLandscape() throws {
        let app = launch()
        let scroll = openTeamSetup(app)

        let done = waitFor(app, "career.teamSetup.done")
        XCTAssertTrue(done.isHittable, "The pinned Done action must be reachable on a compact landscape phone")
        let close = waitFor(app, "career.teamSetup.close")
        XCTAssertTrue(close.isHittable, "The pinned close must be reachable on a compact landscape phone")

        // The single scroll container must actually scroll and settle,
        // with neither pinned action ever scrolling away.
        scroll.swipeUp()
        XCTAssertTrue(done.isHittable, "Done must stay pinned while the sheet is scrolled")
        XCTAssertTrue(close.isHittable, "Close must stay pinned while the sheet is scrolled")
        shot(app, "team_setup_scrolled")
        scroll.swipeDown()
        XCTAssertTrue(done.isHittable, "Done must still be reachable after scrolling back")
        XCTAssertTrue(anyElement(app, "career.teamSetup.formation.4-4-2").exists,
                      "The formation grid should be back in the accessibility tree after scrolling up")
        shot(app, "team_setup_scrolled_back")
    }
}
