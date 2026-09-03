import Foundation

struct LegendsSeasonDevelopmentReport: Codable, Hashable, Identifiable {
    let season: Int
    let entries: [LegendsSeasonReportEntry]
    let squadAgeWarning: String?
    let positionsNeedingReplacements: [String]
    let startingXIAverageAgeBefore: Int?
    let startingXIAverageAgeAfter: Int?
    let signedAverageAgeBefore: Int?
    let signedAverageAgeAfter: Int?
    let createdAt: Date
    let schemaVersion: Int
    var id: Int { season }

    init(season: Int, entries: [LegendsSeasonReportEntry], squadAgeWarning: String? = nil,
         positionsNeedingReplacements: [String] = [], startingXIAverageAgeBefore: Int? = nil,
         startingXIAverageAgeAfter: Int? = nil, signedAverageAgeBefore: Int? = nil,
         signedAverageAgeAfter: Int? = nil, createdAt: Date = Date(), schemaVersion: Int = 1) {
        self.season = season; self.entries = entries; self.squadAgeWarning = squadAgeWarning
        self.positionsNeedingReplacements = positionsNeedingReplacements
        self.startingXIAverageAgeBefore = startingXIAverageAgeBefore
        self.startingXIAverageAgeAfter = startingXIAverageAgeAfter
        self.signedAverageAgeBefore = signedAverageAgeBefore
        self.signedAverageAgeAfter = signedAverageAgeAfter
        self.createdAt = createdAt; self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey { case season, entries, squadAgeWarning, positionsNeedingReplacements, startingXIAverageAgeBefore, startingXIAverageAgeAfter, signedAverageAgeBefore, signedAverageAgeAfter, createdAt, schemaVersion }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        season = try c.decodeIfPresent(Int.self, forKey: .season) ?? 0
        entries = try c.decodeIfPresent([LegendsSeasonReportEntry].self, forKey: .entries) ?? []
        squadAgeWarning = try c.decodeIfPresent(String.self, forKey: .squadAgeWarning)
        positionsNeedingReplacements = try c.decodeIfPresent([String].self, forKey: .positionsNeedingReplacements) ?? []
        startingXIAverageAgeBefore = try c.decodeIfPresent(Int.self, forKey: .startingXIAverageAgeBefore)
        startingXIAverageAgeAfter = try c.decodeIfPresent(Int.self, forKey: .startingXIAverageAgeAfter)
        signedAverageAgeBefore = try c.decodeIfPresent(Int.self, forKey: .signedAverageAgeBefore)
        signedAverageAgeAfter = try c.decodeIfPresent(Int.self, forKey: .signedAverageAgeAfter)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
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
    let portraitReference: String?
    let position: DetailedPosition
    let favourite: Bool
    let attributeDeltas: [String: Int]
    let enteredPrime: Bool
    let trainingFocus: LegendsDevelopmentFocus
    let trainingIntensity: LegendsTrainingIntensity
    let trainingSessions: Int
    let trainingProgress: Int
    let trainingAttributeGains: [String: Int]
    let trainingExplanation: String
    var id: String { cardID }

    init(cardID: String, playerName: String, completedSeason: Int, ageBefore: Int, ageAfter: Int,
         overallBefore: Int, overallAfter: Int, previousStage: String, newStage: String,
         developmentProfile: LegendsCareerLifecyclePolicy.DevelopmentProfile, improved: Bool,
         stable: Bool, declined: Bool, enteredFinalSeason: Bool, retired: Bool,
         retirementRecordID: String? = nil, portraitReference: String? = nil,
         position: DetailedPosition = .goalkeeper, favourite: Bool = false,
         attributeDeltas: [String: Int] = [:], enteredPrime: Bool = false,
         trainingFocus: LegendsDevelopmentFocus = .balanced,
         trainingIntensity: LegendsTrainingIntensity = .normal,
         trainingSessions: Int = 0, trainingProgress: Int = 0,
         trainingAttributeGains: [String: Int] = [:],
         trainingExplanation: String = "No training completed.") {
        self.cardID = cardID; self.playerName = playerName; self.completedSeason = completedSeason
        self.ageBefore = ageBefore; self.ageAfter = ageAfter; self.overallBefore = overallBefore
        self.overallAfter = overallAfter; self.previousStage = previousStage; self.newStage = newStage
        self.developmentProfile = developmentProfile; self.improved = improved; self.stable = stable
        self.declined = declined; self.enteredFinalSeason = enteredFinalSeason; self.retired = retired
        self.retirementRecordID = retirementRecordID; self.portraitReference = portraitReference
        self.position = position; self.favourite = favourite; self.attributeDeltas = attributeDeltas
        self.enteredPrime = enteredPrime
        self.trainingFocus = trainingFocus; self.trainingIntensity = trainingIntensity
        self.trainingSessions = trainingSessions; self.trainingProgress = trainingProgress
        self.trainingAttributeGains = trainingAttributeGains
        self.trainingExplanation = trainingExplanation
    }

    private enum CodingKeys: String, CodingKey { case cardID, playerName, completedSeason, ageBefore, ageAfter, overallBefore, overallAfter, previousStage, newStage, developmentProfile, improved, stable, declined, enteredFinalSeason, retired, retirementRecordID, portraitReference, position, favourite, attributeDeltas, enteredPrime, trainingFocus, trainingIntensity, trainingSessions, trainingProgress, trainingAttributeGains, trainingExplanation }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cardID = try c.decodeIfPresent(String.self, forKey: .cardID) ?? ""; playerName = try c.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        completedSeason = try c.decodeIfPresent(Int.self, forKey: .completedSeason) ?? 0; ageBefore = try c.decodeIfPresent(Int.self, forKey: .ageBefore) ?? 0; ageAfter = try c.decodeIfPresent(Int.self, forKey: .ageAfter) ?? ageBefore
        overallBefore = try c.decodeIfPresent(Int.self, forKey: .overallBefore) ?? 0; overallAfter = try c.decodeIfPresent(Int.self, forKey: .overallAfter) ?? overallBefore
        previousStage = try c.decodeIfPresent(String.self, forKey: .previousStage) ?? "ACTIVE"; newStage = try c.decodeIfPresent(String.self, forKey: .newStage) ?? previousStage
        developmentProfile = try c.decodeIfPresent(LegendsCareerLifecyclePolicy.DevelopmentProfile.self, forKey: .developmentProfile) ?? .standardDeveloper
        improved = try c.decodeIfPresent(Bool.self, forKey: .improved) ?? false; stable = try c.decodeIfPresent(Bool.self, forKey: .stable) ?? false; declined = try c.decodeIfPresent(Bool.self, forKey: .declined) ?? false
        enteredFinalSeason = try c.decodeIfPresent(Bool.self, forKey: .enteredFinalSeason) ?? false; retired = try c.decodeIfPresent(Bool.self, forKey: .retired) ?? false; retirementRecordID = try c.decodeIfPresent(String.self, forKey: .retirementRecordID)
        portraitReference = try c.decodeIfPresent(String.self, forKey: .portraitReference); position = try c.decodeIfPresent(DetailedPosition.self, forKey: .position) ?? .goalkeeper; favourite = try c.decodeIfPresent(Bool.self, forKey: .favourite) ?? false; attributeDeltas = try c.decodeIfPresent([String: Int].self, forKey: .attributeDeltas) ?? [:]; enteredPrime = try c.decodeIfPresent(Bool.self, forKey: .enteredPrime) ?? false
        trainingFocus = try c.decodeIfPresent(LegendsDevelopmentFocus.self, forKey: .trainingFocus) ?? .balanced
        trainingIntensity = try c.decodeIfPresent(LegendsTrainingIntensity.self, forKey: .trainingIntensity) ?? .normal
        trainingSessions = try c.decodeIfPresent(Int.self, forKey: .trainingSessions) ?? 0
        trainingProgress = try c.decodeIfPresent(Int.self, forKey: .trainingProgress) ?? 0
        trainingAttributeGains = try c.decodeIfPresent([String: Int].self, forKey: .trainingAttributeGains) ?? [:]
        trainingExplanation = try c.decodeIfPresent(String.self, forKey: .trainingExplanation) ?? "No training completed."
    }
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
