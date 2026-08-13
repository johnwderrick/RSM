//
//  GameStore+Calendar.swift
//  Retro Season Manager
//
//  Injuries and suspensions, and advancing the day-by-day calendar.
//

import Foundation

extension GameStore {

    // MARK: - Injuries & suspensions

    /// Seeds a couple of injuries so the Medical Centre isn't empty at kick-off.
    func seedInjuries() {
        for clubIndex in clubs.indices {
            let count = Int.random(in: 0...2)
            for _ in 0..<count { injureRandomPlayer(clubIndex: clubIndex) }
        }
    }

    /// Heals injuries and suspensions by one round and rolls for a fresh
    /// knock at each club.
    func advanceWeek() {
        for clubIndex in clubs.indices {
            for playerIndex in clubs[clubIndex].players.indices {
                if clubs[clubIndex].players[playerIndex].injuryWeeks > 0 {
                    clubs[clubIndex].players[playerIndex].injuryWeeks -= 1
                }
                if clubs[clubIndex].players[playerIndex].suspensionMatches > 0 {
                    clubs[clubIndex].players[playerIndex].suspensionMatches -= 1
                }
            }
            // Roughly a one-in-three chance of a fresh training-ground
            // injury — a physio on the staff cuts that down.
            let physioReduction = clubIndex == userClubIndex
                ? Double(staffLevel(.physio)) * 0.06 + Double(clubs[clubIndex].medicalCentreLevel) * 0.02 : 0
            if Double.random(in: 0..<1) < 0.30 - physioReduction {
                injureRandomPlayer(clubIndex: clubIndex)
            }
        }
        trainUserSquad()
    }

    /// Develops the user's players' attributes each week, per training focus.
    func trainUserSquad() {
        for index in clubs[userClubIndex].players.indices {
            var player = clubs[userClubIndex].players[index]
            let devChance: Double
            switch player.age {
            case ..<22:   devChance = 0.30
            case 22...25: devChance = 0.15
            case 26...29: devChance = 0.06
            default:      devChance = 0.0
            }
            // A dedicated professional who works hard in training develops
            // faster than a talented but disinterested teammate at the
            // same age — roughly ±30% around the age-based base chance.
            let traitMultiplier = 0.7 + Double(player.traits.professionalism + player.traits.workEthic) / 200.0 * 0.6
            guard Double.random(in: 0..<1) < devChance * traitMultiplier else { continue }

            let focused = player.attributeOrder.filter { trainingFocus.preferred.isEmpty || trainingFocus.preferred.contains($0) }
            let pool = focused.isEmpty ? player.attributeOrder : focused
            if let name = pool.randomElement(), (player.attributes[name] ?? 0) < 20 {
                player.attributes[name, default: 0] += 1
            }
            // Young players can raise their overall rating (and value).
            if player.age <= 24, player.rating < 90, Double.random(in: 0..<1) < 0.5 {
                player.rating += 1
                player.value = playerValue(rating: player.rating, age: player.age, startYear: startYear)
            }
            clubs[userClubIndex].players[index] = player
        }
        trainYouthProspects()
    }

    /// A gentler version of first-team training for the academy's current
    /// crop, so a prospect sat in the pool for a few months is a little
    /// sharper by the time they're promoted, not still exactly as raw as
    /// the day they arrived.
    func trainYouthProspects() {
        for index in youthProspects.indices where youthProspects[index].rating < 85 {
            guard Double.random(in: 0..<1) < 0.12 else { continue }
            youthProspects[index].rating += 1
            youthProspects[index].value = playerValue(rating: youthProspects[index].rating, age: youthProspects[index].age, startYear: startYear)
        }
    }

    /// Injures one fit player at the club for one to four weeks — a
    /// fragile player is more likely to be picked, and picks up a longer
    /// lay-off; a robust one, the opposite.
    func injureRandomPlayer(clubIndex: Int) {
        let fit = clubs[clubIndex].players.indices.filter { clubs[clubIndex].players[$0].injuryWeeks == 0 }
        // A run of knocks this season makes a player temporarily more
        // likely to be the next one to break down, on top of their fixed
        // durability trait — a squad with an injury crisis feels like one.
        guard let target = weightedRandomIndex(from: Array(fit), weight: {
            clubs[clubIndex].players[$0].durability.injuryChanceMultiplier
                * (1.0 + Double(min(4, clubs[clubIndex].players[$0].injuriesThisSeason)) * 0.15)
        }) else { return }
        let base = Int.random(in: 1...4)
        let physioFactor = clubIndex == userClubIndex
            ? (1.0 - Double(staffLevel(.physio)) * 0.1 - Double(clubs[clubIndex].medicalCentreLevel) * 0.03) : 1.0
        clubs[clubIndex].players[target].injuryWeeks = max(1, Int(Double(base) * clubs[clubIndex].players[target].durability.injuryDurationMultiplier * physioFactor))
        clubs[clubIndex].players[target].injuriesThisSeason += 1
    }

    /// The injured players in a club's squad, worst injuries first.
    func injuredPlayers(forClubIndex index: Int) -> [Player] {
        guard clubs.indices.contains(index) else { return [] }
        return clubs[index].players
            .filter { $0.isInjured }
            .sorted { $0.injuryWeeks > $1.injuryWeeks }
    }

    /// The suspended players in a club's squad, longest ban first.
    func suspendedPlayers(forClubIndex index: Int) -> [Player] {
        guard clubs.indices.contains(index) else { return [] }
        return clubs[index].players
            .filter { $0.isSuspended }
            .sorted { $0.suspensionMatches > $1.suspensionMatches }
    }

    /// A rough calendar date for when an injured player should be back —
    /// injuries heal at one week off per `advanceWeek()` call, so this is
    /// today plus seven days per week still remaining.
    func expectedReturnDate(for player: Player) -> Date? {
        guard player.injuryWeeks > 0 else { return nil }
        return Self.calendar.date(byAdding: .day, value: player.injuryWeeks * 7, to: currentDate)
    }

    // MARK: - Calendar

    static let calendar = Calendar(identifier: .gregorian)
    /// Days from the season's start (1 July) until the opening fixture.
    static let firstMatchOffsetDays = 35   // early August
    /// Days between successive matchdays — roughly weekly, so a 38-round
    /// season runs from August to May.
    static let matchGapDays = 7

    /// The first calendar day of the current season (a July pre-season).
    /// Season 1 begins in the year 2000.
    var seasonStartDate: Date {
        Self.calendar.date(from: DateComponents(year: (startYear - 1) + season, month: 7, day: 1)) ?? Date()
    }

    /// The date a given matchday is played.
    func date(forMatchday matchday: Int) -> Date {
        let days = Self.firstMatchOffsetDays + (matchday - 1) * Self.matchGapDays
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    /// The date of the given pre-season friendly (0 or 1), both well before
    /// the opening league fixture.
    func friendlyDate(_ index: Int) -> Date {
        let days = 14 + index * 7
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    /// The pre-season friendlies scheduled for a given day.
    func friendlyFixtures(onDate day: Date) -> [Fixture] {
        friendlyFixtures.filter { Self.calendar.isDate(friendlyDate($0.matchday), inSameDayAs: day) }
    }

    /// The current in-game day, exposed to the UI as "today".
    var todayDate: Date { currentDate }

    // MARK: - Calendar

    /// The user division's league fixtures scheduled for a given day.
    func fixtures(onDate day: Date) -> [Fixture] {
        fixtures.filter {
            clubs[$0.homeIndex].divisionTier == userDivisionTier
                && Self.calendar.isDate(date(forMatchday: $0.matchday), inSameDayAs: day)
        }
    }

    /// The current-round domestic cup ties on a given day (past rounds are
    /// no longer retained once resolved — check the news feed for those).
    func cupTies(onDate day: Date) -> [CupTie] {
        guard cupRound > 0, Self.calendar.isDate(cupRoundDate(cupRound), inSameDayAs: day) else { return [] }
        return cupTies
    }

    /// The current-round Continental Cup ties on a given day.
    func euroTies(onDate day: Date) -> [CupTie] {
        guard euroRound > 0, Self.calendar.isDate(euroRoundDate(euroRound), inSameDayAs: day) else { return [] }
        return euroTies
    }

    /// The Community Trophy tie, if it's played on the given day.
    func communityShieldTie(onDate day: Date) -> CupTie? {
        guard let tie = communityShieldTie, Self.calendar.isDate(communityShieldDate(), inSameDayAs: day) else { return nil }
        return tie
    }

    /// News items posted on a given day.
    func news(onDate day: Date) -> [NewsItem] {
        news.filter { Self.calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Whether anything at all — a match, a cup tie, or news — happened or
    /// is scheduled on a given day. Used to draw the calendar's day dots.
    func hasCalendarEvent(onDate day: Date) -> Bool {
        !fixtures(onDate: day).isEmpty || !cupTies(onDate: day).isEmpty || !leagueCupTies(onDate: day).isEmpty
            || !euroTies(onDate: day).isEmpty || !uefaCupTies(onDate: day).isEmpty
            || communityShieldTie(onDate: day) != nil || uefaSuperCupTie(onDate: day) != nil
            || !news(onDate: day).isEmpty
    }

    /// The date of the user's next unplayed league fixture, if any.
    var nextUserFixtureDate: Date? {
        nextUserFixture.map { date(forMatchday: $0.matchday) }
    }

    /// The user's live cup tie in the current round (excludes byes), if any.
    var nextUserCupTie: CupTie? {
        guard cupWinnerName == nil else { return nil }
        return cupTies.first { !$0.played && !$0.isBye && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    /// The date of the user's next cup tie, if they're still in the cup.
    var nextUserCupDate: Date? {
        nextUserCupTie.map { cupRoundDate($0.round) }
    }

    /// The user's live Continental Cup tie in the current round, if any.
    var nextUserEuroTie: CupTie? {
        guard euroWinnerName == nil else { return nil }
        return euroTies.first { !$0.played && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    var nextUserEuroDate: Date? {
        nextUserEuroTie.map { euroRoundDate($0.round) }
    }

    var isUserLeagueToday: Bool {
        guard let date = nextUserFixtureDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    var isUserCupToday: Bool {
        guard let date = nextUserCupDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    var isUserEuroToday: Bool {
        guard let date = nextUserEuroDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    /// Whether the user has any match (league, cup, Europe or a one-off shield/super cup) today.
    var isUserMatchToday: Bool {
        isUserLeagueToday || isUserCupToday || isUserLeagueCupToday || isUserEuroToday
            || isUserUefaCupToday || isUserCommunityShieldToday || isUserUefaSuperCupToday
    }

    /// The date of the user's next commitment, across all competitions.
    var nextUserMatchDate: Date? {
        [nextUserFixtureDate, nextUserCupDate, nextUserLeagueCupDate, nextUserEuroDate, nextUserUefaCupDate,
         nextUserCommunityShieldTie != nil ? communityShieldDate() : nil,
         nextUserUefaSuperCupTie != nil ? uefaSuperCupDate() : nil].compactMap { $0 }.min()
    }

    /// Whole days until the user's next match (nil if none).
    var daysUntilNextMatch: Int? {
        guard let date = nextUserMatchDate else { return nil }
        let from = Self.calendar.startOfDay(for: currentDate)
        let to = Self.calendar.startOfDay(for: date)
        return Self.calendar.dateComponents([.day], from: from, to: to).day
    }

    /// Whether today's match (if any) is a knockout tie or one-off cup final.
    var isCupMatchDay: Bool {
        isUserCupToday || isUserLeagueCupToday || isUserEuroToday || isUserUefaCupToday
            || isUserCommunityShieldToday || isUserUefaSuperCupToday
    }

    // MARK: - Advancing the calendar

    /// Advances the game by a single day, up to the next match day.
    func advanceDay() {
        guard !isSeasonOver, !isUserMatchToday else { return }
        currentDate = Self.calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        dailyTick()
        persist()
    }

    /// Advances day by day until the next match, the season's end, or a
    /// freshly-arrived transfer offer that needs the manager's attention.
    /// Offers already pending when this is called (e.g. left over from an
    /// earlier skip) don't block progress — only a new one does.
    func advanceToNextMatch() async {
        let startingOfferCount = pendingOffers.count
        var safety = 0
        while !isSeasonOver && !isUserMatchToday && pendingOffers.count <= startingOfferCount && safety < 120 {
            advanceDay()
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
    }

    /// The CONTINUE button's fast-forward: advances day by day through the
    /// quiet stretches instead of making the manager tap through every
    /// blank day by hand, pulling up as soon as something worth their
    /// attention happens — new news in the inbox, a match day, or the
    /// season ending — whichever comes first.
    func advanceUntilNews() async {
        let startingUnreadCount = unreadNewsIDs.count
        var safety = 0
        while !isSeasonOver && !isUserMatchToday && unreadNewsIDs.count <= startingUnreadCount && safety < 120 {
            advanceDay()
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
    }

    /// Advances day by day up to a chosen calendar date, using the same
    /// stopping rules as `advanceToNextMatch` (season end, a match day, or
    /// a fresh transfer offer) — so simming to a distant date still pulls
    /// up short for anything that needs the manager's attention.
    ///
    /// `await Task.yield()` every few iterations hands control back to the
    /// run loop so the loading spinner actually animates instead of the
    /// whole UI freezing solid for however long this takes — without it,
    /// this whole while loop runs synchronously on the main actor in one
    /// shot and nothing else, including the spinner, gets to draw.
    func simTo(date target: Date) async {
        let startingOfferCount = pendingOffers.count
        var safety = 0
        while !isSeasonOver && !isUserMatchToday && pendingOffers.count <= startingOfferCount
                && currentDate < target && safety < 750 {
            advanceDay()
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
    }

    /// A harder fast-forward to a chosen date: any match due along the way
    /// — including the user's own, in any competition — is auto-resolved
    /// instead of pausing for live play. Still stops at season end.
    func forceSimTo(date target: Date) async {
        var safety = 0
        while !isSeasonOver && currentDate < target && safety < 750 {
            if isUserMatchToday {
                resolveTodaysUserMatchAbstractly()
            } else {
                advanceDay()
            }
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
        persist()
    }

    /// Resolves whichever competition has the user's match today without
    /// live play, then advances the calendar exactly as `advanceDay()` would.
    func resolveTodaysUserMatchAbstractly() {
        if autoPickAssist { smartAutoPick() }
        if isUserCommunityShieldToday {
            resolveCommunityShield(homeGoals: nil, awayGoals: nil)
        } else if isUserUefaSuperCupToday {
            resolveUefaSuperCup(homeGoals: nil, awayGoals: nil)
        } else if isUserEuroToday {
            concludeEuroRound()
        } else if isUserUefaCupToday {
            concludeUefaCupRound()
        } else if isUserCupToday {
            concludeCupRound()
        } else if isUserLeagueCupToday {
            concludeLeagueCupRound()
        } else if isUserLeagueToday {
            forceResolveLeagueDay()
        }
        currentDate = Self.calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        dailyTick()
    }

    /// Simulates every fixture in the current matchday (including the
    /// user's) and advances the matchday counter, mirroring what
    /// `finishLiveMatch()` does for the rest of the round after a live game.
    func forceResolveLeagueDay() {
        let day = currentMatchday
        for index in fixtures.indices where fixtures[index].matchday == day && !fixtures[index].played {
            let fixture = fixtures[index]
            let involvesUser = fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex
            _ = simulate(fixtureIndex: index)
            if involvesUser {
                let updated = fixtures[index]
                applyUserAbstractMatchOutcome(homeIndex: updated.homeIndex, awayIndex: updated.awayIndex,
                                              homeGoals: updated.homeGoals, awayGoals: updated.awayGoals)
            }
        }
        currentMatchday += 1
    }

    /// Applies the same squad-morale and board-confidence swing a live
    /// match would, for a league day resolved abstractly during force-sim
    /// — otherwise board confidence (and the sacking-risk meter) never
    /// moves at all for a manager who always force-sims through matches.
    func applyUserAbstractMatchOutcome(homeIndex: Int, awayIndex: Int, homeGoals: Int, awayGoals: Int) {
        let userIsHome = homeIndex == userClubIndex
        let userScored = userIsHome ? homeGoals : awayGoals
        let userConceded = userIsHome ? awayGoals : homeGoals
        let won = userScored > userConceded
        let draw = userScored == userConceded
        let isDerby = areRivals(clubs[homeIndex].name, clubs[awayIndex].name)
        let derbyBonus = isDerby ? (won ? 6 : (draw ? 0 : -6)) : 0
        for id in userStarterIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                let delta = won ? Int.random(in: 3...8) : (draw ? Int.random(in: -1...2) : -Int.random(in: 3...8))
                // Low temperament (hot-headed) amplifies the swing further;
                // high temperament (composed) damps it down — on top of
                // the existing personality-archetype multiplier.
                let temperamentSwing = 1.0 + Double(50 - clubs[userClubIndex].players[index].traits.temperament) / 100.0
                let scaledDelta = Int(Double(delta) * clubs[userClubIndex].players[index].personality.moraleSwingMultiplier * temperamentSwing)
                // A composed big-game player rides out a bad derby result
                // far better than one who wilts under the extra pressure.
                let pressureFactor = 1.0 + Double(50 - clubs[userClubIndex].players[index].traits.pressure) / 100.0
                let scaledDerbyBonus = Int(Double(derbyBonus) * pressureFactor)
                clubs[userClubIndex].players[index].morale = min(100, max(0, clubs[userClubIndex].players[index].morale + scaledDelta + scaledDerbyBonus))
            }
        }
        updateSquadMorale(appearedIDs: userStarterIDs)
        updateBoard(userWon: won, draw: draw, isHome: userIsHome)
        if won { checkGiantKilling(opponentIndex: userIsHome ? awayIndex : homeIndex) }
    }

    /// A one-off extra reputation and confidence bump for beating a club
    /// far above you in prestige — recognition beyond what a normal win
    /// already earns, on top of `updateBoard`.
    func checkGiantKilling(opponentIndex: Int) {
        let gap = clubs[opponentIndex].prestige - userClub.prestige
        guard gap >= 15 else { return }
        boardConfidence = min(100, boardConfidence + 5)
        fanConfidence = min(100, fanConfidence + 8)
        managerReputation = min(100, managerReputation + 3)
        addNews(.board, "Giant-killing!",
                "\(userClub.name)'s win over the much-fancied \(clubs[opponentIndex].name) turns heads — a real statement result.")
        giantKillingWins += 1
        if giantKillingWins >= 3 { unlock(.giantKiller) }
    }

    /// Simulates the goings-on of a single day: transfer activity and news.
    func dailyTick() {
        expireOffers()
        checkPendingTransferDeals()
        completeScouting()
        recoverFitness()
        progressRetraining()
        checkRealTransferHeadlines()
        checkOwnershipChanges()
        checkMarqueePlayerArrivals()
        checkMarqueePlayerTransfers()
        checkMonthlyAwards()
        checkInternationalCallUps()
        checkRivalManagerSackings()
        checkShortlistAvailability()
        checkObjectiveRisk()
        maybeProcessFriendlies()
        maybeProcessCommunityShield()
        maybeProcessUefaSuperCup()
        maybeProcessCupRound()
        maybeProcessLeagueCupRound()
        maybeProcessEuroRound()
        maybeProcessUefaCupRound()
        let open = transferWindowOpen
        if open && !windowWasOpen {
            generateTransferMarket()
            addNews(.info, "Transfer window open", "Clubs can now buy and sell players.")
            transferBudgetAtWindowOpen = userClub.transferBudget
        } else if !open && windowWasOpen {
            addNews(.info, "Transfer window closed", "No more transfers until the next window.")
            reviewTransferWindowClose()
        }
        windowWasOpen = open

        if open {
            if let days = daysUntilTransferDeadline, days == 2 {
                addNews(.info, "Deadline day looms", "The transfer window shuts in 48 hours — expect late business.")
            } else if let days = daysUntilTransferDeadline, days == 0, !deadlineDayAnnounced {
                deadlineDayAnnounced = true
                addNews(.info, "Deadline day", "Transfer deadline day is here — clubs will be busy right up to the wire.")
            }
            // A last-minute scramble: AI clubs chase far more business in
            // the final 48 hours than on an ordinary day.
            let aiTransferAttempts = isDeadlineDayRush ? Int.random(in: 2...4) : (Double.random(in: 0..<1) < 0.5 ? 1 : 0)
            for _ in 0..<aiTransferAttempts { processAITransfer() }
            let offerChance = isDeadlineDayRush ? 0.20 : 0.08
            if pendingOffers.count < 2 && Double.random(in: 0..<1) < offerChance { generateOfferForUser() }
            maybeGenerateTransferRumour()
        }
    }

    /// Pure gossip: an unverified "linked with a move" story about an
    /// in-game player, using the same clubs and squads as everything else
    /// but never actually moving anyone — flavour for the inbox between
    /// real signings.
    func maybeGenerateTransferRumour() {
        guard Double.random(in: 0..<1) < 0.06 else { return }
        let candidates = clubs.indices.filter { clubs[$0].divisionTier < 4 }
        guard let subjectClubIndex = candidates.randomElement(),
              let subject = clubs[subjectClubIndex].players.filter({ $0.rating >= 65 }).randomElement() else { return }
        let suitors = candidates.filter { $0 != subjectClubIndex && clubs[$0].prestige >= clubs[subjectClubIndex].prestige - 5 }
        guard let suitorIndex = suitors.randomElement() else { return }
        let subjectName = clubs[subjectClubIndex].name
        let suitorName = clubs[suitorIndex].name
        let templates = [
            "\(suitorName) are understood to be monitoring \(subject.name)'s situation at \(subjectName).",
            "Reports link \(subject.name) with a possible move to \(suitorName), though \(subjectName) are yet to comment.",
            "\(suitorName) have been credited with interest in \(subjectName)'s \(subject.name).",
            "Speculation continues to link \(subject.name) with a switch to \(suitorName) — nothing concrete yet.",
        ]
        addNews(.world, "Transfer gossip", templates.randomElement() ?? templates[0])
    }

    /// Everyone recovers a little match fitness on a rest day.
    func recoverFitness() {
        for clubIndex in clubs.indices {
            for index in clubs[clubIndex].players.indices {
                let current = clubs[clubIndex].players[index].fitness
                if current < 100 {
                    clubs[clubIndex].players[index].fitness = min(100, current + Int.random(in: 3...6))
                }
            }
        }
    }

    /// Advances any in-progress position retraining by a day; when it
    /// completes, the trained role becomes an official secondary position.
    func progressRetraining() {
        for index in clubs[userClubIndex].players.indices {
            guard let role = clubs[userClubIndex].players[index].retrainingRole else { continue }
            clubs[userClubIndex].players[index].retrainingDaysRemaining -= 1
            if clubs[userClubIndex].players[index].retrainingDaysRemaining <= 0 {
                let name = clubs[userClubIndex].players[index].name
                if !clubs[userClubIndex].players[index].secondaryPositions.contains(role) {
                    clubs[userClubIndex].players[index].secondaryPositions.append(role)
                }
                clubs[userClubIndex].players[index].retrainingRole = nil
                clubs[userClubIndex].players[index].retrainingDaysRemaining = 0
                addNews(.board, "Retraining complete", "\(name) has completed retraining and can now play \(role.fullName).")
            }
        }
    }

    enum RetrainingOutcome {
        case started(String)
        case blocked(String)
    }

    /// Begins retraining a squad player toward a new detailed role within
    /// their own broad position — you can't retrain a striker into a
    /// goalkeeper, but a centre-back can learn to play left-back, or a
    /// central midfielder can learn to play out wide.
    @discardableResult
    func beginRetraining(_ player: Player, toward role: DetailedPosition) -> RetrainingOutcome {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return .blocked("That player is not in your squad.")
        }
        guard role.broad == player.position else {
            return .blocked("\(player.name) can't retrain outside \(player.position.rawValue).")
        }
        guard role != player.detailedPosition, !player.secondaryPositions.contains(role) else {
            return .blocked("\(player.name) can already play \(role.fullName).")
        }
        let familiar = player.fit(for: role) >= 1
        let baseDays = (familiar ? 5 : 9) * 7
        let ageAdjust = player.age <= 23 ? -14 : (player.age >= 30 ? 14 : 0)
        let days = max(21, baseDays + ageAdjust)
        clubs[userClubIndex].players[index].retrainingRole = role
        clubs[userClubIndex].players[index].retrainingDaysRemaining = days
        addNews(.board, "Retraining started", "\(player.name) begins training to play \(role.fullName), expected to take about \(days / 7) weeks.")
        persist()
        return .started("\(player.name) is now training for \(role.fullName) (~\(days / 7) weeks).")
    }

    /// Hands out a Manager of the Month award for the user's own division
    /// when the calendar rolls into a new month, based on points earned
    /// since the last check (not the raw season total, so it rewards
    /// recent form rather than always crowning the runaway leader).
    func checkMonthlyAwards() {
        guard let year = Self.calendar.dateComponents([.year], from: currentDate).year else { return }
        let month = Self.calendar.component(.month, from: currentDate)
        let key = year * 12 + month
        guard key != lastMonthlyAwardKey else { return }
        let previousKey = lastMonthlyAwardKey
        lastMonthlyAwardKey = key
        let table = leagueTable(tier: userDivisionTier)
        defer { monthlyAwardBaseline = Dictionary(uniqueKeysWithValues: table.map { ($0.id, $0.points) }) }
        guard previousKey != 0 else { return }   // first check this game — just seed the baseline

        let improvements = table.compactMap { club -> (Club, Int)? in
            guard let before = monthlyAwardBaseline[club.id] else { return nil }
            return (club, club.points - before)
        }
        if let best = improvements.max(by: { $0.1 < $1.1 }), best.1 > 0,
           let index = clubs.firstIndex(where: { $0.id == best.0.id }) {
            addNews(.board, "Manager of the Month",
                    "\(managers[index]) (\(best.0.name)) takes the award after \(best.1) point\(best.1 == 1 ? "" : "s") from their last few fixtures.")
        }
        awardClubPlayerOfTheMonth()
        punditPowerRankings()
    }

    /// A monthly pundit-style top-5 roundup for the user's division — a
    /// different flavour of "how are things going" than the plain
    /// standings table, with a nod to where the user's club sits if
    /// they're outside it.
    func punditPowerRankings() {
        let table = leagueTable(tier: userDivisionTier)
        let top5 = Array(table.prefix(5))
        guard !top5.isEmpty else { return }
        let lines = top5.enumerated().map { "\($0.offset + 1). \($0.element.name)" }.joined(separator: ", ")
        var body = "This month's power rankings: \(lines)."
        if let userRank = table.firstIndex(where: { $0.id == userClub.id }), userRank >= 5 {
            body += " \(userClub.name) sit \(userRank + 1)\(ordinalSuffix(userRank + 1)) — plenty to play for."
        }
        addNews(.info, "Power rankings", body)
    }

    func ordinalSuffix(_ n: Int) -> String {
        let mod100 = n % 100
        if (11...13).contains(mod100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    /// The user's own standout performer over recent matches — a smaller,
    /// squad-morale-boosting sibling to the league-wide Manager of the Month.
    func awardClubPlayerOfTheMonth() {
        func recentAverage(_ p: Player) -> Double {
            p.recentRatings.isEmpty ? 0 : p.recentRatings.reduce(0, +) / Double(p.recentRatings.count)
        }
        guard let best = userClub.players.filter({ $0.recentRatings.count >= 2 }).max(by: { recentAverage($0) < recentAverage($1) })
        else { return }
        addNews(.board, "Player of the Month",
                "\(best.name) is named \(userClub.name)'s Player of the Month after a string of strong performances.")
        if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == best.id }) {
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 5)
        }
    }

    /// Real-world international-break windows during an English season, as
    /// day offsets from the season's start. No nationality data exists in
    /// this game, so "called up" is a flavour/fitness-cost mechanic — your
    /// best players occasionally get pulled away — not a specific country's
    /// actual squad.
    static let internationalBreakOffsets = [33, 63, 96, 145, 240]

    func checkInternationalCallUps() {
        guard let daysSinceStart = Self.calendar.dateComponents([.day], from: seasonStartDate, to: currentDate).day,
              Self.internationalBreakOffsets.contains(daysSinceStart) else { return }
        let candidates = userClub.players.filter { $0.rating >= 78 && $0.isAvailable }
        guard !candidates.isEmpty else { return }
        let called = Array(candidates.sorted { $0.rating > $1.rating }.prefix(Int.random(in: 1...3)))
        guard !called.isEmpty else { return }
        for player in called {
            guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else { continue }
            clubs[userClubIndex].players[index].fitness = max(30, clubs[userClubIndex].players[index].fitness - Int.random(in: 15...25))
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 3)
        }
        let names = called.map { $0.name }.joined(separator: ", ")
        addNews(.info, "International call-ups",
                "\(names) \(called.count == 1 ? "has" : "have") been called up for international duty during the break — expect \(called.count == 1 ? "him" : "them") back a little jaded.")
    }

    /// A small daily chance that a struggling AI club sacks its manager —
    /// the wider world keeps turning even when it isn't your own job on
    /// the line.
    /// How precarious a struggling club's manager is — loyal and
    /// press-friendly managers get more patience from their board; a
    /// journeyman never stays long anywhere, and a big spender who isn't
    /// delivering on that outlay is shown the door faster.
    private func sackingWeight(forClubIndex index: Int) -> Double {
        switch personality(forClubIndex: index) {
        case .loyal:         return 0.5
        case .pressFriendly: return 0.7
        case .journeyman:    return 1.6
        case .bigSpender:    return 1.3
        default:             return 1.0
        }
    }

    func checkRivalManagerSackings() {
        guard hasStarted, !isSeasonOver, Double.random(in: 0..<1) < 0.006 else { return }
        var strugglers: [Club] = []
        for tier in 0..<Self.divisionNames.count {
            let table = leagueTable(tier: tier)
            guard table.count > 6 else { continue }
            strugglers.append(contentsOf: table.suffix(4).filter { $0.id != userClub.id && $0.played >= 8 })
        }
        let candidateIndices = strugglers.compactMap { struggler in clubs.firstIndex(where: { $0.id == struggler.id }) }
        guard let index = weightedRandomIndex(from: candidateIndices, weight: { sackingWeight(forClubIndex: $0) }) else { return }
        let oldManager = managers[index]
        managers[index] = Self.randomManagerName()
        if managerPersonalities.indices.contains(index) {
            managerPersonalities[index] = ManagerPersonality.random()
        }
        addNews(.world, "Manager sacked",
                "\(clubs[index].name) have sacked \(oldManager) after a difficult run of results. \(managers[index]) takes charge.")
    }

    /// A one-off ping (per season) when a shortlisted player enters the
    /// final year of his deal — worth a move now, or a free next summer.
    func checkShortlistAvailability() {
        for (player, clubIndex) in shortlistedResults where clubIndex != userClubIndex {
            guard player.contractYears <= 1, !shortlistAlertedIDs.contains(player.id) else { continue }
            shortlistAlertedIDs.insert(player.id)
            addNews(.info, "Shortlist alert",
                    "\(player.name) (\(clubs[clubIndex].name)) is entering the final year of his contract — a move could be within reach.")
        }
    }

    /// A one-off warning, the first time the season is far enough along
    /// that current form is genuinely on track to miss the board's
    /// objective — rather than only finding out at the season review.
    func checkObjectiveRisk() {
        guard !objectiveRiskWarned, isObjectiveAtRisk else { return }
        objectiveRiskWarned = true
        addNews(.board, "Under pressure",
                "With \(userClub.played) games gone, \(userClub.name) are off the pace for \"\(boardObjective)\" — the board will be watching closely.")
    }

    /// Fires any real-world "big transfer" headlines whose real announcement
    /// date the in-game calendar has just reached. Flavour only — none of
    /// these players or clubs exist in this game's world, so nothing here
    /// touches squads, budgets or results.
    func checkRealTransferHeadlines() {
        for entry in RealTransfers.all where entry.year >= startYear {
            let eventID = "realTransfer-\(entry.year)-\(entry.month)-\(entry.day)-\(entry.headline)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date else { continue }
            firedDatedEventIDs.insert(eventID)
            addNews(.world, entry.headline, entry.body)
        }
    }

    /// Fires a genuine transfer-budget boost when a real-world ownership
    /// change's announcement date is reached, for any of these clubs that
    /// exist in the English pyramid. Unlike `checkRealTransferHeadlines`,
    /// this one actually mutates the club's finances.
    func checkOwnershipChanges() {
        for entry in OwnershipChanges.all where entry.year >= startYear {
            let eventID = "ownership-\(entry.club)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date,
                  let index = clubs.firstIndex(where: { $0.name == entry.club }) else { continue }
            firedDatedEventIDs.insert(eventID)
            clubs[index].transferBudget = max(0, clubs[index].transferBudget + entry.budgetInjection)
            clubs[index].wageBudget = max(0, clubs[index].wageBudget + entry.budgetInjection / 6)
            if entry.prestigeBoost != 0 {
                clubs[index].prestige = min(95, clubs[index].prestige + entry.prestigeBoost)
            }
            addNews(.board, entry.headline, entry.body)
            if index == userClubIndex {
                logLedger("Ownership change", amount: entry.budgetInjection, entry.headline)
            }
        }
    }

    /// Adds a handful of real, recognisable players to the game world on
    /// their real breakthrough dates, in place of the weakest same-position
    /// player already at that club — the same "make room" pattern used for
    /// the researched foreign stars, just triggered by the calendar instead
    /// of at game creation.
    func checkMarqueePlayerArrivals() {
        for entry in MarqueePlayers.arrivals where entry.year >= startYear {
            let eventID = "marqueeArrival-\(entry.name)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date,
                  let clubIndex = clubs.firstIndex(where: { $0.name == entry.club }) else { continue }
            firedDatedEventIDs.insert(eventID)
            var player = Self.makePlayer(name: entry.name, position: entry.detailedPosition.broad,
                                         detailedPosition: entry.detailedPosition,
                                         secondaryPositions: entry.secondaryPositions,
                                         age: entry.age, rating: entry.rating, startYear: startYear)
            player.contractYears = Int.random(in: 3...5)
            if let weakestIndex = clubs[clubIndex].players.indices
                .filter({ clubs[clubIndex].players[$0].position == entry.detailedPosition.broad })
                .min(by: { clubs[clubIndex].players[$0].rating < clubs[clubIndex].players[$1].rating }) {
                clubs[clubIndex].players.remove(at: weakestIndex)
            }
            clubs[clubIndex].players.append(player)
            addNews(.transfer, entry.headline, entry.body, player: player, clubName: entry.club)
        }
    }

    /// Moves a real, already-in-the-world player to their real next club on
    /// their real transfer date. Silently skips if that player can't be
    /// found — sold, released or renamed some other way in this save —
    /// rather than risk a duplicate or a crash.
    func checkMarqueePlayerTransfers() {
        for entry in MarqueePlayers.transfers where entry.year >= startYear {
            let eventID = "marqueeTransfer-\(entry.name)-\(entry.toClub)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date,
                  let toIndex = clubs.firstIndex(where: { $0.name == entry.toClub }),
                  let fromIndex = clubs.firstIndex(where: { club in club.players.contains { $0.name == entry.name } }),
                  fromIndex != toIndex,
                  let playerIndex = clubs[fromIndex].players.firstIndex(where: { $0.name == entry.name }) else { continue }
            firedDatedEventIDs.insert(eventID)
            var player = clubs[fromIndex].players.remove(at: playerIndex)
            player.rating = entry.newRating
            player.value = playerValue(rating: entry.newRating, age: player.age, startYear: startYear)
            player.wage = playerWage(rating: entry.newRating, age: player.age, startYear: startYear)
            player.morale = 78
            player.contractYears = Int.random(in: 3...5)
            if let weakestIndex = clubs[toIndex].players.indices
                .filter({ clubs[toIndex].players[$0].position == player.position })
                .min(by: { clubs[toIndex].players[$0].rating < clubs[toIndex].players[$1].rating }) {
                clubs[toIndex].players.remove(at: weakestIndex)
            }
            clubs[toIndex].players.append(player)
            addNews(.transfer, entry.headline, entry.body, player: player, clubName: entry.toClub)
        }
    }

}
