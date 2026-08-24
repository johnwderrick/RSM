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

    var id: String { card.id + (isNewCard ? "-new" : "-dup") + "-\(card.season)" }
}

enum LegendsPackError: Error, Equatable {
    case insufficientFunds
    case emptyPool
    /// The free Starter Pack — cost 0, so `insufficientFunds` can never
    /// naturally gate a second open — has already been claimed this save.
    case alreadyClaimed
    case pendingSelection
    case invalidPendingSelection
}

extension LegendsStore {
    /// Reserves a pack and returns three previews without adding any card
    /// to the library. The player must later claim exactly one candidate.
    @discardableResult
    func preparePack(_ pack: LegendsPack) throws -> [LegendsPackPullResult] {
        if profile.pendingPackID != nil { throw LegendsPackError.pendingSelection }
        if pack.id == "starter" {
            guard !profile.hasClaimedStarterPack else { throw LegendsPackError.alreadyClaimed }
        }
        switch pack.currency {
        case .coins: guard profile.coins >= pack.cost else { throw LegendsPackError.insufficientFunds }
        case .tokens: guard profile.packTokens >= pack.cost else { throw LegendsPackError.insufficientFunds }
        }
        let eligible = LegendsCardDatabase.all.filter(pack.pool)
        guard !eligible.isEmpty else { throw LegendsPackError.emptyPool }
        var available = eligible
        var pulls: [LegendsCard] = []
        for _ in 0..<min(pack.cardCount, available.count) {
            guard let card = Self.weightedPull(from: available) else { break }
            pulls.append(card)
            available.removeAll { $0.id == card.id }
        }
        while pulls.count < pack.cardCount {
            guard let card = Self.weightedPull(from: eligible) else { break }
            pulls.append(card)
        }
        if !pulls.contains(where: { $0.rarity.tier >= pack.guaranteedMinTier }) {
            let guaranteedPool = eligible.filter { $0.rarity.tier >= pack.guaranteedMinTier }
            let unusedGuaranteedPool = guaranteedPool.filter { candidate in
                !pulls.contains(where: { $0.id == candidate.id })
            }
            let replacementPool = unusedGuaranteedPool.isEmpty ? guaranteedPool : unusedGuaranteedPool
            if let boost = Self.weightedPull(from: replacementPool), let weakest = pulls.indices.min(by: { pulls[$0].rarity.tier < pulls[$1].rarity.tier }) {
                pulls[weakest] = boost
            }
        }
        switch pack.currency {
        case .coins: profile.coins -= pack.cost
        case .tokens: profile.packTokens -= pack.cost
        }
        profile.pendingPackID = pack.id
        profile.pendingPackCardIDs = pulls.map(\.id)
        persist()
        return pulls.map { previewResult(for: $0) }
    }

    func pendingPackResults() -> [LegendsPackPullResult] {
        profile.pendingPackCardIDs.compactMap { id in
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }) else { return nil }
            return previewResult(for: card)
        }
    }

    @discardableResult
    func claimPreparedPack(at index: Int) throws -> LegendsPackPullResult {
        guard profile.pendingPackID != nil,
              profile.pendingPackCardIDs.indices.contains(index),
              let card = LegendsCardDatabase.all.first(where: { $0.id == profile.pendingPackCardIDs[index] }) else {
            throw LegendsPackError.invalidPendingSelection
        }
        let result: LegendsPackPullResult
        let packID = profile.pendingPackID ?? "PACK"
        if profile.ownedCardIDs.contains(card.id) {
            let progress = (profile.duplicateProgress[card.id] ?? 0) + 1
            if progress >= Self.duplicatesPerUpgrade {
                profile.duplicateProgress[card.id] = 0
                let current = profile.cardUpgrades[card.id] ?? 0
                let granted = current < Self.maxCardUpgrade
                if granted { profile.cardUpgrades[card.id] = current + 1 }
                result = LegendsPackPullResult(card: card, isNewCard: false, grantedUpgrade: granted)
            } else {
                profile.duplicateProgress[card.id] = progress
                result = LegendsPackPullResult(card: card, isNewCard: false, grantedUpgrade: false)
            }
        } else {
            profile.ownedCardIDs.insert(card.id)
            registerAcquisition(cardID: card.id, method: "PACK: \(packID)")
            result = LegendsPackPullResult(card: card, isNewCard: true, grantedUpgrade: false)
        }
        if profile.pendingPackID == "starter" { profile.hasClaimedStarterPack = true }
        profile.pendingPackID = nil
        profile.pendingPackCardIDs = []
        persist()
        recordManagerPackOpened()
        return result
    }

    private func previewResult(for card: LegendsCard) -> LegendsPackPullResult {
        LegendsPackPullResult(card: card, isNewCard: !profile.ownedCardIDs.contains(card.id), grantedUpgrade: false)
    }
}

extension LegendsStore {
    /// Spends the pack's cost, pulls `cardCount` cards from its pool
    /// (enforcing the guaranteed minimum rarity), applies duplicate/
    /// upgrade rules, persists, and returns the results in pull order
    /// for the reveal animation.
    @discardableResult
    func openPack(_ pack: LegendsPack) throws -> [LegendsPackPullResult] {
        guard profile.pendingPackID == nil else { throw LegendsPackError.pendingSelection }
        if pack.id == "starter" {
            guard !profile.hasClaimedStarterPack else { throw LegendsPackError.alreadyClaimed }
        }

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
                registerAcquisition(cardID: card.id, method: "PACK: \(pack.id)")
                return LegendsPackPullResult(card: card, isNewCard: true, grantedUpgrade: false)
            }
        }

        if pack.id == "starter" { profile.hasClaimedStarterPack = true }

        persist()
        recordManagerPackOpened()
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
