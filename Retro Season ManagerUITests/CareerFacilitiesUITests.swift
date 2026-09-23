//
//  CareerFacilitiesUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Club Facilities sheet,
//  built on the deterministic `UITEST_CAREER_FACILITIES` fixture (itself
//  built on the shared Career navigation fixture):
//
//  A. the Club sidebar tab opens Facilities, shows the summary band with the
//     fixture's authoritative transfer budget and eight facility cards,
//     and scrolls to the final facility through the single container,
//  B. an affordable upgrade (museum at level 1, £2.4M next step, £3.0M
//     budget) goes through the REAL store path: the displayed level,
//     next cost and summary budget all move, and the upgrade still
//     works after reopening the sheet,
//  C. the insufficient-budget state (scouting network £3.4M vs £3.0M)
//     shows a disabled UPGRADE that changes nothing when tapped,
//  D. the max-level state (stadium, level 5) shows the gold MAX LEVEL
//     badge with no upgrade button at all,
//  E. switching to Settings and back keeps the Club tab and facility
//     state intact; Facilities no longer appears in Settings.
//
//  Same primitive discipline as the accepted suites: existence waits on
//  freshly-queried elements, swipes on the named scroll container, and
//  plain element taps. XCUIDevice.orientation is never written — the app
//  is landscape-locked and orientation writes cause rotation churn.
//

import XCTest

final class CareerFacilitiesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_FACILITIES"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_facilities_\(suffixed).png"))
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

    private func launchToClub() -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].waitForExistence(timeout: 15),
                      "Career home should appear after launch")
        openClub(app)
        return app
    }

    /// Club sits below Calendar in the scrollable sidebar on compact phones.
    private func openClub(_ app: XCUIApplication) {
        let tab = app.buttons["career.nav.club"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Club sidebar item missing")
        let scroll = app.scrollViews["career.nav.sidebarScroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        tab.tap()
        XCTAssertTrue(exists(app, "career.club.screen", 8), "Club destination missing")
        XCTAssertTrue(tab.isSelected, "Club should be selected")
    }

    // MARK: - A + D + E. Open, layout, max-level state, scroll, navigation

    func testClubTabShowsAllEightFacilitiesAndScrolls() throws {
        let app = launchToClub()

        // Summary band with the fixture's authoritative budget.
        let summary = waitFor(app, "career.facilities.summary")
        XCTAssertTrue(summary.label.contains("£3.0M"), "Summary should carry the £3.0M budget: \(summary.label)")
        XCTAssertTrue(summary.label.contains("transfer budget"), "Summary should explain facilities spend from the transfer budget: \(summary.label)")
        shot(app, "facilities_overview")

        // All eight facility cards exist, keyed by stable kind raw value.
        for kind in ["trainingGround", "youthAcademy", "medicalCentre", "scoutingNetwork",
                     "stadium", "hospitality", "museum", "clubShop"] {
            XCTAssertTrue(exists(app, "career.facilities.card.\(kind)", 6), "Facility card \(kind) missing")
        }

        // Max-level state: the stadium shows the gold MAX badge and no
        // upgrade button at all.
        XCTAssertTrue(exists(app, "career.facilities.max.stadium", 4), "Stadium MAX LEVEL badge missing")
        XCTAssertFalse(app.descendants(matching: .any)["career.facilities.upgrade.stadium"].exists,
                       "Maxed facility must not offer an upgrade button")

        // Scroll to the end anchor through the single container.
        let scroll = app.scrollViews["career.facilities.scroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(exists(app, "career.facilities.end", 6), "Facilities end anchor missing")
        XCTAssertTrue(app.buttons["career.nav.club"].isSelected, "Club tab must remain selected after scrolling")
        shot(app, "facilities_scrolled")

        // Facilities has moved out of Settings; switching tabs is the exit.
        waitFor(app, "career.nav.settings").tap()
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Settings should remain reachable from Club")
        XCTAssertFalse(exists(app, "career.settings.row.club-facilities", 1),
                       "Facilities should no longer appear in Settings")
        openClub(app)
        XCTAssertTrue(exists(app, "career.facilities.summary", 8), "Club should reopen Facilities")
    }

    // MARK: - B + C. Real upgrade path, budget update, blocked + max states

    func testAffordableUpgradeUpdatesLevelAndBudgetAndBlockedStatesStayPut() throws {
        let app = launchToClub()

        // Baseline: museum at level 1, next step £2.4M, budget £3.0M.
        let museumLevel = waitFor(app, "career.facilities.level.museum")
        XCTAssertTrue(museumLevel.label == "LVL 1/5", "Museum should start at level 1: \(museumLevel.label)")
        let museumCost = waitFor(app, "career.facilities.cost.museum")
        XCTAssertTrue(museumCost.label.contains("£2.4M"), "Museum next cost should be £2.4M: \(museumCost.label)")
        let budgetBefore = waitFor(app, "career.facilities.budget").label
        XCTAssertTrue(budgetBefore.contains("£3.0M"),
                      "Fixture budget should be £3.0M before the upgrade: \(budgetBefore)")

        // Upgrade through the REAL store path (investInFacility: budget
        // deduction, level bump, news story, ledger entry, persist).
        let upgrade = waitFor(app, "career.facilities.upgrade.museum")
        XCTAssertTrue(upgrade.isEnabled, "Affordable upgrade should be enabled")
        upgrade.tap()

        // Level and next cost move immediately.
        XCTAssertTrue(waitFor(app, "career.facilities.level.museum", 6).label == "LVL 2/5",
                      "Museum should now show level 2")
        XCTAssertTrue(waitFor(app, "career.facilities.cost.museum", 6).label.contains("£5.4M"),
                      "Museum next cost should now be £5.4M (base £600K × 3²)")

        // The budget figure in the summary moves with the deduction
        // (£3.0M − £2.4M = £0.6M).
        let budgetAfter = waitFor(app, "career.facilities.budget", 6).label
        XCTAssertTrue(budgetAfter.contains("£600K"),
                      "Budget should drop to £600K after the £2.4M spend, got: \(budgetAfter)")

        // A real deduction leaves a mark: switch tabs, return to Club,
        // and confirm the level persists (fixture reseeds only at launch).
        waitFor(app, "career.nav.settings").tap()
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Settings should remain reachable after an upgrade")
        openClub(app)
        XCTAssertTrue(waitFor(app, "career.facilities.level.museum", 8).label == "LVL 2/5",
                      "Museum level must persist across sheet reopen after a real upgrade")
        shot(app, "facilities_after_upgrade")

        // Insufficient-budget state: scouting network needs £3.4M > £0.6M
        // remaining — disabled button, nothing changes when tapped.
        let scoutCost = waitFor(app, "career.facilities.cost.scoutingNetwork", 6)
        XCTAssertTrue(scoutCost.label.contains("£3.4M"), "Scouting next cost should be £3.4M: \(scoutCost.label)")
        let scoutUpgrade = waitFor(app, "career.facilities.upgrade.scoutingNetwork")
        XCTAssertFalse(scoutUpgrade.isEnabled, "Unaffordable upgrade must be disabled")
        scoutUpgrade.tap() // must be a no-op
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(waitFor(app, "career.facilities.level.scoutingNetwork", 4).label == "LVL 1/5",
                      "Blocked upgrade must not change the level")

        // Max-level state after scrolling down.
        let scroll = app.scrollViews["career.facilities.scroll"].firstMatch
        if scroll.exists {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(exists(app, "career.facilities.max.stadium", 6), "Stadium MAX LEVEL badge missing")
        XCTAssertFalse(app.descendants(matching: .any)["career.facilities.upgrade.stadium"].exists,
                       "Maxed facility must not offer an upgrade button")

        // Switching to Settings still works after the upgrade happened.
        waitFor(app, "career.nav.settings").tap()
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Settings should remain reachable after the upgrade")
    }
}
