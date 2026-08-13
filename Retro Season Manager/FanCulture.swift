//
//  FanCulture.swift
//  Retro Season Manager
//
//  Pure, stateless generators for terrace chants and club fan-culture
//  flavour text — no GameStore dependency, so these can be called from
//  anywhere (including live match simulation) without coupling.
//

import Foundation

/// Terrace chant templates with dynamic name insertion.
enum ChantBook {
    static func goalChant(playerName: String) -> String {
        let first = playerName.split(separator: " ").first.map(String.init) ?? playerName
        return [
            "\(first)! \(first)! \(first)!",
            "Oh \(first), \(first), running down the wing!",
            "There's only one \(first)!",
            "\(first), \(first), give us a wave!",
            "We've got \(first), Super \(first)!",
        ].randomElement()!
    }

    static func winChant(clubShortName: String) -> String {
        [
            "We are \(clubShortName), we're by far the greatest team the world has ever seen!",
            "\(clubShortName) 'til I die!",
            "Que sera, sera, whatever will be, will be!",
            "You're not singing, you're not singing, you're not singing anymore!",
        ].randomElement()!
    }

    static func legendSaleChant() -> String {
        [
            "You don't know what you're doing!",
            "Greedy board, shame on you!",
            "We want our \(["hero", "legend", "captain"].randomElement()!) back!",
            "Money before the club again.",
        ].randomElement()!
    }

    static func relegationFearChant(clubShortName: String) -> String {
        [
            "Staaaay up! Staaaay up!",
            "We're \(clubShortName), and we're staying up!",
            "Is this really happening?",
        ].randomElement()!
    }

    static func promotionChant(clubShortName: String) -> String {
        [
            "We are going up! We are going up! We are, we are, we are going up!",
            "\(clubShortName) are back where we belong!",
            "Champions, champions, champions!",
        ].randomElement()!
    }
}

/// Deterministic per-club identity flavour — traditions and a fan-culture
/// profile stay stable for a given club name across the whole career,
/// using the same seed-free stable hash technique as the newspaper
/// masthead naming (`String.hashValue` is process-randomised and would
/// flicker between app launches).
enum FanCulture {
    private static let traditions = [
        "A pre-match pint at the same pub, three generations running.",
        "The whole ground sings the anthem a cappella before kick-off.",
        "Scarves held aloft at kick-off, every single home game.",
        "A giant flag unfurled across the whole end for cup ties.",
        "Fans arrive hours early to grill sausages in the car park.",
        "A minute's applause for departed legends before every home game.",
        "The mascot has worn the same battered costume since the 90s.",
        "Away days always start with a stop at the same greasy spoon.",
        "A pyro display timed to the players walking out for cup finals.",
        "The same drummer has led the songs from the same seat for years.",
    ]

    private static let cultureProfiles = [
        "Loud, loyal, and never afraid to let the board know when they're unhappy.",
        "A famously patient home crowd — but push them too far and the ground turns toxic.",
        "Known across the league for the noisiest away following in the country.",
        "A close-knit, family-oriented fanbase that prizes effort over results.",
        "Fiercely traditional — new-money owners get a frosty reception here.",
        "Young, vocal, and increasingly online — good news travels fast, bad news travels faster.",
        "A working-class stronghold that measures a manager by effort, not just results.",
        "Famously forgiving of bad form, famously unforgiving of a lack of effort.",
    ]

    private static func stableHash(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
    }

    static func traditions(for clubName: String) -> [String] {
        let base = abs(stableHash(clubName))
        let first = traditions[base % traditions.count]
        let second = traditions[(base / 7) % traditions.count]
        return first == second ? [first] : [first, second]
    }

    static func cultureProfile(for clubName: String) -> String {
        cultureProfiles[abs(stableHash(clubName + "·culture")) % cultureProfiles.count]
    }
}
