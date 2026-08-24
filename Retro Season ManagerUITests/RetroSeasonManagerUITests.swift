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
                                          pressedImageID: "RSMCareerEntryButtonPressed")
    }

    func testLegendsEntryShowsPressedArtworkWhileHeld() throws {
        try assertPressedArtworkWhileHeld(buttonID: "experience.legends",
                                          pressedImageID: "RSMLegendsEntryButtonPressed")
    }

    func testSettingsShowsPressedArtworkWhileHeld() throws {
        try assertPressedArtworkWhileHeld(buttonID: "experience.settings",
                                          pressedImageID: "RSMSettingsButtonPressed")
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
        // Idempotent across re-runs on the same simulator install: without
        // this, a second run would already have a manager profile from the
        // first and skip straight past onboarding to the dashboard.
        app.launchArguments = ["UITEST_RESET_LEGENDS_MANAGER"]
        app.launch()

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
    }

    /// Launches the app fresh, finds `buttonID`, asserts the pressed artwork is
    /// NOT present initially, then holds the button and asserts the pressed
    /// image IS exposed mid-hold.
    private func assertPressedArtworkWhileHeld(buttonID: String,
                                               pressedImageID: String) throws {
        let app = XCUIApplication()
        app.launch()

        let button = app.buttons[buttonID]
        XCTAssertTrue(button.waitForExistence(timeout: 8),
                      "Expected button '\(buttonID)' to appear on the experience selector")
        XCTAssertFalse(app.images[pressedImageID].exists,
                       "Pressed art '\(pressedImageID)' should not be present before pressing")

        // Assert while the press is still held: the artwork swaps in for the
        // duration of the hold, well before `press(forDuration:)` returns.
        let visibleWhileHeld = expectation(description: "pressed art visible while held: \(buttonID)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if app.images[pressedImageID].exists {
                visibleWhileHeld.fulfill()
            } else {
                XCTFail("Pressed art '\(pressedImageID)' was not visible while '\(buttonID)' was held")
            }
        }
        button.press(forDuration: 1.2)
        wait(for: [visibleWhileHeld], timeout: 3)
    }
}
