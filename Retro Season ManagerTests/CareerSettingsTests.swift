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
