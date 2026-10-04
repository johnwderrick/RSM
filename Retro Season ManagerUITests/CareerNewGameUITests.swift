//
//  CareerNewGameUITests.swift
//  Retro Season Manager
//
//  End-to-end coverage for the redesigned club-and-era picker and
//  confirmation flow. Launches from the real experience selector with an
//  isolated empty GameStore: no fixture reads, creates, migrates, or changes
//  an existing save. The selected career still starts through the real
//  `newGame` path and therefore creates its own independent save slot.
//
//  The test exercises compact landscape scrolling, era selection,
//  confirmation back/forward state, manager-name entry + keyboard dismissal,
//  the pinned Manage action, and the resulting club and season in Home.
//  XCUIDevice.orientation is never written — the application locks itself
//  to landscape.
//

import XCTest

final class CareerNewGameUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_NEW_GAME"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let suffixed = "\(name)_\(model)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_new_game_\(suffixed).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: suffixed, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitFor(_ app: XCUIApplication, _ identifier: String,
                         timeout: TimeInterval = 8) -> XCUIElement {
        let element = anyElement(app, identifier)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing element: \(identifier)")
        return element
    }

    private func openNewGame(_ app: XCUIApplication) {
        _ = waitFor(app, "career.newGame.select", timeout: 10)
        _ = waitFor(app, "career.newGame.clubs.scroll")
        _ = waitFor(app, "career.newGame.era.2000")
        _ = waitFor(app, "career.newGame.era.2010")
        _ = waitFor(app, "career.newGame.era.2020")
    }

    func testEraClubNameBackForwardAndManageCreateSelectedSeason() throws {
        let app = launch()
        openNewGame(app)
        shot(app, "club_picker")

        let clubScroll = app.scrollViews["career.newGame.clubs.scroll"].firstMatch
        XCTAssertTrue(clubScroll.exists, "Club list must have its own vertical scroll container")

        // Confirm the club grid scrolls independently while the era choices
        // stay pinned, then return to the top-flight choices.
        let firstClub = app.buttons["career.newGame.club.0"].firstMatch
        XCTAssertTrue(firstClub.isHittable, "The first club should start in view")
        clubScroll.swipeUp()
        XCTAssertFalse(firstClub.isHittable, "A vertical swipe should scroll the club cards")
        clubScroll.swipeDown()
        XCTAssertTrue(firstClub.isHittable, "The top-flight choices should return after scrolling up")

        // The era selector is pinned outside the club scroll, so changing
        // an era never depends on swiping back through the lazy grid.
        let era = app.buttons["career.newGame.era.2020"]
        XCTAssertTrue(era.isHittable, "All current era choices should fit in the pinned era row")
        era.tap()
        XCTAssertTrue(era.isSelected, "The selected era should remain visibly selected")
        XCTAssertTrue(anyElement(app, "career.newGame.selectedEra").label.contains("2020/21"),
                      "Selected era label must reflect the real start year")

        let club = waitFor(app, "career.newGame.club.0")
        XCTAssertTrue(club.isHittable, "Selected top-flight club should be ready for selection")
        club.tap()

        let clubSummary = waitFor(app, "career.newGame.confirm.club")
        XCTAssertTrue(clubSummary.label.contains("Old Trafford Reds"),
                      "Confirmation must identify the chosen club: \(clubSummary.label)")
        XCTAssertTrue(clubSummary.label.contains("2020/21"),
                      "Confirmation must keep the chosen start season: \(clubSummary.label)")
        _ = waitFor(app, "career.newGame.confirm.preview")
        let previewSeason = anyElement(app, "career.newGame.preview.startingSeason")
        XCTAssertTrue(previewSeason.exists, "Starting-season preview row should be present")
        XCTAssertTrue(previewSeason.label.contains("2020/21"),
                      "Starting-season preview should reflect the selected era: \(previewSeason.label)")
        let field = app.textFields["career.newGame.confirm.managerName"]
        XCTAssertTrue(field.waitForExistence(timeout: 6), "Manager-name field missing")
        shot(app, "confirmation_before_name")

        // Type a name and dismiss the keyboard with the field's Done return
        // key. The action remains pinned even when keyboard appearance
        // shrinks the sole scroll region on the SE.
        field.tap()
        field.typeText("Alex Ferguson")
        XCTAssertTrue(field.value as? String == "Alex Ferguson", "Manager name should be entered")
        let done = app.keyboards.buttons["Done"].firstMatch
        if done.exists { done.tap() } else { field.typeText("\n") }

        let manage = app.buttons["career.newGame.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 6), "Pinned Manage action missing")
        XCTAssertTrue(manage.isHittable, "Manage must remain tappable with the keyboard dismissed")
        shot(app, "confirmation_ready")

        // Back must restore both club list and the exact selected era.
        waitFor(app, "career.newGame.confirm.back").tap()
        _ = waitFor(app, "career.newGame.select")
        XCTAssertTrue(app.buttons["career.newGame.era.2020"].isSelected,
                      "Going back must preserve the selected era")
        shot(app, "club_picker_after_back")

        // Forward again to the same club; state remains consistent and
        // the name remains present across the confirmation's keyboard cycle.
        let clubAgain = waitFor(app, "career.newGame.club.0")
        XCTAssertTrue(clubAgain.isHittable, "Chosen club should be reachable after returning to the list")
        clubAgain.tap()
        XCTAssertTrue(waitFor(app, "career.newGame.confirm.club").label.contains("Old Trafford Reds"),
                      "Returning forward must preserve the chosen club")
        let fieldAgain = app.textFields["career.newGame.confirm.managerName"]
        XCTAssertTrue(fieldAgain.waitForExistence(timeout: 6), "Manager field should return with confirmation")
        fieldAgain.tap()
        XCTAssertEqual(fieldAgain.value as? String, "Alex Ferguson",
                       "Going back and forward must retain the entered manager name")
        let doneAgain = app.keyboards.buttons["Done"].firstMatch
        if doneAgain.exists { doneAgain.tap() } else { fieldAgain.typeText("\n") }
        shot(app, "confirmation_after_forward")

        // Manage goes through the existing newGame call; Home reads the
        // authoritative store values, proving club, manager and season.
        waitFor(app, "career.newGame.manage").tap()
        let home = waitFor(app, "career.home.screen", timeout: 30)
        XCTAssertTrue(home.exists, "Starting the career must land on Home")
        let clubName = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "OLD TRAFFORD REDS")).firstMatch
        XCTAssertTrue(clubName.waitForExistence(timeout: 8), "Home should name the selected club")
        let careerIdentity = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                        "ALEX FERGUSON", "2020/21")).firstMatch
        XCTAssertTrue(careerIdentity.waitForExistence(timeout: 8),
                      "Home should show the entered manager and selected season")
        shot(app, "career_started")
    }

    func testFirstMatchGuideFindsTeamSetupAndReachesPreMatchFromRealNewGame() throws {
        let app = launch()
        openNewGame(app)
        waitFor(app, "career.newGame.club.0").tap()
        waitFor(app, "career.newGame.manage").tap()
        _ = waitFor(app, "career.home.screen", timeout: 30)
        let guide = waitFor(app, "career.home.firstMatch.guide")
        XCTAssertTrue(guide.exists)
        XCTAssertTrue(app.staticTexts["CONTINUE advances until news or match day."].exists)
        shot(app, "first_match_guide")
        waitFor(app, "career.home.firstMatch.squad").tap()
        waitFor(app, "career.squad.teamSetup").tap()
        _ = waitFor(app, "career.teamSetup.sheet")
        waitFor(app, "career.teamSetup.autoPick").tap()
        waitFor(app, "career.teamSetup.done").tap()
        waitFor(app, "career.nav.home").tap()

        // Follow both calendar actions through their production paths.
        waitFor(app, "career.continue").tap()
        let kickoff = app.buttons["career.match.kickoff"]
        for _ in 0..<20 {
            if kickoff.waitForExistence(timeout: 3) { break }
            let skip = app.buttons["career.home.skipToMatch"]
            for _ in 0..<8 {
                if kickoff.exists { break }
                if skip.exists && skip.frame.midY >= app.frame.minY && skip.frame.midY <= app.frame.maxY { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            if kickoff.exists { break }
            if !skip.waitForExistence(timeout: 8) {
                // The heavy calendar advance can replace Home with the
                // hub between snapshots; re-check the destination first.
                if kickoff.waitForExistence(timeout: 8) { break }
                XCTFail("Neither Skip nor the pre-match destination appeared")
                return
            }
            skip.tap()
        }
        XCTAssertTrue(kickoff.waitForExistence(timeout: 15), "A fresh career must reach the pre-match hub")
        XCTAssertTrue(anyElement(app, "career.prematch.screen").exists)
        shot(app, "first_match_hub")
        for identifier in ["career.prematch.talk.0", "career.prematch.press.0"] {
            let option = app.buttons[identifier]
            if option.exists {
                for _ in 0..<8 {
                    if option.frame.midY >= app.frame.minY && option.frame.midY <= app.frame.maxY { break }
                    app.scrollViews["career.prematch.scroll"].swipeUp()
                }
                option.tap()
            }
        }
        XCTAssertTrue(kickoff.isEnabled, "Answering the pre-match prompts must enable kickoff")
        kickoff.tap()
        waitFor(app, "career.match.skip", timeout: 15).tap()
        let postMatch = waitFor(app, "career.postMatch.continue", timeout: 15)
        let interview = app.buttons.matching(identifier: "career.postMatch.interviewOption").firstMatch
        if interview.exists && !postMatch.isEnabled {
            for _ in 0..<8 {
                if interview.frame.midY >= app.frame.minY && interview.frame.midY <= app.frame.maxY { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            interview.tap()
        }
        XCTAssertTrue(postMatch.isEnabled)
        postMatch.tap()
        _ = waitFor(app, "career.home.screen", timeout: 15)
        shot(app, "first_match_complete")
    }

    func testConfirmationManageButtonRemainsReachableOnLandscape() throws {
        let app = launch()
        openNewGame(app)
        app.buttons["career.newGame.era.2020"].tap()
        app.buttons["career.newGame.club.0"].tap()

        let manage = app.buttons["career.newGame.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 6), "Manage action missing")
        XCTAssertTrue(manage.isHittable, "Pinned Manage action must be reachable on a compact landscape phone")
        shot(app, "manage_reachable")
    }
}
