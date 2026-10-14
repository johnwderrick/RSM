//
//  SeasonHistoryCompetitionWinnersTests.swift
//  Retro Season ManagerTests
//
//  Guards the explicit per-competition winners stored on SeasonRecord:
//  League Trophy, Midweek Cup and Continental Super Cup winners are kept
//  alongside the original National Cup, Continental Cup and Community
//  Trophy winners. Museum and Manager CV honours are attributed only by
//  the winner field for the same competition. Records written before these
//  fields existed keep the conservative managed-season fallback.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class SeasonHistoryCompetitionWinnersTests: XCTestCase {
    private var archiveRoot: URL!
    private var saveRoot: URL!

    override func setUp() {
        super.setUp()
        archiveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeasonHistoryWinnersArchive-\(UUID().uuidString)", isDirectory: true)
        saveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeasonHistoryWinnersSave-\(UUID().uuidString)", isDirectory: true)
        LegacyArchive.useIsolatedRootForTesting(archiveRoot)
        SaveSlots.useIsolatedRootForTesting(saveRoot)
    }

    override func tearDown() {
        LegacyArchive.useIsolatedRootForTesting(nil)
        SaveSlots.useIsolatedRootForTesting(nil)
        if let archiveRoot { try? FileManager.default.removeItem(at: archiveRoot) }
        if let saveRoot { try? FileManager.default.removeItem(at: saveRoot) }
        super.tearDown()
    }

    /// Keys added after SeasonRecord's first shape. Stripping them produces
    /// exactly what an older save or archive contains.
    private let newWinnerKeys = ["leagueCupWinner", "uefaCupWinner", "uefaSuperCupWinner"]

    private func rivalNames(_ store: GameStore) -> [String] {
        store.clubs.indices.filter { $0 != store.userClubIndex }.map { store.clubs[$0].name }
    }

    /// Clears every competition winner so each test states exactly which
    /// competitions produced a winner this season.
    private func clearWinners(_ store: GameStore) {
        store.cupWinnerName = nil
        store.leagueCupWinnerName = nil
        store.euroWinnerName = nil
        store.uefaCupWinnerName = nil
        store.uefaSuperCupWinnerName = nil
        store.communityShieldWinnerName = nil
    }

    private func honour(_ prize: String, _ label: String) -> String {
        "🏆 \(prize) (\(label))"
    }

    private func assertSameWinners(_ actual: SeasonRecord, _ expected: SeasonRecord,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.cupWinner, expected.cupWinner, file: file, line: line)
        XCTAssertEqual(actual.euroWinner, expected.euroWinner, file: file, line: line)
        XCTAssertEqual(actual.communityShieldWinner, expected.communityShieldWinner, file: file, line: line)
        XCTAssertEqual(actual.leagueCupWinner, expected.leagueCupWinner, file: file, line: line)
        XCTAssertEqual(actual.uefaCupWinner, expected.uefaCupWinner, file: file, line: line)
        XCTAssertEqual(actual.uefaSuperCupWinner, expected.uefaSuperCupWinner, file: file, line: line)
    }

    // MARK: - Recording winners at season end

    func testContinentalAndMidweekWinnersFromDifferentClubsAreRecordedSeparately() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Separate Cups")
        let user = store.userClub.name
        let rivals = rivalNames(store)
        clearWinners(store)
        store.euroWinnerName = rivals[0]
        store.uefaCupWinnerName = user

        store.recordSeasonHonours()

        let record = try XCTUnwrap(store.history.last)
        XCTAssertEqual(record.euroWinner, rivals[0])
        XCTAssertEqual(record.uefaCupWinner, user)
        XCTAssertEqual(record.cupWinner, "—")
        XCTAssertEqual(record.leagueCupWinner, "—")
        XCTAssertEqual(record.uefaSuperCupWinner, "—")

        XCTAssertTrue(store.careerHonours.contains(honour(GameStore.uefaCupName, record.label)))
        XCTAssertFalse(store.careerHonours.contains { $0.contains(GameStore.euroName) },
                       "A rival's Continental Cup must not become the user's honour")

        let userHonours = LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: user)
        XCTAssertEqual(userHonours, [honour(GameStore.uefaCupName, record.label)])
        XCTAssertEqual(LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: rivals[0]), [])
    }

    func testNationalLeagueAndSuperCupWinnersAreIndependent() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Independent Winners")
        let user = store.userClub.name
        let rivals = rivalNames(store)
        clearWinners(store)
        store.cupWinnerName = rivals[0]
        store.leagueCupWinnerName = user
        store.uefaSuperCupWinnerName = rivals[1]

        store.recordSeasonHonours()

        let record = try XCTUnwrap(store.history.last)
        XCTAssertEqual(record.cupWinner, rivals[0])
        XCTAssertEqual(record.leagueCupWinner, user)
        XCTAssertEqual(record.uefaSuperCupWinner, rivals[1])
        XCTAssertEqual(record.euroWinner, "—")
        XCTAssertEqual(record.uefaCupWinner, "—")
        XCTAssertEqual(record.communityShieldWinner, "—")

        let cupFamilyHonours = store.careerHonours.filter {
            $0.contains(GameStore.cupName) || $0.contains(GameStore.leagueCupName) || $0.contains(GameStore.uefaSuperCupName)
        }
        XCTAssertEqual(cupFamilyHonours, [honour(GameStore.leagueCupName, record.label)],
                       "Only the League Trophy was won by the user")

        let userHonours = LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: user)
        XCTAssertTrue(userHonours.contains(honour(GameStore.leagueCupName, record.label)))
        XCTAssertFalse(userHonours.contains { $0.contains(GameStore.cupName) })
        XCTAssertFalse(userHonours.contains { $0.contains(GameStore.uefaSuperCupName) })
        XCTAssertEqual(LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: rivals[0]), [])
        XCTAssertEqual(LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: rivals[1]), [])
    }

    func testWinningAndLosingClubsReceiveOnlyTheirOwnHonours() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Winners And Losers")
        let user = store.userClub.name
        let rivals = rivalNames(store)
        clearWinners(store)
        // The user loses the National Cup final and the League Trophy goes
        // to a rival, but the user wins the Community Trophy.
        store.cupWinnerName = rivals[0]
        store.leagueCupWinnerName = rivals[1]
        store.communityShieldWinnerName = user

        store.recordSeasonHonours()

        let record = try XCTUnwrap(store.history.last)
        XCTAssertEqual(record.cupWinner, rivals[0])
        XCTAssertEqual(record.leagueCupWinner, rivals[1])
        XCTAssertEqual(record.communityShieldWinner, user)

        XCTAssertEqual(store.careerHonours.filter { $0.contains("🏆") && !$0.contains("title") },
                       [honour(GameStore.communityShieldName, record.label)])
        let userHonours = LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: user)
        XCTAssertEqual(userHonours, [honour(GameStore.communityShieldName, record.label)])
        XCTAssertEqual(LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: rivals[0]), [])
        XCTAssertEqual(LegacyArchive.clubHonours(history: store.history, honours: store.careerHonours, club: rivals[1]), [])
    }

    // MARK: - Attribution never crosses competitions

    func testCompetitionWinnerNeverValidatesAnotherCompetition() throws {
        let user = "User FC"
        let label = "2000/01"
        // Every competition is won by someone else except the Continental
        // Cup, so only that honour may be attributed to the user.
        let record = SeasonRecord(season: 1, label: label, userClub: user,
                                  userDivision: "First Division", userPosition: 3,
                                  champion: "Rival A", cupWinner: "—", euroWinner: user,
                                  communityShieldWinner: "—", leagueCupWinner: "Rival B",
                                  uefaCupWinner: "Rival C", uefaSuperCupWinner: "—")
        let honours = [honour(GameStore.uefaCupName, label),
                       honour(GameStore.leagueCupName, label),
                       honour(GameStore.euroName, label)]

        XCTAssertEqual(LegacyArchive.clubHonours(history: [record], honours: honours, club: user),
                       [honour(GameStore.euroName, label)])
    }

    func testReturningToPreviouslyManagedClubDoesNotBleedHonours() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "CV Stints")
        let user = store.userClub.name
        let rivals = rivalNames(store)

        func season(_ number: Int, _ label: String, club: String, cupWinner: String) -> SeasonRecord {
            SeasonRecord(season: number, label: label, userClub: club,
                         userDivision: "First Division", userPosition: 5,
                         champion: rivals[0], cupWinner: cupWinner, euroWinner: "—",
                         communityShieldWinner: "—", leagueCupWinner: "—",
                         uefaCupWinner: "—", uefaSuperCupWinner: "—")
        }
        store.history = [
            season(1, "2000/01", club: user, cupWinner: user),
            season(2, "2001/02", club: rivals[0], cupWinner: rivals[1]),
            season(3, "2002/03", club: user, cupWinner: rivals[1]),
            season(4, "2003/04", club: user, cupWinner: user)
        ]
        store.careerHonours = [honour(GameStore.cupName, "2000/01"), honour(GameStore.cupName, "2003/04")]

        let cv = store.managerCV()

        XCTAssertEqual(cv.map(\.club), [user, rivals[0], user])
        XCTAssertEqual(cv[0].trophies, [honour(GameStore.cupName, "2000/01")])
        XCTAssertEqual(cv[1].trophies, [])
        XCTAssertEqual(cv[2].trophies, [honour(GameStore.cupName, "2003/04")],
                       "The second stint at the user's club must only show its own honours")
    }

    // MARK: - Save and archive round trips

    func testNewWinnerFieldsSurviveSaveReloadAndArchiveRoundTrips() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Round Trip Winners")
        let saveID = try XCTUnwrap(store.currentSaveID)
        let user = store.userClub.name
        let rivals = rivalNames(store)
        clearWinners(store)
        store.cupWinnerName = rivals[0]
        store.leagueCupWinnerName = user
        store.euroWinnerName = rivals[1]
        store.uefaCupWinnerName = user
        store.uefaSuperCupWinnerName = rivals[0]
        store.recordSeasonHonours()
        let expected = try XCTUnwrap(store.history.last)
        XCTAssertTrue(store.persist())

        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        let loaded = try XCTUnwrap(reloaded.history.last)
        assertSameWinners(loaded, expected)

        store.endCareer()
        store.returnToMenuAfterCareer()
        let archiveID = try XCTUnwrap(LegacyArchive.all().first?.id)
        let career = try XCTUnwrap(LegacyArchive.load(id: archiveID))
        let archived = try XCTUnwrap(career.history.last)
        assertSameWinners(archived, expected)

        let honours = LegacyArchive.clubHonours(career, club: user)
        XCTAssertTrue(honours.contains(honour(GameStore.leagueCupName, expected.label)))
        XCTAssertTrue(honours.contains(honour(GameStore.uefaCupName, expected.label)))
        XCTAssertFalse(honours.contains { $0.contains(GameStore.euroName) })
    }

    func testSaveWithoutWinnerFieldsLoadsAsUnknownAndKeepsFallback() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Older Save")
        let saveID = try XCTUnwrap(store.currentSaveID)
        let user = store.userClub.name
        let rivals = rivalNames(store)
        clearWinners(store)
        store.euroWinnerName = rivals[0]
        store.uefaCupWinnerName = user
        store.recordSeasonHonours()
        XCTAssertTrue(store.persist())

        // Rewrite the file as a save written before the winner fields existed.
        let url = SaveSlots.fileURL(for: saveID)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var history = try XCTUnwrap(json["history"] as? [[String: Any]])
        for index in history.indices {
            for key in newWinnerKeys { history[index].removeValue(forKey: key) }
        }
        json["history"] = history
        try JSONSerialization.data(withJSONObject: json).write(to: url)

        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        let record = try XCTUnwrap(reloaded.history.last)
        XCTAssertNil(record.leagueCupWinner)
        XCTAssertNil(record.uefaCupWinner)
        XCTAssertNil(record.uefaSuperCupWinner)
        XCTAssertEqual(record.euroWinner, rivals[0], "Winners stored before this change must still load")
        XCTAssertEqual(reloaded.careerHonours, store.careerHonours)

        // Unknown winners keep the conservative fallback for the managed club.
        let honours = [honour(GameStore.uefaCupName, record.label)]
        XCTAssertEqual(LegacyArchive.clubHonours(history: reloaded.history, honours: honours, club: user), honours)
        XCTAssertEqual(LegacyArchive.clubHonours(history: reloaded.history, honours: honours, club: rivals[0]), [])
    }

    // MARK: - Older record shapes

    func testOlderSeasonRecordDecodesWithUnknownWinnersAndNewShapeDoesNotFallBack() throws {
        let user = "Legacy FC"
        let label = "1999/00"
        let current = SeasonRecord(season: 1, label: label, userClub: user,
                                   userDivision: "First Division", userPosition: 2,
                                   champion: "Other", cupWinner: user, euroWinner: "—",
                                   communityShieldWinner: "—", leagueCupWinner: "Rival",
                                   uefaCupWinner: "—", uefaSuperCupWinner: "—")
        let encoded = try JSONEncoder().encode(current)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in newWinnerKeys { json.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(
            SeasonRecord.self, from: try JSONSerialization.data(withJSONObject: json))

        XCTAssertNil(legacy.leagueCupWinner)
        XCTAssertNil(legacy.uefaCupWinner)
        XCTAssertNil(legacy.uefaSuperCupWinner)
        XCTAssertEqual(legacy.cupWinner, user, "Original winner fields must still decode")

        let honours = [honour(GameStore.uefaCupName, label), honour(GameStore.leagueCupName, label)]
        XCTAssertEqual(LegacyArchive.clubHonours(history: [legacy], honours: honours, club: user), honours,
                       "Unknown winners in an older record keep the managed-season fallback")
        XCTAssertEqual(LegacyArchive.clubHonours(history: [legacy], honours: honours, club: "Other"), [])

        // A season recorded with the new shape and no winner for a competition
        // is a known result, so an honour for that competition is not inferred.
        let knownNoWinner = SeasonRecord(season: 1, label: label, userClub: user,
                                         userDivision: "First Division", userPosition: 2,
                                         champion: "Other", cupWinner: "—", euroWinner: "—",
                                         communityShieldWinner: "—", leagueCupWinner: "—",
                                         uefaCupWinner: "—", uefaSuperCupWinner: "—")
        XCTAssertEqual(LegacyArchive.clubHonours(history: [knownNoWinner], honours: honours, club: user), [])
    }

    // MARK: - Season completion idempotency

    func testRepeatedSeasonCompletionRecordsOneHistoryEntry() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Repeat Completion")
        let user = store.userClub.name
        let rivals = rivalNames(store)
        clearWinners(store)
        store.uefaCupWinnerName = rivals[0]
        store.recordSeasonHonours()
        let honourCount = store.careerHonours.count

        // A later result path re-runs season completion; the recorded season
        // must not be rewritten or duplicated.
        store.uefaCupWinnerName = user
        store.recordSeasonHonours()
        store.recordSeasonHonours()

        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.history.last?.uefaCupWinner, rivals[0])
        XCTAssertEqual(store.careerHonours.count, honourCount)
        XCTAssertFalse(store.careerHonours.contains(honour(GameStore.uefaCupName, try XCTUnwrap(store.history.last).label)))
    }

    func testQuickSimSeasonEndStoresAuthoritativeWinners() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Quick Sim Winners")
        let finishedSeason = store.season

        var matchdaysPlayed = 0
        while !store.isSeasonOver && matchdaysPlayed < 500 {
            store.playNextMatchday()
            matchdaysPlayed += 1
        }
        XCTAssertTrue(store.isSeasonOver, "Quick sim must reach season end")

        let records = store.history.filter { $0.season == finishedSeason }
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.cupWinner, store.cupWinnerName ?? "—")
        XCTAssertEqual(record.euroWinner, store.euroWinnerName ?? "—")
        XCTAssertEqual(record.communityShieldWinner, store.communityShieldWinnerName ?? "—")
        XCTAssertEqual(record.leagueCupWinner, store.leagueCupWinnerName ?? "—")
        XCTAssertEqual(record.uefaCupWinner, store.uefaCupWinnerName ?? "—")
        XCTAssertEqual(record.uefaSuperCupWinner, store.uefaSuperCupWinnerName ?? "—")

        store.recordSeasonHonours()
        XCTAssertEqual(store.history.filter { $0.season == finishedSeason }.count, 1,
                       "Repeating season completion after quick sim must not add a second record")
    }

    func testCalendarForceSimSeasonEndStoresOneRecordWithWinners() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Force Sim Winners")
        let finishedSeason = store.season

        await store.forceSimTo(date: Date.distantFuture)
        XCTAssertTrue(store.isSeasonOver, "Calendar FORCE SIM must reach season end")

        let records = store.history.filter { $0.season == finishedSeason }
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.cupWinner, store.cupWinnerName ?? "—")
        XCTAssertEqual(record.euroWinner, store.euroWinnerName ?? "—")
        XCTAssertEqual(record.communityShieldWinner, store.communityShieldWinnerName ?? "—")
        XCTAssertEqual(record.leagueCupWinner, store.leagueCupWinnerName ?? "—")
        XCTAssertEqual(record.uefaCupWinner, store.uefaCupWinnerName ?? "—")
        XCTAssertEqual(record.uefaSuperCupWinner, store.uefaSuperCupWinnerName ?? "—")

        store.recordSeasonHonours()
        await store.forceSimTo(date: Date.distantFuture)
        XCTAssertEqual(store.history.filter { $0.season == finishedSeason }.count, 1,
                       "Repeated FORCE SIM season completion must not add a second record")
    }
}
