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

/// Read-only, view-facing summary for the redesigned Training screen.
/// Every value is derived from the existing career/training models — no
/// new progression data, no mutation of the store.
struct LegendsTrainingCentreSummary: Equatable {
    let signedPlayers: Int
    let sessionsRemaining: Int
    let totalSessionAllowance: Int
    let playersAtSessionLimit: Int
    let prospectsAndDeveloping: Int
    let finalSeasonPlayers: Int
    let focusCounts: [LegendsDevelopmentFocus: Int]
    let intensityCounts: [LegendsTrainingIntensity: Int]
}

extension LegendsStore {
    /// Aggregates the active signed squad's training state for the
    /// Training centre's summary band and plan block. Read-only.
    func trainingCentreSummary() -> LegendsTrainingCentreSummary {
        let players = activeClubPlayers
        let allowance = Self.maxTrainingSessionsPerSeason
        var remaining = 0
        var atLimit = 0
        var developing = 0
        var finalSeason = 0
        var focusCounts: [LegendsDevelopmentFocus: Int] = [:]
        var intensityCounts: [LegendsTrainingIntensity: Int] = [:]
        for card in players {
            let career = careerState(for: card)
            let left = max(0, allowance - (career?.trainingSessionsThisSeason ?? 0))
            remaining += left
            if left == 0 { atLimit += 1 }
            let stage = playerCareerStage(for: card)
            if stage == "PROSPECT" || stage == "DEVELOPING" { developing += 1 }
            if isFinalSeason(card) { finalSeason += 1 }
            let plan = career?.trainingPlan ?? LegendsTrainingPlan()
            focusCounts[plan.focus, default: 0] += 1
            intensityCounts[plan.intensity, default: 0] += 1
        }
        return LegendsTrainingCentreSummary(
            signedPlayers: players.count,
            sessionsRemaining: remaining,
            totalSessionAllowance: allowance * players.count,
            playersAtSessionLimit: atLimit,
            prospectsAndDeveloping: developing,
            finalSeasonPlayers: finalSeason,
            focusCounts: focusCounts,
            intensityCounts: intensityCounts)
    }

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

    #if DEBUG
    /// Deterministic UI-test fixture: one signed young player and no stale
    /// save state. Production launches can never invoke this path.
    func prepareTrainingFixtureForDebug() {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == "miessi-0506" }) else { return }
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        profile.ownedCardIDs = [card.id]
        profile.activatedCardIDs = [card.id]
        profile.playerCareers = [card.id: Self.makeCareerState(for: card, signedSeason: 1)]
        profile.ownedPlayerRecords = [
            "training-fixture": LegendsOwnedPlayerRecord(
                careerID: "training-fixture", playerDefinitionID: card.id,
                state: .signed, acquiredSeason: 1, acquisitionMethod: "ui-test", isNew: false
            )
        ]
        profile.startingXICardIDs = Array(repeating: nil, count: 11)
        profile.benchCardIDs = Array(repeating: nil, count: Self.benchSize)
        profile.captainCardID = nil
        profile.currentSeason = 1
        profile.matchesPlayedThisSeason = 0
        profile.cardAgeOffsets = [:]
        profile.legendsHall = []
        profile.seasonReports = [:]
        persist()
    }

    /// Deterministic UI-test fixture with a complete, signed Starting XI.
    /// Resetting the whole profile prevents state left by an earlier UI test
    /// from sending the pre-kickoff flow to its "squad not ready" screen.
    func prepareMatchReadyFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()
    }

    /// Deterministic UI-test fixture for the redesigned Division screen: a
    /// fresh starter profile whose first three league rounds are already
    /// played with fixed scores, giving the fixture centre a next fixture,
    /// further upcoming fixtures and win/draw/loss recent results without
    /// playing any matches. The schedule scores are also applied to the
    /// standings ledger through the store's real `recordDivisionMatch`
    /// recording path, so the table is consistent with the results (4
    /// points from three games puts the user top, in the promotion zone).
    /// Presentation only — round resolution and season logic are not run.
    func prepareDivisionFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()
        ensureDivisionSchedule()
        let club = profile.clubName
        // (round, user's goals, opponent's goals)
        let scores: [(round: Int, teamGoals: Int, opponentGoals: Int)] = [
            (1, 3, 1), // win
            (2, 1, 1), // draw
            (3, 0, 2), // loss
        ]
        for score in scores {
            guard let index = profile.divisionSchedule.firstIndex(where: { fixture in
                fixture.round == score.round
                    && (fixture.homeTeamID == club || fixture.awayTeamID == club)
            }) else { continue }
            let userIsHome = profile.divisionSchedule[index].homeTeamID == club
            profile.divisionSchedule[index].homeGoals = userIsHome ? score.teamGoals : score.opponentGoals
            profile.divisionSchedule[index].awayGoals = userIsHome ? score.opponentGoals : score.teamGoals
            let opponent = userIsHome
                ? profile.divisionSchedule[index].awayTeamID
                : profile.divisionSchedule[index].homeTeamID
            recordDivisionMatch(teamGoals: score.teamGoals, opponentGoals: score.opponentGoals,
                                opponentName: opponent)
        }
        persist()
    }

    /// Deterministic UI-test fixture for the redesigned Packs shelf: a
    /// fully onboarded profile with real balances so the shelf shows both
    /// affordable and unaffordable packs, and a mid-open Starter Pack
    /// decision so the pending banner is present. No cards are awarded —
    /// claiming stays a real UI action. Presentation only.
    func preparePacksFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        // Balances chosen to make specific shelf states deterministic:
        // bronze/silver/gold affordable while the premium packs are not.
        // The club balance is intentionally unrelated to pack access.
        profile.coins = 300
        profile.packTokens = 3
        profile.pendingPackID = "starter"
        profile.pendingPackCardIDs = ["miessi-0506", "maldinho-9596", "batigora-9596"]
        profile.hasClaimedStarterPack = false
        persist()
    }

    /// Deterministic UI-test fixture for the redesigned Training centre: the
    /// starter squad with seeded careers so the summary band, training-plan
    /// block and player rows show real development state — one prospect
    /// mid-plan with a session used, one player at the seasonal session
    /// limit. Presentation only; no training sessions are actually run.
    func prepareTrainingCentreFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()
        // Two known anchor cards so UI tests can address specific rows. The
        // store's own migration registers them as signed — no bespoke
        // record bookkeeping here.
        for id in ["miessi-0506", "miessi-1112"] {
            profile.ownedCardIDs.insert(id)
            profile.activatedCardIDs.insert(id)
        }
        migrateOwnedPlayerRecords()
        // Every signed player gets a real career record so rows show plans
        // rather than blanks.
        for card in activeClubPlayers where profile.playerCareers[card.id] == nil {
            profile.playerCareers[card.id] = Self.makeCareerState(for: card, signedSeason: profile.currentSeason)
        }
        if var prospect = profile.playerCareers["miessi-0506"] {
            prospect.trainingSessionsThisSeason = 1
            prospect.trainingPlan.focus = .passing
            prospect.trainingPlan.seasonProgress = 45
            prospect.trainingPlan.lastExplanation = "Training focus improved passing, vision."
            prospect.trainingPlan.seasonAttributeGains = ["Passing": 1, "Vision": 1]
            profile.playerCareers["miessi-0506"] = prospect
        }
        if var capped = profile.playerCareers["miessi-1112"] {
            capped.trainingSessionsThisSeason = Self.maxTrainingSessionsPerSeason
            capped.trainingPlan.focus = .shooting
            capped.trainingPlan.seasonProgress = 78
            capped.trainingPlan.lastExplanation = "Progress slowed near current ceiling."
            profile.playerCareers["miessi-1112"] = capped
        }
        persist()
    }

    /// Deterministic UI-test fixture for the redesigned Assistants and
    /// Stadiums collections: two owned assistants (first active, second
    /// inactive) and two owned stadiums (second active as home), plus a
    /// locked remainder so ALL/OWNED filtering and locked presentation are
    /// all deterministic. Presentation only; no unlock rolls are run.
    func prepareCollectionFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        profile.coins = 500
        profile.packTokens = 7
        profile.ownedManagerIDs = ["fergunson", "guardiablo"]
        profile.activeManagerID = "fergunson"
        profile.ownedStadiumIDs = ["bernabeu-bowl", "camp-fortress"]
        profile.activeStadiumID = "camp-fortress"
        persist()
    }

    /// Deterministic UI-test fixture for the Club Facilities destination.
    /// It uses a fresh onboarded profile with enough Balance for a first
    /// Training Centre upgrade while retaining pack tokens to prove the two
    /// currencies stay separate.
    func prepareFacilitiesFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        profile.coins = 500
        profile.packTokens = 7
        profile.facilityLevels = [:]
        persist()
    }

    #endif
}
