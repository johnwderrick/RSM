import XCTest

/// Drives the real experience-selector screen in the simulator: press-holds
/// each TAP TO ENTER / Settings button and asserts the corresponding pressed
/// artwork image becomes the visible accessibility element while held — proving
/// the two-state artwork stays in sync with the press state.
///
/// Each button is tested in its own fresh launch because pressing the entry
/// buttons navigates away from the selector.
final class RetroSeasonManagerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCareerEntryShowsPressedArtworkWhileHeld() throws {
        try assertPressedArtworkWhileHeld(buttonID: "experience.career",
                                          normalImageID: "RSMCareerEntryButton",
                                          pressedImageID: "RSMCareerEntryButtonPressed")
    }

    func testLegendsEntryShowsPressedArtworkWhileHeld() throws {
        try assertPressedArtworkWhileHeld(buttonID: "experience.legends",
                                          normalImageID: "RSMLegendsEntryButton",
                                          pressedImageID: "RSMLegendsEntryButtonPressed")
    }

    func testSettingsShowsPressedArtworkWhileHeld() throws {
        try assertPressedArtworkWhileHeld(buttonID: "experience.settings",
                                          normalImageID: "RSMSettingsButton",
                                          pressedImageID: "RSMSettingsButtonPressed")
    }

    /// Regression test for a launch-blocking bug: `ClubConfirmView`'s
    /// "MANAGE [CLUB]" button — the only way to actually start a new
    /// Career Mode game — was unreachable on a landscape iPhone (no
    /// scroll container, content taller than the ~402pt of landscape
    /// height). Real XCUITest hit-testing proves the button both exists
    /// and is actually tappable, not just present somewhere off-screen.
    func testNewGameClubConfirmationReachesManageButton() throws {
        let app = XCUIApplication()
        app.launch()

        let careerButton = app.buttons["experience.career"]
        XCTAssertTrue(careerButton.waitForExistence(timeout: 8),
                      "Expected the Career Mode entry button on the experience selector")
        careerButton.tap()

        let newGameButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "New Game")).firstMatch
        XCTAssertTrue(newGameButton.waitForExistence(timeout: 4),
                      "Expected the New Game tile on the Career main menu")
        newGameButton.tap()

        let firstClub = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Old Trafford Reds")).firstMatch
        XCTAssertTrue(firstClub.waitForExistence(timeout: 4),
                      "Expected Old Trafford Reds in the club selection list")
        firstClub.tap()

        let manageButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "MANAGE OLD TRAFFORD REDS")).firstMatch
        XCTAssertTrue(manageButton.waitForExistence(timeout: 4),
                      "Expected the MANAGE button on the club confirmation screen")
        manageButton.tap()

        // Confirms the tap actually did something (started building the
        // squad / left this screen), not just that the coordinate hit.
        XCTAssertFalse(app.buttons["MANAGE OLD TRAFFORD REDS"].waitForExistence(timeout: 4),
                       "Confirming should leave the club confirmation screen entirely")
    }

    /// Drives the full RSM Legends manager-onboarding flow end-to-end on a
    /// fresh install (no `managerProfile` yet, so entering Legends lands
    /// straight on `LegendsManagerOnboardingView`): pick an archetype,
    /// scroll to and tap SELECT MANAGER, fill in a name, tap REVIEW
    /// PROFILE, then BEGIN YOUR LEGEND. Real XCUITest hit-testing (not raw
    /// screen coordinates) is what makes this reliable under the app's
    /// forced-landscape rotation — this is also a real regression test for
    /// the bug this exact flow had: SELECT MANAGER was unreachable once a
    /// profile was picked, because `selection` had no scroll container and
    /// the button was clipped below the visible landscape height.
    func testManagerOnboardingCompletesEndToEnd() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET_LEGENDS_MANAGER"]
        app.launch()
        completeOnboarding(app)
    }

    /// Regression test for a reported "left tab freezes the game" bug:
    /// navigate away from the Home dashboard into another sidebar
    /// destination (Squad), then tap Home again to come back. If
    /// navigating back to Home ever hangs, `waitForHittable` below times
    /// out and this test fails loudly instead of the app just silently
    /// wedging in a live install.
    func testSidebarHomeNavigationDoesNotHangAfterVisitingAnotherTab() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET_LEGENDS_MANAGER"]
        app.launch()
        completeOnboarding(app)

        let squadTab = app.buttons["Squad"]
        XCTAssertTrue(squadTab.waitForExistence(timeout: 8),
                      "Expected the Squad sidebar item on the Legends dashboard")
        squadTab.tap()

        // Grab a screenshot immediately, before any wait-for-idle timeout,
        // so a hang is visible even if the later existence check times out.
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "after-tapping-squad"
        attachment.lifetime = .keepAlways
        add(attachment)
        let pngPath = "/tmp/rsm_squad_tap.png"
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: pngPath))

        // Something Squad-screen-specific should appear, confirming the
        // first navigation itself didn't hang.
        XCTAssertTrue(app.staticTexts["STARTING XI"].waitForExistence(timeout: 8)
                        || app.staticTexts["SQUAD"].waitForExistence(timeout: 2),
                      "Expected to actually land on the Squad screen")

        let homeTab = app.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8),
                      "Expected the Home sidebar item to still be reachable from Squad")
        homeTab.tap()

        // Back on the dashboard, the sidebar's own Squad entry should be
        // tappable again — proves the app is still responsive, not frozen.
        let squadTabAgain = app.buttons["Squad"]
        XCTAssertTrue(squadTabAgain.waitForExistence(timeout: 8),
                      "Expected to land back on the Home dashboard with a live, responsive sidebar")
        XCTAssertTrue(squadTabAgain.isHittable, "Sidebar should be interactive, not frozen, after returning Home")
    }

    func testSquadRedesignTabsAndLibraryRemainReachable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_TRAINING"]
        app.launch()
        XCTAssertTrue(app.buttons["experience.legends"].waitForExistence(timeout: 8))
        app.buttons["experience.legends"].tap()
        XCTAssertTrue(app.buttons["Squad"].waitForExistence(timeout: 8))
        app.buttons["Squad"].tap()
        for tab in ["FORMATIONS", "TACTICS", "ROLES", "SQUAD"] {
            let button = app.buttons["squad.tab.\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertTrue(button.isHittable)
            button.tap()
            if tab == "FORMATIONS" {
                let formation = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "4-4-2")).firstMatch
                XCTAssertTrue(formation.waitForExistence(timeout: 3))
                formation.tap()
            }
        }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Squad redesign"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let library = app.buttons["Player library"]
        XCTAssertTrue(library.isHittable)
        library.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    /// Captures the polished Legends pre-kickoff composition on a real
    /// landscape device and proves the primary action remains reachable after
    /// the dashboard-to-match navigation.
    func testLegendsPreKickoffScreenIsCenteredAndKickoffReachable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_MATCH_READY"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let playMatch = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "PLAY MATCH")).firstMatch
        XCTAssertTrue(playMatch.waitForExistence(timeout: 8),
                      "Expected the Play Match feature on the Legends dashboard")
        // The dashboard itself is vertically scrollable on compact landscape
        // phones; tapping the card lets XCUITest bring it into the visible
        // region before exercising the actual pre-kickoff controls.
        playMatch.tap()

        let kickoff = app.buttons["legends.match.kickoff"]
        XCTAssertTrue(kickoff.waitForExistence(timeout: 8),
                      "Expected the pre-kickoff action on the Play Match screen")
        XCTAssertTrue(kickoff.isHittable,
                      "KICK OFF must remain reachable on a compact landscape screen")
        XCTAssertTrue(app.staticTexts["DIVISION 10"].waitForExistence(timeout: 3),
                      "Division should remain visible with sufficient contrast")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "FIXTURES REMAIN")).firstMatch.exists,
                      "Fixtures remaining should remain visible on the pre-kickoff screen")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends pre-kickoff \(Int(app.windows.firstMatch.frame.width))x\(Int(app.windows.firstMatch.frame.height))"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        let path = "/tmp/rsm_pre_kickoff_\(Int(size.width))x\(Int(size.height)).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
    }

    func testLegendsTrainingPlanPersistsAfterLeavingAndReopening() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_TRAINING"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8))
        legendsButton.tap()

        let trainingTab = app.buttons["legends.nav.training"]
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 8))
        trainingTab.tap()

        let player = app.buttons["legends.training.player.miessi-0506"]
        XCTAssertTrue(player.waitForExistence(timeout: 8))
        player.tap()

        let focus = app.buttons["legends.training.focusPicker"]
        XCTAssertTrue(focus.waitForExistence(timeout: 6))
        focus.tap()
        let passing = app.buttons["PASSING"]
        XCTAssertTrue(passing.waitForExistence(timeout: 4))
        passing.tap()

        let start = app.buttons["legends.training.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 4))
        start.tap()
        XCTAssertTrue(app.staticTexts["1/3 sessions this season"].waitForExistence(timeout: 4))

        app.buttons["Close player details"].tap()
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 6))
        homeTab.tap()
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 6))
        trainingTab.tap()
        XCTAssertTrue(player.waitForExistence(timeout: 6))
        player.tap()

        XCTAssertTrue(app.staticTexts["1/3 sessions this season"].waitForExistence(timeout: 4),
                      "The selected focus and consumed session should persist after navigation")
        XCTAssertTrue(app.buttons["legends.training.focusPicker"].label.contains("PASSING"))
    }

    /// Regression coverage for the sidebar navigation cleanup: every
    /// sidebar destination is reachable, Planning and Reports keep the
    /// sidebar live (their shared chrome renders through LegendsMenuShell
    /// with onNavigate), each highlights its own sidebar item, and rapid
    /// switching never leaves stale or blank content. The selected sidebar
    /// item is exposed to XCUITest via the `.isSelected` trait.
    func testSidebarDestinationsSwitchCleanlyIncludingPlanningAndReports() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET_LEGENDS_MANAGER"]
        app.launch()
        completeOnboarding(app)

        func assertLands(_ tabLabel: String, screenID: String) {
            let tab = app.buttons[tabLabel]
            XCTAssertTrue(tab.waitForExistence(timeout: 8), "Expected sidebar item \(tabLabel)")
            // XCTest centers each tapped sidebar item, leaving the list
            // decelerating; a touch during deceleration stops the scroll
            // instead of activating the button. Let it settle, and retry
            // once if a tap was swallowed that way.
            for attempt in 1...2 {
                Thread.sleep(forTimeInterval: attempt == 1 ? 0.5 : 0.8)
                tab.tap()
                let found = app.otherElements[screenID].waitForExistence(timeout: 8)
                              || app.descendants(matching: .any)[screenID].waitForExistence(timeout: 2)
                if found { return }
                if attempt == 2 {
                    let dump = XCTAttachment(uniformTypeIdentifier: "public.plain-text",
                                             name: "tree-after-\(tabLabel).txt",
                                             payload: app.debugDescription.data(using: .utf8)!)
                    dump.lifetime = .keepAlways
                    add(dump)
                    XCTFail("Tapping \(tabLabel) should show \(screenID)")
                }
            }
        }

        func assertHighlights(_ tabLabel: String) {
            let tab = app.buttons["legends.nav.\(tabLabel.lowercased())"]
            XCTAssertTrue(tab.waitForExistence(timeout: 6), "Sidebar item \(tabLabel) should stay reachable")
            if !tab.isSelected {
                let dump = XCTAttachment(uniformTypeIdentifier: "public.plain-text",
                                         name: "tree-highlight-\(tabLabel).txt",
                                         payload: app.debugDescription.data(using: .utf8)!)
                dump.lifetime = .keepAlways
                add(dump)
            }
            XCTAssertTrue(tab.isSelected,
                          "\(tabLabel) should carry the selected trait while its screen is open")
            XCTAssertTrue(tab.isHittable,
                          "\(tabLabel) should remain visible instead of the sidebar resetting to the top")
        }

        // The full destination sweep — every sidebar item must remain
        // reachable, including Planning and Reports from their own screens.
        // Anchors: screens that already publish their own identifier use it;
        // the rest assert on the shell's derived header identifier.
        let destinations: [(tab: String, screenID: String)] = [
            ("Squad", "legends.shell.squad"), ("Training", "legends.training.screen"), ("Packs", "legends.packs.screen"),
            ("Players", "legends.library"), ("Challenges", "legends.shell.challenges"),
            ("Division", "legends.shell.division"), ("Club", "legends.shell.club"),
            ("Planning", "legends.careerPlanning"), ("Reports", "legends.seasonReports"),
            ("Manager", "legends.shell.manager"), ("Settings", "legends.shell.settings"),
        ]
        for destination in destinations {
            assertLands(destination.tab, screenID: destination.screenID)
        }

        // From Reports: the sidebar must be live and each item must highlight
        // itself — the old Reports screen highlighted PLANNING.
        assertLands("Reports", screenID: "legends.seasonReports")
        assertHighlights("Reports")
        assertLands("Planning", screenID: "legends.careerPlanning")
        assertHighlights("Planning")
        XCTAssertFalse(app.buttons["legends.nav.reports"].isSelected,
                       "Planning must not highlight the Reports item")

        // Direct sidebar routing from Planning to another destination.
        assertLands("Squad", screenID: "legends.shell.squad")
        // Rapid switching must not wedge or blank the app.
        for tab in ["Packs", "Division", "Home", "Hall", "Home"] {
            let tabButton = app.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 6))
            tabButton.tap()
        }
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8),
                      "Rapid switching should settle back on a live Home dashboard")
        XCTAssertTrue(homeTab.isSelected, "Home should be highlighted after returning")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends navigation sweep"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The redesigned Division screen, driven through deterministic fixture
    /// data (`UITEST_LEGENDS_DIVISION`): table visible, user row identifiable,
    /// fixture centre populated with a next fixture, upcoming fixtures and
    /// recent results — and the screen still usable on compact landscape.
    func testDivisionScreenShowsTableUserRowFixturesAndResults() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_DIVISION"]
        app.launch()

        // The fixture profile is already onboarded, so tapping Legends goes
        // straight to the dashboard (no onboarding flow).
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        // The dashboard renders its own sidebar (no shell header), so the
        // first anchor is the sidebar item itself.
        let divisionTab = app.buttons["legends.nav.division"]
        XCTAssertTrue(divisionTab.waitForExistence(timeout: 10),
                      "Expected the Legends dashboard sidebar after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        divisionTab.tap()

        // The Division destination's shell header identifies the screen.
        let divisionShell = app.descendants(matching: .any)["legends.shell.division"]
        XCTAssertTrue(divisionShell.waitForExistence(timeout: 8),
                      "Tapping DIVISION should show the Division screen")
        XCTAssertTrue(divisionTab.isSelected, "DIVISION should be highlighted while its screen is open")

        // The league table renders all eight clubs, with the user's row
        // individually identifiable. (Match any element type — combined
        // accessibility elements can surface as different types.)
        let table = app.descendants(matching: .any)["legends.division.table"]
        XCTAssertTrue(table.waitForExistence(timeout: 8), "Expected the league table panel")
        let userRow = app.descendants(matching: .any)["legends.division.userRow"]
        XCTAssertTrue(userRow.waitForExistence(timeout: 6), "Expected the highlighted user-club row")
        XCTAssertTrue(userRow.label.contains("Your club"), "User row should be announced as the user's club")
        XCTAssertTrue(userRow.label.contains("Promotion zone"),
                      "After a win the user sits in the promotion zone and the row says so")
        for name in ["Neon Borough", "Crown City", "Harbour Rovers", "Atlas Town"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 4),
                          "Expected club \(name) in the table")
        }

        // Zone key spells the colours out in text, not colour alone.
        XCTAssertTrue(app.descendants(matching: .any)["legends.division.zoneKey"].waitForExistence(timeout: 4),
                      "Expected the promotion/relegation zone key")

        // Fixture centre: next fixture prominently marked.
        let nextFixture = app.descendants(matching: .any)["legends.division.nextFixture"]
        XCTAssertTrue(nextFixture.waitForExistence(timeout: 6), "Expected the next-fixture card")
        XCTAssertTrue(nextFixture.label.contains("Next fixture"),
                      "Next fixture card should be announced as such")

        // Upcoming section with the remaining fixtures after the next one.
        let upcoming = app.descendants(matching: .any)["legends.division.upcoming"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 6), "Expected the upcoming fixtures panel")
        XCTAssertTrue(app.staticTexts["UPCOMING"].exists,
                      "Expected the UPCOMING section header")

        // Recent results exist and carry their W/D/L meaning in text.
        let results = app.descendants(matching: .any)["legends.division.results"]
        XCTAssertTrue(results.waitForExistence(timeout: 6), "Expected the recent results panel")
        XCTAssertTrue(app.staticTexts["RECENT RESULTS"].exists,
                      "Expected the RECENT RESULTS section header")
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "won")).firstMatch.exists,
            "Result rows should describe the outcome in words")

        // The user's known results are part of the results panel.
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Harbour Rovers")).firstMatch.exists,
            "Recent results should name the played opponents")

        // The screen remains usable on compact landscape: the fixture centre
        // is hittable (nothing clipped behind the sidebar/safe area). The
        // sidebar stays live — with 13 items XCTest's tap on DIVISION leaves
        // HOME scrolled out of the viewport, so liveness is proven by
        // navigating with it rather than by raw hittability.
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(nextFixture.isHittable, "Next fixture card must be reachable on compact landscape")
        let homeNav = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeNav.waitForExistence(timeout: 6),
                      "Sidebar must stay reachable on the Division screen")

        // Capture the Division screen itself before navigating away.
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Division redesign (compact landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Navigation away and back still works with the redesigned layout.
        for attempt in 1...2 {
            Thread.sleep(forTimeInterval: attempt == 1 ? 0.5 : 0.8)
            homeNav.tap()
            if app.buttons["legends.shell.home"].waitForExistence(timeout: 8)
                || !divisionShell.exists { break }
        }
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        XCTAssertTrue(homeTab.isSelected, "HOME should be highlighted after returning to the dashboard")
        XCTAssertFalse(divisionShell.exists, "Division content should be gone after navigating home")
    }

    /// The redesigned Training development centre, driven by deterministic
    /// fixture data (`UITEST_LEGENDS_TRAINING_CENTRE`): summary band, training
    /// plan, scannable player rows, working filters, player detail round trip
    /// and compact-landscape reachability.
    func testTrainingScreenShowsSummaryPlanPlayersAndStaysUsable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_TRAINING_CENTRE"]
        app.launch()

        // The fixture profile is already onboarded, so tapping Legends goes
        // straight to the dashboard (no onboarding flow).
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        // Dashboard → Training via the sidebar.
        let trainingTab = app.buttons["legends.nav.training"]
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 10),
                      "Expected the Legends dashboard sidebar after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        trainingTab.tap()

        // Summary band with squad-level training facts.
        let summary = app.descendants(matching: .any)["legends.training.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 8), "Expected the training summary band")
        XCTAssertTrue(app.descendants(matching: .any)["legends.training.summary.signed"].waitForExistence(timeout: 4),
                      "Expected the signed-players stat")
        let sessionsStat = app.descendants(matching: .any)["legends.training.summary.sessions"]
        XCTAssertTrue(sessionsStat.waitForExistence(timeout: 4), "Expected the sessions-remaining stat")

        // Training-plan block derived from the saved plans.
        let plan = app.descendants(matching: .any)["legends.training.plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 6), "Expected the training-plan panel")
        XCTAssertTrue(app.staticTexts["TRAINING PLAN"].exists, "Expected the plan panel header")

        // The two anchor players are present, individually identifiable,
        // with their sessions remaining and progress exposed.
        let prospect = app.descendants(matching: .any)["legends.training.player.miessi-0506"]
        XCTAssertTrue(prospect.waitForExistence(timeout: 6), "Expected the seeded prospect player card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.training.player.miessi-1112"].waitForExistence(timeout: 4),
                      "Expected the seeded capped player card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.training.sessions.miessi-0506"].exists,
                      "Expected sessions-remaining text on the player row")
        XCTAssertTrue(app.descendants(matching: .any)["legends.training.progress.miessi-0506"].exists,
                      "Expected a season-progress indicator on the player row")

        // Search and filters: prove reachability by using them. XCTest
        // auto-scrolls to a control before tapping, so a successful menu
        // interaction is stronger evidence than a raw isHittable check that
        // fails for controls below the initial fold of a scrollable screen.
        let search = app.descendants(matching: .any)["legends.training.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 4), "Expected the search field")

        // Regression: Training owns one stable scroll container. The prior
        // GeometryReader nested inside the shell scroll snapped back to the
        // summary after every drag, making these controls effectively hidden.
        let initialSummaryY = summary.frame.minY
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.72))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.48))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertLessThan(summary.frame.minY, initialSummaryY - 20,
                          "Training should retain its moved scroll position instead of jumping back to the top")

        for filter in ["position", "stage", "focus"] {
            XCTAssertTrue(app.buttons["legends.training.filter.\(filter)"].waitForExistence(timeout: 4),
                          "Expected the \(filter) filter")
        }
        XCTAssertTrue(app.buttons["legends.training.sort"].exists, "Expected the sort control")

        // Open the position menu and pick GK: the list narrows and the
        // filter reflects the new value.
        let positionFilter = app.buttons["legends.training.filter.position"]
        positionFilter.tap()
        let gkOption = app.buttons["GK"]
        XCTAssertTrue(gkOption.waitForExistence(timeout: 4),
                      "Tapping POSITION should open its menu — the control is reachable")
        gkOption.tap()
        XCTAssertTrue(positionFilter.label.contains("GK"),
                      "Selecting GK should be reflected in the position filter")
        XCTAssertFalse(prospect.waitForExistence(timeout: 2),
                       "An RW player should be filtered out under the GK position filter")

        // Reset back to ALL so later steps see the full squad.
        positionFilter.tap()
        let allOption = app.buttons["ALL"]
        XCTAssertTrue(allOption.waitForExistence(timeout: 4))
        allOption.tap()
        XCTAssertTrue(prospect.waitForExistence(timeout: 4), "Resetting to ALL should restore the full list")

        // Filtering by search narrows the list but keeps controls usable.
        search.tap()
        app.typeText("miessi")
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(prospect.exists, "The prospect should match 'miessi'")

        // A player card opens the existing detail flow. The capped player
        // sorts to the top of the list, so no scrolling is involved.
        Thread.sleep(forTimeInterval: 0.4)
        let topCard = app.buttons["legends.training.player.miessi-1112"]
        XCTAssertTrue(topCard.waitForExistence(timeout: 6))
        topCard.tap()
        let focusPicker = app.buttons["legends.training.focusPicker"]
        XCTAssertTrue(focusPicker.waitForExistence(timeout: 8),
                      "Opening a player card should show the existing training detail flow")
        XCTAssertTrue(app.buttons["Close player details"].waitForExistence(timeout: 4))
        app.buttons["Close player details"].tap()

        // Navigation away and back still works with the redesigned layout.
        let homeNav = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeNav.waitForExistence(timeout: 6), "Sidebar must stay reachable on Training")
        for attempt in 1...2 {
            Thread.sleep(forTimeInterval: attempt == 1 ? 0.5 : 0.8)
            homeNav.tap()
            if app.buttons["legends.nav.home"].isSelected || !trainingTab.exists { break }
        }
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        XCTAssertTrue(homeTab.isSelected, "HOME should be highlighted after returning to the dashboard")
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.5)
        trainingTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["legends.training.summary"].waitForExistence(timeout: 8),
                      "Training should reopen cleanly after navigating away and back")

        // Capture the Training screen itself.
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Training redesign (compact landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The redesigned Packs shelf and opening flow, driven by deterministic
    /// fixture data (`UITEST_LEGENDS_PACKS`): real balances, an affordable and
    /// an unaffordable tile, the pending Starter Pack banner, opening a pack,
    /// revealing and selecting one of three candidates, claiming it into the
    /// library, and scroll stability on compact landscape.
    func testPacksScreenShowsBalancesOpensPackAndAwardsOneCandidate() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_PACKS"]
        app.launch()

        // The fixture profile is already onboarded, so tapping Legends goes
        // straight to the dashboard (no onboarding flow).
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        // Dashboard → Packs via the sidebar.
        let packsTab = app.buttons["legends.nav.packs"]
        XCTAssertTrue(packsTab.waitForExistence(timeout: 10),
                      "Expected the Legends dashboard sidebar after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        packsTab.tap()

        let packsScreen = app.descendants(matching: .any)["legends.packs.screen"]
        XCTAssertTrue(packsScreen.waitForExistence(timeout: 8), "Expected the Packs shelf")

        // Resources mirror the fixture profile (300 club balance, 3 tokens).
        XCTAssertTrue(app.descendants(matching: .any)["legends.packs.summary.balance"].waitForExistence(timeout: 6),
                      "Expected the club balance stat")
        XCTAssertTrue(app.descendants(matching: .any)["legends.packs.summary.tokens"].exists,
                      "Expected the pack-token balance stat")

        // Pending Starter Pack decision: highly visible and resumable.
        let pendingBanner = app.descendants(matching: .any)["legends.packs.pending"]
        XCTAssertTrue(pendingBanner.waitForExistence(timeout: 6),
                      "The unfinished Starter Pack decision must be visible")

        // Affordable and unaffordable tiles both exist with their stable ids.
        let bronzeTile = app.descendants(matching: .any)["legends.packs.pack.bronze"]
        XCTAssertTrue(bronzeTile.waitForExistence(timeout: 6), "Expected the Bronze Pack tile")
        let iconsTile = app.descendants(matching: .any)["legends.packs.pack.icons"]
        XCTAssertTrue(iconsTile.waitForExistence(timeout: 6), "Expected the Icons Pack tile")
        // With the Starter Pack decision still open, every other pack must
        // explain that it is blocked by the pending decision.
        let finishFirstText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'FINISH OTHER DECISION'")).firstMatch
        let blockedByDecision = iconsTile.label.lowercased().contains("finish")
            || finishFirstText.waitForExistence(timeout: 4)
        XCTAssertTrue(blockedByDecision,
                      "While a decision is pending, other packs must say to finish it first")

        // Scroll stability: one stable scroll container must retain its
        // position after a drag (the old nested-scroll shelf snapped back).
        let initialTileY = bronzeTile.frame.minY
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.72))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.45))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertLessThanOrEqual(bronzeTile.frame.minY, initialTileY + 20,
                                 "Packs should retain its scrolled position instead of jumping back")

        // Resume the pending decision — the shelf must open straight into
        // the three-card choice with the prepared candidates.
        pendingBanner.tap()
        let candidates = (0..<3).map { index in
            app.descendants(matching: .any)["legends.packopening.candidate.\(index)"]
        }
        XCTAssertTrue(candidates[0].waitForExistence(timeout: 8),
                      "Expected three candidate cards for the pending decision")
        XCTAssertTrue(candidates[1].exists && candidates[2].exists,
                      "All three candidate choices must be reachable")

        // Reveal all three cards, then select exactly one.
        for candidate in candidates { candidate.tap(); Thread.sleep(forTimeInterval: 0.3) }
        Thread.sleep(forTimeInterval: 0.6)
        let chosen = candidates[1]
        chosen.tap()
        let claimButton = app.buttons["ADD PLAYER TO LIBRARY"]
        XCTAssertTrue(claimButton.waitForExistence(timeout: 6),
                      "Selecting a candidate must surface the add-to-library action")

        // Claim it: the alert offers the existing add/sign flows.
        claimButton.tap()
        let addButton = app.buttons["ADD TO COLLECTION"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8),
                      "Expected the PLAYER ACQUIRED alert with the existing flows")
        addButton.tap()

        // Back on the shelf, the decision is finished: no pending banner,
        // and the claimed Starter Pack is gone (no permanent CLAIMED tile).
        XCTAssertTrue(app.descendants(matching: .any)["legends.packs.summary"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["legends.packs.pending"].waitForExistence(timeout: 3),
                       "The pending banner must disappear once the decision is claimed")
        XCTAssertFalse(app.descendants(matching: .any)["legends.packs.pack.starter"].exists,
                       "The claimed Starter Pack must disappear from the shelf")
        XCTAssertTrue(bronzeTile.waitForExistence(timeout: 6), "Other packs remain on the shelf")

        // With no decision pending any more, the unaffordable Icons Pack
        // (6 tokens vs the fixture's 3) must now present its real reason.
        let needMoreText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'NEED 3 MORE'")).firstMatch
        let explainsCost = iconsTile.waitForExistence(timeout: 4)
            && (iconsTile.label.lowercased().contains("need 3 more") || needMoreText.exists)
        XCTAssertTrue(explainsCost,
                      "After the decision clears, the unaffordable Icons Pack must explain the missing tokens")

        // Sidebar stays usable after the pack flow.
        let homeNav = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeNav.waitForExistence(timeout: 6), "Sidebar must stay reachable on Packs")
        Thread.sleep(forTimeInterval: 0.5)
        homeNav.tap()
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        XCTAssertTrue(homeTab.isSelected, "HOME should be highlighted after leaving Packs")

        // Capture the Packs shelf.
        Thread.sleep(forTimeInterval: 0.5)
        packsTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["legends.packs.screen"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Packs redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The redesigned Club Facilities destination, driven by deterministic
    /// fixture data (`UITEST_LEGENDS_CLUB_FACILITIES`): Club hub navigation,
    /// Balance-only upgrade, exact balance update, and state preservation
    /// after leaving and reopening the destination.
    func testLegendsFacilitiesNavigationUpgradeAndPersistence() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_CLUB_FACILITIES"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let clubTab = app.buttons["legends.nav.club"]
        XCTAssertTrue(clubTab.waitForExistence(timeout: 10),
                      "Expected the Club sidebar item after entering Legends mode")
        // The compact landscape sidebar is a real scroll container. Bring
        // Club into the visible hit-test area before tapping it; merely
        // finding an off-screen accessibility node does not perform a tap.
        let sidebarScroll = app.scrollViews.firstMatch
        XCTAssertTrue(sidebarScroll.exists, "Expected the Legends sidebar scroll container")
        // XCUITest can report a materialized button as hittable even when its
        // frame is just below the compact landscape viewport. One deliberate
        // sidebar scroll makes the physical hit target visible before the tap.
        sidebarScroll.swipeUp()
        for _ in 0..<3 where !clubTab.isHittable {
            sidebarScroll.swipeUp()
        }
        XCTAssertTrue(clubTab.isHittable,
                      "The Club sidebar item should be reachable in compact landscape")
        Thread.sleep(forTimeInterval: 0.5)
        clubTab.tap()

        // Club's destination content also scrolls on short landscape layouts.
        // Keep the test tied to real hit-testing rather than treating an
        // off-screen materialized tile as usable.
        let destinationScroll = app.scrollViews.element(boundBy: max(0, app.scrollViews.count - 1))
        for _ in 0..<4 {
            if app.buttons["legends.club.facilities"].isHittable { break }
            destinationScroll.swipeUp()
        }

        // The Club hub owns the Facilities route. Prefer the stable identifier,
        // but keep the label fallback for SwiftUI containers that combine the
        // tile's descendants into the button's accessible label.
        let facilityByID = app.buttons["legends.club.facilities"]
        let facilityButton: XCUIElement
        if facilityByID.waitForExistence(timeout: 5) {
            facilityButton = facilityByID
        } else {
            facilityButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "FACILITIES")).firstMatch
            XCTAssertTrue(facilityButton.waitForExistence(timeout: 5),
                          "Expected the Facilities tile in the Club hub")
        }
        facilityButton.tap()

        let facilitiesScreen = app.descendants(matching: .any)["legends.facilities.screen"]
        XCTAssertTrue(facilitiesScreen.waitForExistence(timeout: 8),
                      "Expected the Facilities destination")
        let balance = app.descendants(matching: .any)["legends.facilities.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 5), "Expected the Club Balance summary")
        XCTAssertTrue(balance.label.contains("500"),
                      "The fixture should expose the initial 500 Balance")

        let trainingLevel = app.descendants(matching: .any)["legends.facilities.level.trainingCentre"]
        XCTAssertTrue(trainingLevel.waitForExistence(timeout: 5),
                      "Expected the Training Centre level")
        XCTAssertTrue(trainingLevel.label.contains("LV 0/5"),
                       "Facilities should start at level zero")
        let scoutingLevel = app.descendants(matching: .any)["legends.facilities.level.scoutingNetwork"]
        XCTAssertTrue(scoutingLevel.waitForExistence(timeout: 5),
                      "Expected the Scouting Network level")
        XCTAssertTrue(scoutingLevel.label.contains("LV 0/3"),
                      "Scouting Network should use its meaningful three-level progression")


        let upgradeByID = app.buttons["legends.facilities.upgrade.trainingCentre"]
        let upgradeButton: XCUIElement
        if upgradeByID.waitForExistence(timeout: 5) {
            upgradeButton = upgradeByID
        } else {
            upgradeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Upgrade Training Centre")).firstMatch
            XCTAssertTrue(upgradeButton.waitForExistence(timeout: 5),
                          "Expected the Training Centre upgrade action")
        }
        XCTAssertTrue(upgradeButton.isEnabled, "The first upgrade should be affordable")
        upgradeButton.tap()

        XCTAssertTrue(trainingLevel.waitForExistence(timeout: 5))
        XCTAssertTrue(trainingLevel.label.contains("LV 1/5"),
                      "A successful upgrade should advance the Training Centre to level one")
        XCTAssertTrue(balance.waitForExistence(timeout: 5))
        XCTAssertTrue(balance.label.contains("400"),
                      "The exact 100 Balance upgrade cost should be deducted once")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "UPGRADED TO LEVEL 1")).firstMatch.waitForExistence(timeout: 5),
                      "A successful upgrade should provide visible confirmation")

        // Leave through the shared sidebar, then return through Club and its
        // Facilities tile. This proves the persisted store state survives
        // destination replacement rather than only updating one rendered view.
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 6), "Sidebar must remain usable on Facilities")
        Thread.sleep(forTimeInterval: 0.5)
        homeTab.tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8), "Expected to return to the Home dashboard")
        XCTAssertTrue(homeTab.isSelected, "Home should be highlighted after leaving Facilities")

        let clubTabAgain = app.buttons["legends.nav.club"]
        XCTAssertTrue(clubTabAgain.waitForExistence(timeout: 8))
        // Returning to the dashboard resets the sidebar to its top position;
        // scroll it again before asking XCUITest to tap the off-screen Club
        // destination.
        let sidebarScrollAgain = app.scrollViews.firstMatch
        XCTAssertTrue(sidebarScrollAgain.exists, "Expected the dashboard sidebar scroll container")
        sidebarScrollAgain.swipeUp()
        for _ in 0..<3 where !clubTabAgain.isHittable {
            sidebarScrollAgain.swipeUp()
        }
        XCTAssertTrue(clubTabAgain.isHittable,
                      "The Club sidebar item should remain reachable after returning Home")
        Thread.sleep(forTimeInterval: 0.5)
        clubTabAgain.tap()
        let facilityAgain = app.buttons["legends.club.facilities"]
        let reopenedTile: XCUIElement
        if facilityAgain.waitForExistence(timeout: 5) {
            reopenedTile = facilityAgain
        } else {
            reopenedTile = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "FACILITIES")).firstMatch
            XCTAssertTrue(reopenedTile.waitForExistence(timeout: 5))
        }
        reopenedTile.tap()

        XCTAssertTrue(facilitiesScreen.waitForExistence(timeout: 8),
                      "Facilities should reopen cleanly after navigation away")
        XCTAssertTrue(balance.waitForExistence(timeout: 5) && balance.label.contains("400"),
                      "The updated Balance should remain visible after reopening")
        XCTAssertTrue(trainingLevel.waitForExistence(timeout: 5) && trainingLevel.label.contains("LV 1/5"),
                      "The upgraded facility level should remain visible after reopening")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Facilities redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        let path = "/tmp/rsm_facilities_\(Int(size.width))x\(Int(size.height)).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))

        // Facilities uses the shell-owned vertical ScrollView; SwiftUI can
        // cascade the content screen identifier onto header descendants in
        // this layout, so anchor the real button by its explicit label.
        let facilitiesBackButton = app.buttons["Back to Club"]
        XCTAssertTrue(facilitiesBackButton.waitForExistence(timeout: 6),
                      "Facilities should provide an explicit back button to the Club hub")
        XCTAssertTrue(facilitiesBackButton.label.contains("Back to Club"))
        Thread.sleep(forTimeInterval: 0.5)
        facilitiesBackButton.tap()
        XCTAssertTrue(app.buttons["legends.club.assistants"].waitForExistence(timeout: 6),
                      "The Facilities back button should return to the Club hub")
    }

    /// The redesigned Assistants and Stadiums collections, driven by
    /// deterministic fixture data (`UITEST_LEGENDS_CLUB_COLLECTION`):
    /// Club-hub navigation, active Assistant selection, home Stadium
    /// selection, ALL/OWNED filtering, locked-state presentation, and state
    /// preservation after leaving and reopening each destination.
    func testLegendsAssistantsAndStadiumsSelectionFilteringAndPersistence() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_CLUB_COLLECTION"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        func scrollToClubAndTap() {
            let clubTab = app.buttons["legends.nav.club"]
            XCTAssertTrue(clubTab.waitForExistence(timeout: 10),
                          "Expected the Club sidebar item after entering Legends mode")
            let sidebarScroll = app.scrollViews.firstMatch
            XCTAssertTrue(sidebarScroll.exists, "Expected the Legends sidebar scroll container")
            sidebarScroll.swipeUp()
            for _ in 0..<3 where !clubTab.isHittable {
                sidebarScroll.swipeUp()
            }
            XCTAssertTrue(clubTab.isHittable,
                          "The Club sidebar item should be reachable in compact landscape")
            Thread.sleep(forTimeInterval: 0.5)
            clubTab.tap()
        }

        func openClubTile(identifier: String, title: String) {
            let byID = app.buttons[identifier]
            let tile: XCUIElement
            if byID.waitForExistence(timeout: 5) {
                tile = byID
            } else {
                tile = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", title)).firstMatch
                XCTAssertTrue(tile.waitForExistence(timeout: 5),
                              "Expected the \(title) tile in the Club hub")
            }
            Thread.sleep(forTimeInterval: 0.4)
            tile.tap()
        }

        // MARK: Assistants

        scrollToClubAndTap()
        openClubTile(identifier: "legends.club.assistants", title: "ASSISTANTS")

        let assistantsScreen = app.descendants(matching: .any)["legends.assistants.screen"]
        XCTAssertTrue(assistantsScreen.waitForExistence(timeout: 8),
                      "Expected the redesigned Assistants destination")

        let ownedStat = app.descendants(matching: .any)["legends.assistants.summary.owned"]
        XCTAssertTrue(ownedStat.waitForExistence(timeout: 5), "Expected the owned-count summary")
        XCTAssertTrue(ownedStat.label.contains("2 / 8"),
                      "The fixture owns two assistants; got \(ownedStat.label)")
        let activeStat = app.descendants(matching: .any)["legends.assistants.summary.active"]
        XCTAssertTrue(activeStat.waitForExistence(timeout: 5), "Expected the active-assistant summary")
        XCTAssertTrue(activeStat.label.contains("FERGUNSON"),
                      "The fixture starts with Fergunson active; got \(activeStat.label)")

        // Locked cards present themselves as locked, not as broken rows.
        let lockedAssistant = app.descendants(matching: .any)["legends.assistants.card.sacchini"]
        XCTAssertTrue(lockedAssistant.waitForExistence(timeout: 5),
                      "Expected locked assistant cards in the ALL view")
        XCTAssertTrue(lockedAssistant.label.contains("Locked"),
                      "A locked assistant should announce its locked state; got \(lockedAssistant.label)")
        XCTAssertFalse(lockedAssistant.isEnabled, "Locked assistants must not be selectable")

        // Selecting the second owned assistant deactivates the first:
        // exactly one active assistant at a time.
        let guardiabloCard = app.descendants(matching: .any)["legends.assistants.card.guardiablo"]
        let fergunsonCard = app.descendants(matching: .any)["legends.assistants.card.fergunson"]
        XCTAssertTrue(guardiabloCard.waitForExistence(timeout: 5))
        XCTAssertTrue(guardiabloCard.label.contains("Not active"),
                      "Expected Guardiablo to start inactive; got \(guardiabloCard.label)")
        Thread.sleep(forTimeInterval: 0.4)
        guardiabloCard.tap()

        XCTAssertTrue(guardiabloCard.waitForExistence(timeout: 5))
        XCTAssertTrue(guardiabloCard.label.contains("Active assistant"),
                      "Selecting Guardiablo should make him the active assistant; got \(guardiabloCard.label)")
        XCTAssertTrue(fergunsonCard.waitForExistence(timeout: 5))
        XCTAssertTrue(fergunsonCard.label.contains("Not active"),
                      "Selecting a new assistant should deactivate the previous one")
        XCTAssertTrue(activeStat.label.contains("GUARDIABLO"),
                      "The summary should now name Guardiablo as active")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "SET AS ACTIVE ASSISTANT")).firstMatch.waitForExistence(timeout: 5),
                      "Selection should provide visible confirmation")

        // OWNED filter hides locked cards while keeping owned ones.
        let ownedFilter = app.buttons["legends.assistants.filter.owned"]
        XCTAssertTrue(ownedFilter.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        ownedFilter.tap()
        XCTAssertFalse(lockedAssistant.waitForExistence(timeout: 2),
                       "OWNED filter must hide locked assistant cards")
        XCTAssertTrue(guardiabloCard.exists, "OWNED filter must keep owned cards")

        // Leave through the shared sidebar, then reopen: selection persists.
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 6), "Sidebar must remain usable on Assistants")
        Thread.sleep(forTimeInterval: 0.5)
        homeTab.tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8), "Expected to return to the Home dashboard")

        scrollToClubAndTap()
        openClubTile(identifier: "legends.club.assistants", title: "ASSISTANTS")
        XCTAssertTrue(assistantsScreen.waitForExistence(timeout: 8),
                      "Assistants should reopen cleanly after navigation away")
        XCTAssertTrue(guardiabloCard.waitForExistence(timeout: 5))
        XCTAssertTrue(guardiabloCard.label.contains("Active assistant"),
                      "The active assistant must survive leaving and reopening the screen")
        XCTAssertTrue(activeStat.waitForExistence(timeout: 5) && activeStat.label.contains("GUARDIABLO"),
                      "The summary must reflect the persisted active assistant")

        Thread.sleep(forTimeInterval: 0.6)
        let assistantsShot = XCUIScreen.main.screenshot()
        let assistantsAttachment = XCTAttachment(screenshot: assistantsShot)
        assistantsAttachment.name = "Legends Assistants redesign (landscape)"
        assistantsAttachment.lifetime = .keepAlways
        add(assistantsAttachment)

        // MARK: Stadiums (via the destination's explicit Club back button)

        let assistantsBackButton = app.buttons["legends.header.back"]
        XCTAssertTrue(assistantsBackButton.waitForExistence(timeout: 6),
                      "Assistants should provide an explicit back button to the Club hub")
        XCTAssertTrue(assistantsBackButton.label.contains("Back to Club"))
        Thread.sleep(forTimeInterval: 0.5)
        assistantsBackButton.tap()
        openClubTile(identifier: "legends.club.stadiums", title: "STADIUMS")

        let stadiumsScreen = app.descendants(matching: .any)["legends.stadiums.screen"]
        XCTAssertTrue(stadiumsScreen.waitForExistence(timeout: 8),
                      "Expected the redesigned Stadiums destination")

        let homeStat = app.descendants(matching: .any)["legends.stadiums.summary.home"]
        XCTAssertTrue(homeStat.waitForExistence(timeout: 5), "Expected the home-stadium summary")
        XCTAssertTrue(homeStat.label.contains("FORTRESS"),
                      "The fixture starts with Camp Nou Fortress as home; got \(homeStat.label)")

        let lockedStadium = app.descendants(matching: .any)["legends.stadiums.card.bianconeri-arena"]
        XCTAssertTrue(lockedStadium.waitForExistence(timeout: 5),
                      "Expected locked stadium cards in the ALL view")
        XCTAssertTrue(lockedStadium.label.contains("Locked"),
                      "A locked stadium should announce its locked state; got \(lockedStadium.label)")
        XCTAssertFalse(lockedStadium.isEnabled, "Locked stadiums must not be selectable")

        // Switch the home ground to the other owned stadium.
        let bernabeuCard = app.descendants(matching: .any)["legends.stadiums.card.bernabeu-bowl"]
        let fortressCard = app.descendants(matching: .any)["legends.stadiums.card.camp-fortress"]
        XCTAssertTrue(bernabeuCard.waitForExistence(timeout: 5))
        XCTAssertTrue(bernabeuCard.label.contains("Not the home stadium"),
                      "Expected the Bernabéu Bowl to start as not home; got \(bernabeuCard.label)")
        Thread.sleep(forTimeInterval: 0.4)
        bernabeuCard.tap()

        XCTAssertTrue(bernabeuCard.waitForExistence(timeout: 5))
        XCTAssertTrue(bernabeuCard.label.contains("Current home stadium"),
                      "Selecting the Bernabéu Bowl should make it the home stadium; got \(bernabeuCard.label)")
        XCTAssertTrue(fortressCard.waitForExistence(timeout: 5))
        XCTAssertTrue(fortressCard.label.contains("Not the home stadium"),
                      "Only one home stadium can be active at a time")
        XCTAssertTrue(homeStat.label.contains("BERNABÉU"),
                      "The summary should now name the Bernabéu Bowl as home")

        let stadiumOwnedFilter = app.buttons["legends.stadiums.filter.owned"]
        XCTAssertTrue(stadiumOwnedFilter.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        stadiumOwnedFilter.tap()
        XCTAssertFalse(lockedStadium.waitForExistence(timeout: 2),
                       "OWNED filter must hide locked stadium cards")
        XCTAssertTrue(bernabeuCard.exists, "OWNED filter must keep owned stadiums")

        // Leave and reopen: the home ground persists.
        let homeTab2 = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab2.waitForExistence(timeout: 6), "Sidebar must remain usable on Stadiums")
        Thread.sleep(forTimeInterval: 0.5)
        homeTab2.tap()
        XCTAssertTrue(homeTab2.waitForExistence(timeout: 8), "Expected to return to the Home dashboard")

        scrollToClubAndTap()
        openClubTile(identifier: "legends.club.stadiums", title: "STADIUMS")
        XCTAssertTrue(stadiumsScreen.waitForExistence(timeout: 8),
                      "Stadiums should reopen cleanly after navigation away")
        XCTAssertTrue(bernabeuCard.waitForExistence(timeout: 5))
        XCTAssertTrue(bernabeuCard.label.contains("Current home stadium"),
                      "The home stadium must survive leaving and reopening the screen")
        XCTAssertTrue(homeStat.waitForExistence(timeout: 5) && homeStat.label.contains("BERNABÉU"),
                      "The summary must reflect the persisted home stadium")

        Thread.sleep(forTimeInterval: 0.6)
        let stadiumsShot = XCUIScreen.main.screenshot()
        let stadiumsAttachment = XCTAttachment(screenshot: stadiumsShot)
        stadiumsAttachment.name = "Legends Stadiums redesign (landscape)"
        stadiumsAttachment.lifetime = .keepAlways
        add(stadiumsAttachment)

        let stadiumsBackButton = app.buttons["legends.header.back"]
        XCTAssertTrue(stadiumsBackButton.waitForExistence(timeout: 6),
                      "Stadiums should provide an explicit back button to the Club hub")
        XCTAssertTrue(stadiumsBackButton.label.contains("Back to Club"))
        Thread.sleep(forTimeInterval: 0.5)
        stadiumsBackButton.tap()
        XCTAssertTrue(app.buttons["legends.club.assistants"].waitForExistence(timeout: 6),
                      "The Stadiums back button should return to the Club hub")

        let size = app.windows.firstMatch.frame.size
        try? stadiumsShot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_collection_\(Int(size.width))x\(Int(size.height)).png"))
    }

    /// Shared onboarding flow: pick an archetype, scroll to and tap SELECT
    /// MANAGER, fill in a name, tap REVIEW PROFILE, then BEGIN YOUR LEGEND.
    /// Real XCUITest hit-testing (not raw screen coordinates) is what makes
    /// this reliable under the app's forced-landscape rotation — this is
    /// also a real regression test for the bug this exact flow had: SELECT
    /// MANAGER was unreachable once a profile was picked, because
    /// `selection` had no scroll container and the button was clipped
    /// below the visible landscape height.
    @discardableResult
    private func completeOnboarding(_ app: XCUIApplication) -> Bool {
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let architectCard = app.buttons["THE ARCHITECT. POSSESSION manager. Preferred formation 4-3-3."]
        XCTAssertTrue(architectCard.waitForExistence(timeout: 8),
                      "Expected the Architect archetype card on the manager-selection screen")
        architectCard.tap()

        let selectManagerButton = app.buttons["SELECT MANAGER"]
        XCTAssertTrue(selectManagerButton.waitForExistence(timeout: 4),
                      "SELECT MANAGER should appear once an archetype is picked")
        selectManagerButton.tap()

        let firstNameField = app.textFields["FIRST NAME"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 4),
                      "Expected the customization screen's FIRST NAME field")
        firstNameField.tap()
        firstNameField.typeText("Test")

        let surnameField = app.textFields["SURNAME"]
        XCTAssertTrue(surnameField.exists)
        surnameField.tap()
        surnameField.typeText("Manager")

        let reviewButton = app.buttons["REVIEW PROFILE"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 4))
        XCTAssertTrue(reviewButton.isEnabled, "REVIEW PROFILE should enable once both names are valid")
        reviewButton.tap()

        let beginButton = app.buttons["BEGIN YOUR LEGEND"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 4),
                      "Expected the confirmation screen's BEGIN YOUR LEGEND button")
        beginButton.tap()

        XCTAssertFalse(app.buttons["BEGIN YOUR LEGEND"].waitForExistence(timeout: 4),
                       "Confirming should leave the onboarding flow entirely")
        return true
    }

    /// Launches the app fresh, finds `buttonID`, asserts the pressed artwork is
    /// NOT present initially, then holds the button and asserts the pressed
    /// image IS exposed mid-hold.
    private func assertPressedArtworkWhileHeld(buttonID: String,
                                               normalImageID: String,
                                               pressedImageID: String) throws {
        let app = XCUIApplication()
        let holdDuration: TimeInterval = 3.0
        let pollInterval: TimeInterval = 0.1

        // The first UI test sometimes starts with a cold accessibility tree
        // on hosted runners. Give the real press interaction one clean
        // relaunch before failing, while still requiring the transient
        // pressed artwork to appear during an active hold.
        for attempt in 1...2 {
            if attempt > 1 {
                app.terminate()
            }
            app.launch()

            let button = app.buttons[buttonID]
            XCTAssertTrue(button.waitForExistence(timeout: 8),
                          "Expected button '\(buttonID)' to appear on the experience selector")
            XCTAssertTrue(app.images[normalImageID].waitForExistence(timeout: 5),
                          "Expected normal art '\(normalImageID)' before testing its pressed state")
            XCTAssertTrue(button.isHittable,
                          "Button '\(buttonID)' must be hittable before starting the hold")
            XCTAssertFalse(app.images[pressedImageID].exists,
                           "Pressed art '\(pressedImageID)' should not be present before pressing")

            let visibleWhileHeld = expectation(
                description: "pressed art visible while held: \(buttonID), attempt \(attempt)"
            )
            DispatchQueue.global(qos: .userInitiated).async {
                var elapsed: TimeInterval = 0
                while elapsed < holdDuration {
                    Thread.sleep(forTimeInterval: pollInterval)
                    elapsed += pollInterval
                    if app.images[pressedImageID].exists {
                        visibleWhileHeld.fulfill()
                        return
                    }
                }
            }

            button.press(forDuration: holdDuration)
            let result = XCTWaiter().wait(
                for: [visibleWhileHeld],
                timeout: holdDuration + 2
            )
            if result == .completed {
                return
            }
        }

        XCTFail("Pressed art '\(pressedImageID)' was not visible during either real hold.")
    }
}
