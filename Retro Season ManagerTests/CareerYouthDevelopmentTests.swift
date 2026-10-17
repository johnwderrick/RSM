import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerYouthDevelopmentTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CareerYouth-\(UUID().uuidString)")
        SaveSlots.useIsolatedRootForTesting(root)
        LegacyArchive.useIsolatedRootForTesting(root.appendingPathComponent("legacy"))
    }

    override func tearDown() {
        SaveSlots.useIsolatedRootForTesting(nil)
        LegacyArchive.useIsolatedRootForTesting(nil)
        if testRun?.failureCount == 0 { try? FileManager.default.removeItem(at: root) }
        else { print("Youth audit retained save root: \(root.path)") }
        super.tearDown()
    }

    private func game() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Academy Audit")
        return store
    }

    private func prospect(age: Int = 17, rating: Int = 90) -> Player {
        var player = GameStore.makePlayer(name: "Academy Audit Prospect", position: .forward,
                                         nationality: "England", age: age, rating: rating, startYear: 2000)
        player.isAcademyProduct = true
        player.contractYears = 3
        return player
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    func testIntakeCannotAgeOrGenerateAgainInTheSameSeason() async throws {
        let store = await game()
        let initial = try encoded(store.youthProspects)
        store.generateYouthIntake()
        XCTAssertEqual(try encoded(store.youthProspects), initial,
                       "Repeating this season's intake must neither age existing prospects nor add another crop")
    }

    func testStartingAnotherCareerDoesNotCarryAcademyPlayersAcross() async throws {
        let store = await game()
        let old = prospect()
        store.youthProspects = [old]
        let oldSaveID = try XCTUnwrap(store.currentSaveID)
        XCTAssertTrue(store.persist())
        store.newGame(clubIndex: 1, startYear: 2000, managerName: "Another Manager")
        XCTAssertNotEqual(store.currentSaveID, oldSaveID)
        XCTAssertFalse(store.youthProspects.contains { $0.id == old.id }, "New careers own a new academy")
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: oldSaveID))
        XCTAssertEqual(reloaded.youthProspects.map(\.id), [old.id], "The original career remains intact")
    }

    func testJobHandoffDoesNotTakeTheOutgoingClubsAcademy() async throws {
        let store = await game()
        let old = prospect()
        store.youthProspects = [old]
        let destination = try XCTUnwrap(store.clubs.indices.first { $0 != store.userClubIndex && store.clubs[$0].divisionTier == 0 })
        let destinationID = store.clubs[destination].id
        store.currentMatchday = store.totalMatchdays + 1
        store.pendingJobOffers = [JobOffer(clubIndex: destination, clubName: store.clubs[destination].name,
            divisionName: store.divisionName(store.clubs[destination].divisionTier), prestige: store.clubs[destination].prestige,
            transferBudget: store.clubs[destination].transferBudget, expectedObjective: store.previewObjective(forClubIndex: destination))]
        store.acceptJobOffer(store.pendingJobOffers[0])
        store.startNextSeason()
        XCTAssertEqual(store.userClub.id, destinationID)
        XCTAssertFalse(store.youthProspects.contains { $0.id == old.id }, "Academy prospects belong to their club, not the manager")
        XCTAssertFalse(store.userClub.players.contains { $0.id == old.id })
        XCTAssertFalse(store.youthProspects.isEmpty)
    }

    func testAnnualAcademyDevelopmentAgesOutCapsPoolAndRefreshesValues() async throws {
        let store = await game()
        let holdovers = (0..<11).map { _ in prospect(age: 19, rating: 94) }
        let agedOut = prospect(age: 20, rating: 94)
        store.youthProspects = holdovers + [agedOut]
        store.season += 1
        store.generateYouthIntake()
        XCTAssertEqual(store.youthProspects.count, 12)
        XCTAssertEqual(Set(store.youthProspects.map(\.id)).count, 12)
        XCTAssertFalse(store.youthProspects.contains { $0.id == agedOut.id })
        for old in holdovers {
            let developed = try XCTUnwrap(store.youthProspects.first { $0.id == old.id })
            XCTAssertEqual(developed.age, 20)
            XCTAssertGreaterThanOrEqual(developed.rating, old.rating)
            XCTAssertEqual(developed.value, playerValue(rating: developed.rating, age: developed.age, startYear: store.startYear),
                           "Annual academy growth must not leave an old valuation on the promoted player")
        }
    }

    func testPromotionRefusesAnUnaffordableSeniorWageWithoutMutation() async throws {
        let store = await game()
        let player = prospect()
        store.youthProspects = [player]
        store.clubs[store.userClubIndex].wageBudget = store.userClub.wageBill
        let clubsBefore = try encoded(store.clubs)
        let ledgerBefore = try encoded(store.seasonLedger)
        let message = store.promoteYouth(player)
        XCTAssertTrue(message.lowercased().contains("wage"), message)
        XCTAssertEqual(try encoded(store.clubs), clubsBefore)
        XCTAssertEqual(store.youthProspects.map(\.id), [player.id])
        XCTAssertFalse(store.youthPromotedThisSeasonIDs.contains(player.id))
        XCTAssertEqual(try encoded(store.seasonLedger), ledgerBefore)
    }

    func testPromotionUsesCurrentProspectAndCannotDuplicateOrChargeTwice() async throws {
        let store = await game()
        let oldCard = prospect(rating: 75)
        var improved = oldCard
        improved.rating += 2
        improved.value = playerValue(rating: improved.rating, age: improved.age, startYear: store.startYear)
        store.youthProspects = [improved]
        let wageBefore = store.userClub.wageBill
        store.clubs[store.userClubIndex].wageBudget = wageBefore + improved.wage
        let budget = store.userClub.transferBudget
        let ledger = try encoded(store.seasonLedger)
        XCTAssertTrue(store.promoteYouth(oldCard).contains("promoted"))
        let promoted = try XCTUnwrap(store.userClub.players.first { $0.id == oldCard.id })
        XCTAssertEqual(promoted.rating, improved.rating)
        XCTAssertEqual(store.userClub.wageBill - wageBefore, improved.wage)
        XCTAssertEqual(store.userClub.transferBudget, budget)
        XCTAssertEqual(try encoded(store.seasonLedger), ledger)
        XCTAssertTrue(store.youthProspects.isEmpty)
        XCTAssertTrue(store.youthPromotedThisSeasonIDs.contains(oldCard.id))
        _ = store.promoteYouth(oldCard)
        _ = store.releaseYouth(oldCard)
        XCTAssertEqual(store.clubs.flatMap(\.players).filter { $0.id == oldCard.id }.count, 1)
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertTrue(reloaded.youthProspects.isEmpty)
        XCTAssertEqual(reloaded.userClub.players.filter { $0.id == oldCard.id }.count, 1)
    }

    func testSquadLimitRefusesPromotionAndReleaseCannotReturnAPlayer() async throws {
        let store = await game()
        let player = prospect()
        store.youthProspects = [player]
        while store.userClub.players.count < 30 {
            store.clubs[store.userClubIndex].players.append(prospect())
        }
        store.clubs[store.userClubIndex].wageBudget = 100_000
        XCTAssertTrue(store.promoteYouth(player).contains("Squad is full"))
        XCTAssertEqual(store.youthProspects.map(\.id), [player.id])
        _ = store.releaseYouth(player)
        _ = store.releaseYouth(player)
        XCTAssertTrue(store.youthProspects.isEmpty)
        XCTAssertFalse(store.userClub.players.contains { $0.id == player.id })
        let loaded = await makeTestStore()
        XCTAssertTrue(loaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertTrue(loaded.youthProspects.isEmpty)
        loaded.season += 1
        loaded.generateYouthIntake()
        XCTAssertFalse(loaded.youthProspects.contains { $0.id == player.id })
    }

    func testLegacySaveKeepsItsExistingPoolWithoutAnExtraIntake() async throws {
        let store = await game()
        let player = prospect()
        store.youthProspects = [player]
        XCTAssertTrue(store.persist())
        let id = try XCTUnwrap(store.currentSaveID)
        let url = SaveSlots.fileURL(for: id)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        object.removeValue(forKey: "youthAcademies")
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        let loaded = await makeTestStore()
        XCTAssertTrue(loaded.loadSavedGame(id: id))
        let before = try encoded(loaded.youthProspects)
        loaded.generateYouthIntake()
        XCTAssertEqual(try encoded(loaded.youthProspects), before)
        XCTAssertEqual(loaded.youthProspects.map(\.id), [player.id])
        XCTAssertTrue(loaded.persist())
        let secondLoad = await makeTestStore()
        XCTAssertTrue(secondLoad.loadSavedGame(id: id))
        secondLoad.generateYouthIntake()
        XCTAssertEqual(try encoded(secondLoad.youthProspects), before)
    }

    private func acceptJobAndRollOver(_ store: GameStore, to id: UUID) throws {
        let index = try XCTUnwrap(store.clubs.firstIndex { $0.id == id })
        store.currentMatchday = store.totalMatchdays + 1
        store.pendingJobOffers = [JobOffer(clubIndex: index, clubName: store.clubs[index].name,
            divisionName: store.divisionName(store.clubs[index].divisionTier), prestige: store.clubs[index].prestige,
            transferBudget: store.clubs[index].transferBudget, expectedObjective: store.previewObjective(forClubIndex: index))]
        store.acceptJobOffer(store.pendingJobOffers[0])
        store.startNextSeason()
        XCTAssertEqual(store.userClub.id, id)
    }

    func testReturningToAClubRestoresItsAcademyAndAccountsForElapsedYears() async throws {
        var store = await game()
        let firstClub = store.userClub.id
        let secondClub = try XCTUnwrap(store.clubs.first { $0.id != firstClub && $0.divisionTier == 0 }?.id)
        let original = prospect(age: 16, rating: 94)
        store.youthProspects = [original]
        XCTAssertTrue(store.persist())
        try acceptJobAndRollOver(store, to: secondClub)
        XCTAssertFalse(store.youthProspects.contains { $0.id == original.id })
        XCTAssertEqual(store.youthAcademies[firstClub]?.prospects.map(\.id), [original.id])
        let secondClubProspect = prospect(age: 16, rating: 94)
        store.youthProspects = [secondClubProspect]
        XCTAssertTrue(store.persist())
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        store = reloaded
        try acceptJobAndRollOver(store, to: firstClub)
        let returned = try XCTUnwrap(store.youthProspects.first { $0.id == original.id })
        XCTAssertEqual(returned.age, 18, "Two seasons elapsed while this club's pool was not displayed")
        XCTAssertFalse(store.youthProspects.contains { $0.id == secondClubProspect.id })
        let allIDs = store.clubs.flatMap { $0.players.map(\.id) }
            + store.youthAcademies.values.flatMap { $0.prospects.map(\.id) }
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "Each prospect has one club, separate from senior ownership")
        let before = try encoded(store.youthProspects)
        store.generateYouthIntake()
        store.startNextSeason()
        XCTAssertEqual(try encoded(store.youthProspects), before, "Duplicate intake/rollover must not age the returning pool twice")
        XCTAssertTrue(store.persist())
        let finalLoad = await makeTestStore()
        XCTAssertTrue(finalLoad.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertEqual(try encoded(finalLoad.youthProspects), before)
        XCTAssertEqual(finalLoad.youthAcademies[secondClub]?.prospects.map(\.id), [secondClubProspect.id])
    }

    func testPromotedGraduateAndRetainedProspectAdvanceOnceAtRollover() async throws {
        let store = await game()
        let promoted = prospect(age: 17, rating: 90)
        let retained = prospect(age: 16, rating: 94)
        store.youthProspects = [promoted, retained]
        store.clubs[store.userClubIndex].wageBudget = 1_000_000
        XCTAssertTrue(store.promoteYouth(promoted).contains("promoted"))
        store.currentMatchday = store.totalMatchdays + 1
        store.startNextSeason()
        let senior = try XCTUnwrap(store.userClub.players.first { $0.id == promoted.id })
        XCTAssertEqual(senior.age, 18)
        XCTAssertEqual(senior.contractYears, 2)
        XCTAssertTrue(senior.isAcademyProduct)
        XCTAssertFalse(store.youthProspects.contains { $0.id == senior.id })
        XCTAssertEqual(store.youthProspects.first { $0.id == retained.id }?.age, 17)
        let pool = try encoded(store.youthProspects)
        store.startNextSeason()
        XCTAssertEqual(try encoded(store.youthProspects), pool)
        XCTAssertEqual(store.userClub.players.first { $0.id == senior.id }?.age, 18)
        XCTAssertTrue(store.persist())
        let loaded = await makeTestStore()
        XCTAssertTrue(loaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertEqual(try encoded(loaded.youthProspects), pool)
        XCTAssertEqual(loaded.userClub.players.first { $0.id == senior.id }?.contractYears, 2)
    }

    func testFocusedTrainingAndAcademyGrowthSurviveSaveReload() async throws {
        let store = await game()
        var trainee = prospect(age: 20, rating: 70)
        trainee.attributes = Dictionary(uniqueKeysWithValues: trainee.attributeOrder.map { ($0, 10) })
        store.clubs[store.userClubIndex].players = [trainee]
        store.youthProspects = [prospect(age: 16, rating: 60)]
        store.trainingFocus = .attacking
        let academyID = store.youthProspects[0].id
        for _ in 0..<500 { store.trainUserSquad() }
        let trained = try XCTUnwrap(store.userClub.players.first)
        XCTAssertGreaterThan(trained.attributes.values.reduce(0, +), trainee.attributes.values.reduce(0, +))
        for key in trainee.attributeOrder where !TrainingFocus.attacking.preferred.contains(key) {
            XCTAssertEqual(trained.attributes[key], 10, "Focused training must not grow an unrelated attribute")
        }
        XCTAssertTrue(trained.attributes.values.allSatisfy { (1...20).contains($0) })
        XCTAssertEqual(store.youthProspects[0].id, academyID)
        XCTAssertTrue((61...85).contains(store.youthProspects[0].rating))
        XCTAssertTrue(store.persist())
        let loaded = await makeTestStore()
        XCTAssertTrue(loaded.loadSavedGame(id: try XCTUnwrap(store.currentSaveID)))
        XCTAssertEqual(loaded.trainingFocus, .attacking)
        XCTAssertEqual(try encoded(loaded.userClub.players), try encoded(store.userClub.players))
        XCTAssertEqual(try encoded(loaded.youthProspects), try encoded(store.youthProspects))
    }
}
