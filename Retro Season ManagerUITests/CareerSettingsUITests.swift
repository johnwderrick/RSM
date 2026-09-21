//
//  CareerSettingsUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Settings screen, built
//  on the deterministic `UITEST_CAREER_SETTINGS` fixture:
//
//  A. the career summary shows the fixture's authoritative identity and
//     the save card carries the last-saved stamp,
//  B. every real preference can be changed and keeps its value after an
//     away-and-back round trip,
//  C. the newspaper-archive sheet opens, scrolls and closes back into the
//     same Settings context,
//  D. the transfer-history detail page shows the fixture's logged moves,
//  E. SAVE & EXIT persists the career and lands on the main menu,
//  F. scrolling to the lower menu holds its position (no jump-to-top) and
//     away-and-back navigation stays stable.
//
//  Uses the proven existence-wait + plain-tap primitives from
//  CareerNavigationUITests (frame math is unreliable on this
//  landscape-locked app), and swipes only on named scroll containers.
//

import XCTest

final class CareerSettingsUITests: XCTestCase {

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
        let png = XCUIScreen.main.screenshot().pngRepresentation
        // Suffix with the simulator model so SE and 17 Pro runs each keep
        // their own screenshot set on disk.
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "sim"
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_settings_\(name)_\(device).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: "\(name)-\(device)",
                                       payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitFor(_ app: XCUIApplication, _ identifier: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(identifier) missing")
        return element
    }

    private func exists(_ app: XCUIApplication, _ identifier: String, _ timeout: TimeInterval = 6) -> Bool {
        app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }

    /// Reveals an element that may sit below the fold by swiping the
    /// destination's single scroll container until its centre is inside
    /// the container's visible band (the inbox-proven frame-math gate).
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ identifier: String, maxSwipes: Int = 8) -> XCUIElement {
        let element = waitFor(app, identifier)
        let scroll = app.scrollViews["career.settings.scroll"].firstMatch
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

    /// The settings toggles are SwiftUI `Toggle`s whose accessible row
    /// (with the identifier) contains the real switch control as a child.
    /// Tapping the row's label area does nothing — the inner switch must
    /// be tapped directly.
    private func toggleSwitch(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let row = reveal(app, identifier)
        let inner = row.switches.firstMatch
        return inner.exists ? inner : row
    }

    /// The Settings row for a destination. Rows may need revealing from
    /// behind the fold — reveal uses frame math against the named scroll
    /// container (the inbox-proven pattern), swiping the container only.
    @discardableResult
    private func settingsRow(_ app: XCUIApplication, _ slug: String) -> XCUIElement {
        let row = app.descendants(matching: .any)["career.settings.row.\(slug)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Settings row \(slug) missing")
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
        return row
    }

    @discardableResult
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

    // MARK: - A. Summary + save card

    func testSettingsSummaryAndSaveStatusMatchFixture() throws {
        let app = launchToSettings()
        shot(app, "overview")

        let summary = waitFor(app, "career.settings.summary")
        let label = summary.label
        XCTAssertTrue(label.contains("Old Trafford Reds"), "Summary should name the fixture club: \(label)")
        XCTAssertTrue(label.contains("Nav Fixture Manager"), "Summary should name the manager: \(label)")

        // The last-saved stamp exists (a slot is bound) and announces a
        // full save time.
        let lastSaved = waitFor(app, "career.settings.lastSaved")
        XCTAssertTrue(lastSaved.label.hasPrefix("Last saved "), "Unexpected save status: \(lastSaved.label)")

        // Preferences card (below the fold on compact heights) and its
        // three real controls.
        _ = waitFor(app, "career.settings.preferences", 10)
        XCTAssertTrue(exists(app, "career.settings.pref.difficulty", 10), "Difficulty preference missing")
        XCTAssertTrue(exists(app, "career.settings.pref.auto-pick-assist", 10), "Auto-pick preference missing")
        XCTAssertTrue(exists(app, "career.settings.pref.delegate-assistant", 10), "Delegation preference missing")

        // Records card with archive rows (also below the fold).
        _ = waitFor(app, "career.settings.records", 10)
        for slug in ["newspaper-archive", "transfer-history", "season-history"] {
            let row = app.descendants(matching: .any)["career.settings.archive.\(slug)"].firstMatch
            if row.waitForExistence(timeout: 2) { continue }
            let archiveScroll = app.scrollViews["career.settings.scroll"].firstMatch
            if archiveScroll.exists {
                archiveScroll.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
            }
            XCTAssertTrue(row.waitForExistence(timeout: 4), "Archive row \(slug) missing")
        }
    }

    // MARK: - B. Preference round trip

    func testPreferenceChangesSurviveAwayAndBack() throws {
        let app = launchToSettings()

        // Reveal + tap the auto-pick assist (may sit below the fold).
        XCTAssertEqual(waitFor(app, "career.settings.pref.auto-pick-assist").value as? String, "1",
                       "Fixture seeds auto-pick ON")
        toggleSwitch(app, "career.settings.pref.auto-pick-assist").tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(waitFor(app, "career.settings.pref.auto-pick-assist").value as? String, "0",
                       "Tapping the assist must turn it OFF")

        // Away and back.
        let home = app.buttons["career.nav.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        home.tap()
        XCTAssertTrue(exists(app, "career.home.screen", 8))
        let settingsTab = app.buttons["career.nav.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        _ = waitFor(app, "career.settings.summary")

        XCTAssertEqual(waitFor(app, "career.settings.pref.auto-pick-assist").value as? String, "0",
                       "The changed preference must survive away-and-back")

        // Difficulty segmented control round trip through the same route.
        let difficulty = reveal(app, "career.settings.pref.difficulty")
        let hard = difficulty.buttons["Hard"].exists ? difficulty.buttons["Hard"] : app.buttons["Hard"]
        XCTAssertTrue(hard.waitForExistence(timeout: 4), "Difficulty segments missing")
        hard.tap()
        Thread.sleep(forTimeInterval: 0.3)
        home.tap()
        XCTAssertTrue(exists(app, "career.home.screen", 8))
        settingsTab.tap()
        _ = waitFor(app, "career.settings.summary")
        let difficultyBack = reveal(app, "career.settings.pref.difficulty")
        let hardBack = difficultyBack.buttons["Hard"].exists ? difficultyBack.buttons["Hard"] : app.buttons["Hard"]
        XCTAssertTrue(hardBack.waitForExistence(timeout: 4) && hardBack.isSelected,
                      "Difficulty must survive away-and-back")
        // Restore normal.
        let normal = app.buttons["Normal"]
        if normal.exists { normal.tap() }
    }

    // MARK: - C. Newspaper archive sheet

    func testNewspaperArchiveSheetOpensScrollsAndCloses() throws {
        let app = launchToSettings()

        let row = settingsRow(app, "newspaper-archive")
        row.tap()
        let close = waitFor(app, "career.settings.sheet.close", 8)
        XCTAssertTrue(exists(app, "career.settings.archive.header", 4), "Archive header missing")
        shot(app, "archive")

        // Scroll within the archive's container, then close.
        let scroll = app.scrollViews["career.settings.archive.scroll"].firstMatch
        if scroll.exists { scroll.swipeUp(); Thread.sleep(forTimeInterval: 0.3) }
        close.tap()
        Thread.sleep(forTimeInterval: 0.6)

        // Back in Settings, same destination context.
        XCTAssertTrue(exists(app, "career.settings.summary", 8), "Closing the archive must return to Settings")
        _ = waitFor(app, "career.settings.records")
    }

    // MARK: - D. Transfer history detail

    func testTransferHistoryDetailShowsLoggedMoves() throws {
        let app = launchToSettings()

        let row = settingsRow(app, "transfer-history")
        row.tap()
        _ = waitFor(app, "career.settings.back")
        // The fixture logged Danny Draper through the real store path.
        let signing = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Danny Draper'")).firstMatch
        XCTAssertTrue(signing.waitForExistence(timeout: 8), "Logged signing missing from transfer history")
        shot(app, "history")
        waitFor(app, "career.settings.back").tap()
        _ = waitFor(app, "career.settings.summary")
    }

    // MARK: - E. Save & Exit

    func testSaveAndExitReturnsToMainMenuWithSaveIntact() throws {
        let app = launchToSettings()

        let exit = waitFor(app, "career.settings.saveExit")
        exit.tap()

        // The main menu appears (title text) — the career was persisted,
        // not deleted, so the Resume tile is enabled again.
        XCTAssertTrue(app.staticTexts["⚽︎ RETRO SEASON MANAGER"].waitForExistence(timeout: 10),
                      "SAVE & EXIT should land on the main menu")
        XCTAssertTrue(app.staticTexts["Resume"].waitForExistence(timeout: 8),
                      "The persisted career should offer Resume on the menu")
    }

    // MARK: - F. Scroll stability

    func testLowerMenuScrollHoldsPositionAndAwayBackIsStable() throws {
        let app = launchToSettings()

        let scroll = waitFor(app, "career.settings.scroll")
        let end = waitFor(app, "career.settings.end")

        // Reveal the end anchor by swiping the container itself.
        var swipes = 0
        while swipes < 8 {
            if end.frame.minY < scroll.frame.maxY - 8 { break }
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        let endFrame = end.frame
        shot(app, "lower")

        // Hold briefly — the position must not reset.
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(end.frame.minY, endFrame.minY, accuracy: 4,
                       "Settings must not jump back to the top while idle")

        // Away and back lands cleanly.
        let home = app.buttons["career.nav.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        home.tap()
        XCTAssertTrue(exists(app, "career.home.screen", 8))
        let settingsTab = app.buttons["career.nav.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        XCTAssertTrue(exists(app, "career.settings.summary", 8) || exists(app, "career.settings.screen", 8),
                      "Returning to Settings must work after away-and-back")
        _ = waitFor(app, "career.settings.summary")
    }
}
