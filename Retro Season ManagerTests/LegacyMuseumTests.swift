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

    // MARK: - archiveLegacyCareer() populates the new fields

    func testArchiveLegacyCareerPopulatesNewMuseumFields() async throws {
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

        store.returnToMenuAfterCareer()

        guard let info = LegacyArchive.all().first, let career = LegacyArchive.load(id: info.id) else {
            return XCTFail("Expected the career to be archived")
        }
        defer { LegacyArchive.remove(id: career.id) }

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
            sampleCareer(manager: "M1", club: "A", score: 100, trophies: ["League title"]),
            sampleCareer(manager: "M2", club: "B", score: 100, trophies: ["Cup", "League title"]),
        ]
        let tally = LegacyArchive.trophyTally(from: careers)
        XCTAssertEqual(tally.count, 3)
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
        let original = sampleCareer(manager: "Old Save", club: "Legacy FC", score: 300, trophies: ["Cup"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegacyCareer.self, from: data)

        XCTAssertEqual(decoded.managerName, "Old Save")
        XCTAssertEqual(decoded.careerHonours, ["Cup"])
        XCTAssertNil(decoded.topScorer)
        XCTAssertNil(decoded.topAppearances)
        XCTAssertNil(decoded.topMOTM)
        XCTAssertNil(decoded.recordWin)
        XCTAssertNil(decoded.bestSeason)
        XCTAssertNil(decoded.topTransfers)
        XCTAssertNil(decoded.frontPages)
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
