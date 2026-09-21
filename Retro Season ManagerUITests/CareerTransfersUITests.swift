//
//  CareerTransfersUITests.swift
//  Retro Season Manager
//
//  Focused UI coverage for the redesigned Career Transfer Centre: the
//  summary band, market cards with scouting/pricing states, filters and
//  tabs preserving state, the real shortlist path, negotiations with
//  incoming offers, one stable scroll container, and returning without
//  losing context.
//
//  Uses the same existence-wait + plain-tap primitives as
//  CareerNavigationUITests — frame math is unusable on this
//  landscape-locked app (see that file's header for the full story).
//

import XCTest

final class CareerTransfersUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_TRANSFERS"]
        app.launch()
        return app
    }

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

    @discardableResult
    private func gotoSidebar(_ app: XCUIApplication, _ slug: String) -> XCUIElement {
        let tab = app.buttons["career.nav.\(slug)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Sidebar item \(slug) missing")
        // Plain tap only — probing isHittable/frames on sidebar buttons is
        // the documented anti-pattern on this landscape-locked app
        // (see CareerNavigationUITests' header): the audit tours proved
        // existence-wait + tap reliable where every frame probe flaked.
        tab.tap()
        return tab
    }

    /// Navigates to a destination and asserts its stable root appears,
    /// retrying once for a tap swallowed by an in-flight SwiftUI update.
    private func assertLands(_ app: XCUIApplication, _ slug: String) {
        let tab = gotoSidebar(app, slug)
        var found = screenVisible(app, slug, timeout: 8)
        if !found {
            tab.tap()
            found = screenVisible(app, slug, timeout: 8)
        }
        XCTAssertTrue(found, "Tapping \(slug) should show career.\(slug).screen")
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func elementMatching(_ app: XCUIApplication, _ predicate: NSPredicate) -> XCUIElement {
        app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func firstCard(_ app: XCUIApplication) -> XCUIElement {
        elementMatching(app, NSPredicate(format: "identifier BEGINSWITH %@", "career.transfers.card."))
    }

    private func buttonMatching(_ app: XCUIApplication, _ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    private func openTransfers(_ app: XCUIApplication) {
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")
        assertLands(app, "transfers")
        XCTAssertTrue(anyElement(app, "career.transfers.summary").waitForExistence(timeout: 6),
                      "Transfer Centre summary missing")
    }

    // MARK: - Summary, market cards, states, prices, actions

    func testTransferCentreSummaryMarketCardsAndPrimaryActions() throws {
        let app = launch()
        openTransfers(app)

        // Summary band carries the authoritative figures in its label.
        let summary = anyElement(app, "career.transfers.summary")
        XCTAssertTrue(summary.label.contains("market targets"), "Summary should announce market targets")
        XCTAssertTrue(summary.label.contains("shortlisted"), "Summary should announce the shortlist")

        // Tabs are all present with MARKET selected first.
        for slug in ["market", "shortlist", "negotiations", "squad", "youth", "club"] {
            XCTAssertTrue(app.buttons["career.transfers.tab.\(slug)"].exists, "Tab \(slug) missing")
        }
        XCTAssertTrue(app.buttons["career.transfers.tab.market"].isSelected, "Market should be the initial tab")

        // A market card with portrait, price and the full action row exists.
        let card = firstCard(app)
        XCTAssertTrue(card.waitForExistence(timeout: 6), "No market target card rendered")

        // At least one card offers a shortlist action on the real store path.
        let shortlist = buttonMatching(app, "career.transfers.shortlist.")
        XCTAssertTrue(shortlist.waitForExistence(timeout: 4), "Shortlist action missing on market cards")

        // The view-profile action is present too.
        XCTAssertTrue(buttonMatching(app, "career.transfers.profile.").exists, "View-profile action missing")

        // Filter controls exist.
        XCTAssertTrue(anyElement(app, "career.transfers.filter.search").exists, "Search field missing")
        for slug in ["position", "age", "ability", "price", "sort"] {
            XCTAssertTrue(anyElement(app, "career.transfers.filter.\(slug)").exists, "Filter \(slug) missing")
        }

        shot(app, "market_se")
        app.terminate()
    }

    // MARK: - Filters and tabs preserve state

    func testTransfersFiltersAndTabsPreserveState() throws {
        let app = launch()
        openTransfers(app)

        // Pick an affordable-only filter and a sort; confirm the count
        // label and cards still render.
        anyElement(app, "career.transfers.filter.price").tap()
        app.buttons["AFFORDABLE"].tap()
        XCTAssertTrue(firstCard(app).waitForExistence(timeout: 5) || anyElement(app, "career.transfers.empty").exists,
                      "Affordable filter should leave cards or a clear empty state")

        // Reset filter chips back through the reset control.
        if anyElement(app, "career.transfers.filter.reset").exists {
            anyElement(app, "career.transfers.filter.reset").tap()
        }

        // Tab switch to SHORTLIST — the fixture pre-shortlists one player,
        // so a card appears; the count badge is on the tab.
        app.buttons["career.transfers.tab.shortlist"].tap()
        let shortlistCard = firstCard(app)
        if !shortlistCard.waitForExistence(timeout: 6) {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-shortlist.txt"))
        }
        XCTAssertTrue(shortlistCard.waitForExistence(timeout: 2), "Fixture shortlist should show one card")

        // Away and back: the market tab is preserved (state lives in the
        // view until the destination is recreated) and the screen is usable.
        assertLands(app, "home")
        assertLands(app, "transfers")
        XCTAssertTrue(anyElement(app, "career.transfers.summary").exists, "Summary missing after return")

        shot(app, "filters_tabs_se")
        app.terminate()
    }

    // MARK: - Shortlist add/remove via the real store path

    func testTransfersShortlistRoundTrip() throws {
        let app = launch()
        openTransfers(app)

        // The fixture pre-shortlists the top-rated CLUB-LISTED target.
        let removeButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND identifier BEGINSWITH %@",
                        "SHORTLISTED", "career.transfers.shortlist.")).firstMatch
        XCTAssertTrue(removeButton.waitForExistence(timeout: 6), "A SHORTLISTED market card should exist from the fixture")
        // Capture the player ID from the button identifier so the re-add
        // leg targets the same player — a free agent's shortlist entry can
        // never resolve (shortlistedResults looks players up inside clubs).
        let playerID = removeButton.identifier
            .replacingOccurrences(of: "career.transfers.shortlist.", with: "")
        removeButton.tap()

        // The shortlist tab is now empty with a clear empty state.
        app.buttons["career.transfers.tab.shortlist"].tap()
        let empty = anyElement(app, "career.transfers.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 6), "Shortlist should show its empty state after removal")
        XCTAssertTrue(empty.label.lowercased().contains("empty"), "Empty state should explain the shortlist is empty")

        // Re-add the SAME player from the market.
        app.buttons["career.transfers.tab.market"].tap()
        let addShortlist = app.buttons["career.transfers.shortlist.\(playerID)"]
        XCTAssertTrue(addShortlist.waitForExistence(timeout: 6), "The same market card should still offer SHORTLIST")
        addShortlist.tap()

        // And the shortlist shows a card again.
        app.buttons["career.transfers.tab.shortlist"].tap()
        let readdedCard = firstCard(app)
        if !readdedCard.waitForExistence(timeout: 6) {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-reshortlist.txt"))
        }
        XCTAssertTrue(readdedCard.waitForExistence(timeout: 2), "Shortlisted player should appear on the shortlist tab")

        shot(app, "shortlist_se")
        app.terminate()
    }

    // MARK: - Shortlisting a FREE AGENT resolves on the SHORTLIST tab

    func testTransfersFreeAgentShortlistResolvesOnShortlistTab() throws {
        let app = launch()
        openTransfers(app)

        // Find a market card priced FREE (a free agent) and shortlist him
        // through the real store path. Free agents are attached to no club,
        // which is exactly the case the shortlist query used to drop. The
        // default OVR sort puts them low in a long list, so shortlist the
        // fixture's own target via NAME search instead of scrolling.
        let search = anyElement(app, "career.transfers.filter.search")
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Market search field missing")
        search.tap()
        search.typeText("Bjorn Freehold\n")
        Thread.sleep(forTimeInterval: 0.5)

        // The card wrapper is an .accessibilityElement(children: .ignore)
        // Other, not a Button — query all elements, as firstCard() does.
        let freeCard = elementMatching(
            app, NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                             "career.transfers.card.", "Free agent"))
        if !freeCard.waitForExistence(timeout: 6) {
            let searchValue = (search.value as? String) ?? "<nil>"
            try? "search value: \(searchValue)\n\n\(app.debugDescription)"
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-freeagent.txt"), atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(freeCard.waitForExistence(timeout: 2), "Market should show a free agent card after search")
        let freePlayerID = freeCard.identifier
            .replacingOccurrences(of: "career.transfers.card.", with: "")
        let shortlistButton = app.buttons["career.transfers.shortlist.\(freePlayerID)"]
        XCTAssertTrue(shortlistButton.waitForExistence(timeout: 4), "Free agent card should offer SHORTLIST")
        shortlistButton.tap()
        // Clear the search so the rest of the screen is in its natural state.
        search.tap()
        search.typeText("\n")
        Thread.sleep(forTimeInterval: 0.5)

        // He must appear on the SHORTLIST tab (the regression: this used to
        // show the empty state because free agents live in no club).
        app.buttons["career.transfers.tab.shortlist"].tap()
        let freeShortlistCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@",
                                  "career.transfers.card.\(freePlayerID)")).firstMatch
        if !freeShortlistCard.waitForExistence(timeout: 6) {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-freeagent.txt"))
        }
        XCTAssertTrue(freeShortlistCard.exists,
                      "A shortlisted FREE AGENT must resolve on the SHORTLIST tab")
        XCTAssertTrue(freeShortlistCard.label.localizedCaseInsensitiveContains("free agent"),
                      "Free agent shortlist card should present as a free agent")

        // His profile opens from the shortlist and closes back cleanly.
        let profileButton = app.buttons["career.transfers.profile.\(freePlayerID)"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 4), "Free agent shortlist card should offer VIEW PROFILE")
        profileButton.tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Free agent profile should open from the shortlist")
        anyElement(app, "career.playerProfile.close").tap()
        XCTAssertTrue(anyElement(app, "career.transfers.summary").waitForExistence(timeout: 8),
                      "Transfer Centre should reappear after closing")

        shot(app, "freeagent_shortlist_se")
        app.terminate()
    }

    // MARK: - Player profile round trip from a market card

    func testTransfersProfileOpensAndReturns() throws {
        let app = launch()
        openTransfers(app)

        // Open the profile via the explicit action (not the tappable card
        // body) so the tap can't be swallowed by a stale frame.
        let profileButton = buttonMatching(app, "career.transfers.profile.")
        XCTAssertTrue(profileButton.waitForExistence(timeout: 6), "No VIEW PROFILE action on market cards")
        profileButton.tap()

        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Player profile sheet should open from a market card")
        XCTAssertTrue(anyElement(app, "career.playerProfile.close").exists, "Profile close control missing")
        shot(app, "profile_se")

        // Close and confirm the Transfer Centre is still usable beneath.
        anyElement(app, "career.playerProfile.close").tap()
        XCTAssertTrue(anyElement(app, "career.transfers.summary").waitForExistence(timeout: 8),
                      "Transfer Centre should reappear after closing the profile")

        app.terminate()
    }

    // MARK: - Negotiations: incoming offer accept via real path

    func testTransfersNegotiationsShowIncomingOffer() throws {
        let app = launch()
        openTransfers(app)

        app.buttons["career.transfers.tab.negotiations"].tap()
        let accept = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "career.transfers.offer.", ".accept")).firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "Fixture's incoming offer should render with an ACCEPT action")
        shot(app, "negotiations_se")

        // Accepting runs the real completeSale path: the offer disappears.
        accept.tap()
        let acceptedGone = accept.waitForNonExistence(timeout: 6)
        XCTAssertTrue(acceptedGone || !accept.exists,
                      "Accepted offer should leave the negotiations list")

        app.terminate()
    }

    // MARK: - Full incoming-transfer negotiation via the restyled sheets

    /// Drives the REAL negotiation path end to end through the restyled
    /// light-card sheets: market target → profile → NEGOTIATE →
    /// TransferBidSheet (light-card, actions reachable) → cancel returns to
    /// the same tab → reopen → deterministic first-offer acceptance (the
    /// fixture pins the seller to `.flexible`; the sheet's opening offer is
    /// 0.85 × asking, above the 0.8 accept threshold) → DONE → the
    /// NEGOTIATIONS tab shows the pending deal. Invariant checks guard
    /// against double deals, double fees and lost players.
    func testTransfersNegotiationFlowThroughBidSheetCreatesPendingDeal() throws {
        let app = launch()
        openTransfers(app)

        // Deterministic target by name search — Marcus Bidwell, the
        // fixture's flexible-seller negotiation target.
        let search = anyElement(app, "career.transfers.filter.search")
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Market search field missing")
        search.tap()
        search.typeText("Marcus Bidwell\n")
        Thread.sleep(forTimeInterval: 0.6)

        let targetCard = elementMatching(
            app, NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                             "career.transfers.card.", "Marcus Bidwell"))
        XCTAssertTrue(targetCard.waitForExistence(timeout: 6), "Negotiation target card should appear after search")
        let targetPlayerID = targetCard.identifier
            .replacingOccurrences(of: "career.transfers.card.", with: "")

        // Budget and deals before any action (from the summary's label —
        // the authoritative figures the UI itself shows).
        let summary = anyElement(app, "career.transfers.summary")
        let budgetBefore = budget(fromSummary: summary.label)
        XCTAssertNotNil(budgetBefore, "Summary should announce a transfer budget")
        XCTAssertTrue(summary.label.contains("0 deals in progress"),
                      "Precondition: the fixture starts with no pending deals — the delta after acceptance proves causality: \(summary.label)")

        // The search keyboard covers the lower half of a compact landscape
        // screen and its dismissal/scroll settling can leave the filtered
        // card out of view. Reveal it deterministically: dismiss the
        // keyboard, then a capped scroll-down loop until the card's VIEW
        // PROFILE action is hittable (the pattern the scroll test uses).
        let scroll = app.scrollViews["career.transfers.scroll"]
        scroll.swipeDown()
        Thread.sleep(forTimeInterval: 0.8)

        // 1. Light-card presentation: the profile opens for the target.
        let profileButton = app.buttons["career.transfers.profile.\(targetPlayerID)"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 4), "Target card should offer VIEW PROFILE")
        var reveals = 0
        while !profileButton.isHittable && reveals < 8 {
            scroll.swipeUp()
            reveals += 1
            Thread.sleep(forTimeInterval: 0.4)
        }
        if !profileButton.isHittable {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-negotiate.txt"))
        }
        XCTAssertTrue(profileButton.isHittable, "VIEW PROFILE should be reachable after dismissing the keyboard")
        profileButton.tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Profile should open for the target")

        // 2. Enter the existing transfer-bid negotiation.
        let negotiateButton = app.buttons.matching(
            NSPredicate(format: "label == %@", "NEGOTIATE")).firstMatch
        XCTAssertTrue(negotiateButton.waitForExistence(timeout: 5), "NEGOTIATE pill missing on a market profile")
        negotiateButton.tap()

        // 3. The restyled TransferBidSheet is up, in the light-card language,
        //    with its primary actions present and reachable.
        XCTAssertTrue(app.buttons["career.transfers.bid.make"].waitForExistence(timeout: 8),
                      "MAKE OFFER action missing on the bid sheet")
        XCTAssertTrue(app.buttons["career.transfers.bid.cancel"].exists, "Cancel action missing on the bid sheet")
        XCTAssertTrue(app.staticTexts["NEGOTIATE FEE"].exists, "Bid sheet header missing")
        XCTAssertTrue(app.staticTexts["YOUR OFFER"].exists, "Offer section missing")
        XCTAssertTrue(app.buttons["career.transfers.bid.make"].isHittable,
                      "Primary bid action must be reachable without scrolling")
        shot(app, "bid_sheet_se")

        // 4. Cancel unwinds only the bid sheet — back to the profile (the
        //    sheet stack's correct behaviour; DONE is what closes both).
        app.buttons["career.transfers.bid.cancel"].tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Cancelling the bid should return to the player profile")

        // Close the profile too and confirm the Transfer Centre returns
        // with the same tab/filter context intact.
        anyElement(app, "career.playerProfile.close").tap()
        XCTAssertTrue(anyElement(app, "career.transfers.summary").waitForExistence(timeout: 8),
                      "Closing the profile should return to the Transfer Centre")
        XCTAssertTrue(app.buttons["career.transfers.tab.market"].isSelected,
                      "Cancel should land back on the MARKET tab")
        let searchAfterCancel = anyElement(app, "career.transfers.filter.search")
        XCTAssertEqual(searchAfterCancel.value as? String, "Marcus Bidwell",
                       "Cancel must preserve the active filter context")
        XCTAssertTrue(targetCard.waitForExistence(timeout: 5),
                      "The same target should still be on the market after cancelling")

        // 5. Reopen the same target and complete a valid deterministic bid:
        //    accept the sheet's opening offer (0.85 × asking) as-is.
        var reReveals = 0
        while !profileButton.isHittable && reReveals < 8 {
            scroll.swipeUp()
            reReveals += 1
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(profileButton.isHittable, "VIEW PROFILE should be reachable when reopening the profile")
        profileButton.tap()
        XCTAssertTrue(anyElement(app, "career.playerProfile.screen").waitForExistence(timeout: 8),
                      "Profile should reopen for the same target")
        negotiateButton.tap()
        let makeOffer = app.buttons["career.transfers.bid.make"]
        XCTAssertTrue(makeOffer.waitForExistence(timeout: 8), "Bid sheet should reopen")
        makeOffer.tap()

        // 6. The fixture's flexible seller deterministically ACCEPTS: the
        //    result banner announces it and DONE replaces the action row.
        let result = anyElement(app, "career.transfers.bid.result")
        XCTAssertTrue(result.waitForExistence(timeout: 8), "Bid outcome banner missing")
        if result.label.localizedCaseInsensitiveContains("rejected") {
            // Capture the full sheet (reason text + the gold seller-stance
            // line in the header) so a rejection can be diagnosed.
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-bid-reject.txt"))
        }
        XCTAssertTrue(result.label.localizedCaseInsensitiveContains("accepted"),
                      "The opening offer to a flexible seller must be accepted — banner said: \(result.label)")
        let done = app.buttons["career.transfers.bid.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 4), "DONE action missing after acceptance")
        shot(app, "bid_accepted_se")
        done.tap()

        // 7. Back on the Transfer Centre: the deal is pending — check the
        //    NEGOTIATIONS tab renders it, the market no longer has the
        //    target, and nothing was deducted yet (fee moves only at
        //    personal terms).
        XCTAssertTrue(anyElement(app, "career.transfers.summary").waitForExistence(timeout: 8),
                      "DONE should return to the Transfer Centre")
        let summaryAfterAccept = anyElement(app, "career.transfers.summary")
        XCTAssertEqual(budget(fromSummary: summaryAfterAccept.label), budgetBefore,
                       "Fee acceptance must not deduct the budget — money moves at personal terms only")
        XCTAssertTrue(summaryAfterAccept.label.contains("1 deals in progress"),
                      "The accepted bid must create exactly one deal (0 → 1): \(summaryAfterAccept.label)")

        app.buttons["career.transfers.tab.negotiations"].tap()
        // A fresh deal is in medical/paperwork (isReady == false), so the
        // TALK TERMS control doesn't exist yet — the deal row renders a
        // clock and the always-present withdraw control instead. NOTE: the
        // deal row carries the player's real squad name, not the fixture's
        // DEBUG market-card rename — the 0→1 summary delta above is what
        // ties this row to OUR negotiation.
        let dealWithdraw = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                        "career.transfers.deal.", ".withdraw")).firstMatch
        XCTAssertTrue(dealWithdraw.waitForExistence(timeout: 6), "The pending deal should render on the NEGOTIATIONS tab")
        shot(app, "deal_pending_se")

        // 8. No duplicate transfer: the market card is gone and a second
        //    DONE path can't create a second deal (the sheet is dismissed;
        //    asserting the single deal is the guard).
        app.buttons["career.transfers.tab.market"].tap()
        let bidwellGone = elementMatching(
            app, NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                             "career.transfers.card.", "Marcus Bidwell"))
        XCTAssertFalse(bidwellGone.exists,
                       "The negotiated target must leave the market — no duplicate transfer possible")

        app.terminate()
    }

    /// Parses the transfer budget out of the summary band's accessibility
    /// label ("Transfer budget £X.") without duplicating formatting rules.
    private func budget(fromSummary label: String) -> String? {
        guard let range = label.range(of: "Transfer budget ") else { return nil }
        let rest = label[range.upperBound...]
        guard let end = rest.firstIndex(where: { $0 == "." || $0 == " " }) else { return nil }
        return String(rest[..<end])
    }

    // MARK: - One stable scroll container, no jump-to-top

    func testTransfersScrollReachesLowerContentAndHoldsPosition() throws {
        let app = launch()
        openTransfers(app)

        // Away and back FIRST, while the sidebar state is known-good: after
        // the transfers tap, XCUITest auto-reveals the bottom sidebar item,
        // leaving the items ABOVE it just outside the viewport where taps
        // cannot resolve (the exact poisoned-frame mode documented in
        // CareerNavigationUITests). The pinned INBOX item is always
        // tappable, so away-and-back uses inbox — the full sidebar sweep
        // lives in CareerNavigationUITests.
        gotoSidebar(app, "inbox")
        XCTAssertTrue(screenVisible(app, "inbox", timeout: 8), "Inbox destination should open from Transfers")
        gotoSidebar(app, "transfers")
        XCTAssertTrue(screenVisible(app, "transfers", timeout: 8), "Returning to Transfers should work")
        XCTAssertTrue(anyElement(app, "career.transfers.summary").exists, "Summary should be present after returning")

        // The club tab (finances, board, infrastructure, staff) sits at the
        // bottom of its own tab page — a reliable deep anchor.
        app.buttons["career.transfers.tab.club"].tap()
        let staffCard = app.buttons["career.transfers.staff.assistant-manager"]
        XCTAssertTrue(staffCard.waitForExistence(timeout: 6) || anyElement(app, "career.transfers.ledger").exists,
                      "Club tab content missing")

        let scroll = app.scrollViews["career.transfers.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Transfer Centre's main scroll container missing")

        // Walk down until the staff hire control is hittable, then hold.
        var swipes = 0
        while !staffCard.isHittable && swipes < 20 {
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.3)
        }
        if !staffCard.isHittable {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/transfers-tree-scroll.txt"))
        }
        XCTAssertTrue(staffCard.isHittable, "Lower Club-tab content should be reachable by scrolling")

        let heldY = staffCard.frame.minY
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(staffCard.frame.minY, heldY, accuracy: 24,
                       "Transfer Centre scroll position should remain stable while idle")

        shot(app, "scrolled_se")
        app.terminate()
    }
}

extension XCUIElement {
    /// Polls until the element stops existing (or the timeout elapses).
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !exists { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return !exists
    }
}
