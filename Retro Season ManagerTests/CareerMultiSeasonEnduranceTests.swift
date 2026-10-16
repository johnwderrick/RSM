import XCTest
@testable import Retro_Season_Manager

/// Fast regressions run normally. The real three-season audit is opt-in:
/// TEST_RUNNER_RSM_RUN_ENDURANCE=1 xcodebuild test ...
/// Engine results remain random; assertions use invariants, not scorelines.
@MainActor
final class CareerMultiSeasonEnduranceTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("RSMEndurance-\(UUID().uuidString)")
        SaveSlots.useIsolatedRootForTesting(root)
        LegacyArchive.useIsolatedRootForTesting(root.appendingPathComponent("legacy"))
        print("ENDURANCE isolated reproduction root: \(root.path)")
    }

    override func tearDown() {
        SaveSlots.useIsolatedRootForTesting(nil)
        LegacyArchive.useIsolatedRootForTesting(nil)
        if testRun?.failureCount == 0 { try? FileManager.default.removeItem(at: root) }
        else { print("ENDURANCE retained checkpoint files: \(root.path)") }
        super.tearDown()
    }

    func testValidateRolesRemovesOnlyDepartedStartersAndIsIdempotent() async throws {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Starter Pruning")
        let departed = store.clubs[store.userClubIndex].players.removeFirst()
        store.clubs[1].players.append(departed)
        let retained = try XCTUnwrap(store.userClub.players.first?.id)
        store.userStarterIDs = [departed.id, retained]
        store.captainID = departed.id
        store.penaltyTakerID = departed.id
        store.freeKickTakerID = departed.id
        store.cornerTakerID = departed.id
        let budget = store.userClub.transferBudget
        for _ in 0..<2 {
            store.validateRoles()
            XCTAssertEqual(store.userStarterIDs, [retained], "Pruning must not select extra players or retain a departed starter")
            assertLineupAndRolesValid(store, context: "focused pruning")
            XCTAssertEqual(store.userClub.transferBudget, budget)
        }
    }

    func testDailyTickMarqueeTransferPrunesStarterAndReloadKeepsItPruned() async throws {
        let entry = try XCTUnwrap(MarqueePlayers.transfers.first { $0.name == "Solomon Camwell" })
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Dated Transfer")
        let destination = try XCTUnwrap(store.clubs.firstIndex { $0.name == entry.toClub })
        XCTAssertNotEqual(destination, store.userClubIndex)
        // Pin the dated event's source identity, without depending on how
        // earlier random transfers distributed this named player.
        for index in store.clubs.indices where index != store.userClubIndex {
            store.clubs[index].players.removeAll { $0.name == entry.name }
        }
        store.clubs[store.userClubIndex].players[0] = GameStore.makePlayer(
            name: entry.name, position: .defender, nationality: "England", age: 22, rating: 70, startYear: store.startYear)
        let departing = store.userClub.players[0].id
        store.userStarterIDs = [departing, store.userClub.players[1].id]
        store.captainID = departing
        store.currentDate = try XCTUnwrap(GameStore.calendar.date(from:
            DateComponents(year: entry.year, month: entry.month, day: entry.day)))
        suppressOtherMarqueeEvents(store, except: "marqueeTransfer-\(entry.name)-\(entry.toClub)")
        store.dailyTick()
        XCTAssertTrue(store.clubs[destination].players.contains { $0.id == departing })
        XCTAssertFalse(store.userStarterIDs.contains(departing))
        assertLineupAndRolesValid(store, context: "dated transfer")
        let reloaded = try await checkpoint(store, label: "dated transfer")
        XCTAssertFalse(reloaded.userStarterIDs.contains(departing))
        reloaded.dailyTick()
        XCTAssertEqual(reloaded.clubs.flatMap(\.players).filter { $0.id == departing }.count, 1)
    }

    func testDailyTickMarqueeArrivalPrunesTheReplacedStarter() async throws {
        let entry = try XCTUnwrap(MarqueePlayers.arrivals.first)
        let catalogue = GameStore.catalogueEntries()
        let index = try XCTUnwrap(catalogue.firstIndex { $0.name == entry.club })
        let store = await makeTestStore()
        store.newGame(clubIndex: index, startYear: entry.year, managerName: "Dated Arrival")
        let playerIndex = try XCTUnwrap(store.userClub.players.firstIndex { $0.position == entry.detailedPosition.broad })
        store.clubs[store.userClubIndex].players[playerIndex].rating = 1
        let replaced = store.userClub.players[playerIndex].id
        store.userStarterIDs = [replaced]
        store.captainID = replaced
        store.currentDate = try XCTUnwrap(GameStore.calendar.date(from:
            DateComponents(year: entry.year, month: entry.month, day: entry.day)))
        suppressOtherMarqueeEvents(store, except: "marqueeArrival-\(entry.name)")
        store.dailyTick()
        XCTAssertFalse(store.userClub.players.contains { $0.id == replaced })
        XCTAssertTrue(store.userClub.players.contains { $0.name == entry.name })
        XCTAssertFalse(store.userStarterIDs.contains(replaced))
        assertLineupAndRolesValid(store, context: "dated arrival")
    }

    func testMultiSeasonCareerWithClubSwitchKeepsRolesAndSquadsValid() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RSM_RUN_ENDURANCE"] == "1",
                          "Opt-in: TEST_RUNNER_RSM_RUN_ENDURANCE=1")
        var store = await makeTestStore()
        // A real three-season career reaches the actual career-end boundary.
        store.newGame(clubIndex: 0, startYear: GameStore.careerEndYear - 3, managerName: "Endurance Test")
        let originalClubID = store.userClub.id
        var managedClubIDs: [UUID] = []
        var usedLive = 0, usedQuick = 0, usedForce = 0
        var sawPromotionOrRelegation = false
        for season in 1...3 {
            XCTAssertEqual(store.season, season)
            let managedID = store.userClub.id
            managedClubIDs.append(managedID)
            let managedName = store.userClub.name
            let startingRecord = store.careerRecordByClub[managedName] ?? ClubCareerRecord()
            let ledgerBase = store.seasonLedger.reduce(0) { $0 + $1.amount }
            let budgetBase = store.userClub.transferBudget
            var steps = 0, leagueCommits = 0
            var midseasonReloaded = false
            while !store.isSeasonOver && steps < 500 {
                let beforeDate = store.currentDate
                let beforeDay = store.currentMatchday
                if store.isUserMatchToday {
                    if store.isUserLeagueToday && leagueCommits % 3 == 0 {
                        store.beginUserMatch()
                        let live = try XCTUnwrap(store.live)
                        // Real simulation, including the full-time commit.
                        live.skipToEnd()
                        store.finishLiveMatch()
                        let budget = store.userClub.transferBudget
                        let ledgerIDs = store.seasonLedger.map(\.id)
                        store.finishLiveMatch()
                        XCTAssertEqual(store.userClub.transferBudget, budget)
                        XCTAssertEqual(store.seasonLedger.map(\.id), ledgerIDs)
                        usedLive += 1
                    } else if store.isUserLeagueToday && leagueCommits % 3 == 1 {
                        store.playNextMatchday()
                        usedQuick += 1
                    } else {
                        store.resolveTodaysUserMatchAbstractly()
                        usedForce += 1
                    }
                } else {
                    store.advanceDay()
                }
                if store.currentMatchday > beforeDay { leagueCommits += 1 }
                XCTAssertTrue(store.isSeasonOver || store.currentDate > beforeDate || store.currentMatchday > beforeDay,
                              "No calendar progress: season \(season), step \(steps), \(beforeDate)")
                XCTAssertGreaterThanOrEqual(store.daysUntilNextMatch ?? 0, 0)
                XCTAssertEqual(store.userClub.transferBudget - budgetBase,
                               store.seasonLedger.reduce(0) { $0 + $1.amount } - ledgerBase,
                               "Unreconciled budget change: season \(season), step \(steps)")
                assertLineupAndRolesValid(store, context: "season \(season), step \(steps)")
                if !midseasonReloaded && store.currentMatchday >= store.totalMatchdays / 2 {
                    store = try await checkpoint(store, label: "mid-season \(season)")
                    midseasonReloaded = true
                }
                steps += 1
            }
            XCTAssertTrue(store.isSeasonOver, "Season \(season) exceeded 500 transitions")
            XCTAssertTrue(midseasonReloaded)
            XCTAssertTrue(store.fixtures.allSatisfy(\.played))
            XCTAssertEqual(store.userClub.played, store.totalMatchdays)
            assertSquadsValid(store, context: "season \(season) complete")
            let record = try XCTUnwrap(store.careerRecordByClub[managedName])
            XCTAssertEqual(record.matches - startingRecord.matches, store.totalMatchdays,
                           "Career match totals must match the managed league fixtures")
            let matches = store.fixtures.filter { $0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex }
            let scored = matches.reduce(0) { $0 + ($1.homeIndex == store.userClubIndex ? $1.homeGoals : $1.awayGoals) }
            let conceded = matches.reduce(0) { $0 + ($1.homeIndex == store.userClubIndex ? $1.awayGoals : $1.homeGoals) }
            XCTAssertEqual(record.goalsFor - startingRecord.goalsFor, scored)
            XCTAssertEqual(record.goalsAgainst - startingRecord.goalsAgainst, conceded)
            let history = try XCTUnwrap(store.history.last)
            XCTAssertEqual(history.userClub, managedName)
            XCTAssertEqual(history.cupWinner, store.cupWinnerName ?? "—")
            XCTAssertEqual(history.euroWinner, store.euroWinnerName ?? "—")
            XCTAssertEqual(history.leagueCupWinner, store.leagueCupWinnerName ?? "—")
            XCTAssertEqual(history.uefaCupWinner, store.uefaCupWinnerName ?? "—")
            XCTAssertEqual(history.communityShieldWinner, store.communityShieldWinnerName ?? "—")
            XCTAssertEqual(history.uefaSuperCupWinner, store.uefaSuperCupWinnerName ?? "—")
            let prizes = store.seasonLedger.filter { $0.category == "Prize money" }
            XCTAssertEqual(Set(prizes.map(\.detail)).count, prizes.count, "A competition must pay its prize once")
            let honours = store.careerHonours
            store.recordSeasonHonours()
            XCTAssertEqual(store.history.count, season)
            XCTAssertEqual(store.careerHonours, honours)
            store = try await checkpoint(store, label: "season review \(season)")
            if season < 3 {
                let target = season == 1
                    ? try XCTUnwrap(store.clubs.indices.first { store.clubs[$0].id != managedID && store.clubs[$0].divisionTier < 4 })
                    : try XCTUnwrap(store.clubs.firstIndex { $0.id == originalClubID })
                let destinationID = store.clubs[target].id
                store.pendingJobOffers = [JobOffer(clubIndex: target, clubName: store.clubs[target].name,
                    divisionName: store.divisionName(store.clubs[target].divisionTier), prestige: store.clubs[target].prestige,
                    transferBudget: store.clubs[target].transferBudget, expectedObjective: store.previewObjective(forClubIndex: target))]
                store.acceptJobOffer(store.pendingJobOffers[0])
                store = try await checkpoint(store, label: "accepted job \(season)")
                XCTAssertEqual(store.pendingClubSwitch, target)
                let tiers = Dictionary(uniqueKeysWithValues: store.clubs.map { ($0.id, $0.divisionTier) })
                store.startNextSeason()
                sawPromotionOrRelegation = sawPromotionOrRelegation || store.clubs.contains { tiers[$0.id] != $0.divisionTier }
                XCTAssertEqual(store.userClub.id, destinationID)
                XCTAssertEqual(store.season, season + 1)
                store.startNextSeason()
                XCTAssertEqual(store.season, season + 1, "Duplicate rollover must not advance again")
                store = try await checkpoint(store, label: "rollover \(season)")
            }
        }
        XCTAssertEqual(managedClubIDs.first, managedClubIDs.last)
        XCTAssertNotEqual(managedClubIDs[0], managedClubIDs[1])
        XCTAssertTrue(sawPromotionOrRelegation)
        XCTAssertGreaterThan(usedLive, 0); XCTAssertGreaterThan(usedQuick, 0); XCTAssertGreaterThan(usedForce, 0)
        XCTAssertTrue(store.isFinalSeason)
        store.startNextSeason()
        XCTAssertTrue(store.careerEnded)
        let id = try XCTUnwrap(store.currentSaveID)
        let historyData = try encoded(store.history)
        let honours = store.careerHonours
        let records = store.careerRecordByClub
        XCTAssertTrue(store.returnToMenuAfterCareer())
        XCTAssertTrue(store.returnToMenuAfterCareer())
        XCTAssertFalse(FileManager.default.fileExists(atPath: SaveSlots.fileURL(for: id).path))
        XCTAssertEqual(LegacyArchive.all().map(\.id), [id])
        let archive = try XCTUnwrap(LegacyArchive.load(id: id))
        XCTAssertEqual(try encoded(archive.history), historyData)
        XCTAssertEqual(archive.careerHonours, honours)
        XCTAssertEqual(archive.careerRecordByClub, records)
        let summary = LegacyArchive.matchSummary(archive)
        XCTAssertEqual(summary.matches, records.values.reduce(0) { $0 + $1.matches })
        XCTAssertEqual(summary.goalsFor, records.values.reduce(0) { $0 + $1.goalsFor })
        print("ENDURANCE completed 3 seasons; live=\(usedLive), quick=\(usedQuick), force=\(usedForce); checkpoints and one archive verified")
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func checkpoint(_ store: GameStore, label: String) async throws -> GameStore {
        // Loading intentionally repairs recognised players' nationalities.
        // Apply that documented migration before comparing the full snapshot.
        store.repairKnownPlayerNationalities()
        XCTAssertTrue(store.persist(), label)
        let id = try XCTUnwrap(store.currentSaveID)
        print("ENDURANCE checkpoint \(label): save=\(id), season=\(store.season), date=\(store.currentDate), club=\(store.userClub.name)")
        let loaded = await makeTestStore()
        XCTAssertTrue(loaded.loadSavedGame(id: id), label)
        XCTAssertEqual(loaded.currentSaveID, id, label)
        XCTAssertEqual(loaded.season, store.season, label)
        XCTAssertEqual(loaded.currentMatchday, store.currentMatchday, label)
        XCTAssertEqual(loaded.currentDate, store.currentDate, label)
        let beforeClubs = try encoded(store.clubs)
        let afterClubs = try encoded(loaded.clubs)
        if beforeClubs != afterClubs {
            try beforeClubs.write(to: root.appendingPathComponent("clubs-before.json"))
            try afterClubs.write(to: root.appendingPathComponent("clubs-after.json"))
        }
        XCTAssertEqual(afterClubs, beforeClubs, label)
        XCTAssertEqual(try encoded(loaded.fixtures), try encoded(store.fixtures), label)
        XCTAssertEqual(try encoded(loaded.history), try encoded(store.history), label)
        XCTAssertEqual(loaded.careerHonours, store.careerHonours, label)
        XCTAssertEqual(loaded.careerRecordByClub, store.careerRecordByClub, label)
        XCTAssertEqual(loaded.seasonLedger.map(\.id), store.seasonLedger.map(\.id), label)
        XCTAssertEqual(loaded.userStarterIDs, store.userStarterIDs, label)
        XCTAssertEqual(loaded.pendingClubSwitch, store.pendingClubSwitch, label)
        XCTAssertEqual(try encoded(loaded.pendingJobOffers), try encoded(store.pendingJobOffers), label)
        XCTAssertEqual(loaded.captainID, store.captainID, label)
        XCTAssertEqual(loaded.penaltyTakerID, store.penaltyTakerID, label)
        XCTAssertEqual(loaded.freeKickTakerID, store.freeKickTakerID, label)
        XCTAssertEqual(loaded.cornerTakerID, store.cornerTakerID, label)
        return loaded
    }

    private func suppressOtherMarqueeEvents(_ store: GameStore, except event: String) {
        for entry in MarqueePlayers.arrivals { store.firedDatedEventIDs.insert("marqueeArrival-\(entry.name)") }
        for entry in MarqueePlayers.transfers { store.firedDatedEventIDs.insert("marqueeTransfer-\(entry.name)-\(entry.toClub)") }
        store.firedDatedEventIDs.remove(event)
    }

    private func assertLineupAndRolesValid(_ store: GameStore, context: String) {
        let ids = Set(store.userClub.players.map(\.id))
        XCTAssertTrue(store.userStarterIDs.isSubset(of: ids), context)
        for role in [store.captainID, store.penaltyTakerID, store.freeKickTakerID, store.cornerTakerID].compactMap({ $0 }) {
            XCTAssertTrue(ids.contains(role), context)
        }
    }

    private func assertSquadsValid(_ store: GameStore, context: String) {
        let ids = store.clubs.flatMap { $0.players.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate player identities: \(context)")
        for club in store.clubs {
            XCTAssertGreaterThanOrEqual(club.players.count, 11, "\(club.name): \(context)")
            for player in club.players {
                if let parent = player.onLoanFromClubIndex {
                    XCTAssertTrue(store.clubs.indices.contains(parent), context)
                    XCTAssertNotEqual(parent, store.clubs.firstIndex { $0.id == club.id }, context)
                }
                XCTAssertTrue((1...99).contains(player.rating), context)
                XCTAssertTrue((0...100).contains(player.fitness), context)
                XCTAssertGreaterThanOrEqual(player.injuryWeeks, 0, context)
                XCTAssertGreaterThanOrEqual(player.suspensionMatches, 0, context)
            }
        }
    }
}
