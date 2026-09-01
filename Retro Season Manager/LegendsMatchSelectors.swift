import Foundation

/// Central, bounded selectors for Legends gameplay. These are deliberately
/// small blends: card quality, tactics and chemistry remain authoritative.
enum LegendsMatchSelectors {
    static func bounded(_ value: Double) -> Int { min(99, max(0, Int(value.rounded()))) }
    static func passing(_ attributes: LegendsDetailedAttributes, difficulty: Double = 0) -> Int {
        bounded(Double(attributes.passing) * 0.45 + Double(attributes.vision) * 0.25 + Double(attributes.decisions) * 0.20 + Double(attributes.firstTouch) * 0.10 - difficulty)
    }
    static func chanceCreation(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.passing) * 0.35 + Double(a.vision) * 0.35 + Double(a.decisions) * 0.20 + Double(a.dribbling) * 0.10) }
    static func firstTouch(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.firstTouch) * 0.7 + Double(a.dribbling) * 0.2 + Double(a.composure) * 0.1) }
    static func dribbling(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.dribbling) * 0.65 + Double(a.agility) * 0.2 + Double(a.balance) * 0.15) }
    static func shooting(_ a: LegendsDetailedAttributes, pressure: Double = 0) -> Int { bounded(Double(a.finishing) * 0.45 + Double(a.composure) * 0.25 + Double(a.longShots) * 0.20 + Double(a.firstTouch) * 0.10 - pressure) }
    static func shotPower(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.strength) * 0.45 + Double(a.longShots) * 0.35 + Double(a.finishing) * 0.20) }
    static func defending(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.positioning) * 0.35 + Double(a.anticipation) * 0.30 + Double(a.tackling) * 0.25 + Double(a.strength) * 0.10) }
    static func aerial(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.heading) * 0.45 + Double(a.strength) * 0.30 + Double(a.positioning) * 0.25) }
    static func goalkeeper(_ a: LegendsDetailedAttributes) -> Int { bounded(Double(a.reflexes) * 0.30 + Double(a.handling) * 0.25 + Double(a.goalkeeperPositioning) * 0.20 + Double(a.oneOnOnes) * 0.15 + Double(a.aerialReach) * 0.10) }
}
