//
//  LegendsSettingsTests.swift
//  Retro Season Manager
//
//  Focused coverage for the redesigned Legends Settings: the persisted
//  presentation preferences (defaults, persistence, restore defaults,
//  motion layering) and the destructive-action safety property that
//  deleting a club never touches presentation preferences.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsSettingsTests: XCTestCase {

    /// A dedicated suite keeps the on-disk simulator defaults untouched.
    private let suiteName = "LegendsSettingsTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Clear both the isolated suite and the app-standard keys the UI
        // tests may have left behind, so "default" assertions are exact.
        UserDefaults.standard.removeObject(forKey: LegendsPresentation.reduceMotionKey)
        UserDefaults.standard.removeObject(forKey: LegendsPresentation.commentarySizeKey)
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// The established store-isolation pattern for the shared test host.
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        return store
    }

    // MARK: - Defaults match the previously accepted behaviour

    func testDefaultsMatchPreviouslyAcceptedBehaviour() {
        XCTAssertFalse(LegendsPresentation.reduceInterfaceMotion,
                       "Reduce Interface Motion must default off (the current behaviour)")
        XCTAssertEqual(LegendsPresentation.commentaryTextSize, .medium,
                       "Commentary size must default to the original fixed presentation")

        let suppressed = LegendsPresentation.motionSuppressed(systemReduceMotion: false)
        XCTAssertFalse(suppressed, "No suppression when both the preference and the system setting are off")
    }

    // MARK: - Persistence

    func testPreferencePersistence() {
        LegendsPresentation.setReduceInterfaceMotion(true, defaults: defaults)
        LegendsPresentation.setCommentaryTextSize(.extraLarge, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: LegendsPresentation.reduceMotionKey))
        XCTAssertEqual(
            LegendsPresentation.CommentaryTextSize(
                rawValue: defaults.string(forKey: LegendsPresentation.commentarySizeKey) ?? ""
            ),
            .extraLarge
        )
    }

    // MARK: - Restore defaults

    func testRestoreDefaultsClearsPreferences() {
        defaults.set(true, forKey: LegendsPresentation.reduceMotionKey)
        defaults.set(LegendsPresentation.CommentaryTextSize.extraLarge.rawValue,
                     forKey: LegendsPresentation.commentarySizeKey)

        LegendsPresentation.restoreDefaults(defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: LegendsPresentation.reduceMotionKey))
        XCTAssertNil(defaults.string(forKey: LegendsPresentation.commentarySizeKey))
        XCTAssertEqual(LegendsPresentation.CommentaryTextSize(
            rawValue: defaults.string(forKey: LegendsPresentation.commentarySizeKey) ?? ""
        ) ?? .medium, .medium, "Reading after restore falls back to the default size")
    }

    // MARK: - Motion layering

    func testMotionSuppressionLayersOverSystemSetting() {
        XCTAssertFalse(LegendsPresentation.motionSuppressed(systemReduceMotion: false))

        // motionSuppressed reads the app-standard defaults (the same store
        // the Settings toggle and LegendsFlow write), so exercise that path.
        defer { UserDefaults.standard.removeObject(forKey: LegendsPresentation.reduceMotionKey) }
        UserDefaults.standard.set(true, forKey: LegendsPresentation.reduceMotionKey)
        XCTAssertTrue(LegendsPresentation.motionSuppressed(systemReduceMotion: false),
                      "The Legends preference alone suppresses interface motion")

        XCTAssertTrue(LegendsPresentation.motionSuppressed(systemReduceMotion: true),
                      "System Reduce Motion always suppresses regardless of the preference")
    }

    // MARK: - Commentary size effect

    func testCommentaryTextSizeMapsToAdvertisedTextStyles() {
        // Medium is the original fixed `.footnote` presentation; the larger
        // options scale up from there.
        XCTAssertEqual(LegendsPresentation.CommentaryTextSize.medium.textStyle, .footnote)
        XCTAssertEqual(LegendsPresentation.CommentaryTextSize.large.textStyle, .body)
        XCTAssertEqual(LegendsPresentation.CommentaryTextSize.extraLarge.textStyle, .title3)
    }

    // MARK: - Destructive-action safety

    func testDeleteClubResetsProfileButNeverTouchesPresentationPreferences() async {
        defaults.set(true, forKey: LegendsPresentation.reduceMotionKey)
        defaults.set(LegendsPresentation.CommentaryTextSize.large.rawValue,
                     forKey: LegendsPresentation.commentarySizeKey)

        let expectedStarterCoins = LegendsProfile.starter().coins
        let store = await freshStore()

        store.deleteClub()

        XCTAssertEqual(store.profile.coins, expectedStarterCoins,
                       "deleteClub resets the club to the starter profile")
        XCTAssertTrue(defaults.bool(forKey: LegendsPresentation.reduceMotionKey),
                      "Deleting a club must not change presentation preferences")
        XCTAssertEqual(
            LegendsPresentation.CommentaryTextSize(
                rawValue: defaults.string(forKey: LegendsPresentation.commentarySizeKey) ?? ""
            ),
            .large,
            "Deleting a club must not change presentation preferences"
        )
    }

    // MARK: - Compatibility

    func testStarterProfileRoundTripsForSettingsSummary() throws {
        // LegendsProfile isn't Equatable; compare the fields the Settings
        // summary card displays after a full encode/decode cycle.
        let profile = LegendsProfile.starter()
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertEqual(decoded.clubName, profile.clubName)
        XCTAssertEqual(decoded.crestShort, profile.crestShort)
        XCTAssertEqual(decoded.managerLevel, profile.managerLevel)
        XCTAssertEqual(decoded.managerProfile?.displayName, profile.managerProfile?.displayName)
        XCTAssertEqual(decoded.division, profile.division)
    }

    // MARK: - Auto-Save preference

    private func clearSaveFile() {
        try? FileManager.default.removeItem(
            at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("legends_profile.json"))
    }

    private var saveFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("legends_profile.json")
    }

    func testAutosaveDefaultsOnLikePreviousBehaviour() async {
        defer { UserDefaults.standard.removeObject(forKey: LegendsPresentation.autosaveKey) }
        UserDefaults.standard.removeObject(forKey: LegendsPresentation.autosaveKey)

        let store = await freshStore()

        XCTAssertTrue(store.autosaveEnabled,
                      "A missing preference must mean Auto-Save on — the original always-save behaviour")
    }

    func testAutosaveOffPausesRoutineWrites() async {
        defer {
            UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey)
        }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()

        // A routine mutation (the Squad-screen mentality setter) must apply
        // in memory but not be written while autosave is paused.
        store.setPreferredMentality(.attacking)

        XCTAssertEqual(store.profile.preferredMentality, .attacking)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saveFileURL.path),
                       "Routine changes must not hit disk while Auto-Save is off")
    }

    func testTurningAutosaveBackOnCheckpointsPendingProgress() async {
        defer {
            UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey)
        }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()

        store.profile.clubName = "Checkpoint Athletic"
        XCTAssertFalse(FileManager.default.fileExists(atPath: saveFileURL.path))

        store.setAutosaveEnabled(true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: saveFileURL.path),
                      "Re-enabling Auto-Save must write everything accumulated while paused")
        let data = try? Data(contentsOf: saveFileURL)
        let decoded = data.flatMap { try? JSONDecoder().decode(LegendsProfile.self, from: $0) }
        XCTAssertEqual(decoded?.clubName, "Checkpoint Athletic")
    }

    func testCriticalActionsAlwaysSaveEvenWithAutosaveOff() async {
        defer {
            UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey)
        }
        let store = await freshStore()
        store.setAutosaveEnabled(false)

        // Deleting the club is a critical action and must still be written.
        store.deleteClub()
        XCTAssertTrue(FileManager.default.fileExists(atPath: saveFileURL.path),
                      "deleteClub must persist the reset even with Auto-Save off")
        XCTAssertEqual(store.profile.coins, LegendsProfile.starter().coins)

        // And the delete must not have silently re-enabled autosave.
        clearSaveFile()
        let before = try? Data(contentsOf: saveFileURL)
        store.setPreferredMentality(.defensive)
        XCTAssertEqual(try? Data(contentsOf: saveFileURL), before,
                       "Routine writes stay paused after a critical-action save")
        XCTAssertEqual(store.profile.preferredMentality, .defensive,
                       "Paused autosave must never discard in-memory progress")
    }

    func testPreferenceChangeItselfPersistsCurrentState() async {
        defer {
            UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey)
        }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()
        store.profile.clubName = "Pending United"

        // Flipping the preference back on is itself a checkpoint.
        store.setAutosaveEnabled(true)

        let data = try? Data(contentsOf: saveFileURL)
        let decoded = data.flatMap { try? JSONDecoder().decode(LegendsProfile.self, from: $0) }
        XCTAssertEqual(decoded?.clubName, "Pending United",
                       "The preference change must never lose pending progress")
    }

    // MARK: - Last-saved timestamp

    func testLastSavedDateIsNilWithoutAnySave() async {
        defer { UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey) }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()

        XCTAssertNil(store.lastSavedDate,
                     "With no save file on disk the timestamp must be nil, not a stale guess")
    }

    func testLastSavedDateReflectsRealSave() async {
        defer { UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey) }
        let store = await freshStore()
        clearSaveFile()

        XCTAssertNil(store.lastSavedDate)

        store.profile.clubName = "Timestamp Rovers"
        store.setAutosaveEnabled(true) // checkpoints via persistNow

        let saved = store.lastSavedDate
        XCTAssertNotNil(saved, "A completed save must produce a timestamp")
        if let saved {
            XCTAssertEqual(saved.timeIntervalSinceNow, 0, accuracy: 60,
                           "The timestamp must be the save file's real modification date")
        }

        // A later save moves the timestamp forward.
        Thread.sleep(forTimeInterval: 1.1)
        store.setPreferredMentality(.attacking)
        if let updated = store.lastSavedDate, let saved {
            XCTAssertGreaterThanOrEqual(updated, saved,
                                        "A later save must not move the timestamp backwards")
        }
    }

    func testLastSavedDateCoversAutosaveOffCriticalSave() async {
        defer { UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey) }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()

        store.deleteClub() // critical action, always written

        XCTAssertNotNil(store.lastSavedDate,
                        "A critical-action save with autosave off must still timestamp")
    }

    func testSavedDateTextFormat() throws {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 18
        components.hour = 21; components.minute = 47; components.second = 5
        let date = Calendar(identifier: .gregorian).date(from: components)
        let text = LegendsSettingsView.savedDateText(try XCTUnwrap(date))

        XCTAssertTrue(text.hasPrefix("18 Sep 2026"), "Got \(text)")
        XCTAssertTrue(text.hasSuffix("21:47:05"), "Got \(text)")
    }

    func testRelativeSavedTextBandsAreDeterministic() throws {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 18
        components.hour = 21; components.minute = 0; components.second = 0
        let saved = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: components))

        func secondsAfter(_ s: Int) -> Date { saved.addingTimeInterval(TimeInterval(s)) }

        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(5)), "saved just now")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(30)), "saved less than a minute ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(60)), "saved 1 minute ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(120)), "saved 2 minutes ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(3600)), "saved 1 hour ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(7200)), "saved 2 hours ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(86_400)), "saved 1 day ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(3 * 86_400)), "saved 3 days ago")
        // After a week the relative label falls back to the absolute stamp,
        // keeping the same "saved …" prefix as every other band.
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(8 * 86_400)),
                       "saved \(LegendsSettingsView.savedDateText(saved))")
        // A skewed/future timestamp must clamp to "just now", not go negative.
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(saved, now: secondsAfter(-15)), "saved just now")
    }

    func testRelativeSavedTextExactlyMatchesTheRequestedMinuteBoundaries() {
        let now = Date()
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(now.addingTimeInterval(-9), now: now), "saved just now")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(now.addingTimeInterval(-10), now: now), "saved less than a minute ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(now.addingTimeInterval(-59), now: now), "saved less than a minute ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(now.addingTimeInterval(-3599), now: now), "saved 59 minutes ago")
        XCTAssertEqual(LegendsSettingsView.relativeSavedText(now.addingTimeInterval(-86_399), now: now), "saved 23 hours ago")
    }

    // MARK: - End-to-end autosave through the real match pipeline

    private func fillStrongXI(_ store: LegendsStore) {
        var seenNames = Set<String>()
        let sorted = LegendsCardDatabase.all
            .sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) }
            .filter { seenNames.insert($0.name).inserted }
        for (index, _) in store.startingXISlots.enumerated() {
            store.assign(cardID: sorted[index].id, toXISlot: index)
        }
    }

    private func seedManager(_ store: LegendsStore) {
        store.profile.managerProfile = LegendsManagerProfile(
            firstName: "Save", surname: "Guard", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
    }

    func testInstantMatchDoesNotWriteSaveFileWhileAutosaveIsOff() async {
        defer { UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey) }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()
        fillStrongXI(store)
        seedManager(store)

        guard let summary = store.playMatch() else {
            return XCTFail("Expected the real instant-match pipeline to complete")
        }
        XCTAssertGreaterThan(summary.coinsEarned, 0)

        // The full pipeline ran — rewards, challenge grants and manager
        // stats are all in memory — but nothing reached disk.
        XCTAssertFalse(FileManager.default.fileExists(atPath: saveFileURL.path),
                       "A completed match must not write the save file while Auto-Save is off")

        // Re-enabling checkpoints the match's progress exactly once.
        store.setAutosaveEnabled(true)
        let data = try? Data(contentsOf: saveFileURL)
        let decoded = data.flatMap { try? JSONDecoder().decode(LegendsProfile.self, from: $0) }
        XCTAssertEqual(decoded?.coins, store.profile.coins,
                       "The checkpoint must capture the match's reward total")
        XCTAssertEqual(decoded?.matchesToday, 1)
        XCTAssertEqual(decoded?.managerProfile?.careerStats.matches, 1)
    }

    func testLiveMatchPipelineDoesNotWriteSaveFileWhileAutosaveIsOff() async {
        defer { UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey) }
        let store = await freshStore()
        store.setAutosaveEnabled(false)
        clearSaveFile()
        fillStrongXI(store)
        seedManager(store)

        // The same engine the KICK OFF button launches, driven to full time.
        let live = LegendsLiveMatch(store: store, opponent: LegendsOpponent(name: "Rival XI", rating: 60))
        live.skipToEnd()
        XCTAssertTrue(live.isFinished)
        _ = store.applyMatchOutcome(
            opponent: live.opponent,
            result: live.result,
            events: live.events,
            startingCardIDs: live.startingCardIDs,
            minutesPlayedByCardID: live.minutesPlayedByCardID
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: saveFileURL.path),
                       "The live 2D match path must also respect the paused Auto-Save preference")

        store.setAutosaveEnabled(true)
        let data = try? Data(contentsOf: saveFileURL)
        let decoded = data.flatMap { try? JSONDecoder().decode(LegendsProfile.self, from: $0) }
        XCTAssertEqual(decoded?.matchesToday, 1)
        XCTAssertEqual(decoded?.managerProfile?.careerStats.matches, 1,
                       "The live-match record must survive in the checkpoint")
    }

    func testInstantMatchWritesSaveFileImmediatelyWithAutosaveOn() async {
        defer { UserDefaults.standard.set(true, forKey: LegendsPresentation.autosaveKey) }
        let store = await freshStore()
        fillStrongXI(store)
        seedManager(store)
        clearSaveFile()

        guard let _ = store.playMatch() else {
            return XCTFail("Expected the real instant-match pipeline to complete")
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: saveFileURL.path),
                      "The original always-save behaviour must write the save during the match pipeline")
        let data = try? Data(contentsOf: saveFileURL)
        let decoded = data.flatMap { try? JSONDecoder().decode(LegendsProfile.self, from: $0) }
        XCTAssertEqual(decoded?.coins, store.profile.coins,
                       "The on-disk save must match the in-memory profile after the pipeline's own persists")
        XCTAssertEqual(decoded?.matchesToday, 1)
    }
}
