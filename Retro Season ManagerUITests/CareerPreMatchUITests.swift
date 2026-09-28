//
//  CareerPreMatchUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for the redesigned Career pre-match hub
//  (`PreMatchHubView`), built on the deterministic
//  `UITEST_CAREER_PREMATCH` fixture: the hub opens straight onto a user
//  match day with the two-club fixture card (form, odds), the confirmed
//  lineups, ones to watch, the opponent scouting report and — unless
//  `UITEST_CAREER_PREMATCH_NO_PROMPTS` is also set — a definite team talk
//  and press conference. Covers opening the hub, reading the lower
//  content by scrolling (with a no-jump-to-top position check), answering
//  any available team-talk/press prompt, returning with BACK, and
//  reaching the live match through KICK OFF.
//
//  Uses the same existence-wait + plain-tap primitives as
//  CareerNavigationUITests — frame math is unusable on this
//  landscape-locked app (see that file's header for the full story).
//

import XCTest

final class CareerPreMatchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(noPrompts: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["UITEST_CAREER_PREMATCH"]
        if noPrompts { arguments.append("UITEST_CAREER_PREMATCH_NO_PROMPTS") }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_prematch_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// True once the pre-match hub's root is showing (stable
    /// `career.prematch.screen` identifier).
    private func preMatchVisible(_ app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        app.descendants(matching: .any)["career.prematch.screen"].waitForExistence(timeout: timeout)
    }

    /// The pinned action bar can cover a prompt that exists just below
    /// the fold. XCUITest's automatic scroll-to-visible sometimes leaves
    /// its hit point under the bar. One scroll reveals the prompt; asking
    /// `isHittable` here is unreliable on this landscape-locked app and
    /// repeated swipes can carry the prompt past the top edge.
    private func revealPrompt(in app: XCUIApplication) {
        let scroll = app.scrollViews["career.prematch.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 4), "Pre-match scroll container missing")
        scroll.swipeUp()
    }

    private func disappears(_ element: XCUIElement, within timeout: TimeInterval = 4) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: - Opening the hub

    func testPreMatchHubOpensWithFixtureFormAndOdds() throws {
        let app = launch()
        XCTAssertTrue(preMatchVisible(app), "Fixture should open straight onto the pre-match hub")

        // Header band and the leading fixture card.
        XCTAssertTrue(anyElement(app, "career.prematch.header").waitForExistence(timeout: 6),
                      "Pre-match header missing")
        let fixture = anyElement(app, "career.prematch.fixture")
        XCTAssertTrue(fixture.waitForExistence(timeout: 6), "Fixture card missing")

        // Both clubs' form rows and the odds block, above the fold.
        XCTAssertTrue(anyElement(app, "career.prematch.form.your-form").exists, "User form row missing")
        XCTAssertTrue(anyElement(app, "career.prematch.odds").exists, "Match odds missing")
        XCTAssertTrue(app.buttons["career.match.kickoff"].exists, "KICK OFF missing")
        XCTAssertTrue(app.buttons["career.prematch.back"].exists, "BACK missing")
        shot(app, "open_top")
        app.terminate()
    }

    // MARK: - Reading the lower content

    func testPreMatchLowerContentReadableByScrollingWithoutJumpToTop() throws {
        let app = launch()
        XCTAssertTrue(preMatchVisible(app))

        let scroll = app.scrollViews["career.prematch.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 6), "Pre-match scroll container missing")

        // One stable vertical container: the confirmed lineups, ones to
        // watch and scouting cards all live below the fold and are
        // revealed by scrolling the same container. Window-coordinate
        // drags only — element swipes proved unreliable on this
        // landscape-locked app (see CareerNavigationUITests' header).
        let lineups = anyElement(app, "career.prematch.lineups")
        let keyPlayers = anyElement(app, "career.prematch.keyPlayers")
        let scouting = anyElement(app, "career.prematch.scouting")
        let endAnchor = anyElement(app, "career.prematch.endAnchor")
        var swipes = 0
        while !scouting.isHittable && swipes < 8 {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
            swipes += 1
            Thread.sleep(forTimeInterval: 0.45)
        }
        XCTAssertTrue(lineups.waitForExistence(timeout: 4), "Confirmed lineups missing")
        XCTAssertTrue(keyPlayers.waitForExistence(timeout: 4), "Ones to watch missing")
        XCTAssertTrue(scouting.waitForExistence(timeout: 4), "Opponent scouting missing")
        XCTAssertTrue(endAnchor.waitForExistence(timeout: 4), "End anchor missing")
        XCTAssertTrue(scouting.isHittable, "Scouting card should be on-screen after scrolling")
        shot(app, "lower_content")

        // Position must hold: the scouting card keeps its place while the
        // screen idles — the no-jump-to-top guard, frame-accurate within
        // the nav suite's proven 24pt tolerance.
        let heldY = scouting.frame.minY
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(scouting.frame.minY, heldY, accuracy: 24,
                       "Scroll position should hold (no jump to top)")
        XCTAssertTrue(app.buttons["career.match.kickoff"].exists,
                      "KICK OFF must stay reachable at the bottom of the scroll")

        // Scrolling back up returns the fixture card — same container,
        // both directions.
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(anyElement(app, "career.prematch.fixture").exists,
                      "Fixture card should be reachable again scrolling up")
        app.terminate()
    }

    // MARK: - Answering the prompts

    func testPreMatchAnswerTeamTalkAndPressPrompts() throws {
        let app = launch()
        XCTAssertTrue(preMatchVisible(app))

        // The fixture guarantees both prompts.
        let talk = anyElement(app, "career.prematch.teamTalk")
        XCTAssertTrue(talk.waitForExistence(timeout: 6), "Team talk card missing")
        let press = anyElement(app, "career.prematch.pressCard")
        XCTAssertTrue(press.waitForExistence(timeout: 6), "Press conference card missing")

        // Answer the team talk (option 0), then the press conference
        // (option 0) — the real store paths behind the buttons.
        let talkOption = app.buttons["career.prematch.talk.0"]
        XCTAssertTrue(talkOption.waitForExistence(timeout: 4), "Team talk options missing")
        revealPrompt(in: app)
        talkOption.tap()
        XCTAssertTrue(disappears(talk), "Team talk card should disappear once answered")

        let pressOption = app.buttons["career.prematch.press.0"]
        XCTAssertTrue(pressOption.waitForExistence(timeout: 4), "Press options missing")
        revealPrompt(in: app)
        pressOption.tap()
        XCTAssertTrue(disappears(press), "Press card should disappear once answered")

        // Both cards gone: the hub still stands, and KICK OFF still works
        // from here.
        XCTAssertTrue(preMatchVisible(app, timeout: 4), "Hub should remain after answering")
        XCTAssertTrue(app.buttons["career.match.kickoff"].exists, "KICK OFF missing after prompts")
        shot(app, "after_answers")

        // Complete the flow: the live match must open through KICK OFF.
        app.buttons["career.match.kickoff"].tap()
        XCTAssertTrue(app.buttons["career.match.skip"].waitForExistence(timeout: 12),
                      "Live match should open after KICK OFF")
        app.terminate()
    }

    // MARK: - BACK returns; KICK OFF starts the match

    func testPreMatchBackReturnsToDashboardAndKickOffReachesLiveMatch() throws {
        let app = launch()
        XCTAssertTrue(preMatchVisible(app))

        // BACK: straight back to the dashboard (atPreMatch = false).
        let back = app.buttons["career.prematch.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 6), "BACK missing")
        back.tap()
        XCTAssertTrue(app.buttons["career.continue"].waitForExistence(timeout: 8),
                      "Dashboard CONTINUE should return after BACK")
        shot(app, "after_back")

        // Re-enter the hub the way production does: the CONTINUE button
        // auto-enters the hub on a match day.
        let cont = app.buttons["career.continue"]
        cont.tap()
        XCTAssertTrue(preMatchVisible(app), "CONTINUE should re-enter the pre-match hub")

        // KICK OFF: the live match opens with its SKIP control.
        let ko = app.buttons["career.match.kickoff"]
        XCTAssertTrue(ko.waitForExistence(timeout: 6), "KICK OFF missing on re-entry")
        ko.tap()
        XCTAssertTrue(app.buttons["career.match.skip"].waitForExistence(timeout: 12),
                      "Live match should open after KICK OFF")
        shot(app, "live_match")
        app.terminate()
    }

    // MARK: - No-prompts variant

    func testPreMatchWithoutPromptsSkipsStraightToFixtureFlow() throws {
        let app = launch(noPrompts: true)
        XCTAssertTrue(preMatchVisible(app))

        XCTAssertFalse(anyElement(app, "career.prematch.teamTalk").exists,
                       "No team talk expected with NO_PROMPTS")
        XCTAssertFalse(anyElement(app, "career.prematch.pressCard").exists,
                       "No press conference expected with NO_PROMPTS")
        XCTAssertTrue(anyElement(app, "career.prematch.fixture").waitForExistence(timeout: 6),
                      "Fixture card missing in no-prompt variant")

        // BACK from the prompt-free hub still returns to the dashboard.
        app.buttons["career.prematch.back"].tap()
        XCTAssertTrue(app.buttons["career.continue"].waitForExistence(timeout: 8),
                      "Dashboard CONTINUE should return after BACK")
        app.terminate()
    }
}
