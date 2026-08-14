//
//  LegendsPacks.swift
//  Retro Season Manager
//
//  Pack definitions for RSM Legends (Phase 4 — Pack Opening). The design
//  doc's pack list included five real-league-branded packs (Premier
//  League, La Liga, Serie A, Bundesliga, Ligue 1) and live "Event Packs"
//  — both dropped here rather than adapted: the league names are
//  trademarks the rest of the app deliberately avoids, and Event Packs
//  are a live-service concept with nothing to schedule them against yet.
//  Everything else from the doc's list is implemented.
//

import Foundation

enum LegendsCurrency {
    case coins
    case tokens
}

struct LegendsPack: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let cost: Int
    let currency: LegendsCurrency
    let cardCount: Int
    /// At least one pulled card will meet or exceed this rarity tier
    /// (see `LegendsRarity.tier`) — the "Guaranteed rarity indicators"
    /// the doc calls for.
    let guaranteedMinTier: Int
    /// Which cards this pack can pull from.
    let pool: (LegendsCard) -> Bool

    var guaranteedRarityLabel: String {
        let matches = LegendsRarity.allCases.filter { $0.tier == guaranteedMinTier }
        return matches.first?.rawValue ?? "Common"
    }
}

enum LegendsPackDatabase {
    static let all: [LegendsPack] = [
        LegendsPack(id: "starter", name: "Starter Pack", subtitle: "A free taste of the collection",
                    cost: 0, currency: .coins, cardCount: 3, guaranteedMinTier: 1,
                    pool: { _ in true }),
        LegendsPack(id: "bronze", name: "Bronze Pack", subtitle: "Common and Rare cards",
                    cost: 120, currency: .coins, cardCount: 3, guaranteedMinTier: 0,
                    pool: { $0.rarity.tier <= 2 }),
        LegendsPack(id: "silver", name: "Silver Pack", subtitle: "Guaranteed Elite or better",
                    cost: 260, currency: .coins, cardCount: 3, guaranteedMinTier: 2,
                    pool: { _ in true }),
        LegendsPack(id: "gold", name: "Gold Pack", subtitle: "Guaranteed Hero or better",
                    cost: 450, currency: .coins, cardCount: 3, guaranteedMinTier: 3,
                    pool: { _ in true }),
        LegendsPack(id: "heroes", name: "Heroes Pack", subtitle: "Hero-tier cards only",
                    cost: 2, currency: .tokens, cardCount: 3, guaranteedMinTier: 3,
                    pool: { $0.rarity.tier >= 3 }),
        LegendsPack(id: "legends", name: "Legend Pack", subtitle: "Legend-tier cards only",
                    cost: 4, currency: .tokens, cardCount: 3, guaranteedMinTier: 5,
                    pool: { $0.rarity.tier >= 5 }),
        LegendsPack(id: "icons", name: "Icons Pack", subtitle: "Icon-tier cards only",
                    cost: 6, currency: .tokens, cardCount: 3, guaranteedMinTier: 6,
                    pool: { $0.rarity.tier >= 6 }),
        LegendsPack(id: "wonderkids", name: "Wonderkids Pack", subtitle: "Future Stars era",
                    cost: 150, currency: .coins, cardCount: 3, guaranteedMinTier: 1,
                    pool: { $0.era == .futureStars }),
        LegendsPack(id: "2000s", name: "2000s Pack", subtitle: "Cards from the 2000s",
                    cost: 200, currency: .coins, cardCount: 3, guaranteedMinTier: 0,
                    pool: { $0.era == .twoThousands }),
        LegendsPack(id: "2010s", name: "2010s Pack", subtitle: "Cards from the 2010s",
                    cost: 200, currency: .coins, cardCount: 3, guaranteedMinTier: 0,
                    pool: { $0.era == .twentyTens }),
    ]
}
