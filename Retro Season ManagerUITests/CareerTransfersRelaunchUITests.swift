//
//  CareerTransfersRelaunchUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for transfer-market persistence across a real
//  app relaunch: the fixture seeds a deterministic career on the FIRST
//  launch; the relaunch intentionally passes NO launch arguments, so
//  nothing is reseeded and the career resumes through the normal Resume
//  path — proving the saved market (identities, prices, free agents)
//  and the shortlist survive exactly, in the product's own persistence.
//
//  The relaunch assertions compare the market card's full accessibility
//  label (name, club, price, scout state) between sessions: a regenerated
//  market would reshuffle prices and players and fail here.
//

import XCTest

final class CareerTransfersRelaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers (same proven primitives as CareerTransfersUITests)

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_transfers_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func screenVisible(_ app: XCUIApplication, _ slug: String, timeout: TimeInterval = 8) -> Bool {
        app.otherElements["career.\(slug).screen"].waitForExistence(timeout: timeout)
            || app.descendants(matching: .any)["career.\(slug).screen"].waitForExistence(timeout: 2)
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func gotoSidebar(_ app: XCUIApplication, _ slug: String) {
        let tab = app.buttons["career.nav.\(slug)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Sidebar item \(slug) missing")
        tab.tap()
    }

    /// The shortlist control's identifier appears both on the market card
    /// and on the shortlist tab's REMOVE row (kept alive in the
    /// hierarchy), so look for the one whose label reads SHORTLISTED.
    private func hasShortlistedControl(_ app: XCUIApplication, _ identifier: String) -> Bool {
        let matches = app.buttons.matching(NSPredicate(format: "identifier == %@", identifier))
        guard matches.firstMatch.waitForExistence(timeout: 6) else { return false }
        for index in 0..<min(matches.count, 6)
        where matches.element(boundBy: index).label == "SHORTLISTED" { return true }
        return false
    }

    private func openTransfers(_ app: XCUIApplication) {
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")
        gotoSidebar(app, "transfers")
        XCTAssertTrue(screenVisible(app, "transfers", timeout: 8), "Transfers destination should open")
        XCTAssertTrue(anyElement(app, "career.transfers.summary").waitForExistence(timeout: 6),
                      "Transfer Centre summary missing")
    }

    // MARK: - Persistence across a real relaunch

    func testMarketAndShortlistSurviveTerminateRelaunchWithoutReseeding() throws {
        // Session 1: seed the deterministic fixture career.
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_TRANSFERS"]
        app.launch()
        openTransfers(app)

        // Record the fixture's shortlisted card (its SHORTLIST control
        // reads SHORTLISTED — seeded through the real store path) and a
        // priced market card's full identity from its accessibility label
        // (name, club, price, scout state) plus the stable card id.
        let shortlistedControls = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                        "career.transfers.shortlist.", "SHORTLISTED"))
        XCTAssertTrue(shortlistedControls.firstMatch.waitForExistence(timeout: 8),
                      "The fixture's shortlisted target should show a SHORTLISTED control")
        let shortlistedCardID = shortlistedControls.firstMatch.identifier
            .replacingOccurrences(of: "career.transfers.shortlist.", with: "career.transfers.card.")

        let pricedCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                  "career.transfers.card.", "Asking price")).firstMatch
        XCTAssertTrue(pricedCard.waitForExistence(timeout: 8),
                      "A priced market card should be visible")
        let pricedCardID = pricedCard.identifier
        let pricedLabelBefore = pricedCard.label
        shot(app, "relaunch_session1")

        // Terminate and relaunch with NO arguments — nothing is reseeded;
        // the career resumes only through the product's own save. Clear
        // the arguments explicitly: launch arguments can persist across
        // XCUIApplication instances within a test session.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments = []
        relaunched.launch()

        // Walk the normal entry path: experience selector → Career mode →
        // Resume the most recent career.
        let careerEntry = relaunched.buttons["experience.career"]
        if !careerEntry.waitForExistence(timeout: 10) {
            try? relaunched.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/relaunch-tree3.txt"))
        }
        XCTAssertTrue(careerEntry.waitForExistence(timeout: 2),
                      "A relaunch must land on the experience selector")
        careerEntry.tap()
        let resume = relaunched.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Resume")).firstMatch
        if !resume.waitForExistence(timeout: 10) {
            try? relaunched.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/relaunch-tree.txt"))
        }
        XCTAssertTrue(resume.waitForExistence(timeout: 2),
                      "A saved career must offer the Resume tile on relaunch")
        resume.tap()

        // The career must come back exactly as saved — same transfers
        // destination, same card identities, same prices, same shortlist.
        XCTAssertTrue(screenVisible(relaunched, "home", timeout: 12),
                      "A resumed career should land on the dashboard")
        gotoSidebar(relaunched, "transfers")
        XCTAssertTrue(anyElement(relaunched, "career.transfers.summary").waitForExistence(timeout: 6),
                      "Transfer Centre summary missing after relaunch")

        // 1. The priced card is the exact same target with an identical
        //    label — a regenerated market would reshuffle prices, players
        //    and order, so this equality is the persistence proof.
        let pricedCardAfter = relaunched.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", pricedCardID)).firstMatch
        XCTAssertTrue(pricedCardAfter.waitForExistence(timeout: 8),
                      "The exact same priced target (stable id) must exist after relaunch")
        XCTAssertEqual(pricedCardAfter.label, pricedLabelBefore,
                       "The priced card's full identity (name, club, price, state) must be identical after a relaunch")

        // 2. The shortlist survived: the same target's control still reads
        //    SHORTLISTED (nothing reseeded it — the relaunch carries no
        //    fixture arguments; this state came from the save).
        XCTAssertTrue(hasShortlistedControl(relaunched, shortlistedCardID.replacingOccurrences(of: "career.transfers.card.", with: "career.transfers.shortlist.")),
                      "The shortlist must survive the relaunch")
        shot(relaunched, "relaunch_session2")
        relaunched.terminate()
    }
}
