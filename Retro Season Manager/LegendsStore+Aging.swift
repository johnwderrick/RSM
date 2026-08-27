//
//  LegendsStore+Aging.swift
//  Retro Season Manager
//
//  Player lifecycle for RSM Legends. Owning a card is deliberately not the
//  same thing as starting a career: only a signed card gets a career record,
//  ages, develops, or can eventually retire into the Legends Hall.
//

import Foundation

/// One season of a signed career's statistics and OVR movement. Stored
/// permanently on the career and carried into the Legends Hall at
/// retirement so a player's story survives every season.
struct LegendsSeasonRecord: Codable, Hashable {
    let season: Int
    let age: Int
    let appearances: Int
    let goals: Int
    let assists: Int
    let cleanSheets: Int
    let overallAtStart: Int
    let overallAtEnd: Int
}

/// Named milestones a career can cross. Only the crossing season matters;
/// the exact counters live on the career itself.
enum LegendsCareerMilestone: String, Codable, Hashable, CaseIterable {
    case firstAppearance = "FIRST APPEARANCE"
    case firstGoal = "FIRST GOAL"
    // Appearance/goal landmarks are scaled for the 14-match season (x1.4
    // from the old 10-match seasons) so they land at the same season counts:
    // 70 = 5 seasons, 140 = 10, 350 = 25, 700 = 50; 280 goals = 20 seasons.
    case seventyAppearances = "70 APPEARANCES"
    case hundredFortyAppearances = "140 APPEARANCES"
    case threeFiftyAppearances = "350 APPEARANCES"
    case sevenHundredAppearances = "700 APPEARANCES"
    case seventyGoals = "70 GOALS"
    case hundredFortyGoals = "140 GOALS"
    case twoEightyGoals = "280 GOALS"
    case firstTrophy = "FIRST TROPHY"
    case clubLegend = "CLUB LEGEND"

    /// Maps a persisted raw value to a milestone, translating the old
    /// 10-match-season landmarks ("50 APPEARANCES" etc.) to their scaled
    /// equivalents so pre-14-match saves keep their earned badges.
    static func fromPersisted(_ raw: String) -> LegendsCareerMilestone? {
        switch raw {
        case "50 APPEARANCES": return .seventyAppearances
        case "100 APPEARANCES": return .hundredFortyAppearances
        case "250 APPEARANCES": return .threeFiftyAppearances
        case "500 APPEARANCES": return .sevenHundredAppearances
        case "50 GOALS": return .seventyGoals
        case "100 GOALS": return .hundredFortyGoals
        case "200 GOALS": return .twoEightyGoals
        default: return LegendsCareerMilestone(rawValue: raw)
        }
    }
}

/// A human-facing explanation of a season's OVR movement, shown after a
/// season completes so management decisions feel legible.
struct LegendsSeasonReviewEntry: Codable, Hashable {
    let cardID: String
    let playerName: String
    let position: DetailedPosition
    let overallDelta: Int
    let appearances: Int
    let starts: Int
    let reason: String
}

/// All-time club records. A record persists even after the player who set
/// it retires; `value` means different things per kind (appearances,
/// goals, ... or a player age for the youngest/oldest entries).
struct LegendsClubRecordEntry: Codable, Hashable {
    let playerName: String
    let value: Int
    let season: Int
}

enum LegendsClubRecordKind: String, Codable, Hashable, CaseIterable {
    case mostAppearances = "MOST APPEARANCES"
    case mostGoals = "MOST GOALS"
    case mostAssists = "MOST ASSISTS"
    case mostCleanSheets = "MOST CLEAN SHEETS"
    case highestOverall = "HIGHEST OVR"
    case youngestPlayer = "YOUNGEST PLAYER"
    case youngestGoalscorer = "YOUNGEST GOALSCORER"
    case oldestPlayer = "OLDEST PLAYER"
    case oldestGoalscorer = "OLDEST GOALSCORER"
    case longestServing = "LONGEST SERVING"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .mostAppearances: return "figure.run"
        case .mostGoals: return "soccerball"
        case .mostAssists: return "arrow.up.forward.circle.fill"
        case .mostCleanSheets: return "hand.raised.fill"
        case .highestOverall: return "star.fill"
        case .youngestPlayer, .youngestGoalscorer: return "figure.child"
        case .oldestPlayer, .oldestGoalscorer: return "figure.walk"
        case .longestServing: return "clock.fill"
        }
    }
}

/// Persisted state for one signed career. Potential and prime timings are
/// intentionally stored but never exposed as raw values in the UI.
struct LegendsPlayerCareer: Codable, Hashable {
    let careerID: String
    let cardID: String
    let startingAge: Int
    let startingOverall: Int
    let potential: Int
    let peakStartAge: Int
    let peakEndAge: Int
    let developmentRate: Int
    let declineRate: Int
    let signedSeason: Int
    var developmentProgress: Int
    var trainingSessions: Int
    var trainingSessionsThisSeason: Int
    var trainingSeason: Int
    var appearances: Int
    var goals: Int
    var assists: Int
    var cleanSheets: Int
    var highestOverall: Int
    var retirementAnnounced: Bool
    var announcementSeason: Int?
    /// Minutes and starts (one full match = 90 minutes, one start per
    /// appearance) feed both development and the season review.
    var minutesPlayed: Int
    var starts: Int
    /// The effective OVR at the start of the current season — captured
    /// when the season rolls so the end-of-season review can show a clean
    /// delta after aging/development ran.
    var seasonStartOverall: Int
    /// This season's development/decline flavour — see
    /// `LegendsDevelopmentEvent`. Recomputed every season from the card's
    /// stable seed so it never over-powers the underlying curve.
    var developmentMultiplier: Double
    var formBoost: Int
    var seasonAppearances: Int
    var seasonGoals: Int
    var seasonAssists: Int
    var seasonCleanSheets: Int
    var seasonRecords: [LegendsSeasonRecord]
    var milestones: Set<LegendsCareerMilestone>
    var isClubLegend: Bool
    /// Lifetime counters as of the start of the current season, so the
    /// season-end roll can attribute milestone crossings to the right
    /// season instead of comparing the roll snapshot against itself.
    var seasonStartAppearances: Int
    var seasonStartGoals: Int
    /// Stable lifecycle profile selected when the career begins. Optional
    /// decoding keeps older Legends saves compatible.
    var lifecycleProfile: LegendsCareerLifecyclePolicy.DevelopmentProfile
    /// Deterministic retirement target selected at signing.
    var intendedRetirementAge: Int

    init(careerID: String = UUID().uuidString, cardID: String, startingAge: Int,
         startingOverall: Int, potential: Int, peakStartAge: Int, peakEndAge: Int,
         developmentRate: Int, declineRate: Int, signedSeason: Int,
         developmentProgress: Int = 0, trainingSessions: Int = 0,
         trainingSessionsThisSeason: Int = 0, trainingSeason: Int = 1,
         appearances: Int = 0, goals: Int = 0, assists: Int = 0,
         cleanSheets: Int = 0, highestOverall: Int? = nil,
         retirementAnnounced: Bool = false, announcementSeason: Int? = nil,
         minutesPlayed: Int = 0, starts: Int = 0, seasonStartOverall: Int = 0,
         developmentMultiplier: Double = 1.0, formBoost: Int = 0,
         seasonAppearances: Int = 0, seasonGoals: Int = 0, seasonAssists: Int = 0,
         seasonCleanSheets: Int = 0, seasonRecords: [LegendsSeasonRecord] = [],
         milestones: Set<LegendsCareerMilestone> = [], isClubLegend: Bool = false,
         seasonStartAppearances: Int = 0, seasonStartGoals: Int = 0,
         lifecycleProfile: LegendsCareerLifecyclePolicy.DevelopmentProfile = .standardDeveloper,
         intendedRetirementAge: Int = 36) {
        self.careerID = careerID
        self.cardID = cardID
        self.startingAge = startingAge
        self.startingOverall = startingOverall
        self.potential = potential
        self.peakStartAge = peakStartAge
        self.peakEndAge = peakEndAge
        self.developmentRate = developmentRate
        self.declineRate = declineRate
        self.signedSeason = signedSeason
        self.developmentProgress = developmentProgress
        self.trainingSessions = trainingSessions
        self.trainingSessionsThisSeason = trainingSessionsThisSeason
        self.trainingSeason = trainingSeason
        self.appearances = appearances
        self.goals = goals
        self.assists = assists
        self.cleanSheets = cleanSheets
        self.highestOverall = highestOverall ?? startingOverall
        self.retirementAnnounced = retirementAnnounced
        self.announcementSeason = announcementSeason
        self.minutesPlayed = minutesPlayed
        self.starts = starts
        self.seasonStartOverall = seasonStartOverall
        self.developmentMultiplier = developmentMultiplier
        self.formBoost = formBoost
        self.seasonAppearances = seasonAppearances
        self.seasonGoals = seasonGoals
        self.seasonAssists = seasonAssists
        self.seasonCleanSheets = seasonCleanSheets
        self.seasonRecords = seasonRecords
        self.milestones = milestones
        self.isClubLegend = isClubLegend
        self.seasonStartAppearances = seasonStartAppearances
        self.seasonStartGoals = seasonStartGoals
        self.lifecycleProfile = lifecycleProfile
        self.intendedRetirementAge = intendedRetirementAge
    }

    private enum CodingKeys: String, CodingKey {
        case careerID, cardID, startingAge, startingOverall, potential, peakStartAge, peakEndAge
        case developmentRate, declineRate, signedSeason, developmentProgress, trainingSessions
        case trainingSessionsThisSeason, trainingSeason, appearances, goals, assists, cleanSheets
        case highestOverall, retirementAnnounced, announcementSeason, minutesPlayed, starts
        case seasonStartOverall, developmentMultiplier, formBoost, seasonAppearances, seasonGoals
        case seasonAssists, seasonCleanSheets, seasonRecords, milestones, isClubLegend
        case seasonStartAppearances, seasonStartGoals, lifecycleProfile, intendedRetirementAge
    }

    /// Lenient decode — every field added after the career record first
    /// shipped falls back to its default when missing, so profiles saved
    /// by older builds keep loading exactly like `LegendsProfile.init(from:)`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        careerID = try c.decodeIfPresent(String.self, forKey: .careerID) ?? UUID().uuidString
        cardID = try c.decodeIfPresent(String.self, forKey: .cardID) ?? ""
        startingAge = try c.decodeIfPresent(Int.self, forKey: .startingAge) ?? 18
        startingOverall = try c.decodeIfPresent(Int.self, forKey: .startingOverall) ?? 60
        potential = try c.decodeIfPresent(Int.self, forKey: .potential) ?? startingOverall
        peakStartAge = try c.decodeIfPresent(Int.self, forKey: .peakStartAge) ?? 27
        peakEndAge = try c.decodeIfPresent(Int.self, forKey: .peakEndAge) ?? 31
        developmentRate = try c.decodeIfPresent(Int.self, forKey: .developmentRate) ?? 5
        declineRate = try c.decodeIfPresent(Int.self, forKey: .declineRate) ?? 1
        signedSeason = try c.decodeIfPresent(Int.self, forKey: .signedSeason) ?? 1
        developmentProgress = try c.decodeIfPresent(Int.self, forKey: .developmentProgress) ?? 0
        trainingSessions = try c.decodeIfPresent(Int.self, forKey: .trainingSessions) ?? 0
        trainingSessionsThisSeason = try c.decodeIfPresent(Int.self, forKey: .trainingSessionsThisSeason) ?? 0
        trainingSeason = try c.decodeIfPresent(Int.self, forKey: .trainingSeason) ?? signedSeason
        appearances = try c.decodeIfPresent(Int.self, forKey: .appearances) ?? 0
        goals = try c.decodeIfPresent(Int.self, forKey: .goals) ?? 0
        assists = try c.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        cleanSheets = try c.decodeIfPresent(Int.self, forKey: .cleanSheets) ?? 0
        highestOverall = try c.decodeIfPresent(Int.self, forKey: .highestOverall) ?? startingOverall
        retirementAnnounced = try c.decodeIfPresent(Bool.self, forKey: .retirementAnnounced) ?? false
        announcementSeason = try c.decodeIfPresent(Int.self, forKey: .announcementSeason)
        minutesPlayed = try c.decodeIfPresent(Int.self, forKey: .minutesPlayed) ?? 0
        starts = try c.decodeIfPresent(Int.self, forKey: .starts) ?? 0
        seasonStartOverall = try c.decodeIfPresent(Int.self, forKey: .seasonStartOverall) ?? startingOverall
        developmentMultiplier = try c.decodeIfPresent(Double.self, forKey: .developmentMultiplier) ?? 1.0
        formBoost = try c.decodeIfPresent(Int.self, forKey: .formBoost) ?? 0
        seasonAppearances = try c.decodeIfPresent(Int.self, forKey: .seasonAppearances) ?? 0
        seasonGoals = try c.decodeIfPresent(Int.self, forKey: .seasonGoals) ?? 0
        seasonAssists = try c.decodeIfPresent(Int.self, forKey: .seasonAssists) ?? 0
        seasonCleanSheets = try c.decodeIfPresent(Int.self, forKey: .seasonCleanSheets) ?? 0
        seasonRecords = try c.decodeIfPresent([LegendsSeasonRecord].self, forKey: .seasonRecords) ?? []
        // Lenient: old saves store the pre-14-match landmark strings, which
        // are translated to their scaled equivalents rather than dropped.
        if let raw = try c.decodeIfPresent([String].self, forKey: .milestones) {
            milestones = Set(raw.compactMap { LegendsCareerMilestone.fromPersisted($0) })
        } else {
            milestones = []
        }
        isClubLegend = try c.decodeIfPresent(Bool.self, forKey: .isClubLegend) ?? false
        seasonStartAppearances = try c.decodeIfPresent(Int.self, forKey: .seasonStartAppearances) ?? 0
        seasonStartGoals = try c.decodeIfPresent(Int.self, forKey: .seasonStartGoals) ?? 0
        lifecycleProfile = try c.decodeIfPresent(LegendsCareerLifecyclePolicy.DevelopmentProfile.self, forKey: .lifecycleProfile) ?? .standardDeveloper
        intendedRetirementAge = try c.decodeIfPresent(Int.self, forKey: .intendedRetirementAge) ?? LegendsStore.retirementAge
    }
}

/// A permanent record of a completed career. The card can be packed again
/// later; the new pull starts a new `careerID` and gets a new story.
struct LegendsHallEntry: Codable, Hashable, Identifiable {
    let id: String
    let cardID: String
    let playerName: String
    let position: DetailedPosition
    let nation: String
    let startingAge: Int
    let startingOverall: Int
    let highestOverall: Int
    let finalAge: Int
    let appearances: Int
    let goals: Int
    let assists: Int
    let cleanSheets: Int
    let seasonsAtClub: Int
    let signedSeason: Int
    let retiredSeason: Int
    /// Phase 2 expansion — defaults keep older Hall entries decodable.
    let finalOverall: Int
    let trophies: Int
    let milestones: Set<LegendsCareerMilestone>
    let isClubLegend: Bool
    let legacyScore: Int
    let careerHistory: [LegendsSeasonRecord]

    init(id: String, cardID: String, playerName: String, position: DetailedPosition,
         nation: String, startingAge: Int, startingOverall: Int, highestOverall: Int,
         finalAge: Int, appearances: Int, goals: Int, assists: Int, cleanSheets: Int,
         seasonsAtClub: Int, signedSeason: Int, retiredSeason: Int,
         finalOverall: Int = 0, trophies: Int = 0,
         milestones: Set<LegendsCareerMilestone> = [], isClubLegend: Bool = false,
         legacyScore: Int = 0, careerHistory: [LegendsSeasonRecord] = []) {
        self.id = id
        self.cardID = cardID
        self.playerName = playerName
        self.position = position
        self.nation = nation
        self.startingAge = startingAge
        self.startingOverall = startingOverall
        self.highestOverall = highestOverall
        self.finalAge = finalAge
        self.appearances = appearances
        self.goals = goals
        self.assists = assists
        self.cleanSheets = cleanSheets
        self.seasonsAtClub = seasonsAtClub
        self.signedSeason = signedSeason
        self.retiredSeason = retiredSeason
        self.finalOverall = finalOverall
        self.trophies = trophies
        self.milestones = milestones
        self.isClubLegend = isClubLegend
        self.legacyScore = legacyScore
        self.careerHistory = careerHistory
    }

    /// Lenient decode: keeps pre-14-match saves loading (the old milestone
    /// landmark strings are translated to their scaled equivalents, and the
    /// Phase 2 fields default) instead of failing the whole hall array.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        cardID = try c.decodeIfPresent(String.self, forKey: .cardID) ?? ""
        playerName = try c.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        position = try c.decodeIfPresent(DetailedPosition.self, forKey: .position) ?? .goalkeeper
        nation = try c.decodeIfPresent(String.self, forKey: .nation) ?? ""
        startingAge = try c.decodeIfPresent(Int.self, forKey: .startingAge) ?? 0
        startingOverall = try c.decodeIfPresent(Int.self, forKey: .startingOverall) ?? 0
        highestOverall = try c.decodeIfPresent(Int.self, forKey: .highestOverall) ?? startingOverall
        finalAge = try c.decodeIfPresent(Int.self, forKey: .finalAge) ?? 0
        appearances = try c.decodeIfPresent(Int.self, forKey: .appearances) ?? 0
        goals = try c.decodeIfPresent(Int.self, forKey: .goals) ?? 0
        assists = try c.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        cleanSheets = try c.decodeIfPresent(Int.self, forKey: .cleanSheets) ?? 0
        seasonsAtClub = try c.decodeIfPresent(Int.self, forKey: .seasonsAtClub) ?? 0
        signedSeason = try c.decodeIfPresent(Int.self, forKey: .signedSeason) ?? 0
        retiredSeason = try c.decodeIfPresent(Int.self, forKey: .retiredSeason) ?? 0
        finalOverall = try c.decodeIfPresent(Int.self, forKey: .finalOverall) ?? 0
        trophies = try c.decodeIfPresent(Int.self, forKey: .trophies) ?? 0
        if let raw = try c.decodeIfPresent([String].self, forKey: .milestones) {
            milestones = Set(raw.compactMap { LegendsCareerMilestone.fromPersisted($0) })
        } else {
            milestones = []
        }
        isClubLegend = try c.decodeIfPresent(Bool.self, forKey: .isClubLegend) ?? false
        legacyScore = try c.decodeIfPresent(Int.self, forKey: .legacyScore) ?? 0
        careerHistory = try c.decodeIfPresent([LegendsSeasonRecord].self, forKey: .careerHistory) ?? []
    }
}

struct LegendsSeasonAdvanceResult {
    let newSeason: Int
    let retiredCards: [LegendsCard]
    let divisionResult: LegendsDivisionSeasonResult?
    let retirementAnnouncements: [LegendsCard]
    let retiredAges: [String: Int]
    let developmentReview: [String: LegendsSeasonReviewEntry]
    let newMilestones: [String: [LegendsCareerMilestone]]
    let newClubRecords: [LegendsClubRecordKind]

    init(newSeason: Int, retiredCards: [LegendsCard], divisionResult: LegendsDivisionSeasonResult? = nil,
         retirementAnnouncements: [LegendsCard] = [], retiredAges: [String: Int] = [:],
         developmentReview: [String: LegendsSeasonReviewEntry] = [:],
         newMilestones: [String: [LegendsCareerMilestone]] = [:],
         newClubRecords: [LegendsClubRecordKind] = []) {
        self.newSeason = newSeason
        self.retiredCards = retiredCards
        self.divisionResult = divisionResult
        self.retirementAnnouncements = retirementAnnouncements
        self.retiredAges = retiredAges
        self.developmentReview = developmentReview
        self.newMilestones = newMilestones
        self.newClubRecords = newClubRecords
    }
}

extension LegendsStore {
    static let agingExemptEras: Set<LegendsEra> = [.legends, .icons]
    /// No legacy-card penalty at or under this age when no career record
    /// exists (old saves and unsigned cards retain the previous rule).
    static let declineStartAge = 30
    static let declinePerYearOverPeak = 1
    /// Legacy fallback only for pre-profile records. New careers always
    /// receive their target from LegendsCareerLifecyclePolicy.
    static let retirementAge = 36
    static let maxTrainingSessionsPerSeason = 3

    /// Club Legend requires genuinely exceptional, long-lived achievement.
    /// Appearances scaled for the 14-match season (x1.4 from the old
    /// 10-match seasons) so the gate still lands at the same season count.
    static let clubLegendAppearances = 420
    static let clubLegendSeasons = 10

    /// The flavour label for this season's development/decline modifier —
    /// computed per season from the card's stable seed, so it stays
    /// deterministic and never permanently over-powers a career.
    enum LegendsDevelopmentEvent: String {
        case breakthrough = "BREAKTHROUGH SEASON"
        case lateBloomer = "LATE BLOOMER"
        case stalled = "STALLED DEVELOPMENT"
        case careerBest = "CAREER-BEST FORM"

        var multiplier: Double {
            switch self {
            case .breakthrough: return 1.5
            case .lateBloomer: return 1.3
            case .stalled: return 0.5
            case .careerBest: return 1.0
            }
        }
    }

    enum LegendsPlayerStatus: String {
        case prospect = "PROSPECT"
        case breakthrough = "BREAKTHROUGH PLAYER"
        case firstTeam = "FIRST-TEAM PLAYER"
        case keyPlayer = "KEY PLAYER"
        case star = "STAR PLAYER"
        case clubLegend = "CLUB LEGEND"
        case veteran = "VETERAN"

        var tint: (red: Double, green: Double, blue: Double) {
            switch self {
            case .prospect: return (0.071, 0.404, 0.910)
            case .breakthrough: return (0.020, 0.686, 0.812)
            case .firstTeam: return (0.259, 0.761, 0.102)
            case .keyPlayer: return (0.961, 0.541, 0.000)
            case .star: return (0.518, 0.169, 0.910)
            case .clubLegend: return (0.961, 0.722, 0.000)
            case .veteran: return (0.42, 0.44, 0.50)
            }
        }
    }

    /// A deterministic per-season development event. Events are relatively
    /// uncommon (≈15% of player-seasons) and only bend the season, they
    /// never rewrite the career's underlying curve.
    static func developmentEvent(for card: LegendsCard, season: Int, seed: Int = 0) -> LegendsDevelopmentEvent? {
        let roll = stableSeed("\(card.id)-\(season)-\(seed)") % 100
        let primeStart: Int
        switch card.position.broad {
        case .goalkeeper: primeStart = 29
        case .midfielder: primeStart = 27
        default: primeStart = 25
        }
        let age = card.age + max(0, season - 1)
        if age < primeStart, roll < 7 { return .breakthrough }
        if age > primeStart + 5, roll < 5 { return .lateBloomer }
        if age < 24, roll >= 93 { return .stalled }
        if age >= primeStart, roll < 4 { return .careerBest }
        return nil
    }

    /// A player's current career status — flavour and presentation only,
    /// no gameplay bonus, driven by ability, age, playing time and service.
    func playerStatus(for card: LegendsCard) -> LegendsPlayerStatus {
        guard let state = profile.playerCareers[card.id] else { return .prospect }
        if effectiveAge(for: card) == state.intendedRetirementAge - 1 { return .veteran }
        let age = effectiveAge(for: card)
        let overall = effectiveOverall(for: card)
        let seasons = profile.currentSeason - state.signedSeason
        if state.isClubLegend { return .clubLegend }
        if state.appearances >= Self.clubLegendAppearances, seasons >= Self.clubLegendSeasons,
           state.highestOverall >= 88 {
            return .clubLegend
        }
        if age >= Self.retirementAge - 2 { return .veteran }
        // Thresholds are scaled for the 14-match season (x1.4 from the old
        // 10-match seasons): 56 = 4 seasons, 35 = 2.5, 21 = 1.5, 7 = 0.5.
        if overall >= 90, state.appearances >= 56 { return .star }
        if overall >= 85, state.appearances >= 35 { return .keyPlayer }
        if state.appearances >= 21 { return .firstTeam }
        if state.appearances >= 7 { return .breakthrough }
        return .prospect
    }

    /// The hidden potential label (scouting description) for a signed card.
    func potentialLabel(for card: LegendsCard) -> String {
        guard let state = profile.playerCareers[card.id] else { return "FIRST-TEAM LEVEL" }
        switch state.potential - state.startingOverall {
        case 10...: return "GENERATIONAL TALENT"
        case 7...9: return "ELITE POTENTIAL"
        case 4...6: return "HIGH POTENTIAL"
        case 1...3: return "PROMISING"
        default: return "FIRST-TEAM LEVEL"
        }
    }

    /// A retired career's Legacy Score: appearances, output, service and
    /// achievements weighted into a single all-time number for the Hall.
    static func legacyScore(appearances: Int, goals: Int, assists: Int, cleanSheets: Int,
                            seasons: Int, peakOverall: Int, trophies: Int, isClubLegend: Bool) -> Int {
        var score = appearances * 2 + goals * 8 + assists * 6 + cleanSheets * 5
            + seasons * 15 + trophies * 40 + max(0, peakOverall - 70) * max(0, peakOverall - 70)
        if isClubLegend { score += 500 }
        return score
    }

    /// Estimated career trophies for a retired player — one per division
    /// season they were at the club (a division season always ends in a
    /// rank outcome), capped by their seasons of service.
    static func estimatedTrophies(seasonsAtClub: Int) -> Int {
        max(0, seasonsAtClub - 1)
    }

    /// Every milestone a career's lifetime totals have already reached.
    static func milestonesReached(appearances: Int, goals: Int) -> [LegendsCareerMilestone] {
        var reached: [LegendsCareerMilestone] = []
        if appearances >= 1 { reached.append(.firstAppearance) }
        if goals >= 1 { reached.append(.firstGoal) }
        // Scaled for the 14-match season (x1.4): 70 = 5 seasons, 140 = 10,
        // 350 = 25, 700 = 50; goal thresholds likewise (280 = 20 seasons).
        let appearanceThresholds: [(Int, LegendsCareerMilestone)] = [(70, .seventyAppearances), (140, .hundredFortyAppearances),
                                                                      (350, .threeFiftyAppearances), (700, .sevenHundredAppearances)]
        for (threshold, milestone) in appearanceThresholds where appearances >= threshold {
            reached.append(milestone)
        }
        let goalThresholds: [(Int, LegendsCareerMilestone)] = [(70, .seventyGoals), (140, .hundredFortyGoals), (280, .twoEightyGoals)]
        for (threshold, milestone) in goalThresholds where goals >= threshold {
            reached.append(milestone)
        }
        return reached
    }

    /// Checks every milestone threshold a career may just have crossed.
    /// `before`/`after` are the season-start and season-end snapshots, so
    /// the crossing season is attributed correctly.
    static func milestonesCrossed(before: LegendsPlayerCareer, after: LegendsPlayerCareer) -> [LegendsCareerMilestone] {
        var crossed: [LegendsCareerMilestone] = []
        if before.appearances < 1, after.appearances >= 1, !after.milestones.contains(.firstAppearance) {
            crossed.append(.firstAppearance)
        }
        if before.goals < 1, after.goals >= 1, !after.milestones.contains(.firstGoal) {
            crossed.append(.firstGoal)
        }
        // Scaled for the 14-match season (x1.4) — same season-count pacing.
        let appearanceThresholds: [(Int, LegendsCareerMilestone)] = [(70, .seventyAppearances), (140, .hundredFortyAppearances),
                                                                      (350, .threeFiftyAppearances), (700, .sevenHundredAppearances)]
        for (threshold, milestone) in appearanceThresholds where before.appearances < threshold && after.appearances >= threshold {
            crossed.append(milestone)
        }
        let goalThresholds: [(Int, LegendsCareerMilestone)] = [(70, .seventyGoals), (140, .hundredFortyGoals), (280, .twoEightyGoals)]
        for (threshold, milestone) in goalThresholds where before.goals < threshold && after.goals >= threshold {
            crossed.append(milestone)
        }
        return crossed
    }

    /// Adds career records for cards activated by an older save. This is a
    /// migration only; unsigned collection cards remain completely frozen.
    func migrateLegacyCareerStates() {
        let signedIDs = profile.activatedCardIDs
        for id in signedIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }) else { continue }
            if profile.playerCareers[id] == nil {
                profile.playerCareers[id] = Self.makeCareerState(for: card, signedSeason: profile.currentSeason)
            } else if var state = profile.playerCareers[id], state.intendedRetirementAge == LegendsStore.retirementAge {
                // Migration only: do not age or retire while decoding. An
                // already-old legacy career receives one final season grace.
                let generated = LegendsCareerLifecyclePolicy.retirementAge(for: card.id, position: card.position, profile: state.lifecycleProfile)
                state.intendedRetirementAge = max(generated, effectiveAge(for: card) + 1)
                profile.playerCareers[id] = state
            }
        }
    }

    private static func stableSeed(_ value: String) -> Int {
        abs(value.unicodeScalars.reduce(23) { ($0 * 31 + Int($1.value)) & 0x7fffffff })
    }

    static func makeCareerState(for card: LegendsCard, signedSeason: Int) -> LegendsPlayerCareer {
        let lifecycleProfile = LegendsCareerLifecyclePolicy.profile(for: card.id)
        let lifecyclePolicy = LegendsCareerLifecyclePolicy.configuration(for: lifecycleProfile)
        let seed = stableSeed(card.id)
        let gap: Int
        switch card.age {
        case ...20: gap = 10
        case 21...23: gap = 7
        case 24...27: gap = 3
        default: gap = 0
        }
        let potential = min(99, card.overall + gap)
        let primeBase: Int
        switch card.position.broad {
        case .goalkeeper: primeBase = 29
        case .midfielder: primeBase = 27
        default: primeBase = 25
        }
        let peakStart = max(18, primeBase + lifecyclePolicy.peakStartOffset + seed % 3)
        let peakLength = max(3, lifecyclePolicy.peakEndOffset - lifecyclePolicy.peakStartOffset)
        let rate = card.age <= 20 ? 10 : card.age <= 23 ? 8 : card.age <= 27 ? 5 : 2
        return LegendsPlayerCareer(cardID: card.id, startingAge: card.age,
                                   startingOverall: card.overall, potential: potential,
                                   peakStartAge: peakStart, peakEndAge: peakStart + peakLength,
                                   developmentRate: rate, declineRate: 1 + seed % 2,
                                   signedSeason: signedSeason, trainingSeason: signedSeason,
                                   seasonStartOverall: card.overall,
                                   lifecycleProfile: lifecycleProfile,
                                   intendedRetirementAge: LegendsCareerLifecyclePolicy.retirementAge(for: card.id, position: card.position, profile: lifecycleProfile))
    }

    func careerState(for card: LegendsCard) -> LegendsPlayerCareer? {
        profile.playerCareers[card.id]
    }

    func isCareerStarted(_ card: LegendsCard) -> Bool {
        profile.activatedCardIDs.contains(card.id) || profile.playerCareers[card.id] != nil
    }

    /// Starts a career exactly once. Reassigning a signed player after they
    /// leave the XI does not reset their age, potential, or statistics.
    func startCareerIfNeeded(for card: LegendsCard) {
        guard profile.playerCareers[card.id] == nil else { return }
        var state = Self.makeCareerState(for: card, signedSeason: profile.currentSeason)
        // Baseline the season review from the OVR the player actually has
        // at signing (upgrades included), not the raw card rating.
        state.seasonStartOverall = effectiveOverall(for: card)
        profile.playerCareers[card.id] = state
    }

    /// A hidden-potential scouting label: the exact number stays internal.
    func potentialDescription(for card: LegendsCard) -> String {
        let potential = profile.playerCareers[card.id]?.potential
            ?? Self.makeCareerState(for: card, signedSeason: profile.currentSeason).potential
        switch potential - card.overall {
        case 10...: return "GENERATIONAL TALENT"
        case 7...9: return "ELITE POTENTIAL"
        case 4...6: return "HIGH POTENTIAL"
        case 1...3: return "PROMISING"
        default: return "FIRST-TEAM LEVEL"
        }
    }

    func developmentBonus(for card: LegendsCard) -> Int {
        guard profile.activatedCardIDs.contains(card.id),
              let state = profile.playerCareers[card.id] else { return 0 }
        return min(max(0, state.potential - card.overall), max(0, state.developmentProgress / 100))
    }

    /// Trains a signed player up to three times per aging season. Training
    /// is intentionally a modest accelerator, not an infinite OVR button.
    @discardableResult
    func trainPlayer(_ cardID: String) -> Bool {
        guard profile.activatedCardIDs.contains(cardID),
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
              !isRetired(card),
              var state = profile.playerCareers[cardID] else { return false }
        if state.trainingSeason != profile.currentSeason {
            state.trainingSeason = profile.currentSeason
            state.trainingSessionsThisSeason = 0
        }
        guard state.trainingSessionsThisSeason < Self.maxTrainingSessionsPerSeason else { return false }
        let age = effectiveAge(for: card)
        let ageFactor = age < state.peakStartAge ? 2 : age <= state.peakEndAge ? 1 : 0
        guard ageFactor > 0, state.potential > card.overall else { return false }
        state.trainingSessionsThisSeason += 1
        state.trainingSessions += 1
        state.developmentProgress += Int((Double(state.developmentRate * ageFactor * 2) * state.developmentMultiplier).rounded())
        profile.playerCareers[cardID] = state
        persist()
        return true
    }

    /// A card's age including every season it's aged since signing.
    /// The single source of truth for a card instance's active-career age.
    /// `cardAgeOffsets` is keyed by the stable card-instance ID; the static
    /// database age is never mutated.
    func currentAge(for cardID: String) -> Int? {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { return nil }
        return card.age + (profile.cardAgeOffsets[cardID] ?? 0)
    }

    func currentAge(for card: LegendsCard) -> Int {
        currentAge(for: card.id) ?? card.age
    }

    func effectiveAge(for card: LegendsCard) -> Int {
        currentAge(for: card.id) ?? card.age
    }

    /// OVR lost to age alone (before the duplicate-upgrade cap in
    /// `effectiveOverall(for:)` is applied). Signed careers decline only
    /// once they pass their own `peakEndAge`, at their individual
    /// `declineRate` — and regular first-team minutes soften that decline,
    /// so an experienced starter fades gradually instead of falling off a
    /// cliff. Cards without a career record (unsigned collection cards and
    /// legacy saves) keep the original generic boundary. Exempt eras never
    /// decline.
    func agingPenalty(for card: LegendsCard) -> Int {
        guard !Self.agingExemptEras.contains(card.era) else { return 0 }
        let age = effectiveAge(for: card)
        if let state = profile.playerCareers[card.id] {
            let yearsPastPeak = age - state.peakEndAge
            guard yearsPastPeak > 0 else { return 0 }
            let rate = state.seasonAppearances >= 15 ? max(1, state.declineRate - 1) : state.declineRate
            return yearsPastPeak * rate
        }
        return max(0, (age - Self.declineStartAge) * Self.declinePerYearOverPeak)
    }

    /// The temporary career-best form OVR lift, applied only for the
    /// season the event is active.
    func formBoost(for card: LegendsCard) -> Int {
        profile.playerCareers[card.id]?.formBoost ?? 0
    }

    /// A player's current season development event, or nil when their
    /// season is ordinary.
    func developmentEvent(for card: LegendsCard) -> LegendsDevelopmentEvent? {
        guard let state = profile.playerCareers[card.id] else { return nil }
        let season = profile.currentSeason
        return Self.developmentEvent(for: card, season: season, seed: Self.stableSeed(state.careerID))
    }

    func isRetired(_ card: LegendsCard) -> Bool {
        guard !Self.agingExemptEras.contains(card.era) else { return false }
        return effectiveAge(for: card) >= (profile.playerCareers[card.id]?.intendedRetirementAge ?? Self.retirementAge)
    }

    func isFinalSeason(_ card: LegendsCard) -> Bool {
        guard profile.activatedCardIDs.contains(card.id),
              let state = profile.playerCareers[card.id] else { return false }
        let age = currentAge(for: card.id) ?? card.age
        return age < state.intendedRetirementAge && age == state.intendedRetirementAge - 1
    }

    func recordCareerMatch(_ result: LegendsMatchEngine.Result) {
        let xiIDs = profile.startingXICardIDs.compactMap { $0 }
        guard !xiIDs.isEmpty else { return }
        for id in xiIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }) else { continue }
            startCareerIfNeeded(for: card)
            guard var state = profile.playerCareers[id] else { continue }
            state.appearances += 1
            state.starts += 1
            state.minutesPlayed += 90
            state.seasonAppearances += 1
            let wasCleanSheet = result.opponentGoals == 0
            if wasCleanSheet && card.position.broad == .goalkeeper {
                state.cleanSheets += 1
                state.seasonCleanSheets += 1
            }
            let age = effectiveAge(for: card)
            if age < state.peakStartAge {
                let performanceBoost = result.outcome == .win ? 2 : result.outcome == .draw ? 1 : 0
                state.developmentProgress += Int((Double(state.developmentRate + performanceBoost) * state.developmentMultiplier).rounded())
            }
            // Store the updated state before asking effectiveOverall for
            // the new peak; otherwise the final progress point would lag
            // one appearance behind the Hall record.
            profile.playerCareers[id] = state
            state.highestOverall = max(state.highestOverall, effectiveOverall(for: card))
            profile.playerCareers[id] = state
        }

        let attackers = xiIDs.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            .filter { $0.position.broad == .forward }
        let scorers = attackers.isEmpty ? xiIDs.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } } : attackers
        for goalIndex in 0..<max(0, result.teamGoals) {
            guard let scorer = scorers[safe: goalIndex], var state = profile.playerCareers[scorer.id] else { continue }
            state.goals += 1
            state.seasonGoals += 1
            profile.playerCareers[scorer.id] = state
            if let assister = xiIDs.compactMap({ id in LegendsCardDatabase.all.first { $0.id == id } })
                .first(where: { $0.id != scorer.id && ($0.position.broad == .midfielder || $0.position.broad == .forward) }),
               var assistState = profile.playerCareers[assister.id] {
                assistState.assists += 1
                assistState.seasonAssists += 1
                profile.playerCareers[assister.id] = assistState
            }
        }
    }

    private func archiveRetiredCareer(card: LegendsCard, state: LegendsPlayerCareer, finalAge: Int) {
        guard !profile.legendsHall.contains(where: { $0.id == state.careerID }) else { return }
        let seasons = max(1, profile.currentSeason - state.signedSeason)
        let peak = max(state.highestOverall, effectiveOverall(for: card))
        let trophies = Self.estimatedTrophies(seasonsAtClub: seasons)
        let legend = state.isClubLegend
            || (state.appearances >= Self.clubLegendAppearances && seasons >= Self.clubLegendSeasons && peak >= 88)
        let score = Self.legacyScore(appearances: state.appearances, goals: state.goals, assists: state.assists,
                                     cleanSheets: state.cleanSheets, seasons: seasons, peakOverall: peak,
                                     trophies: trophies, isClubLegend: legend)
        profile.legendsHall.append(LegendsHallEntry(id: state.careerID, cardID: card.id,
                                                     playerName: card.name, position: card.position,
                                                     nation: card.nation, startingAge: state.startingAge,
                                                     startingOverall: state.startingOverall,
                                                     highestOverall: peak,
                                                     finalAge: finalAge, appearances: state.appearances,
                                                     goals: state.goals, assists: state.assists,
                                                     cleanSheets: state.cleanSheets,
                                                     seasonsAtClub: seasons,
                                                     signedSeason: state.signedSeason,
                                                     retiredSeason: profile.currentSeason,
                                                     finalOverall: effectiveOverall(for: card),
                                                     trophies: trophies, milestones: state.milestones,
                                                     isClubLegend: legend, legacyScore: score,
                                                     careerHistory: state.seasonRecords))
    }

    /// Call once per completed match. Only active/signed careers age; an
    /// unsigned collection card never receives an offset or development.
    @discardableResult
    func advanceSeasonIfNeeded(divisionResult: LegendsDivisionSeasonResult? = nil) -> LegendsSeasonAdvanceResult? {
        profile.matchesPlayedThisSeason += 1
        guard profile.matchesPlayedThisSeason >= Self.matchesPerSeason else {
            persist()
            return nil
        }
        profile.matchesPlayedThisSeason = 0
        let finishingSeason = profile.currentSeason
        profile.currentSeason += 1

        let activeIDs = profile.activatedCardIDs
            .union((profile.startingXICardIDs + profile.benchCardIDs).compactMap { $0 })

        // Prepare every active career for the season about to begin: fresh
        // development flavour and the age increment. The season-start
        // baseline (counters and OVR) is NOT captured here — it was set at
        // the end of the previous roll (or at signing), so this roll's
        // milestone/review comparisons measure the season that just ran.
        for id in activeIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }),
                  !Self.agingExemptEras.contains(card.era) else { continue }
            startCareerIfNeeded(for: card)
            if var state = profile.playerCareers[id] {
                state.developmentMultiplier = Self.developmentEvent(for: card, season: finishingSeason, seed: Self.stableSeed(state.careerID))?.multiplier ?? 1.0
                state.formBoost = Self.developmentEvent(for: card, season: finishingSeason, seed: Self.stableSeed(state.careerID)) == .careerBest ? 1 : 0
                profile.playerCareers[id] = state
            }
            // Age is evaluated from the pre-rollover state below. Only
            // active players receive the next-season age after the outcome
            // has been selected; retiring players are never left active at T.
        }

        var retiredCards: [LegendsCard] = []
        var retirementAnnouncements: [LegendsCard] = []
        var retiredAges: [String: Int] = [:]
        var newClubRecords: [LegendsClubRecordKind] = []
        var newMilestones: [String: [LegendsCareerMilestone]] = [:]
        var developmentReview: [String: LegendsSeasonReviewEntry] = [:]

        for id in activeIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }),
                  var state = profile.playerCareers[id] else { continue }
            let currentAge = effectiveAge(for: card)
            let nextAge = currentAge + 1
            let targetAge = state.intendedRetirementAge
            let nextAgeForCard = nextAge
            let shouldRetireAtBoundary = nextAgeForCard >= targetAge
            guard shouldRetireAtBoundary else {
                profile.cardAgeOffsets[id] = (profile.cardAgeOffsets[id] ?? 0) + 1
                if nextAgeForCard == targetAge - 1 && !state.retirementAnnounced {
                    state.retirementAnnounced = true
                    state.announcementSeason = profile.currentSeason
                    retirementAnnouncements.append(card)
                }
                profile.playerCareers[id] = state
                continue
            }
            // `nextAge` is the retirement age. The final-season player was
            // evaluated at currentAge T-1 above; archive the completed
            // season now without leaving an active T-aged copy behind.
            profile.cardAgeOffsets[id] = max(0, targetAge - card.age)
            archiveRetiredCareer(card: card, state: state, finalAge: targetAge)
            profile.playerCareers.removeValue(forKey: id)
            markRetired(cardID: id)
            profile.activatedCardIDs.remove(id)
            profile.ownedCardIDs.remove(id)
            // A later pull is a new generation, so duplicate progress and
            // OVR upgrades belong to the completed career and must not leak
            // into the fresh card.
            profile.duplicateProgress.removeValue(forKey: id)
            profile.cardUpgrades.removeValue(forKey: id)
            profile.cardAgeOffsets.removeValue(forKey: id)
            for index in profile.startingXICardIDs.indices where profile.startingXICardIDs[index] == id {
                profile.startingXICardIDs[index] = nil
            }
            for index in profile.benchCardIDs.indices where profile.benchCardIDs[index] == id {
                profile.benchCardIDs[index] = nil
            }
            if profile.captainCardID == id { profile.captainCardID = nil }
            retiredCards.append(card)
            retiredAges[id] = nextAgeForCard
        }

        // Second pass over the survivors: finalise season records, status,
        // milestones, club records and the development review.
        for id in activeIDs {
            guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }),
                  var state = profile.playerCareers[id] else { continue }
            let age = effectiveAge(for: card)
            let endOverall = effectiveOverall(for: card)

            // Close out the season's statistics into the permanent history.
            state.seasonRecords.append(LegendsSeasonRecord(season: finishingSeason, age: age - 1,
                                                           appearances: state.seasonAppearances,
                                                           goals: state.seasonGoals, assists: state.seasonAssists,
                                                           cleanSheets: state.seasonCleanSheets,
                                                           overallAtStart: state.seasonStartOverall,
                                                           overallAtEnd: endOverall))

            // Milestones crossed this season — first appearance/goal and
            // round-number career thresholds, compared against the
            // season-start counters captured when this season began.
            var start = state
            start.appearances = state.seasonStartAppearances
            start.goals = state.seasonStartGoals
            var crossed = Self.milestonesCrossed(before: start, after: state)
            if divisionResult != nil, !state.milestones.contains(.firstTrophy) {
                crossed.append(.firstTrophy)
            }
            for milestone in crossed {
                state.milestones.insert(milestone)
            }
            if !crossed.isEmpty {
                newMilestones[id] = crossed
            }

            // Club Legend is earned mid-career (after the final season's
            // stats are known), not just at retirement.
            let seasons = profile.currentSeason - state.signedSeason
            if !state.isClubLegend,
               state.appearances >= Self.clubLegendAppearances, seasons >= Self.clubLegendSeasons,
               state.highestOverall >= 88 {
                state.isClubLegend = true
                state.milestones.insert(.clubLegend)
                newMilestones[id, default: []].append(.clubLegend)
            }

            // Development review entry. The season-start OVR was captured
            // when the season began (before this season's matches), so the
            // delta is the season's real development — not just the aging
            // boundary the roll itself would otherwise measure.
            let delta = endOverall - state.seasonStartOverall
                let stageReason = (age - 1) == state.intendedRetirementAge - 1 ? "Entered Final Season" : nil
            let review = LegendsSeasonReviewEntry(cardID: id, playerName: card.name, position: card.position,
                                                  overallDelta: delta, appearances: state.seasonAppearances,
                                                  starts: state.seasonAppearances,
                                                  reason: stageReason ?? Self.reviewReason(for: card, state: state, delta: delta, seasonAppearances: state.seasonAppearances))
            developmentReview[id] = review

            // Club records.
            newClubRecords.append(contentsOf: recordClubPerformance(for: card, state: state, age: age))

            // Reset the per-season counters and capture the baseline the
            // NEXT roll compares against — the OVR and lifetime counters as
            // they stand at the start of the new season.
            state.seasonStartOverall = endOverall
            state.seasonStartAppearances = state.appearances
            state.seasonStartGoals = state.goals
            state.seasonAppearances = 0
            state.seasonGoals = 0
            state.seasonAssists = 0
            state.seasonCleanSheets = 0
            profile.playerCareers[id] = state
        }

        profile.lastSeasonReview = developmentReview
        let reportEntries = developmentReview.values.map { entry in
            let card = LegendsCardDatabase.all.first { $0.id == entry.cardID }
            let career = profile.playerCareers[entry.cardID]
            let afterAge = card.map { effectiveAge(for: $0) } ?? entry.overallDelta
            let beforeAge = max(0, afterAge - 1)
            let afterOverall = card.map { effectiveOverall(for: $0) } ?? entry.overallDelta
            let beforeOverall = afterOverall - entry.overallDelta
            return LegendsSeasonReportEntry(cardID: entry.cardID, playerName: entry.playerName,
                                            completedSeason: finishingSeason, ageBefore: beforeAge,
                                            ageAfter: afterAge, overallBefore: beforeOverall,
                                            overallAfter: afterOverall, previousStage: "ACTIVE",
                                            newStage: entry.reason, developmentProfile: career?.lifecycleProfile ?? .standardDeveloper,
                                            improved: entry.overallDelta > 0, stable: entry.overallDelta == 0,
                                            declined: entry.overallDelta < 0, enteredFinalSeason: entry.reason.contains("Final Season"),
                                            retired: false, retirementRecordID: nil, position: entry.position,
                                            favourite: profile.favouriteCardIDs.contains(entry.cardID))
        }
        let plan = squadCareerPlan()
        profile.seasonReports[finishingSeason] = LegendsSeasonDevelopmentReport(season: finishingSeason, entries: reportEntries,
                                                                                  squadAgeWarning: plan.warning,
                                                                                  positionsNeedingReplacements: plan.positionsNeedingReplacements,
                                                                                  signedAverageAgeAfter: plan.signedAverageAge)
        persist()
        return LegendsSeasonAdvanceResult(newSeason: profile.currentSeason, retiredCards: retiredCards,
                                          divisionResult: divisionResult,
                                          retirementAnnouncements: retirementAnnouncements,
                                          retiredAges: retiredAges,
                                          developmentReview: developmentReview,
                                          newMilestones: newMilestones,
                                          newClubRecords: Array(Set(newClubRecords)))
    }

    /// A short, legible explanation for a season's OVR movement — the
    /// "why" behind a +3 or −2 on the development review. Thresholds match
    /// a Legends season's actual match count (`matchesPerSeason`), not a
    /// real-world 38-game campaign.
    static func reviewReason(for card: LegendsCard, state: LegendsPlayerCareer, delta: Int, seasonAppearances: Int) -> String {
        let age = card.age + max(0, state.seasonRecords.count)
        var reasons: [String] = []
        if seasonAppearances >= 8 { reasons.append("Regular starter") }
        else if seasonAppearances >= 5 { reasons.append("Rotation minutes") }
        else if seasonAppearances > 0 { reasons.append("Limited minutes") }
        else { reasons.append("No first-team football") }
        if age < 21 { reasons.append("Young and developing") }
        if state.potential - state.startingOverall >= 7 { reasons.append("High development potential") }
        if age >= state.peakEndAge { reasons.append("Past peak years") }
        if delta == 0 { reasons.append("Career curve steady") }
        return reasons.joined(separator: " · ")
    }

    /// Checks one active career against the all-time club records and
    /// returns the kinds broken this season.
    private func recordClubPerformance(for card: LegendsCard, state: LegendsPlayerCareer, age: Int) -> [LegendsClubRecordKind] {
        var broken: [LegendsClubRecordKind] = []
        let entries = [
            (LegendsClubRecordKind.mostAppearances, state.appearances),
            (LegendsClubRecordKind.mostGoals, state.goals),
            (LegendsClubRecordKind.mostAssists, state.assists),
            (LegendsClubRecordKind.mostCleanSheets, state.cleanSheets),
            (LegendsClubRecordKind.oldestPlayer, age),
            (LegendsClubRecordKind.longestServing, profile.currentSeason - state.signedSeason)
        ]
        for (kind, value) in entries where value > (profile.clubRecords[kind]?.value ?? -1) {
            profile.clubRecords[kind] = LegendsClubRecordEntry(playerName: card.name, value: value, season: profile.currentSeason)
            broken.append(kind)
        }
        let peak = max(state.highestOverall, effectiveOverall(for: card))
        if peak > (profile.clubRecords[.highestOverall]?.value ?? -1) {
            profile.clubRecords[.highestOverall] = LegendsClubRecordEntry(playerName: card.name, value: peak, season: profile.currentSeason)
            broken.append(.highestOverall)
        }
        if let youngest = profile.clubRecords[.youngestPlayer], state.startingAge < youngest.value {
            profile.clubRecords[.youngestPlayer] = LegendsClubRecordEntry(playerName: card.name, value: state.startingAge, season: profile.currentSeason)
            broken.append(.youngestPlayer)
        } else if profile.clubRecords[.youngestPlayer] == nil {
            profile.clubRecords[.youngestPlayer] = LegendsClubRecordEntry(playerName: card.name, value: state.startingAge, season: profile.currentSeason)
            broken.append(.youngestPlayer)
        }
        if state.goals > 0 {
            if let youngestScorer = profile.clubRecords[.youngestGoalscorer], age < youngestScorer.value {
                profile.clubRecords[.youngestGoalscorer] = LegendsClubRecordEntry(playerName: card.name, value: age, season: profile.currentSeason)
                broken.append(.youngestGoalscorer)
            } else if profile.clubRecords[.youngestGoalscorer] == nil {
                profile.clubRecords[.youngestGoalscorer] = LegendsClubRecordEntry(playerName: card.name, value: age, season: profile.currentSeason)
                broken.append(.youngestGoalscorer)
            }
        }
        if state.goals > 0, age > (profile.clubRecords[.oldestGoalscorer]?.value ?? -1) {
            profile.clubRecords[.oldestGoalscorer] = LegendsClubRecordEntry(playerName: card.name, value: age, season: profile.currentSeason)
            broken.append(.oldestGoalscorer)
        }
        return broken
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
