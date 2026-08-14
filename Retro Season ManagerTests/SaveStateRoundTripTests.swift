//
//  SaveStateRoundTripTests.swift
//  Retro Season ManagerTests
//
//  Regression coverage for the "every new SaveState field is Optional,
//  defaulted at load" convention documented in Docs/Save System.md —
//  previously untested (see that file's old "Testing a save change"
//  section, and Docs/HANDOVER.md §7's "save/load round-trips" gap).
//
//  Two things are checked, both through the real public API
//  (persist() happens implicitly inside newGame(); loadSavedGame(id:) is
//  called directly), not by hand-constructing a SaveState:
//
//  1. A brand-new career round-trips through disk unchanged.
//  2. A save file that's missing fields added after the format's first
//     version — simulated by stripping keys from the actual JSON
//     newGame() just wrote — still loads, with every stripped field
//     coming back as its documented default instead of failing the decode.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class SaveStateRoundTripTests: XCTestCase {

    func testNewCareerRoundTripsThroughPersistAndLoad() async {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2010, managerName: "Round Trip Tester")
        guard let id = store.currentSaveID else {
            XCTFail("newGame() did not set currentSaveID")
            return
        }
        defer { GameStore.deleteSave(id: id) }

        let reloaded = await makeTestStore()
        let didLoad = reloaded.loadSavedGame(id: id)

        XCTAssertTrue(didLoad, "A save newGame() just wrote should load back successfully")
        XCTAssertEqual(reloaded.season, store.season)
        XCTAssertEqual(reloaded.userClubIndex, store.userClubIndex)
        XCTAssertEqual(reloaded.clubs.count, store.clubs.count)
        XCTAssertEqual(reloaded.formation.name, store.formation.name)
        XCTAssertEqual(reloaded.managerName, "Round Trip Tester")
        XCTAssertEqual(reloaded.startYear, 2010)
        XCTAssertEqual(reloaded.userClub.name, store.userClub.name)
        XCTAssertEqual(reloaded.difficulty, store.difficulty)
        XCTAssertEqual(reloaded.boardObjective, store.boardObjective)
    }

    func testLoadingSaveMissingNewerOptionalFieldsUsesDocumentedDefaults() async {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Legacy Save Tester")
        guard let id = store.currentSaveID else {
            XCTFail("newGame() did not set currentSaveID")
            return
        }
        defer { GameStore.deleteSave(id: id) }

        // Rewrite the file newGame() just wrote, stripping keys that map to
        // real Optional fields added well after SaveState's first version —
        // exactly what an old save on a user's device looks like today.
        let url = SaveSlots.fileURL(for: id)
        guard let originalData = try? Data(contentsOf: url),
              var json = try? JSONSerialization.jsonObject(with: originalData) as? [String: Any] else {
            XCTFail("Could not read back the save file that newGame() just wrote")
            return
        }
        let droppedKeys = ["fanConfidence", "delegateToAssistant", "preferredMentality",
                            "managerContractYears", "startYear", "boardConfidenceTrend"]
        for key in droppedKeys {
            XCTAssertNotNil(json[key], "'\(key)' was expected in a freshly-written save — test needs updating if this field was renamed or removed")
            json.removeValue(forKey: key)
        }
        guard let strippedData = try? JSONSerialization.data(withJSONObject: json) else {
            XCTFail("Could not re-serialize the stripped save JSON")
            return
        }
        try? strippedData.write(to: url)

        let reloaded = await makeTestStore()
        let didLoad = reloaded.loadSavedGame(id: id)

        XCTAssertTrue(didLoad, "A save missing only Optional fields should still load, not fail outright")
        XCTAssertEqual(reloaded.fanConfidence, 60, "fanConfidence should default to 60 when absent")
        XCTAssertEqual(reloaded.delegateToAssistant, false, "delegateToAssistant should default to false when absent")
        XCTAssertEqual(reloaded.preferredMentality, .balanced, "preferredMentality should default to .balanced when absent")
        XCTAssertEqual(reloaded.managerContractYears, 3, "managerContractYears should default to 3 when absent")
        XCTAssertEqual(reloaded.startYear, 2000, "startYear should default to 2000 when absent")
        XCTAssertEqual(reloaded.boardConfidenceTrend, 0, "boardConfidenceTrend should default to 0 when absent")
    }
}
