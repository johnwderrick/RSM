//
//  ForeignLeagues.swift
//  Retro Season Manager
//
//  Non-playable club pools for Spain, France, Italy and Germany's top two
//  divisions, circa 2000/01. These clubs exist purely so the Continental Cup
//  and Midweek Cup draw from a genuinely continental field rather than a
//  fixed handful of English-selected "foreign giants" — you can't manage
//  them, and their squads are procedurally generated (like the lower
//  English divisions), not researched real rosters.
//

import Foundation

/// One non-English division: a country, its real-world tier (1 = top
/// flight, 2 = second tier), the game's internal `Club.divisionTier` for
/// it, and the real club names that populate it.
struct ForeignDivision {
    let country: String
    let tier: Int
    let divisionTier: Int
    let clubs: [String]

    var label: String { "\(country) Division \(tier)" }
}

enum ForeignLeagues {
    /// Distinct `Club.divisionTier` values for each pool, kept well clear
    /// of the English pyramid (0-3) and the elite foreign pool (9).
    static let spainTier1 = 20, spainTier2 = 21
    static let italyTier1 = 22, italyTier2 = 23
    static let germanyTier1 = 24, germanyTier2 = 25
    static let franceTier1 = 26, franceTier2 = 27

    static let all: [ForeignDivision] = [
        // Atltico Combine were actually relegated to the Spanish second
        // division at the end of 1999/2000, spending the 2000/01 season
        // there before bouncing straight back — Tier 2 for accuracy.
        ForeignDivision(country: "Spain", tier: 1, divisionTier: spainTier1, clubs: [
            "Valncia Athletic", "Deprtivo Rovers", "Cela Union", "Real Wanderers",
            "Athetic Rangers", "Sevlla Combine", "Real Sporting", "Malorca Dynamo", "Valadolid Olympic",
            "Real Reserve", "Alaés Comrades", "Racng Alliance", "Vilarreal Athletic", "Espnyol Rovers",
            "Las Union", "Málga Wanderers", "Numncia Rangers",
        ]),
        ForeignDivision(country: "Spain", tier: 2, divisionTier: spainTier2, clubs: [
            "Atltico Combine", "Rayo Sporting", "Real Dynamo", "Osauna Olympic", "Tenrife Reserve", "Spoting Comrades",
            "Extemadura Alliance", "Receativo Athletic", "Elce Rovers", "Levnte Union", "Córoba Wanderers",
            "Cádz Rangers", "Albcete Combine", "Xerz Sporting", "Salmanca Dynamo", "Comostela Olympic",
            "Ponerradina Reserve", "Eibr Comrades", "Legnés Alliance",
        ]),
        ForeignDivision(country: "Italy", tier: 1, divisionTier: italyTier1, clubs: [
            "Lazo Athletic", "Tiber Reds", "Para Union", "Fioentina Wanderers", "Udiese Rangers",
            "Bolgna Combine", "Pergia Sporting", "Regina Dynamo", "Helas Olympic", "Lece Reserve",
            "Vicnza Comrades", "Napli Alliance", "Ataanta Athletic", "Adriatic Swifts", "Cagiari Union",
            "Venzia Wanderers", "Brecia Rangers", "Piaenza Combine",
        ]),
        ForeignDivision(country: "Italy", tier: 2, divisionTier: italyTier2, clubs: [
            "Gena Sporting", "Torno Dynamo", "Samdoria Olympic", "Terana Reserve", "Salrnitana Comrades",
            "Cosnza Alliance", "Empli Athletic", "Citadella Rovers", "Ancna Union", "Chivo Wanderers",
            "Mona Rangers", "Pisoiese Combine", "Ravnna Sporting", "Palrmo Dynamo", "Cesna Olympic",
            "Croone Reserve", "Avelino Comrades", "Mesina Alliance",
        ]),
        ForeignDivision(country: "Germany", tier: 1, divisionTier: germanyTier1, clubs: [
            "Borssia Athletic", "Schlke Rovers", "Bayr Union", "VfB Wanderers", "Hamurger Rangers",
            "Werer Combine", "Herha Sporting", "Hana Dynamo", "VfL Olympic", "Kaierslautern Reserve",
            "SC Comrades", "Untrhaching Alliance", "1860 Athletic", "Enegie Rovers", "MSV Union",
            "St. Wanderers", "Einracht Rangers", "FC Combine",
        ]),
        ForeignDivision(country: "Germany", tier: 2, divisionTier: germanyTier2, clubs: [
            "Borssia Sporting", "Einracht Dynamo", "Karsruher Olympic", "1. Reserve", "SSV Comrades",
            "Grether Alliance", "Maiz Athletic", "Unin Rovers", "Erzebirge Union", "Walhof Wanderers",
            "Aleannia Rangers", "VfL Combine", "Rot Sporting", "Chenitzer Dynamo", "Foruna Olympic",
            "Stutgarter Reserve", "Wacer Comrades", "VfL Alliance",
        ]),
        ForeignDivision(country: "France", tier: 1, divisionTier: franceTier1, clubs: [
            "Pars Athletic", "Olypique Rovers", "Olypique Union", "AS Wanderers", "RC Rangers",
            "Girndins Combine", "Nanes Sporting", "AJ Dynamo", "Renes Olympic", "Moselle Athletic",
            "Sedn Comrades", "Guigamp Alliance", "Strsbourg Athletic", "Basia Rovers", "Monpellier Union",
            "Tououse Wanderers", "Lile Rangers", "Nany Combine",
        ]),
        ForeignDivision(country: "France", tier: 2, divisionTier: franceTier2, clubs: [
            "Le Sporting", "Socaux Dynamo", "Riviera Blues", "Sait Reserve", "Norman Athletic",
            "Amins Alliance", "Istes Athletic", "Niot Rovers", "Wasuehal Union", "Angrs Wanderers",
            "Canes Rangers", "Lavl Combine", "Beavais Sporting", "Créeil Dynamo", "Troes Olympic",
            "Guegnon Reserve", "Châeauroux Comrades", "Ajacio Alliance",
        ]),
    ]
}
