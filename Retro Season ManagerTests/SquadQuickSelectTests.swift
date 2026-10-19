//
//  SquadQuickSelectTests.swift
//  Retro Season ManagerTests
//
//  Quick-select from the pitch must never corrupt the starting XI. The
//  XI is stored as a bag of player IDs and validated by each player's own
//  broad position, so a role from another broad group (a midfielder
//  quick-selected at left-back) can't be honoured and must be refused
//  rather than silently wrecking the hand-picked side.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class SquadQuickSelectTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SquadQuickSelect-\(UUID().uuidString)")
        SaveSlots.useIsolatedRootForTesting(root)
        LegacyArchive.useIsolatedRootForTesting(root.appendingPathComponent("legacy"))
    }

    override func tearDown() {
        SaveSlots.useIsolatedRootForTesting(nil)
        LegacyArchive.useIsolatedRootForTesting(nil)
        if testRun?.failureCount == 0 { try? FileManager.default.removeItem(at: root) }
        super.tearDown()
    }

    /// These tests exercise selection, not random squad generation. Keep a
    /// complete 4-4-2 plus known healthy bench players regardless of new-game
    /// formation, player roles or availability rolls.
    private func fixture() async -> (store: GameStore, defender: Player, midfielder: Player) {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Quick Select Audit")
        func player(_ name: String, _ position: Position, _ role: DetailedPosition, _ rating: Int) -> Player {
            Player(name: name, position: position, detailedPosition: role, age: 24, rating: rating)
        }
        let starters = [player("Starting Keeper", .goalkeeper, .goalkeeper, 85)]
            + [90, 85, 80, 75].enumerated().map { player("Starting Defender \($0.offset)", .defender, .leftBack, $0.element) }
            + [88, 84, 80, 76].enumerated().map { player("Starting Midfielder \($0.offset)", .midfielder, .centralMid, $0.element) }
            + [86, 82].enumerated().map { player("Starting Forward \($0.offset)", .forward, .striker, $0.element) }
        let defender = player("Bench Defender", .defender, .leftBack, 55)
        let midfielder = player("Bench Midfielder", .midfielder, .centralMid, 55)
        store.clubs[store.userClubIndex].players = starters + [defender, midfielder]
        store.formation = Formation.all.first { $0.name == "4-4-2" }!
        store.userStarterIDs = Set(starters.map(\.id))
        return (store, defender, midfielder)
    }

    /// A bench midfielder quick-selected into a defensive role must be
    /// refused, and the hand-picked XI must survive intact. Before the fix
    /// this evicted a defender, inserted the midfielder, left the XI
    /// invalid, and `userStartingXI()` silently replaced it with the
    /// best XI.
    func testCrossGroupQuickSelectIsRefusedAndKeepsHandPickedXI() async {
        let (store, handPickedDefender, benchMidfielder) = await fixture()
        _ = store.assignStarter(handPickedDefender, forRole: .leftBack)
        XCTAssertTrue(store.userStarterIDs.contains(handPickedDefender.id))
        XCTAssertTrue(store.isValidLineup(store.userClub.players.filter { store.userStarterIDs.contains($0.id) }),
                      "Precondition: the hand-picked XI must be valid")

        let startersBefore = store.userStarterIDs
        XCTAssertTrue(benchMidfielder.isAvailable)
        XCTAssertFalse(startersBefore.contains(benchMidfielder.id))

        let change = store.assignStarter(benchMidfielder, forRole: .leftBack)

        guard case .blocked = change else {
            return XCTFail("A midfielder must not be quick-selected at a defensive role")
        }
        XCTAssertEqual(store.userStarterIDs, startersBefore,
                       "A refused quick-select must not change the starting XI")
        XCTAssertEqual(Set(store.userStartingXI().map(\.id)), startersBefore,
                       "The hand-picked XI must be fielded, not replaced by the best XI")
    }

    /// The same-group path still works: a bench defender quick-selected
    /// at left-back evicts the weakest defender and leaves a valid XI
    /// containing the chosen player.
    func testSameGroupQuickSelectReplacesWeakestAndStaysValid() async {
        let (store, benchDefender, _) = await fixture()
        XCTAssertTrue(benchDefender.isAvailable)
        XCTAssertFalse(store.userStarterIDs.contains(benchDefender.id))

        let before = store.userStarterIDs
        let weakest = store.userClub.players.filter { before.contains($0.id) && $0.position == .defender }
            .min { $0.effectiveRating(for: .leftBack) < $1.effectiveRating(for: .leftBack) }
        guard let weakest else { return XCTFail("Fixture needs a starting defender") }
        let change = store.assignStarter(benchDefender, forRole: .leftBack)

        guard case .added = change else {
            return XCTFail("A defender must be quick-selected at a defensive role")
        }
        XCTAssertTrue(store.userStarterIDs.contains(benchDefender.id))
        XCTAssertEqual(store.userStarterIDs, before.subtracting([weakest.id]).union([benchDefender.id]),
                       "Only the weakest defender should be replaced")
        let xi = store.userStartingXI()
        XCTAssertTrue(store.isValidLineup(xi), "The XI must stay valid after a same-group quick-select")
        XCTAssertTrue(xi.contains { $0.id == benchDefender.id },
                      "The quick-selected player must be in the fielded XI")
    }
}
