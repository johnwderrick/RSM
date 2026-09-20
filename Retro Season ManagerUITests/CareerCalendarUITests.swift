//
//  CareerCalendarUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for the redesigned Career Calendar destination:
//  season summary, month navigation, competition filters, the highlighted
//  next fixture, played/upcoming separation, and one stable scroll
//  container that never jumps back to the top.
//
//  Uses the same existence-wait + plain-tap primitives as
//  CareerNavigationUITests — frame math is unusable on this
//  landscape-locked app (see that file's header for the full story).
//

import XCTest

final class CareerCalendarUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_NAVIGATION"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_calendar_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func screenVisible(_ app: XCUIApplication, _ slug: String, timeout: TimeInterval = 8) -> Bool {
        app.otherElements["career.\(slug).screen"].waitForExistence(timeout: timeout)
            || app.descendants(matching: .any)["career.\(slug).screen"].waitForExistence(timeout: 2)
    }

    @discardableResult
    private func gotoSidebar(_ app: XCUIApplication, _ slug: String) -> XCUIElement {
        let tab = app.buttons["career.nav.\(slug)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Sidebar item \(slug) missing")
        tab.tap()
        return tab
    }

    /// Navigates to a destination and asserts its stable root appears,
    /// retrying once for a tap swallowed by an in-flight SwiftUI update.
    private func assertLands(_ app: XCUIApplication, _ slug: String) {
        let tab = gotoSidebar(app, slug)
        var found = screenVisible(app, slug, timeout: 8)
        if !found {
            tab.tap()
            found = screenVisible(app, slug, timeout: 8)
        }
        XCTAssertTrue(found, "Tapping \(slug) should show career.\(slug).screen")
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func firstRow(_ app: XCUIApplication, _ prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    // MARK: - Summary, next fixture, played/upcoming separation

    func testCalendarShowsSummaryNextFixtureAndSeparatesPlayedFromUpcoming() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")

        assertLands(app, "calendar")

        let summary = anyElement(app, "career.calendar.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 6), "Season summary band missing")
        XCTAssertTrue(summary.label.contains("MATCHDAY 4"), "Summary should show the authoritative matchday")
        XCTAssertTrue(summary.label.contains("PLAYED 3"), "Summary should show matches played (fixture = 3 rounds)")

        let nextFixture = anyElement(app, "career.calendar.nextFixture")
        XCTAssertTrue(nextFixture.waitForExistence(timeout: 6), "Next-fixture highlight missing")

        let played = firstRow(app, "career.calendar.row.played")
        XCTAssertTrue(played.waitForExistence(timeout: 6), "A completed result should be listed in the current month")
        XCTAssertTrue(played.label.contains("W") || played.label.contains("D") || played.label.contains("L"),
                      "Completed rows should carry a W/D/L result")

        let upcoming = firstRow(app, "career.calendar.row.upcoming")
        XCTAssertTrue(upcoming.waitForExistence(timeout: 6), "An upcoming fixture should be listed")

        shot(app, "summary_se")
        app.terminate()
    }

    // MARK: - Month navigation + competition filters

    func testCalendarMonthNavigationAndCompetitionFilters() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")
        assertLands(app, "calendar")

        let monthLabel = anyElement(app, "career.calendar.month.label")
        XCTAssertTrue(monthLabel.waitForExistence(timeout: 6), "Month label missing")
        let startMonth = monthLabel.value as? String ?? monthLabel.label

        // Forward a month: label updates, schedule follows, TODAY offers a
        // return to the current month.
        let next = app.buttons["career.calendar.month.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Next-month control missing")
        next.tap()
        let afterNext = monthLabel.value as? String ?? monthLabel.label
        XCTAssertNotEqual(afterNext, startMonth, "Next-month control should advance the label")

        // The filter row offers every genuinely-occurring competition.
        for slug in ["all", "league", "national-cup", "league-trophy", "continental-cup", "midweek-cup"] {
            let chip = app.buttons["career.calendar.filter.\(slug)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 4), "Filter chip \(slug) missing")
        }
        let all = app.buttons["career.calendar.filter.all"]
        XCTAssertTrue(all.isSelected, "All should be the initial filter")

        // Switching to League keeps the league rows and the selection.
        let league = app.buttons["career.calendar.filter.league"]
        league.tap()
        XCTAssertTrue(league.waitForExistence(timeout: 3) && league.isSelected, "League chip should become selected")
        let rowsFound = firstRow(app, "career.calendar.row.").waitForExistence(timeout: 5)
        let emptyFound = anyElement(app, "career.calendar.empty").exists
        if !rowsFound && !emptyFound {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/cal-tree-league.txt"))
        }
        XCTAssertTrue(rowsFound || emptyFound,
                      "A filtered schedule shows rows or a clear empty state")

        // Back to the current month via TODAY.
        let today = app.buttons["career.calendar.month.today"]
        XCTAssertTrue(today.waitForExistence(timeout: 4), "Return-to-current-month control missing")
        today.tap()
        let restored = monthLabel.value as? String ?? monthLabel.label
        XCTAssertEqual(restored, startMonth, "TODAY should return to the current month")

        shot(app, "filters_se")
        app.terminate()
    }

    // MARK: - One stable scroll container, no jump-to-top

    func testCalendarScrollReachesLowerContentAndHoldsPosition() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")
        assertLands(app, "calendar")

        let dayDetail = anyElement(app, "career.calendar.dayDetail")
        XCTAssertTrue(dayDetail.waitForExistence(timeout: 6), "Selected-day card missing")

        let scroll = app.scrollViews["career.calendar.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Calendar's main scroll container missing")

        // August can hold 270+ authoritative rows (both national cups draw
        // their 116-tie first rounds in-month), so allow a long scroll.
        var swipes = 0
        while !dayDetail.isHittable && swipes < 20 {
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.3)
        }
        if !dayDetail.isHittable {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/cal-tree-scroll.txt"))
        }
        XCTAssertTrue(dayDetail.isHittable, "Lower content should be reachable by scrolling")

        let heldY = dayDetail.frame.minY
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(dayDetail.frame.minY, heldY, accuracy: 24,
                       "Calendar scroll position should remain stable while idle")

        // Away and back still works and the root re-appears.
        assertLands(app, "squad")
        assertLands(app, "calendar")
        XCTAssertTrue(anyElement(app, "career.calendar.summary").exists, "Summary should be present after returning")

        shot(app, "scrolled_se")
        app.terminate()
    }
}
