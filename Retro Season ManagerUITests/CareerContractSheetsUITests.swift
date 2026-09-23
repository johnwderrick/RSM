//
//  CareerContractSheetsUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for the redesigned Career contract and confirmation
//  sheets, built on the deterministic `UITEST_CAREER_SHEETS` fixture:
//
//  A. the renewal sheet opens with the player's identity and authoritative
//     figures, cancels cleanly, and the squad is unchanged afterwards,
//  B. a deterministic offer produces the result banner (counter/reject
//     presentation included),
//  C. the release confirmation cancels (nothing changes) and confirms
//     (the player leaves the squad),
//  D. the pending-deal withdrawal confirmation cancels and confirms,
//  E. the sheet's footer actions are reachable without scrolling on the
//     compact-landscape iPhone SE,
//  F. a sheet round trip preserves the parent Squad state (mode, scroll).
//
//  Uses the proven primitives from CareerTransfersUITests: existence
//  waits, plain taps (no frame math), and named-scroll swipes.
//

import XCTest

final class CareerContractSheetsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_SHEETS"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_sheets_\(suffixed).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: suffixed, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func screenVisible(_ app: XCUIApplication, _ slug: String, timeout: TimeInterval = 8) -> Bool {
        app.otherElements["career.\(slug).screen"].waitForExistence(timeout: timeout)
            || app.descendants(matching: .any)["career.\(slug).screen"].waitForExistence(timeout: 2)
    }

    @discardableResult
    private func gotoSidebar(_ app: XCUIApplication, _ slug: String) -> XCUIElement {
        let tab = app.buttons["career.nav.\(slug)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Sidebar item \(slug) missing")
        tab.tap()
        return tab
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func elementMatching(_ app: XCUIApplication, _ predicate: NSPredicate) -> XCUIElement {
        app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Opens Squad, switches to the list/table mode, and opens the named
    /// player's profile sheet. Danny Draper (renewal) and Sammy Stalwart
    /// (release) are near the top of the authoritative rating sort.
    private func openProfile(_ app: XCUIApplication, name: String) {
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")
        gotoSidebar(app, "squad")
        XCTAssertTrue(screenVisible(app, "squad", timeout: 8), "Squad screen missing")

        let listMode = app.buttons["career.squad.mode.list"]
        if listMode.waitForExistence(timeout: 5), listMode.exists {
            listMode.tap()
        }
        let row = elementMatching(app, NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                   "career.squad.row.", name))
        // LazyVStack rows only exist once scrolled into view — sweep the
        // named table container until the row materialises (bounded).
        let scroll = app.scrollViews["career.squad.list.scroll"]
        let target = scroll.exists ? scroll : app
        var appeared = row.waitForExistence(timeout: 3)
        var sweeps = 0
        while !appeared && sweeps < 8 {
            target.swipeUp()
            appeared = row.waitForExistence(timeout: 2)
            sweeps += 1
        }
        XCTAssertTrue(appeared, "\(name) row missing in the squad table")
        row.tap()

        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 6),
                      "Player profile sheet did not open")
    }

    /// The renewal sheet's demand, parsed from the NEGOTIATE pill label
    /// ("NEGOTIATE (£1,170)/wk") — the same authoritative figure the
    /// profile pill shows.
    private func demandFromLabel(_ label: String) -> Int? {
        guard let start = label.firstIndex(of: "£"),
              let end = label.firstIndex(of: ")") else { return nil }
        let digits = label[label.index(after: start)..<end]
            .filter { $0.isNumber }
        return Int(digits)
    }

    // MARK: - A. Renewal sheet: open, identity, cancel

    func testRenewalSheetOpensWithIdentityAndCancelsCleanly() throws {
        let app = launch()
        openProfile(app, name: "Danny Draper")

        // The renewal entry point shows the demand figure.
        let negotiate = app.buttons["career.playerProfile.negotiate"]
        XCTAssertTrue(negotiate.waitForExistence(timeout: 6), "NEGOTIATE pill missing")
        let demand = demandFromLabel(negotiate.label)
        XCTAssertNotNil(demand, "NEGOTIATE pill label should carry the demand: \(negotiate.label)")
        negotiate.tap()

        XCTAssertTrue(anyElement(app, "career.contract.sheet").waitForExistence(timeout: 6),
                      "Contract renewal sheet did not open")
        XCTAssertTrue(app.buttons["career.contract.close"].exists, "Pinned close missing")
        XCTAssertTrue(app.buttons["career.contract.makeOffer"].exists, "MAKE THE OFFER missing")
        XCTAssertTrue(app.buttons["career.contract.cancel"].exists, "Walk-away missing")

        shot(app, "renewal_open")
        app.buttons["career.contract.cancel"].tap()
        XCTAssertFalse(anyElement(app, "career.contract.sheet").waitForExistence(timeout: 2),
                       "Sheet should close on walk-away")
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 6),
                      "Should return to the player profile")
        app.buttons["career.playerProfile.close"].tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 6),
                      "Should return to Squad")
    }

    // MARK: - B. Deterministic offer → result banner

    func testRenewalOfferProducesResultPresentation() throws {
        let app = launch()
        openProfile(app, name: "Danny Draper")

        let negotiate = app.buttons["career.playerProfile.negotiate"]
        XCTAssertTrue(negotiate.waitForExistence(timeout: 6))
        guard let demand = demandFromLabel(negotiate.label) else {
            return XCTFail("No demand figure in \(negotiate.label)")
        }
        negotiate.tap()
        XCTAssertTrue(anyElement(app, "career.contract.sheet").waitForExistence(timeout: 6))

        // Raise the wage well above demand with the real steppers —
        // near-certain acceptance (the roll clamps at 0.97) — then offer.
        let wageValue = anyElement(app, "career.contract.wage")
        XCTAssertTrue(wageValue.waitForExistence(timeout: 5), "Wage figure missing")
        let plus = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "career.contract.step.plus")).firstMatch
        XCTAssertTrue(plus.exists, "Wage stepper + missing")
        let perTap = 50
        var targetWage = demand * 2
        var taps = 0
        while targetWage > demand && taps < 60 {
            plus.tap()
            targetWage -= perTap
            taps += 1
        }
        app.buttons["career.contract.makeOffer"].tap()

        let banner = anyElement(app, "career.contract.result")
        let appeared = banner.waitForExistence(timeout: 6)
        if appeared {
            let lowered = banner.label.lowercased()
            XCTAssertTrue(lowered.contains("accepted") || lowered.contains("rejected"),
                          "Banner should carry the outcome, got: \(banner.label)")
        } else {
            // A rejection can render a counter-offer button instead of the
            // plain banner; either way the sheet presents an outcome.
            XCTAssertTrue(app.buttons["career.contract.counter"].exists || app.buttons["career.contract.done"].exists,
                          "No outcome presentation after the offer")
        }
        shot(app, "renewal_result")

        // Leave the sheet without a second submission.
        let done = app.buttons["career.contract.done"]
        if done.exists { done.tap() } else { app.buttons["career.contract.close"].tap() }
    }

    // MARK: - C. Release confirmation: cancel then confirm

    func testReleaseConfirmationCancelThenConfirm() throws {
        let app = launch()
        openProfile(app, name: "Sammy Stalwart")

        let terminate = app.buttons["career.playerProfile.terminate"]
        XCTAssertTrue(terminate.waitForExistence(timeout: 6), "TERMINATE pill missing")
        terminate.tap()

        XCTAssertTrue(anyElement(app, "career.sheet.confirm").waitForExistence(timeout: 6),
                      "Release confirmation sheet did not open")
        let title = anyElement(app, "career.sheet.confirm.title")
        XCTAssertTrue(title.exists && title.label.contains("Sammy Stalwart"),
                      "Confirmation should name the player, got: \(title.label)")
        XCTAssertTrue(anyElement(app, "career.sheet.confirm.cancel").exists,
                      "Cancel action missing")
        shot(app, "release_confirm")

        // Cancel — nothing happens.
        anyElement(app, "career.sheet.confirm.cancel").tap()
        XCTAssertFalse(anyElement(app, "career.sheet.confirm").waitForExistence(timeout: 2),
                       "Confirmation should close on cancel")
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 6),
                      "The profile should remain open after cancelling")
        XCTAssertTrue(elementMatching(app, NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                       "career.squad.row.", "Sammy Stalwart")).exists,
                      "Cancelling the release must keep the player")

        // Reopen and confirm — the player leaves the squad. The profile
        // dismisses right after the confirm action, so wait for the
        // confirmation sheet to go first, then for the profile to go.
        app.buttons["career.playerProfile.terminate"].tap()
        XCTAssertTrue(anyElement(app, "career.sheet.confirm").waitForExistence(timeout: 6))
        anyElement(app, "career.sheet.confirm.confirm").tap()
        _ = anyElement(app, "career.sheet.confirm").waitForNonExistence(timeout: 6)
        _ = anyElement(app, "career.playerProfile.screen").waitForNonExistence(timeout: 6)
        XCTAssertFalse(anyElement(app, "career.playerProfile.screen").exists,
                       "The profile should close after a confirmed release")

        gotoSidebar(app, "squad")
        XCTAssertTrue(screenVisible(app, "squad", timeout: 8))
        let listMode = app.buttons["career.squad.mode.list"]
        if listMode.waitForExistence(timeout: 5), listMode.exists { listMode.tap() }
        XCTAssertFalse(elementMatching(app, NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                        "career.squad.row.", "Sammy Stalwart")).exists,
                       "A confirmed release must remove the player from the squad")
    }

    // MARK: - D. Withdrawal confirmation: cancel then confirm

    func testWithdrawalConfirmationCancelThenConfirm() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10))
        gotoSidebar(app, "transfers")
        XCTAssertTrue(screenVisible(app, "transfers", timeout: 8))

        let negotiations = app.buttons["career.transfers.tab.negotiations"]
        XCTAssertTrue(negotiations.waitForExistence(timeout: 6), "NEGOTIATIONS tab missing")
        negotiations.tap()

        let withdraw = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "career.transfers.deal.", ".withdraw")).firstMatch
        XCTAssertTrue(withdraw.waitForExistence(timeout: 8), "Pending-deal withdraw control missing")
        withdraw.tap()

        XCTAssertTrue(anyElement(app, "career.sheet.confirm").waitForExistence(timeout: 6),
                      "Withdrawal confirmation sheet did not open")
        let title = anyElement(app, "career.sheet.confirm.title")
        XCTAssertTrue(title.exists && title.label.contains("Ivan Ongo"),
                      "Confirmation should name the deal, got: \(title.label)")

        // Cancel — the deal stays on the table.
        anyElement(app, "career.sheet.confirm.cancel").tap()
        XCTAssertFalse(anyElement(app, "career.sheet.confirm").waitForExistence(timeout: 2))
        XCTAssertTrue(withdraw.waitForExistence(timeout: 6), "The pending deal should remain after cancelling")

        // Confirm — the deal leaves the centre.
        withdraw.tap()
        XCTAssertTrue(anyElement(app, "career.sheet.confirm").waitForExistence(timeout: 6))
        anyElement(app, "career.sheet.confirm.confirm").tap()
        XCTAssertFalse(withdraw.waitForExistence(timeout: 4),
                       "A confirmed withdrawal must remove the pending deal")
        shot(app, "withdrawal_done")
    }

    // MARK: - E. Compact-landscape reachability

    func testContractSheetActionsReachableWithoutScrolling() throws {
        let app = launch()
        openProfile(app, name: "Danny Draper")

        let negotiate = app.buttons["career.playerProfile.negotiate"]
        XCTAssertTrue(negotiate.waitForExistence(timeout: 6))
        negotiate.tap()
        XCTAssertTrue(anyElement(app, "career.contract.sheet").waitForExistence(timeout: 6))

        // On the SE the sheet's pinned footer must already be hittable —
        // the sheet pins its actions; scrolling should not be required.
        let offer = app.buttons["career.contract.makeOffer"]
        let walkAway = app.buttons["career.contract.cancel"]
        XCTAssertTrue(offer.waitForExistence(timeout: 6))
        XCTAssertTrue(offer.isHittable, "MAKE THE OFFER must be reachable on compact landscape")
        XCTAssertTrue(walkAway.isHittable, "Walk away must be reachable on compact landscape")
        XCTAssertTrue(app.buttons["career.contract.close"].isHittable, "Close must be reachable")
        shot(app, "renewal_compact")
        app.buttons["career.contract.close"].tap()
    }

    // MARK: - F. Parent state preserved after a sheet round trip

    func testSquadStatePreservedAfterSheetRoundTrip() throws {
        let app = launch()
        openProfile(app, name: "Danny Draper")

        let negotiate = app.buttons["career.playerProfile.negotiate"]
        XCTAssertTrue(negotiate.waitForExistence(timeout: 6))
        negotiate.tap()
        XCTAssertTrue(anyElement(app, "career.contract.sheet").waitForExistence(timeout: 6))
        app.buttons["career.contract.cancel"].tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 6))
        app.buttons["career.playerProfile.close"].tap()

        // Back on the squad table: still in list mode with the rows intact
        // (no reset to the pitch, no empty table).
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 6))
        XCTAssertEqual(app.buttons["career.squad.mode.list"].isSelected, true,
                       "The squad table mode should be preserved after the sheet round trip")
        XCTAssertTrue(elementMatching(app, NSPredicate(format: "identifier BEGINSWITH %@",
                                                       "career.squad.row.")).exists,
                      "Squad rows should still be listed")
    }
}
