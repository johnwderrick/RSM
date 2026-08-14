//
//  LegendsStore+Chemistry.swift
//  Retro Season Manager
//
//  Chemistry (Phase 6) — bonuses from Same Club, Same Nation, Same
//  League, Same Era, Same Manager and Formation Fit. "Same Manager"
//  (Phase 9): a player from the active manager's affinity club gets a
//  link bonus, same weight as a Same Club teammate link. "Same League"
//  doesn't use real league names (same trademark reasoning as dropping
//  the real-league packs in Phase 4) — it's derived from which
//  fictional country each club belongs to, using the same club universe
//  Career Mode's historical squads already established.
//

import Foundation

private let clubCountries: [String: String] = [
    "Old Trafford Reds": "England", "Highbury": "England", "Elland Athletic": "England",
    "Valley Rovers": "England", "Etihad Blues": "England", "Stamford Blues": "England",
    "Bernabéu Whites": "Spain", "Camp Blaugrana": "Spain",
    "San Siro Nerazzurri": "Italy", "San Siro Rossoneri": "Italy", "Turin Bianconeri": "Italy",
    "Bavarian Reds": "Germany",
    "Amsterdam Godenzonen": "Netherlands",
    "Dragão Dragons": "Portugal",
]

extension LegendsCard {
    /// The fictional domestic league (named after its country, not a
    /// real competition brand) this card's club plays in.
    var league: String { clubCountries[club] ?? club }
}

extension LegendsStore {
    /// 0...3 chemistry stars for the card in a given Starting XI slot,
    /// weighing its links to every other filled XI slot and capping the
    /// result if it isn't being played anywhere near its natural
    /// position (Formation Fit).
    func chemistryStars(forXISlot index: Int) -> Int {
        guard let cardID = profile.startingXICardIDs[index],
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { return 0 }

        let teammates = profile.startingXICardIDs.indices
            .filter { $0 != index }
            .compactMap { profile.startingXICardIDs[$0] }
            .compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }

        var linkScore = 0
        for teammate in teammates {
            if teammate.club == card.club { linkScore += 3 }
            if teammate.league == card.league { linkScore += 2 }
            if teammate.nation == card.nation { linkScore += 1 }
            if teammate.era == card.era { linkScore += 1 }
        }
        if let manager = activeManager, manager.affinityClub == card.club { linkScore += 3 }

        let stars: Int
        switch linkScore {
        case 0: stars = 0
        case 1...4: stars = 1
        case 5...10: stars = 2
        default: stars = 3
        }

        let slot = startingXISlots[index]
        if slot == card.position { return stars }
        if slot.broad == card.position.broad { return min(stars, 2) }
        return 0
    }

    /// Sum of every filled Starting XI slot's chemistry, out of a
    /// maximum of 33 (11 players x 3 stars).
    var totalChemistry: Int {
        profile.startingXICardIDs.indices.reduce(0) { $0 + chemistryStars(forXISlot: $1) }
    }
}
