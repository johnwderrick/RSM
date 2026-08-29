//
//  LegendsOpponentRoster.swift
//  Retro Season Manager
//
//  Phase 0 of the Legends 2D match simulator. `LegendsOpponent` today is
//  just `{ name, rating }` (LegendsStore+Match.swift) — no roster, no
//  positions, nothing to draw 22 dots from. This synthesizes a full,
//  plausible opposing XI on the fly from that single rating, deterministic
//  per opponent so it doesn't reshuffle across a view re-render.
//
//  Explicit non-goal: no bench, no opponent substitutions, no opponent
//  energy decay — PROJECT_BIBLE already flags opponent-side subs/energy as
//  separate unfinished scope this feature isn't absorbing. The synthetic
//  XI is fixed for the whole match.
//

import Foundation

struct SyntheticOpponentPlayer: Identifiable, Hashable {
    let id: String
    let name: String
    let position: DetailedPosition
    let overall: Int
    let pace: Int
    let shooting: Int
    let passing: Int
    let dribbling: Int
    let defending: Int
    let physical: Int
    /// Deterministic detailed attributes (Point 2) — synthesized from the
    /// headline ratings + position profile so the 2D simulator's
    /// attacker/defender positioning can select on real action-specific
    /// quality rather than role order alone. Defaults to zero for callers
    /// that construct the struct directly (tests) without a profile.
    var detailed: LegendsDetailedAttributes = .zero
}

enum LegendsOpponentRoster {

    /// A small, clearly-generic surname pool — deliberately not drawn from
    /// `LegendsCardDatabase`, so a synthesized rival never reads as a real
    /// Legend appearing on the wrong team.
    private static let surnames = [
        "Adeyemi", "Baptiste", "Carrow", "Delgado", "Eriksen", "Falk", "Guerrero", "Hallberg",
        "Ibarra", "Jankowski", "Kallas", "Lindqvist", "Marchetti", "Nowak", "Oyelaran", "Petrov",
        "Quintero", "Ramaekers", "Sandoval", "Tavares", "Ulrich", "Vasquez", "Wozniak", "Xhaferi",
        "Yilmaz", "Zamora", "Almeida", "Brandt", "Costin", "Dubois", "Ekstrom", "Ferreira",
        "Gustavsson", "Haddad", "Iversen", "Jovanovic", "Kowalczyk", "Larsen", "Mensah", "Novak",
        "Okafor", "Pereira", "Quaresma", "Rasmussen", "Sokolov", "Trindade", "Unger", "Villanueva",
        "Wagner", "Zubaru",
    ]

    /// Formations weighted toward balanced, familiar shapes so the
    /// generated opponent's structure doesn't feel exotic more often than
    /// not — exotic shapes (4-2-4, 5-2-3, 3-6-1) still turn up sometimes.
    private static func weightedFormation(using generator: inout SeededGenerator) -> Formation {
        let balancedNames: Set<String> = ["4-4-2", "4-3-3", "3-5-2"]
        var weighted: [(Formation, Double)] = []
        for formation in Formation.all {
            weighted.append((formation, balancedNames.contains(formation.name) ? 3 : 1))
        }
        let total = weighted.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<total, using: &generator)
        for (formation, weight) in weighted {
            roll -= weight
            if roll < 0 { return formation }
        }
        return weighted.last!.0
    }

    /// Overall offset (before clamping) applied on top of the slot's
    /// rating-derived baseline — defensive slots trend a touch higher,
    /// attacking slots a touch lower, for a "solid but not prolific"
    /// default opponent rather than a flat rating across the whole XI.
    private static func overallSkew(for broad: Position) -> Int {
        switch broad {
        case .goalkeeper: return 1
        case .defender: return 2
        case .midfielder: return 0
        case .forward: return -2
        }
    }

    /// Per-attribute offsets from the slot's overall, by broad position —
    /// four buckets, not eleven, mirroring the shape already visible
    /// across `LegendsCardDatabase`'s real cards (a striker's shooting/pace
    /// sit well above their overall and defending well below; a
    /// centre-back is the mirror image) so a synthesized XI doesn't read
    /// as flat, robotic stat lines.
    private static func attributeOffsets(for broad: Position) -> (pace: Int, shooting: Int, passing: Int, dribbling: Int, defending: Int, physical: Int) {
        switch broad {
        case .goalkeeper:  return (pace: -20, shooting: -40, passing: -10, dribbling: -30, defending: 15, physical: 10)
        case .defender:    return (pace: -5, shooting: -25, passing: -5, dribbling: -15, defending: 20, physical: 10)
        case .midfielder:  return (pace: 0, shooting: -10, passing: 10, dribbling: 5, defending: -5, physical: 0)
        case .forward:     return (pace: 10, shooting: 15, passing: -10, dribbling: 10, defending: -30, physical: 5)
        }
    }

    private static func clampedAttribute(_ value: Int) -> Int {
        min(99, max(20, value))
    }

    /// Synthesizes a full 11-player XI for `opponent`, deterministic on
    /// `opponent.name` — regenerating for the same opponent (e.g. on a
    /// view re-render) yields an identical roster rather than reshuffling.
    static func generateRoster(for opponent: LegendsOpponent) -> (formation: Formation, slots: [DetailedPosition], players: [SyntheticOpponentPlayer]) {
        var generator = SeededGenerator(seed: opponent.name)
        let formation = weightedFormation(using: &generator)
        let slots = formation.slotRoles()

        let players: [SyntheticOpponentPlayer] = slots.enumerated().map { index, role in
            let broad = role.broad
            let baseOverall = opponent.rating + overallSkew(for: broad) + Int.random(in: -6...6, using: &generator)
            let overall = min(99, max(30, baseOverall))
            let offsets = attributeOffsets(for: broad)
            let surname = surnames[Int.random(in: 0..<surnames.count, using: &generator)]
            return SyntheticOpponentPlayer(
                id: "opp-\(index)",
                name: surname,
                position: role,
                overall: overall,
                pace: clampedAttribute(overall + offsets.pace),
                shooting: clampedAttribute(overall + offsets.shooting),
                passing: clampedAttribute(overall + offsets.passing),
                dribbling: clampedAttribute(overall + offsets.dribbling),
                defending: clampedAttribute(overall + offsets.defending),
                physical: clampedAttribute(overall + offsets.physical),
                detailed: LegendsDetailedAttributes.synthesized(
                    overall: overall,
                    pace: clampedAttribute(overall + offsets.pace),
                    shooting: clampedAttribute(overall + offsets.shooting),
                    passing: clampedAttribute(overall + offsets.passing),
                    dribbling: clampedAttribute(overall + offsets.dribbling),
                    defending: clampedAttribute(overall + offsets.defending),
                    physical: clampedAttribute(overall + offsets.physical),
                    broad: broad,
                    seed: "\(opponent.name)-\(index)"
                )
            )
        }

        return (formation, slots, players)
    }
}
