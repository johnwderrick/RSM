//
//  GameStore+Persistence.swift
//  Retro Season Manager
//
//  Saving and restoring a career from disk.
//

import Foundation

extension GameStore {

    // MARK: - Persistence

    static var legacySaveURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("fm_save.json")
    }

    /// Whether any saved career exists on disk — including a pre-multi-slot
    /// save that hasn't been migrated into the slot system yet.
    static var hasSavedGame: Bool {
        !SaveSlots.all().isEmpty || FileManager.default.fileExists(atPath: legacySaveURL.path)
    }

    /// Every save slot, most recently played first.
    static func savedGames() -> [SaveSlotInfo] {
        migrateLegacySaveIfNeeded()
        return SaveSlots.all()
    }

    /// A one-off migration: the game used to keep a single fixed save file.
    /// If that file is still there and hasn't been folded into a slot yet,
    /// give it a slot of its own so nobody's career is silently dropped.
    static func migrateLegacySaveIfNeeded() {
        guard SaveSlots.all().isEmpty,
              let data = try? Data(contentsOf: legacySaveURL),
              let state = try? JSONDecoder().decode(SaveState.self, from: data) else { return }
        let id = UUID()
        try? data.write(to: SaveSlots.fileURL(for: id))
        let clubName = state.clubs.indices.contains(state.userClubIndex) ? state.clubs[state.userClubIndex].name : "Unknown"
        SaveSlots.upsert(SaveSlotInfo(id: id, clubName: clubName, managerName: "Manager",
                                       season: state.season, divisionName: "", lastPlayed: state.currentDate))
        try? FileManager.default.removeItem(at: legacySaveURL)
    }

    /// Removes a save slot from disk.
    static func deleteSave(id: UUID) {
        SaveSlots.remove(id)
    }

    /// Writes the essential game state to disk.
    func persist() {
        guard hasStarted else { return }
        let state = SaveState(season: season,
                              currentMatchday: currentMatchday,
                              userClubIndex: userClubIndex,
                              formationName: formation.name,
                              currentDate: currentDate,
                              boardObjective: boardObjective,
                              boardConfidence: boardConfidence,
                              fanConfidence: fanConfidence,
                              boardConfidenceTrend: boardConfidenceTrend,
                              managers: managers,
                              managerName: managerName,
                              firstEuropeQualificationSeason: firstEuropeQualificationSeason,
                              starterIDs: Array(userStarterIDs),
                              clubs: clubs,
                              fixtures: fixtures,
                              cupTies: cupTies,
                              cupRound: cupRound,
                              cupWinnerName: cupWinnerName,
                              leagueCupTies: leagueCupTies,
                              leagueCupRound: leagueCupRound,
                              leagueCupWinnerName: leagueCupWinnerName,
                              leagueCupWinnerID: leagueCupWinnerID,
                              careerHonours: careerHonours,
                              lastHonourSeason: lastHonourSeason,
                              euroTies: euroTies,
                              euroRound: euroRound,
                              euroWinnerName: euroWinnerName,
                              euroWinnerID: euroWinnerID,
                              europeanQualifierIDs: europeanQualifierIDs,
                              uefaCupTies: uefaCupTies,
                              uefaCupRound: uefaCupRound,
                              uefaCupWinnerName: uefaCupWinnerName,
                              uefaCupWinnerID: uefaCupWinnerID,
                              uefaCupQualifierIDs: uefaCupQualifierIDs,
                              uefaSuperCupTie: uefaSuperCupTie,
                              uefaSuperCupWinnerName: uefaSuperCupWinnerName,
                              lastSeasonEuroWinnerID: lastSeasonEuroWinnerID,
                              lastSeasonUefaCupWinnerID: lastSeasonUefaCupWinnerID,
                              managerReputation: managerReputation,
                              pendingJobOffers: pendingJobOffers,
                              pendingClubSwitch: pendingClubSwitch,
                              wasSacked: wasSacked,
                              captainID: captainID,
                              penaltyTakerID: penaltyTakerID,
                              freeKickTakerID: freeKickTakerID,
                              cornerTakerID: cornerTakerID,
                              communityShieldTie: communityShieldTie,
                              communityShieldWinnerName: communityShieldWinnerName,
                              cupWinnerID: cupWinnerID,
                              lastSeasonChampionID: lastSeasonChampionID,
                              lastSeasonRunnerUpID: lastSeasonRunnerUpID,
                              lastSeasonCupWinnerID: lastSeasonCupWinnerID,
                              history: history,
                              youthProspects: youthProspects,
                              allTimeScorers: allTimeScorers,
                              allTimeAppearances: allTimeAppearances,
                              careerRecordByClub: careerRecordByClub,
                              motmTally: motmTally,
                              clubTenureStart: clubTenureStart,
                              seasonLedger: seasonLedger,
                              transferHistory: transferHistory,
                              lastBudgetRequestDate: lastBudgetRequestDate,
                              lastClearAirDate: lastClearAirDate,
                              trainingFocus: trainingFocus,
                              hallOfFame: hallOfFame,
                              difficulty: difficulty,
                              shortlistedPlayerIDs: shortlistedPlayerIDs,
                              friendlyFixtures: friendlyFixtures,
                              formationSwitchedDate: formationSwitchedDate,
                              autoPickAssist: autoPickAssist,
                              delegateToAssistant: delegateToAssistant,
                              preferredMentality: preferredMentality,
                              backroomStaff: backroomStaff,
                              slotPins: slotPins,
                              firedDatedEventIDs: firedDatedEventIDs,
                              managerContractYears: managerContractYears,
                              startYear: startYear,
                              pendingTransferDeals: pendingTransferDeals,
                              unlockedAchievements: unlockedAchievements,
                              achievementUnlocks: achievementUnlocks,
                              careerAchievementPoints: careerAchievementPoints,
                              giantKillingWins: giantKillingWins,
                              profitableSalesCount: profitableSalesCount,
                              version: Self.currentSaveVersion,
                              allTimeAssists: allTimeAssists,
                              allTimeCleanSheets: allTimeCleanSheets,
                              allTimeRatingPoints: allTimeRatingPoints,
                              captainSeasonTally: captainSeasonTally,
                              clubLegends: clubLegends,
                              newspapers: newspapers,
                              managerPersonalities: managerPersonalities,
                              clubNegotiationStances: clubNegotiationStances,
                              dynamicRivalries: dynamicRivalries,
                              fanConfidenceTrend: fanConfidenceTrend,
                              seasonTicketHolders: seasonTicketHolders,
                              socialFeed: socialFeed)
        guard let id = currentSaveID, let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: SaveSlots.fileURL(for: id))
        SaveSlots.upsert(SaveSlotInfo(id: id, clubName: userClub.name, managerName: "Manager",
                                       season: season, divisionName: divisionName(userDivisionTier),
                                       lastPlayed: Date()))
    }

    /// Restores a saved game from a specific slot, regenerating transient state.
    @discardableResult
    func loadSavedGame(id: UUID) -> Bool {
        guard let data = try? Data(contentsOf: SaveSlots.fileURL(for: id)),
              let state = try? JSONDecoder().decode(SaveState.self, from: data) else { return false }
        // Every field added since version 1 already defaults itself on
        // load via `?? something` below, so there's nothing to migrate
        // yet — `saveVersion` exists as the hook for the day a change
        // needs more than that (e.g. reshaping a field's type).
        saveVersion = state.version ?? 1
        currentSaveID = id
        clubs = state.clubs
        fixtures = state.fixtures
        userClubIndex = state.userClubIndex
        currentMatchday = state.currentMatchday
        season = state.season
        currentDate = state.currentDate
        managers = state.managers
        managerName = state.managerName ?? Self.randomName()
        firstEuropeQualificationSeason = state.firstEuropeQualificationSeason
        boardObjective = state.boardObjective
        boardConfidence = state.boardConfidence
        fanConfidence = state.fanConfidence ?? 60
        boardConfidenceTrend = state.boardConfidenceTrend ?? 0
        // Set the formation first (its didSet auto-picks), then restore the XI.
        formation = Formation.all.first { $0.name == state.formationName } ?? Formation.all[0]
        userStarterIDs = Set(state.starterIDs)
        captainID = state.captainID
        penaltyTakerID = state.penaltyTakerID
        freeKickTakerID = state.freeKickTakerID
        cornerTakerID = state.cornerTakerID
        communityShieldTie = state.communityShieldTie
        communityShieldWinnerName = state.communityShieldWinnerName
        cupWinnerID = state.cupWinnerID
        lastSeasonChampionID = state.lastSeasonChampionID
        lastSeasonRunnerUpID = state.lastSeasonRunnerUpID
        lastSeasonCupWinnerID = state.lastSeasonCupWinnerID
        history = state.history
        youthProspects = state.youthProspects
        allTimeScorers = state.allTimeScorers
        allTimeAppearances = state.allTimeAppearances ?? [:]
        careerRecordByClub = state.careerRecordByClub ?? [:]
        motmTally = state.motmTally ?? [:]
        clubTenureStart = state.clubTenureStart ?? [:]
        seasonLedger = state.seasonLedger ?? []
        transferHistory = state.transferHistory ?? []
        lastBudgetRequestDate = state.lastBudgetRequestDate
        lastClearAirDate = state.lastClearAirDate
        trainingFocus = state.trainingFocus
        hallOfFame = state.hallOfFame
        difficulty = state.difficulty
        shortlistedPlayerIDs = state.shortlistedPlayerIDs
        friendlyFixtures = state.friendlyFixtures
        formationSwitchedDate = state.formationSwitchedDate
        autoPickAssist = state.autoPickAssist
        delegateToAssistant = state.delegateToAssistant ?? false
        preferredMentality = state.preferredMentality ?? .balanced
        backroomStaff = state.backroomStaff ?? []
        slotPins = state.slotPins
        firedDatedEventIDs = state.firedDatedEventIDs
        cupTies = state.cupTies
        cupRound = state.cupRound
        cupWinnerName = state.cupWinnerName
        leagueCupTies = state.leagueCupTies
        leagueCupRound = state.leagueCupRound
        leagueCupWinnerName = state.leagueCupWinnerName
        leagueCupWinnerID = state.leagueCupWinnerID
        careerHonours = state.careerHonours
        lastHonourSeason = state.lastHonourSeason
        euroTies = state.euroTies
        euroRound = state.euroRound
        euroWinnerName = state.euroWinnerName
        euroWinnerID = state.euroWinnerID
        europeanQualifierIDs = state.europeanQualifierIDs
        uefaCupTies = state.uefaCupTies
        uefaCupRound = state.uefaCupRound
        uefaCupWinnerName = state.uefaCupWinnerName
        uefaCupWinnerID = state.uefaCupWinnerID
        uefaCupQualifierIDs = state.uefaCupQualifierIDs
        uefaSuperCupTie = state.uefaSuperCupTie
        uefaSuperCupWinnerName = state.uefaSuperCupWinnerName
        lastSeasonEuroWinnerID = state.lastSeasonEuroWinnerID
        lastSeasonUefaCupWinnerID = state.lastSeasonUefaCupWinnerID
        managerReputation = state.managerReputation
        pendingJobOffers = state.pendingJobOffers
        pendingClubSwitch = state.pendingClubSwitch
        wasSacked = state.wasSacked
        managerContractYears = state.managerContractYears ?? 3
        startYear = state.startYear ?? 2000
        pendingTransferDeals = state.pendingTransferDeals ?? []
        unlockedAchievements = state.unlockedAchievements ?? []
        achievementUnlocks = state.achievementUnlocks ?? [:]
        careerAchievementPoints = state.careerAchievementPoints ?? 0
        giantKillingWins = state.giantKillingWins ?? 0
        profitableSalesCount = state.profitableSalesCount ?? 0
        allTimeAssists = state.allTimeAssists ?? [:]
        allTimeCleanSheets = state.allTimeCleanSheets ?? [:]
        allTimeRatingPoints = state.allTimeRatingPoints ?? [:]
        captainSeasonTally = state.captainSeasonTally ?? [:]
        clubLegends = state.clubLegends ?? []
        newspapers = state.newspapers ?? []
        // Older saves predate this trait system — give every club a fresh
        // random personality rather than leaving the array empty/mismatched.
        managerPersonalities = state.managerPersonalities ?? clubs.map { _ in ManagerPersonality.random() }
        clubNegotiationStances = state.clubNegotiationStances ?? clubs.map { _ in ClubNegotiationStance.allCases.randomElement()! }
        dynamicRivalries = state.dynamicRivalries ?? []
        fanConfidenceTrend = state.fanConfidenceTrend ?? 0
        seasonTicketHolders = state.seasonTicketHolders ?? Int(Double(stadiumInfo(forClubIndex: userClubIndex).capacity) * 0.4)
        socialFeed = state.socialFeed ?? []
        careerEnded = false
        // Rebuild transient state.
        news = []
        unreadNewsIDs = []
        pendingOffers = []
        scoutedReports = [:]
        scoutingDue = [:]
        generateTransferMarket()
        windowWasOpen = transferWindowOpen
        deadlineDayAnnounced = false
        transferBudgetAtWindowOpen = transferWindowOpen ? userClub.transferBudget : 0
        live = nil
        atPreMatch = false
        hasStarted = true
        addNews(.info, "Save loaded", "Welcome back to \(userClub.name). It's \(currentDate.formatted(.dateTime.day().month(.wide).year())).")
        return true
    }

    /// Starts the next season: ages and develops squads, resets transfer
    /// budgets, re-opens the transfer market and resets the board.
    func startNextSeason() {
        guard season < maxSeasons else { endCareer(); return }
        resetTransferBudgets()     // fresh budget for the new season, from several factors
        awardSeasonHonours()       // Team of the Season / Golden Boot flavour news
        resolveForeignDomesticCups() // Copa del Rey / Coppa Italia / DFB-Pokal / Coupe de France
        applyPromotionRelegation() // shuffle clubs between divisions
        returnLoans()              // loanees go back to their parent clubs
        processContracts()         // run down deals; release the expired
        progressSquads()           // age, develop, retire, youth intake
        simulateWorldEvents()      // takeovers, crises, wonderkids — the wider world keeps moving
        validateRoles()            // reassign captain/penalty/free-kick if the holder retired or left
        season += 1
        startNewSeason(resetRecords: true)
        logLedger("Season budget", amount: userClub.transferBudget, "Fresh budget for the new season")
        let commercial = Self.commercialRevenue(forPrestige: userClub.prestige, startYear: startYear, clubShopLevel: userClub.clubShopLevel)
        logLedger("Commercial", amount: commercial, "Kit sponsorship deal")
        addNews(.board, "Sponsorship deal",
                "\(userClub.name) agree a new kit sponsorship deal worth \(formatMoney(commercial)) for the season.")
        // Apply an accepted move (or forced move after a sacking).
        if let newClub = pendingClubSwitch, clubs.indices.contains(newClub) {
            userClubIndex = newClub
            managerContractYears = Int.random(in: 2...4)
            addNews(.board, "New chapter", "You are the new manager of \(clubs[newClub].name).")
        }
        pendingClubSwitch = nil
        pendingJobOffers = []
        wasSacked = false
        generateTransferMarket()
        setBoardObjective()
        autoPickLineup()
        pendingOffers = []
        windowWasOpen = transferWindowOpen
        deadlineDayAnnounced = false
        transferBudgetAtWindowOpen = transferWindowOpen ? userClub.transferBudget : 0
        addNews(.board, "Season \(season)", "A new campaign begins. Objective: \(boardObjective).")
        persist()
    }

}
