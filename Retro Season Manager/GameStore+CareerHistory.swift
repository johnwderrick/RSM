//
//  GameStore+CareerHistory.swift
//  Retro Season Manager
//
//  End-of-season review and all-time career records.
//

import Foundation

extension GameStore {

    // MARK: - Season review

    /// True once the season is far enough along (past halfway) that the
    /// current league position genuinely predicts missing the board's
    /// objective, rather than just an early-season blip.
    var isObjectiveAtRisk: Bool {
        userClub.played >= Self.divisionSize / 2 && !objectiveMet()
    }

    /// Whether the board's objective was achieved this season.
    func objectiveMet() -> Bool {
        let position = userPosition
        if boardObjective.contains("Win the league") { return position == 1 }
        if boardObjective.contains("automatic promotion") { return position <= 2 }
        if boardObjective.contains("play-offs") { return position <= 6 }
        if boardObjective.contains("top 4") { return position <= 4 }
        if boardObjective.contains("top half") { return position <= Self.divisionSize / 2 }
        if boardObjective.contains("mid-table") { return position <= Self.divisionSize - 3 }
        if boardObjective.contains("relegation") { return position <= Self.divisionSize - 3 }
        return true
    }

    /// The board's end-of-season verdict.
    func seasonVerdict() -> String {
        objectiveMet()
            ? "The board are delighted — objective achieved."
            : "The board are disappointed — the objective was missed."
    }

    /// The user's standout performer, by average match rating.
    func playerOfSeason() -> Player? {
        userClub.players
            .filter { $0.apps > 0 }
            .max { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }
    }

    /// The user's leading scorer this season.
    func userTopScorer() -> Player? {
        userClub.players.filter { $0.goals > 0 }.max { $0.goals < $1.goals }
    }

    /// The league's overall top scorer (the Golden Boot).
    func goldenBoot() -> (player: Player, club: Club)? {
        topScorers(limit: 1).first
    }

    /// Unlocks a career achievement the first time its condition is met —
    /// a no-op on repeat calls, so callers can just re-check the condition
    /// every time without needing to track what's already unlocked.
    func unlock(_ kind: AchievementKind) {
        guard unlockedAchievements.insert(kind).inserted else { return }
        achievementUnlocks[kind] = AchievementUnlock(kind: kind, season: season, date: currentDate,
                                                      context: achievementContext(kind))
        careerAchievementPoints += kind.points
        pendingAchievementCelebration = kind
        addNews(.board, "Achievement unlocked", "🏅 \(kind.rawValue) — \(kind.subtitle)")
        SoundManager.shared.play(kind == .promotion ? .promotion : .trophyLift)
    }

    /// A short, specific line of context for the achievement's history
    /// page — grounded in real career state at the moment it happened,
    /// not generic flavour text.
    private func achievementContext(_ kind: AchievementKind) -> String {
        switch kind {
        case .promotion, .leagueTitle, .cupWinner, .europeanGlory, .treble, .invincible, .underdog, .greatEscape:
            return "\(userClub.name), \(seasonLabel)."
        case .dynasty:
            return "\(season) unbroken seasons at \(userClub.name)."
        case .youthRevolution:
            return "A youth-driven \(userClub.name) side, \(seasonLabel)."
        case .giantKiller:
            return "\(userClub.name) making a habit of punching above their weight."
        case .transferGenius:
            return "Smart business in the transfer market at \(userClub.name)."
        case .matches1000:
            return "A career spanning \(history.count) season\(history.count == 1 ? "" : "s") and counting."
        case .legendaryManager:
            return "A managerial career that will be remembered."
        case .wins50, .wins100, .wins200:
            return "Win number \(kind == .wins50 ? 50 : (kind == .wins100 ? 100 : 200)), \(userClub.name)."
        }
    }

    // MARK: - Hall of Fame induction

    /// Score needed to be inducted as a Club Legend, and the much higher
    /// bar for the Global Hall of Fame — tuned so a genuinely long-serving,
    /// prolific or decorated player clears the first without it being
    /// automatic, and only a handful of truly extraordinary careers ever
    /// reach the second.
    static let clubLegendThreshold = 50
    static let globalLegendThreshold = 95

    /// Evaluates a retiring player against real accumulated career data
    /// and inducts them as a Club Legend (or, for an extraordinary score,
    /// a Global Hall of Fame legend) if they clear the bar. Only called
    /// for the user's own club's retirees — appearances, ratings,
    /// captaincy and tenure are only ever tracked in that depth for
    /// whoever the user is currently managing (see Architecture.md).
    func evaluateForLegendStatus(_ retiree: Player, clubName: String) {
        let appearances = allTimeAppearances[retiree.name] ?? 0
        let goals = allTimeScorers[retiree.name] ?? 0
        let assists = allTimeAssists[retiree.name] ?? 0
        let cleanSheets = allTimeCleanSheets[retiree.name] ?? 0
        let ratingPoints = allTimeRatingPoints[retiree.name] ?? 0
        let averageRating = appearances > 0 ? ratingPoints / Double(appearances) : 0
        let seasonsAsCaptain = captainSeasonTally[retiree.id] ?? 0
        let individualAwards = motmTally[retiree.name] ?? 0
        let joinedSeason = clubTenureStart[retiree.id] ?? season
        let yearsAtClub = max(1, season - joinedSeason + 1)

        let trophiesWon: [String] = history
            .filter { $0.season >= joinedSeason && $0.season <= season && $0.userClub == clubName }
            .flatMap { record -> [String] in
                var won: [String] = []
                if record.champion == clubName { won.append("🏆 \(record.userDivision) title (\(record.label))") }
                if record.cupWinner == clubName { won.append("🏆 \(Self.cupName) (\(record.label))") }
                if record.euroWinner == clubName { won.append("🏆 \(Self.euroName) (\(record.label))") }
                if record.communityShieldWinner == clubName { won.append("🏆 \(Self.communityShieldName) (\(record.label))") }
                return won
            }

        // Goals matter more for a natural goalscorer than a defender;
        // clean sheets are the goalkeeper/defender's equivalent glory stat.
        let goalWeight: Double
        switch retiree.position {
        case .forward:    goalWeight = 0.55
        case .midfielder: goalWeight = 0.35
        case .defender:   goalWeight = 0.15
        case .goalkeeper: goalWeight = 0.05
        }

        let score =
            min(25, appearances / 12) +
            min(20, Int(Double(goals) * goalWeight)) +
            min(10, assists / 2) +
            min(15, cleanSheets / 2) +
            min(20, max(0, Int((averageRating - 60) * 1.3))) +
            min(10, seasonsAsCaptain * 3) +
            min(10, yearsAtClub) +
            min(15, trophiesWon.count * 3) +
            min(10, individualAwards)

        guard score >= Self.clubLegendThreshold else { return }
        let isGlobal = score >= Self.globalLegendThreshold

        let legend = ClubLegend(
            playerID: retiree.id, name: retiree.name, position: retiree.position,
            nationality: retiree.nationality, clubName: clubName,
            joinedSeason: joinedSeason, retiredSeason: season, finalAge: retiree.age,
            appearances: appearances, goals: goals, assists: assists, cleanSheets: cleanSheets,
            averageRating: averageRating, seasonsAsCaptain: seasonsAsCaptain,
            trophiesWon: trophiesWon, individualAwards: individualAwards,
            peakRating: hallOfFame[retiree.name]?.peakRating ?? retiree.rating,
            legendScore: score, isGlobalLegend: isGlobal,
            biography: legendBiography(retiree, clubName: clubName, yearsAtClub: yearsAtClub,
                                       appearances: appearances, goals: goals, assists: assists,
                                       trophiesWon: trophiesWon, seasonsAsCaptain: seasonsAsCaptain, isGlobal: isGlobal))
        clubLegends.append(legend)
        let headline = isGlobal ? "Global Hall of Fame" : "Club Legend"
        addNews(.board, headline,
               "\(retiree.name) has been inducted as a \(clubName) legend after \(yearsAtClub) season\(yearsAtClub == 1 ? "" : "s") at the club.",
               player: retiree, clubName: clubName)
        SoundManager.shared.play(.trophyLift)
    }

    private func legendBiography(_ player: Player, clubName: String, yearsAtClub: Int, appearances: Int, goals: Int,
                                 assists: Int, trophiesWon: [String], seasonsAsCaptain: Int, isGlobal: Bool) -> String {
        var sentences: [String] = []
        sentences.append("\(player.name) (\(player.nationality)) spent \(yearsAtClub) season\(yearsAtClub == 1 ? "" : "s") at \(clubName) as a \(player.detailedPosition.fullName.lowercased()), making \(appearances) appearance\(appearances == 1 ? "" : "s").")
        if goals > 0 {
            sentences.append("He found the net \(goals) time\(goals == 1 ? "" : "s")\(assists > 0 ? " and laid on \(assists) more for teammates" : ".").")
        } else if assists > 0 {
            sentences.append("A creative force, he set up \(assists) goal\(assists == 1 ? "" : "s") for his teammates.")
        }
        if seasonsAsCaptain > 0 {
            sentences.append("He wore the captain's armband for \(seasonsAsCaptain) season\(seasonsAsCaptain == 1 ? "" : "s").")
        }
        if !trophiesWon.isEmpty {
            sentences.append("His time at the club brought \(trophiesWon.count) major honour\(trophiesWon.count == 1 ? "" : "s").")
        }
        sentences.append(isGlobal
            ? "A career of genuine world class, remembered far beyond \(clubName)."
            : "A true \(clubName) great, still spoken of fondly by the fans.")
        return sentences.joined(separator: " ")
    }

    /// Score needed for the user's own managerial career to be considered
    /// legendary — same spirit and rough scale as a Club Legend's
    /// threshold, evaluated on trophies, longevity, reputation and win
    /// record rather than any single stat.
    static let legendaryManagerThreshold = 60

    /// Evaluates the user's whole managerial career so far — every club,
    /// not just the current one. Recomputed on demand rather than stored,
    /// since it should always reflect where the career stands right now.
    func legendaryManagerProfile() -> LegendaryManagerProfile {
        let totalSeasons = history.count
        let totalTrophies = careerHonours.filter { $0.contains("🏆") }.count
        let promotions = careerHonours.filter { $0.contains("Promoted") }.count
        let record = careerRecordByClub.values.reduce(into: ClubCareerRecord()) { total, next in
            total.wins += next.wins; total.draws += next.draws; total.losses += next.losses
        }
        let totalMatches = record.wins + record.draws + record.losses
        let winPercentage = totalMatches > 0 ? Int((Double(record.wins) / Double(totalMatches) * 100).rounded()) : 0

        let cv = managerCV()
        let clubsManaged = cv.count
        let longest = cv.max { $0.seasons < $1.seasons }
        let longestSpell = longest.map { (club: $0.club, seasons: $0.seasons) }

        let score =
            min(20, totalSeasons) +
            min(25, totalTrophies * 3) +
            min(10, promotions * 3) +
            min(20, winPercentage / 3) +
            min(15, managerReputation / 6) +
            min(10, longestSpell?.seasons ?? 0)

        let isLegendary = score >= Self.legendaryManagerThreshold

        var bio = "A managerial career spanning \(totalSeasons) season\(totalSeasons == 1 ? "" : "s")"
        bio += clubsManaged > 1 ? " across \(clubsManaged) clubs" : (longestSpell.map { " at \($0.club)" } ?? "")
        bio += ", winning \(winPercentage)% of matches managed."
        if totalTrophies > 0 {
            bio += " \(totalTrophies) major honour\(totalTrophies == 1 ? "" : "s") along the way."
        }
        bio += isLegendary
            ? " A genuinely legendary managerial career."
            : " Building toward a career worth remembering."

        return LegendaryManagerProfile(totalSeasons: totalSeasons, totalTrophies: totalTrophies,
                                       totalWins: record.wins, totalMatches: totalMatches, winPercentage: winPercentage,
                                       clubsManaged: clubsManaged, longestSpell: longestSpell,
                                       reputation: managerReputation, legendScore: score,
                                       isLegendary: isLegendary, biography: bio)
    }

    /// Career win totals cross round-number milestones mid-season, not
    /// just at the end of one — checked after every result.
    func checkWinMilestones() {
        let totalWins = careerRecordByClub.values.reduce(0) { $0 + $1.wins }
        if totalWins >= 50 { unlock(.wins50) }
        if totalWins >= 100 { unlock(.wins100) }
        if totalWins >= 200 { unlock(.wins200) }
        let totalMatches = careerRecordByClub.values.reduce(0) { $0 + $1.wins + $1.draws + $1.losses }
        if totalMatches >= 1000 { unlock(.matches1000) }
    }

    /// Records any honours the user won this season (called once at season end).
    func recordSeasonHonours() {
        guard lastHonourSeason != season else { return }
        lastHonourSeason = season
        if userPosition == 1 {
            careerHonours.append("🏆 \(divisionName(userDivisionTier)) title (\(seasonLabel))")
        }
        if cupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.cupName) (\(seasonLabel))")
        }
        if leagueCupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.leagueCupName) (\(seasonLabel))")
        }
        if userDivisionTier > 0 && userPosition <= 2 {
            careerHonours.append("⬆︎ Promoted from \(divisionName(userDivisionTier)) (\(seasonLabel))")
        }
        if euroWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.euroName) (\(seasonLabel))")
        }
        if uefaCupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.uefaCupName) (\(seasonLabel))")
        }
        if uefaSuperCupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.uefaSuperCupName) (\(seasonLabel))")
        }
        // Capture this season's First Division top 4 as next season's Europe
        // entrants, and the next four (5th-8th) as next season's Midweek Cup entrants.
        let plQualifiers = leagueTable(tier: 0)
        europeanQualifierIDs = plQualifiers.prefix(4).map { $0.id }
        if europeanQualifierIDs.contains(userClub.id) {
            addNews(.board, "European qualification", "\(userClub.name) have qualified for next season's \(Self.euroName).")
            if firstEuropeQualificationSeason == nil { firstEuropeQualificationSeason = season }
        }
        uefaCupQualifierIDs = plQualifiers.dropFirst(4).prefix(4).map { $0.id }
        if uefaCupQualifierIDs.contains(userClub.id) {
            addNews(.board, "European qualification", "\(userClub.name) have qualified for next season's \(Self.uefaCupName).")
            if firstEuropeQualificationSeason == nil { firstEuropeQualificationSeason = season }
        }
        if communityShieldWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.communityShieldName) (\(seasonLabel))")
        }
        // Capture this season's champion, runner-up and cup winner for the Community Trophy.
        let plTable = leagueTable(tier: 0)
        lastSeasonChampionID = plTable.first?.id
        lastSeasonRunnerUpID = plTable.dropFirst().first?.id
        lastSeasonCupWinnerID = cupWinnerID
        // Capture this season's Continental Cup and Midweek Cup winners for next
        // season's Continental Super Cup.
        lastSeasonEuroWinnerID = euroWinnerID
        lastSeasonUefaCupWinnerID = uefaCupWinnerID

        history.append(SeasonRecord(
            season: season, label: seasonLabel,
            userClub: userClub.name, userDivision: divisionName(userDivisionTier), userPosition: userPosition,
            champion: plTable.first?.name ?? "—",
            cupWinner: cupWinnerName ?? "—",
            euroWinner: euroWinnerName ?? "—",
            communityShieldWinner: communityShieldWinnerName ?? "—"))

        // Career achievement milestones tied to this season's outcome.
        let wonLeague = userPosition == 1
        let wonDomesticCup = cupWinnerName == userClub.name || leagueCupWinnerName == userClub.name
        let wonEurope = euroWinnerName == userClub.name || uefaCupWinnerName == userClub.name
        if userDivisionTier > 0 && userPosition <= 2 { unlock(.promotion) }
        if wonLeague { unlock(.leagueTitle) }
        if wonDomesticCup { unlock(.cupWinner) }
        if wonEurope { unlock(.europeanGlory) }
        if wonLeague && wonDomesticCup && wonEurope { unlock(.treble) }
        if userClub.lost == 0 && userClub.played >= 20 { unlock(.invincible) }
        if history.filter({ $0.userClub == userClub.name }).count >= 10 { unlock(.dynasty) }

        // A major trophy won while genuinely one of the smaller clubs in
        // the division — not just any title.
        let divisionTable = leagueTable(tier: userDivisionTier)
        if !divisionTable.isEmpty {
            let averagePrestige = divisionTable.reduce(0) { $0 + $1.prestige } / divisionTable.count
            if (wonLeague || wonDomesticCup || wonEurope) && userClub.prestige < averagePrestige - 8 {
                unlock(.underdog)
            }
            // Relegation is the bottom 3 (see `applyPromotionRelegation`) —
            // survived right on the edge of the drop zone.
            let safeFromBottom = divisionTable.count - userPosition
            if safeFromBottom == 3 || safeFromBottom == 4 { unlock(.greatEscape) }
        }
        // Five (or more) academy-age players who actually played, not just
        // made up the numbers, in the same season.
        let youthContributors = clubs[userClubIndex].players.filter { $0.age <= 21 && $0.apps >= 10 }.count
        if youthContributors >= 5 { unlock(.youthRevolution) }
        if legendaryManagerProfile().isLegendary { unlock(.legendaryManager) }

        // Accumulate all-time goal tallies across the game, celebrating a
        // round-number milestone crossed this season for the user's own
        // players — a small, recurring "that mattered" moment.
        let milestones = [10, 25, 50, 100, 150, 200, 250, 300]
        for club in clubs where club.divisionTier < 4 {
            for player in club.players where player.goals > 0 {
                let before = allTimeScorers[player.name, default: 0]
                let after = before + player.goals
                allTimeScorers[player.name] = after
                if club.id == userClub.id, let crossed = milestones.last(where: { before < $0 && after >= $0 }) {
                    addNews(.board, "Milestone reached",
                            "\(player.name) has now scored \(crossed)+ career goals for \(club.name).")
                }
            }
            for player in club.players where player.apps > 0 {
                allTimeAppearances[player.name, default: 0] += player.apps
                allTimeRatingPoints[player.name, default: 0] += player.ratingPoints
            }
            for player in club.players where player.assists > 0 {
                allTimeAssists[player.name, default: 0] += player.assists
            }
            for player in club.players where player.cleanSheets > 0 {
                allTimeCleanSheets[player.name, default: 0] += player.cleanSheets
            }
        }
        // Captaincy is only ever assigned at the user's own club, so this
        // is the one Hall of Fame tally that isn't accumulated game-wide.
        if let captainID {
            captainSeasonTally[captainID, default: 0] += 1
        }

        // Record peak ratings of the user's players for the Hall of Fame.
        for player in userClub.players {
            if let existing = hallOfFame[player.name], existing.peakRating >= player.rating { continue }
            hallOfFame[player.name] = HallEntry(name: player.name, position: player.position,
                                                peakRating: player.rating, peakSeason: seasonLabel)
        }

        checkSeasonObjectives(isSeasonEnd: true)
        checkAcademyGraduateBreakthroughs()
        checkFanFavourites()
        checkUserWonderkidBreakthroughs()
        checkSeasonStyleReaction()
        applySeasonTicketAttrition()
        updateReputation()
        checkForSacking()
        checkManagerContractRenewal()
        generateJobOffers()
    }

    /// Runs down the manager's own contract by a year at season's end. If
    /// it expires, the board either extends it (when confidence is decent)
    /// or lets it lapse — a distinct, calmer "time for a new challenge"
    /// moment from being sacked mid-tenure for poor results.
    func checkManagerContractRenewal() {
        guard !wasSacked else { return }
        managerContractYears -= 1
        guard managerContractYears <= 0 else { return }
        if boardConfidence >= 40 {
            let years = Int.random(in: 2...4)
            managerContractYears = years
            addNews(.board, "Contract extended",
                    "The board have extended your contract at \(userClub.name) for another \(years) year\(years == 1 ? "" : "s") — pleased with how things are going.")
        } else {
            wasSacked = true
            addNews(.board, "Contract not renewed",
                    "Your contract at \(userClub.name) has run its course and the board have decided not to renew it. You'll need to find a new club.")
        }
    }

    /// Adjusts reputation from the season's achievements and board mood.
    func updateReputation() {
        var delta = (boardConfidence - 50) / 10
        if userPosition == 1 { delta += 8 }
        if userDivisionTier > 0 && userPosition <= 2 { delta += 6 }
        if cupWinnerName == userClub.name { delta += 6 }
        if euroWinnerName == userClub.name { delta += 12 }
        if !objectiveMet() { delta -= 4 }
        let previous = managerReputation
        managerReputation = min(100, max(0, managerReputation + delta))
        checkReputationMilestones(previous: previous, current: managerReputation)
    }

    /// One-off news the first time reputation crosses a notable threshold —
    /// a sense of career progression beyond just the raw number going up.
    func checkReputationMilestones(previous: Int, current: Int) {
        let milestones: [(threshold: Int, message: String)] = [
            (50, "Your reputation has grown enough that mid-table clubs are starting to take real notice."),
            (65, "Bigger clubs are now watching your work closely — a genuinely elite job could be within reach."),
            (80, "Your reputation is elite — Europe's biggest clubs are aware of what you're building."),
            (95, "Few managers reach this level of reputation — you're spoken of alongside the very best."),
        ]
        for milestone in milestones where previous < milestone.threshold && current >= milestone.threshold {
            addNews(.board, "Reputation milestone", milestone.message)
        }
    }

    /// Sacks the manager if the board has entirely lost faith.
    func checkForSacking() {
        wasSacked = boardConfidence <= 12
        if wasSacked {
            managerReputation = max(0, managerReputation - 6)
            addNews(.board, "Sacked", "\(userClub.name) have relieved you of your duties. You must find a new club.")
        }
    }

    /// Offers the manager jobs from rival clubs, scaled to reputation.
    func generateJobOffers() {
        pendingJobOffers = []
        let domestic = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 }
        var candidates: [Int]
        if wasSacked {
            // Clubs within reach so the career can continue.
            candidates = domestic.filter { clubs[$0].prestige <= managerReputation + 4 }
                .sorted { clubs[$0].prestige > clubs[$1].prestige }
        } else {
            // Ambitious moves: bigger clubs the manager could realistically land.
            candidates = domestic.filter {
                clubs[$0].prestige >= userClub.prestige - 3 && clubs[$0].prestige <= managerReputation + 10
            }.sorted { clubs[$0].prestige > clubs[$1].prestige }
        }
        let count = wasSacked ? min(2, candidates.count) : (objectiveMet() ? Int.random(in: 0...2) : (Bool.random() ? 1 : 0))
        // A sacked manager must always have somewhere to go.
        if wasSacked && candidates.isEmpty, let fallback = domestic.min(by: { clubs[$0].prestige < clubs[$1].prestige }) {
            candidates = [fallback]
        }
        for index in candidates.prefix(max(count, wasSacked ? 1 : 0)) {
            pendingJobOffers.append(JobOffer(clubIndex: index, clubName: clubs[index].name,
                                             divisionName: divisionName(clubs[index].divisionTier),
                                             prestige: clubs[index].prestige,
                                             transferBudget: clubs[index].transferBudget,
                                             expectedObjective: previewObjective(forClubIndex: index)))
        }
    }

    /// Accepts a job offer; the move takes effect next season.
    func acceptJobOffer(_ offer: JobOffer) {
        pendingClubSwitch = offer.clubIndex
        addNews(.board, "New job agreed", "You will take over at \(offer.clubName) next season.")
    }

    /// Ends the career once `maxSeasons` is reached.
    func endCareer() {
        careerEnded = true
        persist()
    }

    /// Leaves a finished career: archives it permanently (see
    /// `LegacyArchive`), then discards the active save — the career itself
    /// stays browsable from the main menu even though the save is gone.
    func returnToMenuAfterCareer() {
        archiveLegacyCareer()
        careerEnded = false
        hasStarted = false
        if let id = currentSaveID { Self.deleteSave(id: id) }
        currentSaveID = nil
    }

    /// Builds and permanently saves a `LegacyCareer` snapshot of the
    /// just-finished career — everything `CareerEndView` shows, frozen at
    /// the moment the manager walks away.
    private func archiveLegacyCareer() {
        guard !history.isEmpty else { return }
        let timeline = careerTimeline().map { moment in
            LegacyCareerMoment(season: moment.season, year: moment.year, icon: moment.icon,
                               headline: moment.headline, detail: moment.detail)
        }
        let score = LegacyScoring.score(trophyCount: careerHonours.count, seasonsManaged: history.count,
                                        achievementPoints: careerAchievementPoints, legendCount: clubLegends.count)
        let topScorer = allTimeScorers.max { $0.value < $1.value }
            .map { LegacyRecordHolder(name: $0.key, value: $0.value, detail: "goals") }
        let topAppearances = allTimeAppearances.max { $0.value < $1.value }
            .map { LegacyRecordHolder(name: $0.key, value: $0.value, detail: "appearances") }
        let topMOTM = motmTally.max { $0.value < $1.value }
            .map { LegacyRecordHolder(name: $0.key, value: $0.value, detail: "MOTM awards") }
        let recordWin = userClub.recordWinMargin > 0
            ? LegacyRecordHolder(name: userClub.name, value: userClub.recordWinMargin, detail: userClub.recordWinDescription)
            : nil
        let bestSeason = history.min { $0.userPosition < $1.userPosition }
            .map { LegacyRecordHolder(name: $0.userClub, value: $0.userPosition, detail: "\($0.userDivision) · \($0.label)") }
        let topSales = transferHistory.filter { $0.action == "Sold" && ($0.fee ?? 0) > 0 }
            .sorted { ($0.fee ?? 0) > ($1.fee ?? 0) }.prefix(3)
        let topSignings = transferHistory.filter { $0.action == "Signed" && $0.otherClub != nil && ($0.fee ?? 0) > 0 }
            .sorted { ($0.fee ?? 0) > ($1.fee ?? 0) }.prefix(3)
        let career = LegacyCareer(id: UUID(), managerName: managerName, clubName: userClub.name,
                                  startYear: startYear, endYear: startYear + history.count,
                                  seasonsManaged: history.count, finalDivisionName: divisionName(userDivisionTier),
                                  careerHonours: careerHonours, autobiography: generateAutobiography(),
                                  timeline: timeline, achievementUnlocks: Array(achievementUnlocks.values),
                                  careerAchievementPoints: careerAchievementPoints, clubLegends: clubLegends,
                                  history: history, careerRecordByClub: careerRecordByClub,
                                  legacyScore: score, legacyTier: .forScore(score),
                                  recordBook: careerRecordBookLines(), archivedDate: Date(),
                                  topScorer: topScorer, topAppearances: topAppearances, topMOTM: topMOTM,
                                  recordWin: recordWin, bestSeason: bestSeason,
                                  topTransfers: Array(topSales) + Array(topSignings),
                                  frontPages: newspapers.filter { $0.importance >= .major })
        LegacyArchive.archive(career)
    }

    /// Formats the standout individual records of this career into
    /// display-ready lines, computed once here from data this snapshot
    /// otherwise doesn't keep (`allTimeScorers`, `transferHistory`, etc.)
    /// — frozen into the archive the same way `autobiography` freezes
    /// prose instead of storing raw beats.
    private func careerRecordBookLines() -> [String] {
        var lines: [String] = []
        if let top = allTimeScorers.max(by: { $0.value < $1.value }), top.value > 0 {
            lines.append("⚽ Top scorer: \(top.key) (\(top.value) goals)")
        }
        if let most = allTimeAppearances.max(by: { $0.value < $1.value }), most.value > 0 {
            lines.append("👕 Most appearances: \(most.key) (\(most.value))")
        }
        if let motm = motmTally.max(by: { $0.value < $1.value }), motm.value > 0 {
            lines.append("🌟 Most Man of the Match: \(motm.key) (\(motm.value))")
        }
        if let sale = transferHistory.filter({ $0.action == "Sold" && ($0.fee ?? 0) > 0 })
            .max(by: { ($0.fee ?? 0) < ($1.fee ?? 0) }) {
            lines.append("💰 Record sale: \(sale.playerName) to \(sale.otherClub ?? "another club") (\(formatMoney(sale.fee ?? 0)))")
        }
        if let signing = transferHistory.filter({ $0.action == "Signed" && $0.otherClub != nil && ($0.fee ?? 0) > 0 })
            .max(by: { ($0.fee ?? 0) < ($1.fee ?? 0) }) {
            lines.append("🖋️ Record signing: \(signing.playerName) from \(signing.otherClub ?? "another club") (\(formatMoney(signing.fee ?? 0)))")
        }
        return lines
    }

    /// The best XI across every division, by overall ability (Team of the Season).
    func teamOfTheSeason() -> [Player] {
        let everyone = clubs.filter { $0.divisionTier < 4 }.flatMap { $0.players }
        func top(_ position: Position, _ count: Int) -> [Player] {
            everyone.filter { $0.position == position }.sorted { $0.rating > $1.rating }.prefix(count).map { $0 }
        }
        return top(.goalkeeper, 1) + top(.defender, 4) + top(.midfielder, 3) + top(.forward, 3)
    }

    /// The short code of the club a player belongs to.
    func clubShort(forPlayerID id: UUID) -> String {
        clubs.first { $0.players.contains { $0.id == id } }?.shortName ?? "?"
    }

    // MARK: - All-time records

    func mostFrequent(_ names: [String]) -> (name: String, count: Int)? {
        var counts: [String: Int] = [:]
        for name in names where name != "—" { counts[name, default: 0] += 1 }
        return counts.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    /// The club with the most league titles across the career, and the count.
    func mostTitles() -> (name: String, count: Int)? { mostFrequent(history.map { $0.champion }) }
    func mostCups() -> (name: String, count: Int)? { mostFrequent(history.map { $0.cupWinner }) }
    func mostEuropeanCups() -> (name: String, count: Int)? { mostFrequent(history.map { $0.euroWinner }) }

    /// The all-time leading scorer in the game, and their goal total.
    func topCareerScorer() -> (name: String, goals: Int)? {
        allTimeScorers.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    /// The all-time leading appearance-maker in the game, and their total.
    func topCareerAppearances() -> (name: String, apps: Int)? {
        allTimeAppearances.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    /// One line of the manager's CV: a spell at one club (grouping
    /// consecutive seasons together, so two separate stints at the same
    /// club show as two lines), its length, match record, and the
    /// trophies won specifically during that spell.
    struct ManagerCVEntry: Identifiable {
        var id: String { "\(club)-\(startLabel)" }
        let club: String
        let startLabel: String
        let seasons: Int
        let record: ClubCareerRecord
        let trophies: [String]
    }

    /// The manager's full career history — every club managed, in order.
    func managerCV() -> [ManagerCVEntry] {
        guard !history.isEmpty else { return [] }
        var groups: [(club: String, startLabel: String, seasons: Int)] = []
        for record in history {
            if let last = groups.last, last.club == record.userClub {
                groups[groups.count - 1].seasons += 1
            } else {
                groups.append((club: record.userClub, startLabel: record.label, seasons: 1))
            }
        }
        let clubForLabel = Dictionary(uniqueKeysWithValues: history.map { ($0.label, $0.userClub) })
        return groups.map { group in
            let trophies = careerHonours.filter { honour in
                clubForLabel.contains { label, club in club == group.club && honour.contains("(\(label))") }
            }
            let record = careerRecordByClub[group.club] ?? ClubCareerRecord()
            return ManagerCVEntry(club: group.club, startLabel: group.startLabel, seasons: group.seasons,
                                   record: record, trophies: trophies)
        }
    }

    /// The best XI the user has ever managed, by peak rating per position.
    func bestEverXI() -> [HallEntry] {
        func top(_ position: Position, _ count: Int) -> [HallEntry] {
            hallOfFame.values.filter { $0.position == position }
                .sorted { $0.peakRating > $1.peakRating }
                .prefix(count).map { $0 }
        }
        return top(.goalkeeper, 1) + top(.defender, 4) + top(.midfielder, 3) + top(.forward, 3)
    }

    /// The user's honour count by type, for the records screen.
    func honourTally() -> (titles: Int, cups: Int, euros: Int, promotions: Int) {
        var t = 0, c = 0, e = 0, p = 0
        for h in careerHonours {
            if h.contains("title") { t += 1 }
            else if h.contains(Self.cupName) { c += 1 }
            else if h.contains(Self.euroName) { e += 1 }
            else if h.contains("Promoted") { p += 1 }
        }
        return (t, c, e, p)
    }

    /// A short description of the user's biggest win, if any.
    func biggestUserWin() -> String? {
        var best: (margin: Int, text: String)?
        for fixture in fixtures where fixture.played
            && (fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex) {
            let isHome = fixture.homeIndex == userClubIndex
            let us = isHome ? fixture.homeGoals : fixture.awayGoals
            let them = isHome ? fixture.awayGoals : fixture.homeGoals
            guard us > them else { continue }
            let margin = us - them
            if best == nil || margin > best!.margin {
                let opponent = clubs[isHome ? fixture.awayIndex : fixture.homeIndex]
                best = (margin, "\(us)-\(them) vs \(opponent.shortName)")
            }
        }
        return best?.text
    }
}
