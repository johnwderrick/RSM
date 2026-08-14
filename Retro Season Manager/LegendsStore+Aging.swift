//
//  LegendsStore+Aging.swift
//  Retro Season Manager
//
//  Seasonal aging: every card ages 1 year per Legends "season"
//  (LegendsStore.matchesPerSeason match results, not a calendar period
//  — Legends has no fixture list to hang a real one off of). Past a
//  peak age, overall declines; past a retirement age, the card can no
//  longer be fielded at all, forcing an actual replacement rather than
//  just a stat dip. "Legends" and "Icons" era cards are exempt — they're
//  timeless tribute cards (the doc's own framing), not a specific
//  season's real-time-aging squad player, matching how genre convention
//  treats Icon-tier cards as fixed rather than versioned by age.
//

import Foundation

struct LegendsSeasonAdvanceResult {
    let newSeason: Int
    let retiredCards: [LegendsCard]
}

extension LegendsStore {
    static let agingExemptEras: Set<LegendsEra> = [.legends, .icons]
    /// No decline at or under this age.
    static let declineStartAge = 30
    static let declinePerYearOverPeak = 1
    /// A card can't be fielded once it reaches this age — the actual
    /// "you must replace this player" trigger, independent of how much
    /// `agingPenalty` alone has knocked off its rating.
    static let retirementAge = 36

    /// A card's age including every season it's aged since first owned.
    func effectiveAge(for card: LegendsCard) -> Int {
        card.age + (profile.cardAgeOffsets[card.id] ?? 0)
    }

    /// OVR lost to age alone (before the duplicate-upgrade cap in
    /// `effectiveOverall(for:)` is applied) — 0 for exempt eras.
    func agingPenalty(for card: LegendsCard) -> Int {
        guard !Self.agingExemptEras.contains(card.era) else { return 0 }
        let age = effectiveAge(for: card)
        return max(0, (age - Self.declineStartAge) * Self.declinePerYearOverPeak)
    }

    func isRetired(_ card: LegendsCard) -> Bool {
        guard !Self.agingExemptEras.contains(card.era) else { return false }
        return effectiveAge(for: card) >= Self.retirementAge
    }

    /// Call once per completed match (see LegendsStore+Match.swift). Only
    /// actually ages the collection and returns a non-nil result once
    /// `matchesPerSeason` results have accumulated.
    @discardableResult
    func advanceSeasonIfNeeded() -> LegendsSeasonAdvanceResult? {
        profile.matchesPlayedThisSeason += 1
        guard profile.matchesPlayedThisSeason >= Self.matchesPerSeason else {
            persist()
            return nil
        }
        profile.matchesPlayedThisSeason = 0
        profile.currentSeason += 1

        for id in profile.ownedCardIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }),
                  !Self.agingExemptEras.contains(card.era) else { continue }
            profile.cardAgeOffsets[id, default: 0] += 1
        }

        var retiredCards: [LegendsCard] = []
        for index in profile.startingXICardIDs.indices {
            guard let id = profile.startingXICardIDs[index],
                  let card = LegendsCardDatabase.all.first(where: { $0.id == id }), isRetired(card) else { continue }
            profile.startingXICardIDs[index] = nil
            if profile.captainCardID == id { profile.captainCardID = nil }
            retiredCards.append(card)
        }
        for index in profile.benchCardIDs.indices {
            guard let id = profile.benchCardIDs[index],
                  let card = LegendsCardDatabase.all.first(where: { $0.id == id }), isRetired(card) else { continue }
            profile.benchCardIDs[index] = nil
            retiredCards.append(card)
        }

        persist()
        return LegendsSeasonAdvanceResult(newSeason: profile.currentSeason, retiredCards: retiredCards)
    }
}
