//
//  GameStore+Facilities.swift
//  Retro Season Manager
//
//  Club infrastructure the user can invest in over a career — training
//  ground, medical centre, scouting network, hospitality, museum and club
//  shop, on top of the existing youth academy/stadium. Same escalating-cost
//  upgrade pattern throughout, each with a real effect on development or
//  finances — the mechanism behind a small club slowly growing into a giant.
//

import Foundation

/// Every piece of investable club infrastructure, unified for a single
/// data-driven "Facilities" screen — stadium and youth academy reuse their
/// existing dedicated functions under the hood; the rest are new.
enum FacilityKind: String, CaseIterable, Identifiable {
    case trainingGround, youthAcademy, medicalCentre, scoutingNetwork, stadium, hospitality, museum, clubShop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trainingGround:  return "Training Ground"
        case .youthAcademy:    return "Youth Academy"
        case .medicalCentre:   return "Medical Centre"
        case .scoutingNetwork: return "Scouting Network"
        case .stadium:         return "Stadium"
        case .hospitality:     return "Hospitality"
        case .museum:          return "Museum"
        case .clubShop:        return "Club Shop"
        }
    }

    var icon: String {
        switch self {
        case .trainingGround:  return "figure.run"
        case .youthAcademy:    return "graduationcap.fill"
        case .medicalCentre:   return "cross.case.fill"
        case .scoutingNetwork: return "binoculars.fill"
        case .stadium:         return "sportscourt.fill"
        case .hospitality:     return "wineglass.fill"
        case .museum:          return "building.columns.fill"
        case .clubShop:        return "bag.fill"
        }
    }

    func level(in club: Club) -> Int {
        switch self {
        case .trainingGround:  return club.trainingGroundLevel
        case .youthAcademy:    return club.youthFacilityLevel
        case .medicalCentre:   return club.medicalCentreLevel
        case .scoutingNetwork: return club.scoutingNetworkLevel
        case .stadium:         return club.stadiumExpansionLevel
        case .hospitality:     return club.hospitalityLevel
        case .museum:          return club.museumLevel
        case .clubShop:        return club.clubShopLevel
        }
    }

    /// A short narrative ladder — "visual progression" in words, since a
    /// level number alone doesn't tell a story on its own.
    private static let tierLadders: [FacilityKind: [String]] = [
        .trainingGround:  ["Public park pitches", "Basic training pitches", "Modern training base", "Elite training complex", "World-class training campus", "Legendary training academy"],
        .youthAcademy:    ["A borrowed changing room", "Small academy setup", "Recognised academy", "Category-one academy", "Renowned youth academy", "World-famous talent factory"],
        .medicalCentre:   ["Corner office and ice bath", "Small medical room", "Modern medical suite", "Full sports science unit", "State-of-the-art medical centre", "World-leading medical facility"],
        .scoutingNetwork: ["One scout, a notebook", "Regional scouting", "National scouting network", "European scouting network", "Global scouting network", "World's finest scouting operation"],
        .stadium:         ["Modest home ground", "Improved terraces", "Modern stands", "Expanded bowl", "Major stadium", "Iconic arena"],
        .hospitality:     ["A tea hut", "Small hospitality suite", "Executive boxes", "Premium hospitality wing", "5-star matchday experience", "World-class hospitality empire"],
        .museum:          ["A trophy in reception", "Small heritage corner", "Club museum opens", "Expanded heritage centre", "Major club museum", "World-famous football museum"],
        .clubShop:        ["Folding table of scarves", "Small club shop", "High street store", "Flagship megastore", "Multi-floor megastore", "Global retail brand"],
    ]

    func tierLabel(_ level: Int) -> String {
        let ladder = Self.tierLadders[self] ?? []
        return ladder.indices.contains(level) ? ladder[level] : ladder.last ?? ""
    }

    /// The concrete mechanical payoff at this level.
    func effectBlurb(_ level: Int) -> String {
        switch self {
        case .trainingGround:  return "+\(level) extra development roll for young players each season."
        case .youthAcademy:    return "Better youth intake quality and quantity."
        case .medicalCentre:   return "-\(level * 2)% injury chance, -\(level * 3)% recovery time."
        case .scoutingNetwork: return "Faster scouting, sharper reports."
        case .stadium:         return "Bigger ground, more matchday revenue."
        case .hospitality:     return "+\(level * 5)% hospitality income on matchdays."
        case .museum:          return "+\(level) prestige and fan loyalty trickle each season."
        case .clubShop:        return "+\(level * 5)% commercial income each season."
        }
    }
}

extension GameStore {

    /// The cost of the next upgrade, or nil at max level (5) — for
    /// stadium/youth academy this defers to their own existing cost
    /// functions so there's exactly one source of truth for those.
    func facilityUpgradeCost(_ kind: FacilityKind, forClubIndex index: Int) -> Int? {
        switch kind {
        case .stadium:      return stadiumUpgradeCost(forClubIndex: index)
        case .youthAcademy: return youthUpgradeCost(forClubIndex: index)
        default:
            let base: Int
            switch kind {
            case .trainingGround:  base = 700
            case .medicalCentre:   base = 800
            case .scoutingNetwork: base = 850
            case .hospitality:     base = 1000
            case .museum:          base = 600
            case .clubShop:        base = 750
            case .stadium, .youthAcademy: return nil // handled above
            }
            let level = kind.level(in: clubs[index])
            guard level < 5 else { return nil }
            return base * (level + 1) * (level + 1)
        }
    }

    /// Spends transfer budget to upgrade one facility by a level, for the
    /// user's own club. Stadium/youth academy defer to their existing
    /// dedicated investment functions; everything else follows the same
    /// shape inline.
    @discardableResult
    func investInFacility(_ kind: FacilityKind) -> String {
        switch kind {
        case .stadium:      return investInStadium()
        case .youthAcademy: return investInYouthAcademy()
        default: break
        }
        guard let cost = facilityUpgradeCost(kind, forClubIndex: userClubIndex) else {
            return "\(kind.displayName) is already at its maximum level."
        }
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget for this upgrade (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        switch kind {
        case .trainingGround:  clubs[userClubIndex].trainingGroundLevel += 1
        case .medicalCentre:   clubs[userClubIndex].medicalCentreLevel += 1
        case .scoutingNetwork: clubs[userClubIndex].scoutingNetworkLevel += 1
        case .hospitality:     clubs[userClubIndex].hospitalityLevel += 1
        case .museum:          clubs[userClubIndex].museumLevel += 1
        case .clubShop:        clubs[userClubIndex].clubShopLevel += 1
        case .stadium, .youthAcademy: break
        }
        let newLevel = kind.level(in: userClub)
        addNews(.board, "\(kind.displayName) upgraded",
                "\(userClub.name) invest in the \(kind.displayName.lowercased()) — now \(kind.tierLabel(newLevel).lowercased()).")
        logLedger("Investment", amount: -cost, "\(kind.displayName) upgrade")
        persist()
        return "\(kind.displayName) upgraded to level \(newLevel)."
    }
}
