//
//  GameStore+MatchEngine.swift
//  Retro Season Manager
//
//  Simulating a match and orchestrating a live one.
//

import Foundation

extension GameStore {

    // MARK: - Match simulation

    /// Samples a Poisson-distributed goal count for the given mean.
    func poisson(_ lambda: Double) -> Int {
        let l = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= Double.random(in: 0...1)
        } while p > l
        return k - 1
    }

    /// Simulates one fixture, updating the fixture, both clubs' records,
    /// and returning a report with the scorers.
    func simulate(fixtureIndex: Int) -> MatchReport {
        let fixture = fixtures[fixtureIndex]
        let home = clubs[fixture.homeIndex]
        let away = clubs[fixture.awayIndex]

        // A bigger, fuller ground is a genuinely louder, more intimidating
        // place to visit — each stadium expansion level adds a little more
        // home advantage on top of the base atmosphere.
        let homeAdvantage = 40.0 + Double(home.stadiumExpansionLevel) * 3.0
        let homeXI = matchXI(forClubIndex: fixture.homeIndex)
        let awayXI = matchXI(forClubIndex: fixture.awayIndex)
        var homeStrength = strengthValue(homeXI) + homeAdvantage
        var awayStrength = strengthValue(awayXI)
        // The user's chosen mentality shifts an abstractly-resolved match
        // too, the same trade-off `LiveMatch` applies minute by minute:
        // more attack for less solidity, or vice versa.
        if fixture.homeIndex == userClubIndex {
            homeStrength *= preferredMentality.attack
            awayStrength /= preferredMentality.solidity
        } else if fixture.awayIndex == userClubIndex {
            awayStrength *= preferredMentality.attack
            homeStrength /= preferredMentality.solidity
        }
        let ratio = homeStrength / (homeStrength + awayStrength)
        applyMatchFitness(clubIndex: fixture.homeIndex, xi: homeXI)
        applyMatchFitness(clubIndex: fixture.awayIndex, xi: awayXI)

        // Around 2.7 goals per game on average, split by relative strength.
        let homeGoals = poisson(2.7 * ratio)
        let awayGoals = poisson(2.7 * (1.0 - ratio))

        // Record the result.
        fixtures[fixtureIndex].played = true
        fixtures[fixtureIndex].homeGoals = homeGoals
        fixtures[fixtureIndex].awayGoals = awayGoals

        applyResult(clubIndex: fixture.homeIndex, scored: homeGoals, conceded: awayGoals, isHome: true, opponentIndex: fixture.awayIndex)
        applyResult(clubIndex: fixture.awayIndex, scored: awayGoals, conceded: homeGoals, isHome: false, opponentIndex: fixture.homeIndex)

        let homeScorers = attributeGoals(homeGoals, toClubAt: fixture.homeIndex)
        let awayScorers = attributeGoals(awayGoals, toClubAt: fixture.awayIndex)

        let involvesUser = fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex
        return MatchReport(matchday: fixture.matchday,
                           homeName: home.name,
                           awayName: away.name,
                           homeGoals: homeGoals,
                           awayGoals: awayGoals,
                           scorers: homeScorers + awayScorers,
                           involvesUser: involvesUser)
    }

    /// Updates a club's win/draw/loss record after a result.
    func applyResult(clubIndex: Int, scored: Int, conceded: Int, isHome: Bool, opponentIndex: Int) {
        clubs[clubIndex].played += 1
        clubs[clubIndex].goalsFor += scored
        clubs[clubIndex].goalsAgainst += conceded
        if scored > conceded {
            clubs[clubIndex].won += 1
        } else if scored == conceded {
            clubs[clubIndex].drawn += 1
        } else {
            clubs[clubIndex].lost += 1
        }

        // Celebrate a new biggest-ever win, for the user's club only —
        // an all-time club record, not reset each season.
        let margin = scored - conceded
        if clubIndex == userClubIndex, margin > clubs[clubIndex].recordWinMargin {
            clubs[clubIndex].recordWinMargin = margin
            clubs[clubIndex].recordWinDescription = "\(scored)-\(conceded) (\(currentDate.formatted(.dateTime.day().month(.wide).year())))"
            addNews(.board, "Club record!", "That's the biggest win in \(userClub.name)'s history — \(scored)-\(conceded).")
        }

        // Gate revenue for the user's own home matches — a stadium
        // investment's actual payoff, on top of the season's budget reset.
        if isHome, clubIndex == userClubIndex {
            let attendance = expectedAttendance(homeIndex: clubIndex, awayIndex: opponentIndex, isCup: false)
            let revenue = attendance * pricePerHead(forClubIndex: clubIndex) / 1000   // in £000s
            clubs[clubIndex].transferBudget += revenue
            logLedger("Gate receipts", amount: revenue, "\(attendance.formatted()) attendance vs \(clubs[opponentIndex].shortName)")
            // Executive boxes and corporate hospitality — a second matchday
            // income stream on top of ticket sales, scaling with both the
            // hospitality level and how full the ground actually is.
            let hospitalityLevel = clubs[clubIndex].hospitalityLevel
            if hospitalityLevel > 0 {
                let hospitalityRevenue = Int(Double(attendance) * 0.05 * Double(hospitalityLevel) / 1000 * 40)
                if hospitalityRevenue > 0 {
                    clubs[clubIndex].transferBudget += hospitalityRevenue
                    logLedger("Hospitality income", amount: hospitalityRevenue, "Matchday hospitality vs \(clubs[opponentIndex].shortName)")
                }
            }
        }
    }

    /// Randomly assigns goals to attacking players, weighted by position
    /// and rating, and increments their season tally.
    func attributeGoals(_ count: Int, toClubAt clubIndex: Int) -> [String] {
        guard count > 0 else { return [] }
        // Weight forwards most, then midfielders, then defenders.
        let weights: [Position: Double] = [.forward: 4, .midfielder: 2, .defender: 0.6, .goalkeeper: 0.02]
        let squad = clubs[clubIndex].players
        var scorers: [String] = []

        func weight(_ player: Player) -> Double {
            (weights[player.position] ?? 1) * Double(player.rating)
        }
        let total = squad.reduce(0.0) { $0 + weight($1) }

        for _ in 0..<count {
            // Pick a scorer by weighted random choice.
            var roll = Double.random(in: 0..<total)
            var chosen = 0
            for (index, player) in squad.enumerated() {
                let w = weight(player)
                if roll < w { chosen = index; break }
                roll -= w
            }
            clubs[clubIndex].players[chosen].goals += 1
            scorers.append("\(clubs[clubIndex].players[chosen].name) (\(clubs[clubIndex].shortName))")
        }
        return scorers
    }

    // MARK: - Advancing the season

    /// Instantly simulates the whole current matchday (used as a fallback
    /// when there is no user match to play out live).
    func playNextMatchday() {
        guard !isSeasonOver else { return }
        let day = currentMatchday
        var reports: [MatchReport] = []
        for index in fixtures.indices where fixtures[index].matchday == day && !fixtures[index].played {
            reports.append(simulate(fixtureIndex: index))
        }
        // Show the user's match first.
        lastReports = reports.sorted { $0.involvesUser && !$1.involvesUser }
        currentMatchday += 1
        advanceWeek()
    }

    // MARK: - Live match orchestration

    /// The user's fiercest rival — a genuine real-world rival if one
    /// exists in this save (even in another division), else a stand-in:
    /// the strongest other club in their own division.
    var rivalClubIndex: Int? {
        if let realRival = clubs.indices.first(where: {
            $0 != userClubIndex && areRivals(userClub.name, clubs[$0].name)
        }) {
            return realRival
        }
        return clubIndices(inTier: userDivisionTier)
            .filter { $0 != userClubIndex }
            .max { clubs[$0].prestige < clubs[$1].prestige }
    }

    /// Whether the next match is a derby against the user's rival.
    var nextMatchIsDerby: Bool {
        guard let info = nextUserMatchInfo, let rival = rivalClubIndex, info.isCup == false else { return false }
        let opponent = info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex
        return opponent == rival
    }

    /// Opens the pre-match hub before the user's next match.
    func enterPreMatch() {
        guard isUserMatchToday else { return }
        atPreMatch = true
        if pendingPressQuestion == nil {
            if nextMatchIsDerby, let rival = rivalClubIndex {
                pendingPressQuestion = makeMindGames(clubs[rival].name)
            } else if Double.random(in: 0..<1) < 0.5 {
                pendingPressQuestion = makePressQuestion()
            }
        }
        if pendingTeamTalk == nil {
            pendingTeamTalk = makeTeamTalk()
        }
        // A capable enough assistant can be trusted to handle the routine
        // stuff — picks whichever option reads best for morale and the
        // board, same as a manager on autopilot would.
        if delegateToAssistant, staffLevel(.assistantManager) >= 3 {
            if let question = pendingPressQuestion,
               let best = question.options.max(by: { ($0.moraleDelta + $0.confidenceDelta) < ($1.moraleDelta + $1.confidenceDelta) }) {
                answerPress(best, headline: "Press conference (assistant)")
            }
            if let talk = pendingTeamTalk,
               let best = talk.options.max(by: { ($0.moraleDelta + $0.confidenceDelta) < ($1.moraleDelta + $1.confidenceDelta) }) {
                answerTeamTalk(best)
            }
        }
    }

    /// A pre-match team talk — reuses the press-conference question shape,
    /// but the morale swing applies only to today's starting XI, before
    /// kickoff, so it genuinely feeds into today's match strength (morale
    /// is one of the factors `strengthValue` weighs) rather than just
    /// banking goodwill for another day.
    func makeTeamTalk() -> PressQuestion {
        let opponent = nextUserMatchInfo.map { info in
            clubs[info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex].name
        } ?? "the opposition"
        return PressQuestion(prompt: "Team talk before facing \(opponent) — what's the message in the dressing room?", options: [
            PressOption(label: "Keep it calm",
                        response: "A measured, low-key talk — the players stay focused and level-headed.",
                        moraleDelta: 3, confidenceDelta: 0),
            PressOption(label: "Rev them up",
                        response: "A rousing, high-energy team talk sends the players out fired up.",
                        moraleDelta: 7, confidenceDelta: 0),
            PressOption(label: "Demand a big performance",
                        response: "The manager set the bar high and demanded a big performance from every player.",
                        moraleDelta: 2, confidenceDelta: 2),
        ])
    }

    /// Applies a team talk's effect to today's starting XI, then clears it.
    func answerTeamTalk(_ option: PressOption) {
        for id in userStarterIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].morale =
                    min(100, max(0, clubs[userClubIndex].players[index].morale + option.moraleDelta))
            }
        }
        boardConfidence = min(100, max(0, boardConfidence + option.confidenceDelta))
        addNews(.board, "Team talk", option.response)
        pendingTeamTalk = nil
    }

    func makeMindGames(_ rival: String) -> PressQuestion {
        PressQuestion(prompt: "\(rival)'s manager says you're “feeling the pressure” before the derby. Your response?", options: [
            PressOption(label: "Fire back", response: "The boss returned fire — the squad is fired up for the derby!", moraleDelta: 6, confidenceDelta: 0),
            PressOption(label: "Stay classy", response: "The manager rose above the mind games, impressing the board.", moraleDelta: 2, confidenceDelta: 2),
            PressOption(label: "Ignore it", response: "The manager refused to engage with the taunts.", moraleDelta: 0, confidenceDelta: 0),
        ])
    }

    func makePressQuestion() -> PressQuestion {
        let opponent = nextUserMatchInfo.map { info in
            clubs[info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex].name
        } ?? "the opposition"
        let prompts = [
            "How do you approach the game against \(opponent)?",
            "The fans want a statement — what's your message before \(opponent)?",
            "There's pressure on the team. What do you tell the press ahead of \(opponent)?",
        ]
        return PressQuestion(prompt: prompts.randomElement()!, options: [
            PressOption(label: "We're going for the win",
                        response: "The manager promised an all-out attacking display. The dressing room is fired up.",
                        moraleDelta: 5, confidenceDelta: 2),
            PressOption(label: "We respect them, but back ourselves",
                        response: "A measured, professional message from the boss.",
                        moraleDelta: 2, confidenceDelta: 1),
            PressOption(label: "The players must prove themselves",
                        response: "The manager publicly questioned his squad — not everyone was happy.",
                        moraleDelta: -3, confidenceDelta: -1),
        ])
    }

    /// Applies a press-conference / interview answer's effects.
    func answerPress(_ option: PressOption, headline: String = "Press conference") {
        for index in clubs[userClubIndex].players.indices {
            clubs[userClubIndex].players[index].morale =
                min(100, max(0, clubs[userClubIndex].players[index].morale + option.moraleDelta))
        }
        boardConfidence = min(100, max(0, boardConfidence + option.confidenceDelta))
        // Fans read the same interview — a bold promise or a dig at the
        // squad lands with them too, not just the boardroom.
        fanConfidence = min(100, max(0, fanConfidence + option.moraleDelta / 2))
        addNews(.board, headline, option.response)
        pendingPressQuestion = nil
    }

    /// Builds a post-match interview shaped by the result.
    func makePostMatchInterview(won: Bool, draw: Bool) -> PressQuestion {
        if won {
            return PressQuestion(prompt: "Delighted with that win, boss?", options: [
                PressOption(label: "Praise the players", response: "The manager heaped praise on his squad.", moraleDelta: 5, confidenceDelta: 2),
                PressOption(label: "Stay grounded", response: "“We move on to the next one.”", moraleDelta: 2, confidenceDelta: 1),
            ])
        } else if draw {
            return PressQuestion(prompt: "A point gained — satisfied?", options: [
                PressOption(label: "A fair result", response: "“A point on the board, we go again.”", moraleDelta: 1, confidenceDelta: 0),
                PressOption(label: "Two points dropped", response: "The boss demanded more from his team.", moraleDelta: -2, confidenceDelta: 1),
            ])
        } else {
            return PressQuestion(prompt: "A tough defeat — your reaction?", options: [
                PressOption(label: "Take responsibility", response: "“That’s on me, not the players.” The squad appreciated it.", moraleDelta: 2, confidenceDelta: 1),
                PressOption(label: "Criticise the players", response: "The manager laid into his team in public.", moraleDelta: -4, confidenceDelta: -1),
            ])
        }
    }

    /// Starts a live match for the user's next match (knockouts take priority).
    func beginUserMatch() {
        if autoPickAssist { smartAutoPick() }
        atPreMatch = false
        if isUserCommunityShieldToday, let tie = nextUserCommunityShieldTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: communityShieldDate(),
                             competitionName: Self.communityShieldName, roundName: "Final")
        } else if isUserUefaSuperCupToday, let tie = nextUserUefaSuperCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: uefaSuperCupDate(),
                             competitionName: Self.uefaSuperCupName, roundName: "Final")
        } else if isUserEuroToday, let tie = nextUserEuroTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: euroRoundDate(tie.round),
                             competitionName: Self.euroName,
                             roundName: euroRoundName(tieCount: euroTies.count))
        } else if isUserCupToday, let tie = nextUserCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: cupRoundDate(tie.round),
                             competitionName: Self.cupName,
                             roundName: cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count))
        } else if isUserLeagueCupToday, let tie = nextUserLeagueCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: leagueCupRoundDate(tie.round),
                             competitionName: Self.leagueCupName,
                             roundName: leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count))
        } else if isUserUefaCupToday, let tie = nextUserUefaCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: uefaCupRoundDate(tie.round),
                             competitionName: Self.uefaCupName,
                             roundName: uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count))
        } else if let fixture = nextUserFixture, isUserLeagueToday {
            live = LiveMatch(store: self, fixture: fixture)
        }
        live?.userMentality = preferredMentality
    }

    /// Commits a finished live match, simulates the rest of the round,
    /// and advances the calendar.
    /// A read-only preview of whether this match's scoreline would clinch
    /// the title or promotion — used purely to decide whether to show the
    /// full-time climax flash, well before `finishLiveMatch()` actually
    /// commits the result. Builds a hypothetical table from this fixture's
    /// score on top of current standings; it doesn't account for other
    /// same-day results, so it's an approximation good enough for "should
    /// we celebrate," not the authoritative promotion/title computation
    /// (`applyPromotionRelegation()`/`recordSeasonHonours()` still own that).
    func climaxFlash(for match: LiveMatch) -> MatchFlashKind? {
        guard !match.isCup, currentMatchday == totalMatchdays,
              clubs.indices.contains(match.homeIndex), clubs.indices.contains(match.awayIndex) else { return nil }
        var hypothetical = clubs
        func apply(_ index: Int, scored: Int, conceded: Int) {
            hypothetical[index].played += 1
            hypothetical[index].goalsFor += scored
            hypothetical[index].goalsAgainst += conceded
            if scored > conceded { hypothetical[index].won += 1 }
            else if scored == conceded { hypothetical[index].drawn += 1 }
            else { hypothetical[index].lost += 1 }
        }
        apply(match.homeIndex, scored: match.homeGoals, conceded: match.awayGoals)
        apply(match.awayIndex, scored: match.awayGoals, conceded: match.homeGoals)
        let tier = userClub.divisionTier
        let table = hypothetical.filter { $0.divisionTier == tier }.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            return $0.goalsFor > $1.goalsFor
        }
        guard let rank = table.firstIndex(where: { $0.id == userClub.id }).map({ $0 + 1 }) else { return nil }
        if rank == 1 { return .champions(clubName: userClub.name) }
        if tier > 0 && rank <= 2 { return .promotion(clubName: userClub.name) }
        return nil
    }

    func finishLiveMatch() {
        guard let match = live, match.isFinished else { return }
        if match.isCup {
            if match.tieID == communityShieldTie?.id { finishLiveCommunityShield(match) }
            else if match.tieID == uefaSuperCupTie?.id { finishLiveUefaSuperCup(match) }
            else if euroTies.contains(where: { $0.id == match.tieID }) { finishLiveEuroTie(match) }
            else if uefaCupTies.contains(where: { $0.id == match.tieID }) { finishLiveUefaCupTie(match) }
            else if leagueCupTies.contains(where: { $0.id == match.tieID }) { finishLiveLeagueCupTie(match) }
            else { finishLiveCupTie(match) }
            return
        }
        let day = currentMatchday

        // Record the user's result.
        if let fxIndex = fixtures.firstIndex(where: { $0.id == match.fixtureID }) {
            fixtures[fxIndex].played = true
            fixtures[fxIndex].homeGoals = match.homeGoals
            fixtures[fxIndex].awayGoals = match.awayGoals
            applyResult(clubIndex: match.homeIndex, scored: match.homeGoals, conceded: match.awayGoals, isHome: true, opponentIndex: match.awayIndex)
            applyResult(clubIndex: match.awayIndex, scored: match.awayGoals, conceded: match.homeGoals, isHome: false, opponentIndex: match.homeIndex)
            for id in match.homeScorerIDs { incrementGoal(clubIndex: match.homeIndex, playerID: id) }
            for id in match.awayScorerIDs { incrementGoal(clubIndex: match.awayIndex, playerID: id) }
        }

        var reports = [MatchReport(matchday: day,
                                   homeName: match.homeName, awayName: match.awayName,
                                   homeGoals: match.homeGoals, awayGoals: match.awayGoals,
                                   scorers: liveScorerNames(match), involvesUser: true)]

        // Simulate every other fixture in the round.
        for index in fixtures.indices where fixtures[index].matchday == day && !fixtures[index].played {
            reports.append(simulate(fixtureIndex: index))
        }
        lastReports = reports
        currentMatchday += 1

        // Heal existing knocks/bans, then apply this match's fresh ones so
        // they carry into the next round.
        advanceWeek()
        for out in match.injuredOut {
            setInjury(clubIndex: out.side == .home ? match.homeIndex : match.awayIndex,
                      playerID: out.id, weeks: Int.random(in: 2...5))
        }
        for red in match.sentOff {
            setSuspension(clubIndex: red.side == .home ? match.homeIndex : match.awayIndex,
                          playerID: red.id, matches: 1)
        }

        // Post-match: record player ratings, morale and board confidence.
        for (id, rating) in match.userPlayerRatingsByID {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].ratingPoints += rating
                clubs[userClubIndex].players[index].apps += 1
                clubs[userClubIndex].players[index].recentRatings.append(rating)
                if clubs[userClubIndex].players[index].recentRatings.count > 5 {
                    clubs[userClubIndex].players[index].recentRatings.removeFirst()
                }
            }
        }
        let userScored = match.userSide == .home ? match.homeGoals : match.awayGoals
        let userConceded = match.userSide == .home ? match.awayGoals : match.homeGoals
        let won = userScored > userConceded
        let draw = userScored == userConceded
        creditAssistsAndCleanSheet(match)
        let isDerby = areRivals(match.homeName, match.awayName)
        let derbyBonus = isDerby ? (won ? 6 : (draw ? 0 : -6)) : 0
        for id in match.userAppearedIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                let delta = won ? Int.random(in: 3...8) : (draw ? Int.random(in: -1...2) : -Int.random(in: 3...8))
                let temperamentSwing = 1.0 + Double(50 - clubs[userClubIndex].players[index].traits.temperament) / 100.0
                let scaledDelta = Int(Double(delta) * clubs[userClubIndex].players[index].personality.moraleSwingMultiplier * temperamentSwing)
                let pressureFactor = 1.0 + Double(50 - clubs[userClubIndex].players[index].traits.pressure) / 100.0
                let scaledDerbyBonus = Int(Double(derbyBonus) * pressureFactor)
                clubs[userClubIndex].players[index].morale = min(100, max(0, clubs[userClubIndex].players[index].morale + scaledDelta + scaledDerbyBonus))
            }
        }
        updateSquadMorale(appearedIDs: Set(match.userAppearedIDs))
        updateBoard(userWon: won, draw: draw, isHome: match.userSide == .home)
        if won { boostFanExcitement(margin: userScored - userConceded) }
        checkWinMilestones()
        if won { checkGiantKilling(opponentIndex: match.userSide == .home ? match.awayIndex : match.homeIndex) }

        let outcome = won ? "Win" : (draw ? "Draw" : "Defeat")
        var body = "Full-time: \(match.homeName) \(match.homeGoals)-\(match.awayGoals) \(match.awayName)."
        if !match.motmName.isEmpty {
            body += " MOTM: \(match.motmName)."
            motmTally[match.motmName, default: 0] += 1
        }
        addNews(.result, isDerby ? "Derby \(outcome.lowercased())! (matchday \(day))" : "\(outcome) on matchday \(day)", body)

        if isSeasonOver { recordSeasonHonours() }
        live = nil
        persist()
    }

    /// Commits a finished live cup tie: records the result (penalties if
    /// drawn), applies player effects, and resolves the rest of the round.
    func finishLiveCupTie(_ match: LiveMatch) {
        if let index = cupTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            cupTies[index].homeGoals = match.homeGoals
            cupTies[index].awayGoals = match.awayGoals
            cupTies[index].winnerIndex = winner
            cupTies[index].onPenalties = pens
            cupTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeCupRound()
        live = nil
        persist()
    }

    /// Applies injuries, suspensions, ratings and morale from a live match
    /// (shared by league and cup, without touching the table or the board).
    func applyLivePlayerEffects(_ match: LiveMatch) {
        for out in match.injuredOut {
            setInjury(clubIndex: out.side == .home ? match.homeIndex : match.awayIndex,
                      playerID: out.id, weeks: Int.random(in: 2...5))
        }
        for red in match.sentOff {
            setSuspension(clubIndex: red.side == .home ? match.homeIndex : match.awayIndex,
                          playerID: red.id, matches: 1)
        }
        for (id, rating) in match.userPlayerRatingsByID {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].ratingPoints += rating
                clubs[userClubIndex].players[index].apps += 1
                clubs[userClubIndex].players[index].recentRatings.append(rating)
                if clubs[userClubIndex].players[index].recentRatings.count > 5 {
                    clubs[userClubIndex].players[index].recentRatings.removeFirst()
                }
            }
        }
        let userScored = match.userSide == .home ? match.homeGoals : match.awayGoals
        let userConceded = match.userSide == .home ? match.awayGoals : match.homeGoals
        let won = userScored > userConceded
        let draw = userScored == userConceded
        creditAssistsAndCleanSheet(match)
        for id in match.userAppearedIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                let delta = won ? Int.random(in: 3...8) : (draw ? Int.random(in: -1...2) : -Int.random(in: 3...8))
                clubs[userClubIndex].players[index].morale = min(100, max(0, clubs[userClubIndex].players[index].morale + delta))
            }
        }
        let appeared = clubs[userClubIndex].players.filter { match.userAppearedIDs.contains($0.id) }
        // A continental away trip costs extra condition on top of the
        // match itself — real travel fatigue, not just the 90 minutes.
        let isEuropeanAway = !match.isUserHome
            && (match.competition.contains(Self.euroName) || match.competition.contains(Self.uefaCupName))
        applyMatchFitness(clubIndex: userClubIndex, xi: appeared, extraFatigue: isEuropeanAway)
        if isEuropeanAway {
            addNews(.info, "Travel toll", "The away trip to Europe leaves the squad a little more fatigued than usual.")
        }
    }

    /// Credits the user's own players with assists and a goalkeeper clean
    /// sheet for this match — shared by both the league path
    /// (`finishLiveMatch`) and the cup paths (`applyLivePlayerEffects`),
    /// same reasoning as why `apps`/`ratingPoints` are only ever tracked
    /// for the user's own club: there's no individual per-player season
    /// tracking for the opposition in a live match.
    func creditAssistsAndCleanSheet(_ match: LiveMatch) {
        let assistIDs = match.userSide == .home ? match.homeAssistIDs : match.awayAssistIDs
        for id in assistIDs where clubs[userClubIndex].players.contains(where: { $0.id == id }) {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].assists += 1
            }
        }
        let userConceded = match.userSide == .home ? match.awayGoals : match.homeGoals
        guard userConceded == 0 else { return }
        let userSquad = match.userSide == .home ? match.homeOnPitch : match.awayOnPitch
        guard let keeper = userSquad.first(where: { $0.onPitch && $0.player.position == .goalkeeper }),
              let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == keeper.id }) else { return }
        clubs[userClubIndex].players[index].cleanSheets += 1
    }

    /// Drops match fitness for the players who featured in a fixture.
    /// `extraFatigue` adds an extra hit on top — used for a European away
    /// trip, where travel itself takes something out of the squad.
    func applyMatchFitness(clubIndex: Int, xi: [Player], extraFatigue: Bool = false) {
        let ids = Set(xi.map { $0.id })
        let extra = extraFatigue ? Int.random(in: 6...12) : 0
        for index in clubs[clubIndex].players.indices where ids.contains(clubs[clubIndex].players[index].id) {
            clubs[clubIndex].players[index].fitness = max(30, clubs[clubIndex].players[index].fitness - Int.random(in: 10...20) - extra)
        }
    }

    func incrementGoal(clubIndex: Int, playerID: UUID) {
        if let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) {
            clubs[clubIndex].players[index].goals += 1
        }
    }

    func setInjury(clubIndex: Int, playerID: UUID, weeks: Int) {
        if let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) {
            let physioFactor = clubIndex == userClubIndex
                ? (1.0 - Double(staffLevel(.physio)) * 0.1 - Double(clubs[clubIndex].medicalCentreLevel) * 0.03) : 1.0
            let scaled = max(1, Int(Double(weeks) * clubs[clubIndex].players[index].durability.injuryDurationMultiplier * physioFactor))
            clubs[clubIndex].players[index].injuryWeeks = max(clubs[clubIndex].players[index].injuryWeeks, scaled)
            clubs[clubIndex].players[index].injuriesThisSeason += 1
        }
    }

    func setSuspension(clubIndex: Int, playerID: UUID, matches: Int) {
        if let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) {
            clubs[clubIndex].players[index].suspensionMatches = max(clubs[clubIndex].players[index].suspensionMatches, matches)
        }
    }

    func liveScorerNames(_ match: LiveMatch) -> [String] {
        func names(_ ids: [UUID], clubIndex: Int) -> [String] {
            ids.compactMap { id in
                clubs[clubIndex].players.first { $0.id == id }
                    .map { "\($0.name) (\(clubs[clubIndex].shortName))" }
            }
        }
        return names(match.homeScorerIDs, clubIndex: match.homeIndex)
            + names(match.awayScorerIDs, clubIndex: match.awayIndex)
    }

    /// The starting XI and the available bench for a club going into a match.
    func matchLineupAndBench(forClubIndex index: Int) -> (xi: [Player], bench: [Player]) {
        let club = clubs[index]
        let xi = index == userClubIndex
            ? userStartingXI()
            : bestXI(for: club, formation: aiFormation(for: club, personality: personality(forClubIndex: index)))
        let xiIDs = Set(xi.map { $0.id })
        let bench = club.players.filter { $0.isAvailable && !xiIDs.contains($0.id) }
        return (xi, bench)
    }

    struct SquadNeed {
        let role: DetailedPosition
        let count: Int
    }

    /// Detailed positions where the user's squad is dangerously thin —
    /// fewer than two available players who can competently fill that
    /// role (a natural, secondary or related fit), sorted worst first.
    func squadNeeds() -> [SquadNeed] {
        DetailedPosition.allCases.compactMap { role in
            let count = userClub.players.filter { $0.isAvailable && $0.fit(for: role) >= 1 }.count
            return count < 2 ? SquadNeed(role: role, count: count) : nil
        }.sorted { $0.count < $1.count }
    }

    /// A handful of transfer-market targets that would plug the squad's
    /// thinnest positions and actually fit the budget — a lightweight
    /// "director of football" nudge, not a full scouting network.
    func suggestedTransferTargets(limit: Int = 5) -> [TransferTarget] {
        let thinRoles = Set(squadNeeds().map { $0.role })
        guard !thinRoles.isEmpty else { return [] }
        return Array(transferMarket
            .filter { target in
                thinRoles.contains { target.player.fit(for: $0) >= 1 }
                    && target.askingPrice <= userClub.transferBudget
                    && userClub.wageBill + target.player.wage <= userClub.wageBudget
            }
            .sorted { $0.player.rating > $1.player.rating }
            .prefix(limit))
    }

    /// The home ground name and capacity for a club, scaled by its stature.
    /// Ground capacity, scaled by division and prestige to roughly match
    /// real English (and European) crowd sizes — not exact, just the right
    /// order of magnitude at each level.
    func stadiumInfo(forClubIndex index: Int) -> (name: String, capacity: Int) {
        let club = clubs[index]
        let range: (min: Int, max: Int)
        switch club.divisionTier {
        case 0:  range = (20_000, 76_000)   // First Division
        case 1:  range = (10_000, 32_000)   // Second Division
        case 2:  range = (5_000, 20_000)    // Third Division
        case 3:  range = (3_000, 12_000)    // Fourth Division
        case Self.foreignTier: range = (40_000, 90_000)   // European giants
        default:
            // Spain/Italy/Germany/France: top-flight vs second-tier grounds.
            let topFlightTiers = [ForeignLeagues.spainTier1, ForeignLeagues.italyTier1,
                                  ForeignLeagues.germanyTier1, ForeignLeagues.franceTier1]
            range = topFlightTiers.contains(club.divisionTier) ? (14_000, 50_000) : (4_000, 22_000)
        }
        let normalized = min(1, max(0, Double(club.prestige - 45) / Double(94 - 45)))
        let base = range.min + Int(Double(range.max - range.min) * normalized)
        let expanded = Int(Double(base) * (1.0 + 0.08 * Double(club.stadiumExpansionLevel)))
        return ("\(club.name) Stadium", expanded)
    }

    /// The cost to expand a club's stadium by one level (0...5), in £000s —
    /// steeper each time, like a real construction project.
    func stadiumUpgradeCost(forClubIndex index: Int) -> Int? {
        let level = clubs[index].stadiumExpansionLevel
        guard level < 5 else { return nil }
        return 1_200 * (level + 1) * (level + 1)
    }

    /// Spends transfer budget to expand the user's stadium by one level.
    @discardableResult
    func investInStadium() -> String {
        guard let cost = stadiumUpgradeCost(forClubIndex: userClubIndex) else {
            return "The stadium is already at its maximum size."
        }
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget for this expansion (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        clubs[userClubIndex].stadiumExpansionLevel += 1
        let newCapacity = stadiumInfo(forClubIndex: userClubIndex).capacity
        addNews(.board, "Stadium expansion approved",
                "Work begins to grow \(userClub.name)'s ground — new capacity around \(newCapacity.formatted()).")
        logLedger("Investment", amount: -cost, "Stadium expansion")
        persist()
        return "Stadium expansion approved — new capacity around \(newCapacity.formatted())."
    }

    /// The cost to upgrade a club's youth academy by one level (0...5).
    func youthUpgradeCost(forClubIndex index: Int) -> Int? {
        let level = clubs[index].youthFacilityLevel
        guard level < 5 else { return nil }
        return 900 * (level + 1) * (level + 1)
    }

    /// Spends transfer budget to improve the user's youth academy —
    /// stronger, more frequent, and more likely to unearth a foreign
    /// wonderkid in future intakes.
    @discardableResult
    func investInYouthAcademy() -> String {
        guard let cost = youthUpgradeCost(forClubIndex: userClubIndex) else {
            return "The academy is already at its best facilities."
        }
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget for this upgrade (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        clubs[userClubIndex].youthFacilityLevel += 1
        addNews(.board, "Academy investment approved",
                "\(userClub.name) invest in better training facilities for the youth academy.")
        logLedger("Investment", amount: -cost, "Youth academy upgrade")
        persist()
        return "Academy upgraded to level \(clubs[userClubIndex].youthFacilityLevel)."
    }

    /// A matchday attendance for a fixture — a fraction of capacity that
    /// leans on the home club's own pull, nudged up for a big away side,
    /// a local derby, or a cup tie, and down for a struggling smaller club.
    func expectedAttendance(homeIndex: Int, awayIndex: Int, isCup: Bool) -> Int {
        let capacity = stadiumInfo(forClubIndex: homeIndex).capacity
        let homePrestige = clubs[homeIndex].prestige
        let awayPrestige = clubs[awayIndex].prestige
        let base = 0.5 + 0.42 * min(1, max(0, Double(homePrestige - 45) / Double(94 - 45)))
        let bigAwayDraw = awayPrestige > homePrestige + 8 ? 0.06 : 0.0
        let derbyBonus = areRivals(clubs[homeIndex].name, clubs[awayIndex].name) ? 0.10 : 0.0
        let cupBonus = isCup ? 0.04 : 0.0
        let formBonus = (Double(clubs[homeIndex].won) - Double(clubs[homeIndex].lost)) * 0.004
        // Only tracked for the user's own club — an angry fanbase stays
        // away, a buzzing one packs the ground beyond what form alone explains.
        let fanFactor = homeIndex == userClubIndex ? (Double(fanConfidence) - 50) * 0.0025 : 0.0
        // Premium pricing keeps some seats empty; cheap tickets fill them.
        let priceFactor = -Double(clubs[homeIndex].ticketPriceLevel - 3) * 0.03
        let occupancy = min(1.0, max(0.30, base + bigAwayDraw + derbyBonus + cupBonus + formBonus + fanFactor + priceFactor
                                      + Double.random(in: -0.05...0.05)))
        return Int(Double(capacity) * occupancy)
    }

    /// The per-head matchday revenue at a club's current ticket price
    /// level, in whole pounds.
    func pricePerHead(forClubIndex index: Int) -> Int {
        10 + clubs[index].ticketPriceLevel * 8
    }

    /// Sets the user's ticket price level (1 cheap ... 5 premium). Raising
    /// prices earns more per head but costs some attendance and fan
    /// goodwill; cutting them does the reverse.
    @discardableResult
    func setTicketPriceLevel(_ level: Int) -> String {
        let clamped = min(5, max(1, level))
        let previous = clubs[userClubIndex].ticketPriceLevel
        guard clamped != previous else { return "Ticket prices unchanged." }
        clubs[userClubIndex].ticketPriceLevel = clamped
        persist()
        if clamped > previous {
            fanConfidence = max(0, fanConfidence - (clamped - previous) * 4)
            addNews(.board, "Ticket prices raised", "The club raises ticket prices — some supporters grumble about the cost of watching their team.")
            return "Ticket prices raised. Fans aren't thrilled."
        } else {
            fanConfidence = min(100, fanConfidence + (previous - clamped) * 3)
            addNews(.board, "Ticket prices cut", "The club lowers ticket prices, welcomed by supporters.")
            return "Ticket prices lowered. Fans approve."
        }
    }

}
