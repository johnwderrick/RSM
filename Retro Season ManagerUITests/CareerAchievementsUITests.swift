//
//  CareerAchievementsUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Achievement Gallery and
//  its achievement detail sheet, built on the deterministic
//  `UITEST_CAREER_ACHIEVEMENTS` fixture (itself built on the shared
//  Career navigation fixture). The fixture unlocks through the REAL
//  `unlock(_:)` path — never seeded unlock records — so these tests
//  cover exactly the state real careers produce:
//
//  A. Gallery: the header band shows the fixture's authoritative figures
//     (2 of 17 unlocked, 200 career points), all four category sections
//     render with their per-category counts, unlocked and locked cards
//     are labelled as such, and the single scroll container reaches the
//     end anchor and holds its position.
//  B. Detail round trip: opening an unlocked achievement presents the
//     full record (history card with its real unlock context, points
//     line) and dismissing returns to the same gallery; opening a locked
//     achievement shows the spoiler-free locked state with no history
//     card.
//
//  Same primitive discipline as the accepted suites: existence waits on
//  freshly-queried elements, swipes only on the named scroll container,
//  and plain element taps. XCUIDevice.orientation is never written —
//  the app is landscape-locked.
//

import XCTest

final class CareerAchievementsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_ACHIEVEMENTS"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_achievements_\(suffixed).png"))
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

    /// Opens the Achievement Gallery through the REAL route: Settings →
    /// the whole-building sheet row. Reveals the row by swiping the named
    /// Settings scroll container only.
    @discardableResult
    private func openAchievements(_ app: XCUIApplication) -> XCUIApplication {
        XCTAssertTrue(exists(app, "career.home.screen", 15), "Career home should appear after launch")
        let tab = app.buttons["career.nav.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Settings sidebar item missing")
        tab.tap()
        _ = waitFor(app, "career.settings.summary")

        let row = app.descendants(matching: .any)["career.settings.row.achievements"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Achievements row missing from Settings")
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

        XCTAssertTrue(exists(app, "career.achievements.close", 8), "Achievements sheet close missing")
        XCTAssertTrue(exists(app, "career.achievements.header", 4), "Achievements header missing")
        return app
    }

    /// Reveals an element inside the gallery's scroll container until its
    /// centre is within the container's visible band — swiping whichever
    /// direction the element needs (lazy rows below the fold materialise
    /// on the way down; rows above the viewport only come back on the
    /// way up).
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ identifier: String, maxSwipes: Int = 12) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        let scroll = app.scrollViews["career.achievements.scroll"].firstMatch
        guard scroll.exists else {
            XCTAssertTrue(element.waitForExistence(timeout: 8), "Missing element: \(identifier)")
            return element
        }
        var swipes = 0
        var searchedDown = false
        while swipes < maxSwipes {
            if element.exists {
                let frame = element.frame
                let visible = scroll.frame
                let centreY = frame.minY + frame.height * 0.5
                let centreInside = centreY <= visible.maxY - 8 && frame.minY >= visible.minY
                if centreInside { return element }
                // Element exists but sits above the viewport → scroll back up.
                if frame.minY < visible.minY {
                    scroll.swipeDown()
                    swipes += 1
                    Thread.sleep(forTimeInterval: 0.35)
                    continue
                }
            }
            // Not materialised yet: keep going down, but if the whole way
            // down found nothing, come back up (the element may have been
            // discarded above the viewport).
            if element.exists == false && searchedDown {
                scroll.swipeDown()
            } else {
                scroll.swipeUp()
                searchedDown = true
            }
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 4), "Missing element: \(identifier)")
        return element
    }

    // MARK: - A. Gallery state + scrolling

    func testGalleryShowsAuthoritativeStateAndScrollsAllCategories() throws {
        let app = openAchievements(launch())

        // The header band carries the fixture's authoritative figures:
        // two achievements unlocked through the real unlock path
        // (50 Wins + Giant Killer = 200 career points) out of 17.
        let header = waitFor(app, "career.achievements.header")
        XCTAssertTrue(header.label.contains("2 of 17 unlocked"), "Header should show 2 of 17: \(header.label)")
        XCTAssertTrue(header.label.contains("200 career points"), "Header should show 200 points: \(header.label)")
        shot(app, "achievements_gallery")

        // All four category sections render with their per-category
        // counts, asserted top-to-bottom so the reveal helper scrolls
        // naturally down the gallery.
        for category in ["trophies", "character", "milestones", "legacy"] {
            XCTAssertTrue(exists(app, "career.achievements.category.\(category)", 6),
                          "Category section missing: \(category)")
        }
        // Unlocked and locked cards are labelled as such — the gallery's
        // state comes straight from `unlockedAchievements`.
        let lockedCard = reveal(app, "career.achievements.card.cup-winner")
        XCTAssertTrue(lockedCard.label.contains("Locked"), "Cup Winner should be labelled locked: \(lockedCard.label)")
        XCTAssertTrue(reveal(app, "career.achievements.card.giant-killer").label.contains("Unlocked"),
                      "Giant Killer should be labelled unlocked")
        let milestones = reveal(app, "career.achievements.category.milestones")
        XCTAssertTrue(milestones.label.contains("1 of 4"), "Milestones count should show 1 of 4: \(milestones.label)")
        let unlockedCard = reveal(app, "career.achievements.card.50-wins")
        XCTAssertTrue(unlockedCard.label.contains("Unlocked"), "50 Wins should be labelled unlocked: \(unlockedCard.label)")

        // The single scroll container reaches the end anchor.
        reveal(app, "career.achievements.end")
        shot(app, "achievements_gallery_end")

        // Held position: the gallery must not jump back to the top while
        // the screen is idle.
        let endFrame = app.descendants(matching: .any)["career.achievements.end"].firstMatch.frame
        Thread.sleep(forTimeInterval: 1.2)
        let endFrameAfter = app.descendants(matching: .any)["career.achievements.end"].firstMatch.frame
        XCTAssertEqual(endFrameAfter.minY, endFrame.minY, accuracy: 8,
                       "Gallery must hold its scroll position while idle")
    }

    // MARK: - B. Detail sheet open/close round trip

    func testDetailSheetRoundTripUnlockedAndLocked() throws {
        let app = openAchievements(launch())

        // Open the unlocked 50 Wins card: the detail sheet presents the
        // full record — history card with the real unlock context, and
        // the points line — under a name-slugged root anchor.
        reveal(app, "career.achievements.card.50-wins").tap()
        XCTAssertTrue(exists(app, "career.achievements.detail.50-wins", 8),
                      "Achievement detail sheet missing after opening an unlocked card")
        XCTAssertTrue(exists(app, "career.achievements.detail.close", 4), "Detail close control missing")
        let history = waitFor(app, "career.achievements.detail.history")
        XCTAssertTrue(history.exists, "Unlock history card missing on an unlocked achievement")
        let points = waitFor(app, "career.achievements.detail.points", 6)
        XCTAssertTrue(points.label.contains("+50 CAREER POINTS"), "Points line should show +50: \(points.label)")
        shot(app, "achievements_detail_unlocked")

        // Dismiss and confirm the gallery is exactly as it was.
        waitFor(app, "career.achievements.detail.close").tap()
        waitGone(app, "career.achievements.detail.50-wins", 6)
        XCTAssertTrue(exists(app, "career.achievements.header", 6), "Gallery should still be present after closing the detail")
        XCTAssertTrue(exists(app, "career.achievements.close", 4), "Gallery close should remain after closing the detail")

        // A locked achievement gets the spoiler-free state: locked card,
        // no history card, no points line.
        reveal(app, "career.achievements.card.cup-winner").tap()
        XCTAssertTrue(exists(app, "career.achievements.detail.cup-winner", 8),
                      "Achievement detail sheet missing after opening a locked card")
        let locked = waitFor(app, "career.achievements.detail.locked", 6)
        XCTAssertTrue(locked.label.contains("Locked"), "Locked state line missing: \(locked.label)")
        XCTAssertFalse(exists(app, "career.achievements.detail.history", 1),
                       "Locked achievement must not show an unlock history card")
        XCTAssertFalse(exists(app, "career.achievements.detail.points", 1),
                       "Locked achievement must not show a points line")
        shot(app, "achievements_detail_locked")

        waitFor(app, "career.achievements.detail.close").tap()
        waitGone(app, "career.achievements.detail.cup-winner", 6)
        XCTAssertTrue(exists(app, "career.achievements.header", 6), "Gallery should survive the second detail round trip")
        shot(app, "achievements_after_roundtrip")
    }

    // MARK: - C. Sheet route round trip

    func testGallerySheetClosesBackIntoSettings() throws {
        let app = openAchievements(launch())

        // Close the sheet — the whole-building row presents it straight
        // over the Settings menu, so closing lands back on that menu in
        // the same context (the accepted settings-suite round trip).
        waitFor(app, "career.achievements.close").tap()
        waitGone(app, "career.achievements.header", 6)
        _ = waitFor(app, "career.settings.summary", 8)
        XCTAssertTrue(exists(app, "career.settings.records", 4),
                      "Closing the Achievement Gallery must return to the Settings menu")
        shot(app, "achievements_settings_return")
    }
}
