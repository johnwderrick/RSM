//
//  CareerSupporterUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Supporter Zone and
//  Season Objectives, built on the deterministic `UITEST_CAREER_SUPPORTER`
//  fixture (itself built on the shared Career navigation fixture):
//
//  A. the Supporter Zone sheet opens from Settings, shows the summary
//     band with the fixture's authoritative mood/figures, scrolls to its
//     end through the single container, and closes back into Settings,
//  B. the Season Objectives sheet opens (from Settings), shows the
//     pinned 1/4 completion in the summary, the four stable objective
//     cards, opens the completed objective's detail, proves the reward
//     band, closes the detail and then the sheet back into Settings,
//  C. both surfaces scroll on compact landscape without losing the
//     pinned close, and the pinned close stays reachable after a full
//     scroll to the end.
//
//  Same primitive discipline as the accepted suites: existence waits on
//  freshly-queried elements, swipes on the named scroll container, and
//  plain element taps. XCUIDevice.orientation is never written — the app
//  is landscape-locked and orientation writes cause rotation churn.
//

import XCTest

final class CareerSupporterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_SUPPORTER"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_supporter_\(suffixed).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: suffixed, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func exists(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 4) -> Bool {
        app.descendants(matching: .any)[id].waitForExistence(timeout: timeout)
    }

    @discardableResult
    private func waitFor(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let el = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Missing element: \(id)")
        return el
    }

    private func launchToSettings() -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].waitForExistence(timeout: 15),
                      "Career home should appear after launch")
        let tab = app.buttons["career.nav.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Settings sidebar item missing")
        tab.tap()
        XCTAssertTrue(exists(app, "career.settings.screen", 8) || exists(app, "career.settings.summary", 4),
                      "Settings destination missing")
        return app
    }

    /// Reveals a Settings menu row that may sit below the fold, using the
    /// accepted pattern: one swipe on the settings scroll container.
    private func openSettingsRow(_ app: XCUIApplication, _ slug: String) {
        let row = app.descendants(matching: .any)["career.settings.row.\(slug)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Settings row \(slug) missing")
        if row.isHittable {
            row.tap()
            return
        }
        let settingsScroll = app.scrollViews["career.settings.scroll"].firstMatch
        if settingsScroll.exists {
            settingsScroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(row.waitForExistence(timeout: 4), "Settings row \(slug) missing after reveal")
        row.tap()
    }

    // MARK: - A. Supporter Zone sheet

    func testSupporterZoneOpensScrollsToStatsAndClosesBackToSettings() throws {
        let app = launchToSettings()
        openSettingsRow(app, "supporter-zone")

        // Summary band with the fixture's authoritative values.
        let summary = waitFor(app, "career.supporter.summary")
        XCTAssertTrue(summary.label.contains("Old Trafford Reds"), "Summary should name the club: \(summary.label)")
        XCTAssertTrue(summary.label.contains("71 percent"), "Summary should carry fan confidence 71%: \(summary.label)")
        XCTAssertTrue(summary.label.contains("Content"), "Summary should carry the mood word (71 → Content): \(summary.label)")
        shot(app, "supporter_overview")

        // Matchday stats seeded/derived by newGame — the ticket-holder
        // row sits below the fold on compact landscape.
        let holders = "career.supporter.stat.season-ticket-holders"
        if !exists(app, holders, 2) {
            let scroll = app.scrollViews["career.supporter.scroll"].firstMatch
            if scroll.exists { scroll.swipeUp(); Thread.sleep(forTimeInterval: 0.4) }
        }
        XCTAssertTrue(exists(app, holders, 6), "Season-ticket holders row missing")
        XCTAssertTrue(exists(app, "career.supporter.stat.ground-capacity", 4), "Ground capacity row missing")

        // Attendance trend (fixture banks two previous seasons).
        XCTAssertTrue(exists(app, "career.supporter.stat.attendance-2", 4), "Attendance trend row missing")

        // Fan reactions through the real pipeline — newest first.
        XCTAssertTrue(exists(app, "career.supporter.post.0", 6), "Newest fan reaction missing")

        // Scroll to the end anchor and confirm the pinned close is still
        // there (it floats above the scroll, never scrolls away).
        let scroll = app.scrollViews["career.supporter.scroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(exists(app, "career.supporter.end", 6), "Supporter Zone end anchor missing")
        XCTAssertTrue(app.buttons["career.supporter.close"].exists, "Pinned close must remain reachable after scrolling")
        shot(app, "supporter_scrolled")

        // Close returns to Settings.
        waitFor(app, "career.supporter.close").tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Closing Supporter Zone should return to Settings")
    }

    // MARK: - B. Season Objectives sheet + detail

    func testSeasonObjectivesOpenShowCardsAndDetailRewardThenClose() throws {
        let app = launchToSettings()
        openSettingsRow(app, "season-objectives")

        // Summary: fixture pins 1 of 4 complete.
        let summary = waitFor(app, "career.objectives.summary")
        XCTAssertTrue(summary.label.contains("1 of 4 complete"), "Summary should show 1/4 complete: \(summary.label)")
        shot(app, "objectives_overview")

        // The four pinned cards, by stable objective id.
        for id in ["beat-rival", "clean-sheet-wall", "sign-young-player", "improve-fan-confidence"] {
            XCTAssertTrue(exists(app, "career.objectives.card.\(id)", 6), "Objective card \(id) missing")
        }

        // The completed one announces itself in its accessibility label.
        let completed = waitFor(app, "career.objectives.card.sign-young-player")
        XCTAssertTrue(completed.label.contains("Completed"), "Completed objective should be announced: \(completed.label)")

        // Detail sheet: open the completed objective, prove the reward band.
        completed.tap()
        let detail = waitFor(app, "career.objectives.detail")
        _ = detail
        let reward = waitFor(app, "career.objectives.detail.reward")
        XCTAssertTrue(reward.label.contains("+1 CAREER POINT"), "Reward band should list the completion rewards: \(reward.label)")
        shot(app, "objectives_detail")

        // Close the detail, then close the sheet — back to Settings.
        waitFor(app, "career.objectives.detail.close").tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(exists(app, "career.objectives.summary", 6), "Detail close should return to the objectives list")
        waitFor(app, "career.objectives.close").tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Closing Season Objectives should return to Settings")
    }

    // MARK: - C. Scroll stability + away-and-back

    func testObjectivesScrollHoldsAndAwayAndBackReopensCleanly() throws {
        let app = launchToSettings()
        openSettingsRow(app, "season-objectives")

        // Scroll within the single container to the end anchor.
        let scroll = app.scrollViews["career.objectives.scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 6), "Objectives scroll container missing")
        scroll.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)
        scroll.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertTrue(exists(app, "career.objectives.end", 6), "Objectives end anchor missing")
        shot(app, "objectives_scrolled")

        // Close, navigate away and back, reopen — no stranded state.
        waitFor(app, "career.objectives.close").tap()
        Thread.sleep(forTimeInterval: 0.6)
        let home = app.buttons["career.nav.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        home.tap()
        XCTAssertTrue(exists(app, "career.home.screen", 8), "Return to Home failed")
        let settingsTab = app.buttons["career.nav.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Return to Settings failed")
        openSettingsRow(app, "season-objectives")
        XCTAssertTrue(exists(app, "career.objectives.summary", 8), "Reopening Season Objectives failed after away-and-back")
    }
}
