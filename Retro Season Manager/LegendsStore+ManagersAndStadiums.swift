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

    /// Combined flat bonus fed into LegendsMatchEngine's team strength —
    /// the doc's "tactical bonuses" (Managers) and "small gameplay
    /// bonus" (Stadiums).
    var matchStrengthBonus: Double {
        Double((activeManager?.tacticalBonus ?? 0) + (activeStadium?.gameplayBonus ?? 0))
    }
}
