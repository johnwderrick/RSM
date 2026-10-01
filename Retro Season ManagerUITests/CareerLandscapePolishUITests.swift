//
//  CareerLandscapePolishUITests.swift
//  Retro Season ManagerUITests
//
//  Focused coverage for the compact-landscape UX fixes:
//   1. Squad pitch slot "Change <role> player" buttons meet the 24pt
//      minimum tap-target floor (was 31x14pt — a stray-tap trap on the
//      dense SE-landscape pitch).
//   2. League-table rows keep a hittable 24pt+ frame, remain tappable
//      (row opens that club's squad view) and keep their selected state.
//   3. The TACTICS/SQUAD LIST segmented control reads as a real control:
//      unselected segments get an ink-on-canvas treatment with a visible
//      outline, both segments stay hittable, and switching still works.
//
//  Landscape-locked app: no orientation writes, existence waits plus
//  native element taps only.
//

import XCTest

final class CareerLandscapePolishUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_NAVIGATION"]
        app.launch()
        return app
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_polish_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - 1. Pitch slot tap targets

    func testPitchSlotChangeButtonsMeetMinimumTapTarget() throws {
        let app = launch()
        let squadTab = app.buttons["career.nav.squad"]
        XCTAssertTrue(squadTab.waitForExistence(timeout: 20), "Sidebar missing")
        squadTab.tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 10),
                      "Squad screen missing")

        let gkSlot = app.buttons["career.squad.pitch.slot.gk"]
        XCTAssertTrue(gkSlot.waitForExistence(timeout: 8), "GK pitch slot missing")
        shot(app, "squad_pitch")

        // Every pitch slot button must meet the 24pt minimum side.
        let slots = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'career.squad.pitch.slot.'"))
            .allElementsBoundByIndex
        XCTAssertTrue(slots.count >= 11, "Expected a full XI of pitch slots, got \(slots.count)")
        for slot in slots {
            let f = slot.frame
            // 23.5 tolerance: a 24pt floor renders as 23.9999… on some
            // devices (floating-point), which is not a UX regression.
            XCTAssertTrue(min(f.width, f.height) >= 23.5,
                          "Pitch slot '\(slot.identifier)' is \(f.width)x\(f.height) — below the 24pt tap floor")
            XCTAssertTrue(slot.isHittable, "Pitch slot '\(slot.identifier)' must be hittable")
        }

        // The bigger pill must still act: tapping the ST slot opens the
        // existing slot picker (behaviour preserved, target now reachable).
        // The picker sheet has no root identifier, so anchor on its
        // "SELECT <ROLE>" heading.
        let st = slots.first { $0.identifier == "career.squad.pitch.slot.st" } ?? slots[0]
        st.tap()
        let pickerHeading = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'SELECT '"))
            .firstMatch
        XCTAssertTrue(pickerHeading.waitForExistence(timeout: 4),
                      "Tapping a pitch slot should open the position picker")
        shot(app, "squad_slot_tapped")
    }

    // MARK: - 2. League table rows

    func testLeagueTableRowsHittableAndTapOpensClubSquad() throws {
        let app = launch()
        let tableTab = app.buttons["career.nav.table"]
        XCTAssertTrue(tableTab.waitForExistence(timeout: 20), "Sidebar missing")
        tableTab.tap()
        XCTAssertTrue(anyElement(app, "career.table.scroll").waitForExistence(timeout: 10),
                      "Table screen missing")
        XCTAssertTrue(anyElement(app, "career.table.userRow").waitForExistence(timeout: 8),
                      "User club row missing")
        shot(app, "table_rows")

        // Visible on-screen rows must all keep a 24pt+ frame.
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'career.table.club.'"))
            .allElementsBoundByIndex
        XCTAssertTrue(rows.count >= 5, "Expected several club rows, got \(rows.count)")
        for row in rows.prefix(8) {
            let f = row.frame
            XCTAssertTrue(f.height >= 23.5,
                          "Table row '\(row.identifier)' is \(f.height)pt tall — below the 24pt tap floor")
        }

        // Behaviour preserved: tapping a club row opens that club's squad
        // sheet (anchored on its new semantic root identifier).
        let target = rows[1]
        XCTAssertTrue(target.isHittable, "Club row must be hittable")
        target.tap()
        XCTAssertTrue(anyElement(app, "career.squad.clubSheet").waitForExistence(timeout: 8),
                      "Tapping a league-table row should open the club squad sheet")
        shot(app, "table_row_tapped")
    }

    // MARK: - 3. Squad mode segmented control

    func testSquadModeSegmentsVisibleSelectionAndSwitching() throws {
        let app = launch()
        let squadTab = app.buttons["career.nav.squad"]
        XCTAssertTrue(squadTab.waitForExistence(timeout: 20), "Sidebar missing")
        squadTab.tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 10),
                      "Squad screen missing")

        let tactics = app.buttons["career.squad.mode.tactics"]
        let list = app.buttons["career.squad.mode.list"]
        XCTAssertTrue(tactics.waitForExistence(timeout: 8), "TACTICS segment missing")
        XCTAssertTrue(list.exists, "SQUAD LIST segment missing")
        shot(app, "squad_modes")

        // Both segments must be comfortable, hittable targets (23.5
        // tolerance for the 24pt floor's floating-point representation).
        for segment in [tactics, list] {
            let f = segment.frame
            XCTAssertTrue(min(f.width, f.height) >= 23.5,
                          "Segment '\(segment.identifier)' is \(f.width)x\(f.height) — below the 24pt floor")
            XCTAssertTrue(segment.isHittable)
        }

        // Selected state is exposed and switching still works.
        XCTAssertTrue(tactics.isSelected, "TACTICS should start selected")
        list.tap()
        XCTAssertTrue(anyElement(app, "career.squad.screen").waitForExistence(timeout: 6),
                      "Mode switch must keep the squad screen stable")
        XCTAssertTrue(list.isSelected, "SQUAD LIST should become selected after tapping it")
        XCTAssertFalse(tactics.isSelected, "TACTICS should lose the selected state")
        shot(app, "squad_modes_list")

        tactics.tap()
        XCTAssertTrue(tactics.isSelected, "TACTICS must switch back on")
    }
}
