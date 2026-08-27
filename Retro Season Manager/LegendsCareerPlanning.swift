import Foundation

struct LegendsSeasonDevelopmentReport: Codable, Hashable, Identifiable {
    let season: Int
    let entries: [LegendsSeasonReportEntry]
    let squadAgeWarning: String?
    let positionsNeedingReplacements: [String]
    var id: Int { season }
}

struct LegendsSeasonReportEntry: Codable, Hashable, Identifiable {
    let cardID: String
    let playerName: String
    let completedSeason: Int
    let ageBefore: Int
    let ageAfter: Int
    let overallBefore: Int
    let overallAfter: Int
    let previousStage: String
    let newStage: String
    let developmentProfile: LegendsCareerLifecyclePolicy.DevelopmentProfile
    let improved: Bool
    let stable: Bool
    let declined: Bool
    let enteredFinalSeason: Bool
    let retired: Bool
    let retirementRecordID: String?
    var id: String { cardID }
}

struct LegendsSquadCareerPlan: Hashable {
    let startingXIAverageAge: Int?
    let signedAverageAge: Int?
    let stageCounts: [String: Int]
    let finalSeasonCount: Int
    let retiringNextSeason: [String]
    let retiringWithinThreeSeasons: [String]
    let positionsNeedingReplacements: [String]
    let unsignedReplacements: [String]
    let ageDistribution: [Int: Int]
    let warning: String?
}

extension LegendsStore {
    nonisolated static let baseUnsignedLibraryCapacity = 350

    var unsignedLibraryCapacity: Int { Self.baseUnsignedLibraryCapacity + max(0, profile.libraryCapacityBonus) }
    var unsignedLibraryUsed: Int { unsignedPlayers.count }
    var isUnsignedLibraryFull: Bool { unsignedLibraryUsed >= unsignedLibraryCapacity }

    func isFavourite(_ cardID: String) -> Bool { profile.favouriteCardIDs.contains(cardID) }

    @discardableResult
    func toggleFavourite(cardID: String) -> Bool {
        guard profile.ownedCardIDs.contains(cardID) else { return false }
        if profile.favouriteCardIDs.contains(cardID) { profile.favouriteCardIDs.remove(cardID) }
        else { profile.favouriteCardIDs.insert(cardID) }
        persist()
        return true
    }

    func exactDuplicateIDs(for card: LegendsCard) -> [String] {
        LegendsCardDatabase.all.filter {
            $0.id != card.id && $0.name == card.name && $0.season == card.season && $0.position == card.position
                && profile.ownedCardIDs.contains($0.id)
        }.map(\.id)
    }

    func isExactDuplicate(_ card: LegendsCard) -> Bool { !exactDuplicateIDs(for: card).isEmpty }

    func releaseUnsigned(cardID: String, confirmedFavourite: Bool = false) -> Bool {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), isUnsigned(card) else { return false }
        guard !isFavourite(cardID) || confirmedFavourite else { return false }
        profile.ownedCardIDs.remove(cardID)
        profile.favouriteCardIDs.remove(cardID)
        profile.ownedPlayerRecords = profile.ownedPlayerRecords.filter { $0.value.playerDefinitionID != cardID }
        persist()
        return true
    }

    func addUnsignedCardsTransactionally(_ cards: [LegendsCard], method: String) -> Bool {
        let newIDs = cards.filter { !profile.ownedCardIDs.contains($0.id) }.map(\.id)
        guard unsignedLibraryUsed + newIDs.count <= unsignedLibraryCapacity else { return false }
        for id in newIDs {
            profile.ownedCardIDs.insert(id)
            registerAcquisition(cardID: id, method: method)
        }
        persist()
        return true
    }

    func squadCareerPlan() -> LegendsSquadCareerPlan {
        let signed = activeClubPlayers
        let xiCards = profile.startingXICardIDs.compactMap { id in id.flatMap { cardID in LegendsCardDatabase.all.first { $0.id == cardID } } }
        let average: ([LegendsCard]) -> Int? = { cards in
            guard !cards.isEmpty else { return nil }
            return Int((Double(cards.reduce(0) { $0 + self.effectiveAge(for: $1) }) / Double(cards.count)).rounded())
        }
        var counts: [String: Int] = [:]
        for card in signed { counts[playerCareerStage(for: card)] = counts[playerCareerStage(for: card), default: 0] + 1 }
        let final = signed.filter(isFinalSeason).map(\.name)
        let next = signed.filter { retirementDistance(for: $0) <= 1 }.map(\.name)
        let within = signed.filter { retirementDistance(for: $0) <= 3 }.map(\.name)
        let positions = Set(xiCards.map { $0.position.broad.rawValue })
        let replacements = LegendsCardDatabase.all.filter { candidate in
            isUnsigned(candidate) && xiCards.contains { canPlay(candidate, in: $0.position) }
        }.map(\.name)
        let distribution = Dictionary(grouping: signed, by: { effectiveAge(for: $0) }).mapValues(\.count)
        let warning = next.count >= 2 ? "Several starters are projected to retire next season." : nil
        return LegendsSquadCareerPlan(startingXIAverageAge: average(xiCards), signedAverageAge: average(signed), stageCounts: counts,
                                      finalSeasonCount: final.count, retiringNextSeason: next,
                                      retiringWithinThreeSeasons: within, positionsNeedingReplacements: Array(positions),
                                      unsignedReplacements: replacements, ageDistribution: distribution, warning: warning)
    }

    private func retirementDistance(for card: LegendsCard) -> Int {
        guard let career = profile.playerCareers[card.id] else { return Int.max }
        return max(0, career.intendedRetirementAge - effectiveAge(for: card))
    }

    func playerCareerStage(for card: LegendsCard) -> String {
        if isFinalSeason(card) { return "FINAL SEASON" }
        guard let career = profile.playerCareers[card.id] else { return "UNSIGNED" }
        let age = effectiveAge(for: card)
        if age < career.peakStartAge - 2 { return "PROSPECT" }
        if age < career.peakStartAge { return "DEVELOPING" }
        if age <= career.peakEndAge { return "PRIME" }
        if agingPenalty(for: card) > 0 { return "DECLINING" }
        return "VETERAN"
    }
}
