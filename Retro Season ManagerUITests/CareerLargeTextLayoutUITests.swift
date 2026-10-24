//
//  CareerLargeTextLayoutUITests.swift
//  Retro Season ManagerUITests
//
//  Regression coverage for the larger-text layouts of the screens that
//  used to cap Dynamic Type: the live match (score bar, every control,
//  the half-time recap, the SUBS sheet), the full-time overlay, the
//  season review (ordinary
//  and sacked/job-offer states) and the shared top-bar GO TO MATCH
//  action. Each scenario runs at the default size (Large) and at the
//  largest accessibility size (AX5), set per launch through the
//  `-UIPreferredContentSizeCategoryName` argument so the run never
//  depends on (or changes) the simulator's own text-size setting.
//
//  The checks are what a larger-text user needs: the handoff actions
//  stay fully inside the screen and hittable without scrolling, every
//  other control and the lower information can be brought on screen by
//  native scrolling, and the CONTINUE transitions still land.
//
//  Evidence: every step writes a screenshot and a frame/hittability
//  report as keepAlways attachments, and — when
//  TEST_RUNNER_RSM_LARGETEXT_EVIDENCE_DIR is set — also to that folder
//  together with a full accessibility-tree dump. Frames are read only
//  after existence waits; the reports are evidence, the assertions use
//  the same frames against the app window.
//

import UIKit
import XCTest

final class CareerLargeTextLayoutUITests: XCTestCase {

    private enum TextSize: String {
        case standard = "UICTContentSizeCategoryL"
        case largest = "UICTContentSizeCategoryAccessibilityXXXL"

        var tag: String { self == .standard ? "default" : "ax5" }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & evidence

    private func launch(_ size: TextSize, _ fixture: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = fixture + ["-UIPreferredContentSizeCategoryName", size.rawValue]
        app.launch()
        return app
    }

    private var evidenceDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["RSM_LARGETEXT_EVIDENCE_DIR"],
              !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var deviceTag: String {
        UIDevice.current.name.contains("17") ? "17pro" : "se3"
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Screenshot plus a frame report for the named elements, attached to
    /// the result bundle and copied to the evidence folder when set.
    private func capture(_ app: XCUIApplication, _ size: TextSize, _ step: String,
                         _ elements: [(String, XCUIElement)] = []) {
        let name = "largetext_\(step)_\(size.tag)_\(deviceTag)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let shot = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        shot.lifetime = .keepAlways
        add(shot)

        var lines = ["window \(app.frame)"]
        for (label, element) in elements {
            guard element.exists else { lines.append("\(label): missing"); continue }
            let frame = element.frame
            let onScreen = isFullyOnScreen(element, in: app)
            let hittable = onScreen && element.isHittable
            lines.append("\(label): frame=\(frame) onScreen=\(onScreen) hittable=\(hittable) "
                         + "enabled=\(element.isEnabled) label='\(element.label)'")
        }
        let report = lines.joined(separator: "\n")
        print("LARGETEXT[\(name)]\n\(report)")
        let text = XCTAttachment(string: report)
        text.name = "\(name)_frames"
        text.lifetime = .keepAlways
        add(text)

        if let dir = evidenceDirectory {
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
            try? report.write(to: dir.appendingPathComponent("\(name)_frames.txt"),
                              atomically: true, encoding: .utf8)
            try? app.debugDescription.write(to: dir.appendingPathComponent("\(name)_tree.txt"),
                                            atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Geometry

    /// The part of the screen an element can be seen in: the window,
    /// narrowed to a scroll container and cut off above a pinned footer
    /// that overlaps the container's bottom edge.
    private func visibleRegion(_ app: XCUIApplication, within container: XCUIElement?,
                               above footer: XCUIElement?) -> CGRect {
        var bounds = app.frame
        if let container, container.exists { bounds = bounds.intersection(container.frame) }
        if let footer, footer.exists, footer.frame.minY < bounds.maxY {
            bounds.size.height = max(0, footer.frame.minY - bounds.minY)
        }
        return bounds.insetBy(dx: -1, dy: -1)
    }

    private func isFullyOnScreen(_ element: XCUIElement, in app: XCUIApplication,
                                 within container: XCUIElement? = nil,
                                 above footer: XCUIElement? = nil) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame.width > 1, frame.height > 1 else { return false }
        return visibleRegion(app, within: container, above: footer).contains(frame)
    }

    /// A pinned action: entirely inside the window, hittable, and a
    /// substantial tap target — without any scrolling. PAUSE keeps its
    /// existing compact (~33pt) default design, so it passes a lower floor.
    /// The check waits (up to 8s) for a settled state: the launch rotation
    /// and the transient full-time flash (whose text is not hit-testable
    /// but still answers XCUITest's accessibility hit test) can briefly
    /// disturb frames or hittability.
    private func assertPinned(_ element: XCUIElement, _ app: XCUIApplication, _ what: String,
                              minHeight: CGFloat = 40,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(what) must exist", file: file, line: line)
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { [unowned self] _, _ in
            self.isFullyOnScreen(element, in: app) && element.isHittable
        }, object: nil)
        _ = XCTWaiter.wait(for: [settled], timeout: 8)
        XCTAssertTrue(isFullyOnScreen(element, in: app),
                      "\(what) must sit fully inside the screen, frame \(element.frame) in \(app.frame)",
                      file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(what) must be hittable", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, minHeight,
                                    "\(what) must keep a \(Int(minHeight))pt+ tap target",
                                    file: file, line: line)
    }

    /// Scrolls the container until the element sits fully inside the
    /// visible region, then requires it to be hittable. Drags start inside
    /// that region — never on a pinned footer, which XCUITest's element
    /// swipes can land on once large text makes the footer tall. Far
    /// targets use flinging drags; near ones a measured drag held at its
    /// end so the content does not overshoot a tall panel.
    @discardableResult
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, _ app: XCUIApplication,
                        _ what: String, above footer: XCUIElement? = nil, maxSteps: Int = 40,
                        file: StaticString = #filePath, line: UInt = #line) -> Bool {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(what) must exist", file: file, line: line)
        var steps = 0
        while !isFullyOnScreen(element, in: app, within: scroll, above: footer), steps < maxSteps {
            let region = visibleRegion(app, within: scroll, above: footer).insetBy(dx: 1, dy: 1)
            // Drags also stay clear of the screen's top and bottom edges: on
            // a short landscape screen (iPhone SE) a drag starting ~29pt from
            // the top opens Notification Center over the app instead.
            let clear = region.intersection(app.frame.insetBy(dx: 0, dy: 50))
            let lane = clear.isNull || clear.height < 40 ? region : clear
            let frame = element.frame
            // Positive: content must move up (target below the region).
            let needed = frame.maxY > region.maxY
                ? frame.maxY - region.maxY + 12
                : -(region.minY - frame.minY + 12)
            let far = abs(needed) > lane.height * 1.5
            let travel = far ? lane.height * 0.8 : min(abs(needed), lane.height * 0.8)
            let dy = needed > 0 ? -travel : travel
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: lane.midX, dy: lane.midY - dy / 2))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)),
                        withVelocity: far ? .fast : .slow, thenHoldForDuration: far ? 0 : 0.3)
            steps += 1
            usleep(far ? 600_000 : 300_000)
        }
        let visible = isFullyOnScreen(element, in: app, within: scroll, above: footer)
        XCTAssertTrue(visible, "\(what) must scroll fully on screen, frame \(element.frame) "
                      + "in \(visibleRegion(app, within: scroll, above: footer))", file: file, line: line)
        XCTAssertTrue(visible && element.isHittable, "\(what) must be hittable once revealed",
                      file: file, line: line)
        return visible
    }

    /// Proves the requested size is in effect and not scaled away: at the
    /// largest size the action is at least one full-size AX5 line tall
    /// (a label shrunk to fit one line, as `minimumScaleFactor` did for
    /// GO TO MATCH, measured ~46pt). The season CONTINUE (44pt by default,
    /// 61pt for one AX5 line) uses a 58pt threshold.
    private func assertTextSizeApplied(_ element: XCUIElement, _ size: TextSize, threshold: CGFloat = 70,
                                       file: StaticString = #filePath, line: UInt = #line) {
        if size == .largest {
            XCTAssertGreaterThanOrEqual(element.frame.height, threshold,
                                        "AX5 should render the action at full size, not scaled down",
                                        file: file, line: line)
        } else {
            XCTAssertLessThan(element.frame.height, threshold, "Default size should keep a one-line action",
                              file: file, line: line)
        }
    }

    // MARK: - Live match → full time → dashboard

    private func runLiveMatchAndFullTime(_ size: TextSize) {
        let app = launch(size, ["UITEST_CAREER_PREMATCH"])
        XCTAssertTrue(anyElement(app, "career.prematch.screen").waitForExistence(timeout: 15),
                      "Fixture should open onto the pre-match hub")
        let kickoff = app.buttons["career.match.kickoff"]
        XCTAssertTrue(kickoff.waitForExistence(timeout: 8), "KICK OFF missing")
        kickoff.tap()

        let controlBar = anyElement(app, "career.match.controlBar")
        XCTAssertTrue(controlBar.waitForExistence(timeout: 12), "Live control bar missing")

        // At larger sizes the feed, stats and controls share one scroll
        // container; at the default size every control is already visible.
        let scroll = anyElement(app, "career.match.largeTextScroll")
        if size == .largest {
            XCTAssertTrue(scroll.waitForExistence(timeout: 5),
                          "Larger text must make the live information scrollable")
        } else {
            XCTAssertFalse(scroll.exists, "The default layout should keep its fixed live screen")
        }

        // Run at 3× to the break: CONTINUE TO 2ND HALF stays on screen
        // without scrolling, whatever the recap's height.
        let speed3 = app.buttons["career.match.speed.3"]
        if size == .largest { reveal(speed3, in: scroll, app, "3× speed") }
        speed3.tap()
        let resume = app.buttons["career.match.halfTime.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 45), "The match should reach half time")
        assertPinned(resume, app, "CONTINUE TO 2ND HALF")
        capture(app, size, "halftime", [("resume", resume)])
        resume.tap()
        XCTAssertTrue(resume.waitForNonExistence(timeout: 6), "Resuming should close the half-time recap")

        // The score and PAUSE stay pinned; freeze the clock for a stable tour.
        let pause = app.buttons["career.match.pause"]
        assertPinned(pause, app, "PAUSE", minHeight: 30)
        let score = anyElement(app, "career.match.score")
        XCTAssertTrue(isFullyOnScreen(score, in: app), "The live score must stay on screen")
        pause.tap()

        let controls: [(String, XCUIElement)] = [
            ("speed1", app.buttons["career.match.speed.1"]),
            ("speed2", app.buttons["career.match.speed.2"]),
            ("speed3", app.buttons["career.match.speed.3"]),
            ("skip", app.buttons["career.match.skip"]),
            ("subs", app.buttons["career.match.bar.SUBS 5/5"]),
            ("mentality", app.buttons["career.match.mentality"]),
            ("instruction", app.buttons["career.match.instruction"]),
        ]
        capture(app, size, "live_top", [("pause", pause), ("score", score)] + controls)
        if size == .largest {
            for (name, control) in controls {
                reveal(control, in: scroll, app, "Live control \(name)")
            }
            reveal(anyElement(app, "career.match.statsLine"), in: scroll, app, "Live stats line")
        } else {
            for (name, control) in controls {
                XCTAssertTrue(control.waitForExistence(timeout: 5), "\(name) missing")
                XCTAssertTrue(isFullyOnScreen(control, in: app) && control.isHittable,
                              "\(name) should be visible and hittable without scrolling")
            }
        }
        capture(app, size, "live_controls", [("pause", pause)] + controls)

        // The SUBS sheet keeps MAKE SUB and Cancel reachable.
        let subs = app.buttons["career.match.bar.SUBS 5/5"]
        subs.tap()
        let confirm = app.buttons["career.match.sub.confirm"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 6), "SUBS sheet should open")
        XCTAssertTrue(isFullyOnScreen(confirm, in: app), "MAKE SUB must sit inside the screen")
        XCTAssertTrue(isFullyOnScreen(cancel, in: app) && cancel.isHittable, "Cancel must be hittable")
        capture(app, size, "subs_sheet", [("makeSub", confirm), ("cancel", cancel)])
        if size == .largest {
            // Header and both lists scroll together above the pinned buttons.
            let subsScroll = anyElement(app, "career.match.sub.scroll")
            XCTAssertTrue(subsScroll.waitForExistence(timeout: 5), "The SUBS sheet should scroll at AX5")
            let bench = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'career.match.sub.on.'"))
            XCTAssertGreaterThanOrEqual(bench.count, 1, "Bench players expected")
            let lastBench = bench.element(boundBy: bench.count - 1)
            reveal(lastBench, in: subsScroll, app, "Last bench player")
            XCTAssertTrue(isFullyOnScreen(cancel, in: app) && cancel.isHittable,
                          "Cancel must stay hittable while the lists scroll")
            capture(app, size, "subs_sheet_scrolled", [("lastBench", lastBench), ("cancel", cancel)])
        }
        cancel.tap()
        XCTAssertTrue(controlBar.waitForExistence(timeout: 6), "Cancel should return to the live match")

        // SKIP to full time.
        let skip = app.buttons["career.match.skip"]
        if size == .largest { reveal(skip, in: scroll, app, "SKIP") }
        skip.tap()
        XCTAssertTrue(anyElement(app, "career.postMatch.screen").waitForExistence(timeout: 12),
                      "Full-time overlay missing after SKIP")

        let cont = app.buttons["career.postMatch.continue"]
        let verdict = anyElement(app, "career.postMatch.verdict")
        let fullTimeScroll = anyElement(app, "career.postMatch.scroll")
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "Full-time CONTINUE must exist")
        capture(app, size, "fulltime_top", [("continue", cont), ("verdict", verdict),
                                            ("scroll", fullTimeScroll)])
        assertPinned(cont, app, "Full-time CONTINUE")
        // The verdict capsule (title type) is the size probe here: the
        // footer's own height includes the home-indicator inset on Pro.
        assertTextSizeApplied(verdict, size)

        // The lower result story scrolls into view above the pinned footer.
        XCTAssertTrue(fullTimeScroll.waitForExistence(timeout: 5), "Full-time scroll container missing")
        let rows = app.descendants(matching: .any).matching(identifier: "career.postMatch.ratingRow")
        XCTAssertGreaterThanOrEqual(rows.count, 1, "At least one rated player expected")
        reveal(rows.element(boundBy: rows.count - 1), in: fullTimeScroll, app, "Last rating row")
        let option = app.buttons.matching(identifier: "career.postMatch.interviewOption").firstMatch
        reveal(option, in: fullTimeScroll, app, "Interview answer")
        assertPinned(cont, app, "Full-time CONTINUE while scrolled")
        capture(app, size, "fulltime_scrolled", [("continue", cont), ("interviewOption", option)])
        option.tap()
        XCTAssertTrue(app.staticTexts["🎙 Interview filed."].waitForExistence(timeout: 6),
                      "Answering should file the interview")

        // CONTINUE commits and lands on the dashboard with its top-bar action usable.
        cont.tap()
        let dashboardAction = app.buttons["career.continue"]
        XCTAssertTrue(dashboardAction.waitForExistence(timeout: 10),
                      "The full-time CONTINUE should return to the dashboard")
        assertPinned(dashboardAction, app, "Dashboard top-bar action")
        capture(app, size, "dashboard_after_match", [("topBarAction", dashboardAction)])
        app.terminate()
    }

    func testLiveMatchAndFullTimeAtDefaultText() {
        runLiveMatchAndFullTime(.standard)
    }

    func testLiveMatchAndFullTimeAtLargestAccessibilityText() {
        runLiveMatchAndFullTime(.largest)
    }

    // MARK: - Shared GO TO MATCH action

    private func runGoToMatch(_ size: TextSize) {
        let app = launch(size, ["UITEST_CAREER_PREMATCH"])
        let back = app.buttons["career.prematch.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 15), "Pre-match BACK missing")
        back.tap()

        let action = app.buttons["career.continue"]
        XCTAssertTrue(action.waitForExistence(timeout: 10), "Top-bar action missing on the dashboard")
        XCTAssertEqual(action.label, "GO TO MATCH", "Match day should offer GO TO MATCH")
        assertPinned(action, app, "GO TO MATCH")
        assertTextSizeApplied(action, size)
        capture(app, size, "goto_match", [("goToMatch", action)])

        action.tap()
        XCTAssertTrue(anyElement(app, "career.prematch.screen").waitForExistence(timeout: 10),
                      "GO TO MATCH should open the pre-match hub")
        capture(app, size, "goto_match_prematch")
        app.terminate()
    }

    func testGoToMatchActionAtDefaultText() {
        runGoToMatch(.standard)
    }

    func testGoToMatchActionAtLargestAccessibilityText() {
        runGoToMatch(.largest)
    }

    // MARK: - Season review

    private func openSeasonReview(_ size: TextSize, sacked: Bool) -> XCUIApplication {
        let app = launch(size, ["UITEST_CAREER_SEASON_END"] + (sacked ? ["UITEST_CAREER_SEASON_END_SACKED"] : []))
        XCTAssertTrue(anyElement(app, "career.seasonReview.screen").waitForExistence(timeout: 40),
                      "The season-end fixture should open on the season review")
        return app
    }

    private func assertDashboardAfterRollover(_ app: XCUIApplication, _ size: TextSize, _ step: String) {
        XCTAssertTrue(anyElement(app, "career.home.screen").waitForExistence(timeout: 40),
                      "Starting the next season should land on the Career dashboard")
        let header = anyElement(app, "career.home.seasonLabel")
        XCTAssertTrue(header.waitForExistence(timeout: 30), "Dashboard season label missing")
        XCTAssertTrue(header.label.contains("SEASON 2001/02"),
                      "The dashboard must read as season 2 after exactly one rollover")
        capture(app, size, step, [("topBarAction", app.buttons["career.continue"])])
    }

    private func runSeasonReview(_ size: TextSize) {
        let app = openSeasonReview(size, sacked: false)
        let cont = app.buttons["career.seasonReview.continue"]
        let scroll = anyElement(app, "career.seasonReview.scroll")
        let footer = anyElement(app, "career.seasonReview.footer")
        assertPinned(cont, app, "Season CONTINUE")
        assertTextSizeApplied(cont, size, threshold: 58)
        XCTAssertTrue(cont.isEnabled, "An employed manager can continue straight away")
        capture(app, size, "season_top", [("continue", cont), ("scroll", scroll)])

        // Every panel down to the job offers scrolls into view above the footer.
        reveal(anyElement(app, "career.seasonReview.standingRow.20"), in: scroll, app, "20th standing row",
               above: footer)
        let golden = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '🥇 Golden Boot'")).firstMatch
        reveal(golden, in: scroll, app, "Golden Boot award", above: footer)
        let offers = anyElement(app, "career.seasonReview.jobOffers")
        XCTAssertTrue(offers.waitForExistence(timeout: 5), "Job offers panel missing")
        let accept = offers.buttons.firstMatch
        reveal(accept, in: scroll, app, "First job offer ACCEPT", above: footer)
        assertPinned(cont, app, "Season CONTINUE while scrolled")
        capture(app, size, "season_bottom", [("continue", cont), ("accept", accept)])

        cont.tap()
        assertDashboardAfterRollover(app, size, "season_next_dashboard")
        app.terminate()
    }

    func testSeasonReviewAtDefaultText() {
        runSeasonReview(.standard)
    }

    func testSeasonReviewAtLargestAccessibilityText() {
        runSeasonReview(.largest)
    }

    private func runSackedSeasonReview(_ size: TextSize) {
        let app = openSeasonReview(size, sacked: true)
        let cont = app.buttons["career.seasonReview.continue"]
        let scroll = anyElement(app, "career.seasonReview.scroll")
        let footer = anyElement(app, "career.seasonReview.footer")
        assertPinned(cont, app, "Sacked season CONTINUE")
        XCTAssertFalse(cont.isEnabled, "A sacked manager must choose a job before continuing")
        let banner = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '⚠️ SACKED'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "SACKED banner missing")
        capture(app, size, "sacked_top", [("continue", cont), ("banner", banner)])

        let accept = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Accept job offer from'")).firstMatch
        reveal(accept, in: scroll, app, "Job offer ACCEPT", above: footer)
        accept.tap()
        let accepted = NSPredicate(format: "value == 'Accepted'")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: accepted, object: accept)],
                                      timeout: 6), .completed, "The offer should read as accepted")
        let enabled = NSPredicate(format: "isEnabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: cont)],
                                      timeout: 6), .completed, "Accepting a job should enable CONTINUE")
        assertPinned(cont, app, "Sacked season CONTINUE after accepting")
        capture(app, size, "sacked_accepted", [("continue", cont), ("accept", accept)])

        cont.tap()
        assertDashboardAfterRollover(app, size, "sacked_next_dashboard")
        app.terminate()
    }

    func testSackedSeasonReviewAtDefaultText() {
        runSackedSeasonReview(.standard)
    }

    func testSackedSeasonReviewAtLargestAccessibilityText() {
        runSackedSeasonReview(.largest)
    }
}
