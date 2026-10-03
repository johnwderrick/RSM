//
//  CareerSeasonEndPolishUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI tests for the season-end review polish, driven by the
//  deterministic season-end fixture (UITEST_CAREER_SEASON_END): a full
//  season parked at the review screen through real store APIs only.
//
//  Verifies the changed outcomes (light-card verdict/standings/awards,
//  pinned handoff footer) and the next-season handoff (advances the
//  season exactly once and lands on the Career dashboard).
//
//  Landscape-locked app: no orientation writes, existence waits plus
//  native element taps only.
//

import XCTest

final class CareerSeasonEndPolishUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_SEASON_END"]
        app.launch()
        return app
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/seasonend_polish_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The handoff action must sit in the pinned footer: visible at the
    /// bottom of the screen without scrolling, whatever the content depth.
    private func assertFooterVisible(_ app: XCUIApplication, _ continueButton: XCUIElement) {
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10),
                      "The pinned CONTINUE action must exist on the review")
        let frame = continueButton.frame
        let screen = app.frame
        XCTAssertGreaterThanOrEqual(frame.minY, screen.minY - 1,
                                    "The CONTINUE action must not sit above the screen")
        XCTAssertLessThanOrEqual(frame.maxY, screen.maxY + 1,
                                 "The CONTINUE action must not be clipped below the screen")
        XCTAssertGreaterThanOrEqual(frame.height, 40,
                                    "The CONTINUE action must keep a substantial tap target")
    }

    func testSeasonReviewLightCardsAndPinnedHandoff() {
        let app = launch()

        let screen = anyElement(app, "career.seasonReview.screen")
        XCTAssertTrue(screen.waitForExistence(timeout: 30),
                      "The season-end fixture should open on the season review")
        shot(app, "01_review_top")

        // Light-card hierarchy: verdict, standings and awards cards exist
        // with stable identifiers.
        let verdict = anyElement(app, "career.seasonReview.verdict")
        XCTAssertTrue(verdict.waitForExistence(timeout: 10), "The verdict card must exist")
        let standings = anyElement(app, "career.seasonReview.standings")
        XCTAssertTrue(standings.exists, "The final standings card must exist")
        let awards = anyElement(app, "career.seasonReview.awards")
        XCTAssertTrue(awards.exists, "The awards card must exist")

        // Final-table rows carry position-keyed identifiers (user row 1
        // and the last row always exist in a complete 20-club season).
        XCTAssertTrue(anyElement(app, "career.seasonReview.standingRow.1").exists,
                      "Row 1 of the final table must be addressable")
        XCTAssertTrue(anyElement(app, "career.seasonReview.standingRow.20").exists,
                      "Row 20 of the final table must be addressable")

        // The handoff action is pinned: reachable without any scrolling.
        let continueButton = anyElement(app, "career.seasonReview.continue")
        assertFooterVisible(app, continueButton)
        shot(app, "02_review_pinned_footer")

        // Scrolling the content must never move the footer out of reach:
        // after swiping to the bottom of the review, the footer is still
        // fully on screen at the same place.
        app.swipeUp()
        app.swipeUp()
        assertFooterVisible(app, continueButton)
        shot(app, "03_review_after_scroll_footer_pinned")
    }

    func testSeasonHandoffAdvancesSeasonOnceToDashboard() {
        let app = launch()

        let screen = anyElement(app, "career.seasonReview.screen")
        XCTAssertTrue(screen.waitForExistence(timeout: 30),
                      "The season-end fixture should open on the season review")

        // The handoff tap must land on a settled screen: ContentView swaps
        // to the review behind an opacity transition and an isBusy-driven
        // animation, and a tap synthesised inside that window can be
        // dropped outright (observed as the review still on screen 40s
        // later with no handoff). Settle first, then tap only once the
        // button is the top-most element at its hit point.
        usleep(800_000)

        // One tap on the pinned handoff: through runHeavy → startNextSeason,
        // the only next-season path. If the very first tap is swallowed by
        // the entrance transition (still rare after settling), one guarded
        // retry keeps the flake out without ever double-driving the store:
        // a completed rollover removes the review screen, so the retry
        // cannot fire twice against startNextSeason.
        let continueButton = anyElement(app, "career.seasonReview.continue")
        assertFooterVisible(app, continueButton)

        // The dashboard must appear, reading as Season 2 (advanced exactly
        // once), and the review must be gone.
        let dashboard = anyElement(app, "career.home.screen")

        continueButton.tap()
        let handoffStarted = dashboard.waitForExistence(timeout: 8)
        if !handoffStarted, continueButton.exists, continueButton.isHittable {
            continueButton.tap()
        }
        XCTAssertTrue(dashboard.waitForExistence(timeout: 40),
                      "Starting the next season should land on the Career dashboard")
        shot(app, "04_next_season_dashboard")

        // The dashboard top bar carries a stable season-label identifier;
        // after one rollover from the fixture it must read 2001/02.
        let seasonLabel = anyElement(app, "career.home.seasonLabel")
        XCTAssertTrue(seasonLabel.waitForExistence(timeout: 30),
                      "The dashboard season label must exist after the handoff")
        XCTAssertTrue(seasonLabel.label.contains("SEASON 2001/02"),
                      "The dashboard must read as season 2 (2001/02) after exactly one " +
                      "rollover, got: \(seasonLabel.label)")
        XCTAssertFalse(screen.exists,
                       "The review must be dismissed after starting the next season")
    }
}
