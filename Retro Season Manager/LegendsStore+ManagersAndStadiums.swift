//
//  LegendsStore+ManagersAndStadiums.swift
//  Retro Season Manager
//
//  Managers & Stadiums logic (Phase 9): assigning the single active
//  manager/stadium, and the match-strength bonuses they contribute.
//

import Foundation

extension LegendsStore {
    var activeManager: LegendsManagerCard? {
        guard let id = profile.activeManagerID else { return nil }
        return LegendsManagerDatabase.all.first { $0.id == id }
    }

    var activeStadium: LegendsStadiumCard? {
        guard let id = profile.activeStadiumID else { return nil }
        return LegendsStadiumDatabase.all.first { $0.id == id }
    }

    /// Only an owned manager/stadium can be made active; `nil` always
    /// clears it.
    func setActiveManager(_ id: String?) {
        guard id == nil || profile.ownedManagerIDs.contains(id!) else { return }
        profile.activeManagerID = id
        persist()
    }

    func setActiveStadium(_ id: String?) {
        guard id == nil || profile.ownedStadiumIDs.contains(id!) else { return }
        profile.activeStadiumID = id
        persist()
    }

    /// The collectible Assistant and Stadium bonuses apply to every match.
    /// The Club Stadium facility is deliberately resolved separately because
    /// it is a home-ground benefit, not a generic team-strength modifier.
    var matchStrengthBonus: Double {
        Double((activeManager?.tacticalBonus ?? 0) + (activeStadium?.gameplayBonus ?? 0))
    }

    /// Resolves the complete pre-match strength bonus from the authoritative
    /// scheduled fixture. Only a fixture whose stored home team is this club
    /// receives the Club Stadium facility effect. Unscheduleable fallback
    /// matches, away fixtures, and malformed/stale fixture IDs receive no
    /// facility stadium bonus.
    func matchStrengthBonus(for opponent: LegendsOpponent) -> Double {
        let collectibleBonus = matchStrengthBonus
        guard let fixtureID = opponent.fixtureID,
              let fixture = profile.divisionSchedule.first(where: { $0.id == fixtureID }),
              fixture.homeTeamID == profile.clubName else {
            return collectibleBonus
        }
        return collectibleBonus + clubStadiumMatchStrengthBonus
    }

    /// Shared by the instant and live match paths so both use exactly the
    /// same home/away and unscheduled-fixture rule.
    func matchChemistryBonus(for opponent: LegendsOpponent) -> Double {
        Double(totalChemistry) * 0.3 + matchStrengthBonus(for: opponent)
    }
}
