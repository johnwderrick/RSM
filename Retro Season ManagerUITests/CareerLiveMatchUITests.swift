//
//  CareerLiveMatchUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for the Career live-match screen (`MatchView`)
//  on phone landscape, built on the deterministic
//  `UITEST_CAREER_PREMATCH` fixture: the hub's KICK OFF opens the live
//  match with its score bar, commentary feed, stats and every match
//  control (pause, 1×/2×/3× speed, SKIP, mentality/instruction pickers,
//  SUBS) present and tappable; the score bar reports the two sides; and
//  SKIP reaches the full-time card whose CONTINUE returns to the
//  dashboard. The redesign keeps the engine, overlays and outcomes
//  untouched — these tests pin the control surface, not the result.
//
//  Uses the same existence-wait + plain-tap primitives as
//  CareerNavigationUITests — frame math is unusable on this
//  landscape-locked app (see that file's header for the full story).
//

import UIKit
import XCTest

final class CareerLiveMatchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_PREMATCH"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_livematch_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Pulls the day count out of a countdown label ("Next match in 3 days"),
    /// returning nil for labels that aren't day countdowns (MATCH DAY,
    /// CUP DAY, SEASON COMPLETE, empty) — callers then skip the assertion.
    private func countdownDays(from label: String) -> Int? {
        guard let range = label.range(of: "Next match in ") else { return nil }
        let token = label[range.upperBound...].split(separator: " ").first.map(String.init) ?? ""
        return Int(token)
    }

    private func pendingOfferCount(_ app: XCUIApplication) -> Int {
        // Match the label in the query itself: Home can disappear between
        // an exists check and a subsequent label read when pre-match opens.
        // Deadline day caps live offers at four (ordinary days at two).
        for count in (1...4).reversed() {
            let label = "⚠️ \(count) bid\(count == 1 ? "" : "s")"
            let predicate = NSPredicate(format: "identifier == %@ AND label == %@",
                                        "career.home.pendingOffers", label)
            if app.descendants(matching: .any).matching(predicate).firstMatch.exists {
                return count
            }
        }
        return 0
    }

    /// Re-evaluates the element until the predicate holds — plain
    /// re-queries after a tap are racy because SwiftUI may not have
    /// re-rendered the changed trait yet. Uses a standalone expectation
    /// (not registered on the test case) so a timeout stays the caller's
    /// decision instead of failing the test at teardown.
    @discardableResult
    private func wait(_ element: XCUIElement, _ predicate: NSPredicate,
                      timeout: TimeInterval = 4) -> Bool {
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    /// Opens the pre-match hub and kicks off into the live match.
    private func openLiveMatch(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["career.prematch.screen"]
            .waitForExistence(timeout: 10), "Fixture should open onto the pre-match hub")
        let ko = app.buttons["career.match.kickoff"]
        XCTAssertTrue(ko.waitForExistence(timeout: 6), "KICK OFF missing")
        ko.tap()
        XCTAssertTrue(anyElement(app, "career.match.controlBar").waitForExistence(timeout: 12),
                      "Live match control bar missing")
    }

    /// SKIP runs the engine's own `skipToEnd()` fast-forward, so the full
    /// score is settled the way the original UI path settles it.
    private func skipToFullTime(_ app: XCUIApplication) {
        let skip = app.buttons["career.match.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8), "SKIP missing in live match")
        skip.tap()
        let postMatch = app.buttons["career.postMatch.continue"]
        XCTAssertTrue(postMatch.waitForExistence(timeout: 12), "Full-time CONTINUE missing after SKIP")
    }

    // MARK: - Control surface on phone landscape

    func testLiveMatchShowsScoreStatsAndAllMatchControls() throws {
        let app = launch()
        openLiveMatch(app)

        // Score bar: the two sides and the pause control.
        let score = anyElement(app, "career.match.score")
        XCTAssertTrue(score.waitForExistence(timeout: 6), "Score element missing")
        XCTAssertTrue(score.label.contains("vs") || score.label.contains(","),
                      "Score label should name both clubs")
        XCTAssertTrue(app.buttons["career.match.pause"].exists, "Pause control missing")
        XCTAssertTrue(app.buttons["career.match.pause"].isEnabled,
                      "Pause should be enabled while the match runs")

        // Stats: the compact line (phone landscape) or full rows.
        let statsLine = anyElement(app, "career.match.statsLine")
        let statsFull = anyElement(app, "career.match.stats")
        XCTAssertTrue(statsLine.exists || statsFull.exists, "Live stats missing")

        // Every match control, all with stable identifiers.
        for identifier in ["career.match.speed.1", "career.match.speed.2", "career.match.speed.3",
                           "career.match.skip", "career.match.bar.SUBS 5/5"] {
            XCTAssertTrue(app.buttons[identifier].exists, "Control \(identifier) missing")
        }
        XCTAssertTrue(app.buttons["career.match.speed.1"].isSelected,
                      "1× should start selected")
        XCTAssertTrue(app.buttons["career.match.mentality"].exists, "Mentality picker missing")
        XCTAssertTrue(app.buttons["career.match.instruction"].exists, "Instruction picker missing")
        shot(app, "controls")
        // A device-suffixed capture of the control surface, so reruns on
        // a different simulator never overwrite a previous device's set.
        let model = UIDevice.current.name
        shot(app, "controls_\(model.contains("17") ? "17pro" : "se")")
        app.terminate()
    }

    // MARK: - Controls actually act

    func testLiveMatchPauseSpeedAndTacticsActWithoutBreakingPlayback() throws {
        let app = launch()
        openLiveMatch(app)

        // Pause then resume — the production pause/resume paths.
        let pause = app.buttons["career.match.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 6), "Pause control missing")
        XCTAssertTrue(wait(pause, NSPredicate(format: "label CONTAINS 'PAUSE'")),
                      "Running match should offer PAUSE")
        pause.tap()
        XCTAssertTrue(wait(pause, NSPredicate(format: "label CONTAINS 'PLAY'")),
                      "Pausing should swap the control to PLAY")
        pause.tap()
        XCTAssertTrue(wait(pause, NSPredicate(format: "label CONTAINS 'PAUSE'")),
                      "Resuming should return the control to PAUSE")

        // Speed: 2× becomes the selected speed, then back to 1×.
        let speed2 = app.buttons["career.match.speed.2"]
        speed2.tap()
        XCTAssertTrue(wait(speed2, NSPredicate(format: "isSelected == true")),
                      "2× should become the selected speed")
        app.buttons["career.match.speed.1"].tap()
        XCTAssertTrue(wait(app.buttons["career.match.speed.1"],
                           NSPredicate(format: "isSelected == true")),
                      "1× should be selectable again")

        // Native menus can make XCTest wait for animation quiescence.
        // Freeze the match while choosing tactics so that CI latency cannot
        // advance it to the half-time overlay behind the open menu.
        pause.tap()
        XCTAssertTrue(wait(pause, NSPredicate(format: "label CONTAINS 'PLAY'")),
                      "Match should pause before opening the tactics menu")

        // Tactics: the mentality menu opens and offers its cases.
        let mentality = app.buttons["career.match.mentality"]
        mentality.tap()
        let attacking = app.buttons["Attacking"]
        XCTAssertTrue(attacking.waitForExistence(timeout: 4), "Mentality menu should list its options")
        attacking.tap()

        XCTAssertTrue(wait(mentality, NSPredicate(format: "label CONTAINS 'Attacking'")),
                      "Choosing Attacking should update the mentality control")
        XCTAssertTrue(wait(pause, NSPredicate(format: "label CONTAINS 'PLAY'")),
                      "Choosing tactics should leave the paused match paused")
        pause.tap()
        XCTAssertTrue(wait(pause, NSPredicate(format: "label CONTAINS 'PAUSE'")),
                      "Playback should resume after choosing tactics")

        // The live score remains present after resuming playback.
        XCTAssertTrue(anyElement(app, "career.match.score").exists,
                      "Score bar should remain after control interactions")
        shot(app, "after_controls")

        skipToFullTime(app)
        app.terminate()
    }

    // MARK: - Substitutions sheet

    func testLiveMatchSubsSheetOpensAndCancels() throws {
        let app = launch()
        openLiveMatch(app)

        let subs = app.buttons["career.match.bar.SUBS 5/5"]
        XCTAssertTrue(subs.waitForExistence(timeout: 6), "SUBS control missing")
        subs.tap()
        XCTAssertTrue(app.staticTexts["SUBSTITUTIONS"].waitForExistence(timeout: 6),
                      "Substitutions sheet should open")
        XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel control missing")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(anyElement(app, "career.match.controlBar").waitForExistence(timeout: 6),
                      "Cancelling should return to the live match")
        shot(app, "after_subs_cancel")

        skipToFullTime(app)
        app.terminate()
    }

    // MARK: - Skip and full time

    func testLiveMatchSkipReachesFullTimeContinueReturnsToDashboard() throws {
        let app = launch()
        openLiveMatch(app)
        skipToFullTime(app)

        // Answer the post-match interview if it is in the way, then
        // CONTINUE — the same route the navigation regression pins.
        let postMatch = app.buttons["career.postMatch.continue"]
        if postMatch.isHittable {
            postMatch.tap()
        } else {
            for option in ["Praise the players", "Stay grounded", "A fair result",
                           "Two points dropped", "Take responsibility", "Criticise the players"] {
                let b = app.buttons.matching(NSPredicate(format: "label == %@", option)).firstMatch
                if b.exists { b.tap(); break }
            }
            XCTAssertTrue(postMatch.waitForExistence(timeout: 4) && postMatch.isHittable,
                          "Full-time CONTINUE should become reachable after the interview")
            postMatch.tap()
        }

        XCTAssertTrue(app.buttons["career.continue"].waitForExistence(timeout: 8),
                      "Dashboard CONTINUE should return after the match")

        // The dashboard's next-match countdown must never count backwards:
        // a past-due commitment (the stranded-cup-tie regression) rendered
        // as "Next match in -12 days" here. After full time the next match
        // is either today, genuinely upcoming, or absent — never negative.
        let countdown = anyElement(app, "career.home.countdown")
        XCTAssertTrue(countdown.waitForExistence(timeout: 6), "Dashboard countdown missing")
        if let days = countdownDays(from: countdown.label) {
            XCTAssertGreaterThanOrEqual(days, 0,
                "Countdown must never be negative — got '\(countdown.label)'")
        }
        shot(app, "after_fulltime")
        // A device-suffixed capture of the same dashboard, so reruns on a
        // different simulator never overwrite a previous device's set.
        let model = UIDevice.current.name
        shot(app, "after_fulltime_\(model.contains("17") ? "17pro" : "se")")

        // A newly arrived transfer bid deliberately interrupts SKIP TO
        // MATCH. Keep skipping after that interruption, as a manager would
        // with another tap; each interruption must show a new bid rather
        // than silently leaving the dashboard unchanged.
        let skipToMatch = app.buttons["career.home.skipToMatch"]
        XCTAssertTrue(skipToMatch.waitForExistence(timeout: 6), "SKIP TO MATCH missing")
        let preMatch = anyElement(app, "career.prematch.screen")
        for _ in 0..<5 where !preMatch.exists {
            let offersBefore = pendingOfferCount(app)
            skipToMatch.tap()
            let deadline = Date().addingTimeInterval(20)
            var offersAfter = offersBefore
            while Date() < deadline && !preMatch.exists && offersAfter <= offersBefore {
                offersAfter = pendingOfferCount(app)
                if offersAfter <= offersBefore { Thread.sleep(forTimeInterval: 0.25) }
            }
            if !preMatch.exists {
                XCTAssertGreaterThan(offersAfter, offersBefore,
                    "SKIP TO MATCH stopped before the next fixture without a new transfer bid")
            }
        }
        XCTAssertTrue(preMatch.exists,
            "SKIP TO MATCH should reach the pre-match hub after any new bids interrupting the skip")
        app.terminate()
    }
}
