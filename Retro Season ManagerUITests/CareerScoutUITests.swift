//
//  CareerScoutUITests.swift
//  Retro Season ManagerUITests
//
//  Focused coverage for the redesigned Career Scouting Centre.
//

import XCTest

final class CareerScoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_SCOUT"]
        app.launch()
        return app
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func first(_ app: XCUIApplication, prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    private func screenVisible(_ app: XCUIApplication, _ slug: String, timeout: TimeInterval = 8) -> Bool {
        app.otherElements["career.\(slug).screen"].waitForExistence(timeout: timeout)
            || app.descendants(matching: .any)["career.\(slug).screen"].waitForExistence(timeout: 2)
    }

    private func gotoScout(_ app: XCUIApplication) {
        let scroll = app.scrollViews["career.nav.sidebarScroll"]
        if scroll.waitForExistence(timeout: 5) {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        let tab = app.buttons["career.nav.scout"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Scout sidebar destination missing")
        tab.tap()
        XCTAssertTrue(screenVisible(app, "scout"), "Scout destination should appear")
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_scout_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testScoutSummaryStatesAndPremiumProfileRoundTrip() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career Scout fixture should reach Home")
        gotoScout(app)

        let summary = anyElement(app, "career.scout.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 6), "Scouting summary missing")
        XCTAssertTrue(summary.label.contains("Reports 1"), "Fixture should expose one completed report")
        XCTAssertTrue(summary.label.contains("Watching 1"), "Fixture should expose one active assignment")
        XCTAssertTrue(summary.label.contains("Shortlist 1"), "Fixture should expose one shortlisted player")

        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.scout.card."))
        XCTAssertGreaterThan(cards.count, 2, "Discovered targets should render as player cards")

        let labels = (0..<cards.count).map { cards.element(boundBy: $0).label }.joined(separator: " ")
        XCTAssertTrue(labels.contains("Full report available"), "A fully scouted state should be visible")
        XCTAssertTrue(labels.contains("Scouting in progress"), "An in-progress state should be visible")
        XCTAssertTrue(labels.contains("Not scouted"), "An unknown scouting state should be visible")

        let profileButton = first(app, prefix: "career.scout.profile.")
        XCTAssertTrue(profileButton.waitForExistence(timeout: 6), "Profile action missing")
        profileButton.tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Scout result should open the accepted premium player profile")
        XCTAssertTrue(anyElement(app, "career.playerProfile.nationality").waitForExistence(timeout: 4),
                      "Player biography should include nationality and flag")
        app.buttons["career.playerProfile.close"].tap()
        XCTAssertTrue(anyElement(app, "career.scout.summary").waitForExistence(timeout: 6),
                      "Closing profile should return to the Scouting Centre")

        shot(app, "summary")
        app.terminate()
    }

    func testScoutFiltersShortlistReportsAndActionsRoundTrip() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career Scout fixture should reach Home")
        gotoScout(app)

        let allPlayers = app.buttons["career.scout.scope.all"]
        XCTAssertTrue(allPlayers.waitForExistence(timeout: 5), "All Players scope missing")
        allPlayers.tap()
        XCTAssertTrue(allPlayers.isSelected, "All Players should become selected")

        let age = app.buttons["career.scout.filter.age"]
        XCTAssertTrue(age.waitForExistence(timeout: 5), "Age filter missing")
        age.tap()
        let youth = app.buttons["U21"]
        XCTAssertTrue(youth.waitForExistence(timeout: 4), "U21 filter option missing")
        youth.tap()
        XCTAssertTrue(app.buttons["career.scout.filters.reset"].waitForExistence(timeout: 5),
                      "Using a filter should expose RESET")
        app.buttons["career.scout.filters.reset"].tap()

        app.buttons["career.scout.scope.discovered"].tap()
        let unstarred = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                  "career.scout.shortlist.", "SHORTLIST"))
        var chosen: XCUIElement?
        for index in 0..<unstarred.count {
            let item = unstarred.element(boundBy: index)
            if !item.label.contains("SHORTLISTED") { chosen = item; break }
        }
        XCTAssertNotNil(chosen, "Fixture should have an unshortlisted player")
        chosen?.tap()
        XCTAssertTrue(anyElement(app, "career.scout.feedback").waitForExistence(timeout: 5),
                      "Shortlisting should produce confirmation feedback")

        let shortlist = app.buttons["career.scout.scope.shortlist"]
        shortlist.tap()
        XCTAssertTrue(shortlist.isSelected, "Shortlist scope should become selected")
        let scoutScroll = app.scrollViews["career.scout.scroll"]
        scoutScroll.swipeUp()
        XCTAssertTrue(first(app, prefix: "career.scout.shortlist.").waitForExistence(timeout: 5),
                      "Shortlist should contain tracked players")

        scoutScroll.swipeDown()
        let reports = app.buttons["career.scout.reports"]
        XCTAssertTrue(reports.waitForExistence(timeout: 5), "Reports action missing")
        reports.tap()
        XCTAssertTrue(anyElement(app, "career.scoutReports.screen").waitForExistence(timeout: 6),
                      "Reports should open in the Career light-card sheet")
        XCTAssertTrue(first(app, prefix: "career.scoutReports.row.").waitForExistence(timeout: 5),
                      "Fixture report should be listed")
        app.buttons["career.scoutReports.close"].tap()
        XCTAssertTrue(anyElement(app, "career.scout.summary").waitForExistence(timeout: 5),
                      "Closing Reports should return to Scout")

        shot(app, "filters")
        app.terminate()
    }

    func testScoutScrollHoldsAndNavigationReturns() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career Scout fixture should reach Home")
        gotoScout(app)

        let scroll = app.scrollViews["career.scout.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Scout should own one stable vertical scroll")
        let lastCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.scout.card.")).element(boundBy: 5)
        XCTAssertTrue(lastCard.waitForExistence(timeout: 5), "Fixture needs enough cards for scrolling")

        var swipes = 0
        // Compact landscape needs more short swipes to reach the sixth card;
        // keep the bound generous without weakening the reachability check.
        while !lastCard.isHittable && swipes < 16 {
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(lastCard.isHittable, "Lower Scout cards should be reachable")
        let heldY = lastCard.frame.minY
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertEqual(lastCard.frame.minY, heldY, accuracy: 24,
                       "Scout scroll position should not jump while idle")

        let inbox = app.buttons["career.nav.inbox"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 5), "Pinned Inbox destination missing")
        inbox.tap()
        XCTAssertTrue(screenVisible(app, "inbox"), "Scout should navigate away cleanly")

        gotoScout(app)
        XCTAssertTrue(anyElement(app, "career.scout.summary").waitForExistence(timeout: 5),
                      "Scout should render after navigating away and back")
        shot(app, "scrolled")
        app.terminate()
    }
}
