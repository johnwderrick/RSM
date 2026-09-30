//
//  CareerLegacyMuseumUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Football Museum
//  (LegacyCareersView.swift), built on the deterministic
//  `UITEST_LEGACY_MUSEUM` fixture: two hand-built archived careers
//  (Ruth Whitmore's treble-winning 8-season spell, Arthur Booth's
//  modest 2-season one) seeded into the real `LegacyArchive` store,
//  which is cleared and rebuilt on every launch. The museum opens
//  through its real route — the main menu's Museum tile, enabled
//  because archives exist.
//
//  Coverage:
//  A. Overview + all six wings render the fixture's content through the
//     ONE shared vertical scroll container, and the Newspapers wing's
//     article sheet opens and closes.
//  B. The career detail sheet replays the frozen record (honours,
//     legends, autobiography) and closes back onto the same wall.
//  C. The delete confirmation is explicit, warns that the deletion
//     can't be undone, and Cancel provably commits nothing.
//  D. Confirming the delete goes through the real `LegacyArchive.remove`
//     path, and deleting both careers reaches the museum's no-archives
//     state before Close returns to the menu.
//
//  Same primitive discipline as the accepted suites: existence waits on
//  freshly-queried elements, swipes only on the named scroll container,
//  plain element taps, screenshots suffixed with the simulator model.
//  XCUIDevice.orientation is never written — the app is landscape-locked.
//

import XCTest

final class CareerLegacyMuseumUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGACY_MUSEUM"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_museum_\(suffixed).png"))
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

    private func waitGone(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 6) {
        let el = app.descendants(matching: .any)[id].firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, el.exists {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(el.exists, "Element should be gone: \(id)")
    }

    private func label(of id: String, in app: XCUIApplication) -> String {
        waitFor(app, id).label
    }

    /// Reveals an element inside the museum's scroll container until its
    /// centre is within the container's visible band.
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ identifier: String, maxSwipes: Int = 10) -> XCUIElement {
        let element = waitFor(app, identifier)
        let scroll = app.scrollViews["career.museum.scroll"].firstMatch
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

    /// Opens the museum through its real route: the main menu's Museum
    /// tile (enabled because the fixture seeded two archives), revealing
    /// the tile by swiping the menu's tile row if it sits off-screen on
    /// the narrow SE.
    @discardableResult
    private func openMuseum(_ app: XCUIApplication) -> XCUIApplication {
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Museum")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 12), "Museum menu tile missing after launch")
        var taps = 0
        while taps < 3, !tile.isHittable {
            app.swipeLeft()
            taps += 1
            Thread.sleep(forTimeInterval: 0.3)
        }
        tile.tap()

        // Hub skeleton: header, close, pinned overview and every wing tab.
        XCTAssertTrue(exists(app, "career.museum.header", 8), "Museum header missing")
        XCTAssertTrue(exists(app, "career.museum.close", 4), "Museum close missing")
        XCTAssertTrue(exists(app, "career.museum.overview", 4), "Museum overview strip missing")
        for wing in ["careers", "trophy-cabinet", "managers", "players", "record-book", "newspapers"] {
            XCTAssertTrue(exists(app, "career.museum.wing.\(wing)", 4), "Wing tab missing: \(wing)")
        }
        XCTAssertTrue(exists(app, "career.museum.scroll", 4), "Museum scroll container missing")
        return app
    }

    private func switchWing(_ app: XCUIApplication, _ wing: String) {
        waitFor(app, "career.museum.wing.\(wing)").tap()
        XCTAssertTrue(app.descendants(matching: .any)["career.museum.wing.\(wing)"].firstMatch
            .isSelected, "Wing tab should be selected: \(wing)")
    }

    // MARK: - A. Overview + six wings in one container

    func testOverviewAndAllSixWingsShowFixtureContentInOneContainer() throws {
        let app = openMuseum(launch())

        // Header + overview carry the archive-wide aggregates.
        XCTAssertTrue(label(of: "career.museum.header", in: app).contains("2 archived careers"),
                      "Header should report both archived careers")
        let overview = label(of: "career.museum.overview", in: app)
        XCTAssertTrue(overview.contains("2") && overview.contains("CAREERS"),
                      "Overview should count 2 careers: \(overview)")
        XCTAssertTrue(overview.contains("3") && overview.contains("TROPHIES"),
                      "Overview should count 3 trophies: \(overview)")
        XCTAssertTrue(overview.contains("LEGENDS"), "Overview should count legends: \(overview)")
        XCTAssertTrue(overview.contains("Legend") && overview.contains("BEST TIER"),
                      "Overview should report the best tier: \(overview)")

        // Careers wing: both cards, newest archive first.
        XCTAssertTrue(label(of: "career.museum.career.ruth-whitmore", in: app).contains("Ruth Whitmore"),
                      "Newest archived career should lead the list")
        XCTAssertTrue(exists(app, "career.museum.career.arthur-booth", 6), "Second career card missing")
        XCTAssertTrue(label(of: "career.museum.career.arthur-booth", in: app).contains("Arthur Booth"),
                      "Second card should be the earlier archive")
        shot(app, "wing_careers")

        // Trophy Cabinet: the fixture's three honours, each tagged with
        // the career that won it.
        switchWing(app, "trophy-cabinet")
        let trophy = reveal(app, "career.museum.trophy.0")
        XCTAssertTrue(trophy.label.contains("Premier Division title (2025/26)"),
                      "First trophy should be the title: \(trophy.label)")
        XCTAssertTrue(trophy.label.contains("Ruth Whitmore at Harbour City"),
                      "Trophies should be tagged with their career: \(trophy.label)")
        XCTAssertTrue(exists(app, "career.museum.trophy.2", 6), "Third trophy missing")
        shot(app, "wing_trophies")

        // Managers: leaderboard, and the two-career comparison through
        // its real menu pickers.
        switchWing(app, "managers")
        let leader = reveal(app, "career.museum.leaderboard.0")
        XCTAssertTrue(leader.label.contains("Ruth Whitmore"), "Whitmore should lead: \(leader.label)")
        XCTAssertTrue(leader.label.contains("500"), "Leader should carry her score: \(leader.label)")
        XCTAssertTrue(exists(app, "career.museum.leaderboard.1", 6), "Second leaderboard row missing")
        reveal(app, "career.museum.compare.career-a").tap()
        let pickA = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Ruth Whitmore")).firstMatch
        XCTAssertTrue(pickA.waitForExistence(timeout: 5), "Comparison menu should offer Whitmore")
        pickA.tap()
        reveal(app, "career.museum.compare.career-b").tap()
        let pickB = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Arthur Booth")).firstMatch
        XCTAssertTrue(pickB.waitForExistence(timeout: 5), "Comparison menu should offer Booth")
        pickB.tap()
        let table = waitFor(app, "career.museum.compare.table", 6)
        XCTAssertTrue(table.exists, "Comparison table should appear once both slots are picked")
        reveal(app, "career.museum.managers.end")
        shot(app, "wing_managers")

        // Players: the legend wall ranked by legend score.
        switchWing(app, "players")
        let player = reveal(app, "career.museum.player.0")
        XCTAssertTrue(player.label.contains("Mara Voss"), "Top legend should lead the wall: \(player.label)")
        XCTAssertTrue(player.label.contains("86"), "Wall row should carry the legend score: \(player.label)")
        XCTAssertTrue(exists(app, "career.museum.player.1", 6), "Second legend row missing")
        shot(app, "wing_players")

        // Record Book: cross-career superlatives and the transfers table.
        switchWing(app, "record-book")
        let transfer = reveal(app, "career.museum.transfer.0")
        XCTAssertTrue(transfer.label.contains("Diego Sarr"), "Biggest sale should lead transfers: \(transfer.label)")
        XCTAssertTrue(exists(app, "career.museum.record-book.end", 8), "Record Book end anchor missing")
        shot(app, "wing_records")

        // Newspapers: Whitmore's two front pages open the article sheet,
        // which closes back onto the wing.
        switchWing(app, "newspapers")
        let page = reveal(app, "career.museum.newspaper.0")
        XCTAssertTrue(page.label.contains("CHAMPIONS AT LAST"),
                      "First front page should be the title splash: \(page.label)")
        shot(app, "wing_papers")
        page.tap()
        waitFor(app, "career.museum.paper", 8)
        shot(app, "paper_article")
        waitFor(app, "career.museum.paper.close").tap()
        waitGone(app, "career.museum.paper")
        XCTAssertTrue(exists(app, "career.museum.scroll", 6), "Museum should still be present after closing the article")

        // The one scroll container survived every wing switch.
        XCTAssertTrue(exists(app, "career.museum.scroll", 4), "Shared scroll container must persist across wings")
    }

    // MARK: - B. Career detail

    func testCareerDetailShowsFrozenRecordAndClosesBackToWall() throws {
        let app = openMuseum(launch())
        waitFor(app, "career.museum.career.ruth-whitmore").tap()

        XCTAssertTrue(exists(app, "career.museum.detail.ruth-whitmore", 8),
                      "Detail sheet missing after opening the top career")
        XCTAssertTrue(exists(app, "career.museum.detail.close", 4), "Detail close missing")
        XCTAssertTrue(exists(app, "career.museum.detail.scroll", 4), "Detail scroll container missing")

        // Honours replay from the frozen snapshot, in order.
        let honour = waitFor(app, "career.museum.detail.honour.0", 6)
        XCTAssertTrue(honour.label.contains("Premier Division title (2025/26)"),
                      "First honour should be the title: \(honour.label)")
        XCTAssertTrue(exists(app, "career.museum.detail.honour.1", 6), "Cup honour missing")
        XCTAssertTrue(exists(app, "career.museum.detail.honour.2", 6), "Continental honour missing")

        // The full story really is the fixture's autobiography.
        let story = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "outgrew its room")).firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 6), "Autobiography text missing from the detail")

        // Club legends are listed under their club.
        let legend = reveal(app, "career.museum.detail.legend.0.0", maxSwipes: 12)
        XCTAssertTrue(legend.label.contains("Mara Voss"), "Whitmore's legend should be listed: \(legend.label)")
        shot(app, "detail")

        waitFor(app, "career.museum.detail.close").tap()
        waitGone(app, "career.museum.detail.ruth-whitmore")
        XCTAssertTrue(exists(app, "career.museum.scroll", 6), "Wall should return after closing the detail")
        XCTAssertTrue(exists(app, "career.museum.career.ruth-whitmore", 6), "Career card should still exist after closing")
        shot(app, "after_detail")
    }

    // MARK: - C. Delete confirmation cancel

    func testDeleteConfirmationWarnsIrreversibilityAndCancelCommitsNothing() throws {
        let app = openMuseum(launch())
        waitFor(app, "career.museum.career.delete.ruth-whitmore").tap()

        XCTAssertTrue(exists(app, "career.museum.delete.confirm", 6), "Delete confirm missing")
        XCTAssertTrue(exists(app, "career.museum.delete.cancel", 4), "Delete cancel missing")
        let warning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "can't be undone")).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 4),
                      "The delete confirmation must warn that it can't be undone")
        shot(app, "delete_prompt")

        waitFor(app, "career.museum.delete.cancel").tap()
        waitGone(app, "career.museum.delete.confirm")
        XCTAssertTrue(exists(app, "career.museum.career.ruth-whitmore", 6), "Cancel must keep the career")
        XCTAssertTrue(exists(app, "career.museum.career.arthur-booth", 4), "Cancel must keep the other career")
        XCTAssertTrue(label(of: "career.museum.header", in: app).contains("2 archived careers"),
                      "Cancel must leave the archive untouched")
        shot(app, "after_cancel")
    }

    // MARK: - D. Delete commits + the no-archives museum

    func testDeleteCommitsThroughArchiveAndRemovingAllCareersShowsEmptyState() throws {
        let app = openMuseum(launch())

        // Delete Whitmore through the confirmation.
        waitFor(app, "career.museum.career.delete.ruth-whitmore").tap()
        waitFor(app, "career.museum.delete.confirm").tap()
        waitGone(app, "career.museum.career.ruth-whitmore", 8)
        XCTAssertTrue(label(of: "career.museum.header", in: app).contains("1 archived career"),
                      "Header should count the one remaining career")
        XCTAssertTrue(exists(app, "career.museum.career.arthur-booth", 6),
                      "The remaining career should still be present")
        shot(app, "after_first_delete")

        // Delete Booth too: the museum reaches its no-archives state —
        // cards, overview and wing switcher all gone, empty state shown.
        waitFor(app, "career.museum.career.delete.arthur-booth").tap()
        waitFor(app, "career.museum.delete.confirm").tap()
        waitGone(app, "career.museum.career.arthur-booth", 8)
        XCTAssertTrue(exists(app, "career.museum.empty", 8), "No-archives empty state missing")
        XCTAssertFalse(exists(app, "career.museum.overview", 2),
                       "Overview strip must not show with no archives")
        XCTAssertFalse(exists(app, "career.museum.wing.careers", 2),
                       "Wing switcher must not show with no archives")
        XCTAssertTrue(label(of: "career.museum.header", in: app).contains("0 archived careers"),
                      "Header should report the empty archive")
        shot(app, "no_archives")

        // Close returns to the main menu.
        waitFor(app, "career.museum.close").tap()
        waitGone(app, "career.museum.header")
        shot(app, "back_on_menu")
    }
}
