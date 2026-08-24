//
//  GameStore+SeasonObjectives.swift
//  Retro Season Manager
//
//  Evaluates and rewards this season's Season Objectives — a single,
//  idempotent sweep called at every user match result (via `updateBoard`)
//  and once more at season end (via `recordSeasonHonours`), mirroring
//  `unlock(_:)`'s idempotency without scattering condition checks across
//  every call site the way `AchievementKind` does.
//

import Foundation

extension GameStore {

    /// Checks every not-yet-completed objective against current state and
    /// rewards any that now qualify. `isSeasonEnd` gates the handful of
    /// kinds that only make sense as a final verdict (a mid-season "fan
    /// confidence is up" or "still above the rival" reading could easily
    /// flip back before the season actually ends).
    @discardableResult
    func checkSeasonObjectives(isSeasonEnd: Bool = false) -> Bool {
        var anyCompleted = false
        for objective in seasonObjectives where !completedSeasonObjectiveIDs.contains(objective.id) {
            if seasonObjectiveConditionMet(objective.kind, isSeasonEnd: isSeasonEnd) {
                completeSeasonObjective(objective)
                anyCompleted = true
            }
        }
        return anyCompleted
    }

    private func seasonObjectiveConditionMet(_ kind: SeasonObjectiveKind, isSeasonEnd: Bool) -> Bool {
        switch kind {
        case .beatRival:
            return rivalWinThisSeason
        case .academyBreakthrough(let minApps):
            return youthPromotedThisSeasonIDs.contains { id in
                (userClub.players.first { $0.id == id }?.apps ?? 0) >= minApps
            }
        case .cleanSheetWall(let target):
            return userClub.players.reduce(0) { $0 + $1.cleanSheets } >= target
        case .finishAboveClub(let clubName):
            guard isSeasonEnd, let rival = clubs.first(where: { $0.name == clubName }) else { return false }
            if userClub.divisionTier != rival.divisionTier { return userClub.divisionTier < rival.divisionTier }
            let rivalPosition = (leagueTable(tier: rival.divisionTier).firstIndex { $0.id == rival.id } ?? Int.max - 1) + 1
            return userPosition < rivalPosition
        case .cupQuarterFinal:
            return reachedCupQuarterFinalThisSeason
        case .wageDiscipline:
            return Double(userClub.wageBill) <= Double(userClub.wageBudget) * 0.9
        case .signYoungPlayer:
            return signedYoungPlayerThisSeason
        case .protectFanFavourite:
            return isSeasonEnd && !soldFanFavouriteThisSeason
        case .improveFanConfidence:
            return isSeasonEnd && fanConfidence > fanConfidenceAtSeasonStart
        case .homeUnbeatenRun(let target):
            return homeUnbeatenStreak >= target
        }
    }

    private func completeSeasonObjective(_ objective: SeasonObjective) {
        completedSeasonObjectiveIDs.insert(objective.id)
        managerReputation = min(100, managerReputation + 2)
        fanConfidence = min(100, fanConfidence + 3)
        careerAchievementPoints += 1
        addNews(.board, "Objective complete: \(objective.title)", objective.description)
    }
}
