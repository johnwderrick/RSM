//
//  LegendsStore+Packs.swift
//  Retro Season Manager
//
//  Pack-opening logic (Phase 4). Split from LegendsStore.swift the same
//  way GameStore's own logic lives in GameStore+<Domain>.swift files —
//  the store itself only holds state.
//

import Foundation

struct LegendsPackPullResult: Identifiable {
    let card: LegendsCard
    let isNewCard: Bool
    /// True if this pull was the 3rd duplicate and just granted an
    /// upgrade point.
    let grantedUpgrade: Bool

    var id: String { card.id + (isNewCard ? "-new" : "-dup") }
}

enum LegendsPackError: Error {
    case insufficientFunds
    case emptyPool
}

extension LegendsStore {
    /// Spends the pack's cost, pulls `cardCount` cards from its pool
    /// (enforcing the guaranteed minimum rarity), applies duplicate/
    /// upgrade rules, persists, and returns the results in pull order
    /// for the reveal animation.
    @discardableResult
    func openPack(_ pack: LegendsPack) throws -> [LegendsPackPullResult] {
        switch pack.currency {
        case .coins:
            guard profile.coins >= pack.cost else { throw LegendsPackError.insufficientFunds }
        case .tokens:
            guard profile.packTokens >= pack.cost else { throw LegendsPackError.insufficientFunds }
        }

        let eligible = LegendsCardDatabase.all.filter(pack.pool)
        guard !eligible.isEmpty else { throw LegendsPackError.emptyPool }

        var pulls = (0..<pack.cardCount).compactMap { _ in Self.weightedPull(from: eligible) }

        let hasGuaranteedTier = pulls.contains { $0.rarity.tier >= pack.guaranteedMinTier }
        if !hasGuaranteedTier {
            let guaranteedPool = eligible.filter { $0.rarity.tier >= pack.guaranteedMinTier }
            if let boost = Self.weightedPull(from: guaranteedPool), let weakestIndex = pulls.indices.min(by: { pulls[$0].rarity.tier < pulls[$1].rarity.tier }) {
                pulls[weakestIndex] = boost
            }
        }

        switch pack.currency {
        case .coins: profile.coins -= pack.cost
        case .tokens: profile.packTokens -= pack.cost
        }

        let results = pulls.map { card -> LegendsPackPullResult in
            if profile.ownedCardIDs.contains(card.id) {
                let progress = (profile.duplicateProgress[card.id] ?? 0) + 1
                if progress >= Self.duplicatesPerUpgrade {
                    profile.duplicateProgress[card.id] = 0
                    let currentUpgrade = profile.cardUpgrades[card.id] ?? 0
                    let granted = currentUpgrade < Self.maxCardUpgrade
                    if granted { profile.cardUpgrades[card.id] = currentUpgrade + 1 }
                    return LegendsPackPullResult(card: card, isNewCard: false, grantedUpgrade: granted)
                } else {
                    profile.duplicateProgress[card.id] = progress
                    return LegendsPackPullResult(card: card, isNewCard: false, grantedUpgrade: false)
                }
            } else {
                profile.ownedCardIDs.insert(card.id)
                return LegendsPackPullResult(card: card, isNewCard: true, grantedUpgrade: false)
            }
        }

        persist()
        return results
    }

    /// Draws one card weighted by `LegendsRarity.pullWeight` rather than
    /// uniformly — the 40-card database itself already skews toward
    /// Hero-and-above, so a uniform draw would make top rarities come up
    /// far too often to feel special. Falls back to a uniform pick only
    /// if every candidate has zero weight (shouldn't happen with the
    /// current rarity table, but keeps this total).
    static func weightedPull(from cards: [LegendsCard]) -> LegendsCard? {
        let totalWeight = cards.reduce(0.0) { $0 + $1.rarity.pullWeight }
        guard totalWeight > 0 else { return cards.randomElement() }
        var roll = Double.random(in: 0..<totalWeight)
        for card in cards {
            roll -= card.rarity.pullWeight
            if roll < 0 { return card }
        }
        return cards.last
    }
}
