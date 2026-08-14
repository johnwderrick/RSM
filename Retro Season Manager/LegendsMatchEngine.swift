//
//  LegendsMatchEngine.swift
//  Retro Season Manager
//
//  Phase 7 — Play Match. A small standalone simulator rather than a
//  reuse of GameStore+MatchEngine.swift's simulate(fixtureIndex:):
//  that function is wired deep into Club/Player/GameStore season state
//  (fixtures, board, morale, stadium) that Legends has no equivalent
//  of. What's reused is the underlying math — the same Poisson goal
//  model and home-strength-ratio approach — copied here as pure,
//  dependency-free functions so Legends' single teamRating/chemistry
//  numbers can drive it without constructing fake Player/Club objects.
//

import Foundation

enum LegendsMatchEngine {
    /// Identical formula to GameStore+MatchEngine.swift's own
    /// `poisson(_:)` — same goal distribution, no shared state.
    static func poisson(_ lambda: Double) -> Int {
        let l = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= Double.random(in: 0...1)
        } while p > l
        return k - 1
    }

    struct Result {
        let teamGoals: Int
        let opponentGoals: Int

        var outcome: LegendsMatchOutcome {
            if teamGoals > opponentGoals { return .win }
            if teamGoals < opponentGoals { return .loss }
            return .draw
        }
    }

    /// `teamRating`/`opponentRating` are plain 0...99 overalls (an
    /// average, not a sum) — the win-probability ratio is scale
    /// invariant, so no per-player expansion is needed the way Career
    /// Mode's `strengthValue` sums 11 players. `chemistryBonus` nudges
    /// the ratio in the team's favour for good squad cohesion.
    static func simulate(teamRating: Int, opponentRating: Int, chemistryBonus: Double) -> Result {
        let teamStrength = max(Double(teamRating) + chemistryBonus, 1)
        let opponentStrength = max(Double(opponentRating), 1)
        let ratio = teamStrength / (teamStrength + opponentStrength)
        // Around 2.7 goals per game on average, split by relative strength
        // — same constant Career Mode's own simulate() uses.
        let teamGoals = poisson(2.7 * ratio)
        let opponentGoals = poisson(2.7 * (1.0 - ratio))
        return Result(teamGoals: teamGoals, opponentGoals: opponentGoals)
    }
}

enum LegendsMatchOutcome {
    case win, draw, loss

    var label: String {
        switch self {
        case .win: return "VICTORY"
        case .draw: return "DRAW"
        case .loss: return "DEFEAT"
        }
    }
}
