//
//  LegendsStore+Challenges.swift
//  Retro Season Manager
//
//  Challenge progress and rewards (Phase 8), driven by match results
//  from LegendsStore+Match.swift's playMatch().
//

import Foundation

struct LegendsChallengeCompletion {
    let challenge: LegendsChallenge
}

extension LegendsStore {
    /// Resets Daily/Weekly counters and their completed-challenge sets
    /// when the calendar day/week has rolled over since they were last
    /// touched. Cheap and idempotent — safe to call from any screen
    /// that displays challenge state, not just after a match.
    func refreshChallengeCadences() {
        let cal = Calendar.current
        if !cal.isDateInToday(profile.lastDailyReset) {
            profile.lastDailyReset = Date()
            profile.matchesToday = 0
            profile.winsToday = 0
            profile.completedDailyChallengeIDs = []
        }
        let now = Date()
        let sameWeek = cal.component(.yearForWeekOfYear, from: profile.lastWeeklyReset) == cal.component(.yearForWeekOfYear, from: now)
            && cal.component(.weekOfYear, from: profile.lastWeeklyReset) == cal.component(.weekOfYear, from: now)
        if !sameWeek {
            profile.lastWeeklyReset = now
            profile.winsThisWeek = 0
            profile.goalsThisWeek = 0
            profile.completedWeeklyChallengeIDs = []
        }
    }

    private var startingXICards: [LegendsCard] {
        profile.startingXICardIDs.compactMap { $0 }.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
    }

    /// Updates every running stat, then grants any challenge whose
    /// condition is newly met. Called once per match from `playMatch()`.
    @discardableResult
    func recordMatchResult(_ summary: LegendsMatchOutcomeSummary) -> [LegendsChallengeCompletion] {
        refreshChallengeCadences()

        profile.matchesToday += 1
        profile.goalsThisWeek += summary.result.teamGoals
        if summary.result.outcome == .win {
            profile.totalWins += 1
            profile.currentWinStreak += 1
            profile.winsToday += 1
            profile.winsThisWeek += 1
        } else {
            profile.currentWinStreak = 0
        }

        // A literal "all 11 share one nation/era/club" is unreachable
        // with the current 40-card database (max nation count is 7,
        // "France" — see LegendsCardDatabaseTests) — a shared "core" of
        // Self.xiShareThreshold is the achievable version of the same idea.
        let xi = startingXICards
        func maxShared<T: Hashable>(_ key: (LegendsCard) -> T) -> Int {
            guard xi.count == startingXISlots.count else { return 0 }
            return Dictionary(grouping: xi, by: key).map(\.value.count).max() ?? 0
        }
        let sameNation = maxShared(\.nation) >= Self.xiShareThreshold
        let sameEra = maxShared(\.era) >= Self.xiShareThreshold
        let sameClub = maxShared(\.club) >= Self.xiShareThreshold

        var completions: [LegendsChallengeCompletion] = []
        for challenge in LegendsChallengeDatabase.all {
            guard !isCompleted(challenge) else { continue }
            let met: Bool
            switch challenge.kind {
            case .winMatches(let n): met = profile.totalWins >= n
            case .scoreGoalsInOneMatch(let n): met = summary.result.teamGoals >= n
            case .cleanSheet: met = summary.result.outcome != .loss && summary.result.opponentGoals == 0
            case .winStreak(let n): met = profile.currentWinStreak >= n
            case .sameNationXIWin: met = summary.result.outcome == .win && sameNation
            case .sameEraXIWin: met = summary.result.outcome == .win && sameEra
            case .sameClubXIWin: met = summary.result.outcome == .win && sameClub
            case .getPromoted: met = summary.promoted
            case .ownCards(let n): met = profile.ownedCardIDs.count >= n
            case .playMatchesToday(let n): met = profile.matchesToday >= n
            case .winMatchesToday(let n): met = profile.winsToday >= n
            case .winMatchesThisWeek(let n): met = profile.winsThisWeek >= n
            case .scoreGoalsThisWeek(let n): met = profile.goalsThisWeek >= n
            case .beatStrongerOpponent: met = summary.result.outcome == .win && summary.opponent.rating >= currentTeamRating
            case .winWithManager: met = summary.result.outcome == .win && profile.activeManagerID != nil
            case .winWithStadium: met = summary.result.outcome == .win && profile.activeStadiumID != nil
            case .winInTopDivision: met = summary.result.outcome == .win && profile.division == .worldLeague
            }
            if met {
                grant(challenge)
                completions.append(LegendsChallengeCompletion(challenge: challenge))
            }
        }

        persist()
        return completions
    }

    func isCompleted(_ challenge: LegendsChallenge) -> Bool {
        switch challenge.cadence {
        case .permanent: return profile.completedPermanentChallengeIDs.contains(challenge.id)
        case .daily: return profile.completedDailyChallengeIDs.contains(challenge.id)
        case .weekly: return profile.completedWeeklyChallengeIDs.contains(challenge.id)
        }
    }

    private func grant(_ challenge: LegendsChallenge) {
        profile.coins += challenge.coinReward
        profile.packTokens += challenge.tokenReward
        switch challenge.cadence {
        case .permanent: profile.completedPermanentChallengeIDs.insert(challenge.id)
        case .daily: profile.completedDailyChallengeIDs.insert(challenge.id)
        case .weekly: profile.completedWeeklyChallengeIDs.insert(challenge.id)
        }
    }

    /// 0...1 progress for display — best-effort for count-based kinds,
    /// binary (0 or 1) for one-shot conditions that only get evaluated
    /// against a real match result.
    func progress(for challenge: LegendsChallenge) -> Double {
        if isCompleted(challenge) { return 1 }
        switch challenge.kind {
        case .winMatches(let n): return min(1, Double(profile.totalWins) / Double(n))
        case .winStreak(let n): return min(1, Double(profile.currentWinStreak) / Double(n))
        case .ownCards(let n): return min(1, Double(profile.ownedCardIDs.count) / Double(n))
        case .playMatchesToday(let n): return min(1, Double(profile.matchesToday) / Double(n))
        case .winMatchesToday(let n): return min(1, Double(profile.winsToday) / Double(n))
        case .winMatchesThisWeek(let n): return min(1, Double(profile.winsThisWeek) / Double(n))
        case .scoreGoalsThisWeek(let n): return min(1, Double(profile.goalsThisWeek) / Double(n))
        case .scoreGoalsInOneMatch, .cleanSheet, .sameNationXIWin, .sameEraXIWin, .sameClubXIWin, .getPromoted,
             .beatStrongerOpponent, .winWithManager, .winWithStadium, .winInTopDivision:
            return 0
        }
    }
}
