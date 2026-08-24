//
//  SeasonObjectives.swift
//  Retro Season Manager
//
//  Season Objectives: four richer, specific goals rolled each season
//  alongside the board's own flat objective — same typed-kind/centralized-
//  evaluation shape as Legends' LegendsChallengeKind/LegendsChallengeDatabase,
//  since these are season-scoped and resettable rather than career-permanent
//  like AchievementKind.
//

import Foundation

enum SeasonObjectiveKind: Codable, Equatable {
    case beatRival
    case academyBreakthrough(minApps: Int)
    case cleanSheetWall(Int)
    case finishAboveClub(clubName: String)
    case cupQuarterFinal
    case wageDiscipline
    case signYoungPlayer(maxAge: Int)
    case protectFanFavourite
    case improveFanConfidence
    case homeUnbeatenRun(Int)

    /// A small SF Symbol per kind, read by `SeasonObjectivesView` — same
    /// presentational role as `LegendsChallengeKind.glyph`.
    var glyph: String {
        switch self {
        case .beatRival:            return "bolt.fill"
        case .academyBreakthrough:  return "graduationcap.fill"
        case .cleanSheetWall:       return "shield.fill"
        case .finishAboveClub:      return "arrow.up.right.circle.fill"
        case .cupQuarterFinal:      return "trophy.fill"
        case .wageDiscipline:       return "banknote.fill"
        case .signYoungPlayer:      return "person.badge.plus.fill"
        case .protectFanFavourite:  return "heart.fill"
        case .improveFanConfidence: return "megaphone.fill"
        case .homeUnbeatenRun:      return "house.fill"
        }
    }
}

struct SeasonObjective: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let kind: SeasonObjectiveKind
}

extension GameStore {

    /// Rolls four fresh Season Objectives for the new season, resolving
    /// the rival-facing kinds against `rivalClubIndex` (always non-nil —
    /// it falls back to the strongest same-tier club) and resetting every
    /// tracking flag the season's evaluation depends on. Called right
    /// after `setBoardObjective()` in both `newGame()` and
    /// `startNextSeason()`.
    func setSeasonObjectives() {
        let rivalName = rivalClubIndex.map { clubs[$0].name } ?? "your rivals"
        let pool: [SeasonObjective] = [
            SeasonObjective(id: "beat-rival", title: "Settle the Score",
                             description: "Beat \(rivalName) this season.", kind: .beatRival),
            SeasonObjective(id: "academy-breakthrough", title: "Academy Breakthrough",
                             description: "Give a youth-promoted player 5 first-team appearances.",
                             kind: .academyBreakthrough(minApps: 5)),
            SeasonObjective(id: "clean-sheet-wall", title: "Clean Sheet Wall",
                             description: "Keep 8 clean sheets this season.", kind: .cleanSheetWall(8)),
            SeasonObjective(id: "finish-above-rival", title: "Local Bragging Rights",
                             description: "Finish the season above \(rivalName) in the table.",
                             kind: .finishAboveClub(clubName: rivalName)),
            SeasonObjective(id: "cup-quarter-final", title: "Cup Run",
                             description: "Reach the quarter-finals of the \(Self.cupName).", kind: .cupQuarterFinal),
            SeasonObjective(id: "wage-discipline", title: "Wage Discipline",
                             description: "Keep the wage bill under 90% of the wage budget.", kind: .wageDiscipline),
            SeasonObjective(id: "sign-young-player", title: "Ones to Watch",
                             description: "Sign a player aged 21 or younger.", kind: .signYoungPlayer(maxAge: 21)),
            SeasonObjective(id: "protect-fan-favourite", title: "Keep the Faithful Happy",
                             description: "Don't sell a fan favourite this season.", kind: .protectFanFavourite),
            SeasonObjective(id: "improve-fan-confidence", title: "Winning Them Over",
                             description: "End the season with higher fan confidence than you started with.",
                             kind: .improveFanConfidence),
            SeasonObjective(id: "home-unbeaten-run", title: "Fortress",
                             description: "Go 6 home matches unbeaten.", kind: .homeUnbeatenRun(6)),
        ]
        seasonObjectives = Array(pool.shuffled().prefix(4))
        completedSeasonObjectiveIDs = []
        fanConfidenceAtSeasonStart = fanConfidence
        rivalWinThisSeason = false
        youthPromotedThisSeasonIDs = []
        reachedCupQuarterFinalThisSeason = false
        soldFanFavouriteThisSeason = false
        signedYoungPlayerThisSeason = false
        // Bank the season just finished (nothing to bank on a fresh
        // newGame(), where no home match has been played yet) before
        // resetting the running totals for the new one.
        if seasonHomeMatchesPlayed > 0 {
            attendanceHistory.append(seasonAttendanceTotal / seasonHomeMatchesPlayed)
        }
        seasonAttendanceTotal = 0
        seasonHomeMatchesPlayed = 0
        fanCampaignFiredThisSeason = false
    }
}
