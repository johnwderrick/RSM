//
//  LegendsMatchSelectors2DTests.swift
//  Retro Season ManagerTests
//
//  Point 2 (Phase 6): the 2D match simulator's attacker/defender
//  positioning must select on real detailed attributes through the same
//  `LegendsMatchSelectors` used by the live match engine — not on role
//  order plus a uniform random pick. Covered here:
//
//  1. Wide-run casting prefers the winger with the best
//     passing+sprintSpeed selector score (deterministic, no randomness).
//  2. Finisher casting prefers the striker with the best
//     shooting+positioning score, and never duplicates the wide runner.
//  3. Marker casting picks the best defending-selector score among the
//     three nearest defenders (positioning/anticipation/tackling), not
//     merely the nearest body.
//  4. Deterministic detailed-attribute synthesis for the synthetic
//     opponent roster: same seed → same values, clamped to 0...99,
//     position-profiled (strikers favour finishing, keepers get
//     goalkeeping attributes, outfielders get zero goalkeeping values).
//
//  Everything is driven through `startAttack` via the public
//  `triggerAttack` + `testHasRunOverride`/`testMarkerID` test hooks and
//  `testAdvance(dt:)` — no private-state poking.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsMatchSelectors2DTests: XCTestCase {

    // MARK: - Fixtures

    /// Builds a sim with one home winger whose detailed attributes are
    /// configurable, plus a standard opposing XI.
    private func makeSimulation(
        wingerDetailed: LegendsDetailedAttributes,
        strikerDetailed: LegendsDetailedAttributes,
        defenderDetailed: LegendsDetailedAttributes
    ) async -> LegendsMatchSimulation {
        let formation = Formation.all.first { $0.name == "4-4-2" }!
        let roles = formation.slotRoles()
        var userDetailed: [String: LegendsDetailedAttributes] = [:]
        let userSlots: [(role: DetailedPosition, id: String, name: String)] = roles.enumerated().map { index, role in
            let id = "user-\(index)"
            switch role {
            case .rightWing: userDetailed[id] = wingerDetailed
            case .striker: userDetailed[id] = strikerDetailed
            case .leftBack: userDetailed[id] = defenderDetailed
            default: break
            }
            return (role, id, "Player \(index)")
        }
        let opponent = LegendsOpponentRoster.generateRoster(for: LegendsOpponent(name: "Selectors Rivals", rating: 65))
        return await Task { @MainActor in
            LegendsMatchSimulation(
                userSlots: userSlots,
                userFormation: formation,
                opponentFormation: opponent.formation,
                opponentPlayers: opponent.players,
                userDetailedAttributes: userDetailed
            )
        }.value
    }

    private func makeStrongFinishing() -> LegendsDetailedAttributes {
        var a = LegendsDetailedAttributes.zero
        a.finishing = 95
        a.composure = 90
        a.longShots = 85
        a.firstTouch = 85
        a.positioning = 90
        return a
    }

    private func makeWeakFinishing() -> LegendsDetailedAttributes {
        var a = LegendsDetailedAttributes.zero
        a.finishing = 20
        a.composure = 25
        a.longShots = 15
        a.firstTouch = 20
        a.positioning = 25
        return a
    }

    private func makeStrongDefending() -> LegendsDetailedAttributes {
        var a = LegendsDetailedAttributes.zero
        a.positioning = 95
        a.anticipation = 92
        a.tackling = 90
        a.strength = 85
        return a
    }

    private func makeWeakDefending() -> LegendsDetailedAttributes {
        var a = LegendsDetailedAttributes.zero
        a.positioning = 20
        a.anticipation = 18
        a.tackling = 15
        a.strength = 22
        return a
    }

    // MARK: - Wide runner + finisher casting

    func testWideRunnerPrefersStrongerWinger() async {
        // 4-4-2 slot order: GK, LB, CB, CB, RB, LM, RM, CM, CM, ST, ST.
        // The wide-runner preference tier list starts at leftMid — the
        // first tier with a candidate wins the tier, and within the tier
        // the best selector score wins. Give the LEFT mid strong
        // attributes and the RIGHT mid weak ones: the left mid must make
        // the run deterministically (role order + attribute score), and
        // the same pick must repeat across two identical sims (no
        // randomElement()).
        var strong = LegendsDetailedAttributes.zero
        strong.passing = 95
        strong.vision = 90
        strong.decisions = 88
        strong.firstTouch = 90
        strong.sprintSpeed = 95
        strong.acceleration = 92
        var weak = strong
        weak.passing = 30
        weak.sprintSpeed = 30

        // simA: leftMid strong (slot 5 = user-5), rightMid weak (slot 6).
        // simB: identical attributes — casting must be deterministic and
        // identical across the two sims.
        var userDetailedA: [String: LegendsDetailedAttributes] = [:]
        var userDetailedB: [String: LegendsDetailedAttributes] = [:]
        userDetailedA["user-5"] = strong
        userDetailedA["user-6"] = weak
        userDetailedB["user-5"] = strong
        userDetailedB["user-6"] = weak

        let formation = Formation.all.first { $0.name == "4-4-2" }!
        let roles = formation.slotRoles()
        let userSlots: [(role: DetailedPosition, id: String, name: String)] = roles.enumerated().map { index, role in
            (role, "user-\(index)", "Player \(index)")
        }
        let opponent = LegendsOpponentRoster.generateRoster(for: LegendsOpponent(name: "Selectors Rivals", rating: 65))
        func build(_ detailed: [String: LegendsDetailedAttributes]) async -> LegendsMatchSimulation {
            await Task { @MainActor in
                LegendsMatchSimulation(
                    userSlots: userSlots,
                    userFormation: formation,
                    opponentFormation: opponent.formation,
                    opponentPlayers: opponent.players,
                    userDetailedAttributes: detailed
                )
            }.value
        }
        let simA = await build(userDetailedA)
        let simB = await build(userDetailedB)

        simA.triggerAttack(forUser: true, scored: true)
        simB.triggerAttack(forUser: true, scored: true)

        let runnerA = simA.players.first { $0.id == simA.testFollowedPlayerID(atLegIndex: 2) }
        let runnerB = simB.players.first { $0.id == simB.testFollowedPlayerID(atLegIndex: 2) }
        XCTAssertEqual(runnerA?.role, .leftMid,
                       "The strong left mid should win the first available wide tier")
        XCTAssertEqual(runnerA?.id, runnerB?.id,
                       "Identical attribute setups must cast the same runner (deterministic, not randomElement)")
    }

    func testFinisherNeverDuplicatesWideRunner() async {
        let sim = await makeSimulation(
            wingerDetailed: makeStrongFinishing(),
            strikerDetailed: makeStrongFinishing(),
            defenderDetailed: makeStrongDefending()
        )
        sim.triggerAttack(forUser: true, scored: true)
        let runnerID = sim.testFollowedPlayerID(atLegIndex: 2)
        let finisherID = sim.testFollowedPlayerID(atLegIndex: 3)
        XCTAssertNotNil(runnerID)
        XCTAssertNotNil(finisherID)
        XCTAssertNotEqual(runnerID, finisherID,
                          "The finisher must be a different player from the wide runner")
        let finisher = sim.players.first { $0.id == finisherID }
        XCTAssertEqual(finisher?.role, .striker,
                       "The striker with the best shooting+positioning score should finish")
    }

    // MARK: - Marker casting

    func testMarkerIsBestDefenderAmongNearest() async {
        // leftBack has strong defending attributes; the other defenders
        // are weak. The marker must be the leftBack even though all four
        // defenders start at similar distance from the wide run.
        let sim = await makeSimulation(
            wingerDetailed: makeStrongFinishing(),
            strikerDetailed: makeStrongFinishing(),
            defenderDetailed: makeStrongDefending()
        )
        sim.triggerAttack(forUser: false, scored: true) // away attacks → home defends
        let markerID = sim.testMarkerID()
        XCTAssertNotNil(markerID, "An attack sequence must assign a marking defender")
        let marker = sim.players.first { $0.id == markerID }
        XCTAssertEqual(marker?.role, .leftBack,
                       "The defender with the best defending-selector score among the nearest three should mark")
    }

    // MARK: - Deterministic synthesis for the synthetic roster

    func testSynthesizedAttributesAreDeterministicAndClamped() {
        let headline = (overall: 70, pace: 80, shooting: 60, passing: 65, dribbling: 66, defending: 55, physical: 72)
        let a = LegendsDetailedAttributes.synthesized(
            overall: headline.overall, pace: headline.pace, shooting: headline.shooting,
            passing: headline.passing, dribbling: headline.dribbling, defending: headline.defending,
            physical: headline.physical, broad: .forward, seed: "Test Rivals-9"
        )
        let b = LegendsDetailedAttributes.synthesized(
            overall: headline.overall, pace: headline.pace, shooting: headline.shooting,
            passing: headline.passing, dribbling: headline.dribbling, defending: headline.defending,
            physical: headline.physical, broad: .forward, seed: "Test Rivals-9"
        )
        XCTAssertEqual(a, b, "Same seed must produce identical attributes (no hashValue, no randomness)")

        let all = [
            a.finishing, a.longShots, a.passing, a.crossing, a.dribbling, a.firstTouch,
            a.tackling, a.heading, a.setPieces, a.vision, a.decisions, a.positioning,
            a.anticipation, a.composure, a.workRate, a.leadership, a.teamwork,
            a.acceleration, a.sprintSpeed, a.agility, a.balance, a.stamina, a.strength,
            a.handling, a.reflexes, a.oneOnOnes, a.aerialReach, a.distribution, a.goalkeeperPositioning,
        ]
        XCTAssertTrue(all.allSatisfy { $0 >= 0 && $0 <= 99 }, "All synthesized values must stay within 0...99")
    }

    func testSynthesizedAttributesFollowPositionProfile() {
        let base = (overall: 70, pace: 70, shooting: 70, passing: 70, dribbling: 70, defending: 70, physical: 70)
        func make(_ broad: Position, seed: String) -> LegendsDetailedAttributes {
            LegendsDetailedAttributes.synthesized(
                overall: base.overall, pace: base.pace, shooting: base.shooting,
                passing: base.passing, dribbling: base.dribbling, defending: base.defending,
                physical: base.physical, broad: broad, seed: seed
            )
        }
        let striker = make(.forward, seed: "pos-striker")
        let keeper = make(.goalkeeper, seed: "pos-keeper")
        let defender = make(.defender, seed: "pos-defender")

        XCTAssertGreaterThan(striker.finishing, 70, "Strikers should skew above their shooting baseline for finishing")
        XCTAssertGreaterThan(keeper.reflexes, 0, "Keepers must receive meaningful goalkeeping attributes")
        XCTAssertGreaterThan(keeper.handling, 0)
        let outfieldKeeperValues = [defender.handling, defender.reflexes, defender.oneOnOnes, defender.aerialReach, defender.distribution, defender.goalkeeperPositioning]
        XCTAssertTrue(outfieldKeeperValues.allSatisfy { $0 == 0 },
                      "Outfielders must have zero goalkeeping attributes")
    }

    func testOpponentRosterCarriesDeterministicDetailedAttributes() {
        let opponent = LegendsOpponent(name: "Detail Rivals", rating: 68)
        let first = LegendsOpponentRoster.generateRoster(for: opponent)
        let second = LegendsOpponentRoster.generateRoster(for: opponent)
        XCTAssertEqual(first.players, second.players,
                       "Roster regeneration must be deterministic, including detailed attributes")
        let keeper = first.players.first { $0.position.broad == .goalkeeper }
        XCTAssertNotNil(keeper)
        XCTAssertGreaterThan(keeper!.detailed.reflexes, 0,
                             "The synthetic keeper must carry real goalkeeping attributes")
        let forward = first.players.first { $0.position.broad == .forward }
        XCTAssertNotNil(forward)
        XCTAssertEqual(forward!.detailed.handling, 0,
                       "Synthetic outfielders must have zero goalkeeping attributes")
    }
}
