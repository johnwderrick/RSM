//
//  LegendsManagersAndStadiums.swift
//  Retro Season Manager
//
//  Managers & Stadiums (Phase 9). Names follow the same PES-style
//  convention already used for player cards — real-sounding first name,
//  invented surname, evoking a real historic manager without being an
//  exact match. Club affinities and stadium names reuse the fictional
//  club universe already established (several of which already borrow
//  loosely from real ground names — "Highbury", "San Siro" — the same
//  light-touch precedent these follow).
//
//  Unlike player cards, Manager/Stadium cards aren't sold in Packs (the
//  doc's Pack System list is player-card-only) — they come from Play
//  Match's Rewards, per the doc's own Rewards list.
//

import SwiftUI

struct LegendsManagerCard: Identifiable, Codable {
    let id: String
    let name: String
    let nation: String
    let specialty: String
    /// Flat bonus added to match strength while this manager is active.
    let tacticalBonus: Int
    /// If a Starting XI player is from this club, they get a small
    /// chemistry bump while this manager is active — the doc's "Same
    /// Manager" chemistry link.
    let affinityClub: String
}

struct LegendsStadiumCard: Identifiable, Codable {
    let id: String
    let name: String
    let club: String
    let capacity: Int
    /// Flat bonus added to match strength while this stadium is home —
    /// the doc's "small gameplay bonus".
    let gameplayBonus: Int
    /// Cosmetic theme colour, shown behind the club crest when this
    /// stadium is home.
    let themeColorRGB: [Double]
}

enum LegendsManagerDatabase {
    static let all: [LegendsManagerCard] = [
        LegendsManagerCard(id: "fergunson", name: "A. Fergunson", nation: "Scotland",
                            specialty: "Built dynasties through relentless standards and famous hairdryer team talks.",
                            tacticalBonus: 4, affinityClub: "Old Trafford Reds"),
        LegendsManagerCard(id: "guardiablo", name: "P. Guardiablo", nation: "Spain",
                            specialty: "Possession-obsessed perfectionist who reinvented the game more than once.",
                            tacticalBonus: 5, affinityClub: "Camp Blaugrana"),
        LegendsManagerCard(id: "mourinsky", name: "J. Mourinsky", nation: "Portugal",
                            specialty: "Self-declared 'Special One' — allergic to losing, addicted to silverware.",
                            tacticalBonus: 4, affinityClub: "Stamford Blues"),
        LegendsManagerCard(id: "wengeri", name: "A. Wengeri", nation: "France",
                            specialty: "Turned a mid-table side into an unbeaten Invincible machine.",
                            tacticalBonus: 3, affinityClub: "Highbury"),
        LegendsManagerCard(id: "ancelotto", name: "C. Ancelotto", nation: "Italy",
                            specialty: "Calm, unflappable, and somehow always in the final.",
                            tacticalBonus: 4, affinityClub: "San Siro Rossoneri"),
        LegendsManagerCard(id: "michelsen", name: "R. Michelsen", nation: "Netherlands",
                            specialty: "Father of Total Football — invented a philosophy, not just a formation.",
                            tacticalBonus: 4, affinityClub: "Amsterdam Godenzonen"),
        LegendsManagerCard(id: "sacchini", name: "A. Sacchini", nation: "Italy",
                            specialty: "Proved you don't need to have been a great player to become a great coach.",
                            tacticalBonus: 3, affinityClub: "San Siro Nerazzurri"),
        LegendsManagerCard(id: "vangaalen", name: "L. Van Gaalen", nation: "Netherlands",
                            specialty: "Meticulous, blunt, and relentlessly effective wherever he's gone.",
                            tacticalBonus: 3, affinityClub: "Bavarian Reds"),
    ]
}

enum LegendsStadiumDatabase {
    static let all: [LegendsStadiumCard] = [
        LegendsStadiumCard(id: "bernabeu-bowl", name: "The Bernabéu Bowl", club: "Bernabéu Whites",
                            capacity: 81_000, gameplayBonus: 3, themeColorRGB: [0.95, 0.95, 0.95]),
        LegendsStadiumCard(id: "camp-fortress", name: "Camp Nou Fortress", club: "Camp Blaugrana",
                            capacity: 99_000, gameplayBonus: 4, themeColorRGB: [0.65, 0.1, 0.2]),
        LegendsStadiumCard(id: "the-theatre", name: "The Theatre", club: "Old Trafford Reds",
                            capacity: 74_000, gameplayBonus: 3, themeColorRGB: [0.8, 0.1, 0.1]),
        LegendsStadiumCard(id: "san-siro", name: "San Siro", club: "San Siro Nerazzurri",
                            capacity: 75_000, gameplayBonus: 3, themeColorRGB: [0.1, 0.1, 0.4]),
        LegendsStadiumCard(id: "bianconeri-arena", name: "The Bianconeri Arena", club: "Turin Bianconeri",
                            capacity: 41_000, gameplayBonus: 2, themeColorRGB: [0.1, 0.1, 0.1]),
        LegendsStadiumCard(id: "etihad-bowl", name: "Etihad Bowl", club: "Etihad Blues",
                            capacity: 55_000, gameplayBonus: 2, themeColorRGB: [0.4, 0.7, 0.9]),
        LegendsStadiumCard(id: "bavarian-arena", name: "The Bavarian Arena", club: "Bavarian Reds",
                            capacity: 75_000, gameplayBonus: 3, themeColorRGB: [0.8, 0.1, 0.1]),
        LegendsStadiumCard(id: "amsterdam-arena", name: "Amsterdam Arena", club: "Amsterdam Godenzonen",
                            capacity: 55_000, gameplayBonus: 2, themeColorRGB: [0.9, 0.5, 0.1]),
    ]
}
