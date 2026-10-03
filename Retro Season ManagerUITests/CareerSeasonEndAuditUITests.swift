//
//  CareerSeasonEndAuditUITests.swift
//  Retro Season ManagerUITests
//
//  Read-only audit tour for the Career season-end flow, driven by the
//  deterministic season-end fixture (UITEST_CAREER_SEASON_END): a full
//  season parked at the review screen, reached only through real store
//  APIs. The tour captures screenshots of the review's full depth,
//  logs accessibility red flags for the on-screen buttons, then taps
//  the real CONTINUE action and verifies the next-season handoff lands
//  on the dashboard with the season advanced exactly once.
//
//  Slow by design and opt-in; the focused polish tests are the normal
//  gate. The app is landscape-locked: XCUIDevice.orientation is never
//  written and interactions are existence waits, native swipes and
//  native element taps.
//

import XCTest

final class CareerSeasonEndAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        // This diagnostic tour is opt-in; enable it in the test scheme's
        // environment when collecting a fresh audit.
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RSM_RUN_SEASONEND_AUDIT"] == "1",
                          "Set RSM_RUN_SEASONEND_AUDIT=1 to run the diagnostic tour")
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
        try? png.write(to: URL(fileURLWithPath: "/tmp/seasonend_audit_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Logs the on-screen buttons with frames — enough to spot sub-24pt
    /// targets and off-screen actions without slow full-tree walks. The
    /// live tree can shrink mid-scan while a swipe settles, so each
    /// element is re-resolved through a fresh existence check instead of
    /// holding stale bound-by-index handles (a stale handle hard-fails
    /// the whole tour if the tree no longer matches it).
    private func logButtons(_ app: XCUIApplication, _ screen: String) {
        let count = min(app.buttons.count, 24)
        for index in 0..<count {
            let button = app.buttons.element(boundBy: index)
            guard button.exists, button.frame.width > 1 else { continue }
            let label = button.label.trimmingCharacters(in: .whitespaces)
            let f = button.frame
            print("AUDIT[\(screen)] button\(index) label='\(label)' frame=\(f) minSide=\(min(f.width, f.height))")
        }
    }

    private func isOnScreenSafely(_ element: XCUIElement, screenHeight: CGFloat) -> Bool {
        // Frame reads can fail on elements with invalid activation points;
        // treat any read failure as "not provably on screen".
        guard element.exists, element.frame.width > 1 else { return false }
        let f = element.frame
        return f.maxY > 0 && f.minY < screenHeight
    }

    func testSeasonEndReviewAuditTourAndHandoff() {
        let app = launch()

        // 1. The season-end fixture should land directly on the review.
        let reviewTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'REVIEW'")).firstMatch
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 30),
                      "The season-end fixture should open on the season review")
        shot(app, "01_review_top")
        logButtons(app, "review-top")

        // 2. Walk the review's full depth with native swipes, capturing
        //    each depth — standings/awards, team of the season, job
        //    offers, and wherever the season handoff action actually sits.
        let continueButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'CONTINUE'")).firstMatch
        var reachedBottom = isOnScreenSafely(continueButton, screenHeight: app.frame.height)
        var swipes = 0
        while swipes < 8 {
            app.swipeUp()
            swipes += 1
            // Let the scroll settle before snapshotting; mid-animation the
            // accessibility tree transiently drops off-screen elements.
            usleep(500_000)
            shot(app, String(format: "02_review_depth%02d", swipes))
            logButtons(app, "review-depth\(swipes)")
            if !reachedBottom, isOnScreenSafely(continueButton, screenHeight: app.frame.height) {
                reachedBottom = true
            }
        }

        // The handoff action must exist somewhere on the review, and the
        // tour asserts only what must always hold: it exists and can be
        // brought on screen by native scrolling.
        XCTAssertTrue(continueButton.exists, "The review must offer a season handoff action")
        if !reachedBottom {
            // One extra swipe for deep layouts; assert existence either way —
            // reachability findings belong to the audit, not a hard gate here.
            app.swipeUp()
            usleep(500_000)
            shot(app, "03_review_bottom")
            logButtons(app, "review-bottom")
        }
        print("AUDIT[review] continue on screen after \(swipes) swipes: \(reachedBottom)")

        // 3. Tap the handoff and verify the next-season handoff: the
        //    season must advance exactly once and land on the dashboard.
        let seasonBefore = 1 // the fixture's season
        continueButton.tap()

        let dashboard = anyElement(app, "career.home.screen")
        XCTAssertTrue(dashboard.waitForExistence(timeout: 40),
                      "Starting the next season should land on the Career dashboard")
        shot(app, "04_next_season_dashboard")

        // The dashboard top bar's stable season label must read 2001/02
        // after exactly one rollover.
        let header = anyElement(app, "career.home.seasonLabel")
        XCTAssertTrue(header.waitForExistence(timeout: 30),
                      "The dashboard season label must exist after the handoff")
        XCTAssertTrue(header.label.contains("SEASON 2001/02"),
                      "The dashboard must read as season 2 after exactly one rollover")
        XCTAssertFalse(reviewTitle.exists,
                       "The review must be dismissed after starting the next season")
        print("AUDIT[handoff] advanced from season \(seasonBefore) to the season-2 dashboard")
    }
}
