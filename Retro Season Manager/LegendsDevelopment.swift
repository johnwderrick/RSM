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
        profile.coins = 300 * LegendsBalance.legacyUnitScale
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

    /// Deterministic UI-test fixture for the redesigned Players collection:
    /// the fully-signed starter squad plus two unsigned cards (a top-rated
    /// Maldinho and a young Miessi), a favourited card, an exact duplicate
    /// pair, and a completed Hall career so every summary figure, status
    /// chip and tile badge is deterministic. Presentation only; no pack or
    /// signing actions are performed.
    func preparePlayersFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()
        // Two unsigned cards: owned but never signed, so their age stays
        // frozen and the UNSIGNED chip has deterministic content.
        profile.ownedCardIDs.insert("maldinho-9596")
        profile.ownedCardIDs.insert("miessi-0506")
        // An exact duplicate pair: same player name+season+position. The
        // base card is activated (signed, in the reserves); its retro twin
        // stays unsigned, so both states are deterministic.
        profile.ownedCardIDs.insert("cantina-9596")
        profile.ownedCardIDs.insert("cantina-9596-retro")
        profile.activatedCardIDs.insert("cantina-9596")
        profile.favouriteCardIDs.insert("cantina-9596")
        migrateOwnedPlayerRecords()
        // A completed career in the Hall for a card no longer owned, so the
        // LEGENDS status has deterministic content.
        profile.legendsHall.append(LegendsHallEntry(
            id: "ui-test-mbappa-career", cardID: "mbappa-2223", playerName: "K. Mbappa",
            position: .striker, nation: "France", startingAge: 23, startingOverall: 91,
            highestOverall: 94, finalAge: 34, appearances: 412, goals: 289, assists: 87,
            cleanSheets: 0, seasonsAtClub: 11, signedSeason: 1, retiredSeason: 11))
        migrateOwnedPlayerRecords()
        persist()
    }

    /// Deterministic UI-test fixture for the redesigned player-detail
    /// screen: one signed squad holding a starting-XI starter (Buffonte,
    /// goalkeeper), a bench substitute (starter-squad outfielder), and
    /// Cantina (reserves, favourited, exact-duplicate twin, final-season
    /// career with progress) plus the unsigned Maldinho — every state the
    /// detail screen can present, deterministic and presentation-only.
    func preparePlayerDetailFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect)
        migrateOwnedPlayerRecords()

        // Unsigned: owned but never signed, age frozen.
        profile.ownedCardIDs.insert("maldinho-9596")

        // Signed states on top of the starter XI: Cantina becomes a
        // reserves career with a mid-career age and final-season warning,
        // favourites set, and an exact duplicate twin owned but unsigned.
        profile.ownedCardIDs.insert("cantina-9596")
        profile.ownedCardIDs.insert("cantina-9596-retro")
        signPlayer(cardID: "cantina-9596")
        profile.favouriteCardIDs.insert("cantina-9596")
        if var career = profile.playerCareers["cantina-9596"] {
            // Deterministic mid-career progress: enough for apps, goals,
            // a season record, milestone, and final-season flagging under
            // the authoritative isFinalSeason rule (age == intended - 1).
            career.appearances = 120
            career.seasonAppearances = 12
            career.goals = 44
            career.seasonGoals = 5
            career.assists = 31
            career.seasonAssists = 4
            career.cleanSheets = 6
            career.seasonCleanSheets = 1
            career.minutesPlayed = 9_800
            career.starts = 110
            career.highestOverall = career.startingOverall + 2
            career.trainingSessionsThisSeason = 2
            career.trainingSessions = 9
            profile.playerCareers["cantina-9596"] = career
        }
        // Age the Cantina career to one season before its intended
        // retirement so the final-season warning is deterministically on
        // (age is driven by cardAgeOffsets, the same lever the season
        // rollover uses).
        if let card = LegendsCardDatabase.all.first(where: { $0.id == "cantina-9596" }),
           let career = profile.playerCareers["cantina-9596"] {
            profile.cardAgeOffsets[card.id] = career.intendedRetirementAge - card.age - 1
        }

        // Duplicate progress on the base Cantina card: one duplicate
        // already counted toward the next upgrade (never grants one).
        profile.duplicateProgress["cantina-9596"] = 1

        migrateOwnedPlayerRecords()
        persist()
    }

    /// Deterministic UI-test fixture for the Squad reserves section: two
    /// signed players held outside the XI and bench (one favourited), plus
    /// one owned-but-unsigned card that must never surface as a reserve.
    /// Presentation only — the starter squad keeps its default XI and bench
    /// (buffonte-0506 is the starter goalkeeper, and one-card-per-person
    /// rules out any starter's other-season card, so reserves use Cantina
    /// and Neuwald — neither shares a person with the starter squad).
    func prepareReservesFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()

        // The empty variant keeps the starter squad untouched: every signed
        // player is already in the XI or bench, so reserves are empty.
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_SQUAD_RESERVES_EMPTY") {
            persist()
            return
        }

        profile.ownedCardIDs.insert("cantina-9596")
        profile.ownedCardIDs.insert("maldinho-9596")
        profile.ownedCardIDs.insert("neuwald-2223")

        signPlayer(cardID: "cantina-9596")
        signPlayer(cardID: "neuwald-2223")
        profile.favouriteCardIDs.insert("neuwald-2223")
        // maldinho-9596 stays owned but unsigned: the reserves list must
        // exclude it even though it is visible in the collection.

        migrateOwnedPlayerRecords()
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
        profile.coins = 500 * LegendsBalance.legacyUnitScale
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
        profile.coins = 500 * LegendsBalance.legacyUnitScale
        profile.packTokens = 7
        profile.facilityLevels = [:]
        persist()
    }

    /// Deterministic UI-test fixture for the redesigned Legends Hall: five
    /// completed careers with varied rankings, statistics, honours, awards,
    /// favourites and one club legend, so the summary band, Hall of Fame
    /// podium, sorting, search and card presentation are all deterministic.
    /// Presentation only — no retirement or legacy recalculation is run;
    /// the legacy scores below were produced by the authoritative formula.
    func prepareHallFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()

        func record(_ start: Int, _ end: Int, age: Int, apps: Int, goals: Int,
                    assists: Int, cleanSheets: Int = 0, overallStart: Int,
                    overallEnd: Int) -> LegendsSeasonRecord {
            LegendsSeasonRecord(season: start, age: age, appearances: apps, goals: goals,
                                assists: assists, cleanSheets: cleanSheets,
                                overallAtStart: overallStart, overallAtEnd: overallEnd)
        }

        // #1 by legacy score — club-legend striker with honours and awards.
        profile.legendsHall.append(LegendsHallEntry(
            id: "ui-hall-mbappa", cardID: "mbappa-2223", playerName: "K. Mbappa",
            position: .striker, nation: "France", startingAge: 23, startingOverall: 91,
            highestOverall: 94, finalAge: 34, appearances: 412, goals: 289, assists: 87,
            cleanSheets: 0, seasonsAtClub: 11, signedSeason: 1, retiredSeason: 11,
            finalOverall: 90, trophies: 10,
            milestones: [.firstAppearance, .firstGoal, .seventyAppearances, .hundredFortyAppearances,
                         .threeFiftyAppearances, .seventyGoals, .hundredFortyGoals, .twoEightyGoals,
                         .firstTrophy, .clubLegend],
            isClubLegend: true, legacyScore: 5512,
            careerHistory: [
                record(1, 1, age: 23, apps: 36, goals: 24, assists: 8, overallStart: 91, overallEnd: 92),
                record(2, 2, age: 24, apps: 38, goals: 27, assists: 9, overallStart: 92, overallEnd: 93),
                record(3, 3, age: 25, apps: 37, goals: 30, assists: 7, overallStart: 93, overallEnd: 94),
            ],
            identityProfile: LegendsIdentityEngine.profile(for: LegendsCardDatabase.all.first { $0.id == "mbappa-2223" }!),
            honours: [
                LegendsHonour(id: "ui-hall-mbappa-h1", season: 1, competitionID: "division-1",
                              competitionName: "Legends Division 1", type: "CHAMPIONS",
                              clubName: profile.clubName, cardID: "mbappa-2223", careerID: "ui-hall-mbappa"),
                LegendsHonour(id: "ui-hall-mbappa-h2", season: 3, competitionID: "legends-cup",
                              competitionName: "Legends Cup", type: "WINNERS",
                              clubName: profile.clubName, cardID: "mbappa-2223", careerID: "ui-hall-mbappa"),
            ],
            individualAwards: [
                LegendsIndividualAward(id: "ui-hall-mbappa-a1", season: 2, type: "GOLDEN BOOT",
                                       cardID: "mbappa-2223", careerID: "ui-hall-mbappa", value: 27),
                LegendsIndividualAward(id: "ui-hall-mbappa-a2", season: 3, type: "PLAYER OF THE SEASON",
                                       cardID: "mbappa-2223", careerID: "ui-hall-mbappa", value: 30),
            ]))

        // #2 — long-serving defender, clean sheets, favourited.
        profile.legendsHall.append(LegendsHallEntry(
            id: "ui-hall-maldinho", cardID: "maldinho-9596", playerName: "P. Maldinho",
            position: .centreBack, nation: "Italy", startingAge: 27, startingOverall: 91,
            highestOverall: 93, finalAge: 37, appearances: 380, goals: 21, assists: 12,
            cleanSheets: 146, seasonsAtClub: 10, signedSeason: 2, retiredSeason: 11,
            finalOverall: 88, trophies: 8,
            milestones: [.firstAppearance, .seventyAppearances, .hundredFortyAppearances,
                         .threeFiftyAppearances, .firstTrophy, .clubLegend],
            isClubLegend: true, legacyScore: 4719,
            careerHistory: [
                record(2, 2, age: 27, apps: 37, goals: 2, assists: 1, cleanSheets: 17, overallStart: 91, overallEnd: 92),
                record(3, 3, age: 28, apps: 38, goals: 3, assists: 2, cleanSheets: 19, overallStart: 92, overallEnd: 93),
            ],
            identityProfile: LegendsIdentityEngine.profile(for: LegendsCardDatabase.all.first { $0.id == "maldinho-9596" }!),
            honours: [
                LegendsHonour(id: "ui-hall-maldinho-h1", season: 2, competitionID: "division-1",
                              competitionName: "Legends Division 1", type: "CHAMPIONS",
                              clubName: profile.clubName, cardID: "maldinho-9596", careerID: "ui-hall-maldinho"),
            ]))
        profile.favouriteCardIDs.insert("maldinho-9596")

        // #3 — prolific forward without a legend crown.
        profile.legendsHall.append(LegendsHallEntry(
            id: "ui-hall-batigora", cardID: "batigora-9596", playerName: "G. Batigora",
            position: .striker, nation: "Argentina", startingAge: 26, startingOverall: 89,
            highestOverall: 91, finalAge: 33, appearances: 266, goals: 178, assists: 41,
            cleanSheets: 0, seasonsAtClub: 7, signedSeason: 4, retiredSeason: 10,
            finalOverall: 86, trophies: 5,
            milestones: [.firstAppearance, .firstGoal, .seventyAppearances, .hundredFortyAppearances,
                         .seventyGoals, .hundredFortyGoals, .firstTrophy],
            isClubLegend: false, legacyScore: 2988,
            careerHistory: [
                record(4, 4, age: 26, apps: 35, goals: 22, assists: 5, overallStart: 89, overallEnd: 90),
                record(5, 5, age: 27, apps: 38, goals: 28, assists: 7, overallStart: 90, overallEnd: 91),
            ],
            identityProfile: LegendsIdentityEngine.profile(for: LegendsCardDatabase.all.first { $0.id == "batigora-9596" }!)))

        // #4 — loyal midfielder, modest output, long service.
        profile.legendsHall.append(LegendsHallEntry(
            id: "ui-hall-cantina", cardID: "cantina-9596", playerName: "E. Cantina",
            position: .striker, nation: "France", startingAge: 29, startingOverall: 88,
            highestOverall: 89, finalAge: 36, appearances: 244, goals: 96, assists: 63,
            cleanSheets: 0, seasonsAtClub: 7, signedSeason: 3, retiredSeason: 9,
            finalOverall: 81, trophies: 4,
            milestones: [.firstAppearance, .firstGoal, .seventyAppearances, .hundredFortyAppearances,
                         .seventyGoals, .firstTrophy],
            isClubLegend: false, legacyScore: 1997,
            careerHistory: [
                record(3, 3, age: 29, apps: 33, goals: 12, assists: 8, overallStart: 88, overallEnd: 89),
                record(4, 4, age: 30, apps: 36, goals: 15, assists: 10, overallStart: 89, overallEnd: 89),
            ]))

        // #5 — short single-season cult hero, lowest legacy score.
        profile.legendsHall.append(LegendsHallEntry(
            id: "ui-hall-renaldo", cardID: "renaldo-0405", playerName: "C. Renaldo",
            position: .rightWing, nation: "Portugal", startingAge: 19, startingOverall: 82,
            highestOverall: 84, finalAge: 20, appearances: 34, goals: 7, assists: 11,
            cleanSheets: 0, seasonsAtClub: 1, signedSeason: 5, retiredSeason: 5,
            finalOverall: 84, trophies: 1,
            milestones: [.firstAppearance, .firstGoal, .firstTrophy],
            isClubLegend: false, legacyScore: 592,
            careerHistory: [
                record(5, 5, age: 19, apps: 34, goals: 7, assists: 11, overallStart: 82, overallEnd: 84),
            ]))

        persist()
    }

    /// Deterministic UI-test fixture for the redesigned Challenges screen:
    /// mixed progress and completion across all three cadences, including
    /// Balance-only, token-only and mixed-reward examples. Presentation
    /// only — no match results are recorded and no reward grants are run;
    /// the completed sets below are the authoritative persisted state.
    func prepareChallengesFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()

        // Completed permanent challenges. Rewards were already granted
        // through the real grant path in earlier sessions; the fixture
        // restores the resulting balances alongside the completed set.
        //   first-win  — Balance-only (£1,000,000)
        //   collector-10 — token-only (1 pack token)
        //   clean-sheet — mixed (£1,000,000 + 1 token)
        profile.completedPermanentChallengeIDs = ["first-win", "collector-10", "clean-sheet"]
        profile.completedDailyChallengeIDs = ["daily-match"]
        profile.completedWeeklyChallengeIDs = []

        // Counters that drive the deterministic progress bars:
        profile.totalWins = 6          // streak-3 bar: 2/3 toward its target
        profile.currentWinStreak = 1   // streak-5 bar: 1/5
        profile.matchesToday = 1       // daily-match: completed
        profile.winsToday = 0          // daily-win: 0/1
        profile.winsThisWeek = 1       // weekly-wins: 1/3
        profile.goalsThisWeek = 2      // weekly-goals: 2/5
        profile.lastDailyReset = Date()
        profile.lastWeeklyReset = Date()

        // The remembered cadence/filter tabs are presentation memory stored
        // in user defaults, deliberately outside the save. Clear them so
        // the fixture always presents the default Daily/ALL view, keeping
        // the UI test deterministic across repeated simulator runs.
        UserDefaults.standard.removeObject(forKey: "legends.challenges.cadence")
        UserDefaults.standard.removeObject(forKey: "legends.challenges.stateFilter")

        persist()
    }

    /// Deterministic UI-test fixture for the manager-editing flow: a
    /// returning manager with an established career (level, XP, match
    /// history, reputation, earned nicknames) and progression state the
    /// edit must preserve. DOB is 1980-01-01 so the manager is inside the
    /// valid 30–70 age window with room to move in either direction.
    ///
    /// Seeds once per app install: the edit UI test's relaunch leg must
    /// observe the edited identity loaded back from disk, not a re-seeded
    /// fixture. A UserDefaults marker (outside the save, wiped together
    /// with the container on reinstall) distinguishes a run's first launch
    /// from its relaunches, so the fixture stays deterministic even when
    /// unit tests have written a manager to the shared save beforehand.
    func prepareManagerEditFixtureForDebug() {
        let seededKey = "rsm.uitest.managerEditSeeded"
        guard UserDefaults.standard.bool(forKey: seededKey) == false else { return }
        UserDefaults.standard.set(true, forKey: seededKey)
        profile = .starter()
        var manager = LegendsManagerProfile(
            firstName: "Alex", surname: "Ferguson", nationalityCode: "Scotland",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        // Established career the edit must never touch.
        profile.managerLevel = 4
        profile.managerXP = 230
        manager.reputation = 44
        manager.careerStats.matches = 37
        manager.careerStats.wins = 21
        manager.careerStats.draws = 8
        manager.careerStats.losses = 8
        manager.careerStats.goalsScored = 63
        manager.careerStats.goalsConceded = 40
        manager.careerStats.promotions = 2
        manager.careerStats.trophies = 1
        manager.careerStats.packsOpened = 12
        manager.earnedNicknames = [.architect, .collector]
        manager.activeNickname = .architect
        profile.managerProfile = manager
        migrateOwnedPlayerRecords()
        persist()
    }

    #endif
}
