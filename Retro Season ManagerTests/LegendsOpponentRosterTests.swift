//
//  LegendsOpponentRosterTests.swift
//  Retro Season ManagerTests
//
//  Phase 0 of the Legends 2D match simulator — guards the synthesized
//  opponent XI (LegendsOpponentRoster.swift) that fills the gap left by
//  LegendsOpponent being just `{ name, rating }` with no real roster.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsOpponentRosterTests: XCTestCase {

    func testRosterIsDeterministicForTheSameOpponent() {
        let opponent = LegendsOpponent(name: "Highbury", rating: 72)
        let first = LegendsOpponentRoster.generateRoster(for: opponent)
        let second = LegendsOpponentRoster.generateRoster(for: opponent)

        XCTAssertEqual(first.formation.name, second.formation.name)
        XCTAssertEqual(first.slots, second.slots)
        XCTAssertEqual(first.players.map(\.id), second.players.map(\.id))
        XCTAssertEqual(first.players.map(\.name), second.players.map(\.name))
        XCTAssertEqual(first.players.map(\.overall), second.players.map(\.overall))
    }

    func testRosterHasElevenPlayersFillingEveryFormationSlot() {
        for rating in stride(from: 35, through: 99, by: 8) {
            let opponent = LegendsOpponent(name: "Rival #\(rating)", rating: rating)
            let roster = LegendsOpponentRoster.generateRoster(for: opponent)
            XCTAssertEqual(roster.players.count, 11, "Rating \(rating) roster should always be 11 players.")
            XCTAssertEqual(roster.slots.count, 11)
            XCTAssertEqual(roster.players.map(\.position), roster.slots, "Each player's position should match its slot, in order.")
        }
    }

    func testGeneratedOverallsStayInAPlausibleBandAroundTheOpponentRating() {
        for rating in stride(from: 35, through: 99, by: 4) {
            let opponent = LegendsOpponent(name: "Rival #\(rating)", rating: rating)
            let roster = LegendsOpponentRoster.generateRoster(for: opponent)
            for player in roster.players {
                XCTAssertGreaterThanOrEqual(player.overall, 30, "Overall should never drop below the clamp floor.")
                XCTAssertLessThanOrEqual(player.overall, 99, "Overall should never exceed the clamp ceiling.")
                XCTAssertLessThanOrEqual(abs(player.overall - rating), 12,
                                          "Player overall \(player.overall) drifted too far from opponent rating \(rating).")
            }
        }
    }

    func testGeneratedAttributesStayWithinValidRange() {
        for rating in [35, 55, 75, 99] {
            let opponent = LegendsOpponent(name: "Rival #\(rating)", rating: rating)
            let roster = LegendsOpponentRoster.generateRoster(for: opponent)
            for player in roster.players {
                for value in [player.pace, player.shooting, player.passing, player.dribbling, player.defending, player.physical] {
                    XCTAssertGreaterThanOrEqual(value, 20)
                    XCTAssertLessThanOrEqual(value, 99)
                }
            }
        }
    }

    func testStrikersLeanTowardShootingAndPaceOverDefending() {
        // Not deterministic in isolation for any single roster (a formation
        // might not roll a lone example), so scan several opponents and
        // assert the shape holds wherever a striker does appear.
        var checkedAtLeastOne = false
        for i in 0..<20 {
            let opponent = LegendsOpponent(name: "Scan #\(i)", rating: 70)
            let roster = LegendsOpponentRoster.generateRoster(for: opponent)
            for player in roster.players where player.position == .striker {
                checkedAtLeastOne = true
                XCTAssertGreaterThan(player.shooting, player.defending,
                                      "A synthesized striker's shooting should exceed their defending.")
            }
        }
        XCTAssertTrue(checkedAtLeastOne, "Expected at least one striker across 20 scanned opponents.")
    }

    func testGoalkeeperSlotIsAlwaysFirstAndAlwaysGoalkeeper() {
        for name in ["Alpha", "Beta", "Gamma", "Delta"] {
            let opponent = LegendsOpponent(name: name, rating: 65)
            let roster = LegendsOpponentRoster.generateRoster(for: opponent)
            XCTAssertEqual(roster.slots.first, .goalkeeper)
            XCTAssertEqual(roster.players.first?.position, .goalkeeper)
            XCTAssertEqual(roster.players.first?.id, "opp-0")
        }
    }
}
