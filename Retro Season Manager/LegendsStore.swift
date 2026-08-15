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

    static func starter() -> LegendsProfile {
        LegendsProfile(clubName: "RSM Legends FC", crestShort: "RSM",
                        crestColorRGB: [0.10, 0.76, 0.35],
                        managerLevel: 1, managerXP: 0,
                        coins: 500, packTokens: 3,
                        division: .division10, teamRating: 0)
    }

    // A custom, lenient decode — matching SaveState/LegacyCareer's own
    // pattern — so a field added in a later phase never breaks loading
    // an existing Legends save.
    enum CodingKeys: String, CodingKey {
        case clubName, crestShort, crestColorRGB, managerLevel, managerXP
        case coins, packTokens, division, teamRating, ownedCardIDs
        case duplicateProgress, cardUpgrades
        case formationName, startingXICardIDs, benchCardIDs, captainCardID
        case divisionWins
        case totalWins, currentWinStreak, matchesToday, winsToday, winsThisWeek, goalsThisWeek
        case lastDailyReset, lastWeeklyReset
        case completedPermanentChallengeIDs, completedDailyChallengeIDs, completedWeeklyChallengeIDs
        case ownedManagerIDs, activeManagerID, ownedStadiumIDs, activeStadiumID
        case currentSeason, matchesPlayedThisSeason, cardAgeOffsets
        case preferredMentality
    }

    init(clubName: String, crestShort: String, crestColorRGB: [Double],
         managerLevel: Int, managerXP: Int, coins: Int, packTokens: Int,
         division: LegendsDivision, teamRating: Int, ownedCardIDs: Set<String> = [],
         duplicateProgress: [String: Int] = [:], cardUpgrades: [String: Int] = [:],
         formationName: String = "4-4-2", startingXICardIDs: [String?] = Array(repeating: nil, count: 11),
         benchCardIDs: [String?] = Array(repeating: nil, count: LegendsStore.benchSize),
         captainCardID: String? = nil, divisionWins: Int = 0,
         totalWins: Int = 0, currentWinStreak: Int = 0, matchesToday: Int = 0, winsToday: Int = 0,
         winsThisWeek: Int = 0, goalsThisWeek: Int = 0,
         lastDailyReset: Date = .distantPast, lastWeeklyReset: Date = .distantPast,
         completedPermanentChallengeIDs: Set<String> = [], completedDailyChallengeIDs: Set<String> = [],
         completedWeeklyChallengeIDs: Set<String> = [],
         ownedManagerIDs: Set<String> = [], activeManagerID: String? = nil,
         ownedStadiumIDs: Set<String> = [], activeStadiumID: String? = nil,
         currentSeason: Int = 1, matchesPlayedThisSeason: Int = 0, cardAgeOffsets: [String: Int] = [:],
         preferredMentality: Mentality = .balanced) {
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
        self.duplicateProgress = duplicateProgress
        self.cardUpgrades = cardUpgrades
        self.formationName = formationName
        self.startingXICardIDs = startingXICardIDs
        self.benchCardIDs = benchCardIDs
        self.captainCardID = captainCardID
        self.divisionWins = divisionWins
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
        duplicateProgress = try c.decodeIfPresent([String: Int].self, forKey: .duplicateProgress) ?? [:]
        cardUpgrades = try c.decodeIfPresent([String: Int].self, forKey: .cardUpgrades) ?? [:]
        formationName = try c.decodeIfPresent(String.self, forKey: .formationName) ?? "4-4-2"
        startingXICardIDs = try c.decodeIfPresent([String?].self, forKey: .startingXICardIDs) ?? Array(repeating: nil, count: 11)
        benchCardIDs = try c.decodeIfPresent([String?].self, forKey: .benchCardIDs) ?? Array(repeating: nil, count: LegendsStore.benchSize)
        captainCardID = try c.decodeIfPresent(String.self, forKey: .captainCardID)
        divisionWins = try c.decodeIfPresent(Int.self, forKey: .divisionWins) ?? 0
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
    /// Wins needed at a division before promotion (Phase 7).
    static let winsToPromote = 6
    /// How many Starting XI players must share a nation/era/club for the
    /// "core XI" challenges (Phase 8) — see LegendsStore+Challenges.swift.
    static let xiShareThreshold = 6
    /// A "season" for aging purposes (LegendsStore+Aging.swift) — this
    /// many Play Match results, not a calendar period.
    static let matchesPerSeason = 10

    init() {
        profile = Self.load() ?? .starter()
    }

    /// A card's overall including any duplicate-earned upgrade and any
    /// seasonal aging decline (LegendsStore+Aging.swift), capped at 99
    /// and floored at 1.
    func effectiveOverall(for card: LegendsCard) -> Int {
        let upgraded = card.overall + (profile.cardUpgrades[card.id] ?? 0)
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
}
