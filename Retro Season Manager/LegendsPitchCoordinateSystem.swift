//
//  LegendsPitchCoordinateSystem.swift
//  Retro Season Manager
//
//  Phase 0 of the Legends 2D match simulator: a real numeric pitch
//  coordinate system, replacing the label-only row/index geometry
//  `DetailedPosition.expected(for:indexInRow:rowCount:)` already encodes.
//  Pure and dependency-free — no store, no live-match state — so it can
//  be unit-tested in isolation and reused later by the continuous-motion
//  simulation (Phase 1+) without pulling in view or engine code.
//
//  Coordinate space: x/y both normalized to 0...1, a single shared frame
//  for the whole pitch (not per-team-relative) — required later so shots,
//  passes and the offside line can compare positions across both sides
//  directly. y=0 is the opponent's goal line, y=1 is the user's own goal
//  line, matching `LegendsPitchView`'s existing top-to-bottom "forwards,
//  midfield, defence, GK" row order so this pitch visually rhymes with
//  the Squad screen players already know.
//

import Foundation

enum PitchCoordinateSystem {

    /// How deep (toward the user's own goal, y=1) each detailed role
    /// lines up by default, before mirroring for the opponent side. Roles
    /// `DetailedPosition.expected(for:...)` never actually produces for a
    /// formation-generated slot (e.g. `.attackingMid`) still get a sane
    /// depth so the table stays total over the whole enum, not just the
    /// subset `expected(for:)` happens to emit today.
    private static func rowDepth(for role: DetailedPosition) -> Double {
        switch role {
        case .goalkeeper: return 0.94
        case .centreBack: return 0.78
        case .leftBack, .rightBack: return 0.72
        case .holding: return 0.62
        case .centralMid: return 0.52
        case .attackingMid: return 0.40
        case .leftWing, .rightWing: return 0.28
        case .leftMid, .rightMid: return 0.50
        case .striker: return 0.16
        }
    }

    /// Even x-spread across a row: index 0 sits at the left-touchline
    /// margin, the last index at the right-touchline margin. A row of one
    /// (goalkeeper, a lone striker/holder) sits centered.
    private static func xPosition(indexInRow: Int, rowCount: Int) -> Double {
        guard rowCount > 1 else { return 0.5 }
        let margin = 0.12
        let span = 1 - margin * 2
        let step = span / Double(rowCount - 1)
        return margin + step * Double(indexInRow)
    }

    /// The formation-relative base position for one Starting XI slot,
    /// normalized 0...1 in the shared pitch frame. `team == .home` attacks
    /// toward y=0 (their own goal at y=1); `.away` is the mirror image
    /// (attacks toward y=1, own goal at y=0) — same row/index geometry,
    /// flipped depth.
    static func baseAnchor(role: DetailedPosition, indexInRow: Int, rowCount: Int, team: Side) -> CGPoint {
        let y = rowDepth(for: role)
        let x = xPosition(indexInRow: indexInRow, rowCount: rowCount)
        return CGPoint(x: x, y: team == .home ? y : 1 - y)
    }

    /// Every Starting XI slot's base anchor for a formation, in the same
    /// goalkeeper-first, defence/midfield/attack-row order
    /// `Formation.slotRoles()` already returns — so the two arrays line
    /// up index-for-index (`zip(formation.slotRoles(), anchors)`).
    static func anchors(for formation: Formation, team: Side) -> [CGPoint] {
        let rowCounts = [1, formation.defenders, formation.midfielders, formation.forwards]
        let roles = formation.slotRoles()
        var points: [CGPoint] = []
        var slotIndex = 0
        for rowCount in rowCounts {
            for indexInRow in 0..<rowCount {
                points.append(baseAnchor(role: roles[slotIndex], indexInRow: indexInRow, rowCount: rowCount, team: team))
                slotIndex += 1
            }
        }
        return points
    }
}
