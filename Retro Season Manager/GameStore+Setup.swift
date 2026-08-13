//
//  GameStore+Setup.swift
//  Retro Season Manager
//
//  Building the club catalogue and setting up a brand new career.
//

import Foundation

extension GameStore {

    // MARK: - Club catalogue

    /// Real club name pools for each division (used up to `divisionSize`).
    /// The First Division tier is the actual 2000/01 top flight, ordered by
    /// final league position so prestige (which decays by pool index) lines
    /// up with real sporting merit that season.
    static let tierPools: [[String]] = [
        // First Division (2000/01 final table order)
        ["Old Trafford Reds", "Highbury", "Mersey Reds", "Elland Athletic", "Portman Rovers", "Stamford Blues", "Wearside",
         "Aston Rovers", "Valley Rovers", "Solent", "Tyneside", "White Hart Athletic", "Filbert Foxes",
         "Teesside", "Upton Athletic", "Goodison Blues", "Pride Rams", "Etihad Blues", "Highfield Athletic", "Valley Parade"],
        // Second Division (absorbs the 2000/01 Division One clubs displaced from the pool above)
        ["Craven Cottagers", "Ewood Rovers", "Trotters", "Molineux Old Gold", "Bramall Blades", "Hillsborough Owls", "Vicarage Hornets",
         "Selhurst Eagles", "Elm Royals", "Britannia Potters", "Ninian Bluebirds", "Turf Clarets", "Deepdale North End", "Loftus Hoops", "The Den Lions",
         "Boothferry Tigers", "Ashton Robins", "Home Park Argyle", "Oakwell Reds", "Springfield Latics", "Carrow Canaries"],
        // Third Division
        ["Fratton Blues", "Bloomfield Tangerines", "Boundary Athletic", "Griffin Bees", "Vetch Swans", "London Road Posh", "Bescot Saddlers",
         "Layer Us", "Priestfield Gills", "Prenton Rovers", "Dean Court Cherries", "Belle Rovers", "Huish Glovers", "Amex Seagulls",
         "Sixfields Cobblers", "Millmoor Millers", "Saltergate Spireites", "Gigg Shakers", "Vale Park", "Elland Athletic Road Terriers"],
        // Fourth Division
        ["Victoria Pool", "Spotland Dale", "Blundell Mariners", "Meadow Magpies", "Field Stags", "Gresty Railwaymen", "Sincil Imps",
         "Feethams Quakers", "Brunton Cumbrians", "St James Grecians", "Plainmoor Gulls", "Glanford Iron", "Whaddon Robins", "Moss Silkmen",
         "Meadow Shrews", "Roots Shrimpers", "Brisbane Os", "Memorial Pirates", "County Robins", "Racecourse Reds"],
    ]

    static let tierBasePrestige = [84, 70, 60, 52]

    /// Curated primary colours for well-known clubs (visible on the dark UI).
    static let clubColors: [String: [Double]] = [
        "Stamford Blues": [0.15, 0.35, 0.85], "Etihad Blues": [0.45, 0.75, 0.95],
        "Mersey Reds": [0.90, 0.20, 0.25], "Old Trafford Reds": [0.95, 0.25, 0.20],
        "Highbury": [0.95, 0.20, 0.22], "White Hart Athletic": [0.62, 0.68, 0.95],
        "Goodison Blues": [0.25, 0.45, 0.95], "Tyneside": [0.80, 0.80, 0.85],
        "Elland Athletic": [0.95, 0.85, 0.35], "Aston Rovers": [0.55, 0.20, 0.45],
        "Upton Athletic": [0.70, 0.30, 0.40], "Filbert Foxes": [0.30, 0.55, 0.95],
        "Solent": [0.95, 0.35, 0.35], "Molineux Old Gold": [0.95, 0.70, 0.25],
        "Portman Rovers": [0.20, 0.40, 0.80], "Wearside": [0.85, 0.15, 0.15],
        "Valley Rovers": [0.82, 0.12, 0.20], "Highfield Athletic": [0.35, 0.65, 0.92],
        "Valley Parade": [0.55, 0.15, 0.25], "Teesside": [0.80, 0.15, 0.15],
        "Bernabéu Whites": [0.65, 0.68, 0.78], "Camp Blaugrana": [0.55, 0.15, 0.55],
        "Bavarian Reds": [0.85, 0.15, 0.15], "Turin Bianconeri": [0.15, 0.15, 0.15],
        "San Siro Rossoneri": [0.85, 0.15, 0.15], "San Siro Nerazzurri": [0.15, 0.25, 0.55],
        "Amsterdam Godenzonen": [0.85, 0.15, 0.15], "Dragão Dragons": [0.15, 0.35, 0.65],
    ]

    static let colorPalette: [[Double]] = [
        [0.90, 0.35, 0.35], [0.35, 0.62, 0.95], [0.95, 0.66, 0.25], [0.62, 0.42, 0.88],
        [0.35, 0.80, 0.55], [0.95, 0.52, 0.72], [0.42, 0.82, 0.86], [0.88, 0.82, 0.35],
        [0.95, 0.48, 0.28], [0.58, 0.78, 0.38],
    ]

    /// A stable primary colour for any club name.
    static func clubColor(name: String) -> [Double] {
        if let curated = clubColors[name] { return curated }
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colorPalette[hash % colorPalette.count]
    }

    /// A club's starting transfer budget (in £000s) from its prestige,
    /// baseline calibrated to year-2000 spending — a big top-flight club
    /// has a few tens of millions to spend, not hundreds — then scaled up
    /// by `economyMultiplier` for a later career start.
    static func transferBudget(forPrestige prestige: Int, startYear: Int = 2000) -> Int {
        let base = pow(Double(prestige) / 45.0, 7.0) * 247.0
        return max(50, Int(base * economyMultiplier(startYear: startYear)))
    }

    /// Sentinel division for foreign clubs (they sit outside the pyramid but
    /// live in `clubs` so all index-based match code works for them too).
    static let foreignTier = 9
    /// The eight European giants outside the English pyramid, with a
    /// prestige range roughly matching their real 2000/01 stature — four
    /// go into the Continental Cup each season, four into the Midweek Cup.
    static let foreignPool: [(name: String, prestige: ClosedRange<Int>)] = [
        ("Bernabéu Whites", 87...92), ("Camp Blaugrana", 86...91), ("Bavarian Reds", 85...90),
        ("Turin Bianconeri", 85...90), ("San Siro Rossoneri", 84...89), ("San Siro Nerazzurri", 83...88),
        ("Amsterdam Godenzonen", 77...83), ("Dragão Dragons", 75...81),
    ]

    /// A unique three-letter code for a club name.
    static func uniqueCode(for name: String, used: inout Set<String>) -> String {
        let letters = name.uppercased().filter { $0.isLetter }
        var base = String(letters.prefix(3))
        while base.count < 3 { base += "X" }
        var code = base
        var suffix = 1
        while used.contains(code) {
            code = String(letters.prefix(2)) + "\(suffix)"
            suffix += 1
        }
        used.insert(code)
        return code
    }

    /// The full catalogue, generated deterministically (tier-major order).
    static func catalogueEntries() -> [(name: String, short: String, prestige: Int, tier: Int)] {
        var result: [(name: String, short: String, prestige: Int, tier: Int)] = []
        var used = Set<String>()
        for tier in tierPools.indices {
            let pool = Array(tierPools[tier].prefix(divisionSize))
            for (i, name) in pool.enumerated() {
                let prestige = clampRating(tierBasePrestige[tier] - Int(Double(i) * 0.9))
                result.append((name, uniqueCode(for: name, used: &used), prestige, tier))
            }
        }
        return result
    }

    /// Clubs the player can choose from, grouped by division.
    var clubsByDivision: [(tier: Int, name: String, clubs: [(index: Int, name: String, short: String)])] {
        let entries = Self.catalogueEntries()
        return (0..<Self.divisionNames.count).map { tier in
            let clubsInTier = entries.enumerated()
                .filter { $0.element.tier == tier }
                .map { (index: $0.offset, name: $0.element.name, short: $0.element.short) }
            return (tier, divisionName(tier), clubsInTier)
        }
    }

    /// A preview of what a club offers, shown on the confirmation screen before starting a new game.
    struct ClubPreview {
        let name: String
        let short: String
        let divisionName: String
        let divisionRank: Int
        let divisionSize: Int
        let prestige: Int
        let stars: Int
        let estimatedBudget: Int
        let boardObjective: String
        let colorRGB: [Double]
    }

    /// Builds a preview for a club without starting a game, using the same
    /// deterministic catalogue that `newGame(clubIndex:)` draws from.
    func clubPreview(forClubIndex index: Int, startYear: Int = 2000) -> ClubPreview? {
        let entries = Self.catalogueEntries()
        guard entries.indices.contains(index) else { return nil }
        let entry = entries[index]

        let tierEntries = entries.enumerated()
            .filter { $0.element.tier == entry.tier }
            .sorted { $0.element.prestige > $1.element.prestige }
        let rank = (tierEntries.firstIndex { $0.offset == index } ?? 0) + 1

        var budget = Self.transferBudget(forPrestige: entry.prestige, startYear: startYear)
        // Mirror newGame's retroactive ownership-change bump, so the
        // preview a manager sees before committing already reflects it —
        // otherwise a 2010+ Chelsea/Man City-equivalent would look
        // deceptively ordinary right up until the squad actually loads.
        for change in OwnershipChanges.all where change.year < startYear && change.club == entry.name {
            budget = max(0, budget + Int(Double(change.budgetInjection) * economyMultiplier(startYear: startYear)))
        }

        let objective: String
        if entry.tier == 0 {
            objective = rank <= 1 ? "Win the league"
                : rank <= 4 ? "Qualify for Europe (top 4)"
                : rank <= Self.divisionSize / 2 ? "Finish in the top half"
                : "Avoid relegation"
        } else {
            objective = rank <= 2 ? "Win automatic promotion (top 2)"
                : rank <= 6 ? "Reach the play-offs (top 6)"
                : rank <= Self.divisionSize / 2 ? "Finish in the top half"
                : (entry.tier == Self.divisionNames.count - 1 ? "Finish mid-table" : "Avoid relegation")
        }

        let stars: Int
        switch entry.prestige {
        case 86...:   stars = 5
        case 78..<86: stars = 4
        case 68..<78: stars = 3
        case 58..<68: stars = 2
        default:      stars = 1
        }

        return ClubPreview(name: entry.name, short: entry.short, divisionName: divisionName(entry.tier),
                           divisionRank: rank, divisionSize: tierEntries.count, prestige: entry.prestige,
                           stars: stars, estimatedBudget: budget, boardObjective: objective,
                           colorRGB: Self.clubColor(name: entry.name))
    }

    // MARK: - New game

    /// Builds the four-division pyramid with generated squads and fixtures.
    /// - Parameter clubIndex: The club the manager will control.
    func newGame(clubIndex: Int, startYear: Int = 2000, managerName: String = "") {
        currentSaveID = UUID()
        self.startYear = startYear
        let trimmedName = managerName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.managerName = trimmedName.isEmpty ? Self.randomName() : trimmedName
        clubs = Self.catalogueEntries().map { entry in
            var club = Club(name: entry.name,
                            shortName: entry.short,
                            players: Self.makeSquad(name: entry.name, prestige: entry.prestige, startYear: startYear))
            club.prestige = entry.prestige
            club.transferBudget = Self.transferBudget(forPrestige: entry.prestige, startYear: startYear)
            club.wageBudget = Int(Double(club.wageBill) * 1.4)
            club.divisionTier = entry.tier
            club.colorRGB = Self.clubColor(name: entry.name)
            return club
        }
        // A start year later than 2000 means some real-world ownership
        // changes (Stamford Blues 2003, Etihad Blues 2008, etc.) have
        // already happened by kickoff — the live news event for these is
        // skipped for anything dated before `startYear` (see
        // `checkOwnershipChanges`), so their cumulative budget/prestige
        // effect needs to be baked into the starting numbers directly
        // instead, or a 2010+ Chelsea/Man City-equivalent would start with
        // no trace of the takeover that actually defined their era.
        for change in OwnershipChanges.all where change.year < startYear {
            guard let index = clubs.firstIndex(where: { $0.name == change.club }) else { continue }
            let scaled = Int(Double(change.budgetInjection) * economyMultiplier(startYear: startYear))
            clubs[index].transferBudget = max(0, clubs[index].transferBudget + scaled)
            clubs[index].wageBudget = max(0, clubs[index].wageBudget + scaled / 6)
            if change.prestigeBoost != 0 {
                clubs[index].prestige = min(95, clubs[index].prestige + change.prestigeBoost)
            }
        }
        // Eight European giants outside the pyramid — four go into the
        // Continental Cup each season, four into the Midweek Cup.
        var usedCodes = Set(clubs.map { $0.shortName })
        for (name, prestigeRange) in Self.foreignPool {
            let prestige = Int.random(in: prestigeRange)
            var club = Club(name: name,
                            shortName: Self.uniqueCode(for: name, used: &usedCodes),
                            players: Self.makeSquad(name: name, prestige: prestige, startYear: startYear))
            club.prestige = prestige
            club.divisionTier = Self.foreignTier
            club.colorRGB = Self.clubColor(name: name)
            club.wageBudget = Int(Double(club.wageBill) * 1.4)
            clubs.append(club)
        }
        // Non-playable clubs from Spain, France, Italy and Germany's top two
        // divisions — background depth for a genuinely continental European
        // Cup / Midweek Cup field. Squads are generated, not researched.
        for division in ForeignLeagues.all {
            let prestigeRange = division.tier == 1 ? 62...78 : 48...62
            for name in division.clubs {
                let prestige = Int.random(in: prestigeRange)
                var club = Club(name: name,
                                shortName: Self.uniqueCode(for: name, used: &usedCodes),
                                players: Self.makeSquad(prestige: prestige, startYear: startYear))
                club.prestige = prestige
                club.divisionTier = division.divisionTier
                club.colorRGB = Self.clubColor(name: name)
                Self.applyForeignStars(to: &club, startYear: startYear)
                club.wageBudget = Int(Double(club.wageBill) * 1.4)
                clubs.append(club)
            }
        }
        managers = clubs.map { _ in Self.randomManagerName() }
        managerPersonalities = clubs.map { _ in ManagerPersonality.random() }
        clubNegotiationStances = clubs.map { _ in ClubNegotiationStance.allCases.randomElement()! }
        dynamicRivalries = []
        fanConfidenceTrend = 0
        socialFeed = []
        userClubIndex = clubIndex
        season = 1
        formationSwitchedDate = nil
        slotPins = [:]
        formation = Formation.all[0]
        startNewSeason(resetRecords: false)
        seedInjuries()
        generateTransferMarket()
        setBoardObjective()
        news = []
        unreadNewsIDs = []
        pendingOffers = []
        shortlistedPlayerIDs = []
        firedDatedEventIDs = []
        lastMonthlyAwardKey = 0
        monthlyAwardBaseline = [:]
        careerHonours = []
        history = []
        allTimeScorers = [:]
        allTimeAppearances = [:]
        allTimeAssists = [:]
        allTimeCleanSheets = [:]
        allTimeRatingPoints = [:]
        captainSeasonTally = [:]
        clubLegends = []
        newspapers = []
        careerRecordByClub = [:]
        motmTally = [:]
        clubTenureStart = [:]
        seasonLedger = []
        transferHistory = []
        pendingTransferDeals = []
        lastBudgetRequestDate = nil
        hallOfFame = [:]
        unlockedAchievements = []
        achievementUnlocks = [:]
        careerAchievementPoints = 0
        pendingAchievementCelebration = nil
        giantKillingWins = 0
        profitableSalesCount = 0
        firstEuropeQualificationSeason = nil
        lastHonourSeason = 0
        careerEnded = false
        managerReputation = 40 + (3 - userDivisionTier) * 5   // PL 55 … Fourth Division 40
        fanConfidence = 60
        seasonTicketHolders = Int(Double(stadiumInfo(forClubIndex: userClubIndex).capacity) * 0.4)
        backroomStaff = []
        pendingJobOffers = []
        pendingClubSwitch = nil
        wasSacked = false
        captainID = nil; penaltyTakerID = nil; freeKickTakerID = nil; cornerTakerID = nil
        validateRoles()
        windowWasOpen = transferWindowOpen
        deadlineDayAnnounced = false
        transferBudgetAtWindowOpen = transferWindowOpen ? userClub.transferBudget : 0
        addNews(.info, "Welcome to \(userClub.name)", "Season \(season) begins. The board's objective: \(boardObjective).")
        hasStarted = true
        persist()
    }

    /// Regenerates fixtures and (optionally) clears season records.
    func startNewSeason(resetRecords: Bool) {
        if resetRecords {
            for index in clubs.indices { clubs[index].resetSeason() }
            seasonLedger = []
            shortlistAlertedIDs = []
            objectiveRiskWarned = false
        }
        fixtures = makeAllFixtures()
        currentMatchday = 1
        lastReports = []
        currentDate = seasonStartDate
        // dailyTick never visits the season's own opening day (currentDate
        // jumps straight to it above), so anything date-triggered has to
        // be checked explicitly here too, or an event dated exactly to a
        // season's 1 July opener — like Ferro's fictional 2005 arrival — would
        // never fire under any circumstances, not just a missed one.
        checkRealTransferHeadlines()
        checkOwnershipChanges()
        checkMarqueePlayerArrivals()
        checkMarqueePlayerTransfers()
        allocateForeignClubsForSeason()
        startCup()
        startLeagueCup()
        startEuropeanCup()
        startUefaCup()
        startCommunityShield()
        startUefaSuperCup()
        generateYouthIntake()
        scheduleFriendlies()
        shuffleForeignDivisions()
    }

    /// A light touch of promotion/relegation for the four non-playable
    /// countries: one club swaps up, one swaps down, each season after the
    /// first (season 1 keeps the researched real-world placements). These
    /// clubs don't play a simulated table, so this stands in for it —
    /// enough that the European draw's background field isn't frozen forever.
    func shuffleForeignDivisions() {
        guard season > 1 else { return }
        var promotedNames: [String] = []
        var relegatedNames: [String] = []
        for pair in [(ForeignLeagues.spainTier1, ForeignLeagues.spainTier2),
                     (ForeignLeagues.italyTier1, ForeignLeagues.italyTier2),
                     (ForeignLeagues.germanyTier1, ForeignLeagues.germanyTier2),
                     (ForeignLeagues.franceTier1, ForeignLeagues.franceTier2)] {
            let (tier1, tier2) = pair
            guard Double.random(in: 0..<1) < 0.6 else { continue }   // not every country shuffles every season
            guard let relegated = clubs.indices.filter({ clubs[$0].divisionTier == tier1 }).randomElement(),
                  let promoted = clubs.indices.filter({ clubs[$0].divisionTier == tier2 }).randomElement() else { continue }
            clubs[relegated].divisionTier = tier2
            clubs[relegated].prestige = Int.random(in: 48...62)
            clubs[promoted].divisionTier = tier1
            clubs[promoted].prestige = Int.random(in: 62...78)
            relegatedNames.append(clubs[relegated].name)
            promotedNames.append(clubs[promoted].name)
        }
        if !promotedNames.isEmpty {
            addNews(.world, "European football: promotion & relegation",
                    "Up: \(promotedNames.joined(separator: ", ")). Down: \(relegatedNames.joined(separator: ", ")).")
        }
    }

    /// Picks two distinct domestic opponents for the user's pre-season
    /// friendlies. Home/away alternates so both a home and away friendly
    /// happen most seasons.
    func scheduleFriendlies() {
        let candidates = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 }
        let opponents = Array(candidates.shuffled().prefix(2))
        friendlyFixtures = opponents.enumerated().map { offset, opponent in
            let isHome = offset % 2 == 0
            return Fixture(matchday: offset,
                           homeIndex: isHome ? userClubIndex : opponent,
                           awayIndex: isHome ? opponent : userClubIndex)
        }
    }

    /// Returns to the main menu (the game is saved automatically).
    func quitToMenu() {
        persist()
        hasStarted = false
    }

}
