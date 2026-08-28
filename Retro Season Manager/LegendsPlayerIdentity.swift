import Foundation

/// Stable identity for a fictional footballer. Card definitions remain the
/// ownership unit; personID only connects legitimate seasonal variants.
struct LegendsPlayerIdentity: Codable, Hashable, Identifiable {
    let personID: String
    let preferredFoot: LegendsPreferredFoot
    let archetype: LegendsPlayingArchetype
    let biography: String
    var id: String { personID }
}

enum LegendsPreferredFoot: String, Codable, CaseIterable {
    case left = "LEFT"
    case right = "RIGHT"
    case either = "EITHER"
}

enum LegendsPlayingArchetype: String, Codable, CaseIterable {
    case finisher = "FINISHER"
    case creator = "CREATOR"
    case defender = "DEFENDER"
    case goalkeeper = "GOALKEEPER"
    case engine = "ENGINE"
    case winger = "WINGER"
    case complete = "COMPLETE"
}

enum LegendsAttributeGroup: String, Codable, CaseIterable {
    case technical = "TECHNICAL"
    case mental = "MENTAL"
    case physical = "PHYSICAL"
    case goalkeeping = "GOALKEEPING"
}

struct LegendsDetailedAttributes: Codable, Hashable {
    var finishing: Int
    var longShots: Int
    var passing: Int
    var crossing: Int
    var dribbling: Int
    var firstTouch: Int
    var tackling: Int
    var heading: Int
    var setPieces: Int
    var vision: Int
    var decisions: Int
    var positioning: Int
    var anticipation: Int
    var composure: Int
    var workRate: Int
    var leadership: Int
    var teamwork: Int
    var acceleration: Int
    var sprintSpeed: Int
    var agility: Int
    var balance: Int
    var stamina: Int
    var strength: Int
    var handling: Int
    var reflexes: Int
    var oneOnOnes: Int
    var aerialReach: Int
    var distribution: Int
    var goalkeeperPositioning: Int

    static let zero = LegendsDetailedAttributes(finishing: 0, longShots: 0, passing: 0, crossing: 0, dribbling: 0,
        firstTouch: 0, tackling: 0, heading: 0, setPieces: 0, vision: 0, decisions: 0, positioning: 0,
        anticipation: 0, composure: 0, workRate: 0, leadership: 0, teamwork: 0, acceleration: 0,
        sprintSpeed: 0, agility: 0, balance: 0, stamina: 0, strength: 0, handling: 0, reflexes: 0,
        oneOnOnes: 0, aerialReach: 0, distribution: 0, goalkeeperPositioning: 0)

    func value(for key: String) -> Int {
        switch key {
        case "Finishing": return finishing; case "Long shots": return longShots; case "Passing": return passing
        case "Crossing": return crossing; case "Dribbling": return dribbling; case "First touch": return firstTouch
        case "Tackling": return tackling; case "Heading": return heading; case "Set pieces": return setPieces
        case "Vision": return vision; case "Decisions": return decisions; case "Positioning": return positioning
        case "Anticipation": return anticipation; case "Composure": return composure; case "Work rate": return workRate
        case "Leadership": return leadership; case "Teamwork": return teamwork; case "Acceleration": return acceleration
        case "Sprint speed": return sprintSpeed; case "Agility": return agility; case "Balance": return balance
        case "Stamina": return stamina; case "Strength": return strength; case "Handling": return handling
        case "Reflexes": return reflexes; case "One-on-ones": return oneOnOnes; case "Aerial reach": return aerialReach
        case "Distribution": return distribution; case "Goalkeeper positioning": return goalkeeperPositioning
        default: return 0
        }
    }

    func values(in group: LegendsAttributeGroup) -> [(String, Int)] {
        switch group {
        case .technical: return [("Finishing", finishing), ("Long shots", longShots), ("Passing", passing), ("Crossing", crossing), ("Dribbling", dribbling), ("First touch", firstTouch), ("Tackling", tackling), ("Heading", heading), ("Set pieces", setPieces)]
        case .mental: return [("Vision", vision), ("Decisions", decisions), ("Positioning", positioning), ("Anticipation", anticipation), ("Composure", composure), ("Work rate", workRate), ("Leadership", leadership), ("Teamwork", teamwork)]
        case .physical: return [("Acceleration", acceleration), ("Sprint speed", sprintSpeed), ("Agility", agility), ("Balance", balance), ("Stamina", stamina), ("Strength", strength)]
        case .goalkeeping: return [("Handling", handling), ("Reflexes", reflexes), ("One-on-ones", oneOnOnes), ("Aerial reach", aerialReach), ("Distribution", distribution), ("Goalkeeper positioning", goalkeeperPositioning)]
        }
    }
}

struct LegendsPlayerIdentityProfile: Codable, Hashable {
    let identity: LegendsPlayerIdentity
    let attributes: LegendsDetailedAttributes
    let potential: Int
}

enum LegendsIdentityEngine {
    static func profile(for card: LegendsCard) -> LegendsPlayerIdentityProfile {
        let personID: String = {
            let suffixes = ["-tots", "-golden", "-retro", "-immortal", "-icon"]
            var value = suffixes.reduce(card.id) { value, suffix in value.hasSuffix(suffix) ? String(value.dropLast(suffix.count)) : value }
            // Seasonal variants append a four-digit season code (e.g.
            // "miessi-0506", "miessi-1112", "cantina-9596-retro"). Strip it
            // so every legitimate version of the same fictional person
            // resolves to one stable person identity, while the card
            // definitions themselves stay distinct ownership units.
            if let lastHyphen = value.lastIndex(of: "-") {
                let tail = value[value.index(after: lastHyphen)...]
                if tail.count == 4, tail.allSatisfy(\.isNumber) {
                    value = String(value[..<lastHyphen])
                }
            }
            return value
        }()
        let broad = card.position.broad
        let archetype: LegendsPlayingArchetype = {
            switch broad { case .forward: return .finisher; case .midfielder: return .creator; case .defender: return .defender; case .goalkeeper: return .goalkeeper }
        }()
        let foot: LegendsPreferredFoot = stableNumber(personID + "-foot") % 3 == 0 ? .left : (stableNumber(personID + "-foot") % 3 == 1 ? .right : .either)
        let b = card.overall
        func v(_ offset: Int, _ bonus: Int = 0) -> Int { min(99, max(0, b + offset + bonus + stableNumber(card.id + "-" + String(offset)) % 5 - 2)) }
        let keeper = broad == .goalkeeper
        let attrs = LegendsDetailedAttributes(
            finishing: v(card.shooting - b), longShots: v(card.shooting - b - 2), passing: v(card.passing - b), crossing: v(card.passing - b - 1), dribbling: v(card.dribbling - b), firstTouch: v(card.dribbling - b + 1), tackling: v(card.defending - b), heading: v(card.physical - b), setPieces: v(card.passing - b + 1),
            vision: v(card.passing - b + 1), decisions: v(0), positioning: v(card.defending - b + (broad == .forward ? 8 : 0)), anticipation: v(card.defending - b + 2), composure: v(card.shooting - b + 1), workRate: v(card.physical - b + 2), leadership: v(0), teamwork: v(0), acceleration: v(card.pace - b), sprintSpeed: v(card.pace - b), agility: v(card.dribbling - b), balance: v(card.dribbling - b + 1), stamina: v(card.physical - b), strength: v(card.physical - b), handling: keeper ? v(0, 2) : 0, reflexes: keeper ? v(2) : 0, oneOnOnes: keeper ? v(0) : 0, aerialReach: keeper ? v(1) : 0, distribution: keeper ? v(card.passing - b) : 0, goalkeeperPositioning: keeper ? v(1) : 0)
        return LegendsPlayerIdentityProfile(identity: LegendsPlayerIdentity(personID: personID, preferredFoot: foot, archetype: archetype, biography: card.biography), attributes: attrs, potential: min(99, max(b, b + (card.age < 21 ? 10 : card.age < 24 ? 7 : card.age < 28 ? 3 : 0))))
    }

    static func stableNumber(_ string: String) -> Int { string.unicodeScalars.reduce(17) { ($0 * 31 + Int($1.value)) & 0x7fffffff } }
}
