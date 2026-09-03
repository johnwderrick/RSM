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
    let fixtureID: String?

    init(name: String, rating: Int, fixtureID: String? = nil) {
        self.name = name
        self.rating = rating
        self.fixtureID = fixtureID
    }
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
    var divisionSeasonResult: LegendsDivisionSeasonResult? = nil
}

extension LegendsStore {
    /// A pool of opponent names drawn from the same fictional club
    /// universe the card database already uses, so Legends stays one
    /// consistent football world rather than inventing a second one.
    private var opponentClubPool: [String] {
        let standings = divisionStandings().map(\.name).filter { $0 != profile.clubName }
        return standings.isEmpty ? ["Rival XI"] : standings
    }

    private var scheduledOpponentFixture: LegendsFixture? {
        ensureDivisionSchedule()
        return nextDivisionFixture
    }

    func scheduledOpponent() -> LegendsOpponent {
        guard let fixture = scheduledOpponentFixture else {
            return generateOpponent()
        }
        let opponentID = fixture.homeTeamID == profile.clubName ? fixture.awayTeamID : fixture.homeTeamID
        let base = 90 - profile.division.rawValue * 4
        let seed = abs(opponentID.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) & 0x7fffffff })
        let rating = min(99, max(35, base + (seed % 9) - 4))
        return LegendsOpponent(name: opponentID, rating: rating, fixtureID: fixture.id)
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

    /// Plays one match instantly against a freshly generated opponent —
    /// the pre-live-match-engine path, kept for anything that still wants
    /// an immediate result rather than watching it play out. Requires a
    /// complete Starting XI (mirrors the home screen's own "—" rating
    /// placeholder for an unset squad) — returns nil otherwise.
    func playMatch() -> LegendsMatchOutcomeSummary? {
        guard currentTeamRating > 0 else { return nil }
        let opponent = scheduledOpponentFixture == nil ? generateOpponent() : scheduledOpponent()
        let chemistryBonus = Double(totalChemistry) * 0.3 + matchStrengthBonus
        let result = LegendsMatchEngine.simulate(teamRating: currentTeamRating, opponentRating: opponent.rating,
                                                   chemistryBonus: chemistryBonus)
        return applyMatchOutcome(opponent: opponent, result: result)
    }

    private func scheduledScore(homeID: String, awayID: String) -> (home: Int, away: Int) {
        let seedText = "\(profile.divisionSeason)|\(homeID)|\(awayID)"
        let seed = abs(seedText.unicodeScalars.reduce(17) { ($0 * 31 + Int($1.value)) & 0x7fffffff })
        let home = seed % 4
        let away = (seed / 7) % 3
        return (home, away)
    }

    private func recordFixture(_ fixture: LegendsFixture, homeGoals: Int, awayGoals: Int) {
        guard let homeIndex = profile.divisionTable.firstIndex(where: { $0.id == fixture.homeTeamID }),
              let awayIndex = profile.divisionTable.firstIndex(where: { $0.id == fixture.awayTeamID }) else { return }

        profile.divisionTable[homeIndex].played += 1
        profile.divisionTable[homeIndex].goalsFor += homeGoals
        profile.divisionTable[homeIndex].goalsAgainst += awayGoals
        profile.divisionTable[awayIndex].played += 1
        profile.divisionTable[awayIndex].goalsFor += awayGoals
        profile.divisionTable[awayIndex].goalsAgainst += homeGoals

        if homeGoals > awayGoals {
            profile.divisionTable[homeIndex].won += 1
            profile.divisionTable[awayIndex].lost += 1
        } else if homeGoals < awayGoals {
            profile.divisionTable[homeIndex].lost += 1
            profile.divisionTable[awayIndex].won += 1
        } else {
            profile.divisionTable[homeIndex].drawn += 1
            profile.divisionTable[awayIndex].drawn += 1
        }
    }

    private func recordScheduledFixture(opponent: LegendsOpponent, result: LegendsMatchEngine.Result) -> LegendsDivisionSeasonResult? {
        ensureDivisionSchedule()
        guard let fixtureIndex = profile.divisionSchedule.firstIndex(where: { $0.id == opponent.fixtureID }),
              !profile.divisionSchedule[fixtureIndex].isPlayed else { return nil }

        let fixture = profile.divisionSchedule[fixtureIndex]
        let userIsHome = fixture.homeTeamID == profile.clubName
        let homeGoals = userIsHome ? result.teamGoals : result.opponentGoals
        let awayGoals = userIsHome ? result.opponentGoals : result.teamGoals
        profile.divisionSchedule[fixtureIndex].homeGoals = homeGoals
        profile.divisionSchedule[fixtureIndex].awayGoals = awayGoals
        recordFixture(fixture, homeGoals: homeGoals, awayGoals: awayGoals)

        // Resolve the rest of the round at the same time. This keeps the
        // table honest without simulating matches the player never watched.
        let round = fixture.round
        for index in profile.divisionSchedule.indices where profile.divisionSchedule[index].round == round && !profile.divisionSchedule[index].isPlayed {
            let other = profile.divisionSchedule[index]
            let score = scheduledScore(homeID: other.homeTeamID, awayID: other.awayTeamID)
            profile.divisionSchedule[index].homeGoals = score.home
            profile.divisionSchedule[index].awayGoals = score.away
            recordFixture(other, homeGoals: score.home, awayGoals: score.away)
        }

        if divisionFixturesRemaining == 0 {
            return settleDivisionSeason()
        }
        return nil
    }

    /// Applies rank pressure only at the end of a complete schedule. The
    /// bottom two are relegated when a lower division exists; the top two
    /// rise when a higher division exists. World League and Division 10
    /// clamp at their respective boundaries.
    private func settleDivisionSeason() -> LegendsDivisionSeasonResult? {
        let standings = divisionStandings()
        guard let finalRank = standings.firstIndex(where: { $0.id == profile.clubName }) else { return nil }
        let previousDivision = profile.division
        let rank = finalRank + 1
        let totalTeams = standings.count
        let seasonOutcome = Self.seasonOutcome(finalRank: rank, totalTeams: totalTeams, division: previousDivision)
        let outcome = seasonOutcome.outcome
        let newDivision = seasonOutcome.newDivision
        let reward = Self.seasonReward(for: outcome)
        profile.coins += reward.coins
        profile.packTokens += reward.tokens
        profile.managerXP += reward.managerXP
        profile.division = newDivision
        profile.divisionWins = 0
        profile.divisionSeason += 1
        let result = LegendsDivisionSeasonResult(season: profile.divisionSeason - 1, finalRank: rank,
                                                 totalTeams: totalTeams, outcome: outcome,
                                                 previousDivision: previousDivision, newDivision: newDivision,
                                                 reward: reward)
        profile.lastDivisionSeasonResult = result
        resetDivisionTable()
        return result
    }

    /// Runs the reward/promotion/challenge/manager-stadium/aging pipeline
    /// for a completed result, however it was produced — the instant
    /// `playMatch()` above, or a `LegendsLiveMatch` that's just finished.
    /// Call this exactly once per completed match; `advanceSeasonIfNeeded()`
    /// inside it assumes one call == one match played.
    func applyMatchOutcome(
        opponent: LegendsOpponent,
        result: LegendsMatchEngine.Result,
        events: [LegendsMatchEvent] = [],
        startingCardIDs: [String]? = nil,
        minutesPlayedByCardID: [String: Int]? = nil
    ) -> LegendsMatchOutcomeSummary {
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
        let divisionSeasonResult: LegendsDivisionSeasonResult?
        if opponent.fixtureID == nil {
            recordDivisionMatch(teamGoals: result.teamGoals, opponentGoals: result.opponentGoals, opponentName: opponent.name)
            divisionSeasonResult = nil
        } else {
            divisionSeasonResult = recordScheduledFixture(opponent: opponent, result: result)
        }
        if let divisionSeasonResult {
            promoted = divisionSeasonResult.outcome == .champion || divisionSeasonResult.outcome == .promoted
        }

        if result.outcome == .win {
            if opponent.fixtureID == nil {
                profile.divisionWins += 1
            }
            if opponent.fixtureID == nil,
               profile.divisionWins >= Self.winsToPromote,
               profile.division != .worldLeague {
                profile.divisionWins = 0
                profile.division = LegendsDivision(rawValue: profile.division.rawValue - 1) ?? .worldLeague
                resetDivisionTable()
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

        // Live matches supply their immutable event ledger and real
        // participation snapshot. Instant simulation keeps the legacy
        // fallback through the default arguments.
        recordCareerMatch(
            result,
            events: events,
            startingCardIDs: startingCardIDs,
            minutesPlayedByCardID: minutesPlayedByCardID
        )

        // Every match counts toward the current season, win or not —
        // aging doesn't care about the scoreline, only that time passed.
        let seasonAdvance = advanceSeasonIfNeeded(divisionResult: divisionSeasonResult)

        var summary = LegendsMatchOutcomeSummary(opponent: opponent, result: result, coinsEarned: coins, tokensEarned: tokens,
                                                  xpEarned: xp, leveledUp: leveledUp, promoted: promoted, newDivision: profile.division,
                                                  newManager: newManager, newStadium: newStadium, seasonAdvance: seasonAdvance,
                                                  divisionSeasonResult: divisionSeasonResult)
        // recordMatchResult persists — it runs last so it sees every
        // stat this match just updated (division, manager level, etc.)
        summary.completedChallenges = recordMatchResult(summary)
        recordManagerMatch(summary.result,
                           divisionSeasonResult: summary.divisionSeasonResult,
                           completedChallengeCount: summary.completedChallenges.count)
        return summary
    }
}
