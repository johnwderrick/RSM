//
//  CareerInboxUITests.swift
//  Retro Season ManagerUITests
//
//  Focused UI coverage for the redesigned Career Inbox, built on the
//  deterministic `UITEST_CAREER_NAVIGATION` fixture:
//
//  A. the summary band's authoritative counts,
//  B. the UNREAD and category filters,
//  C. opening an unread message marks it read and the updated unread
//     count persists after closing the article,
//  D. a long article scrolls to its end in one container,
//  E. close returns to the same filtered list state,
//  F. away-and-back navigation stays stable,
//  G. a held scroll position does not jump back to the top.
//
//  Uses the same existence-wait + plain-tap primitives as
//  CareerNavigationUITests — frame math is unreliable on this
//  landscape-locked app (see that file's notes).
//

import XCTest

final class CareerInboxUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch & capture

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_NAVIGATION"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_inbox_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name,
                                       payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func gotoInbox(_ app: XCUIApplication) -> XCUIElement {
        let tab = app.buttons["career.nav.inbox"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Inbox sidebar item missing")
        tab.tap()
        return tab
    }

    private func inboxVisible(_ app: XCUIApplication, _ timeout: TimeInterval = 8) -> Bool {
        app.descendants(matching: .any)["career.inbox.screen"].waitForExistence(timeout: timeout)
            || app.descendants(matching: .any)["career.inbox.summary"].waitForExistence(timeout: 2)
    }

    /// Launches, waits for the career shell, navigates to the Inbox and
    /// proves it is showing. Every test starts here.
    @discardableResult
    private func launchToInbox() -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].waitForExistence(timeout: 15),
                      "Career home should appear after launch")
        gotoInbox(app)
        XCTAssertTrue(inboxVisible(app), "Inbox destination missing")
        return app
    }

    private func waitFor(_ app: XCUIApplication, _ identifier: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(identifier) missing")
        return element
    }

    /// Inbox rows are Buttons, but querying the whole app for a duplicate
    /// identifier can surface multiple elements (sheet copies etc.), so
    /// every row reference goes through a scoped, first-match lookup.
    private func row(_ app: XCUIApplication, _ slug: String) -> XCUIElement {
        let inButtons = app.buttons["career.inbox.row.\(slug)"].firstMatch
        return inButtons.exists ? inButtons
            : app.descendants(matching: .any)["career.inbox.row.\(slug)"].firstMatch
    }

    /// Reveals a lower row by swiping on the destination's named scroll
    /// container until the row's centre is inside the container's visible
    /// band. `isHittable` alone is trusted here on no account: the dump
    /// evidence shows it can report true while the row's activation point
    /// sits below the viewport (only a sliver visible), producing dead
    /// taps. Frame math within one query pass has proven coherent for
    /// this destination (unlike the sidebar's flapping window space).
    @discardableResult
    private func revealRow(_ app: XCUIApplication, _ slug: String, maxSwipes: Int = 6) -> XCUIElement {
        let element = row(app, slug)
        let scroll = app.scrollViews["career.inbox.scroll"].firstMatch
        guard element.exists, scroll.exists else { return element }
        var swipes = 0
        while swipes < maxSwipes {
            let rowFrame = element.frame
            let visible = scroll.frame
            let centreY = rowFrame.minY + rowFrame.height * 0.5
            let centreInside = centreY <= visible.maxY - 8 && rowFrame.minY >= visible.minY
            if centreInside { break }
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        return element
    }

    // MARK: - A+B. Summary counts, filters, unread marker treatment

    func testInboxSummaryCountsAndFiltersMatchFixture() throws {
        let app = launchToInbox()
        shot(app, "list")

        // Fixture: 7 deterministic messages on top (engine history below),
        // exactly 3 unread, with 2 of them in Board.
        let summary = waitFor(app, "career.inbox.summary")
        XCTAssertTrue(summary.exists)

        let allChip = app.buttons["career.inbox.filter.all"].firstMatch
        XCTAssertTrue(allChip.label.contains("3 unread"), "ALL chip should report 3 unread, got: \(allChip.label)")

        let unreadChip = app.buttons["career.inbox.filter.unread"].firstMatch
        XCTAssertTrue(unreadChip.label.contains("3 unread"), "UNREAD chip should report 3 unread, got: \(unreadChip.label)")

        let boardChip = app.buttons["career.inbox.filter.board"].firstMatch
        XCTAssertTrue(boardChip.label.contains("1 unread"), "Board chip should report 1 unread (the player story; the objectives story is read), got: \(boardChip.label)")

        // Every supported category chip exists and is reachable without
        // scrolling; the category folders derive from InboxFolder.
        for slug in ["results", "transfers", "board", "club", "world"] {
            XCTAssertTrue(app.buttons["career.inbox.filter.\(slug)"].firstMatch.exists,
                          "Category filter \(slug) missing")
        }

        // Row treatment: the unread long article's label carries the
        // Unread marker text; the read routine row does not.
        let unreadRow = row(app, "deterministic-long-article")
        XCTAssertTrue(unreadRow.waitForExistence(timeout: 8))
        XCTAssertTrue(unreadRow.label.hasPrefix("Unread."),
                      "Unread row should announce itself, got: \(unreadRow.label)")
        let readRow = row(app, "transfer-window-opens")
        XCTAssertTrue(readRow.exists)
        XCTAssertFalse(readRow.label.hasPrefix("Unread."),
                       "Read row must not announce itself as unread")

        // UNREAD filter shows exactly the 3 unread fixture items.
        unreadChip.tap()
        XCTAssertTrue(row(app, "deterministic-long-article").waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "title-race-tightening-across-europe").exists)
        XCTAssertTrue(row(app, "star-signs-contract-extension").exists)
        XCTAssertFalse(row(app, "transfer-window-opens").exists,
                       "Read items must not appear under the UNREAD filter")
        shot(app, "filtered_unread")

        // A category filter narrows to its folder only.
        app.buttons["career.inbox.filter.board"].firstMatch.tap()
        XCTAssertTrue(row(app, "star-signs-contract-extension").waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "board-reviews-season-objectives").exists)
        XCTAssertFalse(row(app, "deterministic-long-article").exists,
                       "Info stories must not appear under the Board filter")

        // The Results filter shows its folder's content (the fixture's
        // deterministic result story plus any engine result history —
        // applyResult can emit record news, so emptiness isn't guaranteed).
        app.buttons["career.inbox.filter.results"].firstMatch.tap()
        XCTAssertTrue(row(app, "season-opener-ends-level").waitForExistence(timeout: 5),
                      "Results folder should show the deterministic result story")
        XCTAssertFalse(row(app, "star-signs-contract-extension").exists,
                       "Board stories must not appear under the Results filter")

        // Back to ALL restores the full list.
        app.buttons["career.inbox.filter.all"].firstMatch.tap()
        XCTAssertTrue(row(app, "deterministic-long-article").waitForExistence(timeout: 5))
        app.terminate()
    }

    // MARK: - C+E. Read-state round trip through the article

    func testOpeningUnreadMessageMarksItReadAndPersistsAfterClose() throws {
        let app = launchToInbox()

        // Pre-state: 3 unread (fixture). Engine history adds extra read
        // messages, so only the unread count is deterministic.
        let summary = waitFor(app, "career.inbox.summary")
        XCTAssertTrue(summary.label.contains("3 unread"), "Summary pre-state wrong: \(summary.label)")

        // Open the unread player-context story (it carries the fixture's
        // real squad player, so the article's snapshot card has data). On
        // SE landscape the row can sit below the fold — reveal it, let the
        // scroll settle, then tap (swipe momentum can swallow one tap, so
        // retry once if the sheet didn't come up).
        var rowElement = revealRow(app, "star-signs-contract-extension")
        XCTAssertTrue(rowElement.waitForExistence(timeout: 8))
        rowElement.tap()
        let close = app.descendants(matching: .any)["career.inbox.article.close"].firstMatch
        if !close.waitForExistence(timeout: 3) {
            Thread.sleep(forTimeInterval: 0.8)
            rowElement = revealRow(app, "star-signs-contract-extension")
            rowElement.tap()
        }
        if !close.waitForExistence(timeout: 3) {
            // Diagnostic evidence for the flake investigation.
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/inbox-open-dump.txt"))
            let target = row(app, "star-signs-contract-extension")
            print("INBOXDIAG row exists=\(target.exists) hittable=\((try? target.isHittable) ?? false)")
        }

        // Article: pinned header + close. The player story is
        // newspaper-worthy (Board, notable), so it renders the generated
        // front page — the authoritative article presentation. Its
        // scrolling depth is covered by the plain-layout long-article
        // test; here the pinned close and the read-state round trip
        // are what's under test.
        waitFor(app, "career.inbox.article.close")
        shot(app, "article")

        // Close returns to the list; the message is now read.
        app.descendants(matching: .any)["career.inbox.article.close"].firstMatch.tap()
        XCTAssertTrue(inboxVisible(app), "Closing the article should return to the Inbox")

        // The row's treatment flips: no more Unread announcement.
        let reopenedRow = row(app, "star-signs-contract-extension")
        XCTAssertTrue(reopenedRow.waitForExistence(timeout: 8))
        if reopenedRow.label.hasPrefix("Unread.") {
            // Wait out the state propagation, then re-query.
            Thread.sleep(forTimeInterval: 1.0)
        }
        let refreshed = row(app, "star-signs-contract-extension")
        XCTAssertFalse(refreshed.exists && refreshed.label.hasPrefix("Unread."),
                       "Opening a message must mark it read through markNewsRead")

        // The summary's unread count decremented and persists after
        // closing the article (read state lives in the store, not the row).
        let summaryAfter = app.descendants(matching: .any)["career.inbox.summary"].firstMatch
        XCTAssertTrue(summaryAfter.waitForExistence(timeout: 5))
        XCTAssertTrue(summaryAfter.label.contains("2 unread"),
                      "Unread count should drop 3→2 after reading one message, got: \(summaryAfter.label)")

        // Away and back: the read state survives navigation.
        app.buttons["career.nav.home"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].waitForExistence(timeout: 8))
        gotoInbox(app)
        XCTAssertTrue(inboxVisible(app))
        let summaryBack = app.descendants(matching: .any)["career.inbox.summary"].firstMatch
        XCTAssertTrue(summaryBack.waitForExistence(timeout: 8))
        XCTAssertTrue(summaryBack.label.contains("2 unread"),
                      "Read state must survive away-and-back navigation")
        shot(app, "list_after_read")
        app.terminate()
    }

    // MARK: - D. Long article scrolling

    func testLongArticleScrollsToEndInSingleContainer() throws {
        let app = launchToInbox()

        let article = row(app, "deterministic-long-article")
        XCTAssertTrue(article.waitForExistence(timeout: 8), "Deterministic long article missing")
        article.tap()

        let end = app.descendants(matching: .any)["career.inbox.article.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 6), "Article should open")
        // The fixture's article is deliberately long; swipe until the end
        // marker is hittable (each drag advances the single container).
        var swipes = 0
        while !end.isHittable && swipes < 12 {
            app.swipeUp(velocity: .fast)
            swipes += 1
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(end.isHittable, "Long article's lower content should be reachable in one scroll container")
        shot(app, "article_end")

        // Close from depth; the list returns.
        waitFor(app, "career.inbox.article.close").tap()
        XCTAssertTrue(inboxVisible(app), "Close should return to the Inbox list")
        app.terminate()
    }

    // MARK: - F+G. Away-and-back stability + no jump-to-top while held

    func testInboxScrollPositionHoldsAndSurvivesAwayAndBack() throws {
        let app = launchToInbox()

        // Scroll to the very bottom of the list (the end anchor proves
        // depth) using the scroll container's own frame math — the same
        // virtual-frame-safe check revealRow uses.
        let end = app.descendants(matching: .any)["career.inbox.list.end"].firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 6), "List end anchor missing")
        let scroll = app.scrollViews["career.inbox.scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 4), "Inbox scroll container missing")
        func endVisible() -> Bool {
            let ef = end.frame
            let sf = scroll.frame
            let centreY = ef.minY + ef.height * 0.5
            return centreY <= sf.maxY - 8 && ef.minY >= sf.minY
        }
        var swipes = 0
        while !endVisible() && swipes < 10 {
            scroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        XCTAssertTrue(endVisible(), "Lower inbox content should be reachable")

        // Hold the position; ordinary view updates must not reset the
        // scroll to the top.
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertTrue(endVisible(), "Held scroll position must not jump back to the top")

        // Away and back: Inbox remains usable.
        app.buttons["career.nav.home"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].waitForExistence(timeout: 8))
        gotoInbox(app)
        XCTAssertTrue(inboxVisible(app))
        waitFor(app, "career.inbox.summary")
        // The list is functional after the round trip.
        XCTAssertTrue(row(app, "deterministic-long-article").waitForExistence(timeout: 8),
                      "Inbox list should render after away-and-back")
        shot(app, "away_and_back")
        app.terminate()
    }

    // MARK: - Empty state content (UNREAD after reading everything)

    func testUnreadFilterShowsEmptyStateWhenCaughtUp() throws {
        let app = launchToInbox()

        // Mark everything read through the real store mechanism.
        let markAll = app.buttons["career.inbox.markall"].firstMatch
        if markAll.waitForExistence(timeout: 4) {
            markAll.tap()
        } else {
            XCTFail("MARK ALL READ control missing")
        }

        app.buttons["career.inbox.filter.unread"].firstMatch.tap()
        let empty = app.descendants(matching: .any)["career.inbox.empty"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "Caught-up UNREAD filter should show its empty state")
        XCTAssertTrue(empty.label.contains("caught up"), "Empty state should explain the caught-up situation, got: \(empty.label)")
        shot(app, "unread_empty")
        app.terminate()
    }
}
