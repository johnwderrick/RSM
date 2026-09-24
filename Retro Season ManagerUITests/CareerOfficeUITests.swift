//
//  CareerOfficeUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Manager tab,
//  built on the deterministic `UITEST_CAREER_OFFICE` fixture (itself
//  built on the shared Career navigation fixture, which plays three
//  matchdays and seeds a manager named "Nav Fixture Manager"):
//
//  A. Overview: the summary band shows the fixture's authoritative career
//     figures (one club spell, 70 matches, 66% win rate, 3 trophies),
//     the trophy shelf renders the honours, and the autobiography card is
//     present; the tab scrolls to its end anchor through the single
//     container.
//  B. Timeline: switching tabs shows the fixture's beats (2000 takeover
//     through 2002 achievements) as connected rows, and the scrapbook
//     tab shows the moment photos plus the two historic front pages;
//     opening a front page shows the article and dismissing it returns
//     to the same scrapbook state.
//  C. Lower-content reachability + return navigation: the timeline
//     scrolls to its last row and holds its position while idle; the
//     sidebar reaches Settings and returns to Manager cleanly.
//
//  Same primitive discipline as the accepted suites: existence waits on
//  freshly-queried elements, swipes on the named scroll container, and
//  plain element taps. XCUIDevice.orientation is never written — the app
//  is landscape-locked and orientation writes cause rotation churn.
//

import XCTest

final class CareerOfficeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_OFFICE"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_office_\(suffixed).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: suffixed, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func exists(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 4) -> Bool {
        app.descendants(matching: .any)[id].firstMatch.waitForExistence(timeout: timeout)
    }

    @discardableResult
    private func waitFor(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let el = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Missing element: \(id)")
        return el
    }

    /// Manager sits below Club in the scrollable sidebar on compact phones.
    private func openOffice(_ app: XCUIApplication) -> XCUIApplication {
        let tab = app.buttons["career.nav.manager"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Manager sidebar item missing")
        let scroll = app.scrollViews["career.nav.sidebarScroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        tab.tap()
        XCTAssertTrue(exists(app, "career.manager.screen", 8), "Manager destination missing")
        XCTAssertTrue(tab.isSelected, "Manager sidebar item should be selected")
        XCTAssertTrue(exists(app, "career.office.header", 8), "Manager Office content missing")
        XCTAssertTrue(exists(app, "career.office.tab.overview", 4), "Overview tab missing")
        return app
    }

    /// Reveals an element inside the office scroll container until its
    /// centre is within the container's visible band.
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ identifier: String, maxSwipes: Int = 10) -> XCUIElement {
        let element = waitFor(app, identifier)
        let scroll = app.scrollViews["career.office.scroll"].firstMatch
        guard scroll.exists else { return element }
        var swipes = 0
        while swipes < maxSwipes {
            let frame = element.frame
            let visible = scroll.frame
            let centreY = frame.minY + frame.height * 0.5
            let centreInside = centreY <= visible.maxY - 8 && frame.minY >= visible.minY
            if centreInside { break }
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        return element
    }

    // MARK: - A. Overview tab: summary, trophy shelf, story, scroll

    func testOverviewShowsAuthoritativeCareerFiguresAndScrolls() throws {
        let app = openOffice(launch())

        // Summary band with the fixture's authoritative figures: one club
        // spell (both history records are at the same club), 70 matches
        // (46W+12D+12L), 66% win rate, 3 trophies.
        let summary = waitFor(app, "career.office.summary")
        XCTAssertTrue(summary.label.contains("1 club"), "Summary should show 1 club spell: \(summary.label)")
        XCTAssertTrue(summary.label.contains("70 matches"), "Summary should show 70 matches: \(summary.label)")
        XCTAssertTrue(summary.label.contains("66 percent"), "Summary should show the 66% win rate: \(summary.label)")
        XCTAssertTrue(summary.label.contains("3 trophies"), "Summary should show 3 trophies: \(summary.label)")
        shot(app, "office_overview")

        // Trophy shelf renders both named trophies and honours without a
        // bespoke TrophyKind silhouette.
        waitFor(app, "career.office.trophyShelf")
        XCTAssertTrue(exists(app, "career.office.trophy.0", 6), "First trophy missing from the shelf")

        // The generated autobiography card is present.
        waitFor(app, "career.office.story")

        // Scroll to the tab's end anchor through the single container.
        let scroll = app.scrollViews["career.office.scroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(exists(app, "career.office.trophy.3", 6),
                      "Unclassified honour should remain visible on the shelf")
        XCTAssertTrue(exists(app, "career.office.overview.end", 6), "Overview end anchor missing")
        shot(app, "office_overview_scrolled")

        // Timeline and scrapbook tabs are reachable without closing.
        XCTAssertTrue(exists(app, "career.office.tab.timeline", 4), "Timeline tab missing")
        XCTAssertTrue(exists(app, "career.office.tab.scrapbook", 4), "Scrapbook tab missing")
    }

    // MARK: - B. Timeline + scrapbook tabs

    func testTimelineListsBeatsAndScrapbookShowsPhotosAndFrontPages() throws {
        let app = openOffice(launch())

        // Switch to the Timeline tab: the fixture's beats span the 2000
        // takeover through the 2002 achievements.
        waitFor(app, "career.office.tab.timeline").tap()
        XCTAssertTrue(waitFor(app, "career.timeline.row.2000", 8).exists, "First timeline beat (2000) missing")
        XCTAssertTrue(exists(app, "career.timeline.row.2002", 6), "Achievement beats (2002) missing")
        let summaryGone = !app.descendants(matching: .any)["career.office.summary"].exists
        XCTAssertTrue(summaryGone, "Overview content should not linger on the Timeline tab")
        shot(app, "office_timeline")

        // Switch to the Scrapbook tab: moments to remember (trophy beats)
        // and the two historic front pages. The front-page grid is lazy —
        // its cards only materialise near the viewport, so bring the
        // section into range by swiping the shared container first.
        waitFor(app, "career.office.tab.scrapbook").tap()
        waitFor(app, "career.scrapbook.moments")
        XCTAssertTrue(exists(app, "career.scrapbook.moment.2001", 6), "Title-winning moment photo missing")
        let scroll = app.scrollViews["career.office.scroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        let firstPage = waitFor(app, "career.scrapbook.frontPage.0", 10)
        waitFor(app, "career.scrapbook.frontPages")

        // Open the front page through the REAL route (sheet), verify the
        // article renders, then dismiss and confirm the scrapbook state.
        if !firstPage.isHittable {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        waitFor(app, "career.scrapbook.frontPage.0").tap()
        let headline = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "CROWNED")).firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 8), "Article headline missing after opening a front page")
        shot(app, "office_article")

        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(exists(app, "career.scrapbook.frontPages", 6), "Scrapbook should still show front pages after closing the article")
        XCTAssertTrue(app.buttons["career.office.tab.scrapbook"].isSelected, "Scrapbook tab must stay selected")
        shot(app, "office_scrapbook")
    }

    // MARK: - C. Scroll reachability, hold, and return navigation

    func testTimelineScrollReachesEndHoldsAndSidebarReturnsToManager() throws {
        let app = openOffice(launch())

        // Timeline, scrolled to the very last beat through the container.
        waitFor(app, "career.office.tab.timeline").tap()
        waitFor(app, "career.timeline.row.2000", 8)
        let scroll = app.scrollViews["career.office.scroll"].firstMatch
        for _ in 0..<3 {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        let lastRow = waitFor(app, "career.timeline.row.2002")
        let frameBefore = lastRow.frame

        // Held position: the scroll must not jump back to the top while
        // the screen is idle.
        Thread.sleep(forTimeInterval: 1.2)
        let frameAfter = app.descendants(matching: .any)["career.timeline.row.2002"].firstMatch.frame
        XCTAssertEqual(frameAfter.minY, frameBefore.minY, accuracy: 8,
                       "Timeline must hold its scroll position while idle")
        XCTAssertTrue(exists(app, "career.office.timeline.end", 6), "Timeline end anchor missing")
        shot(app, "office_timeline_end")

        // The tab has no sheet close control; Settings is reached through
        // the persistent sidebar, and its former Office row is gone.
        XCTAssertFalse(exists(app, "career.office.close", 1), "Manager tab should not have a sheet close button")
        waitFor(app, "career.nav.settings").tap()
        XCTAssertTrue(exists(app, "career.settings.screen", 8) || exists(app, "career.settings.summary", 8),
                      "Settings should open from the Manager tab")
        XCTAssertFalse(exists(app, "career.settings.row.manager-office", 1),
                       "Settings should no longer contain Manager Office")

        // Returning through the sidebar works cleanly.
        waitFor(app, "career.nav.manager").tap()
        XCTAssertTrue(exists(app, "career.manager.screen", 8), "Manager tab should reopen")
        XCTAssertTrue(exists(app, "career.office.summary", 6), "Overview should be the reopening tab")
        shot(app, "office_reopened")
    }
}
