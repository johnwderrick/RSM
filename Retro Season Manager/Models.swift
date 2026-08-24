//
//  Models.swift
//  Retro Season Manager
//
//  Core data models for the football manager game.
//

import Foundation

/// The playing position of a footballer.
enum Position: String, CaseIterable, Codable {
    case goalkeeper = "GK"
    case defender   = "DEF"
    case midfielder = "MID"
    case forward    = "FWD"

    /// Sort order used when listing a squad, back to front.
    var order: Int {
        switch self {
        case .goalkeeper: return 0
        case .defender:   return 1
        case .midfielder: return 2
        case .forward:    return 3
        }
    }
}

/// A specific on-pitch role — more granular than the broad `Position`
/// bucket, e.g. distinguishing a centre-back from a left-back.
enum DetailedPosition: String, CaseIterable, Codable {
    case goalkeeper  = "GK"
    case centreBack  = "CB"
    case leftBack    = "LB"
    case rightBack   = "RB"
    case holding     = "CDM"
    case centralMid  = "CM"
    case attackingMid = "CAM"
    case leftWing    = "LW"
    case rightWing   = "RW"
    case leftMid     = "LM"
    case rightMid    = "RM"
    case striker     = "ST"

    /// The broad bucket this detailed role belongs to. Wingers count as
    /// midfielders (as on a traditional squad sheet), not forwards.
    var broad: Position {
        switch self {
        case .goalkeeper: return .goalkeeper
        case .centreBack, .leftBack, .rightBack: return .defender
        case .holding, .centralMid, .attackingMid, .leftWing, .rightWing, .leftMid, .rightMid: return .midfielder
        case .striker: return .forward
        }
    }

    /// The full display name, e.g. for the player profile screen.
    var fullName: String {
        switch self {
        case .goalkeeper: return "Goalkeeper"
        case .centreBack: return "Centre-Back"
        case .leftBack: return "Left-Back"
        case .rightBack: return "Right-Back"
        case .holding: return "Defensive Midfielder"
        case .centralMid: return "Central Midfielder"
        case .attackingMid: return "Attacking Midfielder"
        case .leftWing: return "Left Winger"
        case .rightWing: return "Right Winger"
        case .leftMid: return "Left Midfielder"
        case .rightMid: return "Right Midfielder"
        case .striker: return "Striker"
        }
    }

    /// Roles this one is naturally comfortable deputising in even without
    /// an explicit secondary tag — the opposite flank, or an adjacent
    /// central-midfield role. A real fullback or winger usually has some
    /// ability on the other side; a real CM usually has some game managing
    /// either a bit deeper (CDM) or a bit higher (CAM).
    var relatedRoles: [DetailedPosition] {
        switch self {
        case .leftBack:  return [.rightBack]
        case .rightBack: return [.leftBack]
        case .leftWing:  return [.rightWing, .leftMid]
        case .rightWing: return [.leftWing, .rightMid]
        case .leftMid:   return [.rightMid, .leftWing]
        case .rightMid:  return [.leftMid, .rightWing]
        case .centralMid:  return [.holding, .attackingMid]
        case .holding:     return [.centralMid]
        case .attackingMid: return [.centralMid]
        default: return []
        }
    }

    /// The detailed roles plausible within a broad position bucket, used
    /// when generating a player without an explicit detailed role.
    static func plausibleRoles(for broad: Position) -> [DetailedPosition] {
        switch broad {
        case .goalkeeper: return [.goalkeeper]
        case .defender:   return [.centreBack, .leftBack, .rightBack]
        case .midfielder: return [.holding, .centralMid, .attackingMid, .leftWing, .rightWing, .leftMid, .rightMid]
        case .forward:    return [.striker]
        }
    }

    /// The detailed role a formation expects at a given slot — wide vs
    /// central, holding vs attacking — used both to label the pitch and to
    /// prefer well-fitted players when picking a starting XI. Index 0 is
    /// treated as the left side, the last index as the right. `wideIsWinger`
    /// distinguishes a genuine front-three shape (advanced wingers either
    /// side of a lone striker, e.g. 4-3-3) from a flat, defensively-minded
    /// bank of midfielders either side of the middle (e.g. 4-4-2's LM/RM) —
    /// same slot geometry, different real-football role.
    static func expected(for position: Position, indexInRow index: Int, rowCount count: Int, wideIsWinger: Bool = false) -> DetailedPosition {
        switch position {
        case .goalkeeper:
            return .goalkeeper
        case .defender:
            if count >= 4 && index == 0 { return .leftBack }
            if count >= 4 && index == count - 1 { return .rightBack }
            return .centreBack
        case .midfielder:
            if count == 1 { return .holding }
            if count >= 4 && index == 0 { return wideIsWinger ? .leftWing : .leftMid }
            if count >= 4 && index == count - 1 { return wideIsWinger ? .rightWing : .rightMid }
            return .centralMid
        case .forward:
            // Wingers count as midfielders, so every forward-row slot — wide
            // or central — is filled by a striker.
            return .striker
        }
    }
}

/// A quick "how comfortable is this player here" read, derived from
/// `Player.fit(for:)` — the traffic light shown across the pitch, squad
/// list and position pickers. Colour mapping lives in the UI layer.
enum PositionFitLevel {
    case confident, okay, poor

    var label: String {
        switch self {
        case .confident: return "Confident"
        case .okay:       return "Okay"
        case .poor:       return "Poor fit"
        }
    }
}

/// A fixed physical trait set when a player is generated — some players
/// are just more prone to picking up knocks than others, independent of
/// age or ability.
enum Durability: String, Codable, CaseIterable {
    case robust, normal, fragile

    var label: String {
        switch self {
        case .robust:  return "Robust"
        case .normal:  return "Normal"
        case .fragile: return "Fragile"
        }
    }

    /// How much more (or less) likely this player is to be the one an
    /// injury roll picks out, relative to a normal player.
    var injuryChanceMultiplier: Double {
        switch self {
        case .robust:  return 0.6
        case .normal:  return 1.0
        case .fragile: return 1.7
        }
    }

    /// How much longer (or shorter) their injuries tend to run.
    var injuryDurationMultiplier: Double {
        switch self {
        case .robust:  return 0.8
        case .normal:  return 1.0
        case .fragile: return 1.4
        }
    }
}

/// A fixed character trait set when the player is created — colours
/// contract negotiations and how sharply their mood swings with results.
enum Personality: String, Codable, CaseIterable {
    case ambitious, loyal, professional, volatile

    var label: String {
        switch self {
        case .ambitious:    return "Ambitious"
        case .loyal:        return "Loyal"
        case .professional: return "Professional"
        case .volatile:     return "Volatile"
        }
    }

    /// A flat adjustment to the chance a renewal offer is accepted —
    /// loyal players are easier to keep happy, ambitious ones want more.
    var renewalChanceAdjustment: Double {
        switch self {
        case .loyal:     return 0.10
        case .ambitious: return -0.08
        default:         return 0.0
        }
    }

    /// How sharply this player's morale reacts to results and news —
    /// volatile swings hard either way, professional stays level.
    var moraleSwingMultiplier: Double {
        switch self {
        case .volatile:     return 1.6
        case .professional: return 0.65
        default:            return 1.0
        }
    }
}

/// How hard a club is to do transfer business with — a distinct trait
/// from `ManagerPersonality` (which drives an AI manager's own buying
/// habits): this one governs how the club's board responds when it's on
/// the other side of the table from the user, in `proposeBid` and
/// `counterSellOffer`.
enum ClubNegotiationStance: String, Codable, CaseIterable {
    case difficult, flexible, desperate, protective, balanced

    /// >1 = harder to please (tighter thresholds, smaller concessions);
    /// <1 = easier. Applied by multiplying when the club is selling
    /// (needs relatively more to say yes) and dividing when it's buying
    /// (won't stretch as far above value to say yes).
    var hardnessMultiplier: Double {
        switch self {
        case .difficult:  return 1.25
        case .flexible:   return 0.8
        case .desperate:  return 0.65
        case .protective: return 1.15
        case .balanced:   return 1.0
        }
    }

    /// Extra resistance specifically for a genuine star (rating ≥ 80) —
    /// only a protective board treats its best players differently.
    func starPlayerHardness(rating: Int) -> Double {
        self == .protective && rating >= 80 ? 1.25 : 1.0
    }

    var displayLabel: String {
        switch self {
        case .difficult:  return "Difficult negotiator"
        case .flexible:   return "Flexible negotiator"
        case .desperate:  return "Financially stretched"
        case .protective: return "Protective of their best players"
        case .balanced:   return "Balanced negotiator"
        }
    }
}

/// Hidden numeric personality values, 0...100 each, never shown directly
/// in the UI — a richer, more granular layer on top of the `Personality`
/// archetype above. Higher is always "more of the named quality" in a
/// positive sense: a 90 temperament is composed, not explosive; a 90
/// pressure is ice-cool in a big match. Expressed only through how a
/// player trains, develops, handles moves, swings in morale, suits the
/// captaincy, times their retirement, and comes across in the press —
/// see the various `GameStore` extensions that read these fields.
struct PlayerTraits: Codable {
    var professionalism: Int
    var leadership: Int
    var temperament: Int
    var loyalty: Int
    var ambition: Int
    var pressure: Int
    var consistency: Int
    var workEthic: Int

    static let neutral = PlayerTraits(professionalism: 50, leadership: 50, temperament: 50, loyalty: 50,
                                       ambition: 50, pressure: 50, consistency: 50, workEthic: 50)
}

/// A player's standing in the pecking order — driven by ability and
/// whether they're actually starting, not stored on the player directly
/// so it always reflects the squad's current shape. Flavours contract
/// talks: a genuine star knows his worth and negotiates like it, while a
/// fringe player or academy prospect is a much easier conversation.
enum SquadRole: String, CaseIterable {
    case starPlayer = "Star Player"
    case firstTeamRegular = "First-Team Regular"
    case rotation = "Rotation Option"
    case backup = "Backup"
    case youthProspect = "Youth Prospect"

    /// Replaces the old flat 1.15x renewal markup — a star pushes hard for
    /// more, a fringe or academy player settles for less and just wants
    /// game time.
    var wageDemandMultiplier: Double {
        switch self {
        case .starPlayer:        return 1.30
        case .firstTeamRegular:  return 1.15
        case .rotation:          return 1.05
        case .backup:            return 0.95
        case .youthProspect:     return 0.85
        }
    }

    var short: String {
        switch self {
        case .starPlayer:       return "Star"
        case .firstTeamRegular: return "Regular"
        case .rotation:         return "Rotation"
        case .backup:           return "Backup"
        case .youthProspect:    return "Youth"
        }
    }
}

/// A single footballer on a club's roster.
struct Player: Identifiable, Codable {
    var id = UUID()
    let name: String
    let position: Position
    /// The player's specific natural role (more granular than `position`).
    var detailedPosition: DetailedPosition = .centreBack
    /// Other detailed roles the player can competently deputise in.
    var secondaryPositions: [DetailedPosition] = []
    var age: Int
    /// Overall ability rating, roughly 40...94.
    var rating: Int
    /// League goals scored this season.
    var goals: Int = 0
    /// Weeks remaining on an injury. Zero means fully fit.
    var injuryWeeks: Int = 0
    /// Matches remaining on a suspension (e.g. after a red card).
    var suspensionMatches: Int = 0
    /// Match fitness / condition, 0...100. Drops after playing, recovers on rest days.
    var fitness: Int = 100

    // Career / management details.
    /// Transfer value in thousands of pounds.
    var value: Int = 0
    /// Weekly wage in thousands of pounds.
    var wage: Int = 0
    /// Morale, 0...100.
    var morale: Int = 70
    /// Appearances this season (for the average match rating).
    var apps: Int = 0
    /// Sum of match ratings this season.
    var ratingPoints: Double = 0
    /// Whether the manager has listed this player for sale.
    var isTransferListed: Bool = false
    /// Seasons remaining on the player's contract.
    var contractYears: Int = 3
    /// The parent club's index if the player is on loan, else nil.
    var onLoanFromClubIndex: Int? = nil
    /// Whether the player has asked to leave (e.g. lack of game time).
    var wantsToLeave: Bool = false
    /// The detailed role currently being trained toward, if any.
    var retrainingRole: DetailedPosition? = nil
    /// Days of training left before `retrainingRole` becomes a secondary
    /// position. Zero/nil `retrainingRole` means no retraining in progress.
    var retrainingDaysRemaining: Int = 0
    /// A fixed physical trait set when the player is created — how often
    /// (and how badly) they pick up injuries.
    var durability: Durability = .normal
    /// A fixed character trait set when the player is created — colours
    /// contract negotiations and how sharply their mood swings.
    var personality: Personality = .professional
    var traits: PlayerTraits = .neutral
    /// A release-clause figure agreed at the last renewal, in £000s. Any
    /// bid a rival makes for this player is set at least this high.
    var releaseClause: Int? = nil
    /// A sell-on cut owed to the club that last sold this player, agreed
    /// as part of that transfer's terms — paid out automatically the next
    /// time this player is sold on.
    var sellOnClause: SellOnClause? = nil
    /// A fixed-fee buy-back right retained by the club that sold this
    /// player, agreed as part of that transfer's terms — if it undercuts
    /// market value, they get first refusal at that price when he's next sold.
    var buyBackClause: BuyBackClause? = nil
    /// Injuries picked up this season — a run of knocks temporarily makes
    /// a player more injury-prone on top of their fixed `durability`,
    /// resets to zero at season rollover.
    var injuriesThisSeason: Int = 0
    /// League assists this season — resets alongside `goals`/`apps` at
    /// season rollover. Attributed by the live match engine on non-penalty
    /// goals.
    var assists: Int = 0
    /// Clean sheets kept this season while on the pitch as goalkeeper —
    /// resets alongside `goals`/`apps` at season rollover.
    var cleanSheets: Int = 0
    /// The player's nation, for the profile screen and Hall of Fame — a
    /// flavour detail set at generation time, not tied to any gameplay
    /// mechanic.
    var nationality: String = "England"
    /// Whether this player came through the club's own academy — set once,
    /// at youth-prospect generation, and never cleared, so a graduate's
    /// provenance survives long after they're promoted to the senior squad.
    var isAcademyProduct: Bool = false

    /// Detailed 1...20 attributes, keyed by name.
    var attributes: [String: Int] = [:]
    /// The player's preferred foot.
    var foot: String = "Right"
    /// Match ratings from recent games, for the form guide (newest last).
    var recentRatings: [Double] = []

    /// Whether the player is currently on loan from another club.
    var isOnLoan: Bool { onLoanFromClubIndex != nil }

    /// How well this player fits a detailed role: 2 = natural, 1 = can
    /// deputise there, 0 = same broad line but not a role they play,
    /// -1 = a different broad position entirely (e.g. a defender at CAM).
    func fit(for role: DetailedPosition) -> Int {
        if role == detailedPosition { return 2 }
        if secondaryPositions.contains(role) { return 1 }
        if detailedPosition.relatedRoles.contains(role) { return 1 }
        if role.broad == position { return 0 }
        return -1
    }

    /// A simple traffic-light read on `fit`, for the UI: green for a
    /// natural role, amber for a competent deputy, red for anything else —
    /// including a wrong broad position entirely (e.g. a striker in goal).
    func fitLevel(for role: DetailedPosition) -> PositionFitLevel {
        switch fit(for: role) {
        case 2:  return .confident
        case 1:  return .okay
        default: return .poor
        }
    }

    /// This player's ability at a specific detailed role — the base rating,
    /// reduced the further the role is from their natural position.
    func effectiveRating(for role: DetailedPosition) -> Int {
        switch fit(for: role) {
        case 2:  return rating
        case 1:  return max(1, rating - 8)
        case 0:  return max(1, rating - 20)
        default: return max(1, rating - 35)
        }
    }

    /// A short read on match fitness, for the squad screen.
    var fitnessLabel: String {
        switch fitness {
        case 90...:   return "Sharp"
        case 75..<90: return "Fit"
        case 55..<75: return "Tiring"
        default:      return "Jaded"
        }
    }

    /// A 1...5 star rating derived from overall ability.
    var stars: Int {
        switch rating {
        case 86...: return 5
        case 78..<86: return 4
        case 68..<78: return 3
        case 58..<68: return 2
        default: return 1
        }
    }

    /// The recent form guide as rounded rating integers, e.g. [7,6,8].
    var formGuide: [Int] { recentRatings.map { Int($0.rounded()) } }

    /// The ordered attribute names for this player's position.
    var attributeOrder: [String] {
        position == .goalkeeper ? Player.goalkeeperAttributes : Player.outfieldAttributes
    }

    static let outfieldAttributes = [
        "Pace", "Shooting", "Passing", "Dribbling",
        "Defending", "Physical", "Vision", "Positioning",
    ]
    static let goalkeeperAttributes = [
        "Handling", "Reflexes", "Aerial", "Kicking",
        "Command", "Agility", "Positioning", "Communication",
    ]

    /// Whether the player is currently unavailable through injury.
    var isInjured: Bool { injuryWeeks > 0 }
    /// Whether the player is currently serving a suspension.
    var isSuspended: Bool { suspensionMatches > 0 }
    /// Whether the player can be selected for the next match.
    var isAvailable: Bool { !isInjured && !isSuspended }

    /// The average match rating this season, or nil if yet to play.
    var averageRating: Double? { apps > 0 ? ratingPoints / Double(apps) : nil }

    /// A short word describing current morale.
    var moraleLabel: String {
        switch morale {
        case 80...:   return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Okay"
        case 20..<40: return "Poor"
        default:      return "Very poor"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, position, detailedPosition, secondaryPositions, age, rating, goals, injuryWeeks, suspensionMatches
        case fitness, value, wage, morale, apps, ratingPoints, isTransferListed
        case contractYears, onLoanFromClubIndex, wantsToLeave
        case attributes, foot, recentRatings
        case retrainingRole, retrainingDaysRemaining, durability, releaseClause, injuriesThisSeason, personality
        case sellOnClause, buyBackClause
        case assists, cleanSheets, nationality
        case traits
        case isAcademyProduct
    }
}

/// A sell-on percentage owed to a player's previous club, agreed when he
/// was bought from them — paid out of the fee the next time he's sold.
struct SellOnClause: Codable, Equatable {
    var club: String
    var percentage: Int
}

/// A fixed-fee buy-back right retained by a player's previous club,
/// agreed when he was bought from them.
struct BuyBackClause: Codable, Equatable {
    var club: String
    var fee: Int
}

extension Player {
    /// A lenient decoder: `detailedPosition`, `secondaryPositions` and
    /// `fitness` were added to this struct after `CodingKeys` was first
    /// written, so older save files never wrote them. Falling back to a
    /// sensible default instead of a hard decode failure means an old save
    /// still loads instead of erroring out — the values just regenerate
    /// from `position` where genuinely missing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        position = try container.decode(Position.self, forKey: .position)
        detailedPosition = try container.decodeIfPresent(DetailedPosition.self, forKey: .detailedPosition)
            ?? DetailedPosition.plausibleRoles(for: position).randomElement() ?? .centreBack
        secondaryPositions = try container.decodeIfPresent([DetailedPosition].self, forKey: .secondaryPositions) ?? []
        age = try container.decode(Int.self, forKey: .age)
        rating = try container.decode(Int.self, forKey: .rating)
        goals = try container.decodeIfPresent(Int.self, forKey: .goals) ?? 0
        injuryWeeks = try container.decodeIfPresent(Int.self, forKey: .injuryWeeks) ?? 0
        suspensionMatches = try container.decodeIfPresent(Int.self, forKey: .suspensionMatches) ?? 0
        fitness = try container.decodeIfPresent(Int.self, forKey: .fitness) ?? 100
        value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 0
        wage = try container.decodeIfPresent(Int.self, forKey: .wage) ?? 0
        morale = try container.decodeIfPresent(Int.self, forKey: .morale) ?? 70
        apps = try container.decodeIfPresent(Int.self, forKey: .apps) ?? 0
        ratingPoints = try container.decodeIfPresent(Double.self, forKey: .ratingPoints) ?? 0
        isTransferListed = try container.decodeIfPresent(Bool.self, forKey: .isTransferListed) ?? false
        contractYears = try container.decodeIfPresent(Int.self, forKey: .contractYears) ?? 3
        onLoanFromClubIndex = try container.decodeIfPresent(Int.self, forKey: .onLoanFromClubIndex)
        wantsToLeave = try container.decodeIfPresent(Bool.self, forKey: .wantsToLeave) ?? false
        attributes = try container.decodeIfPresent([String: Int].self, forKey: .attributes) ?? [:]
        foot = try container.decodeIfPresent(String.self, forKey: .foot) ?? "Right"
        recentRatings = try container.decodeIfPresent([Double].self, forKey: .recentRatings) ?? []
        retrainingRole = try container.decodeIfPresent(DetailedPosition.self, forKey: .retrainingRole)
        retrainingDaysRemaining = try container.decodeIfPresent(Int.self, forKey: .retrainingDaysRemaining) ?? 0
        durability = try container.decodeIfPresent(Durability.self, forKey: .durability) ?? .normal
        releaseClause = try container.decodeIfPresent(Int.self, forKey: .releaseClause)
        injuriesThisSeason = try container.decodeIfPresent(Int.self, forKey: .injuriesThisSeason) ?? 0
        personality = try container.decodeIfPresent(Personality.self, forKey: .personality) ?? .professional
        traits = try container.decodeIfPresent(PlayerTraits.self, forKey: .traits) ?? .neutral
        sellOnClause = try container.decodeIfPresent(SellOnClause.self, forKey: .sellOnClause)
        buyBackClause = try container.decodeIfPresent(BuyBackClause.self, forKey: .buyBackClause)
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        cleanSheets = try container.decodeIfPresent(Int.self, forKey: .cleanSheets) ?? 0
        nationality = try container.decodeIfPresent(String.self, forKey: .nationality) ?? "England"
        isAcademyProduct = try container.decodeIfPresent(Bool.self, forKey: .isAcademyProduct) ?? false
    }
}

/// Builds a plausible 1...20 attribute set for a player from their overall
/// rating and position (stronger where their role demands it).
func makeAttributes(position: Position, rating: Int) -> [String: Int] {
    let base = Double(rating - 40) / 3.4 + 2.5   // ~2.5 (40 OVR) → ~18 (94 OVR)
    // Per-attribute emphasis by position.
    let emphasis: [String: Double]
    switch position {
    case .goalkeeper:
        emphasis = ["Handling": 3, "Reflexes": 3, "Aerial": 2, "Command": 1,
                    "Kicking": 0, "Agility": 1, "Positioning": 2, "Communication": 1]
    case .defender:
        emphasis = ["Defending": 3, "Physical": 2, "Positioning": 2, "Pace": 1,
                    "Passing": 0, "Vision": -1, "Shooting": -3, "Dribbling": -2]
    case .midfielder:
        emphasis = ["Passing": 3, "Vision": 2, "Dribbling": 1, "Physical": 1,
                    "Defending": 0, "Shooting": 0, "Pace": 0, "Positioning": 1]
    case .forward:
        emphasis = ["Shooting": 3, "Pace": 2, "Dribbling": 2, "Positioning": 1,
                    "Physical": 0, "Passing": 0, "Vision": 1, "Defending": -3]
    }
    let names = position == .goalkeeper ? Player.goalkeeperAttributes : Player.outfieldAttributes
    var result: [String: Int] = [:]
    for name in names {
        let value = base + (emphasis[name] ?? 0) + Double(Int.random(in: -2...2))
        result[name] = min(20, max(1, Int(value.rounded())))
    }
    return result
}

/// A single-leg knockout tie in the domestic cup. A "bye" is a tie where
/// homeIndex == awayIndex.
struct CupTie: Identifiable, Codable {
    var id = UUID()
    let round: Int
    let homeIndex: Int
    let awayIndex: Int
    var played = false
    var homeGoals = 0
    var awayGoals = 0
    var winnerIndex = -1
    /// True when the winner needed a penalty shootout.
    var onPenalties = false

    var isBye: Bool { homeIndex == awayIndex }
}

/// The game difficulty, affecting your team's edge and the board's patience.
enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"

    var id: String { rawValue }

    /// A multiplier on the user's team strength in live matches.
    var userStrengthMultiplier: Double {
        switch self {
        case .easy:   return 1.12
        case .normal: return 1.0
        case .hard:   return 0.90
        }
    }

    /// How harshly the board reacts to defeats.
    var boardLossHarshness: Double {
        switch self {
        case .easy:   return 0.6
        case .normal: return 1.0
        case .hard:   return 1.6
        }
    }
}

/// The weekly training emphasis for the squad.
enum TrainingFocus: String, CaseIterable, Identifiable, Codable {
    case balanced = "Balanced"
    case attacking = "Attacking"
    case defending = "Defending"
    case technical = "Technical"
    case physical = "Physical"

    var id: String { rawValue }

    /// Attributes this focus develops (empty = any).
    var preferred: [String] {
        switch self {
        case .balanced:  return []
        case .attacking: return ["Shooting", "Pace", "Dribbling", "Positioning"]
        case .defending: return ["Defending", "Positioning", "Physical", "Aerial"]
        case .technical: return ["Passing", "Vision", "Dribbling", "Handling"]
        case .physical:  return ["Physical", "Pace", "Reflexes", "Agility"]
        }
    }
}

/// A summary of one completed season, for the history book.
/// One line of the season's finance ledger — every transfer-budget
/// change the manager can attribute to something specific, in order.
struct LedgerEntry: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let category: String
    /// In £000s. Positive is income, negative is expenditure.
    let amount: Int
    let detail: String
}

/// One line of a permanent, career-long transfer history — every
/// signing, sale and loan move involving the user's club, unlike the
/// finance ledger which resets each season.
struct TransferHistoryEntry: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let playerName: String
    /// e.g. "Signed", "Sold", "Loaned out", "Loan in", "Released".
    let action: String
    /// The other club involved, if any (free-agent signings have none).
    let otherClub: String?
    /// In £000s, where relevant — nil for loans/releases.
    let fee: Int?
}

struct SeasonRecord: Identifiable, Codable {
    var id = UUID()
    let season: Int
    let label: String
    let userClub: String
    let userDivision: String
    let userPosition: Int
    let champion: String
    let cupWinner: String
    let euroWinner: String
    let communityShieldWinner: String
}

/// A manager's cumulative match record at one club, across every stint —
/// the raw material for the manager CV screen's win percentage.
struct ClubCareerRecord: Codable {
    var wins = 0
    var draws = 0
    var losses = 0
    var homeWins = 0
    var homeDraws = 0
    var homeLosses = 0
    var awayWins = 0
    var awayDraws = 0
    var awayLosses = 0
    var matches: Int { wins + draws + losses }
    var winPercentage: Int { matches > 0 ? Int((Double(wins) / Double(matches) * 100).rounded()) : 0 }
    var homeMatches: Int { homeWins + homeDraws + homeLosses }
    var awayMatches: Int { awayWins + awayDraws + awayLosses }
}

/// A lenient decoder so old saves (predating the home/away split) load
/// fine, defaulting the new counters to zero instead of hard-failing.
extension ClubCareerRecord {
    private enum CodingKeys: String, CodingKey {
        case wins, draws, losses, homeWins, homeDraws, homeLosses, awayWins, awayDraws, awayLosses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        draws = try c.decodeIfPresent(Int.self, forKey: .draws) ?? 0
        losses = try c.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        homeWins = try c.decodeIfPresent(Int.self, forKey: .homeWins) ?? 0
        homeDraws = try c.decodeIfPresent(Int.self, forKey: .homeDraws) ?? 0
        homeLosses = try c.decodeIfPresent(Int.self, forKey: .homeLosses) ?? 0
        awayWins = try c.decodeIfPresent(Int.self, forKey: .awayWins) ?? 0
        awayDraws = try c.decodeIfPresent(Int.self, forKey: .awayDraws) ?? 0
        awayLosses = try c.decodeIfPresent(Int.self, forKey: .awayLosses) ?? 0
    }
}

/// A press-conference response option and its effects.
struct PressOption: Identifiable {
    var id = UUID()
    let label: String
    let response: String
    let moraleDelta: Int
    let confidenceDelta: Int
}

/// A press-conference question put to the manager before a match.
struct PressQuestion: Identifiable {
    var id = UUID()
    let prompt: String
    let options: [PressOption]
}

/// A player's peak spell while managed by the user, for the Hall of Fame.
struct HallEntry: Identifiable, Codable {
    var id = UUID()
    let name: String
    let position: Position
    let peakRating: Int
    let peakSeason: String
}

/// A player permanently inducted into a club's Hall of Fame at retirement —
/// judged on real career data accumulated while playing under the user's
/// management (appearances, goals, assists, clean sheets, average rating,
/// captaincy, loyalty, trophies, individual awards), not a fabricated
/// record. See `GameStore+CareerHistory.swift`'s `evaluateForLegendStatus`
/// for the induction criteria.
struct ClubLegend: Identifiable, Codable {
    var id = UUID()
    let playerID: UUID
    let name: String
    let position: Position
    let nationality: String
    let clubName: String
    let joinedSeason: Int
    let retiredSeason: Int
    let finalAge: Int
    let appearances: Int
    let goals: Int
    let assists: Int
    let cleanSheets: Int
    let averageRating: Double
    let seasonsAsCaptain: Int
    let trophiesWon: [String]
    let individualAwards: Int
    let peakRating: Int
    let legendScore: Int
    let isGlobalLegend: Bool
    let biography: String

    var yearsAtClub: Int { max(1, retiredSeason - joinedSeason + 1) }
}

/// The user's own managerial career, evaluated the same way a Club Legend
/// is — computed fresh from `history`/`careerHonours`/`careerRecordByClub`
/// each time rather than stored, since it can always be re-derived and
/// should reflect the career's current state, not a snapshot.
struct LegendaryManagerProfile {
    let totalSeasons: Int
    let totalTrophies: Int
    let totalWins: Int
    let totalMatches: Int
    let winPercentage: Int
    let clubsManaged: Int
    let longestSpell: (club: String, seasons: Int)?
    let reputation: Int
    let legendScore: Int
    let isLegendary: Bool
    let biography: String
}

/// A hidden behavioural profile for an AI-controlled manager — never shown
/// directly in the UI, but expressed through how their club buys and sells,
/// sets up tactically, uses its bench, develops youth, renews contracts and
/// fares in the wider managerial job market. Keeps AI-vs-AI careers from
/// ever playing out identically twice.
enum ManagerPersonality: String, Codable, CaseIterable {
    case aggressive, defensive, youthDeveloper, bigSpender, moneySaver
    case cupSpecialist, pressFriendly, loyal, journeyman

    static func random() -> ManagerPersonality { allCases.randomElement()! }
}

/// The tone of a generated fan reaction — drives which colour/glyph a
/// `SocialPost` renders with.
enum SocialSentiment: String, Codable {
    case hype, outrage, banter, concern, pride
}

/// A short, punchy social-media-style reaction to a club event — never
/// literal in-fiction dialogue, just flavour that makes the fanbase feel
/// like a living crowd instead of a single confidence number.
struct SocialPost: Identifiable, Codable {
    var id = UUID()
    let handle: String
    let text: String
    let date: Date
    let likeCount: Int
    let sentiment: SocialSentiment
}

/// A job offer from a rival club at the end of a season.
struct JobOffer: Identifiable, Codable {
    var id = UUID()
    let clubIndex: Int
    let clubName: String
    let divisionName: String
    let prestige: Int
    let transferBudget: Int
    let expectedObjective: String
}

/// A scout's assessment of a transfer target.
struct ScoutReport {
    /// The assessed player, kept alongside the report so it still reads
    /// sensibly in a reports list even after the target leaves the
    /// transfer market (sold elsewhere, window closed).
    let playerID: UUID
    let playerName: String
    /// Estimated ceiling of the player's ability.
    let potential: Int
    /// One-line recommendation.
    let verdict: String
    /// A short note on the player's profile.
    let note: String
    /// A value range rather than a single figure — how wide it is (and
    /// how confident the report is) depends on the scouting network's
    /// level, not a hidden exact number handed straight to the manager.
    let valueRangeLow: Int
    let valueRangeHigh: Int
    /// 0...100 — how much to trust the range above.
    let confidence: Int
}

/// A rough multiplier for how much bigger transfer fees, wages and club
/// budgets are for a given career start year — loosely tracking how
/// football's finances actually grew through the 2000s and 2010s, not a
/// precise economic model. 2000 stays the unscaled baseline (and how
/// every pre-existing save's economy already behaves). Extend this as
/// further start years are added.
func economyMultiplier(startYear: Int) -> Double {
    switch startYear {
    case ..<2005:     return 1.0
    case 2005..<2010: return 1.4
    case 2010..<2015: return 2.0
    case 2015..<2020: return 2.8
    default:          return 3.6
    }
}

/// The transfer value of a player (in £000s), from ability and age.
/// Baseline calibrated to year-2000 transfer fees — a world-class player
/// tops out in the low tens of millions, not hundreds — then scaled up by
/// `economyMultiplier` for a later career start.
func playerValue(rating: Int, age: Int, startYear: Int = 2000) -> Int {
    let base = pow(Double(rating) / 50.0, 8.0) * 180.0
    let ageFactor: Double
    switch age {
    case ..<20:    ageFactor = 1.05
    case 20...26:  ageFactor = 1.0
    case 27...29:  ageFactor = 0.85
    case 30...32:  ageFactor = 0.6
    case 33...35:  ageFactor = 0.35
    default:       ageFactor = 0.18
    }
    return max(20, Int(base * ageFactor * economyMultiplier(startYear: startYear)))
}

/// The weekly wage of a player (in £000s), from ability.
/// Baseline calibrated to year-2000 wages — the very best players earn low
/// tens of thousands per week, not six figures — then scaled by
/// `economyMultiplier` for a later career start.
func playerWage(rating: Int, age: Int, startYear: Int = 2000) -> Int {
    let base = Double(Int(pow(Double(max(rating - 52, 0)), 2)) / 34)
    return max(1, Int(base * economyMultiplier(startYear: startYear)))
}

/// Formats an amount given in thousands of pounds, e.g. 51000 -> "£51.0M", -5000 -> "-£5.0M".
func formatMoney(_ thousands: Int) -> String {
    let sign = thousands < 0 ? "-" : ""
    let magnitude = abs(thousands)
    if magnitude >= 1000 {
        return String(format: "\(sign)£%.1fM", Double(magnitude) / 1000.0)
    }
    return "\(sign)£\(magnitude)K"
}

/// A player listed on the transfer market, with an asking price.
struct TransferTarget: Identifiable {
    let id = UUID()
    let player: Player
    /// The selling club's index, or nil for a free agent.
    let sellingClubIndex: Int?
    /// Asking price in thousands of pounds.
    let askingPrice: Int
}

/// A transfer where a fee has been agreed with the selling club but
/// personal terms with the player haven't been settled yet. Real transfers
/// go through a medical and personal-terms negotiation before anything's
/// final, so agreeing a fee doesn't complete the move on the spot — the
/// player sits in limbo (out of every squad) until terms are agreed or the
/// deal is walked away from, at which point he returns to the seller.
struct PendingTransferDeal: Identifiable, Codable {
    let id: UUID
    var player: Player
    var sellingClubIndex: Int
    var sellingClubName: String
    var agreedFee: Int
    var sellOnPercentage: Int
    var buyBackFee: Int
    var includedPlayerID: UUID?
    var includedPlayerName: String?
    var readyDate: Date
    var isReady: Bool = false
}

/// A bid from a rival club for one of the user's players.
struct TransferOffer: Identifiable {
    let id = UUID()
    let playerID: UUID
    let playerName: String
    let fromClubIndex: Int
    /// Bid amount in thousands of pounds — a `var` since a counteroffer
    /// revises it in place rather than replacing the whole offer (which
    /// would mint a new `id` and break UI/expiry tracking).
    var amount: Int
    let expiryDate: Date
}

/// The kind of news feed item.
enum NewsCategory: Codable {
    case result, transfer, offer, injury, board, info, world

    var glyph: String {
        switch self {
        case .result:   return "⚽︎"
        case .transfer: return "⇄"
        case .offer:    return "£"
        case .injury:   return "＋"
        case .board:    return "▣"
        case .info:     return "ⓘ"
        case .world:    return "🌍"
        }
    }

    /// Who the item reads as being "from", for an inbox feel.
    var sender: String {
        switch self {
        case .result:   return "Sports Desk"
        case .transfer: return "Transfer Desk"
        case .offer:    return "Transfer Desk"
        case .injury:   return "Club Medical"
        case .board:    return "The Board"
        case .info:     return "Club Secretary"
        case .world:    return "Football News Wire"
        }
    }

    /// The inbox folder this category files under.
    var folder: InboxFolder {
        switch self {
        case .result:                return .results
        case .transfer, .offer:      return .transfers
        case .board:                 return .board
        case .injury, .info:         return .club
        case .world:                 return .world
        }
    }
}

/// The folders an inbox groups news into.
enum InboxFolder: String, CaseIterable, Identifiable {
    case all = "All"
    case results = "Results"
    case transfers = "Transfers"
    case board = "Board"
    case club = "Club"
    case world = "World"

    var id: String { rawValue }
}

/// A single dated item in the news / inbox feed. The player/club fields are
/// a snapshot at the moment the story ran — deliberately not a live lookup,
/// so a story about someone since sold or retired still reads correctly.
struct NewsItem: Identifiable {
    let id = UUID()
    let date: Date
    let category: NewsCategory
    let title: String
    let body: String
    var playerName: String? = nil
    var playerRating: Int? = nil
    var playerPosition: Position? = nil
    var playerAge: Int? = nil
    var clubName: String? = nil
    /// Links this inbox item to its generated front page in `GameStore.newspapers`,
    /// when the underlying story was judged newspaper-worthy — see `GameStore+Newspaper.swift`.
    var newspaperID: UUID? = nil
}

/// Which kind of outlet ran a story — drives both the masthead styling and
/// the flavour of headline a story gets (a local human-interest piece reads
/// very differently to a national splash on the same event).
enum NewspaperOutlet: String, Codable, CaseIterable {
    case local, national, european, magazine

    var editionLabel: String {
        switch self {
        case .local:     return "LOCAL EDITION"
        case .national:  return "NATIONAL EDITION"
        case .european:  return "EUROPEAN EDITION"
        case .magazine:  return "FEATURE"
        }
    }
}

/// How big a splash a story deserves — scales headline size/colour and
/// decides whether it was worth printing a front page for at all.
enum NewspaperImportance: Int, Codable, Comparable {
    case minor = 0, notable = 1, major = 2, historic = 3

    static func < (lhs: NewspaperImportance, rhs: NewspaperImportance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A generated newspaper front page for one news story — the dressed-up
/// presentation layer over a `NewsItem`. Kept as a permanent archive (unlike
/// the ephemeral `news` inbox) so it can double as illustrated season history.
struct Newspaper: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let season: Int
    let outlet: NewspaperOutlet
    let masthead: String
    let headline: String
    let standfirst: String
    let body: String
    let category: NewsCategory
    let importance: NewspaperImportance
    var playerName: String? = nil
    var playerPosition: Position? = nil
    var playerAge: Int? = nil
    var clubName: String? = nil
}

/// Which side of a match an event or team refers to.
enum Side {
    case home, away
    var opposite: Side { self == .home ? .away : .home }
}

/// One line of live match commentary. `side`, when known, is which team
/// the line is about — the commentary feed anchors it to that side rather
/// than always reading down the middle.
struct CommentaryLine: Identifiable {
    let id = UUID()
    let text: String
    let side: Side?
}

/// A backroom appointment the manager can make, each with a distinct,
/// concrete effect on club life rather than a vague overall bonus.
enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case assistantManager = "Assistant Manager"
    case chiefScout = "Chief Scout"
    case physio = "Physio"

    var id: String { rawValue }

    var effectDescription: String {
        switch self {
        case .assistantManager: return "Softens the sting of bad results with the board and fans."
        case .chiefScout:        return "Faster scouting reports."
        case .physio:             return "Fewer, shorter injuries across the squad."
        }
    }
}

/// A hired member of the backroom staff, 1...3 levels of quality.
struct StaffMember: Codable, Identifiable {
    var id = UUID()
    let role: StaffRole
    let name: String
    let level: Int
}

/// The manager's in-match mentality, trading attack against solidity.
enum Mentality: String, CaseIterable, Identifiable, Codable {
    case defensive = "Defensive"
    case balanced  = "Balanced"
    case attacking = "Attacking"

    var id: String { rawValue }

    /// Multiplier on the team's chance creation.
    var attack: Double {
        switch self {
        case .defensive: return 0.82
        case .balanced:  return 1.0
        case .attacking: return 1.20
        }
    }

    /// Multiplier on defensive solidity (higher is better at the back).
    var solidity: Double {
        switch self {
        case .defensive: return 1.18
        case .balanced:  return 1.0
        case .attacking: return 0.84
        }
    }
}

/// A mid-match tactical instruction the manager can toggle.
enum MatchInstruction: String, CaseIterable, Identifiable {
    case balanced    = "Balanced"
    case pushForward = "Push Forward"
    case containment = "Contain"
    case timeWaste   = "Time-Waste"

    var id: String { rawValue }

    /// Multiplier on the user's attacking output.
    var attack: Double {
        switch self {
        case .balanced: return 1.0
        case .pushForward: return 1.28
        case .containment: return 0.80
        case .timeWaste: return 0.68
        }
    }

    /// Multiplier on the user's defensive solidity.
    var solidity: Double {
        switch self {
        case .balanced: return 1.0
        case .pushForward: return 0.82
        case .containment: return 1.22
        case .timeWaste: return 1.30
        }
    }
}

/// The kind of thing that happened during a match.
/// Match-day conditions, rolled once per fixture from its month — snow
/// only in winter, sunny spells cluster in summer, rain year-round like
/// English football demands. Poor conditions blunt finishing more than
/// they blunt chance creation, so the effect is felt without every match
/// in the rain turning into a stalemate.
enum Weather: String, CaseIterable {
    case sunny = "Sunny", cloudy = "Cloudy", rain = "Rain", snow = "Snow", fog = "Fog"

    var glyph: String {
        switch self {
        case .sunny:  return "☀"
        case .cloudy: return "☁"
        case .rain:   return "🌧"
        case .snow:   return "🌨"
        case .fog:    return "🌫"
        }
    }

    /// Multiplier on the chance a shot on target actually happens.
    var accuracyMultiplier: Double {
        switch self {
        case .sunny, .cloudy: return 1.0
        case .rain: return 0.88
        case .snow: return 0.80
        case .fog:  return 0.92
        }
    }

    static func random(forMonth month: Int) -> Weather {
        let winter = month == 12 || month <= 2
        let summer = (6...8).contains(month)
        let weights: [(Weather, Double)]
        if winter {
            weights = [(.cloudy, 0.30), (.rain, 0.28), (.snow, 0.17), (.fog, 0.15), (.sunny, 0.10)]
        } else if summer {
            weights = [(.sunny, 0.47), (.cloudy, 0.30), (.rain, 0.20), (.fog, 0.03), (.snow, 0.0)]
        } else {
            weights = [(.cloudy, 0.35), (.rain, 0.32), (.sunny, 0.20), (.fog, 0.10), (.snow, 0.03)]
        }
        let roll = Double.random(in: 0..<1)
        var cumulative = 0.0
        for (weather, weight) in weights {
            cumulative += weight
            if roll < cumulative { return weather }
        }
        return .cloudy
    }
}

enum MatchEventType {
    case kickOff, goal, penalty, yellowCard, redCard, substitution, injury, halfTime, fullTime

    var glyph: String {
        switch self {
        case .kickOff:      return "⦿"
        case .goal:         return "⚽︎"
        case .penalty:      return "⚽︎"
        case .yellowCard:   return "🟨"
        case .redCard:      return "🟥"
        case .substitution: return "⇄"
        case .injury:       return "＋"
        case .halfTime:     return "⏸"
        case .fullTime:     return "⏱"
        }
    }
}

/// A single timeline event in a live match.
struct MatchEvent: Identifiable {
    let id = UUID()
    let minute: Int
    let side: Side?
    let type: MatchEventType
    let name: String
    let note: String?

    /// The headline shown on the timeline, e.g. "ISAK 86 (PEN)".
    var headline: String {
        var line = "\(name) \(minute)'"
        if let note { line += " \(note)" }
        return line
    }
}

/// A player as tracked on the pitch during a live match, with live condition.
struct PitchPlayer: Identifiable {
    let player: Player
    var energy: Double = 100
    var yellowCards: Int = 0
    var onPitch: Bool = true

    var id: UUID { player.id }
    /// Effective rating after fatigue is taken into account.
    var effectiveRating: Double {
        Double(player.rating) * (0.72 + 0.28 * energy / 100)
    }
}

/// The result of a match from one club's point of view.
enum MatchOutcome {
    case win, draw, loss

    var letter: String {
        switch self {
        case .win:  return "W"
        case .draw: return "D"
        case .loss: return "L"
        }
    }
}

/// A club competing in the league.
struct Club: Identifiable, Codable {
    var id = UUID()
    let name: String
    /// Three-letter abbreviation shown in the league table.
    let shortName: String
    var players: [Player]

    /// The club's base standing, which drives player quality and finances.
    var prestige = 70
    /// Money available for transfers, in thousands of pounds.
    var transferBudget = 0
    /// The most the club is willing to carry in total weekly wages, in
    /// thousands of pounds — a separate ceiling from the transfer budget,
    /// so a club can be transfer-rich but wage-constrained (or vice versa).
    var wageBudget = 0
    /// Which division the club plays in (0 = top tier).
    var divisionTier = 0
    /// The club's primary colour as [red, green, blue] in 0...1.
    var colorRGB: [Double] = [0.55, 1.0, 0.55]

    // Season record.
    var played = 0
    var won = 0
    var drawn = 0
    var lost = 0
    var goalsFor = 0
    var goalsAgainst = 0

    /// The biggest winning margin in this club's history, and a short
    /// description of that match — an all-time club record, not reset
    /// each season.
    var recordWinMargin = 0
    var recordWinDescription = ""

    /// Investable club infrastructure, 0...5. The academy improves youth
    /// intake quality; stadium expansion grows matchday capacity (and so
    /// gate revenue). Both cost more to upgrade the higher they already are.
    var youthFacilityLevel = 0
    var stadiumExpansionLevel = 0
    /// Ticket price level, 1 (cheap) ... 5 (premium). Cheaper fills more
    /// seats and keeps fans onside; premium pricing earns more per head
    /// but costs some attendance and fan goodwill. Defaults to neutral.
    var ticketPriceLevel = 3
    /// The rest of a club's investable infrastructure, 0...5 each, same
    /// escalating-cost pattern as the academy/stadium above — see
    /// `GameStore+Facilities.swift` for costs and `README`-style effects:
    /// training ground speeds up player development; medical centre cuts
    /// injury frequency/duration; scouting network speeds up and sharpens
    /// scouting; hospitality adds matchday revenue; museum builds prestige
    /// and fan loyalty; club shop boosts season commercial income.
    var trainingGroundLevel = 0
    var medicalCentreLevel = 0
    var scoutingNetworkLevel = 0
    var hospitalityLevel = 0
    var museumLevel = 0
    var clubShopLevel = 0

    var points: Int { won * 3 + drawn }
    var goalDifference: Int { goalsFor - goalsAgainst }
    /// Total weekly wage bill, in thousands of pounds.
    var wageBill: Int { players.reduce(0) { $0 + $1.wage } }

    private enum CodingKeys: String, CodingKey {
        case id, name, shortName, players, prestige, transferBudget, wageBudget, divisionTier, colorRGB
        case played, won, drawn, lost, goalsFor, goalsAgainst
        case recordWinMargin, recordWinDescription
        case youthFacilityLevel, stadiumExpansionLevel, ticketPriceLevel
        case trainingGroundLevel, medicalCentreLevel, scoutingNetworkLevel
        case hospitalityLevel, museumLevel, clubShopLevel
    }

    /// Resets the season record and every player's season-scoped stats.
    ///
    /// `apps`/`ratingPoints` previously had no reset at all despite being
    /// documented as "this season" — meaning `averageRating` was
    /// quietly a career average, not a season one, and the all-time
    /// accumulation in `GameStore+CareerHistory.swift` was re-adding an
    /// ever-growing cumulative `apps` figure every season instead of just
    /// that season's appearances. Fixed here alongside adding
    /// `assists`/`cleanSheets` to the same reset.
    mutating func resetSeason() {
        played = 0; won = 0; drawn = 0; lost = 0
        goalsFor = 0; goalsAgainst = 0
        for index in players.indices {
            players[index].goals = 0
            players[index].assists = 0
            players[index].cleanSheets = 0
            players[index].apps = 0
            players[index].ratingPoints = 0
            players[index].injuriesThisSeason = 0
        }
    }
}

extension Club {
    /// A lenient decoder: `wageBudget` and the club-record fields were
    /// added after `CodingKeys` was first written, so older saves never
    /// wrote them. Falling back to a default instead of a hard decode
    /// failure means an old save still loads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        shortName = try container.decode(String.self, forKey: .shortName)
        players = try container.decode([Player].self, forKey: .players)
        prestige = try container.decodeIfPresent(Int.self, forKey: .prestige) ?? 70
        transferBudget = try container.decodeIfPresent(Int.self, forKey: .transferBudget) ?? 0
        wageBudget = try container.decodeIfPresent(Int.self, forKey: .wageBudget) ?? 0
        divisionTier = try container.decodeIfPresent(Int.self, forKey: .divisionTier) ?? 0
        colorRGB = try container.decodeIfPresent([Double].self, forKey: .colorRGB) ?? [0.55, 1.0, 0.55]
        played = try container.decodeIfPresent(Int.self, forKey: .played) ?? 0
        won = try container.decodeIfPresent(Int.self, forKey: .won) ?? 0
        drawn = try container.decodeIfPresent(Int.self, forKey: .drawn) ?? 0
        lost = try container.decodeIfPresent(Int.self, forKey: .lost) ?? 0
        goalsFor = try container.decodeIfPresent(Int.self, forKey: .goalsFor) ?? 0
        goalsAgainst = try container.decodeIfPresent(Int.self, forKey: .goalsAgainst) ?? 0
        recordWinMargin = try container.decodeIfPresent(Int.self, forKey: .recordWinMargin) ?? 0
        recordWinDescription = try container.decodeIfPresent(String.self, forKey: .recordWinDescription) ?? ""
        youthFacilityLevel = try container.decodeIfPresent(Int.self, forKey: .youthFacilityLevel) ?? 0
        stadiumExpansionLevel = try container.decodeIfPresent(Int.self, forKey: .stadiumExpansionLevel) ?? 0
        ticketPriceLevel = try container.decodeIfPresent(Int.self, forKey: .ticketPriceLevel) ?? 3
        trainingGroundLevel = try container.decodeIfPresent(Int.self, forKey: .trainingGroundLevel) ?? 0
        medicalCentreLevel = try container.decodeIfPresent(Int.self, forKey: .medicalCentreLevel) ?? 0
        scoutingNetworkLevel = try container.decodeIfPresent(Int.self, forKey: .scoutingNetworkLevel) ?? 0
        hospitalityLevel = try container.decodeIfPresent(Int.self, forKey: .hospitalityLevel) ?? 0
        museumLevel = try container.decodeIfPresent(Int.self, forKey: .museumLevel) ?? 0
        clubShopLevel = try container.decodeIfPresent(Int.self, forKey: .clubShopLevel) ?? 0
    }
}

/// A scheduled match between two clubs.
struct Fixture: Identifiable, Codable {
    let id = UUID()
    let matchday: Int
    let homeIndex: Int
    let awayIndex: Int

    var played = false
    var homeGoals = 0
    var awayGoals = 0

    private enum CodingKeys: String, CodingKey {
        case matchday, homeIndex, awayIndex, played, homeGoals, awayGoals
    }
}

/// A tactical formation the manager can pick, expressed as
/// defenders / midfielders / forwards (the goalkeeper is implied).
struct Formation: Identifiable, Hashable {
    let name: String
    let defenders: Int
    let midfielders: Int
    let forwards: Int
    /// True only for a genuine front-three shape, where the wide midfield
    /// slots are advanced wingers either side of a lone striker. Everywhere
    /// else — including every other lone-striker shape like 4-5-1 or
    /// 5-4-1 — the wide slots are flat, defensively-minded wide midfielders
    /// (LM/RM), same as a classic 4-4-2.
    var wideMidfieldersAreWingers: Bool = false

    var id: String { name }

    static let all: [Formation] = [
        Formation(name: "4-4-2", defenders: 4, midfielders: 4, forwards: 2),
        // The classic front three: 2 wingers either side of a lone striker,
        // with a winger belonging to the midfield line on a real team sheet.
        Formation(name: "4-3-3", defenders: 4, midfielders: 5, forwards: 1, wideMidfieldersAreWingers: true),
        Formation(name: "3-5-2", defenders: 3, midfielders: 5, forwards: 2),
        Formation(name: "5-3-2", defenders: 5, midfielders: 3, forwards: 2),
        Formation(name: "4-5-1", defenders: 4, midfielders: 5, forwards: 1),
        // Same reasoning as 4-3-3: the front three is 2 wingers + 1 striker.
        Formation(name: "3-4-3", defenders: 3, midfielders: 6, forwards: 1, wideMidfieldersAreWingers: true),
        Formation(name: "5-4-1", defenders: 5, midfielders: 4, forwards: 1),
        Formation(name: "4-2-4", defenders: 4, midfielders: 2, forwards: 4),
        Formation(name: "5-2-3", defenders: 5, midfielders: 2, forwards: 3),
        Formation(name: "3-6-1", defenders: 3, midfielders: 6, forwards: 1),
    ]

    /// This formation's Starting XI slot roles, goalkeeper first then the
    /// defense, midfield and attack rows — the same geometry Legends'
    /// `startingXISlots` and Career's `PitchView` both need, factored out
    /// once rather than duplicated per caller.
    func slotRoles() -> [DetailedPosition] {
        var slots: [DetailedPosition] = [.goalkeeper]
        for i in 0..<defenders {
            slots.append(.expected(for: .defender, indexInRow: i, rowCount: defenders))
        }
        for i in 0..<midfielders {
            slots.append(.expected(for: .midfielder, indexInRow: i, rowCount: midfielders, wideIsWinger: wideMidfieldersAreWingers))
        }
        for i in 0..<forwards {
            slots.append(.expected(for: .forward, indexInRow: i, rowCount: forwards))
        }
        return slots
    }
}
