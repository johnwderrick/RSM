//
//  LegacyMuseumTests.swift
//  Retro Season ManagerTests
//
//  Guards item 7 of the improvement directive: the seven new structured
//  museum fields on LegacyCareer, their population in
//  archiveLegacyCareer(), the new pure cross-save LegacyArchive
//  aggregation functions, and — since this modifies an already-shipped
//  Codable struct — backward-compatible decoding of an "old-shaped"
//  archived career missing the new fields entirely.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegacyMuseumTests: XCTestCase {
    private var archiveRoot: URL!
    private var saveRoot: URL!

    override func setUp() {
        super.setUp()
        archiveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyMuseumTests-\(UUID().uuidString)", isDirectory: true)
        saveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyMuseumSaveTests-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - archiveLegacyCareer() populates the new fields

    func testArchiveLegacyCareerPopulatesNewMuseumFields() async throws {
        let existingArchiveIDs = Set(LegacyArchive.all().map(\.id))
        XCTAssertTrue(existingArchiveIDs.isEmpty, "Each Museum test must start in its isolated archive")
        let temporaryRoot = archiveRoot.appendingPathComponent("end-career-flow", isDirectory: true)
        let priorArchiveRoot = archiveRoot
        LegacyArchive.useIsolatedRootForTesting(temporaryRoot)
        defer { LegacyArchive.useIsolatedRootForTesting(priorArchiveRoot) }
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Museum Test")

        // archiveLegacyCareer() guards on `!history.isEmpty` — seed one
        // completed season directly rather than simulating a whole career.
        store.history = [SeasonRecord(season: 1, label: "2000/01", userClub: store.userClub.name,
                                       userDivision: "First Division", userPosition: 1,
                                       champion: store.userClub.name, cupWinner: "—",
                                       euroWinner: "—", communityShieldWinner: "—")]
        store.allTimeScorers = ["Test Striker": 42]
        store.allTimeAppearances = ["Test Keeper": 38]
        store.motmTally = ["Test Striker": 7]
        // The archive's best-win record is associated with clubs having
        // managed match records, so give this club an explicit record here.
        store.careerRecordByClub[store.userClub.name] = ClubCareerRecord(wins: 1)
        store.clubs[store.userClubIndex].recordWinMargin = 6
        store.clubs[store.userClubIndex].recordWinDescription = "7-1 (1 January 2001)"
        store.transferHistory = [
            TransferHistoryEntry(date: store.currentDate, playerName: "Big Sale", action: "Sold", otherClub: "Rival FC", fee: 20_000),
            TransferHistoryEntry(date: store.currentDate, playerName: "Big Signing", action: "Signed", otherClub: "Other FC", fee: 18_000),
        ]
        store.newspapers = [
            Newspaper(date: store.currentDate, season: 1, outlet: .national, masthead: "THE HERALD",
                      headline: "HISTORIC WIN", standfirst: "...", body: "...", category: .result, importance: .historic),
            Newspaper(date: store.currentDate, season: 1, outlet: .local, masthead: "THE ECHO",
                      headline: "Routine win", standfirst: "...", body: "...", category: .result, importance: .minor),
        ]

        store.endCareer()
        let activeSaveID = store.currentSaveID
        store.returnToMenuAfterCareer()
        // A repeated delivery after the menu transition must be a no-op.
        store.returnToMenuAfterCareer()

        let createdArchives = LegacyArchive.all().filter { !existingArchiveIDs.contains($0.id) }
        guard let info = createdArchives.first,
              let career = LegacyArchive.load(id: info.id) else {
            return XCTFail("Expected this test's career to be archived")
        }
        defer { LegacyArchive.remove(id: career.id) }

        XCTAssertEqual(createdArchives.count, 1, "The duplicate endCareer call must not create another archive")
        XCTAssertNil(store.currentSaveID, "Leaving the career clears the active save ID")
        if let activeSaveID {
            XCTAssertFalse(SaveSlots.all().contains { $0.id == activeSaveID }, "Leaving the career deletes its active save slot")
        }
        XCTAssertEqual(career.topScorer?.name, "Test Striker")
        XCTAssertEqual(career.topScorer?.value, 42)
        XCTAssertEqual(career.topAppearances?.name, "Test Keeper")
        XCTAssertEqual(career.topAppearances?.value, 38)
        XCTAssertEqual(career.topMOTM?.name, "Test Striker")
        XCTAssertEqual(career.recordWin?.value, 6)
        XCTAssertEqual(career.recordWin?.detail, "7-1 (1 January 2001)")
        XCTAssertEqual(career.bestSeason?.value, 1)
        XCTAssertEqual(career.topTransfers?.count, 2)
        XCTAssertTrue(career.topTransfers?.contains { $0.playerName == "Big Sale" } ?? false)
        // Only .major/.historic front pages are preserved — the .minor one shouldn't be.
        XCTAssertEqual(career.frontPages?.count, 1)
        XCTAssertEqual(career.frontPages?.first?.headline, "HISTORIC WIN")
    }

    // MARK: - LegacyArchive aggregation functions (pure)

    private func sampleCareer(manager: String, club: String, score: Int, trophies: [String] = [],
                               legends: [ClubLegend] = []) -> LegacyCareer {
        LegacyCareer(id: UUID(), managerName: manager, clubName: club, startYear: 2000, endYear: 2005,
                     seasonsManaged: 5, finalDivisionName: "First Division", careerHonours: trophies,
                     autobiography: "A career.", timeline: [], achievementUnlocks: [], careerAchievementPoints: 0,
                     clubLegends: legends, history: [], careerRecordByClub: [:], legacyScore: score,
                     legacyTier: .forScore(score), recordBook: [], archivedDate: Date())
    }

    private func sampleLegend(name: String, club: String, legendScore: Int) -> ClubLegend {
        ClubLegend(playerID: UUID(), name: name, position: .forward, nationality: "England", clubName: club,
                   joinedSeason: 1, retiredSeason: 5, finalAge: 34, appearances: 200, goals: 100, assists: 20,
                   cleanSheets: 0, averageRating: 7.2, seasonsAsCaptain: 2, trophiesWon: [], individualAwards: 1,
                   peakRating: 88, legendScore: legendScore, isGlobalLegend: legendScore >= 95, biography: "A legend.")
    }

    func testGreatestManagersSortsByLegacyScoreDescending() {
        let careers = [
            sampleCareer(manager: "Low", club: "A", score: 50),
            sampleCareer(manager: "High", club: "B", score: 500),
            sampleCareer(manager: "Mid", club: "C", score: 200),
        ]
        let ranked = LegacyArchive.greatestManagers(from: careers, limit: 2)
        XCTAssertEqual(ranked.map { $0.managerName }, ["High", "Mid"])
    }

    func testGreatestPlayersFlattensAndSortsByLegendScore() {
        let careers = [
            sampleCareer(manager: "M1", club: "A", score: 100, legends: [sampleLegend(name: "Star", club: "A", legendScore: 90)]),
            sampleCareer(manager: "M2", club: "B", score: 100, legends: [sampleLegend(name: "Icon", club: "B", legendScore: 97),
                                                                          sampleLegend(name: "Bench", club: "B", legendScore: 40)]),
        ]
        let wall = LegacyArchive.greatestPlayers(from: careers, limit: 2)
        XCTAssertEqual(wall.map { $0.legend.name }, ["Icon", "Star"])
        XCTAssertEqual(wall.first?.career, "M2 at B")
    }

    func testTrophyTallyFlattensEveryCareersHonours() {
        let careers = [
            sampleCareer(manager: "M1", club: "A", score: 100, trophies: ["🏆 League title"]),
            sampleCareer(manager: "M2", club: "B", score: 100, trophies: ["🏆 Cup", "🏆 League title"]),
        ]
        let tally = LegacyArchive.trophyTally(from: careers)
        XCTAssertEqual(tally.count, 3)
        XCTAssertEqual(LegacyArchive.trophyCount(careers[0]), 1)
        XCTAssertEqual(LegacyArchive.trophyCount(careers[1]), 2)
    }

    func testGlobalBestSeasonPicksTheLowestPosition() {
        let careers = [
            sampleCareer(manager: "M1", club: "A", score: 100)
                .withBestSeason(LegacyRecordHolder(name: "A", value: 3, detail: "First Division · 2002/03")),
            sampleCareer(manager: "M2", club: "B", score: 100)
                .withBestSeason(LegacyRecordHolder(name: "B", value: 1, detail: "First Division · 2003/04")),
        ]
        let best = LegacyArchive.globalBestSeason(from: careers)
        XCTAssertEqual(best?.holder.name, "B")
        XCTAssertEqual(best?.holder.value, 1)
    }

    // MARK: - Backward compatibility

    func testOldShapedArchiveWithoutNewFieldsStillDecodes() throws {
        // The seven new fields default to nil in the memberwise init, and
        // JSONEncoder's synthesized encoding omits nil Optional keys
        // entirely — so this round-trip is exactly what decoding a career
        // archived before this update looks like.
        let original = sampleCareer(manager: "Old Save", club: "Legacy FC", score: 300, trophies: ["🏆 Cup"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegacyCareer.self, from: data)

        XCTAssertEqual(decoded.managerName, "Old Save")
        XCTAssertEqual(decoded.careerHonours, ["🏆 Cup"])
        XCTAssertNil(decoded.topScorer)
        XCTAssertNil(decoded.topAppearances)
        XCTAssertNil(decoded.topMOTM)
        XCTAssertNil(decoded.recordWin)
        XCTAssertNil(decoded.bestSeason)
        XCTAssertNil(decoded.topTransfers)
        XCTAssertNil(decoded.frontPages)
    }

    func testArchiveWithSameIDTwiceKeepsOneMuseumEntryAndRefreshesSnapshot() {
        let id = UUID()
        let titleHistory = [SeasonRecord(season: 1, label: "2000/01", userClub: "A",
                                         userDivision: "First Division", userPosition: 1, champion: "A",
                                         cupWinner: "—", euroWinner: "—", communityShieldWinner: "—")]
        let first = LegacyCareer(id: id, managerName: "First Snapshot", clubName: "A",
                                 startYear: 2000, endYear: 2001, seasonsManaged: 1,
                                 finalDivisionName: "First Division",
                                 careerHonours: ["First Division title (2000/01)"],
                                 autobiography: "First snapshot.", timeline: [], achievementUnlocks: [],
                                 careerAchievementPoints: 0, clubLegends: [], history: titleHistory,
                                 careerRecordByClub: [:], legacyScore: 100, legacyTier: .journeyman,
                                 recordBook: [], archivedDate: Date())
        LegacyArchive.archive(first)
        let updated = LegacyCareer(id: id, managerName: "Updated Snapshot", clubName: "B",
                                   startYear: 2001, endYear: 2002, seasonsManaged: 1,
                                   finalDivisionName: "Second Division", careerHonours: ["⬆︎ Promoted (2001/02)"],
                                   autobiography: "Updated.", timeline: [], achievementUnlocks: [],
                                   careerAchievementPoints: 25, clubLegends: [],
                                   history: [SeasonRecord(season: 1, label: "2001/02", userClub: "B",
                                                          userDivision: "Second Division", userPosition: 1,
                                                          champion: "B", cupWinner: "—", euroWinner: "—",
                                                          communityShieldWinner: "—")],
                                   careerRecordByClub: ["B": ClubCareerRecord(wins: 2)],
                                   legacyScore: 200, legacyTier: .accomplished, recordBook: [], archivedDate: Date())
        LegacyArchive.archive(updated)
        defer { LegacyArchive.remove(id: id) }
        _ = LegacyArchive.refreshedIndex()

        XCTAssertEqual(LegacyArchive.all().filter { $0.id == id }.count, 1,
                       "An archive ID can appear only once in the Museum index")
        XCTAssertEqual(LegacyArchive.all().first { $0.id == id }?.managerName, "First Snapshot",
                       "A repeated archive callback must preserve the original career snapshot")
        XCTAssertEqual(LegacyArchive.load(id: id)?.careerHonours, first.careerHonours)
        XCTAssertEqual(LegacyArchive.refreshedIndex().first { $0.id == id }?.trophyCount, 1)
        XCTAssertEqual(LegacyArchive.clubHonours(first, club: "A"), first.careerHonours,
                       "Unprefixed archived silverware still attributes to its club")
    }

    func testMatchRecordsAndMuseumBreakdownsCombineMultipleClubsAndRepeatStints() throws {
        let seasonHistory = [
            SeasonRecord(season: 1, label: "2000/01", userClub: "A", userDivision: "Second Division",
                         userPosition: 1, champion: "A", cupWinner: "—", euroWinner: "—", communityShieldWinner: "—"),
            SeasonRecord(season: 2, label: "2001/02", userClub: "B", userDivision: "First Division",
                         userPosition: 14, champion: "C", cupWinner: "—", euroWinner: "—", communityShieldWinner: "—"),
            SeasonRecord(season: 3, label: "2002/03", userClub: "A", userDivision: "First Division",
                         userPosition: 4, champion: "C", cupWinner: "A", euroWinner: "—", communityShieldWinner: "—"),
        ]
        let honours = [
            "🏆 Second Division title (2000/01)", "⬆︎ Promoted from Second Division (2000/01)",
            "🏆 National Cup (2002/03)", "🏆 A title (1999/00)",
        ]
        let records = [
            "A": ClubCareerRecord(wins: 25, draws: 10, losses: 5, goalsFor: 62, goalsAgainst: 24,
                                  homeWins: 14, homeDraws: 4, homeLosses: 2, awayWins: 11, awayDraws: 6, awayLosses: 3),
            "B": ClubCareerRecord(wins: 2, draws: 3, losses: 4, goalsFor: 11, goalsAgainst: 17,
                                  homeWins: 1, homeDraws: 2, homeLosses: 2, awayWins: 1, awayDraws: 1, awayLosses: 2),
        ]
        let career = LegacyCareer(id: UUID(), managerName: "Multi Club", clubName: "A",
                                  startYear: 2000, endYear: 2003, seasonsManaged: 3,
                                  finalDivisionName: "First Division", careerHonours: honours,
                                  autobiography: "Three spells.", timeline: [], achievementUnlocks: [],
                                  careerAchievementPoints: 15, clubLegends: [], history: seasonHistory,
                                  careerRecordByClub: records, legacyScore: 300, legacyTier: .distinguished,
                                  recordBook: [], archivedDate: Date())
        LegacyArchive.archive(career)
        defer { LegacyArchive.remove(id: career.id) }

        let roundTripped = try XCTUnwrap(LegacyArchive.load(id: career.id))
        let totals = LegacyArchive.matchSummary(roundTripped)
        XCTAssertEqual(totals.matches, 49)
        XCTAssertEqual(totals.wins, 27)
        XCTAssertEqual(totals.draws, 13)
        XCTAssertEqual(totals.losses, 9)
        XCTAssertEqual(totals.goalsFor, 73)
        XCTAssertEqual(totals.goalsAgainst, 41)
        XCTAssertEqual(LegacyArchive.clubRecords(roundTripped).map(\.club), ["A", "B"])
        XCTAssertEqual(LegacyArchive.clubHonours(roundTripped, club: "A"), Array(honours.prefix(3)))
        XCTAssertEqual(LegacyArchive.clubHonours(roundTripped, club: "B"), [])
        let clubA = try XCTUnwrap(LegacyArchive.clubRecords(roundTripped).first { $0.club == "A" })
        XCTAssertEqual(clubA.record.wins, 25)
        XCTAssertEqual(clubA.record.goalsFor, 62)
        XCTAssertEqual(LegacyArchive.clubHonours(roundTripped, club: "A").count, 3)
        XCTAssertEqual(LegacyArchive.trophyCount(roundTripped), 3)
        XCTAssertEqual(LegacyArchive.trophyTally(from: [roundTripped]).count, 3)
    }

    func testSparseLegacyCareerHasNoInventedRecordsOrTrophies() {
        let sparse = sampleCareer(manager: "Sparse", club: "Legacy FC", score: 0,
                                  trophies: ["⬆︎ Promoted from Second Division (2000/01)"])
        let totals = LegacyArchive.matchSummary(sparse)
        XCTAssertEqual(totals.matches, 0)
        XCTAssertEqual(totals.wins, 0)
        XCTAssertEqual(totals.draws, 0)
        XCTAssertEqual(totals.losses, 0)
        XCTAssertEqual(totals.goalsFor, 0)
        XCTAssertEqual(totals.goalsAgainst, 0)
        XCTAssertTrue(LegacyArchive.clubRecords(sparse).isEmpty)
        XCTAssertEqual(LegacyArchive.trophyCount(sparse), 0)
        XCTAssertTrue(LegacyArchive.trophyTally(from: [sparse]).isEmpty)
    }

    func testActiveCareerMatchStatsCreditOnceAcrossLiveQuickSimAndForceSimAndReload() async throws {
        let previousSaveRoot = SaveSlots.isolatedRootForTesting
        let previousArchiveRoot = archiveRoot
        let temporarySaveRoot = saveRoot.appendingPathComponent("active-match-records", isDirectory: true)
        SaveSlots.useIsolatedRootForTesting(temporarySaveRoot)
        LegacyArchive.useIsolatedRootForTesting(temporarySaveRoot.appendingPathComponent("legacy", isDirectory: true))
        defer {
            SaveSlots.useIsolatedRootForTesting(previousSaveRoot)
            LegacyArchive.useIsolatedRootForTesting(previousArchiveRoot)
        }
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Record Attribution")
        let saveID = try XCTUnwrap(store.currentSaveID)
        defer { GameStore.deleteSave(id: saveID) }

        let liveFixtureIndex = try XCTUnwrap(store.fixtures.firstIndex {
            !$0.played && ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
        })
        let liveFixture = store.fixtures[liveFixtureIndex]
        let userIsHome = liveFixture.homeIndex == store.userClubIndex
        let opponentIndex = userIsHome ? liveFixture.awayIndex : liveFixture.homeIndex
        let day = liveFixture.matchday
        store.currentMatchday = day
        store.currentDate = store.date(forMatchday: day)
        let userWinBeforeLive = store.careerRecordByClub[store.userClub.name]?.wins ?? 0
        store.beginUserMatch()
        let live = try XCTUnwrap(store.live)
        live.skipToEnd()
        let expectedUserGoals = userIsHome ? live.homeGoals : live.awayGoals
        let expectedOpponentGoals = userIsHome ? live.awayGoals : live.homeGoals
        store.finishLiveMatch()
        XCTAssertTrue(store.persist())
        let recordAfterLive = try XCTUnwrap(store.careerRecordByClub[store.userClub.name])
        XCTAssertEqual(recordAfterLive.matches, 1)
        XCTAssertEqual(recordAfterLive.goalsFor, expectedUserGoals)
        XCTAssertEqual(recordAfterLive.goalsAgainst, expectedOpponentGoals)
        XCTAssertEqual(store.careerRecordByClub[store.clubs[opponentIndex].name]?.matches, nil,
                       "The opponent must not be credited as managed by the user")

        store.currentDate = store.date(forMatchday: day + 1)
        let quickFixtureIndex = try XCTUnwrap(store.fixtures.firstIndex {
            !$0.played && ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
        })
        let quickFixture = store.fixtures[quickFixtureIndex]
        store.currentMatchday = quickFixture.matchday
        let userIndex = store.userClubIndex
        let beforeQuick = store.careerRecordByClub[store.userClub.name] ?? ClubCareerRecord()
        store.playNextMatchday()
        XCTAssertTrue(store.persist())
        let quickUpdated = store.fixtures[quickFixtureIndex]
        let quickUserGoals = quickUpdated.homeIndex == userIndex ? quickUpdated.homeGoals : quickUpdated.awayGoals
        let quickOpponentGoals = quickUpdated.homeIndex == userIndex ? quickUpdated.awayGoals : quickUpdated.homeGoals
        let afterQuick = try XCTUnwrap(store.careerRecordByClub[store.userClub.name])
        XCTAssertEqual(afterQuick.matches, beforeQuick.matches + 1)
        XCTAssertEqual(afterQuick.goalsFor, beforeQuick.goalsFor + quickUserGoals)
        XCTAssertEqual(afterQuick.goalsAgainst, beforeQuick.goalsAgainst + quickOpponentGoals)

        let forceFixtureIndex = try XCTUnwrap(store.fixtures.firstIndex {
            !$0.played && ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
        })
        let forceFixture = store.fixtures[forceFixtureIndex]
        store.currentMatchday = forceFixture.matchday
        store.currentDate = store.date(forMatchday: forceFixture.matchday)
        let beforeForce = store.careerRecordByClub[store.userClub.name] ?? ClubCareerRecord()
        store.forceResolveLeagueDay()
        XCTAssertTrue(store.persist())
        let forced = store.fixtures[forceFixtureIndex]
        let forceUserGoals = forced.homeIndex == userIndex ? forced.homeGoals : forced.awayGoals
        let forceOpponentGoals = forced.homeIndex == userIndex ? forced.awayGoals : forced.homeGoals
        let afterForce = try XCTUnwrap(store.careerRecordByClub[store.userClub.name])
        XCTAssertEqual(afterForce.matches, beforeForce.matches + 1)
        XCTAssertEqual(afterForce.goalsFor, beforeForce.goalsFor + forceUserGoals)
        XCTAssertEqual(afterForce.goalsAgainst, beforeForce.goalsAgainst + forceOpponentGoals)
        XCTAssertGreaterThanOrEqual(afterForce.wins, userWinBeforeLive)

        let expectedRecord = afterForce
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
        XCTAssertEqual(reloaded.careerRecordByClub[store.userClub.name], expectedRecord,
                       "Match W/D/L, home/away and goal totals round-trip through real persistence")
    }

    func testOldClubCareerRecordDecodesWithMissingNewCounters() throws {
        let json = Data("{\"wins\":7,\"draws\":3,\"losses\":2,\"homeWins\":4}".utf8)
        let record = try JSONDecoder().decode(ClubCareerRecord.self, from: json)
        XCTAssertEqual(record.matches, 12)
        XCTAssertEqual(record.goalsFor, 0)
        XCTAssertEqual(record.goalsAgainst, 0)
        XCTAssertEqual(record.homeMatches, 4)
        XCTAssertEqual(record.awayMatches, 0)
    }

    func testDuplicateSeasonLabelsDoNotMakeAClubClaimAnotherClubsHonour() {
        let history = [
            SeasonRecord(season: 1, label: "2000/01", userClub: "A", userDivision: "Second Division",
                         userPosition: 1, champion: "A", cupWinner: "—", euroWinner: "—", communityShieldWinner: "—"),
            SeasonRecord(season: 2, label: "2000/01", userClub: "B", userDivision: "First Division",
                         userPosition: 4, champion: "C", cupWinner: "A", euroWinner: "—", communityShieldWinner: "—"),
        ]
        let honours = ["🏆 Second Division title (2000/01)"]
        XCTAssertEqual(LegacyArchive.clubHonours(history: history, honours: honours, club: "A").count, 1)
        XCTAssertTrue(LegacyArchive.clubHonours(history: history, honours: honours, club: "B").isEmpty)

        let nonChampionHistory = [
            SeasonRecord(season: 1, label: "2000/01", userClub: "A", userDivision: "Second Division",
                         userPosition: 1, champion: "C", cupWinner: "—", euroWinner: "—", communityShieldWinner: "—"),
        ]
        XCTAssertTrue(LegacyArchive.clubHonours(history: nonChampionHistory, honours: honours, club: "A").isEmpty,
                      "A club must not receive a division title when the season champion is another club")
    }

    func testMidweekCupHonoursDoNotDependOnContinentalCupWinner() async {
        let store = await makeTestStore()
        for continentalWinner in ["Other Club", "—"] {
            store.history = [
                SeasonRecord(season: 1, label: "2000/01", userClub: "A", userDivision: "First Division",
                             userPosition: 5, champion: "Other Club", cupWinner: "—",
                             euroWinner: continentalWinner, communityShieldWinner: "—"),
                SeasonRecord(season: 2, label: "2001/02", userClub: "B", userDivision: "First Division",
                             userPosition: 2, champion: "Other Club", cupWinner: "—",
                             euroWinner: "B", communityShieldWinner: "—"),
                SeasonRecord(season: 3, label: "2002/03", userClub: "A", userDivision: "First Division",
                             userPosition: 4, champion: "Other Club", cupWinner: "—",
                             euroWinner: continentalWinner, communityShieldWinner: "—"),
            ]
            let firstHonour = "🏆 \(GameStore.uefaCupName) (2000/01)"
            let secondHonour = "🏆 \(GameStore.euroName) (2001/02)"
            let returningHonour = "🏆 \(GameStore.uefaCupName) (2002/03)"
            store.careerHonours = [firstHonour, secondHonour, returningHonour]

            XCTAssertEqual(LegacyArchive.clubHonours(history: store.history,
                honours: store.careerHonours, club: "A"), [firstHonour, returningHonour],
                "Midweek Cup wins must remain credited when the separate Continental Cup winner differs or is absent")
            XCTAssertEqual(LegacyArchive.clubHonours(history: store.history,
                honours: store.careerHonours, club: "B"), [secondHonour])
            let cv = store.managerCV()
            XCTAssertEqual(cv.map(\.club), ["A", "B", "A"])
            XCTAssertEqual(cv.map(\.trophies), [[firstHonour], [secondHonour], [returningHonour]],
                           "Each CV stint must retain only its own competition honours")
        }
    }

    func testMuseumHonourTallyExcludesPromotionFromTrophyTotals() {
        let modern = sampleCareer(manager: "Promotion", club: "A", score: 100,
                                  trophies: ["🏆 League title (2000/01)", "⬆︎ Promoted from Second Division (2001/02)"])
        XCTAssertEqual(LegacyArchive.trophyCount(modern), 1)
        XCTAssertEqual(LegacyArchive.trophyTally(from: [modern]).count, 1)

        let legacy = sampleCareer(manager: "Legacy Honours", club: "B", score: 100,
                                  trophies: ["Cup", "Promoted from Second Division"])
        XCTAssertEqual(LegacyArchive.trophyCount(legacy), 1,
                       "Pre-prefix silverware stays a trophy; only promotion text is excluded")
        XCTAssertEqual(LegacyArchive.trophyTally(from: [legacy]).map(\.honour), ["Cup"])
    }
}

private extension LegacyCareer {
    /// Test-only helper for building a career with just `bestSeason` set,
    /// without repeating every other field at each call site.
    func withBestSeason(_ holder: LegacyRecordHolder) -> LegacyCareer {
        LegacyCareer(id: id, managerName: managerName, clubName: clubName, startYear: startYear, endYear: endYear,
                     seasonsManaged: seasonsManaged, finalDivisionName: finalDivisionName, careerHonours: careerHonours,
                     autobiography: autobiography, timeline: timeline, achievementUnlocks: achievementUnlocks,
                     careerAchievementPoints: careerAchievementPoints, clubLegends: clubLegends, history: history,
                     careerRecordByClub: careerRecordByClub, legacyScore: legacyScore, legacyTier: legacyTier,
                     recordBook: recordBook, archivedDate: archivedDate, bestSeason: holder)
    }
}
