//
//  GameStore+ClubIdentity.swift
//  Retro Season Manager
//
//  A club's own hidden character — independent of whoever currently
//  manages it. Unlike `ManagerPersonality` (re-rolled every time a club
//  changes manager, see `checkRivalManagerSackings()`), a `ClubIdentity`
//  is assigned once at `newGame()` and never touched again, the same
//  lifecycle `clubNegotiationStances` already has. Never shown to the
//  player as a raw label — its effects are felt through existing
//  transfer/youth/facility/news/sacking behaviour (see the hooks in
//  `GameStore+Transfers.swift`, `GameStore+SquadManagement.swift`,
//  `GameStore+WorldSimulation.swift`, `GameStore+Calendar.swift`,
//  `GameStore+ContractsAndBoard.swift`, `GameStore+SupporterSystem.swift`,
//  `GameStore+Competitions.swift`), plus one short in-world flavour line
//  in the pre-match opponent panel.
//

import Foundation

enum ClubIdentity: String, Codable, CaseIterable {
    case youthFactory = "Youth Factory"
    case sellingClub = "Selling Club"
    case sleepingGiant = "Sleeping Giant"
    case financialPowerhouse = "Financial Powerhouse"
    case underdog = "Underdog"
    case historicGiant = "Historic Giant"
    case communityClub = "Community Club"
    case crisisClub = "Crisis Club"
    case cupSpecialist = "Cup Specialist"
    case talentHoarder = "Talent Hoarder"

    /// A short, in-world sentence — never the raw case name — for the one
    /// place this is allowed to surface to the player at all.
    var flavorText: String {
        switch self {
        case .youthFactory:          return "Renowned for producing their own talent."
        case .sellingClub:           return "Frequently cashes in on its best players."
        case .sleepingGiant:         return "A famous old name yet to rediscover its best."
        case .financialPowerhouse:   return "Backed by serious financial muscle."
        case .underdog:              return "Punches above its weight with limited resources."
        case .historicGiant:         return "Steeped in history and used to winning."
        case .communityClub:         return "Proudly rooted in its local community."
        case .crisisClub:            return "A club in some financial disarray."
        case .cupSpecialist:         return "Has a knack for raising its game in cup competition."
        case .talentHoarder:         return "Reluctant to let its prized assets leave."
        }
    }

    /// Hand-authored overrides for clubs with an existing real-world
    /// analogue elsewhere in the codebase (`OwnershipChanges.swift`,
    /// `GameStore+Setup.swift`'s `clubColors`) — the same two-tier
    /// "bulk-generated + per-name override" pattern `tierPools`/`clubColors`
    /// already use everywhere else.
    static let knownIdentities: [String: ClubIdentity] = [
        "Stamford Blues": .financialPowerhouse,
        "Etihad Blues": .financialPowerhouse,
        "Old Trafford Reds": .historicGiant,
        "Mersey Reds": .historicGiant,
        "Highbury": .historicGiant,
        "Goodison Blues": .communityClub,
        "Tyneside": .sleepingGiant,
        "Elland Athletic": .sleepingGiant,
        "Aston Rovers": .cupSpecialist,
    ]
}

extension GameStore {

    /// A club's hidden, permanent identity — see `ClubIdentity`.
    func clubIdentity(forClubIndex index: Int) -> ClubIdentity? {
        clubIdentities.indices.contains(index) ? clubIdentities[index] : nil
    }

    /// Assigns every club a `ClubIdentity` — a hand-authored override for
    /// clubs with a real-world analogue elsewhere in the codebase, a
    /// prestige/division-weighted random pick for everyone else. Called
    /// once from `newGame()`; never re-rolled afterward.
    func assignClubIdentities() {
        clubIdentities = clubs.map { club in
            ClubIdentity.knownIdentities[club.name] ?? Self.deriveClubIdentity(prestige: club.prestige, tier: club.divisionTier)
        }
    }

    /// Weights plausible identities by a club's prestige/division band —
    /// a big, prestigious top-flight club is more likely to land as a
    /// Historic Giant/Financial Powerhouse/Sleeping Giant than a small
    /// lower-league one, and vice versa for Underdog/Community
    /// Club/Selling Club — without needing any hand-authored data for the
    /// ~180 clubs the override table doesn't cover.
    static func deriveClubIdentity(prestige: Int, tier: Int) -> ClubIdentity {
        var weights: [ClubIdentity: Double] = Dictionary(uniqueKeysWithValues: ClubIdentity.allCases.map { ($0, 1.0) })
        if tier == 0 && prestige >= 75 {
            weights[.historicGiant, default: 1] += 2
            weights[.financialPowerhouse, default: 1] += 1.5
            weights[.sleepingGiant, default: 1] += 1
            weights[.talentHoarder, default: 1] += 1
        }
        if prestige < 55 {
            weights[.underdog, default: 1] += 2.5
            weights[.communityClub, default: 1] += 1.5
            weights[.sellingClub, default: 1] += 1.5
        }
        if tier >= 2 {
            weights[.crisisClub, default: 1] += 1
            weights[.youthFactory, default: 1] += 1
            weights[.sellingClub, default: 1] += 0.5
        }
        if tier == 3 {
            weights[.communityClub, default: 1] += 1
        }
        let ordered = ClubIdentity.allCases
        let total = ordered.reduce(0.0) { $0 + (weights[$1] ?? 1) }
        var roll = Double.random(in: 0..<total)
        for identity in ordered {
            let w = weights[identity] ?? 1
            if roll < w { return identity }
            roll -= w
        }
        return ordered.last!
    }
}
