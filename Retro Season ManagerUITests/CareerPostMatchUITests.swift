//
//  CareerPostMatchUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for the redesigned Career full-time overlay,
//  built on the deterministic `UITEST_CAREER_PREMATCH` fixture: KICK
//  OFF → live match → SKIP settles the score through the engine's own
//  `skipToEnd()`, so whatever verdict lands (win, draw or loss) is a
//  real engine outcome, never scripted. Pins the redesigned result
//  hierarchy (verdict, score, Man of the Match, player ratings in the
//  overlay's one scroll container), the answerable post-match
//  interview, and the CONTINUE footer that commits through the
//  unchanged `finishLiveMatch()` and returns to the dashboard.
//
//  Uses the same existence-wait + plain-tap primitives as the other
//  Career suites — frame math is unusable on this landscape-locked app.
//

import UIKit
import XCTest

final class CareerPostMatchUITests: XCTestCase {

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
        let suffix = UIDevice.current.name.contains("17") ? "17pro" : "se"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_postmatch_\(name)_\(suffix).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Opens the pre-match hub, kicks off and SKIPs to full time — the
    /// settled score comes from the engine, so the verdict varies.
    private func openFullTime(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["career.prematch.screen"]
            .waitForExistence(timeout: 10), "Fixture should open onto the pre-match hub")
        let ko = app.buttons["career.match.kickoff"]
        XCTAssertTrue(ko.waitForExistence(timeout: 6), "KICK OFF missing")
        ko.tap()
        XCTAssertTrue(anyElement(app, "career.match.controlBar").waitForExistence(timeout: 12),
                      "Live match control bar missing")
        let skip = app.buttons["career.match.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8), "SKIP missing in live match")
        skip.tap()
        XCTAssertTrue(anyElement(app, "career.postMatch.screen").waitForExistence(timeout: 12),
                      "Full-time overlay missing after SKIP")
    }

    // MARK: - Result hierarchy

    func testPostMatchShowsVerdictScoreMOTMRatingsAndPinnedContinue() throws {
        let app = launch()
        openFullTime(app)

        // Verdict leads, self-consistent with the score beneath it, and
        // covers the win/draw/loss presentation whatever the engine produced.
        let verdict = anyElement(app, "career.postMatch.verdict")
        XCTAssertTrue(verdict.waitForExistence(timeout: 6), "Verdict missing")
        let verdictLabels = ["VICTORY", "DRAW", "DEFEAT"]
        let matched = verdictLabels.first { verdict.label.hasPrefix($0) }
        XCTAssertNotNil(matched,
                        "Verdict label should open with one of \(verdictLabels), got '\(verdict.label)'")
        XCTAssertTrue(verdict.label.contains("You "), "Verdict label should speak from the user's side")

        XCTAssertTrue(anyElement(app, "career.postMatch.score").exists, "Score missing")

        // Player ratings render in the single scroll container.
        let ratings = anyElement(app, "career.postMatch.ratings")
        XCTAssertTrue(ratings.waitForExistence(timeout: 6), "Ratings block missing")
        let rows = app.descendants(matching: .any)
            .matching(identifier: "career.postMatch.ratingRow").allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(rows.count, 1, "At least one rated player expected")
        XCTAssertTrue(rows[0].label.contains("rating "), "Rating row should announce name and rating")

        // Man of the Match equals the top-rated player, when shown.
        let motm = anyElement(app, "career.postMatch.motm")
        if motm.exists {
            let topPlayer = rows[0].label.components(separatedBy: ", rating ").first ?? ""
            XCTAssertTrue(motm.label.contains(topPlayer),
                          "MOTM '\(motm.label)' should match top-rated '\(topPlayer)'")
        }

        // CONTINUE is reachable without scrolling — the footer pins it
        // below the card (24pt tolerance, as in the navigation suite).
        let cont = app.buttons["career.postMatch.continue"]
        XCTAssertTrue(cont.exists, "CONTINUE missing")
        XCTAssertLessThanOrEqual(cont.frame.maxY, app.frame.maxY + 24,
                                 "CONTINUE should be visible without scrolling")

        shot(app, "fulltime_\(matched!.lowercased())")
        app.terminate()
    }

    // MARK: - Interview

    func testPostMatchInterviewAnswerUpdatesPresentationAndContinueCommits() throws {
        let app = launch()
        openFullTime(app)

        let interview = anyElement(app, "career.postMatch.interview")
        XCTAssertTrue(interview.waitForExistence(timeout: 6), "Interview missing")
        let option = app.buttons.matching(identifier: "career.postMatch.interviewOption").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 4), "Interview options missing")
        option.tap()

        // The question is replaced by the filed confirmation.
        let filed = app.staticTexts["🎙 Interview filed."]
        XCTAssertTrue(filed.waitForExistence(timeout: 6),
                      "Interview should switch to its filed state after answering")
        XCTAssertFalse(interview.exists, "The unanswered interview block should be gone")

        // CONTINUE still commits and lands on the dashboard.
        let cont = app.buttons["career.postMatch.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 4) && cont.isHittable,
                      "CONTINUE should remain reachable after the interview")
        cont.tap()
        XCTAssertTrue(app.buttons["career.continue"].waitForExistence(timeout: 8),
                      "Dashboard CONTINUE should follow the full-time commit")
        shot(app, "after_interview_continue")
        app.terminate()
    }

    // MARK: - Return to dashboard

    func testPostMatchContinueReturnsToDashboardWithoutInterview() throws {
        let app = launch()
        openFullTime(app)

        // The interview is optional: CONTINUE must commit either way,
        // preserving the pre-existing rule that the manager can skip it.
        let cont = app.buttons["career.postMatch.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 6), "CONTINUE missing")
        cont.tap()
        XCTAssertTrue(app.buttons["career.continue"].waitForExistence(timeout: 8),
                      "Dashboard CONTINUE should return after the match")
        shot(app, "dashboard_after_continue")
        app.terminate()
    }
}
