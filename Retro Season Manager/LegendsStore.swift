//
//  LegendsStore.swift
//  Retro Season Manager
//
//  The single source of truth for RSM Legends — a standalone collecting
//  mode with its own save file and progression, entirely separate from
//  Career Mode's GameStore. Mirrors GameStore's own single-observable,
//  file-per-domain convention rather than introducing several small
//  observables for one mode.
//

import Foundation
import SwiftUI

enum LegendsDivision: Int, Codable, CaseIterable {
    case worldLeague = 0
    case division1 = 1, division2, division3, division4, division5
    case division6, division7, division8, division9, division10

    var displayName: String {
        self == .worldLeague ? "World League" : "Division \(rawValue)"
    }
}

struct LegendsDivisionRecord: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var played: Int
    var won: Int
    var drawn: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int

    var goalDifference: Int { goalsFor - goalsAgainst }
    var points: Int { won * 3 + drawn }
}

/// One scheduled home-and-away league fixture. The user's match is played
/// live; the other fixtures in that round are resolved deterministically when
/// the round closes so the table and schedule always move together.
struct LegendsFixture: Codable, Hashable, Identifiable {
    let id: String
    let round: Int
    let homeTeamID: String
    let awayTeamID: String
    var homeGoals: Int? = nil
    var awayGoals: Int? = nil

    var isPlayed: Bool { homeGoals != nil && awayGoals != nil }
}

struct LegendsSeasonReward: Codable, Hashable {
    let coins: Int
    let tokens: Int
    let managerXP: Int
}

enum LegendsDivisionSeasonOutcome: String, Codable, Hashable {
    case champion
    case promoted
    case retained
    case relegated

    var displayName: String {
        switch self {
        case .champion: return "DIVISION CHAMPIONS"
        case .promoted: return "PROMOTED"
        case .retained: return "DIVISION RETAINED"
        case .relegated: return "RELEGATED"
        }
    }
}

struct LegendsDivisionSeasonResult: Codable, Hashable {
    let season: Int
    let finalRank: Int
    let totalTeams: Int
    let outcome: LegendsDivisionSeasonOutcome
    let previousDivision: LegendsDivision
    let newDivision: LegendsDivision
    let reward: LegendsSeasonReward
}

enum LegendsDivisionTable {
    private static let clubNames = [
        "RSM Legends FC", "Northstar Athletic", "Neon Borough", "Crown City",
        "Harbour Rovers", "Vertex United", "Silverline FC", "Atlas Town"
    ]

    static func seed(userClub: String) -> [LegendsDivisionRecord] {
        var names = clubNames
        if !names.contains(userClub) {
            names[0] = userClub
        }
        return names.map { name in
            LegendsDivisionRecord(id: name, name: name, played: 0, won: 0, drawn: 0, lost: 0,
                                  goalsFor: 0, goalsAgainst: 0)
        }
    }

    /// Generates a deterministic double round-robin using the circle method:
    /// eight clubs, fourteen rounds, four fixtures per round, with every
    /// pairing appearing once at home and once away.
    static func schedule(clubIDs: [String], season: Int) -> [LegendsFixture] {
        guard clubIDs.count >= 2, clubIDs.count.isMultiple(of: 2) else { return [] }
        let count = clubIDs.count
        var rotation = clubIDs
        var fixtures: [LegendsFixture] = []

        for round in 0..<(count - 1) {
            for index in 0..<(count / 2) {
                let first = rotation[index]
                let second = rotation[count - 1 - index]
                let home = (round + index).isMultiple(of: 2) ? first : second
                let away = home == first ? second : first
                fixtures.append(LegendsFixture(id: "S\(season)-R\(round + 1)-\(index + 1)",
                                                round: round + 1,
                                                homeTeamID: home,
                                                awayTeamID: away))
            }
            // Keep the first club fixed and rotate every other club one
            // place clockwise. This guarantees exactly one fixture per club
            // in every round.
            let last = rotation.removeLast()
            rotation.insert(last, at: 1)
        }

        let firstHalf = fixtures
        for fixture in firstHalf {
            fixtures.append(LegendsFixture(id: "S\(season)-R\(fixture.round + count - 1)-\(fixture.awayTeamID)-\(fixture.homeTeamID)",
                                            round: fixture.round + count - 1,
                                            homeTeamID: fixture.awayTeamID,
                                            awayTeamID: fixture.homeTeamID))
        }
        return fixtures
    }
}

struct LegendsProfile: Codable {
    var clubName: String
    var crestShort: String
    var crestColorRGB: [Double]
    var managerLevel: Int
    var managerXP: Int
    var coins: Int
    var packTokens: Int
    var division: LegendsDivision
    var teamRating: Int
    /// IDs into `LegendsCardDatabase.all` — populated by opening packs
    /// (Phase 4).
    var ownedCardIDs: Set<String> = []
    /// Cards that have crossed the signing boundary. A signed card stays
    /// active even if it is later dropped from the XI, so it can never be
    /// returned to frozen Collection status.
    var activatedCardIDs: Set<String> = []
    /// One persisted record per current signed career. Unsigned collection
    /// cards intentionally have no entry here and therefore never age.
    var playerCareers: [String: LegendsPlayerCareer] = [:]
    /// Completed careers remain permanently visible even after their card
    /// is removed from the active collection and can later be packed again.
    var legendsHall: [LegendsHallEntry] = []
    /// All-time club records (Phase 2), persisted across seasons and
    /// surviving the player who set them.
    var clubRecords: [LegendsClubRecordKind: LegendsClubRecordEntry] = [:]
    /// The most recent end-of-season development review, shown on the home
    /// dashboard once and cleared when the player dismisses it.
    var lastSeasonReview: [String: LegendsSeasonReviewEntry] = [:]
    /// Duplicate pulls not yet consumed into an upgrade, keyed by card ID.
    /// Resets to 0 (and bumps `cardUpgrades`) every 3rd duplicate.
    var duplicateProgress: [String: Int] = [:]
    /// Permanent +OVR earned per card from duplicates, capped at
    /// `LegendsStore.maxCardUpgrade` to keep the doc's "maximum rating
    /// capped to maintain realism" rule.
    var cardUpgrades: [String: Int] = [:]
    /// Squad Builder (Phase 5). `startingXICardIDs` is indexed the same
    /// way as `LegendsStore.startingXISlots` for the current formation
    /// (GK, then defenders/midfielders/forwards rows); `nil` = empty
    /// slot. Resized by `LegendsStore.setFormation(_:)` when the
    /// formation changes.
    var formationName: String = "4-4-2"
    var startingXICardIDs: [String?] = Array(repeating: nil, count: 11)
    var benchCardIDs: [String?] = Array(repeating: nil, count: LegendsStore.benchSize)
    var captainCardID: String? = nil
    /// Wins accumulated at the current division (Phase 7) — resets on
    /// promotion. See `LegendsStore.winsToPromote`.
    var divisionWins: Int = 0
    /// Persistent division ledger used by the Legends table and home podium.
    var divisionTable: [LegendsDivisionRecord] = []
    /// Full home-and-away schedule for the current Legends division season.
    var divisionSchedule: [LegendsFixture] = []
    /// Competition season is separate from the legacy ten-match aging cycle.
    var divisionSeason: Int = 1
    var lastDivisionSeasonResult: LegendsDivisionSeasonResult? = nil
    /// Challenges (Phase 8). Permanent stats plus daily/weekly windows
    /// that reset on a calendar boundary — see
    /// `LegendsStore.refreshChallengeCadences()`.
    var totalWins: Int = 0
    var currentWinStreak: Int = 0
    var matchesToday: Int = 0
    var winsToday: Int = 0
    var winsThisWeek: Int = 0
    var goalsThisWeek: Int = 0
    var lastDailyReset: Date = .distantPast
    var lastWeeklyReset: Date = .distantPast
    var completedPermanentChallengeIDs: Set<String> = []
    var completedDailyChallengeIDs: Set<String> = []
    var completedWeeklyChallengeIDs: Set<String> = []
    /// Managers & Stadiums (Phase 9). Only one of each can be active at
    /// a time — a manager/stadium not in the owned set can't be set active.
    var ownedManagerIDs: Set<String> = []
    var activeManagerID: String? = nil
    var ownedStadiumIDs: Set<String> = []
    var activeStadiumID: String? = nil
    /// Seasonal aging (see LegendsStore+Aging.swift). A "season" is
    /// `LegendsStore.matchesPerSeason` matches, not a calendar period —
    /// Legends has no fixture list to hang a real calendar off of.
    var currentSeason: Int = 1
    var matchesPlayedThisSeason: Int = 0
    /// Years aged on top of a card's own printed `age`, keyed by card ID
    /// — only present once a card has actually aged past its base age.
    var cardAgeOffsets: [String: Int] = [:]
    /// Chosen pre-match on the Squad screen, seeds each live match's
    /// starting mentality — reuses Career Mode's own `Mentality` type
    /// (Models.swift), which has zero GameStore coupling.
    var preferredMentality: Mentality = .balanced
    /// The free Starter Pack (LegendsPacks.swift, id "starter") can only
    /// ever be opened once per club — its cost is 0, so without this flag
    /// it would otherwise be an infinitely-repeatable free pack.
    var pendingPackID: String? = nil
    var pendingPackCardIDs: [String] = []
    var hasClaimedStarterPack: Bool = false
    /// The user's persistent manager identity. Nil means this Legends save
    /// still needs the one-time manager creation flow.
    var managerProfile: LegendsManagerProfile? = nil
    /// One record per owned career instance. The legacy ID sets remain
    /// decoded for compatibility and are reconciled into this registry.
    var ownedPlayerRecords: [String: LegendsOwnedPlayerRecord] = [:]
    /// Unsigned-library capacity. Existing saves retain every card even if
    /// they exceed this value; the bonus is reserved for future progression.
    var libraryCapacityBonus: Int = 0
    var favouriteCardIDs: Set<String> = []
    var seasonReports: [Int: LegendsSeasonDevelopmentReport] = [:]

    static func starter() -> LegendsProfile {
        let squad = starterSquad()
        var profile = LegendsProfile(clubName: "RSM Legends FC", crestShort: "RSM",
                                      crestColorRGB: [0.10, 0.76, 0.35],
                                      managerLevel: 1, managerXP: 0,
                                      coins: 500, packTokens: 3,
                                      division: .division10, teamRating: 0,
                                      ownedCardIDs: squad.owned,
                                      activatedCardIDs: squad.owned,
                                      startingXICardIDs: squad.xi,
                                      benchCardIDs: squad.bench,
                                      divisionTable: LegendsDivisionTable.seed(userClub: "RSM Legends FC"))
        let clubIDs = profile.divisionTable.map(\.id)
        profile.divisionSchedule = LegendsDivisionTable.schedule(clubIDs: clubIDs, season: profile.divisionSeason)
        return profile
    }

    /// Picks one low-rated (Common/Rare/Elite) card per real player so a
    /// brand-new club fields a full, legal — but genuinely bad — Starting
    /// XI and bench from minute one, instead of an empty squad that's
    /// unplayable until packs are opened. Reuses the same name-dedup rule
    /// as `LegendsStore+Squad.swift` (one card per person) and derives the
    /// default "4-4-2" slot geometry the same way that file's
    /// `startingXISlots` does — evaluated directly here since a brand-new
    /// profile has no `LegendsStore` instance yet to ask.
    private static func starterSquad() -> (owned: Set<String>, xi: [String?], bench: [String?]) {
        let formation = Formation.all.first { $0.name == "4-4-2" } ?? Formation.all[0]
        var slots: [DetailedPosition] = [.goalkeeper]
        for i in 0..<formation.defenders {
            slots.append(.expected(for: .defender, indexInRow: i, rowCount: formation.defenders))
        }
        for i in 0..<formation.midfielders {
            slots.append(.expected(for: .midfielder, indexInRow: i, rowCount: formation.midfielders, wideIsWinger: formation.wideMidfieldersAreWingers))
        }
        for i in 0..<formation.forwards {
            slots.append(.expected(for: .forward, indexInRow: i, rowCount: formation.forwards))
        }

        // Common/Rare/Elite only (tier <= 2, the same cutoff the Bronze
        // Pack's own pool already uses) — sorted weakest-first so both the
        // exact-slot picks and the "whatever's left" fallback stay bad.
        var seenNames = Set<String>()
        var pool = LegendsCardDatabase.all
            .filter { $0.rarity.tier <= 2 }
            .sorted { $0.overall < $1.overall }
            .filter { seenNames.insert($0.name).inserted }

        func take(where predicate: (LegendsCard) -> Bool) -> LegendsCard? {
            guard let index = pool.firstIndex(where: predicate) else { return nil }
            return pool.remove(at: index)
        }

        let xi: [String?] = slots.map { slot in
            let card = take { $0.position == slot }
                ?? take { $0.position.broad == slot.broad }
                ?? (pool.isEmpty ? nil : pool.removeFirst())
            return card?.id
        }

        let bench: [String?] = (0..<LegendsStore.benchSize).map { _ in
            pool.isEmpty ? nil : pool.removeFirst().id
        }

        let owned = Set((xi + bench).compactMap { $0 })
        return (owned, xi, bench)
    }

    // A custom, lenient decode — matching SaveState/LegacyCareer's own
    // pattern — so a field added in a later phase never breaks loading
    // an existing Legends save.
    enum CodingKeys: String, CodingKey {
        case clubName, crestShort, crestColorRGB, managerLevel, managerXP
        case coins, packTokens, division, teamRating, ownedCardIDs, activatedCardIDs
        case playerCareers, legendsHall, clubRecords, lastSeasonReview
        case duplicateProgress, cardUpgrades
        case formationName, startingXICardIDs, benchCardIDs, captainCardID
        case divisionWins, divisionTable, divisionSchedule, divisionSeason, lastDivisionSeasonResult
        case totalWins, currentWinStreak, matchesToday, winsToday, winsThisWeek, goalsThisWeek
        case lastDailyReset, lastWeeklyReset
        case completedPermanentChallengeIDs, completedDailyChallengeIDs, completedWeeklyChallengeIDs
        case ownedManagerIDs, activeManagerID, ownedStadiumIDs, activeStadiumID
        case currentSeason, matchesPlayedThisSeason, cardAgeOffsets
        case preferredMentality
        case pendingPackID, pendingPackCardIDs, hasClaimedStarterPack, managerProfile, ownedPlayerRecords
        case libraryCapacityBonus, favouriteCardIDs, seasonReports
    }

    init(clubName: String, crestShort: String, crestColorRGB: [Double],
         managerLevel: Int, managerXP: Int, coins: Int, packTokens: Int,
         division: LegendsDivision, teamRating: Int, ownedCardIDs: Set<String> = [],
         activatedCardIDs: Set<String> = [], playerCareers: [String: LegendsPlayerCareer] = [:],
         legendsHall: [LegendsHallEntry] = [], clubRecords: [LegendsClubRecordKind: LegendsClubRecordEntry] = [:],
         lastSeasonReview: [String: LegendsSeasonReviewEntry] = [:],
         duplicateProgress: [String: Int] = [:], cardUpgrades: [String: Int] = [:],
         formationName: String = "4-4-2", startingXICardIDs: [String?] = Array(repeating: nil, count: 11),
         benchCardIDs: [String?] = Array(repeating: nil, count: LegendsStore.benchSize),
         captainCardID: String? = nil, divisionWins: Int = 0,
         divisionTable: [LegendsDivisionRecord] = [], divisionSchedule: [LegendsFixture] = [], divisionSeason: Int = 1,
         lastDivisionSeasonResult: LegendsDivisionSeasonResult? = nil,
         totalWins: Int = 0, currentWinStreak: Int = 0, matchesToday: Int = 0, winsToday: Int = 0,
         winsThisWeek: Int = 0, goalsThisWeek: Int = 0,
         lastDailyReset: Date = .distantPast, lastWeeklyReset: Date = .distantPast,
         completedPermanentChallengeIDs: Set<String> = [], completedDailyChallengeIDs: Set<String> = [],
         completedWeeklyChallengeIDs: Set<String> = [],
         ownedManagerIDs: Set<String> = [], activeManagerID: String? = nil,
         ownedStadiumIDs: Set<String> = [], activeStadiumID: String? = nil,
         currentSeason: Int = 1, matchesPlayedThisSeason: Int = 0, cardAgeOffsets: [String: Int] = [:],
         preferredMentality: Mentality = .balanced, pendingPackID: String? = nil,
         pendingPackCardIDs: [String] = [], hasClaimedStarterPack: Bool = false,
         managerProfile: LegendsManagerProfile? = nil,
         ownedPlayerRecords: [String: LegendsOwnedPlayerRecord] = [:], libraryCapacityBonus: Int = 0,
         favouriteCardIDs: Set<String> = [], seasonReports: [Int: LegendsSeasonDevelopmentReport] = [:]) {
        self.clubName = clubName
        self.crestShort = crestShort
        self.crestColorRGB = crestColorRGB
        self.managerLevel = managerLevel
        self.managerXP = managerXP
        self.coins = coins
        self.packTokens = packTokens
        self.division = division
        self.teamRating = teamRating
        self.ownedCardIDs = ownedCardIDs
        self.activatedCardIDs = activatedCardIDs
        self.playerCareers = playerCareers
        self.legendsHall = legendsHall
        self.clubRecords = clubRecords
        self.lastSeasonReview = lastSeasonReview
        self.duplicateProgress = duplicateProgress
        self.cardUpgrades = cardUpgrades
        self.formationName = formationName
        self.startingXICardIDs = startingXICardIDs
        self.benchCardIDs = benchCardIDs
        self.captainCardID = captainCardID
        self.divisionWins = divisionWins
        self.divisionTable = divisionTable
        self.divisionSchedule = divisionSchedule
        self.divisionSeason = divisionSeason
        self.lastDivisionSeasonResult = lastDivisionSeasonResult
        self.totalWins = totalWins
        self.currentWinStreak = currentWinStreak
        self.matchesToday = matchesToday
        self.winsToday = winsToday
        self.winsThisWeek = winsThisWeek
        self.goalsThisWeek = goalsThisWeek
        self.lastDailyReset = lastDailyReset
        self.lastWeeklyReset = lastWeeklyReset
        self.completedPermanentChallengeIDs = completedPermanentChallengeIDs
        self.completedDailyChallengeIDs = completedDailyChallengeIDs
        self.completedWeeklyChallengeIDs = completedWeeklyChallengeIDs
        self.ownedManagerIDs = ownedManagerIDs
        self.activeManagerID = activeManagerID
        self.ownedStadiumIDs = ownedStadiumIDs
        self.activeStadiumID = activeStadiumID
        self.currentSeason = currentSeason
        self.matchesPlayedThisSeason = matchesPlayedThisSeason
        self.cardAgeOffsets = cardAgeOffsets
        self.preferredMentality = preferredMentality
        self.pendingPackID = pendingPackID
        self.pendingPackCardIDs = pendingPackCardIDs
        self.hasClaimedStarterPack = hasClaimedStarterPack
        self.managerProfile = managerProfile
        self.ownedPlayerRecords = ownedPlayerRecords
        self.libraryCapacityBonus = libraryCapacityBonus
        self.favouriteCardIDs = favouriteCardIDs
        self.seasonReports = seasonReports
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clubName = try c.decodeIfPresent(String.self, forKey: .clubName) ?? "RSM Legends FC"
        crestShort = try c.decodeIfPresent(String.self, forKey: .crestShort) ?? "RSM"
        crestColorRGB = try c.decodeIfPresent([Double].self, forKey: .crestColorRGB) ?? [0.10, 0.76, 0.35]
        managerLevel = try c.decodeIfPresent(Int.self, forKey: .managerLevel) ?? 1
        managerXP = try c.decodeIfPresent(Int.self, forKey: .managerXP) ?? 0
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        packTokens = try c.decodeIfPresent(Int.self, forKey: .packTokens) ?? 0
        division = try c.decodeIfPresent(LegendsDivision.self, forKey: .division) ?? .division10
        teamRating = try c.decodeIfPresent(Int.self, forKey: .teamRating) ?? 0
        ownedCardIDs = try c.decodeIfPresent(Set<String>.self, forKey: .ownedCardIDs) ?? []
        startingXICardIDs = try c.decodeIfPresent([String?].self, forKey: .startingXICardIDs) ?? Array(repeating: nil, count: 11)
        benchCardIDs = try c.decodeIfPresent([String?].self, forKey: .benchCardIDs) ?? Array(repeating: nil, count: LegendsStore.benchSize)
        activatedCardIDs = try c.decodeIfPresent(Set<String>.self, forKey: .activatedCardIDs)
            ?? Set((startingXICardIDs + benchCardIDs).compactMap { $0 })
        playerCareers = try c.decodeIfPresent([String: LegendsPlayerCareer].self, forKey: .playerCareers) ?? [:]
        legendsHall = try c.decodeIfPresent([LegendsHallEntry].self, forKey: .legendsHall) ?? []
        clubRecords = try c.decodeIfPresent([LegendsClubRecordKind: LegendsClubRecordEntry].self, forKey: .clubRecords) ?? [:]
        lastSeasonReview = try c.decodeIfPresent([String: LegendsSeasonReviewEntry].self, forKey: .lastSeasonReview) ?? [:]
        duplicateProgress = try c.decodeIfPresent([String: Int].self, forKey: .duplicateProgress) ?? [:]
        cardUpgrades = try c.decodeIfPresent([String: Int].self, forKey: .cardUpgrades) ?? [:]
        formationName = try c.decodeIfPresent(String.self, forKey: .formationName) ?? "4-4-2"
        captainCardID = try c.decodeIfPresent(String.self, forKey: .captainCardID)
        divisionWins = try c.decodeIfPresent(Int.self, forKey: .divisionWins) ?? 0
        divisionTable = try c.decodeIfPresent([LegendsDivisionRecord].self, forKey: .divisionTable) ?? []
        divisionSchedule = try c.decodeIfPresent([LegendsFixture].self, forKey: .divisionSchedule) ?? []
        divisionSeason = try c.decodeIfPresent(Int.self, forKey: .divisionSeason) ?? 1
        lastDivisionSeasonResult = try c.decodeIfPresent(LegendsDivisionSeasonResult.self, forKey: .lastDivisionSeasonResult)
        totalWins = try c.decodeIfPresent(Int.self, forKey: .totalWins) ?? 0
        currentWinStreak = try c.decodeIfPresent(Int.self, forKey: .currentWinStreak) ?? 0
        matchesToday = try c.decodeIfPresent(Int.self, forKey: .matchesToday) ?? 0
        winsToday = try c.decodeIfPresent(Int.self, forKey: .winsToday) ?? 0
        winsThisWeek = try c.decodeIfPresent(Int.self, forKey: .winsThisWeek) ?? 0
        goalsThisWeek = try c.decodeIfPresent(Int.self, forKey: .goalsThisWeek) ?? 0
        lastDailyReset = try c.decodeIfPresent(Date.self, forKey: .lastDailyReset) ?? .distantPast
        lastWeeklyReset = try c.decodeIfPresent(Date.self, forKey: .lastWeeklyReset) ?? .distantPast
        completedPermanentChallengeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .completedPermanentChallengeIDs) ?? []
        completedDailyChallengeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .completedDailyChallengeIDs) ?? []
        completedWeeklyChallengeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .completedWeeklyChallengeIDs) ?? []
        ownedManagerIDs = try c.decodeIfPresent(Set<String>.self, forKey: .ownedManagerIDs) ?? []
        activeManagerID = try c.decodeIfPresent(String.self, forKey: .activeManagerID)
        ownedStadiumIDs = try c.decodeIfPresent(Set<String>.self, forKey: .ownedStadiumIDs) ?? []
        activeStadiumID = try c.decodeIfPresent(String.self, forKey: .activeStadiumID)
        currentSeason = try c.decodeIfPresent(Int.self, forKey: .currentSeason) ?? 1
        matchesPlayedThisSeason = try c.decodeIfPresent(Int.self, forKey: .matchesPlayedThisSeason) ?? 0
        cardAgeOffsets = try c.decodeIfPresent([String: Int].self, forKey: .cardAgeOffsets) ?? [:]
        preferredMentality = try c.decodeIfPresent(Mentality.self, forKey: .preferredMentality) ?? .balanced
        pendingPackID = try c.decodeIfPresent(String.self, forKey: .pendingPackID)
        pendingPackCardIDs = try c.decodeIfPresent([String].self, forKey: .pendingPackCardIDs) ?? []
        hasClaimedStarterPack = try c.decodeIfPresent(Bool.self, forKey: .hasClaimedStarterPack) ?? false
        managerProfile = try c.decodeIfPresent(LegendsManagerProfile.self, forKey: .managerProfile)
        ownedPlayerRecords = try c.decodeIfPresent([String: LegendsOwnedPlayerRecord].self, forKey: .ownedPlayerRecords) ?? [:]
        libraryCapacityBonus = max(0, try c.decodeIfPresent(Int.self, forKey: .libraryCapacityBonus) ?? 0)
        favouriteCardIDs = try c.decodeIfPresent(Set<String>.self, forKey: .favouriteCardIDs) ?? []
        seasonReports = try c.decodeIfPresent([Int: LegendsSeasonDevelopmentReport].self, forKey: .seasonReports) ?? [:]
    }
}

@MainActor
@Observable
final class LegendsStore {
    // Plain `var`, not `private(set)` — matching GameStore's own
    // convention, since `private(set)` is file-scoped in Swift and the
    // pack-opening logic in LegendsStore+Packs.swift needs to mutate
    // this from another file.
    var profile: LegendsProfile

    /// 3 duplicates = +1 OVR, capped at 3 upgrade levels per card (+3 OVR)
    /// — keeps the doc's "maximum rating capped to maintain realism" rule.
    static let maxCardUpgrade = 3
    static let duplicatesPerUpgrade = 3
    /// Starting XI (11) + Bench = 18, matching Career Mode's own squad size.
    // `nonisolated` so it can be referenced from LegendsProfile's init
    // default-parameter expressions, which evaluate outside MainActor
    // isolation — safe, it's just a compile-time constant.
    nonisolated static let benchSize = 7
    /// Wins needed at a division before promotion (legacy ad-hoc match path).
    static let winsToPromote = 6
    static func nextDivision(after division: LegendsDivision) -> LegendsDivision {
        LegendsDivision(rawValue: max(LegendsDivision.worldLeague.rawValue,
                                       min(LegendsDivision.division10.rawValue, division.rawValue - 1))) ?? .worldLeague
    }

    static func previousDivision(after division: LegendsDivision) -> LegendsDivision {
        LegendsDivision(rawValue: max(LegendsDivision.worldLeague.rawValue,
                                       min(LegendsDivision.division10.rawValue, division.rawValue + 1))) ?? .division10
    }

    static func seasonReward(for outcome: LegendsDivisionSeasonOutcome) -> LegendsSeasonReward {
        switch outcome {
        case .champion: return LegendsSeasonReward(coins: 300, tokens: 3, managerXP: 100)
        case .promoted: return LegendsSeasonReward(coins: 220, tokens: 2, managerXP: 80)
        case .retained: return LegendsSeasonReward(coins: 100, tokens: 1, managerXP: 40)
        case .relegated: return LegendsSeasonReward(coins: 50, tokens: 0, managerXP: 20)
        }
    }

    static func seasonOutcome(finalRank: Int, totalTeams: Int, division: LegendsDivision) -> (outcome: LegendsDivisionSeasonOutcome, newDivision: LegendsDivision) {
        if finalRank == 1 && division != .worldLeague {
            return (.champion, nextDivision(after: division))
        }
        if finalRank <= 2 && division != .worldLeague {
            return (.promoted, nextDivision(after: division))
        }
        if finalRank > totalTeams - 2 && division != .division10 {
            return (.relegated, previousDivision(after: division))
        }
        return (.retained, division)
    }
    /// How many Starting XI players must share a nation/era/club for the
    /// "core XI" challenges (Phase 8) — see LegendsStore+Challenges.swift.
    static let xiShareThreshold = 6
    /// A "season" for aging purposes (LegendsStore+Aging.swift) — this
    /// many Play Match results, not a calendar period.
    ///
    /// Kept equal to the division campaign length (a 14-match double
    /// round-robin of the 8 clubs) so aging, retirement and the season
    /// review all land at the same boundary as the division season.
    static let matchesPerSeason = 14

    init() {
        profile = Self.load() ?? .starter()
        // Older saves have activated IDs but no lifecycle records. Create
        // only those signed records; collection-only cards stay untouched.
        migrateLegacyCareerStates()
        migrateOwnedPlayerRecords()
    }

    /// The current table, with a seeded fallback for older saves.
    func divisionStandings() -> [LegendsDivisionRecord] {
        let table = profile.divisionTable.isEmpty
            ? LegendsDivisionTable.seed(userClub: profile.clubName)
            : profile.divisionTable
        return table.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
            return $0.name < $1.name
        }
    }

    func ensureDivisionTable() {
        if profile.divisionTable.isEmpty {
            profile.divisionTable = LegendsDivisionTable.seed(userClub: profile.clubName)
        } else if !profile.divisionTable.contains(where: { $0.id == profile.clubName }) {
            profile.divisionTable.append(LegendsDivisionRecord(id: profile.clubName, name: profile.clubName,
                                                               played: 0, won: 0, drawn: 0, lost: 0,
                                                               goalsFor: 0, goalsAgainst: 0))
        }
        ensureDivisionSchedule()
    }

    /// Migrates older saves that only had a standings ledger. The first
    /// access creates a fresh schedule without changing any saved results.
    func ensureDivisionSchedule() {
        ensureDivisionTableWithoutSchedule()
        if profile.divisionSchedule.isEmpty && isLegacySyntheticTable {
            profile.divisionTable = LegendsDivisionTable.seed(userClub: profile.clubName)
        }
        let clubIDs = profile.divisionTable.map(\.id)
        let expectedFixtureCount = max(0, clubIDs.count * (clubIDs.count - 1))
        if profile.divisionSchedule.count != expectedFixtureCount
            || profile.divisionSchedule.contains(where: { !clubIDs.contains($0.homeTeamID) || !clubIDs.contains($0.awayTeamID) }) {
            profile.divisionSchedule = LegendsDivisionTable.schedule(clubIDs: clubIDs, season: profile.divisionSeason)
        }
    }

    private var isLegacySyntheticTable: Bool {
        guard profile.divisionTable.count == 8 else { return false }
        return profile.divisionTable.allSatisfy { $0.played == 3 }
    }

    private func ensureDivisionTableWithoutSchedule() {
        if profile.divisionTable.isEmpty {
            profile.divisionTable = LegendsDivisionTable.seed(userClub: profile.clubName)
        } else if !profile.divisionTable.contains(where: { $0.id == profile.clubName }) {
            profile.divisionTable.append(LegendsDivisionRecord(id: profile.clubName, name: profile.clubName,
                                                               played: 0, won: 0, drawn: 0, lost: 0,
                                                               goalsFor: 0, goalsAgainst: 0))
        }
    }

    func recordDivisionMatch(teamGoals: Int, opponentGoals: Int, opponentName: String) {
        ensureDivisionTableWithoutSchedule()
        if let index = profile.divisionTable.firstIndex(where: { $0.id == profile.clubName }) {
            profile.divisionTable[index].played += 1
            profile.divisionTable[index].goalsFor += teamGoals
            profile.divisionTable[index].goalsAgainst += opponentGoals
            if teamGoals > opponentGoals { profile.divisionTable[index].won += 1 }
            else if teamGoals == opponentGoals { profile.divisionTable[index].drawn += 1 }
            else { profile.divisionTable[index].lost += 1 }
        }
        if let index = profile.divisionTable.firstIndex(where: { $0.name == opponentName }) {
            profile.divisionTable[index].played += 1
            profile.divisionTable[index].goalsFor += opponentGoals
            profile.divisionTable[index].goalsAgainst += teamGoals
            if opponentGoals > teamGoals { profile.divisionTable[index].won += 1 }
            else if opponentGoals == teamGoals { profile.divisionTable[index].drawn += 1 }
            else { profile.divisionTable[index].lost += 1 }
        }
    }

    func resetDivisionTable() {
        profile.divisionTable = LegendsDivisionTable.seed(userClub: profile.clubName)
        profile.divisionSchedule = LegendsDivisionTable.schedule(clubIDs: profile.divisionTable.map(\.id), season: profile.divisionSeason)
    }

    var nextDivisionFixture: LegendsFixture? {
        ensureDivisionSchedule()
        return profile.divisionSchedule.first { fixture in
            !fixture.isPlayed && (fixture.homeTeamID == profile.clubName || fixture.awayTeamID == profile.clubName)
        }
    }

    var divisionFixturesRemaining: Int {
        ensureDivisionSchedule()
        return profile.divisionSchedule.filter { !$0.isPlayed && ($0.homeTeamID == profile.clubName || $0.awayTeamID == profile.clubName) }.count
    }

    var divisionMatchesPlayed: Int {
        ensureDivisionSchedule()
        return profile.divisionSchedule.filter { $0.isPlayed && ($0.homeTeamID == profile.clubName || $0.awayTeamID == profile.clubName) }.count
    }

    var divisionMatchCount: Int {
        ensureDivisionSchedule()
        return profile.divisionSchedule.filter { $0.homeTeamID == profile.clubName || $0.awayTeamID == profile.clubName }.count
    }

    var divisionPressure: Double {
        guard let rank = divisionStandings().firstIndex(where: { $0.id == profile.clubName }) else { return 0 }
        let total = max(1, divisionStandings().count)
        let played = divisionMatchesPlayed
        let remaining = max(1, divisionMatchCount - played)
        let points = divisionStandings()[rank].points
        let leader = divisionStandings().first?.points ?? points
        let relegationCutoff = divisionStandings().dropFirst(max(0, total - 2)).first?.points ?? 0
        let promotionThreat = rank <= 2 ? 1.0 : Double(max(0, leader - points + remaining)) / Double(max(1, remaining * 3))
        let relegationThreat = rank >= total - 2 ? 1.0 : Double(max(0, relegationCutoff - points + remaining)) / Double(max(1, remaining * 3))
        return min(1, max(0, max(promotionThreat, relegationThreat)))
    }

    /// A card's overall including any duplicate-earned upgrade and any
    /// seasonal aging decline (LegendsStore+Aging.swift), capped at 99
    /// and floored at 1.
    func effectiveOverall(for card: LegendsCard) -> Int {
        let upgraded = card.overall + (profile.cardUpgrades[card.id] ?? 0) + developmentBonus(for: card) + formBoost(for: card)
        return min(99, max(1, upgraded - agingPenalty(for: card)))
    }

    /// Sets the mentality the next live match seeds from — chosen on the
    /// Squad screen, editable again mid-match on the live match screen.
    func setPreferredMentality(_ mentality: Mentality) {
        profile.preferredMentality = mentality
        persist()
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("legends_profile.json")
    }

    private static func load() -> LegendsProfile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LegendsProfile.self, from: data)
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: Self.fileURL)
    }

    /// Wipes the save file and resets in-memory state back to a fresh
    /// starter club — Legends has just one save slot, so "delete" is a
    /// full reset rather than removing one of several files.
    func deleteClub() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        profile = .starter()
        migrateLegacyCareerStates()
        migrateOwnedPlayerRecords()
        persist()
    }
}
