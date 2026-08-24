//
//  LegendsChallenges.swift
//  Retro Season Manager
//
//  Challenges (Phase 8): Historic teams / Nation-only / Era-only squads
//  become "win a match fielding a Starting XI that's entirely one
//  club/nation/era" — checked against the live squad at the moment a
//  match is won, rather than a separate constrained team-selection mode
//  that doesn't exist. Daily and Weekly objectives reset on a calendar
//  boundary; Permanent ones are earned once and stay earned.
//

import Foundation

enum LegendsChallengeCadence: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case permanent = "Permanent"
}

enum LegendsChallengeKind: Codable, Equatable {
    case winMatches(Int)
    case scoreGoalsInOneMatch(Int)
    case cleanSheet
    case winStreak(Int)
    case sameNationXIWin
    case sameEraXIWin
    case sameClubXIWin
    case getPromoted
    case ownCards(Int)
    case playMatchesToday(Int)
    case winMatchesToday(Int)
    case winMatchesThisWeek(Int)
    case scoreGoalsThisWeek(Int)
    /// Win a match against an opponent rated at or above the user's own
    /// current team rating at kickoff.
    case beatStrongerOpponent
    /// Win with an active Manager set — directly rewards actually using
    /// the Managers system, which now has a real effect on live matches
    /// (see `LegendsLiveMatch.strengthBonus`).
    case winWithManager
    /// Win with an active Stadium set — same reasoning as `winWithManager`.
    case winWithStadium
    /// Win a match while playing in the World League, the top division.
    case winInTopDivision

    /// A small SF Symbol per challenge *category* — every challenge used
    /// to render identically regardless of kind (win-based, squad-
    /// composition-based, meta), which made a long list read as visually
    /// flat. Purely presentational, read by `LegendsChallengesView`.
    var glyph: String {
        switch self {
        case .winMatches, .winMatchesToday, .winMatchesThisWeek: return "trophy.fill"
        case .winStreak: return "flame.fill"
        case .scoreGoalsInOneMatch, .scoreGoalsThisWeek: return "soccerball"
        case .cleanSheet: return "shield.fill"
        case .sameNationXIWin: return "flag.fill"
        case .sameEraXIWin: return "clock.fill"
        case .sameClubXIWin: return "building.columns.fill"
        case .getPromoted, .winInTopDivision: return "arrow.up.circle.fill"
        case .ownCards: return "square.stack.fill"
        case .playMatchesToday: return "calendar"
        case .beatStrongerOpponent: return "bolt.fill"
        case .winWithManager: return "person.crop.circle.fill"
        case .winWithStadium: return "building.2.fill"
        }
    }
}

struct LegendsChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let cadence: LegendsChallengeCadence
    let kind: LegendsChallengeKind
    let coinReward: Int
    let tokenReward: Int
}

enum LegendsChallengeDatabase {
    static let all: [LegendsChallenge] = [
        LegendsChallenge(id: "first-win", title: "First Victory", description: "Win your first match.",
                          cadence: .permanent, kind: .winMatches(1), coinReward: 100, tokenReward: 0),
        LegendsChallenge(id: "hat-trick", title: "Hat-trick Hero", description: "Score 3 or more goals in a single match.",
                          cadence: .permanent, kind: .scoreGoalsInOneMatch(3), coinReward: 150, tokenReward: 0),
        LegendsChallenge(id: "clean-sheet", title: "Clean Sheet", description: "Win or draw without conceding a goal.",
                          cadence: .permanent, kind: .cleanSheet, coinReward: 100, tokenReward: 1),
        LegendsChallenge(id: "streak-3", title: "On A Roll", description: "Win 3 matches in a row.",
                          cadence: .permanent, kind: .winStreak(3), coinReward: 200, tokenReward: 1),
        LegendsChallenge(id: "streak-5", title: "Unstoppable", description: "Win 5 matches in a row.",
                          cadence: .permanent, kind: .winStreak(5), coinReward: 400, tokenReward: 2),
        LegendsChallenge(id: "one-flag", title: "One Flag", description: "Win a match with at least 6 Starting XI players sharing one nation.",
                          cadence: .permanent, kind: .sameNationXIWin, coinReward: 150, tokenReward: 1),
        LegendsChallenge(id: "one-era", title: "One Era", description: "Win a match with at least 6 Starting XI players sharing one era.",
                          cadence: .permanent, kind: .sameEraXIWin, coinReward: 150, tokenReward: 1),
        LegendsChallenge(id: "club-legends", title: "Historic XI", description: "Win a match with at least 6 Starting XI players sharing one club.",
                          cadence: .permanent, kind: .sameClubXIWin, coinReward: 200, tokenReward: 2),
        LegendsChallenge(id: "promoted", title: "Promotion", description: "Get promoted to a higher division.",
                          cadence: .permanent, kind: .getPromoted, coinReward: 100, tokenReward: 0),
        LegendsChallenge(id: "collector-10", title: "Growing Collection", description: "Own 10 or more cards.",
                          cadence: .permanent, kind: .ownCards(10), coinReward: 0, tokenReward: 1),

        LegendsChallenge(id: "daily-match", title: "Daily Match", description: "Play 1 match today.",
                          cadence: .daily, kind: .playMatchesToday(1), coinReward: 30, tokenReward: 0),
        LegendsChallenge(id: "daily-win", title: "Daily Win", description: "Win 1 match today.",
                          cadence: .daily, kind: .winMatchesToday(1), coinReward: 50, tokenReward: 1),

        LegendsChallenge(id: "weekly-wins", title: "Weekly Winner", description: "Win 3 matches this week.",
                          cadence: .weekly, kind: .winMatchesThisWeek(3), coinReward: 150, tokenReward: 1),
        LegendsChallenge(id: "weekly-goals", title: "Goal Rush", description: "Score 5 goals this week.",
                          cadence: .weekly, kind: .scoreGoalsThisWeek(5), coinReward: 100, tokenReward: 0),

        LegendsChallenge(id: "giant-killer", title: "Giant Killer", description: "Beat an opponent rated as strong as or stronger than your own team.",
                          cadence: .permanent, kind: .beatStrongerOpponent, coinReward: 200, tokenReward: 2),
        LegendsChallenge(id: "tactical-edge", title: "Tactical Edge", description: "Win a match with an active Manager set.",
                          cadence: .permanent, kind: .winWithManager, coinReward: 100, tokenReward: 1),
        LegendsChallenge(id: "home-advantage", title: "Home Advantage", description: "Win a match with an active Stadium set.",
                          cadence: .permanent, kind: .winWithStadium, coinReward: 100, tokenReward: 1),
        LegendsChallenge(id: "top-flight", title: "Top Flight", description: "Win a match in the World League.",
                          cadence: .permanent, kind: .winInTopDivision, coinReward: 250, tokenReward: 2),
        LegendsChallenge(id: "weekly-giant-killer", title: "Weekly Upset", description: "Beat a stronger-rated opponent this week.",
                          cadence: .weekly, kind: .beatStrongerOpponent, coinReward: 120, tokenReward: 1),
    ]
}
