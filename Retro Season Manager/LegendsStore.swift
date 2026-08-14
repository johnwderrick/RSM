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
    }

    init(clubName: String, crestShort: String, crestColorRGB: [Double],
         managerLevel: Int, managerXP: Int, coins: Int, packTokens: Int,
         division: LegendsDivision, teamRating: Int, ownedCardIDs: Set<String> = [],
         duplicateProgress: [String: Int] = [:], cardUpgrades: [String: Int] = [:]) {
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

    init() {
        profile = Self.load() ?? .starter()
    }

    /// A card's overall including any duplicate-earned upgrade, capped at 99.
    func effectiveOverall(for card: LegendsCard) -> Int {
        min(99, card.overall + (profile.cardUpgrades[card.id] ?? 0))
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
