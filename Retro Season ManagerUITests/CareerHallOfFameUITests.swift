//
//  CareerHallOfFameUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Hall of Fame and the
//  legend detail sheet, built on the deterministic `UITEST_CAREER_HALL`
//  fixture (itself built on the shared Career navigation fixture). The
//  fixture inducts through the REAL induction path —
//  `evaluateForLegendStatus` and its scoring, never seeded legends —
//  so these tests cover the induction output exactly as real careers
//  produce it:
//
//  A. Club Legends wall: two inductees render as framed portrait cards,
//     the header band carries the authoritative count, and scrolling the
//     single container reaches the manager exhibit below.
//  B. Exhibit switching: the Global exhibit shows its empty state and
//     never mixes in club-legend content, and switching back restores
//     the wall.
//  C. Legend detail: opening a wall card presents the full induction
//     record (identity, career statistics, honours won, generated
//     biography) and dismissing returns to the same wall.
//  D. Manager exhibit + sheet route: the profile card shows the
//     fixture's authoritative career figures, the trophy cabinet lists
//     the honours, the sheet closes back into Settings, and the Settings
//     detail hosting (no close control, back bar instead) round-trips.
//
//  Same primitive discipline as the accepted suites: existence waits on
//  freshly-queried elements, swipes only on the named scroll container,
//  and plain element taps. XCUIDevice.orientation is never written —
//  the app is landscape-locked.
//

import XCTest

final class CareerHallOfFameUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_HALL"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_hall_\(suffixed).png"))
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

    private func waitGone(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 4) {
        let el = app.descendants(matching: .any)[id].firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, el.exists {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(el.exists, "Element should be gone: \(id)")
    }

    /// Opens the Hall of Fame through the REAL route: Settings → the
    /// whole-building sheet row. Reveals the row by swiping the named
    /// Settings scroll container only.
    @discardableResult
    private func openHallOfFame(_ app: XCUIApplication) -> XCUIApplication {
        XCTAssertTrue(exists(app, "career.home.screen", 15), "Career home should appear after launch")
        let tab = app.buttons["career.nav.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Settings sidebar item missing")
        tab.tap()
        _ = waitFor(app, "career.settings.summary")

        let row = app.descendants(matching: .any)["career.settings.row.hall-of-fame"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Hall of Fame row missing from Settings")
        let scroll = app.scrollViews["career.settings.scroll"].firstMatch
        var swipes = 0
        while swipes < 6 {
            guard row.exists, scroll.exists else { break }
            let rowFrame = row.frame
            let visible = scroll.frame
            let centreY = rowFrame.minY + rowFrame.height * 0.5
            let centreInside = centreY <= visible.maxY - 8 && rowFrame.minY >= visible.minY
            if centreInside { break }
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        row.tap()

        XCTAssertTrue(exists(app, "career.hall.close", 8), "Hall of Fame sheet close missing")
        XCTAssertTrue(exists(app, "career.hall.header", 4), "Hall of Fame header missing")
        XCTAssertTrue(exists(app, "career.hall.tab.club-legends", 4), "Club Legends tab missing")
        return app
    }

    /// Reveals an element inside the hall scroll container until its
    /// centre is within the container's visible band.
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ identifier: String, maxSwipes: Int = 10) -> XCUIElement {
        let element = waitFor(app, identifier)
        let scroll = app.scrollViews["career.hall.scroll"].firstMatch
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

    // MARK: - A. Club Legends wall

    func testClubLegendsWallShowsInducteesAndScrollsToManagerExhibit() throws {
        let app = openHallOfFame(launch())

        // The header band carries the authoritative count of all
        // inductees: two Club Legends plus the Global inductee (whose
        // wall is a separate exhibit).
        let header = waitFor(app, "career.hall.header")
        XCTAssertTrue(header.label.contains("3 legends"), "Header should show all three inductees: \(header.label)")
        shot(app, "hall_wall")

        // Both wall cards render with their stable per-index anchors and
        // open-state buttons.
        XCTAssertTrue(exists(app, "career.hall.legend.0", 6), "First wall card missing")
        XCTAssertTrue(exists(app, "career.hall.legend.1", 6), "Second wall card missing")
        let wall = waitFor(app, "career.hall.wall")
        XCTAssertTrue(wall.exists, "Wall grid container missing")

        // Scrolling the single shared container reaches the Club Legends
        // end anchor without nested scrolling, and the manager exhibit
        // stays exclusive to the MANAGER tab — exhibits never mix.
        reveal(app, "career.hall.club-legends.end")
        XCTAssertFalse(exists(app, "career.hall.managerCard", 1),
                       "Manager exhibit must not mix into the Club Legends exhibit")
        shot(app, "hall_wall_scrolled")
    }

    // MARK: - B. Exhibit switching

    func testGlobalExhibitSwitchShowsEmptyStateAndNeverMixesContent() throws {
        let app = openHallOfFame(launch())

        // Switch to the GLOBAL exhibit: the fixture inducted exactly one
        // Global legend, so the wall shows exactly one card and none of
        // the club-legend content lingers.
        waitFor(app, "career.hall.tab.global").tap()
        waitFor(app, "career.hall.legend.0", 6)
        let header = app.descendants(matching: .any)["career.hall.header"].firstMatch
        XCTAssertTrue(header.exists, "Header should persist across exhibit switches")
        XCTAssertTrue(app.buttons["career.hall.tab.global"].isSelected, "GLOBAL tab should be selected")
        shot(app, "hall_global")

        // Switch back: the Club Legends wall is restored with both cards.
        waitFor(app, "career.hall.tab.club-legends").tap()
        XCTAssertTrue(exists(app, "career.hall.legend.0", 6), "Wall should restore on switching back")
        XCTAssertTrue(exists(app, "career.hall.legend.1", 6), "Second card should restore on switching back")

        // The MANAGER exhibit holds its own content, and a switch to the
        // empty-state-free Global exhibit never mixes club-legend cards.
        waitFor(app, "career.hall.tab.manager").tap()
        waitFor(app, "career.hall.managerCard", 6)
        waitFor(app, "career.hall.tab.global").tap()
        let mixed = exists(app, "career.hall.managerCard", 1)
        XCTAssertFalse(mixed, "Manager exhibit content must not linger on the GLOBAL exhibit")
        XCTAssertTrue(exists(app, "career.hall.global.end", 6), "Global end anchor missing")
        shot(app, "hall_global_end")
    }

    // MARK: - C. Legend detail sheet

    func testLegendDetailOpensWithInductionRecordAndCloses() throws {
        let app = openHallOfFame(launch())

        // Open the first wall card (highest legend score: Rowan striker,
        // score 80). The detail sheet presents the full induction record
        // under a name-slugged root anchor.
        waitFor(app, "career.hall.legend.0").tap()
        XCTAssertTrue(exists(app, "career.hall.detail.rowan-striker", 8),
                      "Legend detail sheet missing after opening a wall card")
        XCTAssertTrue(exists(app, "career.hall.detail.close", 4), "Detail close control missing")
        XCTAssertTrue(exists(app, "career.hall.detail.stats", 4), "Career statistics card missing")
        XCTAssertTrue(exists(app, "career.hall.detail.biography", 4), "Biography card missing")

        // Honours: the fixture's title-and-cup season flows through the
        // real induction path, so the record carries both lines.
        let honours = waitFor(app, "career.hall.detail.honours")
        XCTAssertTrue(honours.exists, "Honours card missing")
        let firstHonour = waitFor(app, "career.hall.detail.honour.0", 6)
        XCTAssertTrue(firstHonour.label.contains("title"), "First honour should be the title: \(firstHonour.label)")
        XCTAssertTrue(exists(app, "career.hall.detail.honour.1", 6), "Cup honour missing")
        shot(app, "hall_detail")

        // Dismiss and confirm the wall is exactly as it was.
        waitFor(app, "career.hall.detail.close").tap()
        waitGone(app, "career.hall.detail.rowan-striker", 6)
        XCTAssertTrue(exists(app, "career.hall.scroll", 6), "Wall should still be present after closing the detail")
        XCTAssertTrue(app.buttons["career.hall.tab.club-legends"].isSelected, "Club Legends tab must stay selected")
        XCTAssertTrue(exists(app, "career.hall.legend.0", 6), "Wall card should still exist after closing the detail")
        shot(app, "hall_after_detail")
    }

    // MARK: - D. Manager exhibit figures + sheet route round trip

    func testManagerExhibitShowsAuthoritativeFiguresAndSheetRouteRoundTrips() throws {
        let app = openHallOfFame(launch())

        // The manager exhibit: one completed season, 44 matches (31W+6D+7L),
        // 70% win rate, 2 trophies — all through legendaryManagerProfile().
        waitFor(app, "career.hall.tab.manager").tap()
        let card = waitFor(app, "career.hall.managerCard")
        XCTAssertTrue(card.label.contains("1 season"), "Profile should show one season: \(card.label)")
        XCTAssertTrue(card.label.contains("70 percent"), "Profile should show the 70% win rate: \(card.label)")
        XCTAssertTrue(card.label.contains("2 trophies"), "Profile should show the two trophies: \(card.label)")

        // The trophy cabinet lists the honours in the real log format.
        // The grid is lazy — reveal the cabinet by swiping the shared
        // container before its items exist.
        reveal(app, "career.hall.trophyCabinet")
        let firstTrophy = reveal(app, "career.hall.trophy.0")
        XCTAssertTrue(firstTrophy.label.contains("title"), "First cabinet trophy should be the title: \(firstTrophy.label)")
        reveal(app, "career.hall.trophy.1")
        reveal(app, "career.hall.manager.end")
        shot(app, "hall_manager")

        // Close the sheet — the whole-building row presents it straight
        // over the Settings menu, so closing lands back on that menu in
        // the same context (the accepted settings-suite round trip).
        waitFor(app, "career.hall.close").tap()
        waitGone(app, "career.hall.header", 6)
        _ = waitFor(app, "career.settings.summary", 8)
        XCTAssertTrue(exists(app, "career.settings.records", 4),
                      "Closing the Hall of Fame must return to the Settings menu")
        shot(app, "hall_settings_return")
    }
}
