//
//  CareerSettingsTests.swift
//  Retro Season Manager
//
//  Focused store-level coverage behind the redesigned Settings screen:
//  the deterministic settings fixture's shape, the save/exit round trip
//  the SAVE & EXIT action performs (including the slot's authoritative
//  lastPlayed stamp), and the existing preference properties persisting
//  through encode/decode.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerSettingsTests: XCTestCase {

    /// Creates a fresh store and starts a real career for it (the same
    /// path a normal new game takes), with the save slot already bound.
    private func freshCareer() async -> GameStore {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Settings Tester")
        XCTAssertNotNil(store.currentSaveID, "A new career must be bound to a save slot")
        return store
    }

    // MARK: - Settings fixture

    func testSettingsFixtureProvidesAuthoritativeContent() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerSettingsFixtureForDebug()

        // Transfer history through the real logging path (newest first).
        XCTAssertGreaterThanOrEqual(store.transferHistory.count, 3)
        XCTAssertEqual(store.transferHistory.first?.action, "Released")
        XCTAssertTrue(store.transferHistory.contains { $0.action == "Signed" && ($0.fee ?? 0) > 0 })

        // At least one printed front page in the archive.
        XCTAssertFalse(store.newspapers.isEmpty, "The fixture must print at least one front page via addNews")

        // One achievement through the real unlock path, and no pending
        // celebration overlay left in the way of the shell.
        XCTAssertTrue(store.unlockedAchievements.contains(.wins50))
        XCTAssertNotNil(store.achievementUnlocks[.wins50])
        XCTAssertNil(store.pendingAchievementCelebration)

        // A previous season in the history table (older than current).
        let past = store.history.filter { $0.season < store.season }
        XCTAssertFalse(past.isEmpty, "The fixture must seed a completed previous season")
        XCTAssertTrue(past.allSatisfy { $0.userClub == store.userClub.name })

        // Seeded preference; delegation stays at its default.
        XCTAssertTrue(store.autoPickAssist)
        XCTAssertFalse(store.delegateToAssistant)
    }

    // MARK: - Save & exit round trip

    func testQuitToMenuPersistsAndReloadsState() async throws {
        let store = await freshCareer()
        store.difficulty = .hard
        store.autoPickAssist = true
        store.logTransferHistory("Persistence Pete", action: "Signed", otherClub: "Riverton FC", fee: 500)
        let savedClubName = store.userClub.name

        // The authoritative SAVE & EXIT action: persists, then returns to
        // the menu. Nothing is deleted.
        store.quitToMenu()
        XCTAssertFalse(store.hasStarted, "quitToMenu must exit to the main menu")
        XCTAssertNotNil(store.currentSaveID, "The save slot must stay bound — quit never deletes")

        // The slot index records the save (this is what Settings shows).
        let slot = SaveSlots.all().first { $0.id == store.currentSaveID! }
        XCTAssertNotNil(slot)
        XCTAssertEqual(slot?.clubName, savedClubName)

        // Reloading restores the career state exactly.
        store.loadSavedGame(id: store.currentSaveID!)
        XCTAssertTrue(store.hasStarted)
        XCTAssertEqual(store.difficulty, .hard, "Difficulty must survive save/exit/relaunch")
        XCTAssertTrue(store.autoPickAssist, "Auto-pick assist must survive save/exit/relaunch")
        XCTAssertEqual(store.userClub.name, savedClubName)
        XCTAssertTrue(store.transferHistory.contains { $0.playerName == "Persistence Pete" })
    }

    func testSlotLastPlayedStampUpdatesOnPersist() async throws {
        let store = await freshCareer()
        let before = SaveSlots.all().first { $0.id == store.currentSaveID! }?.lastPlayed

        // Persist through the same call SAVE & EXIT makes.
        store.persist()

        let after = SaveSlots.all().first { $0.id == store.currentSaveID! }?.lastPlayed
        XCTAssertNotNil(after)
        if let before {
            XCTAssertGreaterThanOrEqual(after!, before, "A persist must refresh (or keep) the lastPlayed stamp")
        }
    }

    func testFailedCareerFileWriteKeepsPreviousSaveAndCareerOpen() async throws {
        let store = await freshCareer()
        let id = try XCTUnwrap(store.currentSaveID)
        defer { SaveSlots.debugFailNextWrite = nil; SaveSlots.remove(id) }
        let previousData = try Data(contentsOf: SaveSlots.fileURL(for: id))
        let previousSlot = SaveSlots.all().first { $0.id == id }
        store.difficulty = .hard

        SaveSlots.debugFailNextWrite = .saveFile
        XCTAssertFalse(store.quitToMenu())
        XCTAssertTrue(store.hasStarted)
        XCTAssertEqual(try Data(contentsOf: SaveSlots.fileURL(for: id)), previousData)
        XCTAssertEqual(SaveSlots.all().first { $0.id == id }, previousSlot)

        XCTAssertTrue(store.quitToMenu(), "A retry should work once storage is available")
        XCTAssertFalse(store.hasStarted)
        let reloaded = GameStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: id))
        XCTAssertEqual(reloaded.difficulty, .hard)
    }

    func testFailedSlotIndexWriteKeepsCareerOpenAndOldIndexIntact() async throws {
        let store = await freshCareer()
        let id = try XCTUnwrap(store.currentSaveID)
        defer { SaveSlots.debugFailNextWrite = nil; SaveSlots.remove(id) }
        let previousSlot = SaveSlots.all().first { $0.id == id }
        store.difficulty = .hard

        SaveSlots.debugFailNextWrite = .index
        XCTAssertFalse(store.quitToMenu())
        XCTAssertTrue(store.hasStarted)
        XCTAssertEqual(SaveSlots.all().first { $0.id == id }, previousSlot)

        XCTAssertTrue(store.quitToMenu())
        XCTAssertFalse(store.hasStarted)
        let reloaded = GameStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: id))
        XCTAssertEqual(reloaded.difficulty, .hard)
    }

    func testRenamedSaveTitleSurvivesAutosaveReloadAndClubChange() async {
        let store = await freshCareer()
        let id = store.currentSaveID!
        defer { SaveSlots.remove(id) }
        let originalClub = store.userClub.name

        SaveSlots.rename(id, to: "My Long Career")
        SaveSlots.rename(id, to: "   ")
        store.persist()
        XCTAssertEqual(SaveSlots.all().first { $0.id == id }?.displayName, "My Long Career")
        XCTAssertEqual(SaveSlots.all().first { $0.id == id }?.clubName, originalClub)

        let reloaded = GameStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: id))
        reloaded.userClubIndex = 1
        reloaded.persist()
        let slot = SaveSlots.all().first { $0.id == id }
        XCTAssertEqual(slot?.displayName, "My Long Career")
        XCTAssertEqual(slot?.clubName, reloaded.userClub.name)
    }

    func testOldRenamedSaveTitleMigratesOnLoad() async {
        let store = await freshCareer()
        let id = store.currentSaveID!
        defer { SaveSlots.remove(id) }
        var oldSlot = SaveSlots.all().first { $0.id == id }!
        oldSlot.clubName = "Old Custom Title"
        SaveSlots.upsert(oldSlot)

        let reloaded = GameStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: id))
        reloaded.persist()
        let slot = SaveSlots.all().first { $0.id == id }
        XCTAssertEqual(slot?.displayName, "Old Custom Title")
        XCTAssertEqual(slot?.clubName, reloaded.userClub.name)
    }

    func testUnreadableSaveDoesNotChangeCareerOrRemoveSlot() async throws {
        let store = await freshCareer()
        let id = store.currentSaveID!
        defer { SaveSlots.remove(id) }
        let brokenData = Data("invalid career save".utf8)
        try brokenData.write(to: SaveSlots.fileURL(for: id))

        let reloaded = GameStore()
        XCTAssertFalse(reloaded.loadSavedGame(id: id))
        XCTAssertFalse(reloaded.hasStarted)
        XCTAssertNil(reloaded.currentSaveID)
        XCTAssertTrue(SaveSlots.all().contains { $0.id == id })
        XCTAssertEqual(try Data(contentsOf: SaveSlots.fileURL(for: id)), brokenData)
    }

    func testDecodedSaveWithInvalidClubReferenceLeavesActiveCareerUntouched() async throws {
        let damaged = await freshCareer()
        let damagedID = try XCTUnwrap(damaged.currentSaveID)
        let validData = try Data(contentsOf: SaveSlots.fileURL(for: damagedID))
        let validJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: validData) as? [String: Any])
        let damagedSlot = SaveSlots.all().first { $0.id == damagedID }
        let active = await freshCareer()
        let activeID = try XCTUnwrap(active.currentSaveID)
        defer { SaveSlots.remove(damagedID); SaveSlots.remove(activeID) }
        let activeData = try Data(contentsOf: SaveSlots.fileURL(for: activeID))
        let clubIDs = active.clubs.map(\.id)
        let managerName = active.managerName
        let currentDate = active.currentDate

        for variant in ["negative index", "past last club", "empty clubs"] {
            var json = validJSON
            switch variant {
            case "negative index": json["userClubIndex"] = -1
            case "past last club": json["userClubIndex"] = damaged.clubs.count
            default: json["clubs"] = []; json["userClubIndex"] = 0
            }
            let data = try JSONSerialization.data(withJSONObject: json)
            // These are syntactically valid saves, unlike the existing
            // unreadable-file test. Structural validation must reject them.
            _ = try JSONDecoder().decode(SaveState.self, from: data)
            try data.write(to: SaveSlots.fileURL(for: damagedID), options: .atomic)

            XCTAssertFalse(active.loadSavedGame(id: damagedID), variant)
            XCTAssertTrue(active.hasStarted, variant)
            XCTAssertEqual(active.currentSaveID, activeID, variant)
            XCTAssertEqual(active.clubs.map(\.id), clubIDs, variant)
            XCTAssertEqual(active.managerName, managerName, variant)
            XCTAssertEqual(active.currentDate, currentDate, variant)
            XCTAssertEqual(SaveSlots.all().first { $0.id == damagedID }, damagedSlot, variant)
            XCTAssertEqual(try Data(contentsOf: SaveSlots.fileURL(for: damagedID)), data, variant)
            XCTAssertEqual(try Data(contentsOf: SaveSlots.fileURL(for: activeID)), activeData, variant)
        }
    }

    // MARK: - Preference persistence

    func testPreferencesSurviveSaveRoundTrip() async throws {
        let store = await freshCareer()
        store.difficulty = .easy
        store.autoPickAssist = true
        store.delegateToAssistant = false
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        reloaded.loadSavedGame(id: store.currentSaveID!)
        XCTAssertEqual(reloaded.difficulty, .easy)
        XCTAssertTrue(reloaded.autoPickAssist)
        XCTAssertFalse(reloaded.delegateToAssistant)
    }
}
