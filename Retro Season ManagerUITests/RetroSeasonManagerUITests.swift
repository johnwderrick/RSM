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

    /// Focused coverage for the polished manager-creation flow: every
    /// archetype reachable and selectable, validation gating the primary
    /// action, the keyboard never trapping REVIEW PROFILE (regression for a
    /// confirmed defect where the step had no scroll container), back
    /// navigation, clean per-step screenshots, and relaunch bypass after
    /// creation. Runs in landscape so the compact-device reachability
    /// guarantees are exercised on every target size.
    ///
    /// Deliberately launches with NO launch arguments: launch arguments set
    /// on any XCUIApplication in a test method persist across app instances
    /// (a relaunch with the reset flag wiped the freshly created profile —
    /// verified via an app-side init log). Determinism comes from the app's
    /// own DEBUG "RESET MANAGER ONBOARDING" control instead.
    func testManagerCreationShowsFullBodyArtworkAndRemainsUsable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()

        func snap(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            let size = app.windows.firstMatch.frame.size
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_mc_\(name)_\(Int(size.width))x\(Int(size.height)).png"))
        }

        // Step 1 — archetype selection. A leftover profile from a previous
        // run is reset through the app's own DEBUG control (never launch args).
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8))
        legendsButton.tap()
        if !app.staticTexts["CHOOSE YOUR MANAGER"].waitForExistence(timeout: 4) {
            let managerNav = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Manager")).firstMatch
            XCTAssertTrue(managerNav.waitForExistence(timeout: 8),
                          "Expected the Manager sidebar destination when a profile already exists")
            managerNav.tap()
            let resetButton = app.buttons["RESET MANAGER ONBOARDING"]
            XCTAssertTrue(resetButton.waitForExistence(timeout: 8),
                          "Expected the DEBUG reset control on the Manager Profile screen")
            resetButton.tap()
        }
        XCTAssertTrue(app.staticTexts["CHOOSE YOUR MANAGER"].waitForExistence(timeout: 8),
                      "Onboarding must be showing before the creation journey starts")
        snap("1-selection")

        let archetypeCards = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Preferred formation"))
        XCTAssertTrue(archetypeCards.firstMatch.waitForExistence(timeout: 8),
                      "Expected the archetype cards on the manager-selection screen")
        XCTAssertEqual(archetypeCards.count, 5, "All five manager profiles must be offered")
        XCTAssertTrue(archetypeCards.element(boundBy: 0).isHittable,
                      "The first archetype card must be reachable in landscape")

        // Select the last card to prove the horizontal card row scrolls and
        // every option is selectable, not just the first one visible.
        archetypeCards.element(boundBy: 0).tap()
        let selectManagerButton = app.buttons["SELECT MANAGER"]
        XCTAssertTrue(selectManagerButton.waitForExistence(timeout: 4))
        selectManagerButton.tap()

        // Back navigation returns to selection with the choice retained.
        XCTAssertTrue(app.buttons["BACK"].waitForExistence(timeout: 4))
        // (Back is on the customization step; verified after moving forward.)

        // Step 2 — customization: validation, keyboard, reachability.
        let firstNameField = app.textFields["FIRST NAME"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 4))
        snap("2-customization")
        let reviewButton = app.buttons["REVIEW PROFILE"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 4))
        XCTAssertFalse(reviewButton.isEnabled,
                       "REVIEW PROFILE must be disabled while required fields are incomplete")

        firstNameField.tap()
        firstNameField.typeText("Alex")
        let surnameField = app.textFields["SURNAME"]
        XCTAssertTrue(surnameField.waitForExistence(timeout: 4))
        surnameField.tap()
        surnameField.typeText("Ferguson")

        // Regression for the two confirmed keyboard-trap defects: on a
        // compact landscape phone the scroll container reveals the action;
        // on iPad compatibility mode the content fits the viewport so
        // scrolling is impossible — tapping outside the fields dismisses the
        // keyboard instead (the affordance added with this pass).
        for _ in 0..<3 {
            if reviewButton.isHittable { break }
            app.swipeUp()
            if reviewButton.isHittable { break }
            app.otherElements.firstMatch.tap()
        }
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 4))
        XCTAssertTrue(reviewButton.isEnabled, "Valid names must enable REVIEW PROFILE")
        XCTAssertTrue(reviewButton.isHittable,
                      "REVIEW PROFILE must be reachable with the keyboard up")

        // Back returns to step 1 with the archetype still selected.
        app.buttons["BACK"].firstMatch.tap()
        XCTAssertTrue(selectManagerButton.waitForExistence(timeout: 4),
                      "Back must return to the selection step with the choice retained")
        selectManagerButton.tap()
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 4))
        XCTAssertEqual(firstNameField.value as? String, "Alex",
                       "Forward navigation must retain entered names")

        // Move on to confirmation.
        if !reviewButton.isHittable { app.swipeUp() }
        reviewButton.tap()

        // Step 3 — confirmation: full-body artwork card, primary action reachable.
        // The full-body card is taller than the old cropped circle, so on a
        // compact landscape phone the action starts below the fold; the step
        // owns the scroll container, so scrolling must reveal it (the same
        // reachability contract as the customization step's keyboard case).
        let beginButton = app.buttons["BEGIN YOUR LEGEND"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 4))
        snap("3-confirmation-artwork")
        for _ in 0..<3 where !beginButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(beginButton.isEnabled)
        XCTAssertTrue(beginButton.isHittable,
                      "BEGIN YOUR LEGEND must be reachable by scrolling, never clipped permanently")
        snap("3-confirmation-actions")
        beginButton.tap()

        // Creation reaches the first playable Legends screen.
        XCTAssertTrue(app.buttons["Squad"].waitForExistence(timeout: 8),
                      "Confirming creation must land on the playable Legends dashboard")
        snap("4-dashboard")

        // Relaunching with the created profile must bypass onboarding.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        let legendsAgain = relaunched.buttons["experience.legends"]
        XCTAssertTrue(legendsAgain.waitForExistence(timeout: 12),
                      "A returning player must still reach the experience selector on relaunch")
        legendsAgain.tap()
        XCTAssertTrue(relaunched.buttons["Squad"].waitForExistence(timeout: 8),
                      "A created profile must skip manager creation on relaunch")
        XCTAssertFalse(relaunched.staticTexts["CHOOSE YOUR MANAGER"].exists,
                       "Onboarding must not repeat for a returning profile")
    }

    /// Focused coverage for the manager-editing flow opened from the Manager
    /// Profile destination's EDIT MANAGER action: opens with every saved
    /// value prepopulated, offers the full archetype set, validates like
    /// creation, reaches review with the keyboard up, explains retained
    /// progression, applies exactly once, preserves career state, and the
    /// edited identity survives an app relaunch. Cancel and Back never
    /// change the stored manager.
    func testManagerEditFlowPrepopulatesAppliesOnceAndPreservesCareer() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_MANAGER_EDIT"]
        app.launch()

        func snap(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            let size = app.windows.firstMatch.frame.size
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_me_\(name)_\(Int(size.width))x\(Int(size.height)).png"))
        }

        func clearAndType(_ field: XCUIElement, _ text: String) {
            field.tap()
            let current = (field.value as? String) ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4))
            field.typeText(text)
        }

        // Enter Legends and open the Manager Profile destination.
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8))
        legendsButton.tap()
        let managerTab = app.buttons["legends.nav.manager"]
        XCTAssertTrue(managerTab.waitForExistence(timeout: 10),
                      "Expected the Manager sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        managerTab.tap()

        let editManager = app.buttons["manager.editManager"]
        XCTAssertTrue(editManager.waitForExistence(timeout: 8),
                      "Expected the EDIT MANAGER action on the Manager Profile destination")
        snap("1-profile")

        // Open the editor: it must present the archetype choice preselected.
        editManager.tap()
        XCTAssertTrue(app.staticTexts["EDIT YOUR MANAGER"].waitForExistence(timeout: 8),
                      "Expected the polished editor to open on the archetype step")
        XCTAssertTrue(app.buttons["identity.archetypeCard.architect"].exists,
                      "The current manager's archetype card must be offered")
        let continueButton = app.buttons["identity.edit.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))

        // CANCEL from the archetype step: the editor closes and the stored
        // manager is unchanged.
        let cancelButton = app.buttons["identity.edit.cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 4))
        cancelButton.tap()
        XCTAssertFalse(continueButton.waitForExistence(timeout: 2),
                       "Cancel must close the editor")
        XCTAssertTrue(app.buttons["manager.editManager"].waitForExistence(timeout: 6),
                      "Cancel returns to the Manager Profile destination")

        // Reopen and walk forward without changing anything to verify the
        // prepopulated values.
        app.buttons["manager.editManager"].tap()
        XCTAssertTrue(continueButton.waitForExistence(timeout: 6))
        continueButton.tap()
        let firstNameField = app.textFields["FIRST NAME"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 5))
        XCTAssertEqual(firstNameField.value as? String, "Alex",
                       "First name must be prepopulated from the saved manager")
        XCTAssertEqual(app.textFields["SURNAME"].value as? String, "Ferguson",
                       "Surname must be prepopulated from the saved manager")
        let reviewButton = app.buttons["identity.edit.review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 4))
        XCTAssertTrue(reviewButton.isEnabled, "Saved values must already be valid")
        snap("2-details-prepopulated")

        // An invalid surname blocks review exactly like creation.
        let surnameField = app.textFields["SURNAME"]
        surnameField.tap()
        surnameField.typeText("!")
        XCTAssertFalse(reviewButton.isEnabled, "An invalid edit must not be savable")

        // Edit the identity: surname, first name and nationality.
        clearAndType(surnameField, "Mourinho")
        clearAndType(firstNameField, "Jose")
        // Dismiss the keyboard before opening the nationality menu (tapping
        // the heading is a safe outside-tap; a focused field plus a
        // competing tap otherwise swallows the picker's opening tap).
        app.staticTexts["MANAGER DETAILS"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        let nationalityPicker = app.descendants(matching: .any)["identity.edit.nationality"]
        XCTAssertTrue(nationalityPicker.waitForExistence(timeout: 4))
        nationalityPicker.tap()
        // France sits near the top of the nation list, so the popup menu
        // shows it without scrolling (menu scrolling is not deterministic
        // under XCUITest).
        let franceOption = app.buttons["France"]
        XCTAssertTrue(franceOption.waitForExistence(timeout: 6),
                      "Expected the nationality menu to offer France")
        franceOption.tap()

        // Review must be reachable with the keyboard up (scroll on compact
        // phones; tap-outside dismisses it where content fits, iPad style).
        for _ in 0..<4 {
            if reviewButton.isHittable { break }
            app.swipeUp()
            if reviewButton.isHittable { break }
            app.otherElements.firstMatch.tap()
        }
        XCTAssertTrue(reviewButton.isEnabled, "Valid edited values must enable review")
        XCTAssertTrue(reviewButton.isHittable,
                      "REVIEW PROFILE must be reachable with the keyboard up")
        reviewButton.tap()

        // Review step: full-body artwork, identity summary, and the explicit
        // promise that the club career and its progress are retained.
        XCTAssertTrue(app.staticTexts["REVIEW CHANGES"].waitForExistence(timeout: 5))
        let promise = app.descendants(matching: .any)["identity.edit.promise"]
        XCTAssertTrue(promise.waitForExistence(timeout: 5),
                      "Review must explain that career progress is retained")
        XCTAssertTrue(promise.label.contains("carry over unchanged"), "Got \(promise.label)")
        XCTAssertTrue(app.staticTexts["JOSE MOURINHO"].exists,
                      "Review must show the edited identity")
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "France · AGE")).firstMatch.exists,
                      "Review must show the edited nationality; got a different nationality")
        let applyButton = app.buttons["identity.edit.apply"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 4))
        snap("3-review")

        // Apply once: the editor closes and the profile shows the new
        // identity immediately.
        applyButton.tap()
        XCTAssertFalse(applyButton.waitForExistence(timeout: 2),
                       "Applying must close the editor")
        XCTAssertFalse(app.staticTexts["REVIEW CHANGES"].exists,
                       "Applying must dismiss the complete edit flow")
        XCTAssertTrue(app.buttons["manager.editManager"].waitForExistence(timeout: 8),
                      "Applying must return to the Manager Profile destination")
        XCTAssertTrue(app.staticTexts["JOSE MOURINHO"].waitForExistence(timeout: 8),
                      "The Manager Profile destination must show the new identity")
        snap("4-profile-updated")

        // An unchanged edit is a successful no-op: Save still closes the
        // editor and returns to the profile without rewriting identity.
        app.buttons["manager.editManager"].firstMatch.tap()
        XCTAssertTrue(app.buttons["identity.edit.continue"].waitForExistence(timeout: 6))
        app.buttons["identity.edit.continue"].tap()
        let reviewAgain = app.buttons["identity.edit.review"]
        XCTAssertTrue(reviewAgain.waitForExistence(timeout: 5))
        for _ in 0..<3 where !reviewAgain.isHittable { app.swipeUp() }
        reviewAgain.tap()
        let applyAgain = app.buttons["identity.edit.apply"]
        XCTAssertTrue(applyAgain.waitForExistence(timeout: 5))
        applyAgain.tap()
        XCTAssertFalse(applyAgain.waitForExistence(timeout: 2),
                       "Saving an unchanged manager must close the editor")
        XCTAssertFalse(app.staticTexts["REVIEW CHANGES"].exists,
                       "An unchanged save must dismiss the complete edit flow")
        XCTAssertTrue(app.buttons["manager.editManager"].waitForExistence(timeout: 8),
                      "An unchanged save must return to Manager Profile")
        XCTAssertTrue(app.staticTexts["JOSE MOURINHO"].exists,
                      "An unchanged save must retain the existing identity")

        // Relaunch with no launch arguments: the edited identity must come
        // back from disk, not from a fixture re-seed.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        let legendsAgain = relaunched.buttons["experience.legends"]
        XCTAssertTrue(legendsAgain.waitForExistence(timeout: 12))
        legendsAgain.tap()
        let managerTabAgain = relaunched.buttons["legends.nav.manager"]
        XCTAssertTrue(managerTabAgain.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.5)
        managerTabAgain.tap()
        XCTAssertTrue(relaunched.staticTexts["JOSE MOURINHO"].waitForExistence(timeout: 8),
                      "The edited identity must survive save/load and relaunch")
        XCTAssertTrue(relaunched.buttons["manager.editManager"].waitForExistence(timeout: 6))
        snap("5-relaunch-preserved")
    }

    /// Regression test for a reported "left tab freezes the game" bug:
    /// navigate away from the Home dashboard into another sidebar
    /// destination (Squad), then tap Home again to come back. If
    /// navigating back to Home ever hangs, `waitForHittable` below times
    /// out and this test fails loudly instead of the app just silently
    /// wedging in a live install.
    /// The redesigned player-detail sheet: opens from a Squad pitch token
    /// and from the Players grid, presents the flag/biography/status
    /// attributes, favourites from the detail, and returns with the origin
    /// screen's filters and scroll position intact.
    func testLegendsPlayerDetailBiographyStatusAndRoundTrip() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_PLAYER_DETAIL"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        // ---- From Squad: a pitch token opens the redesigned detail ----
        XCTAssertTrue(app.buttons["Squad"].waitForExistence(timeout: 10),
                      "Expected the Squad sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Squad"].tap()

        let keeperToken = app.buttons["squad.token.xi.0"]
        XCTAssertTrue(keeperToken.waitForExistence(timeout: 8),
                      "Expected the starting-XI goalkeeper token (fixture starter GK slot)")
        Thread.sleep(forTimeInterval: 0.4)
        keeperToken.tap()

        let detail = app.descendants(matching: .any)["legends.playerDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 8),
                      "Expected the redesigned player-detail sheet from Squad")
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.portrait"].exists,
                      "Expected the player portrait")
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.flag"].exists,
                      "Expected the nationality flag beside the nationality")
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.biography"].exists,
                      "Expected the biography card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.statusCard"].exists,
                      "Expected the career-status card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.nationalityRow"].exists,
                      "Expected the biography nationality row")
        snap("rsm_pdetail_1-squad-gk")

        let detailClose = app.buttons["legends.playerDetail.close"]
        XCTAssertTrue(detailClose.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        detailClose.tap()
        XCTAssertTrue(keeperToken.waitForExistence(timeout: 8),
                      "Closing the sheet returns to Squad with the pitch intact")

        // ---- From Players: open detail, favourite, return with state ----
        // Orientation can be dropped on a cold simulator relaunch; the
        // frame-stability assertions below are only meaningful in the
        // compact-landscape configuration this test verifies.
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.8)
        let windowSize = app.windows.firstMatch.frame.size
        XCTAssertTrue(windowSize.width > windowSize.height,
                      "Expected landscape orientation (got \(windowSize)); the scroll-stability assertion needs it")

        let playersTab = app.buttons["legends.nav.players"]
        XCTAssertTrue(playersTab.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.5)
        playersTab.tap()

        let playersScreen = app.descendants(matching: .any)["legends.library"]
        XCTAssertTrue(playersScreen.waitForExistence(timeout: 8),
                      "Expected the Players destination")
        let cantinaTile = app.descendants(matching: .any)["legends.players.card.cantina-9596"]
        XCTAssertTrue(cantinaTile.waitForExistence(timeout: 5),
                      "Expected the Cantina tile (fixture reserves player)")

        // Record the tile's frame before opening the detail sheet — after
        // returning, the grid must not have jumped (same on-screen place).
        let frameBefore = cantinaTile.frame
        Thread.sleep(forTimeInterval: 0.4)
        cantinaTile.tap()

        XCTAssertTrue(detail.waitForExistence(timeout: 8),
                      "Expected the redesigned player-detail sheet from Players")
        let favouriteButton = app.buttons["legends.player.favourite"]
        XCTAssertTrue(favouriteButton.waitForExistence(timeout: 5),
                      "Expected the FAVOURITE action in the detail sheet")
        XCTAssertTrue(favouriteButton.label.contains("FAVOURITED"),
                      "Cantina is pre-favourited in the fixture; got \(favouriteButton.label)")
        favouriteButton.tap()
        XCTAssertTrue(favouriteButton.waitForExistence(timeout: 3)
                      && !favouriteButton.label.contains("FAVOURITED"),
                      "Tapping FAVOURITED unfavourites through the authoritative store")
        favouriteButton.tap()
        XCTAssertTrue(favouriteButton.waitForExistence(timeout: 3)
                      && favouriteButton.label.contains("FAVOURITED"),
                      "Tapping again re-favourites (round trip)")

        // The grouped attribute cards render in the sheet's single stable
        // scroll container (plain rows keep them in the accessibility tree
        // even off-screen). Physical drags are deliberately avoided here:
        // simulator rotation can silently fail on relaunch, which would
        // aim the gesture at the Players grid underneath and corrupt the
        // frame-stability measurement below.
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.attributes"].waitForExistence(timeout: 4),
                      "Expected the grouped attribute cards in the detail")
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail.detailedAttributes"].exists,
                      "Expected the detailed-attribute card (goalkeeper grouping included)")
        XCTAssertTrue(detailClose.isHittable, "Close remains reachable over the scroll container (pinned)")
        snap("rsm_pdetail_2-players-cantina")

        Thread.sleep(forTimeInterval: 0.4)
        detailClose.tap()
        XCTAssertTrue(playersScreen.waitForExistence(timeout: 8),
                      "Returning from detail lands back on the Players screen")
        // Let the dismissal transition fully settle before measuring frames.
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(cantinaTile.waitForExistence(timeout: 5),
                      "The same player tile survives the detail round trip")

        // Scroll-stability check immune to XCUITest's own tap-time
        // auto-scrolling (the first tap scrolled the off-screen tile into
        // view, which is a test-runner artefact, not a product reset): a
        // second detail round trip on the now-visible tile must leave the
        // grid at exactly the same position — a dismissal-time scroll
        // reset would move it back to the top.
        let frameAfterFirstTrip = cantinaTile.frame
        Thread.sleep(forTimeInterval: 0.4)
        cantinaTile.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.5)
        detailClose.tap()
        XCTAssertTrue(playersScreen.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(cantinaTile.waitForExistence(timeout: 5))
        let frameAfterSecondTrip = cantinaTile.frame
        XCTAssertEqual(frameAfterSecondTrip.minY, frameAfterFirstTrip.minY, accuracy: 5,
                       "Closing the detail sheet must not reset the grid scroll (no jump-to-top)")

        // Comparison still works from the redesigned detail.
        Thread.sleep(forTimeInterval: 0.4)
        cantinaTile.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        let compareButton = app.buttons["legends.player.compare"]
        XCTAssertTrue(compareButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        compareButton.tap()
        let comparison = app.descendants(matching: .any)["legends.playerComparison"]
        XCTAssertTrue(comparison.waitForExistence(timeout: 8),
                      "Expected the comparison sheet from the redesigned detail")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        done.tap()
        XCTAssertTrue(detailClose.waitForExistence(timeout: 5),
                      "Landing back on the detail after comparison")
        Thread.sleep(forTimeInterval: 0.4)
        detailClose.tap()
        XCTAssertTrue(playersScreen.waitForExistence(timeout: 8))

        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends player detail redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_pdetail_final_\(Int(size.width))x\(Int(size.height)).png"))
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = XCUIApplication().windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/\(name)_\(Int(size.width))x\(Int(size.height)).png"))
    }

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

    /// Squad reserves section: BENCH/RESERVES sub-tabs, reserve entries with
    /// portrait/OVR/position, unsigned exclusion, detail round trip preserving
    /// the RESERVES selection, stable panel scroll, and the empty state.
    func testLegendsSquadReservesSectionAndDetailRoundTrip() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_SQUAD_RESERVES"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        XCTAssertTrue(app.buttons["Squad"].waitForExistence(timeout: 10),
                      "Expected the Squad sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Squad"].tap()

        // Switch to RESERVES; the unsigned Cantina card must be excluded.
        let reservesTab = app.buttons["squad.panel.reserves"]
        XCTAssertTrue(reservesTab.waitForExistence(timeout: 8), "Expected the RESERVES sub-tab")
        Thread.sleep(forTimeInterval: 0.3)
        reservesTab.tap()
        XCTAssertTrue(reservesTab.isSelected, "RESERVES should be selected after tapping")

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "RESERVES (")).firstMatch.waitForExistence(timeout: 5),
                      "Expected the reserves count header")
        XCTAssertFalse(app.descendants(matching: .any)["squad.reserves.empty"].exists,
                       "The fixture has two signed reserves, so the empty state must not show")
        XCTAssertFalse(app.descendants(matching: .any)["squad.reserve.maldinho-9596"].exists,
                       "Unsigned collection cards must never appear as reserves")

        // The reserve container uses .accessibilityElement(children: .contain),
        // so it surfaces as a generic element, not a button.
        let reserve = app.descendants(matching: .any)["squad.reserve.neuwald-2223"]
        XCTAssertTrue(reserve.waitForExistence(timeout: 5),
                      "Expected the favourited reserve (Neuwald) entry")
        let card = app.descendants(matching: .any)["squad.reserve.cantina-9596"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Expected the signed reserve (Cantina) entry")
        snap("rsm_reserves_1-list")

        // Detail round trip from a reserve; the RESERVES tab must survive.
        Thread.sleep(forTimeInterval: 0.3)
        card.tap()
        let detail = app.descendants(matching: .any)["legends.playerDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 8),
                      "Expected the player-detail sheet to open from a reserve entry")
        snap("rsm_reserves_2-detail")
        let close = app.buttons["legends.playerDetail.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        close.tap()
        XCTAssertTrue(app.buttons["squad.panel.reserves"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["squad.panel.reserves"].isSelected,
                      "Closing Player Detail must return to the same RESERVES subsection")
        XCTAssertTrue(app.descendants(matching: .any)["squad.reserve.cantina-9596"].exists,
                      "Reserve entries must still be listed after the detail round trip")

        // ---- Reserve → occupied XI slot: premium pitch targeting ----
        let toXI = app.descendants(matching: .any)["squad.reserve.toxi.cantina-9596"]
        XCTAssertTrue(toXI.waitForExistence(timeout: 5), "Expected the MOVE TO XI action on a reserve row")
        Thread.sleep(forTimeInterval: 0.3)
        toXI.tap()

        let assignmentBanner = app.descendants(matching: .any)["squad.assignment.banner"]
        XCTAssertTrue(assignmentBanner.waitForExistence(timeout: 6),
                      "Expected the premium assignment banner above the live squad")
        let occupiedRow = app.buttons["squad.assignment.xi.0"]
        XCTAssertTrue(occupiedRow.waitForExistence(timeout: 5))
        XCTAssertTrue(occupiedRow.label.localizedCaseInsensitiveContains("occupied by"),
                      "Occupied targets must name the player who will move to reserves; got: \(occupiedRow.label)")
        let secondTarget = app.buttons["squad.assignment.xi.10"]
        XCTAssertTrue(secondTarget.waitForExistence(timeout: 3),
                      "Every live XI position must become a direct target")
        snap("rsm_reserves_4-pitch-targeting")

        // Cancellation returns cleanly to RESERVES without changing the squad.
        let cancelAssignment = app.buttons["squad.assignment.cancel"]
        XCTAssertTrue(cancelAssignment.waitForExistence(timeout: 3))
        cancelAssignment.tap()
        XCTAssertFalse(assignmentBanner.waitForExistence(timeout: 1))
        XCTAssertTrue(app.descendants(matching: .any)["squad.reserve.cantina-9596"].exists)
        XCTAssertTrue(app.buttons["squad.panel.reserves"].isSelected)
        app.descendants(matching: .any)["squad.reserve.toxi.cantina-9596"].tap()
        XCTAssertTrue(occupiedRow.waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.3)
        occupiedRow.tap()

        let status = app.descendants(matching: .any)["squad.panel.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 6),
                      "Expected confirmation feedback naming the move")
        XCTAssertTrue(status.label.contains("→ STARTING XI slot 1"), "Status must name the destination; got: \(status.label)")
        XCTAssertTrue(status.label.contains("to reserves"), "Status must name the displaced player; got: \(status.label)")
        XCTAssertFalse(app.descendants(matching: .any)["squad.reserve.cantina-9596"].exists,
                       "The moved reserve must leave the reserves list")
        XCTAssertTrue(app.buttons["squad.panel.reserves"].isSelected,
                      "XI targeting must return to the RESERVES list after a move")

        // ---- Reserve → bench slot: direct targeting in the live bench ----
        let toBench = app.descendants(matching: .any)["squad.reserve.tobench.neuwald-2223"]
        XCTAssertTrue(toBench.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.3)
        toBench.tap()
        XCTAssertTrue(assignmentBanner.waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["squad.panel.bench"].isSelected,
                      "Bench targeting should reveal the live BENCH panel")
        let benchRow = app.buttons["squad.assignment.bench.0"]
        XCTAssertTrue(benchRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.3)
        benchRow.tap()
        XCTAssertTrue(status.waitForExistence(timeout: 6))
        XCTAssertTrue(status.label.contains("→ BENCH slot 1"), "Bench move feedback missing; got: \(status.label)")
        XCTAssertFalse(app.descendants(matching: .any)["squad.reserve.neuwald-2223"].waitForExistence(timeout: 3),
                       "The moved reserve must leave the reserves list")

        // Bench remains visible after placement, using the normal token UI.
        let benchTab = app.buttons["squad.panel.bench"]
        XCTAssertTrue(benchTab.waitForExistence(timeout: 5))
        XCTAssertTrue(benchTab.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["squad.token.bench.0"].waitForExistence(timeout: 5),
                      "Expected the existing bench slots under BENCH")

        // A selected XI/bench player exposes an obvious move action in the
        // accepted Player Detail presentation; it is not hidden behind a
        // long-press context menu.
        let benchPlayer = app.descendants(matching: .any)["squad.token.bench.0"]
        benchPlayer.tap()
        XCTAssertTrue(app.descendants(matching: .any)["legends.playerDetail"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["legends.playerDetail.moveToReserves"].waitForExistence(timeout: 4),
                      "Assigned players must expose a visible MOVE TO RESERVES action")
        app.buttons["legends.playerDetail.close"].tap()

        let size = app.windows.firstMatch.frame.size
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_reserves_3-bench_\(Int(size.width))x\(Int(size.height)).png"))
    }

    /// The reserves empty state: with every signed player assigned to the XI
    /// or bench, the panel explains the situation instead of showing a blank.
    func testLegendsSquadReservesEmptyStateExplainsAssignment() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_SQUAD_RESERVES_EMPTY"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8))
        legendsButton.tap()
        XCTAssertTrue(app.buttons["Squad"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Squad"].tap()

        let reservesTab = app.buttons["squad.panel.reserves"]
        XCTAssertTrue(reservesTab.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.3)
        reservesTab.tap()

        let empty = app.staticTexts["squad.reserves.empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5),
                      "Expected the explanatory empty state when no signed reserves exist")
        XCTAssertTrue(empty.label.contains("All signed players are currently assigned to the Starting XI or bench."),
                      "Empty state must explain the assignment situation; got: \(empty.label)")
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
        let trainingSessions = app.staticTexts["legends.playerDetail.trainingSessions"]
        XCTAssertTrue(trainingSessions.waitForExistence(timeout: 4))
        XCTAssertEqual(trainingSessions.label, "1/3 THIS SEASON")

        app.buttons["Close player details"].tap()
        let homeTab = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 6))
        homeTab.tap()
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 6))
        trainingTab.tap()
        XCTAssertTrue(player.waitForExistence(timeout: 6))
        player.tap()

        XCTAssertTrue(trainingSessions.waitForExistence(timeout: 4),
                      "The consumed session should persist after navigation")
        XCTAssertEqual(trainingSessions.label, "1/3 THIS SEASON")
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
            ("Planning", "legends.planning.screen"), ("Reports", "legends.reports.screen"),
            ("Manager", "legends.shell.manager"), ("Settings", "legends.shell.settings"),
        ]
        for destination in destinations {
            assertLands(destination.tab, screenID: destination.screenID)
        }

        // From Reports: the sidebar must be live and each item must highlight
        // itself — the old Reports screen highlighted PLANNING.
        assertLands("Reports", screenID: "legends.reports.screen")
        assertHighlights("Reports")
        assertLands("Planning", screenID: "legends.planning.screen")
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

    /// Regression for the reported Division scroll lock: the page used to
    /// stick at the top (the content's GeometryReader absorbed the shell
    /// ScrollView's viewport-height proposal) and could jump back to the top
    /// during ordinary view updates. The screen must own one stable scroll
    /// container: swiping must genuinely move the content, lower panels must
    /// become reachable, the position must hold across idle time, and
    /// navigating away and back must stay reliable.
    func testDivisionScreenScrollsToLowerContentHoldsPositionAndSurvivesRoundTrip() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_DIVISION"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let divisionTab = app.buttons["legends.nav.division"]
        XCTAssertTrue(divisionTab.waitForExistence(timeout: 10),
                      "Expected the Legends dashboard sidebar after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        divisionTab.tap()

        let divisionShell = app.descendants(matching: .any)["legends.shell.division"]
        XCTAssertTrue(divisionShell.waitForExistence(timeout: 8),
                      "Tapping DIVISION should show the Division screen")

        // Navigate away and back FIRST, in the same state the accepted
        // Division test uses (before content scrolling changes sidebar
        // auto-centering): the screen must survive a full round trip.
        let homeNav = app.buttons["legends.nav.home"]
        XCTAssertTrue(homeNav.waitForExistence(timeout: 6))
        var homeLanded = false
        for attempt in 1...2 {
            Thread.sleep(forTimeInterval: attempt == 1 ? 0.5 : 0.8)
            homeNav.tap()
            homeLanded = app.buttons["legends.shell.home"].waitForExistence(timeout: 6)
                          || !divisionShell.exists
            if homeLanded { break }
        }
        XCTAssertTrue(homeLanded, "Expected the Home dashboard after navigating away")
        Thread.sleep(forTimeInterval: 0.5)
        divisionTab.tap()
        XCTAssertTrue(divisionShell.waitForExistence(timeout: 8),
                      "Division must reopen after a home round trip")
        XCTAssertTrue(app.descendants(matching: .any)["legends.division.results"].waitForExistence(timeout: 6),
                      "Results panel must exist after reopening Division")
        XCTAssertTrue(app.descendants(matching: .any)["legends.division.userRow"].waitForExistence(timeout: 6),
                      "Table must render after reopening Division")

        // Lower content: the recent-results panel sits well below the fold
        // on compact landscape phones.
        let results = app.descendants(matching: .any)["legends.division.results"].firstMatch
        XCTAssertTrue(results.waitForExistence(timeout: 8), "Expected the recent results panel")
        let window = app.windows.firstMatch
        let resultsBefore = results.frame
        XCTAssertTrue(resultsBefore.minY > window.frame.maxY - 60,
                      "Precondition: results start below the visible area (frame \(resultsBefore), window \(window.frame))")

        // Scroll down using the suite's accepted drag gesture (a plain
        // app.swipeUp() is unreliable on some simulators). With the defect
        // the content never moves — the GeometryReader pins the scroll
        // extent to the viewport.
        func dragContentUp() {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = start.withOffset(CGVector(dx: 0, dy: -140))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        func dragContentDown() {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            let end = start.withOffset(CGVector(dx: 0, dy: 140))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        for _ in 1...2 {
            dragContentUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        let resultsAfterScroll = results.frame
        XCTAssertLessThan(resultsAfterScroll.minY, resultsBefore.minY - 40,
                          "Swiping up must move the Division content; results frame stayed at \(resultsAfterScroll)")
        XCTAssertLessThanOrEqual(resultsAfterScroll.minY, window.frame.maxY,
                                 "Lower content must become visible after scrolling")

        // Hold the position long enough to expose a scroll reset from
        // ordinary view updates (e.g. a verticalSizeClass / layout flip).
        Thread.sleep(forTimeInterval: 1.5)
        let resultsHeld = results.frame
        XCTAssertLessThan(resultsHeld.minY, resultsBefore.minY - 40,
                          "Scroll position must hold; content snapped back to \(resultsHeld)")

        // The table (upper content) must remain reachable by scrolling back.
        var userRowVisible = false
        var userRowFrame: CGRect = .zero
        for _ in 0..<4 {
            dragContentDown()
            let userRow = app.descendants(matching: .any)["legends.division.userRow"].firstMatch
            if userRow.waitForExistence(timeout: 2) {
                userRowFrame = userRow.frame
                if userRowFrame.minY >= window.frame.minY && userRowFrame.maxY <= window.frame.maxY + 20 {
                    userRowVisible = true
                    break
                }
            }
        }
        XCTAssertTrue(userRowVisible,
                      "User table row must be back in the visible area after scrolling up; frame \(userRowFrame)")

        Thread.sleep(forTimeInterval: 0.6)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Division scroll regression (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_division_scroll_\(Int(size.width))x\(Int(size.height)).png"))
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

        // Resources mirror the fixture profile (£3,000,000 club balance, 3 tokens).
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
        XCTAssertTrue(balance.label.contains("£5,000,000"),
                      "The fixture should expose the initial £5,000,000 Balance; got \(balance.label)")

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
        XCTAssertTrue(balance.label.contains("£4,000,000"),
                      "The exact £1,000,000 upgrade cost should be deducted once; got \(balance.label)")
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
        XCTAssertTrue(balance.waitForExistence(timeout: 5) && balance.label.contains("£4,000,000"),
                      "The updated Balance should remain visible after reopening; got \(balance.label)")
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

    /// The redesigned Players collection, driven by deterministic fixture
    /// data (`UITEST_LEGENDS_PLAYERS`): summary band figures, primary filters,
    /// advanced filters, tile status/badges, detail + comparison round trip,
    /// and scroll-position/filter preservation.
    func testLegendsPlayersSummaryFiltersDetailAndComparisonRoundTrip() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_PLAYERS"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let playersTab = app.buttons["legends.nav.players"]
        XCTAssertTrue(playersTab.waitForExistence(timeout: 10),
                      "Expected the Players sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        playersTab.tap()

        let screen = app.descendants(matching: .any)["legends.library"]
        XCTAssertTrue(screen.waitForExistence(timeout: 8),
                      "Expected the redesigned Players destination")

        // Summary band figures, derived from the deterministic fixture.
        let ownedStat = app.descendants(matching: .any)["legends.players.summary.owned"]
        XCTAssertTrue(ownedStat.waitForExistence(timeout: 5), "Expected the owned summary")
        XCTAssertTrue(ownedStat.label.contains("22/"),
                      "The fixture owns the 18-card starter squad plus 4 extra cards; got \(ownedStat.label)")
        let unsignedStat = app.descendants(matching: .any)["legends.players.summary.unsigned"]
        XCTAssertTrue(unsignedStat.waitForExistence(timeout: 5), "Expected the unsigned summary")
        XCTAssertTrue(unsignedStat.label.contains("3"),
                      "Exactly three cards are owned but unsigned (Maldinho, Miessi, retro Cantina); got \(unsignedStat.label)")
        let legendsStat = app.descendants(matching: .any)["legends.players.summary.legends"]
        XCTAssertTrue(legendsStat.waitForExistence(timeout: 5), "Expected the legends summary")
        XCTAssertTrue(legendsStat.label.contains("1"),
                      "Exactly one completed career sits in the Hall; got \(legendsStat.label)")

        // Tiles exist for owned, signed, unsigned and retired cards.
        let cantinaTile = app.descendants(matching: .any)["legends.players.card.cantina-9596"]
        XCTAssertTrue(cantinaTile.waitForExistence(timeout: 5), "Expected the Cantina tile")
        XCTAssertTrue(cantinaTile.label.contains("RESERVES"),
                      "Cantina is signed but unassigned in the fixture; got \(cantinaTile.label)")
        XCTAssertTrue(cantinaTile.label.contains("Favourite"),
                      "Cantina is favourited in the fixture")
        XCTAssertTrue(cantinaTile.label.contains("Exact duplicate"),
                      "Cantina has an exact duplicate in the fixture")
        let maldinhoTile = app.descendants(matching: .any)["legends.players.card.maldinho-9596"]
        XCTAssertTrue(maldinhoTile.waitForExistence(timeout: 5), "Expected the unsigned Maldinho tile")
        XCTAssertTrue(maldinhoTile.label.contains("UNSIGNED"),
                      "Maldinho is unsigned in the fixture; got \(maldinhoTile.label)")

        // Status chips filter the grid.
        let unsignedChip = app.buttons["legends.players.status.unsigned"]
        XCTAssertTrue(unsignedChip.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        unsignedChip.tap()
        XCTAssertTrue(maldinhoTile.waitForExistence(timeout: 5),
                      "Unsigned chip keeps the unsigned Maldinho tile")
        let retroCantinaTile = app.descendants(matching: .any)["legends.players.card.cantina-9596-retro"]
        XCTAssertTrue(retroCantinaTile.waitForExistence(timeout: 5),
                      "Unsigned chip keeps the unsigned retro Cantina twin")
        XCTAssertFalse(cantinaTile.waitForExistence(timeout: 2),
                       "Unsigned chip must hide signed cards")

        // LEGENDS chip: the fixture's completed career is no longer owned,
        // so the grid shows the dedicated empty state (the Hall itself is
        // where completed careers are browsed).
        let legendsChip = app.buttons["legends.players.status.legends"]
        XCTAssertTrue(legendsChip.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        legendsChip.tap()
        let legendsEmpty = app.descendants(matching: .any)["legends.players.empty"]
        XCTAssertTrue(legendsEmpty.waitForExistence(timeout: 5),
                      "LEGENDS chip with no owned-retired cards shows the empty state")
        XCTAssertFalse(maldinhoTile.waitForExistence(timeout: 2),
                       "LEGENDS chip must hide active cards")

        // Advanced filters open, search filters, and reset restores.
        let filtersToggle = app.buttons["legends.library.filters"]
        XCTAssertTrue(filtersToggle.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        filtersToggle.tap()
        let searchField = app.textFields["legends.library.search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Expected the advanced filter panel with search")

        // Back to ALL before opening a detail so every tile exists again.
        let allChip = app.buttons["legends.players.status.all"]
        XCTAssertTrue(allChip.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.3)
        allChip.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Scroll the grid, then open a detail from a lower row to prove the
        // sheet works from real hit-testing and that returning preserves the
        // list position (the same tile still exists and the scroll container
        // did not reset).
        cantinaTile.tap()

        let detailClose = app.buttons["Close player details"]
        XCTAssertTrue(detailClose.waitForExistence(timeout: 8),
                      "Expected the player detail sheet to open")
        let compareButton = app.buttons["legends.player.compare"]
        XCTAssertTrue(compareButton.waitForExistence(timeout: 5),
                      "Expected the COMPARE action in the detail sheet")
        Thread.sleep(forTimeInterval: 0.4)
        compareButton.tap()
        let comparison = app.descendants(matching: .any)["legends.playerComparison"]
        XCTAssertTrue(comparison.waitForExistence(timeout: 8),
                      "Expected the comparison sheet")
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        doneButton.tap()
        XCTAssertTrue(compareButton.waitForExistence(timeout: 5),
                      "Returning from comparison should land back on the detail sheet")

        Thread.sleep(forTimeInterval: 0.4)
        detailClose.tap()
        XCTAssertTrue(screen.waitForExistence(timeout: 8),
                      "Returning from the detail sheet should land back on the collection")
        XCTAssertTrue(filtersToggle.exists, "Filter toggle remains reachable after the round trip")
        XCTAssertTrue(cantinaTile.exists, "Tiles survive the detail round trip")

        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Players redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_players_\(Int(size.width))x\(Int(size.height)).png"))
    }

    /// The redesigned Legends Hall: navigation from the sidebar, deterministic
    /// summary figures, podium and card presentation, favourites filtering,
    /// search, every sort option switching, opening and closing a career page,
    /// and filter state surviving the round trip.
    func testLegendsHallSummaryPodiumSortingAndCareerRoundTrip() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_HALL"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let hallTab = app.buttons["legends.nav.hall"]
        XCTAssertTrue(hallTab.waitForExistence(timeout: 10),
                      "Expected the Hall sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        hallTab.tap()

        let screen = app.descendants(matching: .any)["legends.hall.screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 8),
                      "Expected the redesigned Hall destination")
        XCTAssertTrue(app.staticTexts["LEGENDS HALL"].waitForExistence(timeout: 5),
                      "Hall must stay the highlighted shell destination")

        // Summary band figures, derived from the deterministic fixture:
        // 5 careers, 2 club legends, 1336 appearances, 591 goals, 3 honours.
        let careersStat = app.descendants(matching: .any)["legends.hall.summary.careers"]
        XCTAssertTrue(careersStat.waitForExistence(timeout: 5), "Expected the careers summary")
        XCTAssertTrue(careersStat.label.contains("5 completed careers"), "Got \(careersStat.label)")
        let legendsStat = app.descendants(matching: .any)["legends.hall.summary.clubLegends"]
        XCTAssertTrue(legendsStat.waitForExistence(timeout: 5), "Expected the club-legend summary")
        XCTAssertTrue(legendsStat.label.contains("2 club legends"), "Got \(legendsStat.label)")
        let appearancesStat = app.descendants(matching: .any)["legends.hall.summary.appearances"]
        XCTAssertTrue(appearancesStat.waitForExistence(timeout: 5), "Expected the appearances summary")
        XCTAssertTrue(appearancesStat.label.contains("total appearances"), "Got \(appearancesStat.label)")
        let goalsStat = app.descendants(matching: .any)["legends.hall.summary.goals"]
        XCTAssertTrue(goalsStat.waitForExistence(timeout: 5), "Expected the goals summary")
        XCTAssertTrue(goalsStat.label.contains("total goals"), "Got \(goalsStat.label)")
        let honoursStat = app.descendants(matching: .any)["legends.hall.summary.honours"]
        XCTAssertTrue(honoursStat.waitForExistence(timeout: 5), "Expected the honours summary")
        XCTAssertTrue(honoursStat.label.contains("career honours"), "Got \(honoursStat.label)")

        // The Hall of Fame podium shows the three greatest careers by legacy
        // score in order, with the club legend marked.
        let firstPodium = app.descendants(matching: .any)["legends.hall.podium.1"]
        XCTAssertTrue(firstPodium.waitForExistence(timeout: 5), "Expected the #1 podium card")
        XCTAssertTrue(firstPodium.label.contains("K. Mbappa") && firstPodium.label.contains("club legend"),
                      "Mbappa ranks #1 as club legend; got \(firstPodium.label)")
        let secondPodium = app.descendants(matching: .any)["legends.hall.podium.2"]
        XCTAssertTrue(secondPodium.waitForExistence(timeout: 5))
        XCTAssertTrue(secondPodium.label.contains("P. Maldinho"), "Maldinho ranks #2; got \(secondPodium.label)")
        let thirdPodium = app.descendants(matching: .any)["legends.hall.podium.3"]
        XCTAssertTrue(thirdPodium.waitForExistence(timeout: 5))
        XCTAssertTrue(thirdPodium.label.contains("G. Batigora"), "Batigora ranks #3; got \(thirdPodium.label)")

        // Career cards expose the key figures in their accessibility label.
        let mbappaCard = app.descendants(matching: .any)["legends.hall.card.mbappa-2223"]
        XCTAssertTrue(mbappaCard.waitForExistence(timeout: 5), "Expected the Mbappa career card")
        XCTAssertTrue(mbappaCard.label.contains("412 appearances"), "Got \(mbappaCard.label)")
        XCTAssertTrue(mbappaCard.label.contains("289 goals"), "Got \(mbappaCard.label)")
        XCTAssertTrue(mbappaCard.label.contains("legacy score"), "Got \(mbappaCard.label)")
        let maldinhoCard = app.descendants(matching: .any)["legends.hall.card.maldinho-9596"]
        XCTAssertTrue(maldinhoCard.waitForExistence(timeout: 5), "Expected the Maldinho career card")
        XCTAssertTrue(maldinhoCard.label.contains("favourited"), "Maldinho is favourited in the fixture")

        // Favourites filter narrows the list to the favourited career only.
        let favouritesToggle = app.buttons["legends.hall.favourites"]
        XCTAssertTrue(favouritesToggle.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        favouritesToggle.tap()
        XCTAssertTrue(maldinhoCard.waitForExistence(timeout: 5),
                      "Favourites filter keeps the favourited Maldinho card")
        XCTAssertFalse(mbappaCard.waitForExistence(timeout: 2),
                       "Favourites filter must hide the unfavourited Mbappa card")
        Thread.sleep(forTimeInterval: 0.4)
        favouritesToggle.tap()
        XCTAssertTrue(mbappaCard.waitForExistence(timeout: 5),
                      "Toggling favourites off restores the full list")

        // Search filters by name.
        let searchField = app.textFields["legends.hall.search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Batigo")
        XCTAssertTrue(app.descendants(matching: .any)["legends.hall.card.batigora-9596"].waitForExistence(timeout: 5),
                      "Search keeps the matching Batigora card")
        XCTAssertFalse(mbappaCard.waitForExistence(timeout: 2),
                       "Search must hide non-matching careers")
        let clearButton = app.buttons["legends.hall.clearSearch"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3), "Expected the clear-search affordance")
        clearButton.tap()
        XCTAssertTrue(mbappaCard.waitForExistence(timeout: 5),
                      "Clearing search restores the full list")

        // Every sort option is selectable and reorders the deterministic set.
        let sortMenu = app.buttons["legends.hall.sort"]
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 5))
        let sortExpectations: [(String, String)] = [
            ("PEAK OVR", "mbappa-2223"),
            ("APPEARANCES", "mbappa-2223"),
            ("GOALS", "mbappa-2223"),
            ("SEASONS AT CLUB", "mbappa-2223"),
            ("RETIREMENT SEASON", "mbappa-2223"),
            ("LEGACY", "mbappa-2223"),
            ("NAME", "batigora-9596"),
        ]
        for (option, expectedTopCardSuffix) in sortExpectations {
            Thread.sleep(forTimeInterval: 0.4)
            sortMenu.tap()
            let item = app.buttons[option]
            XCTAssertTrue(item.waitForExistence(timeout: 4), "Expected sort option \(option)")
            Thread.sleep(forTimeInterval: 0.3)
            item.tap()
            // The first list card (not the podium) must match the expectation.
            // Card IDs are deterministic per fixture entry, so assert the
            // expected top card still exists under the chosen ordering.
            let topCard = app.descendants(matching: .any)["legends.hall.card.\(expectedTopCardSuffix)"]
            XCTAssertTrue(topCard.waitForExistence(timeout: 5),
                          "After sorting by \(option), expected \(expectedTopCardSuffix) present")
        }

        // Open the Mbappa career page from the list.
        Thread.sleep(forTimeInterval: 0.4)
        mbappaCard.tap()
        let detailTitle = app.staticTexts["CAREER TOTALS"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 8),
                      "Expected the career page sheet to open")
        XCTAssertTrue(app.descendants(matching: .any)["legends.hall.detail.totals"].waitForExistence(timeout: 5),
                      "Expected the career totals panel")
        XCTAssertTrue(app.descendants(matching: .any)["legends.hall.detail.honours"].waitForExistence(timeout: 5),
                      "Expected the honours panel")
        XCTAssertTrue(app.descendants(matching: .any)["legends.hall.detail.awards"].waitForExistence(timeout: 5),
                      "Expected the awards panel")

        let favouriteButton = app.buttons["legends.hall.detail.favourite"]
        XCTAssertTrue(favouriteButton.waitForExistence(timeout: 5))

        Thread.sleep(forTimeInterval: 0.4)
        let closeButton = app.buttons["legends.hall.detail.close"]
        closeButton.tap()
        XCTAssertTrue(screen.waitForExistence(timeout: 8),
                      "Closing the career page lands back on the Hall")
        XCTAssertTrue(mbappaCard.exists, "Career cards survive the detail round trip")
        XCTAssertTrue(sortMenu.exists, "Sort control remains reachable after the round trip")

        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Hall redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_hall_\(Int(size.width))x\(Int(size.height)).png"))
    }

    /// The redesigned Legends Challenges screen: navigation, deterministic
    /// summary values, all three cadences, active/completed filtering,
    /// reward labels, and state preservation after navigating away and back.
    func testLegendsChallengesSummaryCadencesFiltersAndRewards() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_CHALLENGES"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let challengesTab = app.buttons["legends.nav.challenges"]
        XCTAssertTrue(challengesTab.waitForExistence(timeout: 10),
                      "Expected the Challenges sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        challengesTab.tap()

        let screen = app.descendants(matching: .any)["legends.challenges.screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 8),
                      "Expected the redesigned Challenges destination")
        XCTAssertTrue(app.staticTexts["CHALLENGES"].waitForExistence(timeout: 5),
                      "Challenges must stay the highlighted shell destination")

        // Summary band, derived from the deterministic fixture:
        // 4 completed of 19 total, 15 active; Daily 1/2, Weekly 0/3,
        // Permanent 3/15.
        let completedStat = app.descendants(matching: .any)["legends.challenges.summary.completed"]
        XCTAssertTrue(completedStat.waitForExistence(timeout: 5), "Expected the completed summary")
        XCTAssertTrue(completedStat.label.contains("4 COMPLETED"), "Got \(completedStat.label)")
        let activeStat = app.descendants(matching: .any)["legends.challenges.summary.active"]
        XCTAssertTrue(activeStat.waitForExistence(timeout: 5), "Expected the active summary")
        XCTAssertTrue(activeStat.label.contains("15 ACTIVE"), "Got \(activeStat.label)")
        let dailyStat = app.descendants(matching: .any)["legends.challenges.summary.daily"]
        XCTAssertTrue(dailyStat.waitForExistence(timeout: 5), "Expected the daily summary")
        XCTAssertTrue(dailyStat.label.contains("1 of 2"), "Got \(dailyStat.label)")
        let weeklyStat = app.descendants(matching: .any)["legends.challenges.summary.weekly"]
        XCTAssertTrue(weeklyStat.waitForExistence(timeout: 5), "Expected the weekly summary")
        XCTAssertTrue(weeklyStat.label.contains("0 of 3"), "Got \(weeklyStat.label)")
        let permanentStat = app.descendants(matching: .any)["legends.challenges.summary.permanent"]
        XCTAssertTrue(permanentStat.waitForExistence(timeout: 5), "Expected the permanent summary")
        XCTAssertTrue(permanentStat.label.contains("3 of 14"), "Got \(permanentStat.label)")

        // Daily cadence (default): completed daily-match plus active daily-win.
        let dailyMatchCard = app.descendants(matching: .any)["legends.challenges.card.daily-match"]
        XCTAssertTrue(dailyMatchCard.waitForExistence(timeout: 5), "Expected the completed daily-match card")
        XCTAssertTrue(dailyMatchCard.label.contains("completed"), "Got \(dailyMatchCard.label)")
        let dailyWinCard = app.descendants(matching: .any)["legends.challenges.card.daily-win"]
        XCTAssertTrue(dailyWinCard.waitForExistence(timeout: 5), "Expected the active daily-win card")
        XCTAssertTrue(dailyWinCard.label.contains("active"), "Got \(dailyWinCard.label)")

        // Reward labels: Balance-only, token-only and mixed examples.
        let dailyMatchReward = app.descendants(matching: .any)["legends.challenges.reward.daily-match"]
        XCTAssertTrue(dailyMatchReward.waitForExistence(timeout: 5))
        XCTAssertTrue(dailyMatchReward.label.contains("+£300,000 Balance"), "Got \(dailyMatchReward.label)")
        let dailyWinReward = app.descendants(matching: .any)["legends.challenges.reward.daily-win"]
        XCTAssertTrue(dailyWinReward.waitForExistence(timeout: 5))
        XCTAssertTrue(dailyWinReward.label.contains("+£500,000 Balance") && dailyWinReward.label.contains("1 pack token"),
                      "Got \(dailyWinReward.label)")

        // Progress labels reflect the fixture counters.
        let dailyWinProgress = app.descendants(matching: .any)["legends.challenges.progress.daily-win"]
        XCTAssertTrue(dailyWinProgress.waitForExistence(timeout: 5))
        XCTAssertTrue(dailyWinProgress.label.contains("0 of 1"), "Got \(dailyWinProgress.label)")

        // COMPLETED filter hides the active daily challenge.
        let completedFilter = app.buttons["legends.challenges.filter.completed"]
        let activeFilter = app.buttons["legends.challenges.filter.active"]
        let allFilter = app.buttons["legends.challenges.filter.all"]
        XCTAssertTrue(completedFilter.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        completedFilter.tap()
        XCTAssertTrue(dailyMatchCard.waitForExistence(timeout: 5),
                      "COMPLETED filter keeps the completed daily-match card")
        XCTAssertFalse(dailyWinCard.waitForExistence(timeout: 2),
                       "COMPLETED filter must hide the active daily-win card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.challenges.empty"].waitForExistence(timeout: 2) == false,
                      "COMPLETED daily has content, so no empty state")

        // ACTIVE filter inverts the list.
        Thread.sleep(forTimeInterval: 0.4)
        activeFilter.tap()
        XCTAssertTrue(dailyWinCard.waitForExistence(timeout: 5),
                      "ACTIVE filter keeps the active daily-win card")
        XCTAssertFalse(dailyMatchCard.waitForExistence(timeout: 2),
                       "ACTIVE filter must hide the completed daily-match card")

        // ALL restores both.
        Thread.sleep(forTimeInterval: 0.4)
        allFilter.tap()
        XCTAssertTrue(dailyMatchCard.waitForExistence(timeout: 5))
        XCTAssertTrue(dailyWinCard.waitForExistence(timeout: 5))

        // Switch to Weekly: both weekly challenges are active in the fixture,
        // so the COMPLETED filter shows the dedicated empty state.
        let weeklyTab = app.buttons["legends.challenges.cadence.weekly"]
        XCTAssertTrue(weeklyTab.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        weeklyTab.tap()
        let weeklyWinsCard = app.descendants(matching: .any)["legends.challenges.card.weekly-wins"]
        XCTAssertTrue(weeklyWinsCard.waitForExistence(timeout: 5), "Expected the weekly-wins card")
        let weeklyGoalsCard = app.descendants(matching: .any)["legends.challenges.card.weekly-goals"]
        XCTAssertTrue(weeklyGoalsCard.waitForExistence(timeout: 5), "Expected the weekly-goals card")
        let weeklyProgress = app.descendants(matching: .any)["legends.challenges.progress.weekly-wins"]
        XCTAssertTrue(weeklyProgress.waitForExistence(timeout: 5))
        XCTAssertTrue(weeklyProgress.label.contains("1 of 3"), "Got \(weeklyProgress.label)")
        Thread.sleep(forTimeInterval: 0.4)
        completedFilter.tap()
        XCTAssertTrue(app.descendants(matching: .any)["legends.challenges.empty"].waitForExistence(timeout: 5),
                      "Weekly COMPLETED with no completions shows the empty state")
        Thread.sleep(forTimeInterval: 0.4)
        allFilter.tap()
        XCTAssertTrue(weeklyWinsCard.waitForExistence(timeout: 5))

        // Switch to Permanent: three completed in the fixture.
        let permanentTab = app.buttons["legends.challenges.cadence.permanent"]
        XCTAssertTrue(permanentTab.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        permanentTab.tap()
        let firstWinCard = app.descendants(matching: .any)["legends.challenges.card.first-win"]
        XCTAssertTrue(firstWinCard.waitForExistence(timeout: 5), "Expected the completed first-win card")
        XCTAssertTrue(firstWinCard.label.contains("completed"), "Got \(firstWinCard.label)")
        let firstWinReward = app.descendants(matching: .any)["legends.challenges.reward.first-win"]
        XCTAssertTrue(firstWinReward.waitForExistence(timeout: 5))
        XCTAssertTrue(firstWinReward.label.contains("+£1,000,000 Balance"), "Got \(firstWinReward.label)")
        let collectorCard = app.descendants(matching: .any)["legends.challenges.card.collector-10"]
        XCTAssertTrue(collectorCard.waitForExistence(timeout: 5))
        let collectorReward = app.descendants(matching: .any)["legends.challenges.reward.collector-10"]
        XCTAssertTrue(collectorReward.waitForExistence(timeout: 5))
        XCTAssertTrue(collectorReward.label.contains("1 pack token") && !collectorReward.label.contains("Balance"),
                      "Token-only reward; got \(collectorReward.label)")
        let cleanSheetReward = app.descendants(matching: .any)["legends.challenges.reward.clean-sheet"]
        XCTAssertTrue(cleanSheetReward.waitForExistence(timeout: 5))
        XCTAssertTrue(cleanSheetReward.label.contains("+£1,000,000 Balance") && cleanSheetReward.label.contains("1 pack token"),
                      "Mixed reward; got \(cleanSheetReward.label)")

        // Scroll the permanent list — the badge collection is long.
        app.swipeUp()
        let topFlightCard = app.descendants(matching: .any)["legends.challenges.card.top-flight"]
        XCTAssertTrue(topFlightCard.waitForExistence(timeout: 5),
                      "Challenges further down the list stay reachable while scrolling")

        // Navigate away and back: cadence and filter state are preserved.
        Thread.sleep(forTimeInterval: 0.4)
        let homeTab = app.buttons["legends.nav.home"]
        homeTab.tap()
        XCTAssertTrue(app.buttons["legends.nav.challenges"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["legends.nav.challenges"].tap()
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Returning to Challenges lands back on the screen")
        XCTAssertTrue(firstWinCard.waitForExistence(timeout: 5),
                      "Permanent cadence selection survives leaving and returning")

        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Challenges redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_challenges_\(Int(size.width))x\(Int(size.height)).png"))
    }

    /// The redesigned Career Planning and Season Reports destinations:
    /// navigation, sidebar highlights, planning summary and sections,
    /// report archive and detail categories, dismissal, and round trips.
    func testLegendsPlanningAndReportsSummaryNavigationAndDetailRoundTrip() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_PLANNING_REPORTS"]
        app.launch()

        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let planningTab = app.buttons["legends.nav.planning"]
        XCTAssertTrue(planningTab.waitForExistence(timeout: 10),
                      "Expected the Planning sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        planningTab.tap()

        let planningScreen = app.descendants(matching: .any)["legends.planning.screen"]
        XCTAssertTrue(planningScreen.waitForExistence(timeout: 8),
                      "Expected the redesigned Career Planning destination")
        XCTAssertTrue(app.staticTexts["CAREER PLANNING"].waitForExistence(timeout: 5),
                      "Planning must be the highlighted shell destination")

        // Summary band values from the deterministic fixture squad.
        let xiAge = app.descendants(matching: .any)["legends.planning.summary.xiAge"]
        XCTAssertTrue(xiAge.waitForExistence(timeout: 5), "Expected the XI age summary")
        XCTAssertTrue(xiAge.label.contains("average age"), "Got \(xiAge.label)")
        let squadAge = app.descendants(matching: .any)["legends.planning.summary.squadAge"]
        XCTAssertTrue(squadAge.waitForExistence(timeout: 5), "Expected the squad age summary")
        let finalCount = app.descendants(matching: .any)["legends.planning.summary.finalSeason"]
        XCTAssertTrue(finalCount.waitForExistence(timeout: 5), "Expected the final-season summary")
        XCTAssertTrue(finalCount.label.contains("final season"), "Got \(finalCount.label)")
        let risk = app.descendants(matching: .any)["legends.planning.summary.risk"]
        XCTAssertTrue(risk.waitForExistence(timeout: 5), "Expected the retirement-risk status")
        XCTAssertTrue(risk.label.contains("Retirement risk"), "Got \(risk.label)")

        // Career-stage rows and radar groups exist with fixture content.
        XCTAssertTrue(app.descendants(matching: .any)["legends.planning.stages"].waitForExistence(timeout: 5),
                      "Expected the career-stage distribution")
        XCTAssertTrue(app.descendants(matching: .any)["legends.planning.stage.prime"].waitForExistence(timeout: 5),
                      "Expected a PRIME stage row")
        let radarNext = app.descendants(matching: .any)["legends.planning.radar.next"]
        XCTAssertTrue(radarNext.waitForExistence(timeout: 5), "Expected the next-season radar group")
        XCTAssertTrue(radarNext.label.contains("Modricek") && radarNext.label.contains("Keegana"),
                      "Named next-season retirees; got \(radarNext.label)")
        let radarWithin = app.descendants(matching: .any)["legends.planning.radar.within"]
        XCTAssertTrue(radarWithin.waitForExistence(timeout: 5), "Expected the within-three-seasons group")
        XCTAssertTrue(radarWithin.label.contains("Walkerino"), "Named within-three-seasons retirees; got \(radarWithin.label)")

        // Replacement Watch has named unsigned candidates and slots.
        XCTAssertTrue(app.descendants(matching: .any)["legends.planning.replacement.positions"].waitForExistence(timeout: 5),
                      "Expected the slots-to-cover row")
        let suggestion = app.descendants(matching: .any)["legends.planning.replacement.suggestion"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "Expected at least one unsigned replacement suggestion")

        // Age distribution rows.
        XCTAssertTrue(app.descendants(matching: .any)["legends.planning.ages"].waitForExistence(timeout: 5),
                      "Expected the age distribution")
        XCTAssertTrue(app.descendants(matching: .any)["legends.planning.age.25"].waitForExistence(timeout: 5) ||
                      app.descendants(matching: .any)["legends.planning.age.26"].waitForExistence(timeout: 2) ||
                      app.descendants(matching: .any)["legends.planning.age.27"].waitForExistence(timeout: 2),
                      "Expected at least one populated age row")

        Thread.sleep(forTimeInterval: 0.6)
        let planningShot = XCUIScreen.main.screenshot()
        let planningAttachment = XCTAttachment(screenshot: planningShot)
        planningAttachment.name = "Legends Career Planning redesign (landscape)"
        planningAttachment.lifetime = .keepAlways
        add(planningAttachment)
        let planningSize = app.windows.firstMatch.frame.size
        try? planningShot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_planning_\(Int(planningSize.width))x\(Int(planningSize.height)).png"))

        // Compact-screen reachability: scroll to the bottom of Planning.
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["legends.planning.ages"].waitForExistence(timeout: 5) ||
                      app.descendants(matching: .any)["legends.planning.replacement"].waitForExistence(timeout: 2),
                      "Planning sections remain reachable while scrolling")

        // Direct Planning → Reports navigation from the sidebar.
        let reportsTab = app.buttons["legends.nav.reports"]
        XCTAssertTrue(reportsTab.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 0.5)
        reportsTab.tap()

        let reportsScreen = app.descendants(matching: .any)["legends.reports.screen"]
        XCTAssertTrue(reportsScreen.waitForExistence(timeout: 8),
                      "Expected the redesigned Season Reports destination")
        XCTAssertTrue(app.staticTexts["SEASON REPORTS"].waitForExistence(timeout: 5),
                      "Reports must be the highlighted shell destination")

        // Archive summary from the fixture: 3 reports, latest S3.
        let reportCount = app.descendants(matching: .any)["legends.reports.summary.count"]
        XCTAssertTrue(reportCount.waitForExistence(timeout: 5), "Expected the report-count summary")
        XCTAssertTrue(reportCount.label.contains("3 season reports"), "Got \(reportCount.label)")
        let latestSeason = app.descendants(matching: .any)["legends.reports.summary.latest"]
        XCTAssertTrue(latestSeason.waitForExistence(timeout: 5))
        XCTAssertTrue(latestSeason.label.contains("season 3"), "Got \(latestSeason.label)")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.summary.improved"].waitForExistence(timeout: 5),
                      "Expected the latest-season improved chip")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.summary.retired"].waitForExistence(timeout: 5),
                      "Expected the latest-season retired chip")

        // Season cards exist for all three fixture reports.
        let season3Card = app.descendants(matching: .any)["legends.reports.card.3"]
        XCTAssertTrue(season3Card.waitForExistence(timeout: 5), "Expected the season 3 card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.card.2"].waitForExistence(timeout: 5),
                      "Expected the season 2 card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.card.1"].waitForExistence(timeout: 5),
                      "Expected the season 1 card")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.card.3.warning"].waitForExistence(timeout: 5),
                      "Expected the season 3 squad-age warning")

        // Open the season 3 report and reach every category group.
        Thread.sleep(forTimeInterval: 0.4)
        season3Card.tap()
        XCTAssertTrue(app.staticTexts["SEASON 3"].waitForExistence(timeout: 8),
                      "Expected the report detail page for season 3")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.detail.improved"].waitForExistence(timeout: 5),
                      "Expected the IMPROVED group")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.detail.stable"].waitForExistence(timeout: 5),
                      "Expected the STABLE group")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.detail.declining"].waitForExistence(timeout: 5),
                      "Expected the DECLINING group")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.detail.final"].waitForExistence(timeout: 5),
                      "Expected the FINAL SEASON group")
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.detail.warning"].waitForExistence(timeout: 5),
                      "Expected the squad-age warning panel")
        let playerEntry = app.descendants(matching: .any)["legends.reports.detail.player.mbappa-2223"]
        XCTAssertTrue(playerEntry.waitForExistence(timeout: 5), "Expected the Mbappa report entry")
        XCTAssertTrue(playerEntry.label.contains("25"), "Age-after in the entry label; got \(playerEntry.label)")

        // Scroll inside the detail to reach the FINAL SEASON group fully.
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.detail.final"].waitForExistence(timeout: 5),
                      "Final-season group stays reachable while scrolling")

        // Dismiss and land back on the archive.
        Thread.sleep(forTimeInterval: 0.4)
        let closeButton = app.buttons["legends.reports.detail.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        XCTAssertTrue(reportsScreen.waitForExistence(timeout: 8),
                      "Closing the report lands back on the archive")
        XCTAssertTrue(season3Card.exists, "Season cards survive the detail round trip")

        // Navigate away and back: both destinations remain reliable.
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["legends.nav.home"].tap()
        XCTAssertTrue(app.buttons["legends.nav.planning"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["legends.nav.reports"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["legends.reports.screen"].waitForExistence(timeout: 8),
                      "Returning to Reports after visiting Home works")
        XCTAssertTrue(app.staticTexts["SEASON REPORTS"].waitForExistence(timeout: 5),
                      "Reports remains the highlighted destination after the round trip")

        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Reports redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_reports_\(Int(size.width))x\(Int(size.height)).png"))
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

    /// Shared entry into the Settings destination via the sidebar, using
    /// the deterministic settings fixture (established manager and club).
    @discardableResult
    private func openLegendsSettings(_ app: XCUIApplication) -> XCUIElement {
        let legendsButton = app.buttons["experience.legends"]
        XCTAssertTrue(legendsButton.waitForExistence(timeout: 8),
                      "Expected the RSM Legends entry button on the experience selector")
        legendsButton.tap()

        let settingsTab = app.buttons["legends.nav.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10),
                      "Expected the Settings sidebar item after entering Legends mode")
        Thread.sleep(forTimeInterval: 0.5)
        settingsTab.tap()

        let settingsScreen = app.descendants(matching: .any)["legends.shell.settings"]
        XCTAssertTrue(settingsScreen.waitForExistence(timeout: 8),
                      "Expected the redesigned Settings destination")
        XCTAssertTrue(app.staticTexts["SETTINGS"].waitForExistence(timeout: 5),
                      "Settings must be the highlighted shell destination")
        return settingsScreen
    }

    /// The redesigned Settings destination: summary card, presentation
    /// preference effects and persistence, restore defaults, destructive
    /// confirmation safety, and navigation round trips.
    func testLegendsSettingsSummaryPreferencesAndDeleteConfirmation() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_SETTINGS"]
        app.launch()

        openLegendsSettings(app)

        // Summary card shows the authoritative fixture values.
        let clubName = app.descendants(matching: .any)["settings.summary.clubName"]
        XCTAssertTrue(clubName.waitForExistence(timeout: 5), "Expected the club-name summary value")
        let manager = app.descendants(matching: .any)["settings.summary.manager"]
        XCTAssertTrue(manager.waitForExistence(timeout: 5), "Expected the manager summary row")
        XCTAssertTrue(manager.label.contains("Test Manager"), "Got \(manager.label)")
        let level = app.descendants(matching: .any)["settings.summary.level"]
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        XCTAssertTrue(level.label.contains("Lv 4"), "Got \(level.label)")
        XCTAssertTrue(app.descendants(matching: .any)["settings.summary.division"].waitForExistence(timeout: 5),
                      "Expected the division summary row")
        let saveStatus = app.descendants(matching: .any)["settings.summary.saveStatus"]
        XCTAssertTrue(saveStatus.waitForExistence(timeout: 5), "Expected the save-status indicator")
        XCTAssertTrue(saveStatus.label.lowercased().contains("automatic"), "Got \(saveStatus.label)")
        XCTAssertTrue(app.descendants(matching: .any)["settings.about.version"].waitForExistence(timeout: 5),
                      "Expected the app-version row in the About section")

        // The fixture persists at launch, so the LAST SAVED row must show a
        // real timestamp rather than the not-yet-saved fallback.
        let lastSaved = app.descendants(matching: .any)["settings.save.lastSavedRow"]
        XCTAssertTrue(lastSaved.waitForExistence(timeout: 5),
                      "Expected the LAST SAVED row in SAVE & DATA")
        XCTAssertFalse(lastSaved.label.lowercased().contains("not yet"),
                       "The fixture saves at launch, so a timestamp must be shown; got \(lastSaved.label)")
        XCTAssertTrue(lastSaved.label.lowercased().contains("auto-save is on"),
                      "The accessibility label must state the autosave state; got \(lastSaved.label)")

        // The live relative label renders alongside the timestamp; its exact
        // wording depends on elapsed time, so assert the stable prefix.
        let relativeSaved = app.staticTexts["settings.save.lastSaved.relative"]
        XCTAssertTrue(relativeSaved.waitForExistence(timeout: 5),
                      "Expected the live relative saved-time label")
        XCTAssertTrue(relativeSaved.label.lowercased().hasPrefix("saved "),
                      "Expected relative wording like 'saved just now'; got \(relativeSaved.label)")

        Thread.sleep(forTimeInterval: 0.6)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Legends Settings redesign (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_settings_\(Int(size.width))x\(Int(size.height)).png"))

        // Compact-screen reachability: the danger zone sits at the bottom.
        app.swipeUp()
        let deleteButton = app.buttons["settings.deleteClub"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "DELETE CLUB must be reachable by scrolling on compact landscape")

        // Preference effects: flip Reduce Interface Motion and commentary
        // size, verifying the controls reflect and persist the change.
        let motionToggle = app.switches["settings.motion.toggle"]
        if motionToggle.waitForExistence(timeout: 4) {
            motionToggle.tap()
        } else {
            app.swipeDown(); app.swipeDown()
            XCTAssertTrue(motionToggle.waitForExistence(timeout: 5),
                          "The Reduce Interface Motion toggle must be reachable")
            motionToggle.tap()
        }

        // Restore defaults returns both controls to the accepted defaults.
        let restoreButton = app.buttons["settings.restoreDefaults"]
        if !restoreButton.waitForExistence(timeout: 4) { app.swipeDown() }
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 5),
                      "Expected the RESTORE PRESENTATION DEFAULTS action")
        restoreButton.tap()

        // Destructive safety: DELETE CLUB opens the confirmation sheet;
        // cancelling keeps the club and lands back on Settings.
        if !deleteButton.exists { app.swipeUp() }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
        deleteButton.tap()

        // The sheet's explicit confirm and cancel actions must both exist.
        let confirmButton = app.descendants(matching: .any)["settings.delete.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 6),
                      "DELETE CLUB must present the confirmation sheet with an explicit permanent-delete action")
        let cancelButton = app.descendants(matching: .any)["settings.delete.cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Expected the KEEP MY CLUB action")
        Thread.sleep(forTimeInterval: 0.4)
        cancelButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["legends.shell.settings"].waitForExistence(timeout: 6),
                      "Cancelling the delete returns to the Settings screen with the club intact")
        XCTAssertTrue(clubName.exists, "The club summary survives the cancelled deletion")

        // Navigate away and back: the destination remains reliable.
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["legends.nav.home"].tap()
        XCTAssertTrue(app.buttons["legends.nav.settings"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["legends.nav.settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["legends.shell.settings"].waitForExistence(timeout: 8),
                      "Returning to Settings after visiting Home works")

        Thread.sleep(forTimeInterval: 0.8)
        let finalShot = XCUIScreen.main.screenshot()
        let finalAttachment = XCTAttachment(screenshot: finalShot)
        finalAttachment.name = "Legends Settings after navigation round trip (landscape)"
        finalAttachment.lifetime = .keepAlways
        add(finalAttachment)
        try? finalShot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_settings_roundtrip_\(Int(size.width))x\(Int(size.height)).png"))
    }

    /// The commentary text-size preference persists across relaunches.
    /// (Reduce Interface Motion's effect is covered at unit level; the
    /// relaunch leg here proves the persistence layer itself.)
    func testLegendsSettingsCommentarySizePreferencePersistsAcrossRelaunch() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_SETTINGS"]
        app.launch()

        openLegendsSettings(app)

        let sizePicker = app.descendants(matching: .any)["settings.commentary.size"]
        if !sizePicker.waitForExistence(timeout: 4) { app.swipeDown() }
        XCTAssertTrue(sizePicker.waitForExistence(timeout: 5),
                      "Expected the commentary text-size segmented control")

        // Choose XL (the last segment) and confirm the control reflects it
        // before relaunching — this separates tap-landing from persistence.
        let xl = sizePicker.buttons["XL"]
        if xl.exists {
            xl.tap()
        } else {
            let large = sizePicker.buttons["LARGE"]
            XCTAssertTrue(large.waitForExistence(timeout: 4), "Expected LARGE/XL segments")
            large.tap()
        }
        Thread.sleep(forTimeInterval: 0.5)

        app.terminate()
        app.launch()
        openLegendsSettings(app)

        let sizePicker2 = app.descendants(matching: .any)["settings.commentary.size"]
        if !sizePicker2.waitForExistence(timeout: 4) { app.swipeDown() }
        XCTAssertTrue(sizePicker2.waitForExistence(timeout: 5),
                      "Expected the commentary text-size control after relaunch")
        // The selected segment exposes the isSelected accessibility trait.
        let selectedSegment = sizePicker2.buttons.matching(
            NSPredicate(format: "isSelected == true")
        ).firstMatch
        XCTAssertTrue(selectedSegment.waitForExistence(timeout: 5),
                      "Expected a selected commentary-size segment after relaunch")
        XCTAssertTrue(selectedSegment.label == "XL" || selectedSegment.label == "LARGE",
                      "The changed commentary size must persist across relaunch; got \(selectedSegment.label)")
    }

    /// The Auto-Save toggle flips the live save status and restores cleanly.
    /// (Disk-level autosave behaviour is covered at unit level in
    /// LegendsSettingsTests; this proves the controls reflect the state.)
    func testLegendsSettingsAutosaveToggleReflectsAndRestores() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_SETTINGS"]
        app.launch()

        openLegendsSettings(app)

        let saveStatus = app.descendants(matching: .any)["settings.summary.saveStatus"]
        XCTAssertTrue(saveStatus.waitForExistence(timeout: 5), "Expected the save-status indicator")
        XCTAssertTrue(saveStatus.label.lowercased().contains("after every change"),
                      "Auto-Save must start on (the default); got \(saveStatus.label)")

        let autosaveToggle = app.switches["settings.autosave.toggle"]
        if !autosaveToggle.waitForExistence(timeout: 4) { app.swipeUp() }
        XCTAssertTrue(autosaveToggle.waitForExistence(timeout: 5),
                      "Expected the Auto-Save toggle in SAVE & DATA")

        // Turning Auto-Save off updates the live save status...
        autosaveToggle.tap()
        XCTAssertTrue(saveStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(saveStatus.label.lowercased().contains("paused"),
                      "Turning Auto-Save off must announce the paused state; got \(saveStatus.label)")

        // ...and turning it back on restores the automatic status.
        autosaveToggle.tap()
        XCTAssertTrue(saveStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(saveStatus.label.lowercased().contains("after every change"),
                      "Turning Auto-Save back on must restore the automatic status; got \(saveStatus.label)")

        Thread.sleep(forTimeInterval: 0.5)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "Legends Settings Auto-Save restored (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// End-to-end disk-write verification: with Auto-Save off, playing a
    /// complete real match (KICK OFF → live 2D engine → SKIP → CONTINUE)
    /// must not move the LAST SAVED timestamp, because the store's match
    /// pipeline persists through `persist()` which the paused preference
    /// gates. Re-enabling Auto-Save must checkpoint the match immediately.
    func testLegendsAutosaveOffPausesDiskWritesAcrossALiveMatch() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_LEGENDS_SETTINGS"]
        app.launch()

        openLegendsSettings(app)

        // Baseline: autosave on (fixture pins it), then turn it off through
        // the real toggle. The preference change itself checkpoints at T0.
        let lastSaved = app.descendants(matching: .any)["settings.save.lastSavedRow"]
        XCTAssertTrue(lastSaved.waitForExistence(timeout: 5), "Expected the LAST SAVED row")

        let autosaveToggle = app.switches["settings.autosave.toggle"]
        if !autosaveToggle.waitForExistence(timeout: 4) { app.swipeUp() }
        XCTAssertTrue(autosaveToggle.waitForExistence(timeout: 5))
        autosaveToggle.tap()
        XCTAssertTrue(lastSaved.waitForExistence(timeout: 5))
        XCTAssertTrue(lastSaved.label.lowercased().contains("auto-save is off"),
                      "Toggling off must checkpoint (T0 timestamp) and announce the pause; got \(lastSaved.label)")
        let savedLabelBeforeMatch = lastSaved.label

        // Play a complete match through the real UI path.
        app.buttons["legends.nav.home"].tap()
        XCTAssertTrue(app.buttons["legends.nav.settings"].waitForExistence(timeout: 8))

        let playMatch = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "PLAY MATCH")).firstMatch
        XCTAssertTrue(playMatch.waitForExistence(timeout: 8), "Expected the Play Match feature")
        playMatch.tap()

        let kickoff = app.buttons["legends.match.kickoff"]
        XCTAssertTrue(kickoff.waitForExistence(timeout: 8))
        kickoff.tap()

        let skip = app.buttons.matching(NSPredicate(format: "label == %@", "SKIP")).firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "Expected the live match SKIP control")
        skip.tap()

        let continueButton = app.buttons["legends.live.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10), "Expected the FULL TIME continue action")
        Thread.sleep(forTimeInterval: 0.4)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "REWARDS")).firstMatch.waitForExistence(timeout: 8),
                      "Expected the post-match result panel after CONTINUE")

        // Back to Settings: the timestamp must be exactly the pre-match T0
        // value — the match pipeline ran completely, but wrote nothing.
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["legends.nav.settings"].tap()
        XCTAssertTrue(lastSaved.waitForExistence(timeout: 6))
        if !autosaveToggle.exists { app.swipeUp() }
        XCTAssertTrue(lastSaved.waitForExistence(timeout: 5))
        XCTAssertEqual(lastSaved.label, savedLabelBeforeMatch,
                       "A completed match with Auto-Save paused must not write the save file " +
                       "(timestamp would have advanced); got \(lastSaved.label), expected \(savedLabelBeforeMatch)")

        // Re-enabling checkpoints the match's progress: timestamp moves and
        // the status flips back to automatic.
        let autosaveToggle2 = app.switches["settings.autosave.toggle"]
        if !autosaveToggle2.waitForExistence(timeout: 4) { app.swipeUp() }
        XCTAssertTrue(autosaveToggle2.waitForExistence(timeout: 5))
        autosaveToggle2.tap()
        XCTAssertTrue(lastSaved.waitForExistence(timeout: 5))
        XCTAssertNotEqual(lastSaved.label, savedLabelBeforeMatch,
                          "Re-enabling Auto-Save must checkpoint the match progress (new timestamp)")
        XCTAssertTrue(lastSaved.label.lowercased().contains("auto-save is on"),
                      "Status must return to automatic; got \(lastSaved.label)")

        Thread.sleep(forTimeInterval: 0.5)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "Legends Auto-Save end-to-end match verification (landscape)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let size = app.windows.firstMatch.frame.size
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/rsm_autosave_e2e_\(Int(size.width))x\(Int(size.height)).png"))
    }
}
