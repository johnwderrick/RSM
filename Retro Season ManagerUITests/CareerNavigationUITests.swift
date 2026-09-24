//
//  CareerNavigationUITests.swift
//  Retro Season ManagerUITests
//
//  Foundation coverage for Career Mode navigation, built on the
//  deterministic `UITEST_CAREER_NAVIGATION` fixture:
//
//  A. every sidebar destination lands on its stable `career.<x>.screen`
//     root, with the matching sidebar item carrying the selected trait,
//  B. rapid destination switching settles cleanly and returning Home is
//     immediate and stable (navigation-flash regression guard),
//  C. the Home dashboard scrolls to lower content (Medical Centre sheet)
//     and the position holds — no jump back to the top,
//  D. the Inbox opens a long deterministic article and its lower content
//     is reachable in the detail sheet's single scroll container,
//  E. the full pre-match → live → SKIP → post-match CONTINUE route still
//     works after the navigation changes (match-flow preservation).
//
//  XCUITest notes baked into the helpers below:
//  - Querying `isHittable` on a sidebar button that is scrolled outside
//    the sidebar's viewport *throws* ("Activation point invalid"), so all
//    reveal decisions use the element's `frame` against the window frame.
//  - Plain `tap()` on the custom sidebar buttons intermittently resolves
//    a stale icon-sized accessibility frame; a coordinate tap on the
//    validated frame is used instead.
//

import XCTest

final class CareerNavigationUITests: XCTestCase {

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

    /// FRAME COORDINATES ARE UNUSABLE ON THIS APP.
    ///
    /// The app is landscape-locked (Info.plist + AppDelegate mask) but
    /// XCUITest's window/element frames for it intermittently read as a
    /// half-scale, portrait-oriented space (e.g. a 187.5x333.5 window on
    /// an 667x375 device) while the app itself is verifiably rendering
    /// and responding in landscape. Every frame gate, window-band drag
    /// and coordinate tap built on that data failed nondeterministically
    /// — including taps that landed "outside the window". The audit
    /// tours passed on all three devices using only existence waits and
    /// plain taps, so this file uses exactly those primitives:
    ///
    /// - readiness:  waitForExistence on freshly-queried elements
    /// - reveal:     element swipes on the sidebar's own ScrollView
    /// - tapping:    plain element tap (XCUITest resolves the hit point)
    ///
    /// XCUIDevice.orientation is never written: with the app's own lock
    /// active, orientation writes cause endless rotation churn.

    /// Append-only evidence log (existence-based, no frames).
    private func trace(_ app: XCUIApplication, _ slug: String, _ note: String) {
        let line = "\(Int(Date().timeIntervalSince1970)) hop=\(slug) root=\(screenVisible(app, slug, timeout: 0.2)) \(note)\n"
        if let data = line.data(using: .utf8) {
            if !FileManager.default.fileExists(atPath: "/tmp/navf-trace.log") {
                FileManager.default.createFile(atPath: "/tmp/navf-trace.log", contents: nil)
            }
            if let handle = FileHandle(forWritingAtPath: "/tmp/navf-trace.log") {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_nav_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name,
                                       payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Sidebar helpers

    @discardableResult
    private func gotoSidebar(_ app: XCUIApplication, _ slug: String) -> XCUIElement {
        let tab = app.buttons["career.nav.\(slug)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Sidebar item \(slug) missing")

        // On SE landscape the six scrolling items overflow the sidebar's
        // viewport. The ONLY sidebar gesture that has proven safe under
        // XCUITest here is an upward swipe for the lower items (club,
        // manager, scout and transfers) — a downward swipe delivered through the corrupted
        // coordinate space lands destructively (observed: swallowed the
        // next tap entirely). Non-scrolled hops therefore never swipe;
        // callers that need the top region again simply relaunch the app
        // (fresh sidebar scroll state) instead of swiping back up.
        let scroll = app.scrollViews["career.nav.sidebarScroll"]
        if scroll.exists && (slug == "club" || slug == "manager" || slug == "scout" || slug == "transfers") {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        tab.tap()
        return tab
    }

    /// Navigates to a destination and asserts its stable screen root
    /// appears and the sidebar item carries the selected trait. A tap
    /// swallowed by an in-flight SwiftUI update is retried once.
    private func assertLands(_ app: XCUIApplication, _ slug: String) {
        var tab = gotoSidebar(app, slug)
        trace(app, slug, "after-tap-1")
        var found = screenVisible(app, slug, timeout: 8)
        if !found {
            trace(app, slug, "retry")
            tab = gotoSidebar(app, slug)
            trace(app, slug, "after-tap-2")
            found = screenVisible(app, slug, timeout: 8)
        }
        if !found {
            let stamp = Int(Date().timeIntervalSince1970)
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/navf-tree-\(slug)-\(stamp).txt"))
            XCTFail("Tapping \(slug) should show career.\(slug).screen")
        }
        XCTAssertTrue(tab.isSelected, "\(slug) should carry the selected trait")
    }

    private func screenVisible(_ app: XCUIApplication, _ slug: String, timeout: TimeInterval = 8) -> Bool {
        app.otherElements["career.\(slug).screen"].waitForExistence(timeout: timeout)
            || app.descendants(matching: .any)["career.\(slug).screen"].waitForExistence(timeout: 2)
    }

    // MARK: - A. Destination navigation + rapid switching

    func testCareerDestinationsReachableSelectedAndRapidSwitchingSettles() throws {
        // Never write XCUIDevice.orientation here: the app is landscape-
        // locked and an explicit orientation write while the lock settles
        // causes endless rotation churn. gotoSidebar waits on existence.
        let app = launch()

        // Top-region hops first (no swipes), then the swiped lower hops,
        // then the pinned items — the only safe ordering given that a
        // swipe can corrupt subsequent taps (see gotoSidebar notes).
        for slug in ["home", "squad", "table", "calendar", "club", "manager", "scout", "transfers", "inbox", "settings"] {
            assertLands(app, slug)
        }

        // Settings drill-downs keep their own stable selectors. The
        // redesigned menu opens with the summary/save/preference/records
        // cards, so the MANAGER group's first row sits below the fold and
        // needs one reveal swipe on the destination's scroll container.
        gotoSidebar(app, "settings")
        let profileRow = app.descendants(matching: .any)["career.settings.row.manager-profile"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 6), "Settings rows missing")
        let settingsScroll = app.scrollViews["career.settings.scroll"].firstMatch
        if settingsScroll.exists {
            settingsScroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        profileRow.tap()
        let back = app.descendants(matching: .any)["career.settings.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 6), "Settings back control missing")
        back.tap()
        // The back control is a custom button; give the drill-down time to
        // unwind, then verify Settings' root is showing again before any
        // sidebar tap (a swallowed tap here strands the test mid-drill-down).
        if !screenVisible(app, "settings", timeout: 4) { back.tap(); _ = screenVisible(app, "settings", timeout: 4) }
        if !screenVisible(app, "settings", timeout: 2) {
            try? app.debugDescription.data(using: .utf8)!
                .write(to: URL(fileURLWithPath: "/tmp/navf-tree-back.txt"))
            XCTFail("Settings drill-down did not unwind after Back")
        }

        // Rapid switching must settle immediately on the requested
        // destination — the removed crossfade used to flash stale frames.
        // Run on a fresh launch so the sidebar's scroll state is at the
        // top again (reaching squad after the transfers swipe would
        // otherwise need the unsafe downward swipe).
        app.terminate()
        let relaunched = launch()
        for slug in ["squad", "inbox", "table", "home"] {
            gotoSidebar(relaunched, slug)
            if !screenVisible(relaunched, slug, timeout: 6) {
                try? relaunched.debugDescription.data(using: .utf8)!
                    .write(to: URL(fileURLWithPath: "/tmp/navf-tree-rapid-\(slug).txt"))
            }
            XCTAssertTrue(screenVisible(relaunched, slug, timeout: 2),
                          "Rapid switch to \(slug) should land on its screen")
        }
        XCTAssertTrue(screenVisible(relaunched, "home"), "Rapid switching should settle on Home")
        XCTAssertTrue(relaunched.buttons["career.nav.home"].isSelected,
                      "Home should stay highlighted after rapid switching")

        shot(relaunched, "settled_home")
        relaunched.terminate()
    }

    // MARK: - Squad pitch + player profile

    func testCareerSquadPitchOpensPremiumPlayerProfileAndReturnsIntact() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")

        gotoSidebar(app, "squad")
        XCTAssertTrue(screenVisible(app, "squad", timeout: 8), "Squad destination missing")

        let tactics = app.buttons["career.squad.mode.tactics"]
        XCTAssertTrue(tactics.waitForExistence(timeout: 6) && tactics.isSelected,
                      "Squad should open on the tactics board")

        let player = app.buttons.matching(identifier: "career.squad.pitch.player").firstMatch
        XCTAssertTrue(player.waitForExistence(timeout: 8), "A starting-XI player should be tappable on the pitch")
        player.tap()

        let profile = app.descendants(matching: .any)["career.playerProfile.screen"]
        XCTAssertTrue(profile.waitForExistence(timeout: 8), "Pitch player should open the redesigned profile")
        XCTAssertTrue(app.descendants(matching: .any)["career.playerProfile.nationality"].waitForExistence(timeout: 5),
                      "Player biography should expose nationality beside its flag")

        shot(app, "squad_player_profile")

        let close = app.buttons["career.playerProfile.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Pinned profile close action missing")
        close.tap()
        XCTAssertTrue(screenVisible(app, "squad", timeout: 8), "Closing profile should return to Squad")
        XCTAssertTrue(tactics.exists && tactics.isSelected,
                      "Closing a player profile should preserve the tactics board")

        // The small role control remains a separate path for changing the
        // player, preventing the profile tap from altering the team sheet.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                       "career.squad.pitch.slot.")).firstMatch.waitForExistence(timeout: 5),
                      "Pitch roles should retain their change-player controls")
        shot(app, "squad_return")
        app.terminate()
    }

    // MARK: - Table and fixture centre

    func testCareerTableShowsSeasonContextCompetitionsAndStableScrolling() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Career fixture should reach Home")

        gotoSidebar(app, "table")
        XCTAssertTrue(screenVisible(app, "table", timeout: 8), "Table destination missing")

        let summary = app.descendants(matching: .any)["career.table.summary"]
        let leagueTable = app.descendants(matching: .any)["career.table.leagueTable"]
        let userRow = app.descendants(matching: .any)["career.table.userRow"]
        XCTAssertTrue(summary.waitForExistence(timeout: 6), "Competition summary missing")
        XCTAssertTrue(leagueTable.waitForExistence(timeout: 6), "Full league table missing")
        XCTAssertTrue(userRow.waitForExistence(timeout: 6), "The user's highlighted league row missing")
        XCTAssertTrue(userRow.label.contains("played 3"), "Fixture should place the user after three completed rounds")

        let league = app.buttons["career.table.competition.league"]
        let cup = app.buttons["career.table.competition.national-cup"]
        XCTAssertTrue(league.exists && league.isSelected, "League should be the initial competition")
        XCTAssertTrue(cup.waitForExistence(timeout: 5), "National Cup selector missing")
        cup.tap()
        XCTAssertTrue(cup.isSelected, "National Cup should become selected")
        league.tap()
        XCTAssertTrue(league.isSelected && leagueTable.waitForExistence(timeout: 5),
                      "Returning to League should restore the table")

        let nextFixture = app.descendants(matching: .any)["career.table.nextFixture"]
        let fixtureCentre = app.descendants(matching: .any)["career.table.fixtureCentre"]
        let recentResults = app.descendants(matching: .any)["career.table.fixtureCentre.recent"]
        XCTAssertTrue(nextFixture.waitForExistence(timeout: 6), "Next fixture card missing")
        XCTAssertTrue(fixtureCentre.waitForExistence(timeout: 6), "Fixture centre missing")
        XCTAssertTrue(recentResults.waitForExistence(timeout: 6), "Recent-results section missing")

        shot(app, "table_overview")

        // Compact landscape stacks the lower cards below the full table.
        // Reaching the fixture centre proves the screen owns one usable
        // scroll container; holding its position guards against the same
        // jump-to-top defect previously fixed in Legends Division.
        let tableScroll = app.scrollViews["career.table.scroll"]
        XCTAssertTrue(tableScroll.waitForExistence(timeout: 5), "Table's main scroll container missing")
        var swipes = 0
        while !recentResults.isHittable && swipes < 10 {
            tableScroll.swipeUp()
            swipes += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        XCTAssertTrue(recentResults.isHittable, "Lower fixture content should be reachable by scrolling")
        let heldY = recentResults.frame.minY
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(recentResults.frame.minY, heldY, accuracy: 24,
                       "Table scroll position should remain stable while idle")

        shot(app, "table_fixtures")
        app.terminate()
    }

    // MARK: - B. Home scrolling + no jump-to-top

    func testCareerHomeScrollsToLowerContentAndHoldsPosition() throws {
        let app = launch()
        XCTAssertTrue(screenVisible(app, "home", timeout: 10), "Home screen missing")

        // Open the full Medical Centre from the Home dashboard panel.
        let medical = app.descendants(matching: .any)["career.home.medicalCentre"]
        XCTAssertTrue(medical.waitForExistence(timeout: 8),
                      "Medical Centre panel should be present on Home (fixture has injuries)")
        medical.tap()
        let close = app.descendants(matching: .any)["career.home.medicalSheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 6), "Medical Centre sheet should open")

        // Scroll down: the last injury row must come into view. The row is
        // an accessibility-combined element, so match any element type.
        let lastRow = app.descendants(matching: .any)["career.home.medicalSheet.lastInjury"]
        var swipes = 0
        while !lastRow.isHittable && swipes < 8 {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.2)))
            swipes += 1
            Thread.sleep(forTimeInterval: 0.45)
        }
        XCTAssertTrue(lastRow.exists && lastRow.isHittable,
                      "Lower injury content should become reachable by scrolling")

        // Hold the position: an ordinary update must not reset the scroll.
        let frameBefore = lastRow.frame
        Thread.sleep(forTimeInterval: 1.6)
        XCTAssertEqual(lastRow.frame.minY, frameBefore.minY, accuracy: 24,
                       "Scroll position must not jump back toward the top while idle")

        // Away and back must stay reliable.
        close.tap()
        Thread.sleep(forTimeInterval: 0.6)
        gotoSidebar(app, "inbox")
        XCTAssertTrue(screenVisible(app, "inbox"), "Inbox should open")
        gotoSidebar(app, "home")
        XCTAssertTrue(medical.exists, "Home should return intact")

        shot(app, "home_scroll")
        app.terminate()
    }

    // MARK: - C. Inbox long-article scrolling

    func testCareerInboxLongArticleScrollsInSingleContainer() throws {
        let app = launch()

        XCTAssertTrue(screenVisible(app, "home", timeout: 10)
                      || { gotoSidebar(app, "home"); return screenVisible(app, "home") }(),
                      "Home dashboard missing")

        gotoSidebar(app, "inbox")
        XCTAssertTrue(screenVisible(app, "inbox"), "Inbox destination missing")

        let article = app.descendants(matching: .any)["career.inbox.row.deterministic-long-article"]
        XCTAssertTrue(article.waitForExistence(timeout: 8), "Deterministic long article missing")
        article.tap()

        let end = app.descendants(matching: .any)["career.inbox.article.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 6), "Article detail sheet should open")
        // The fixture's article is deliberately long; swipe until the end
        // marker is on screen (each drag advances the single container).
        var swipes = 0
        while !end.isHittable && swipes < 10 {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
            swipes += 1
            Thread.sleep(forTimeInterval: 0.45)
        }
        XCTAssertTrue(end.isHittable, "Long article's lower content should be reachable in one scroll container")

        shot(app, "inbox_article")
        app.terminate()
    }

    // MARK: - E. Match-flow preservation

    func testCareerMatchFlowPreservedThroughPostMatchContinue() throws {
        let app = launch()
        // Advance to the first user match; the CONTINUE button auto-enters
        // the match-day hub when the match day arrives.
        let ko = app.buttons["career.match.kickoff"]
        var reached = false
        for i in 0..<30 {
            if ko.waitForExistence(timeout: 2) { reached = true; break }
            let cont = app.buttons["career.continue"]
            XCTAssertTrue(cont.waitForExistence(timeout: 8), "CONTINUE missing")
            trace(app, "matchflow", "press\(i) label='\(cont.label)'")
            if cont.label.contains("MATCH") {
                cont.tap()
                reached = ko.waitForExistence(timeout: 10)
                break
            }
            cont.tap()
        }
        if !reached {
            shot(app, "matchflow_stuck")
        }
        XCTAssertTrue(reached, "Never reached KICK OFF within 30 advances")
        XCTAssertTrue(screenVisible(app, "prematch", timeout: 6), "Pre-match screen missing")

        ko.tap()
        let skip = app.buttons["career.match.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 12), "SKIP missing in live match")
        skip.tap()

        let postMatch = app.buttons["career.postMatch.continue"]
        XCTAssertTrue(postMatch.waitForExistence(timeout: 10), "Post-match CONTINUE missing")
        // Answer the interview if shown, then close the result card.
        if postMatch.isHittable {
            postMatch.tap()
        } else {
            for option in ["Praise the players", "Stay grounded", "A fair result",
                           "Two points dropped", "Take responsibility", "Criticise the players"] {
                let b = app.buttons.matching(NSPredicate(format: "label == %@", option)).firstMatch
                if b.exists { b.tap(); break }
            }
            XCTAssertTrue(postMatch.waitForExistence(timeout: 4) && postMatch.isHittable,
                          "Post-match CONTINUE should become reachable after the interview")
            postMatch.tap()
        }

        // Back on the dashboard with a live CONTINUE action.
        XCTAssertTrue(app.buttons["career.continue"].waitForExistence(timeout: 8),
                      "Dashboard CONTINUE should be back after the match")
        shot(app, "after_postmatch")
        app.terminate()
    }
}
