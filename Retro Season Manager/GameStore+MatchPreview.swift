//
//  GameStore+MatchPreview.swift
//  Retro Season Manager
//
//  Pre-match preview data and other small derived views onto state.
//

import Foundation

extension GameStore {

    // MARK: - Match preview data

    /// A 1...5 star rating for a club, scaled across the league by strength.
    func starRating(forClubIndex index: Int) -> Int {
        starRatings(forClubIndices: [index])[index] ?? 1
    }

    /// A 1...5 fixture-difficulty rating for an upcoming opponent — just
    /// their own league-wide star rating, so a top club always reads as a
    /// tough game regardless of who's asking.
    func fixtureDifficulty(opponentIndex: Int) -> Int {
        starRating(forClubIndex: opponentIndex)
    }

    /// Star ratings for several clubs at once, sharing a single pass over
    /// every club's best XI instead of recomputing it per club requested.
    /// The full league-wide pass is genuinely expensive (every club's best
    /// XI across every formation), so it's cached for the current day
    /// rather than redone on every SwiftUI body evaluation — callers like
    /// the Home dashboard's fixture list can otherwise trigger it dozens
    /// of times a second during a single screen.
    func starRatings(forClubIndices indices: [Int]) -> [Int: Int] {
        if starRatingsCacheDate != currentDate {
            let strengths = clubs.indices.map { strengthValue(bestXI(for: clubs[$0], formation: aiFormation(for: clubs[$0]))) }
            let sorted = strengths.enumerated().sorted { $0.element > $1.element }
            let denominator = max(clubs.count - 1, 1)
            var cache: [Int: Int] = [:]
            for index in clubs.indices {
                let rank = sorted.firstIndex { $0.offset == index } ?? 0
                let stars = Int(round(5.0 - 4.0 * Double(rank) / Double(denominator)))
                cache[index] = min(5, max(1, stars))
            }
            starRatingsCache = cache
            starRatingsCacheDate = currentDate
        }
        var result: [Int: Int] = [:]
        for index in indices where clubs.indices.contains(index) {
            result[index] = starRatingsCache[index] ?? 1
        }
        return result
    }

    /// A club's recent results, oldest to newest, from its point of view.
    func recentForm(forClubIndex index: Int, count: Int = 5) -> [MatchOutcome] {
        let played = fixtures
            .filter { $0.played && ($0.homeIndex == index || $0.awayIndex == index) }
            .sorted { $0.matchday < $1.matchday }
            .suffix(count)
        return played.map { fixture in
            let isHome = fixture.homeIndex == index
            let scored = isHome ? fixture.homeGoals : fixture.awayGoals
            let conceded = isHome ? fixture.awayGoals : fixture.homeGoals
            if scored > conceded { return .win }
            if scored == conceded { return .draw }
            return .loss
        }
    }

    /// Win / draw / loss probabilities for a match between two clubs,
    /// derived from the same strength model the engine uses.
    func outcomeProbabilities(homeIndex: Int, awayIndex: Int) -> (home: Double, draw: Double, away: Double) {
        let homeStrength = strengthValue(matchXIForPreview(homeIndex)) + 40.0
        let awayStrength = strengthValue(matchXIForPreview(awayIndex))
        let ratio = homeStrength / (homeStrength + awayStrength)
        let homeExp = 2.7 * ratio
        let awayExp = 2.7 * (1.0 - ratio)

        func pmf(_ k: Int, _ lambda: Double) -> Double {
            var fact = 1.0
            for i in 1...max(k, 1) where k > 0 { fact *= Double(i) }
            return exp(-lambda) * pow(lambda, Double(k)) / (k == 0 ? 1.0 : fact)
        }

        var home = 0.0, draw = 0.0, away = 0.0
        for h in 0...8 {
            for a in 0...8 {
                let p = pmf(h, homeExp) * pmf(a, awayExp)
                if h > a { home += p } else if h == a { draw += p } else { away += p }
            }
        }
        let total = home + draw + away
        guard total > 0 else { return (0.34, 0.33, 0.33) }
        return (home / total, draw / total, away / total)
    }

    /// The XI used for previews (mirrors the engine's match selection).
    func matchXIForPreview(_ index: Int) -> [Player] {
        if index == userClubIndex { return userStartingXI() }
        return bestXI(for: clubs[index], formation: aiFormation(for: clubs[index]))
    }

    // MARK: - Derived views

    /// Clubs in a division, sorted into league-table order.
    func leagueTable(tier: Int) -> [Club] {
        clubs.filter { $0.divisionTier == tier }.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
            return $0.name < $1.name
        }
    }

    /// The user's own division table.
    func userTable() -> [Club] { leagueTable(tier: userDivisionTier) }

    /// The user club's current position in its division (1-based).
    var userPosition: Int {
        (userTable().firstIndex { $0.id == userClub.id } ?? 0) + 1
    }

    /// The 1-based position of any club within its own division.
    func position(ofClubIndex index: Int) -> Int {
        guard clubs.indices.contains(index) else { return 0 }
        let club = clubs[index]
        return (leagueTable(tier: club.divisionTier).firstIndex { $0.id == club.id } ?? 0) + 1
    }

    /// A short window of the user's fixtures: the most recent result plus
    /// the next few matches, for the home-screen summary.
    func userFixtureWindow(count: Int = 5) -> [Fixture] {
        let mine = fixtures
            .filter { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }
            .sorted { $0.matchday < $1.matchday }
        let nextIndex = mine.firstIndex { !$0.played } ?? mine.count
        let start = max(0, nextIndex - 1)
        return Array(mine[start..<min(start + count, mine.count)])
    }

    /// The user club's next unplayed fixture, if any.
    var nextUserFixture: Fixture? {
        fixtures.first { !$0.played && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    /// Every scheduled match the user is still involved in, across every
    /// competition, soonest first — the shared basis for "what's my next
    /// match" and "what's coming up after that".
    var upcomingUserMatches: [(date: Date, info: UserMatchInfo)] {
        let candidates: [(date: Date, info: UserMatchInfo)] = [
            nextUserCommunityShieldTie.map { tie in
                (communityShieldDate(), UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                               label: "\(Self.communityShieldName) · Final")) },
            nextUserUefaSuperCupTie.map { tie in
                (uefaSuperCupDate(), UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                               label: "\(Self.uefaSuperCupName) · Final")) },
            nextUserEuroDate.flatMap { date in nextUserEuroTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.euroName) · \(euroRoundName(tieCount: euroTies.count))")) } },
            nextUserUefaCupDate.flatMap { date in nextUserUefaCupTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.uefaCupName) · \(uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count))")) } },
            nextUserCupDate.flatMap { date in nextUserCupTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.cupName) · \(cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count))")) } },
            nextUserLeagueCupDate.flatMap { date in nextUserLeagueCupTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.leagueCupName) · \(leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count))")) } },
            nextUserFixtureDate.flatMap { date in nextUserFixture.map { fixture in
                (date, UserMatchInfo(homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex, isCup: false,
                                     label: divisionName(userDivisionTier))) } },
        ].compactMap { $0 }
        return candidates.sorted { $0.date < $1.date }
    }

    /// A unified description of the user's next match — league or cup,
    /// whichever comes first.
    var nextUserMatchInfo: UserMatchInfo? { upcomingUserMatches.first?.info }

    /// The top scorers in a division (defaults to the user's).
    func topScorers(limit: Int = 10, tier: Int? = nil) -> [(player: Player, club: Club)] {
        let divisionTier = tier ?? userDivisionTier
        var rows: [(Player, Club)] = []
        for club in clubs where club.divisionTier == divisionTier {
            for player in club.players where player.goals > 0 {
                rows.append((player, club))
            }
        }
        return rows
            .sorted { $0.0.goals > $1.0.goals }
            .prefix(limit)
            .map { (player: $0.0, club: $0.1) }
    }

    /// The champion of the user's division once the season is complete.
    var champion: Club? { isSeasonOver ? userTable().first : nil }

}
