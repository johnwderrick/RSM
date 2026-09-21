//
//  TransferMarketPersistenceTests.swift
//  Retro Season Manager
//
//  Focused coverage for transfer-market and scouting persistence: the
//  market (targets, identities, prices, ordering), completed scout
//  reports and in-progress scouting assignments survive save/load cycles
//  exactly; old-format saves (no persisted market) generate one exactly
//  once; shortlisted club players and free agents both survive; and
//  stable target identity is deterministic per player.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class TransferMarketPersistenceTests: XCTestCase {

    /// Creates a fresh store and starts a real career for it (the same
    /// path a normal new game takes), with the save slot already bound.
    private func freshCareer() async -> GameStore {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Persistence Tester")
        XCTAssertNotNil(store.currentSaveID, "A new career must be bound to a save slot")
        return store
    }

    // MARK: - Stable identity

    func testStableTargetIdentityIsDeterministicPerPlayer() {
        let playerID = UUID()
        XCTAssertEqual(TransferTarget.stableID(for: playerID),
                       TransferTarget.stableID(for: playerID),
                       "The same player id must always map to the same target id")
        XCTAssertNotEqual(TransferTarget.stableID(for: playerID),
                          TransferTarget.stableID(for: UUID()),
                          "Different player ids must map to different target ids")
        let rebuilt = TransferTarget(player: Player(id: playerID, name: "X", position: .forward,
                                                    detailedPosition: .striker, secondaryPositions: [],
                                                    age: 25, rating: 70),
                                     sellingClubIndex: 3, askingPrice: 100)
        let moved = TransferTarget(player: Player(id: playerID, name: "X", position: .forward,
                                                  detailedPosition: .striker, secondaryPositions: [],
                                                  age: 25, rating: 70),
                                   sellingClubIndex: nil, askingPrice: 200)
        XCTAssertEqual(rebuilt.id, moved.id,
                       "Rebuilding a target (price/club changes) must not change its identity")
    }

    // MARK: - Market persistence

    func testMarketTargetsPricesAndOrderSurviveSaveLoad() async {
        let store = await freshCareer()
        // A hand-built market with known content and ordering.
        let players = (0..<4).map { index in
            Player(id: UUID(), name: "Target \(index)", position: .midfielder,
                   detailedPosition: .centralMid, secondaryPositions: [],
                   age: 24 + index, rating: 68 + index)
        }
        store.transferMarket = [
            TransferTarget(player: players[0], sellingClubIndex: 1, askingPrice: 9_900),
            TransferTarget(player: players[1], sellingClubIndex: 2, askingPrice: 8_800),
            TransferTarget(player: players[2], sellingClubIndex: nil, askingPrice: 7_700),
            TransferTarget(player: players[3], sellingClubIndex: 1, askingPrice: 6_600),
        ]
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        let saveID = store.currentSaveID!
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID), "The save must reload")

        XCTAssertEqual(reloaded.transferMarket.map(\.id), store.transferMarket.map(\.id),
                       "Target identity and ordering must survive exactly")
        XCTAssertEqual(reloaded.transferMarket.map(\.askingPrice), store.transferMarket.map(\.askingPrice),
                       "Asking prices must survive exactly")
        XCTAssertEqual(reloaded.transferMarket.map(\.sellingClubIndex), store.transferMarket.map(\.sellingClubIndex),
                       "Selling clubs must survive exactly")
        XCTAssertEqual(reloaded.transferMarket.map(\.player.id), store.transferMarket.map(\.player.id),
                       "Underlying player identities must survive exactly")
    }

    func testGeneratedFreeAgentsSurviveWithSameIdentityAndPrice() async {
        let store = await freshCareer()
        let freeAgentsBefore = store.transferMarket.filter { $0.sellingClubIndex == nil }
        XCTAssertFalse(freeAgentsBefore.isEmpty, "A generated market contains free agents")
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: store.currentSaveID!))

        let freeAgentsAfter = reloaded.transferMarket.filter { $0.sellingClubIndex == nil }
        XCTAssertEqual(freeAgentsAfter.map(\.id), freeAgentsBefore.map(\.id),
                       "Generated free agents must survive with the same identities")
        XCTAssertEqual(freeAgentsAfter.map(\.askingPrice), freeAgentsBefore.map(\.askingPrice),
                       "Generated free agents must keep their prices")
        XCTAssertEqual(freeAgentsAfter.map(\.player.name), freeAgentsBefore.map(\.player.name),
                       "Generated free agents must be the same players, not fresh rolls")
    }

    func testRepeatedSaveLoadCyclesDoNotDuplicateOrRegenerate() async {
        let store = await freshCareer()
        let idsBefore = store.transferMarket.map(\.id)
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        for _ in 0..<3 {
            XCTAssertTrue(reloaded.loadSavedGame(id: store.currentSaveID!))
            XCTAssertEqual(reloaded.transferMarket.map(\.id), idsBefore,
                           "Repeated load cycles must restore the same market, not regenerate it")
            XCTAssertEqual(Set(reloaded.transferMarket.map(\.id)).count, reloaded.transferMarket.count,
                           "No duplicate targets may appear across reload cycles")
            reloaded.persist()
        }
    }

    // MARK: - Scouting persistence

    func testCompletedScoutReportsSurviveSaveLoad() async {
        let store = await freshCareer()
        guard let target = store.transferMarket.first(where: { $0.sellingClubIndex != nil }) else {
            return XCTFail("The generated market should contain a club-listed target")
        }
        let report = ScoutReport(playerID: target.player.id, playerName: target.player.name,
                                 potential: target.player.rating + 7, verdict: "Test verdict",
                                 note: "Test note", valueRangeLow: 100, valueRangeHigh: 200, confidence: 75)
        store.scoutedReports[target.id] = report
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: store.currentSaveID!))
        let restored = reloaded.scoutedReports[target.id]
        XCTAssertEqual(restored?.playerID, report.playerID)
        XCTAssertEqual(restored?.playerName, report.playerName)
        XCTAssertEqual(restored?.potential, report.potential)
        XCTAssertEqual(restored?.verdict, report.verdict)
        XCTAssertEqual(restored?.note, report.note)
        XCTAssertEqual(restored?.valueRangeLow, report.valueRangeLow)
        XCTAssertEqual(restored?.valueRangeHigh, report.valueRangeHigh)
        XCTAssertEqual(restored?.confidence, report.confidence,
                       "The completed scout report must survive the reload field-for-field")
    }

    func testInProgressAssignmentsSurviveAndResolveAfterReload() async {
        let store = await freshCareer()
        guard let target = store.transferMarket.first else {
            return XCTFail("The generated market should contain a target")
        }
        let due = store.currentDate.addingTimeInterval(3 * 86_400)
        store.scoutingDue[target.id] = due
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: store.currentSaveID!))
        XCTAssertEqual(reloaded.scoutingDue[target.id], due,
                       "The in-progress assignment must survive with its due date")

        // Once the due date passes, the authoritative completion path
        // resolves the assignment into a report — after a reload, not
        // only in the session that started it.
        reloaded.currentDate = due.addingTimeInterval(60)
        reloaded.completeScouting()
        XCTAssertNil(reloaded.scoutingDue[target.id], "The assignment must clear once resolved")
        XCTAssertEqual(reloaded.scoutedReports[target.id]?.playerID, target.player.id,
                       "The resolved report must be for the scouted player")
    }

    // MARK: - Shortlists

    func testClubAndFreeAgentShortlistsSurviveSaveLoad() async {
        let store = await freshCareer()
        guard let clubTarget = store.transferMarket.first(where: { $0.sellingClubIndex != nil }),
              let freeAgent = store.transferMarket.first(where: { $0.sellingClubIndex == nil }) else {
            return XCTFail("The generated market should contain both a club target and a free agent")
        }
        store.shortlistedPlayerIDs = [clubTarget.player.id, freeAgent.player.id]
        store.persist()

        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: store.currentSaveID!))

        let results = reloaded.shortlistedResults
        XCTAssertEqual(Set(results.map(\.player.id)), Set(store.shortlistedPlayerIDs),
                       "Both shortlisted players must resolve after the reload")
        let freeAgentResult = results.first { $0.player.id == freeAgent.player.id }
        XCTAssertEqual(freeAgentResult?.clubIndex, nil,
                       "The free agent must resolve with a nil club index")
        let clubResult = results.first { $0.player.id == clubTarget.player.id }
        XCTAssertEqual(clubResult?.clubIndex, clubTarget.sellingClubIndex,
                       "The club player must resolve with his club's index")
    }

    // MARK: - Old-format saves

    func testOldFormatSaveWithoutMarketGeneratesExactlyOnce() async {
        let store = await freshCareer()
        // Strip the new persistence fields from the saved JSON, exactly
        // matching what a pre-persistence build would have written: the
        // decoder then sees absent keys and defaults them to nil.
        store.persist()
        let saveID = store.currentSaveID!
        let url = SaveSlots.fileURL(for: saveID)
        var raw = try! JSONSerialization.jsonObject(with: try! Data(contentsOf: url)) as! [String: Any]
        raw.removeValue(forKey: "transferMarket")
        raw.removeValue(forKey: "scoutedReports")
        raw.removeValue(forKey: "scoutingDue")
        try! JSONSerialization.data(withJSONObject: raw).write(to: url)

        let reloaded = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(reloaded.loadSavedGame(id: saveID), "An old-format save must still decode")
        XCTAssertFalse(reloaded.transferMarket.isEmpty, "An old-format save must generate a market")
        let firstGeneration = reloaded.transferMarket.map(\.id)
        reloaded.persist()

        // Once migrated, the market is persisted and never regenerated again.
        let migrated = await Task { @MainActor in GameStore() }.value
        XCTAssertTrue(migrated.loadSavedGame(id: saveID))
        XCTAssertEqual(migrated.transferMarket.map(\.id), firstGeneration,
                       "After the one-time generation the market must be stable across reloads")
    }

    func testScoutReportCodableRoundTrip() throws {
        let report = ScoutReport(playerID: UUID(), playerName: "Round Trip",
                                 potential: 88, verdict: "Verdict", note: "Note",
                                 valueRangeLow: 1_000, valueRangeHigh: 2_000, confidence: 66)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ScoutReport.self, from: data)
        XCTAssertEqual(decoded.playerID, report.playerID)
        XCTAssertEqual(decoded.potential, report.potential)
        XCTAssertEqual(decoded.confidence, report.confidence)
    }
}
