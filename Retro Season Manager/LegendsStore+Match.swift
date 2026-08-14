//
//  LegendsStore+Match.swift
//  Retro Season Manager
//
//  Play Match orchestration (Phase 7): generates a division-scaled
//  opponent, runs LegendsMatchEngine, and applies Rewards (Coins, Pack
//  Tokens, Manager XP, Manager/Stadium Cards — Phase 9) plus Division
//  promotion. "Special Packs" from the doc's Rewards list still isn't
//  given: there's no separate "special" pack tier distinct from the
//  Phase 4 catalog to draw from.
//

import Foundation

struct LegendsOpponent {
    let name: String
    let rating: Int
}

struct LegendsMatchOutcomeSummary {
    let opponent: LegendsOpponent
    let result: LegendsMatchEngine.Result
    let coinsEarned: Int
    let tokensEarned: Int
    let xpEarned: Int
    let leveledUp: Bool
    let promoted: Bool
    let newDivision: LegendsDivision
    var completedChallenges: [LegendsChallengeCompletion] = []
    var newManager: LegendsManagerCard? = nil
    var newStadium: LegendsStadiumCard? = nil
    var seasonAdvance: LegendsSeasonAdvanceResult? = nil
}

extension LegendsStore {
    /// A pool of opponent names drawn from the same fictional club
    /// universe the card database already uses, so Legends stays one
    /// consistent football world rather than inventing a second one.
    private var opponentClubPool: [String] {
        let clubs = Set(LegendsCardDatabase.all.map(\.club)).subtracting(["Portugal"])
        return Array(clubs).sorted()
    }

    /// A fresh opponent scaled to the current division — World League
    /// (rawValue 0) is the toughest, Division 10 (rawValue 10) the
    /// easiest, with a little variance so the same division doesn't
    /// always feel identical.
    func generateOpponent() -> LegendsOpponent {
        let base = 90 - profile.division.rawValue * 4
        let rating = min(99, max(35, base + Int.random(in: -5...5)))
        let name = opponentClubPool.randomElement() ?? "Rival XI"
        return LegendsOpponent(name: name, rating: rating)
    }

    /// Plays one match against a freshly generated opponent. Requires a
    /// complete Starting XI (mirrors the home screen's own "—" rating
    /// placeholder for an unset squad) — returns nil otherwise.
    func playMatch() -> LegendsMatchOutcomeSummary? {
        guard currentTeamRating > 0 else { return nil }

        let opponent = generateOpponent()
        let chemistryBonus = Double(totalChemistry) * 0.3 + matchStrengthBonus
        let result = LegendsMatchEngine.simulate(teamRating: currentTeamRating, opponentRating: opponent.rating,
                                                   chemistryBonus: chemistryBonus)

        let coins: Int
        let tokens: Int
        let xp: Int
        switch result.outcome {
        case .win: coins = 50; tokens = 1; xp = 30
        case .draw: coins = 20; tokens = 0; xp = 10
        case .loss: coins = 10; tokens = 0; xp = 5
        }
        profile.coins += coins
        profile.packTokens += tokens
        profile.managerXP += xp

        let levelThreshold = profile.managerLevel * 100
        var leveledUp = false
        if profile.managerXP >= levelThreshold {
            profile.managerXP -= levelThreshold
            profile.managerLevel += 1
            leveledUp = true
        }

        var promoted = false
        var newManager: LegendsManagerCard? = nil
        var newStadium: LegendsStadiumCard? = nil
        if result.outcome == .win {
            profile.divisionWins += 1
            if profile.divisionWins >= Self.winsToPromote, profile.division != .worldLeague {
                profile.divisionWins = 0
                profile.division = LegendsDivision(rawValue: profile.division.rawValue - 1) ?? .worldLeague
                promoted = true
            }

            // Manager/Stadium Cards from the doc's Rewards list — a
            // modest independent chance per win, only from cards not
            // already owned.
            if let manager = LegendsManagerDatabase.all.filter({ !profile.ownedManagerIDs.contains($0.id) }).randomElement(),
               Double.random(in: 0...1) < 0.2 {
                profile.ownedManagerIDs.insert(manager.id)
                newManager = manager
            }
            if let stadium = LegendsStadiumDatabase.all.filter({ !profile.ownedStadiumIDs.contains($0.id) }).randomElement(),
               Double.random(in: 0...1) < 0.2 {
                profile.ownedStadiumIDs.insert(stadium.id)
                newStadium = stadium
            }
        }

        // Every match counts toward the current season, win or not —
        // aging doesn't care about the scoreline, only that time passed.
        let seasonAdvance = advanceSeasonIfNeeded()

        var summary = LegendsMatchOutcomeSummary(opponent: opponent, result: result, coinsEarned: coins, tokensEarned: tokens,
                                                  xpEarned: xp, leveledUp: leveledUp, promoted: promoted, newDivision: profile.division,
                                                  newManager: newManager, newStadium: newStadium, seasonAdvance: seasonAdvance)
        // recordMatchResult persists — it runs last so it sees every
        // stat this match just updated (division, manager level, etc.)
        summary.completedChallenges = recordMatchResult(summary)
        return summary
    }
}
