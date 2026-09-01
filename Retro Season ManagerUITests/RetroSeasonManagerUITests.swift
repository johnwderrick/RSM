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

        // Poll repeatedly during the hold rather than checking at one fixed
        // instant. A single point-in-time check (this used to be scheduled
        // for exactly 0.5s into the 1.2s hold) is timing-sensitive: on a
        // slower/loaded CI runner, the synthesized touch-down event and
        // the SwiftUI re-render that swaps in the pressed image can
        // together take longer than that fixed offset, so the check could
        // fire before the pressed artwork has actually appeared even
        // though the button genuinely is still being held — exactly what
        // was seen on CI ("Pressed art ... was not visible while ... was
        // held"). Polling verifies the same real behavior — the pressed
        // artwork appears at some point during a genuine hold, before
        // release — without assuming any particular render latency.
        //
        // The poll loop runs on its own background queue with a real
        // Thread.sleep, not chained DispatchQueue.main.asyncAfter calls —
        // `button.press(forDuration:)` below blocks the main thread/run
        // loop for the duration of the hold, and a *recursive* asyncAfter
        // (each poll rescheduling the next one from inside the previous
        // callback) turned out not to reliably get past its first
        // invocation while that block was in effect on the CI runner
        // (confirmed: the very first, and only, poll fired, then the
        // expectation just timed out with no further checks ever
        // running). A plain background thread doesn't depend on the main
        // run loop processing anything at all, so it isn't affected by
        // whatever `press(forDuration:)` does to it.
        // The first UI test starts from a cold accessibility tree on CI. Waiting
        // for the normal artwork above and holding for three seconds gives
        // XCTest enough time to publish the transient pressed child without
        // weakening the assertion or accepting the post-release state.
        let holdDuration: TimeInterval = 3.0
        let pollInterval: TimeInterval = 0.1
        let visibleWhileHeld = expectation(description: "pressed art visible while held: \(buttonID)")
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
        wait(for: [visibleWhileHeld], timeout: holdDuration + 2)
    }
}
