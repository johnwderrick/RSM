import Foundation

enum LegendsDevelopmentFocus: String, Codable, CaseIterable, Identifiable {
    case balanced = "BALANCED"
    case pace = "PACE"
    case shooting = "SHOOTING"
    case passing = "PASSING"
    case dribbling = "DRIBBLING"
    case defending = "DEFENDING"
    case physical = "PHYSICAL"
    case goalkeeping = "GOALKEEPING"
    case roleSpecific = "ROLE-SPECIFIC"

    var id: String { rawValue }
}

enum LegendsTrainingIntensity: String, Codable, CaseIterable, Identifiable {
    case light = "LIGHT"
    case normal = "NORMAL"
    case intensive = "INTENSIVE"

    var id: String { rawValue }
    var progressMultiplier: Double {
        switch self { case .light: return 0.7; case .normal: return 1; case .intensive: return 1.25 }
    }
}

struct LegendsTrainingRecord: Codable, Hashable, Identifiable {
    let id: String
    let season: Int
    let session: Int
    let focus: LegendsDevelopmentFocus
    let intensity: LegendsTrainingIntensity
    let progress: Int
    let attributeGains: [String: Int]
    let explanation: String
}

struct LegendsTrainingPlan: Codable, Hashable {
    var focus: LegendsDevelopmentFocus
    var intensity: LegendsTrainingIntensity
    var seasonProgress: Int
    var attributeProgress: [String: Int]
    var seasonAttributeGains: [String: Int]
    var recentAttributeGains: [String: Int]
    var lastExplanation: String
    var consecutiveIntensiveSessions: Int
    var history: [LegendsTrainingRecord]

    init(focus: LegendsDevelopmentFocus = .balanced,
         intensity: LegendsTrainingIntensity = .normal,
         seasonProgress: Int = 0,
         attributeProgress: [String: Int] = [:],
         seasonAttributeGains: [String: Int] = [:],
         recentAttributeGains: [String: Int] = [:],
         lastExplanation: String = "Ready to begin development.",
         consecutiveIntensiveSessions: Int = 0,
         history: [LegendsTrainingRecord] = []) {
        self.focus = focus
        self.intensity = intensity
        self.seasonProgress = seasonProgress
        self.attributeProgress = attributeProgress
        self.seasonAttributeGains = seasonAttributeGains
        self.recentAttributeGains = recentAttributeGains
        self.lastExplanation = lastExplanation
        self.consecutiveIntensiveSessions = consecutiveIntensiveSessions
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case focus, intensity, seasonProgress, attributeProgress, seasonAttributeGains
        case recentAttributeGains, lastExplanation, consecutiveIntensiveSessions, history
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focus = try c.decodeIfPresent(LegendsDevelopmentFocus.self, forKey: .focus) ?? .balanced
        intensity = try c.decodeIfPresent(LegendsTrainingIntensity.self, forKey: .intensity) ?? .normal
        seasonProgress = try c.decodeIfPresent(Int.self, forKey: .seasonProgress) ?? 0
        attributeProgress = try c.decodeIfPresent([String: Int].self, forKey: .attributeProgress) ?? [:]
        seasonAttributeGains = try c.decodeIfPresent([String: Int].self, forKey: .seasonAttributeGains) ?? [:]
        recentAttributeGains = try c.decodeIfPresent([String: Int].self, forKey: .recentAttributeGains) ?? [:]
        lastExplanation = try c.decodeIfPresent(String.self, forKey: .lastExplanation) ?? "Ready to begin development."
        consecutiveIntensiveSessions = try c.decodeIfPresent(Int.self, forKey: .consecutiveIntensiveSessions) ?? 0
        history = try c.decodeIfPresent([LegendsTrainingRecord].self, forKey: .history) ?? []
    }
}

extension LegendsDetailedAttributes {
    mutating func addDevelopment(_ amount: Int, to key: String) {
        guard amount > 0 else { return }
        switch key {
        case "Finishing": finishing += amount
        case "Long shots": longShots += amount
        case "Passing": passing += amount
        case "Crossing": crossing += amount
        case "Dribbling": dribbling += amount
        case "First touch": firstTouch += amount
        case "Tackling": tackling += amount
        case "Heading": heading += amount
        case "Set pieces": setPieces += amount
        case "Vision": vision += amount
        case "Decisions": decisions += amount
        case "Positioning": positioning += amount
        case "Anticipation": anticipation += amount
        case "Composure": composure += amount
        case "Work rate": workRate += amount
        case "Leadership": leadership += amount
        case "Teamwork": teamwork += amount
        case "Acceleration": acceleration += amount
        case "Sprint speed": sprintSpeed += amount
        case "Agility": agility += amount
        case "Balance": balance += amount
        case "Stamina": stamina += amount
        case "Strength": strength += amount
        case "Handling": handling += amount
        case "Reflexes": reflexes += amount
        case "One-on-ones": oneOnOnes += amount
        case "Aerial reach": aerialReach += amount
        case "Distribution": distribution += amount
        case "Goalkeeper positioning": goalkeeperPositioning += amount
        default: break
        }
    }

    func applyingDevelopment(_ offsets: LegendsDetailedAttributes) -> LegendsDetailedAttributes {
        func bounded(_ base: Int, _ offset: Int) -> Int { min(99, max(0, base + max(0, offset))) }
        return LegendsDetailedAttributes(
            finishing: bounded(finishing, offsets.finishing), longShots: bounded(longShots, offsets.longShots),
            passing: bounded(passing, offsets.passing), crossing: bounded(crossing, offsets.crossing),
            dribbling: bounded(dribbling, offsets.dribbling), firstTouch: bounded(firstTouch, offsets.firstTouch),
            tackling: bounded(tackling, offsets.tackling), heading: bounded(heading, offsets.heading),
            setPieces: bounded(setPieces, offsets.setPieces), vision: bounded(vision, offsets.vision),
            decisions: bounded(decisions, offsets.decisions), positioning: bounded(positioning, offsets.positioning),
            anticipation: bounded(anticipation, offsets.anticipation), composure: bounded(composure, offsets.composure),
            workRate: bounded(workRate, offsets.workRate), leadership: bounded(leadership, offsets.leadership),
            teamwork: bounded(teamwork, offsets.teamwork), acceleration: bounded(acceleration, offsets.acceleration),
            sprintSpeed: bounded(sprintSpeed, offsets.sprintSpeed), agility: bounded(agility, offsets.agility),
            balance: bounded(balance, offsets.balance), stamina: bounded(stamina, offsets.stamina),
            strength: bounded(strength, offsets.strength), handling: bounded(handling, offsets.handling),
            reflexes: bounded(reflexes, offsets.reflexes), oneOnOnes: bounded(oneOnOnes, offsets.oneOnOnes),
            aerialReach: bounded(aerialReach, offsets.aerialReach), distribution: bounded(distribution, offsets.distribution),
            goalkeeperPositioning: bounded(goalkeeperPositioning, offsets.goalkeeperPositioning)
        )
    }
}

extension LegendsStore {
    func trainingPlan(for card: LegendsCard) -> LegendsTrainingPlan? {
        profile.playerCareers[card.id]?.trainingPlan
    }

    func availableDevelopmentFocuses(for card: LegendsCard) -> [LegendsDevelopmentFocus] {
        if card.position.broad == .goalkeeper {
            return [.balanced, .passing, .physical, .goalkeeping, .roleSpecific]
        }
        return LegendsDevelopmentFocus.allCases.filter { $0 != .goalkeeping }
    }

    @discardableResult
    func setDevelopmentFocus(_ focus: LegendsDevelopmentFocus, for cardID: String) -> Bool {
        guard var career = activeTrainingCareer(cardID),
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
              availableDevelopmentFocuses(for: card).contains(focus) else { return false }
        career.trainingPlan.focus = focus
        career.trainingPlan.lastExplanation = "Development focus changed to \(focus.rawValue.lowercased())."
        profile.playerCareers[cardID] = career
        persist()
        return true
    }

    @discardableResult
    func setTrainingIntensity(_ intensity: LegendsTrainingIntensity, for cardID: String) -> Bool {
        guard var career = activeTrainingCareer(cardID) else { return false }
        career.trainingPlan.intensity = intensity
        career.trainingPlan.lastExplanation = "Training intensity set to \(intensity.rawValue.lowercased())."
        if intensity != .intensive { career.trainingPlan.consecutiveIntensiveSessions = 0 }
        profile.playerCareers[cardID] = career
        persist()
        return true
    }

    private func activeTrainingCareer(_ cardID: String) -> LegendsPlayerCareer? {
        guard profile.activatedCardIDs.contains(cardID), profile.ownedCardIDs.contains(cardID),
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), !isRetired(card) else { return nil }
        return profile.playerCareers[cardID]
    }

    static func focusTargets(_ focus: LegendsDevelopmentFocus, for card: LegendsCard,
                             archetype: LegendsPlayingArchetype) -> [String] {
        if card.position.broad == .goalkeeper {
            switch focus {
            case .passing: return ["Distribution", "Decisions", "First touch"]
            case .physical: return ["Strength", "Agility", "Aerial reach", "Stamina"]
            default: return ["Handling", "Reflexes", "One-on-ones", "Goalkeeper positioning", "Aerial reach", "Distribution"]
            }
        }
        switch focus {
        case .pace: return ["Acceleration", "Sprint speed", "Agility"]
        case .shooting: return ["Finishing", "Long shots", "Composure", "Positioning"]
        case .passing: return ["Passing", "Vision", "Decisions", "Crossing"]
        case .dribbling: return ["Dribbling", "First touch", "Balance", "Agility"]
        case .defending: return ["Tackling", "Positioning", "Anticipation", "Heading"]
        case .physical: return ["Stamina", "Strength", "Work rate", "Balance"]
        case .roleSpecific:
            switch card.position.broad {
            case .forward: return ["Finishing", "Positioning", "Composure", "Acceleration"]
            case .midfielder: return ["Passing", "Vision", "Decisions", "First touch"]
            case .defender: return ["Tackling", "Positioning", "Anticipation", "Strength"]
            case .goalkeeper: return []
            }
        case .balanced:
            switch archetype {
            case .finisher: return ["Finishing", "Composure", "Acceleration", "First touch"]
            case .creator, .winger: return ["Passing", "Vision", "Dribbling", "Stamina"]
            case .defender: return ["Tackling", "Positioning", "Strength", "Decisions"]
            case .engine: return ["Stamina", "Work rate", "Passing", "Teamwork"]
            case .complete: return ["Decisions", "First touch", "Stamina", "Positioning"]
            case .goalkeeper: return []
            }
        case .goalkeeping: return []
        }
    }

    static func trainingExplanation(age: Int, career: LegendsPlayerCareer, progress: Int,
                                    gains: [String: Int]) -> String {
        if age > career.peakEndAge { return gains.isEmpty ? "Maintaining ability beyond peak." : "Training softened age-related decline." }
        if career.potential <= career.startingOverall + developmentBonusValue(career) { return "Progress slowed near current ceiling." }
        if career.seasonAppearances == 0 { return "Limited minutes reduced development." }
        if !gains.isEmpty { return "Training focus improved \(gains.keys.sorted().joined(separator: ", ").lowercased())." }
        return progress > 0 ? "Developing steadily through training." : "Development held steady."
    }

    private static func developmentBonusValue(_ career: LegendsPlayerCareer) -> Int {
        max(0, career.developmentProgress / 100)
    }
}
