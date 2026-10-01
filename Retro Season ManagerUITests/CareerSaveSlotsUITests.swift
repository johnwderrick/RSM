//
//  CareerSaveSlotsUITests.swift
//  Retro Season ManagerUITests
//
//  Exercises the real main-menu save picker with two DEBUG-only saved careers.
//

import XCTest

final class CareerSaveSlotsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(corruptNewest: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_SAVE_SLOTS"]
        if corruptNewest { app.launchArguments.append("UITEST_CAREER_SAVE_SLOTS_CORRUPT") }
        app.launch()
        return app
    }

    private func openSaves(_ app: XCUIApplication) {
        let open = app.buttons["career.menu.loadGame"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.staticTexts["career.saves.header"].waitForExistence(timeout: 8))
    }

    private func shot(_ app: XCUIApplication, _ label: String) {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let name = "career_saves_\(label)_\(model)"
        try? png.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRenameCancelDeleteAndLoadAreSeparateActions() {
        let app = launch()
        openSaves(app)
        let rename = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.saves.rename.")).firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        let id = rename.identifier.replacingOccurrences(of: "career.saves.rename.", with: "")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.saves.load.")).count, 2)
        shot(app, "overview")

        rename.tap()
        let field = app.alerts.textFields["Save name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + "My Career")
        app.alerts.buttons["Save"].tap()
        let name = app.staticTexts["career.saves.name.\(id)"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "My Career")

        app.buttons["career.saves.delete.\(id)"].tap()
        XCTAssertTrue(app.alerts["Delete this save?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.saves.load.")).count, 2)

        app.buttons["career.saves.close"].tap()
        openSaves(app)
        XCTAssertEqual(app.staticTexts["career.saves.name.\(id)"].label, "My Career")
        app.buttons["career.saves.load.\(id)"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].firstMatch.waitForExistence(timeout: 15),
                      "LOAD CAREER should open the saved game")
    }

    func testDeleteCommitShowsEmptyState() {
        let app = launch()
        openSaves(app)
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.saves.delete."))
        XCTAssertEqual(buttons.count, 2)
        let ids = buttons.allElementsBoundByIndex.map { $0.identifier.replacingOccurrences(of: "career.saves.delete.", with: "") }
        for id in ids {
            app.buttons["career.saves.delete.\(id)"].tap()
            XCTAssertTrue(app.alerts["Delete this save?"].waitForExistence(timeout: 5))
            app.alerts.buttons["Delete"].tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["career.saves.empty"].firstMatch.waitForExistence(timeout: 5))
        shot(app, "empty")
        app.buttons["career.saves.close"].tap()
        XCTAssertFalse(app.buttons["career.menu.loadGame"].isEnabled)
    }

    func testDamagedSaveDoesNotBlockOtherCareer() {
        let app = launch(corruptNewest: true)
        let resume = app.buttons["career.menu.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        let error = app.alerts["Unable to load career"]
        XCTAssertTrue(error.waitForExistence(timeout: 8))
        XCTAssertTrue(error.staticTexts["This save could not be opened. Your other saves have not been changed."].exists)
        error.buttons["OK"].tap()

        openSaves(app)
        let loads = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.saves.load."))
        XCTAssertEqual(loads.count, 2)
        loads.element(boundBy: 0).tap()
        XCTAssertTrue(error.waitForExistence(timeout: 8))
        error.buttons["OK"].tap()
        XCTAssertEqual(loads.count, 2, "A failed load must not remove or overwrite either save")
        loads.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["career.home.screen"].firstMatch.waitForExistence(timeout: 15))
    }
}
