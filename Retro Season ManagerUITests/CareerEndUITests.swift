//
//  CareerEndUITests.swift
//  Retro Season ManagerUITests
//
//  Career End presentation, scroll reachability, archive handoff and sparse
//  honours coverage. Every launch uses an isolated DEBUG fixture archive.
//

import XCTest

final class CareerEndUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_END"] + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let filename = "career_end_\(name)_\(model)"
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let rotatedData = data
        let artifactDirectory = URL(fileURLWithPath: "/private/tmp/rsm-freebuff-career-end-light-cards/artifacts", isDirectory: true)
        try? FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        let screenshotURL = artifactDirectory.appendingPathComponent("\(filename).png")
        try? rotatedData.write(to: screenshotURL)
        print("CAREER_END_SCREENSHOT \(screenshotURL.path)")
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: filename, payload: rotatedData)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitFor(_ app: XCUIApplication, _ id: String, _ timeout: TimeInterval = 10) -> XCUIElement {
        let element = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing element: \(id)")
        return element
    }

    private func visible(_ element: XCUIElement, within scroll: XCUIElement) -> Bool {
        let frame = element.frame
        let viewport = scroll.frame
        let centre = frame.minY + frame.height / 2
        return centre >= viewport.minY && centre <= viewport.maxY - 8
    }

    private func reveal(_ app: XCUIApplication, _ id: String, maxSwipes: Int = 18) -> XCUIElement {
        let scroll = waitFor(app, "career.end.scroll")
        var swipes = 0
        while swipes < maxSwipes {
            let target = app.descendants(matching: .any)[id].firstMatch
            if target.exists && visible(target, within: scroll) { return target }
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.3)
        }
        return app.descendants(matching: .any)[id].firstMatch
    }

    func testSummaryAndEarnedHonoursAndAchievements() throws {
        let app = launch()
        let summary = waitFor(app, "career.end.summary")
        XCTAssertTrue(summary.label.contains("Morgan Example"), summary.label)
        XCTAssertTrue(summary.label.contains("Old Trafford Reds"), summary.label)
        XCTAssertTrue(summary.label.contains("4 seasons"), summary.label)

        let honours = waitFor(app, "career.end.honours")
        XCTAssertTrue(honours.label.contains("First Division title"), honours.label)
        XCTAssertTrue(honours.label.contains("National Cup"), honours.label)
        let achievements = reveal(app, "career.end.achievements")
        XCTAssertTrue(achievements.label.contains("2 earned"), achievements.label)
        XCTAssertTrue(waitFor(app, "career.end.achievement.50-wins").label.contains("50 Wins"))
        XCTAssertTrue(waitFor(app, "career.end.achievement.giant-killer").label.contains("Giant Killer"))
        shot(app, "summary")
        app.terminate()
    }

    func testLongContentScrollsAndPinnedMenuRemainsReachable() throws {
        let app = launch(["UITEST_CAREER_END_LONG"])
        let scroll = waitFor(app, "career.end.scroll")
        let menu = waitFor(app, "career.end.menu")
        XCTAssertTrue(menu.isHittable, "Pinned menu action must be reachable at the initial scroll position")
        var swipes = 0
        while swipes < 24 {
            let refreshedEnd = app.descendants(matching: .any)["career.end.contentEnd"].firstMatch
            if refreshedEnd.exists && visible(refreshedEnd, within: scroll) { break }
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.3)
        }
        let endAtBottom = app.descendants(matching: .any)["career.end.contentEnd"].firstMatch
        XCTAssertTrue(endAtBottom.exists && visible(endAtBottom, within: scroll),
                      "Long retrospective should scroll to its end")
        XCTAssertTrue(menu.isHittable, "Pinned menu action must remain reachable after scrolling")
        shot(app, "long_end")
        app.terminate()
    }

    func testMenuArchivesOnceAndMuseumShowsTheEndedCareer() throws {
        let app = launch(["UITEST_CAREER_END_ARCHIVE"])
        waitFor(app, "career.end.menu").tap()
        let museumTile = waitFor(app, "career.menu.museum", 12)
        if !museumTile.isHittable { app.swipeLeft() }
        museumTile.tap()
        let museumHeader = waitFor(app, "career.museum.header", 12)
        XCTAssertTrue(museumHeader.label.contains("1 archived career"), museumHeader.label)
        let archive = waitFor(app, "career.museum.career.morgan-example", 10)
        XCTAssertTrue(archive.label.contains("Morgan Example"), archive.label)
        XCTAssertTrue(archive.label.contains("Old Trafford Reds"), archive.label)
        shot(app, "museum_handoff")
        app.terminate()
    }

    func testSparseCareerShowsHonoursEmptyStateAndNoInventedAchievements() throws {
        let app = launch(["UITEST_CAREER_END_SPARSE"])
        let emptyHonours = waitFor(app, "career.end.honours.empty")
        XCTAssertTrue(emptyHonours.label.contains("No major honours"), emptyHonours.label)
        let emptyAchievements = waitFor(app, "career.end.achievements.empty")
        XCTAssertTrue(emptyAchievements.label.contains("No achievements earned"), emptyAchievements.label)
        shot(app, "sparse")
        app.terminate()
    }

    /// Baseline audit capture retained as a separate artifact from the
    /// redesigned screen for before/after visual review.
    func testBaselineCareerEndScreenScreenshot() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["CAREER COMPLETE"].waitForExistence(timeout: 20))
        shot(app, "baseline")
        app.terminate()
    }
}
