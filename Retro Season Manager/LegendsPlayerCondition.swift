import Foundation

struct LegendsPlayerCondition: Codable, Hashable {
    var form: Int = 50
    var morale: Int = 50
    var teamwork: Int = 25
    var fame: Int = 0

    mutating func applyMatch(outcome: LegendsMatchOutcome, goals: Int = 0, assists: Int = 0, cleanSheet: Bool = false) {
        let resultDelta = outcome == .win ? 3 : (outcome == .draw ? 1 : -3)
        form = min(100, max(0, form + resultDelta + goals * 3 + assists * 2 + (cleanSheet ? 2 : 0)))
        morale = min(100, max(0, morale + resultDelta + goals + assists))
        teamwork = min(100, teamwork + 1)
        fame = min(100, fame + goals + assists + (cleanSheet ? 1 : 0))
    }

    mutating func closeSeason(improved: Bool, declined: Bool, appearances: Int) {
        form += (50 - form) / 4
        morale = min(100, max(0, morale + (improved ? 2 : declined ? -2 : 0)))
        teamwork = min(100, teamwork + min(8, max(1, appearances / 3)))
        fame = min(100, fame + (appearances >= 10 ? 2 : 0))
    }
}

struct LegendsHonour: Codable, Hashable, Identifiable {
    let id: String
    let season: Int
    let competitionID: String
    let competitionName: String
    let type: String
    let clubName: String
    let cardID: String
    let careerID: String
}

struct LegendsIndividualAward: Codable, Hashable, Identifiable {
    let id: String
    let season: Int
    let type: String
    let cardID: String
    let careerID: String
    let value: Int
}
