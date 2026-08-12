//
//  RivalClubs.swift
//  Retro Season Manager
//
//  Real English club rivalries, used to give derby fixtures a genuine
//  identity — bigger attendance, sharper news, more morale on the line —
//  rather than just picking "whichever other club in your division is
//  currently strongest" as a stand-in rival.
//

import Foundation

enum RivalClubs {
    /// Not exhaustive — the most widely recognised derbies among clubs
    /// that actually exist in this game's pyramid. A club can have more
    /// than one real rival (Man Utd's rivalry with both City and
    /// Mersey Reds are both genuine), so this maps a name to a set of names.
    static let pairs: [String: Set<String>] = [
        "Old Trafford Reds": ["Etihad Blues", "Mersey Reds", "Elland Athletic"],
        "Etihad Blues": ["Old Trafford Reds"],
        "Mersey Reds": ["Goodison Blues", "Old Trafford Reds"],
        "Goodison Blues": ["Mersey Reds"],
        "Highbury": ["White Hart Athletic"],
        "White Hart Athletic": ["Highbury", "Stamford Blues"],
        "Stamford Blues": ["White Hart Athletic", "Upton Athletic"],
        "Upton Athletic": ["Stamford Blues", "The Den Lions"],
        "The Den Lions": ["Upton Athletic"],
        "Tyneside": ["Wearside"],
        "Wearside": ["Tyneside"],
        "Elland Athletic": ["Old Trafford Reds"],
        "Bramall Blades": ["Hillsborough Owls"],
        "Hillsborough Owls": ["Bramall Blades"],
        "Ashton Robins": ["Memorial Pirates"],
        "Memorial Pirates": ["Ashton Robins"],
        "Fratton Blues": ["Solent"],
        "Solent": ["Fratton Blues"],
        "Ninian Bluebirds": ["Vetch Swans"],
        "Vetch Swans": ["Ninian Bluebirds"],
        "Deepdale North End": ["Bloomfield Tangerines"],
        "Bloomfield Tangerines": ["Deepdale North End"],
    ]

    static func areRivals(_ nameA: String, _ nameB: String) -> Bool {
        pairs[nameA]?.contains(nameB) ?? false
    }
}
