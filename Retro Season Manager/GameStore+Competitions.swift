//
//  GameStore+Competitions.swift
//  Retro Season Manager
//
//  The domestic cup, League Trophy, Community Trophy, Continental
//  Cup, Midweek Cup and Continental Super Cup.
//

import Foundation

extension GameStore {

    // MARK: - Domestic cup

    /// The date a given cup round is played (spread across the season).
    /// Every competition's round gap is a multiple of 7 days and its base
    /// offset lands on a different weekday than the league's, so no cup
    /// round can ever fall on the same date as a league fixture, at any
    /// round number — no rescheduling is needed.
    func cupRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 26 + (round - 1) * 28
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    /// A friendly name for a round given how many ties it contains.
    func cupRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:     return "Final"
        case 2:     return "Semi-finals"
        case 3...4: return "Quarter-finals"
        default:    return "Round \(cupRound)"
        }
    }

    var cupRoundLabel: String {
        cupWinnerName != nil ? "Completed" : cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count)
    }

    /// Draws the first cup round from all clubs in the pyramid.
    func startCup() {
        cupWinnerName = nil
        cupRound = 1
        cupTies = makeCupTies(from: Array(clubs.indices), round: 1)
    }

    /// Seeded draw: the stronger half is drawn against the weaker half so the
    /// big clubs are spread out (and lower sides get their shot at a giant).
    func makeCupTies(from indices: [Int], round: Int) -> [CupTie] {
        let ranked = indices.sorted { clubs[$0].prestige > clubs[$1].prestige }
        let half = ranked.count / 2
        var seeds = Array(ranked[0..<half]).shuffled()
        var unseeded = Array(ranked[half...]).shuffled()
        var ties: [CupTie] = []
        while !seeds.isEmpty && !unseeded.isEmpty {
            ties.append(CupTie(round: round, homeIndex: seeds.removeFirst(), awayIndex: unseeded.removeFirst()))
        }
        var rest = (seeds + unseeded).shuffled()
        while rest.count >= 2 {
            ties.append(CupTie(round: round, homeIndex: rest.removeFirst(), awayIndex: rest.removeFirst()))
        }
        if let bye = rest.first {
            ties.append(CupTie(round: round, homeIndex: bye, awayIndex: bye))
        }
        return ties
    }

    /// Simulates a knockout tie, deciding drawn ties on penalties. `magic`
    /// flattens the strength gap toward a coin-flip, so higher values produce
    /// more cup upsets.
    func simCupTie(_ homeIndex: Int, _ awayIndex: Int, magic: Double = 0) -> (hg: Int, ag: Int, winner: Int, pens: Bool) {
        if homeIndex == awayIndex { return (0, 0, homeIndex, false) }   // bye
        var homeStrength = strengthValue(bestXI(for: clubs[homeIndex], formation: aiFormation(for: clubs[homeIndex]))) + 30
        var awayStrength = strengthValue(bestXI(for: clubs[awayIndex], formation: aiFormation(for: clubs[awayIndex])))
        // A Cup Specialist genuinely raises its game in cup competition —
        // the first real effect on a tie's actual win probability this
        // flavour of identity has ever had (the similarly-named
        // `ManagerPersonality.cupSpecialist` only ever set a live
        // opponent's starting mentality, never the underlying odds).
        if clubIdentity(forClubIndex: homeIndex) == .cupSpecialist { homeStrength *= 1.08 }
        if clubIdentity(forClubIndex: awayIndex) == .cupSpecialist { awayStrength *= 1.08 }
        var ratio = homeStrength / (homeStrength + awayStrength)
        ratio = ratio * (1 - magic) + 0.5 * magic
        let hg = poisson(2.6 * ratio)
        let ag = poisson(2.6 * (1 - ratio))
        if hg != ag { return (hg, ag, hg > ag ? homeIndex : awayIndex, false) }
        let winner = Double.random(in: 0..<1) < ratio ? homeIndex : awayIndex
        return (hg, ag, winner, true)
    }

    /// Auto-plays a due cup round — but only when the user isn't in it (they
    /// play their own tie live).
    func maybeProcessCupRound() {
        guard cupRound > 0, cupWinnerName == nil, !cupTies.isEmpty else { return }
        guard currentDate >= cupRoundDate(cupRound) else { return }
        guard cupTies.contains(where: { !$0.played }) else { return }
        guard nextUserCupTie == nil else { return }   // the user must play theirs live
        concludeCupRound()
    }

    /// Simulates any remaining ties in the current round, reports the user's
    /// outcome, and draws the next round (or crowns a winner).
    func concludeCupRound() {
        for index in cupTies.indices where !cupTies[index].played {
            let result = simCupTie(cupTies[index].homeIndex, cupTies[index].awayIndex, magic: 0.28)
            cupTies[index].homeGoals = result.hg
            cupTies[index].awayGoals = result.ag
            cupTies[index].winnerIndex = result.winner
            cupTies[index].onPenalties = result.pens
            cupTies[index].played = true
        }

        // Headline the biggest giant-killing of the round.
        var upset: (gap: Int, text: String)?
        for tie in cupTies where !tie.isBye && tie.winnerIndex >= 0 {
            let loser = tie.winnerIndex == tie.homeIndex ? tie.awayIndex : tie.homeIndex
            let gap = clubs[tie.winnerIndex].divisionTier - clubs[loser].divisionTier
            if gap >= 2, upset == nil || gap > upset!.gap {
                upset = (gap, "\(clubs[tie.winnerIndex].name) (\(divisionName(clubs[tie.winnerIndex].divisionTier))) knock out \(clubs[loser].name)!")
            }
        }
        if let upset { addNews(.result, "\(Self.cupName) SHOCK", upset.text) }

        if let tie = cupTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let roundName = cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count)
            if roundName == "Quarter-finals" { reachedCupQuarterFinalThisSeason = true }
            if tie.isBye {
                addNews(.result, "\(Self.cupName): \(roundName)", "\(userClub.name) receive a bye to the next round.")
            } else {
                let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
                let advanced = tie.winnerIndex == userClubIndex
                let pens = tie.onPenalties ? " (on penalties)" : ""
                addNews(.result, "\(Self.cupName): \(roundName)",
                        "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(pens). "
                        + "\(userClub.name) \(advanced ? "advance vs \(opponent.shortName)." : "are knocked out by \(opponent.shortName).")")
            }
        }

        let winners = cupTies.map { $0.winnerIndex }
        if winners.count == 1 {
            let winnerIndex = winners[0]
            cupWinnerName = clubs[winnerIndex].name
            cupWinnerID = clubs[winnerIndex].id
            clubs[winnerIndex].transferBudget += 1_300
            addNews(.board, "\(Self.cupName) winners", "\(cupWinnerName!) lift the \(Self.cupName)!")
            // Celebrate the moment the cup is actually lifted, rather than
            // leaving the payoff to a batched season-end achievement —
            // unlock(_:) is idempotent, so recordSeasonHonours()'s own
            // later call to the same case at season end is a safe no-op.
            if winnerIndex == userClubIndex { unlock(.cupWinner) }
        } else {
            cupRound += 1
            cupTies = makeCupTies(from: winners, round: cupRound)
        }
    }

    // MARK: - League Trophy

    /// The date a given League Trophy round is played — offset from the FA
    /// Cup's own rounds so the two competitions don't collide.
    func leagueCupRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 9 + (round - 1) * 28
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    func leagueCupRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:     return "Final"
        case 2:     return "Semi-finals"
        case 3...4: return "Quarter-finals"
        default:    return "Round \(leagueCupRound)"
        }
    }

    var leagueCupRoundLabel: String {
        leagueCupWinnerName != nil ? "Completed" : leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count)
    }

    /// Draws the first League Trophy round from all clubs in the pyramid.
    func startLeagueCup() {
        leagueCupWinnerName = nil
        leagueCupWinnerID = nil
        leagueCupRound = 1
        leagueCupTies = makeCupTies(from: Array(clubs.indices), round: 1)
    }

    /// The user's live League Trophy tie in the current round (excludes byes), if any.
    var nextUserLeagueCupTie: CupTie? {
        guard leagueCupWinnerName == nil else { return nil }
        return leagueCupTies.first { !$0.played && !$0.isBye && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    var nextUserLeagueCupDate: Date? {
        nextUserLeagueCupTie.map { leagueCupRoundDate($0.round) }
    }

    var isUserLeagueCupToday: Bool {
        guard let date = nextUserLeagueCupDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    /// The League Trophy ties scheduled on a given day, for the calendar.
    func leagueCupTies(onDate day: Date) -> [CupTie] {
        guard leagueCupRound > 0, Self.calendar.isDate(leagueCupRoundDate(leagueCupRound), inSameDayAs: day) else { return [] }
        return leagueCupTies
    }

    /// Auto-plays a due League Trophy round when the user isn't in it.
    func maybeProcessLeagueCupRound() {
        guard leagueCupRound > 0, leagueCupWinnerName == nil, !leagueCupTies.isEmpty else { return }
        guard currentDate >= leagueCupRoundDate(leagueCupRound) else { return }
        guard leagueCupTies.contains(where: { !$0.played }) else { return }
        guard nextUserLeagueCupTie == nil else { return }
        concludeLeagueCupRound()
    }

    func concludeLeagueCupRound() {
        for index in leagueCupTies.indices where !leagueCupTies[index].played {
            let result = simCupTie(leagueCupTies[index].homeIndex, leagueCupTies[index].awayIndex, magic: 0.32)
            leagueCupTies[index].homeGoals = result.hg
            leagueCupTies[index].awayGoals = result.ag
            leagueCupTies[index].winnerIndex = result.winner
            leagueCupTies[index].onPenalties = result.pens
            leagueCupTies[index].played = true
        }

        if let tie = leagueCupTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let roundName = leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count)
            if tie.isBye {
                addNews(.result, "\(Self.leagueCupName): \(roundName)", "\(userClub.name) receive a bye to the next round.")
            } else {
                let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
                let advanced = tie.winnerIndex == userClubIndex
                let pens = tie.onPenalties ? " (on penalties)" : ""
                addNews(.result, "\(Self.leagueCupName): \(roundName)",
                        "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(pens). "
                        + "\(userClub.name) \(advanced ? "advance vs \(opponent.shortName)." : "are knocked out by \(opponent.shortName).")")
            }
        }

        let winners = leagueCupTies.map { $0.winnerIndex }
        if winners.count == 1 {
            let winnerIndex = winners[0]
            leagueCupWinnerName = clubs[winnerIndex].name
            leagueCupWinnerID = clubs[winnerIndex].id
            clubs[winnerIndex].transferBudget += 700
            addNews(.board, "\(Self.leagueCupName) winners", "\(leagueCupWinnerName!) lift the \(Self.leagueCupName)!")
            if winnerIndex == userClubIndex { unlock(.cupWinner) }
        } else {
            leagueCupRound += 1
            leagueCupTies = makeCupTies(from: winners, round: leagueCupRound)
        }
    }

    func finishLiveLeagueCupTie(_ match: LiveMatch) {
        if let index = leagueCupTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            leagueCupTies[index].homeGoals = match.homeGoals
            leagueCupTies[index].awayGoals = match.awayGoals
            leagueCupTies[index].winnerIndex = winner
            leagueCupTies[index].onPenalties = pens
            leagueCupTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeLeagueCupRound()
        live = nil
        persist()
    }

    // MARK: - Community Trophy

    /// The Community Trophy is played early in the pre-season.
    func communityShieldDate() -> Date {
        Self.calendar.date(byAdding: .day, value: 24, to: seasonStartDate) ?? seasonStartDate
    }

    /// Sets up the Community Trophy between last season's champion and cup winner.
    func startCommunityShield() {
        communityShieldTie = nil
        communityShieldWinnerName = nil
        cupWinnerID = nil
        guard let championID = lastSeasonChampionID,
              let champion = clubs.firstIndex(where: { $0.id == championID }) else { return }
        var opponent = lastSeasonCupWinnerID.flatMap { id in clubs.firstIndex { $0.id == id } }
        // If the champion also won the cup (or the winner is gone), use the runner-up.
        if opponent == nil || opponent == champion {
            opponent = lastSeasonRunnerUpID.flatMap { id in clubs.firstIndex { $0.id == id } }
        }
        guard let away = opponent, away != champion else { return }
        communityShieldTie = CupTie(round: 0, homeIndex: champion, awayIndex: away)
    }

    var nextUserCommunityShieldTie: CupTie? {
        guard let tie = communityShieldTie, !tie.played,
              tie.homeIndex == userClubIndex || tie.awayIndex == userClubIndex else { return nil }
        return tie
    }

    var isUserCommunityShieldToday: Bool {
        guard nextUserCommunityShieldTie != nil else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: communityShieldDate())
    }

    /// Resolves any pre-season friendly whose date has arrived. Always
    /// auto-resolved (never live) — the point is low-stakes fitness work,
    /// not a match to sit through. Result is flavour only: no league
    /// record, goalscorer tally or fitness drain, just a light sharpening
    /// for anyone who was short of full fitness.
    func maybeProcessFriendlies() {
        for index in friendlyFixtures.indices where !friendlyFixtures[index].played
                && currentDate >= friendlyDate(friendlyFixtures[index].matchday) {
            let fixture = friendlyFixtures[index]
            let homeXI = matchXI(forClubIndex: fixture.homeIndex)
            let awayXI = matchXI(forClubIndex: fixture.awayIndex)
            let homeStrength = strengthValue(homeXI) + 15.0
            let awayStrength = strengthValue(awayXI)
            let ratio = homeStrength / (homeStrength + awayStrength)
            let homeGoals = poisson(2.4 * ratio)
            let awayGoals = poisson(2.4 * (1.0 - ratio))
            friendlyFixtures[index].played = true
            friendlyFixtures[index].homeGoals = homeGoals
            friendlyFixtures[index].awayGoals = awayGoals
            for player in homeXI + awayXI {
                sharpenFitness(playerID: player.id)
            }
            let home = clubs[fixture.homeIndex].name
            let away = clubs[fixture.awayIndex].name
            addNews(.result, "Pre-season friendly", "\(home) \(homeGoals) - \(awayGoals) \(away).")
        }
    }

    /// A friendly builds fitness rather than draining it, the opposite of a
    /// competitive match — that's the whole point of playing one.
    func sharpenFitness(playerID: UUID) {
        for clubIndex in clubs.indices {
            guard let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) else { continue }
            clubs[clubIndex].players[index].fitness = min(100, clubs[clubIndex].players[index].fitness + 10)
            return
        }
    }

    func maybeProcessCommunityShield() {
        guard let tie = communityShieldTie, !tie.played else { return }
        guard currentDate >= communityShieldDate() else { return }
        guard nextUserCommunityShieldTie == nil else { return }   // user plays it live
        resolveCommunityShield(homeGoals: nil, awayGoals: nil)
    }

    /// Resolves the Community Trophy — from a live result if given, else simulated.
    func resolveCommunityShield(homeGoals: Int?, awayGoals: Int?) {
        guard var tie = communityShieldTie else { return }
        if let hg = homeGoals, let ag = awayGoals {
            tie.homeGoals = hg; tie.awayGoals = ag
            if hg != ag { tie.winnerIndex = hg > ag ? tie.homeIndex : tie.awayIndex }
            else {
                let hs = strengthValue(bestXI(for: clubs[tie.homeIndex], formation: aiFormation(for: clubs[tie.homeIndex])))
                let aws = strengthValue(bestXI(for: clubs[tie.awayIndex], formation: aiFormation(for: clubs[tie.awayIndex])))
                tie.winnerIndex = Double.random(in: 0..<1) < hs / (hs + aws) ? tie.homeIndex : tie.awayIndex
                tie.onPenalties = true
            }
        } else {
            let result = simCupTie(tie.homeIndex, tie.awayIndex)
            tie.homeGoals = result.hg; tie.awayGoals = result.ag
            tie.winnerIndex = result.winner; tie.onPenalties = result.pens
        }
        tie.played = true
        communityShieldTie = tie
        communityShieldWinnerName = clubs[tie.winnerIndex].name
        clubs[tie.winnerIndex].transferBudget += 300
        addNews(.result, "\(Self.communityShieldName)",
                "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(tie.onPenalties ? " (pens)" : "") — \(communityShieldWinnerName!) win the \(Self.communityShieldName).")
    }

    func finishLiveCommunityShield(_ match: LiveMatch) {
        applyLivePlayerEffects(match)
        resolveCommunityShield(homeGoals: match.homeGoals, awayGoals: match.awayGoals)
        live = nil
        persist()
    }

    // MARK: - Continental Cup

    /// The date a Continental Cup round is played.
    func euroRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 55 + (round - 1) * 42
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    func euroRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:  return "Final"
        case 2:  return "Semi-finals"
        default: return "Quarter-finals"
        }
    }

    /// The global indices of the foreign clubs.
    var foreignClubIndices: [Int] {
        clubs.indices.filter { clubs[$0].divisionTier == Self.foreignTier }
    }

    /// A readable division label for a club (handles foreign clubs).
    func clubDivisionLabel(forClubIndex index: Int) -> String {
        guard clubs.indices.contains(index) else { return "" }
        let tier = clubs[index].divisionTier
        if tier == Self.foreignTier { return "European club" }
        if let division = ForeignLeagues.all.first(where: { $0.divisionTier == tier }) { return division.label }
        return divisionName(tier)
    }

    var euroRoundLabel: String {
        euroWinnerName != nil ? "Completed" : euroRoundName(tieCount: euroTies.count)
    }

    /// Whether the user's club is in this season's Continental Cup.
    var userInEurope: Bool {
        euroTies.contains { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }
            || euroWinnerName != nil && europeanQualifierIDs.contains(userClub.id)
    }

    /// Seeds the Continental Cup with the four qualifiers (last season's PL top 4,
    /// or the strongest PL clubs in season one).
    func startEuropeanCup() {
        euroWinnerName = nil
        euroWinnerID = nil
        euroRound = 0
        euroTies = []
        var english = europeanQualifierIDs.compactMap { id in clubs.firstIndex { $0.id == id } }
        if english.count < 4 {
            // Season one: seed by prestige (no prior table yet).
            english = Array(clubIndices(inTier: 0).sorted { clubs[$0].prestige > clubs[$1].prestige }.prefix(4))
        }
        english = Array(english.prefix(4))
        // Eight-team field: four English qualifiers + four of this season's foreign giants.
        let field = (english + seasonForeignAllocation.europe).shuffled()
        guard field.count >= 2 else { return }
        euroRound = 1
        euroTies = makeEuroTies(from: field, round: 1)
    }

    /// This season's random split of the foreign pool between the European
    /// Cup and the Midweek Cup.
    /// The elite eight plus each of Spain/Italy/Germany/France's strongest
    /// club this season — the pool Continental Cup and Midweek Cup qualification
    /// draws from, so the continental field has some real variety.
    var europeanCandidateIndices: [Int] {
        var candidates = foreignClubIndices
        let topFlightTiers = [ForeignLeagues.spainTier1, ForeignLeagues.italyTier1,
                              ForeignLeagues.germanyTier1, ForeignLeagues.franceTier1]
        for tier in topFlightTiers {
            if let best = clubs.indices.filter({ clubs[$0].divisionTier == tier })
                .max(by: { clubs[$0].prestige < clubs[$1].prestige }) {
                candidates.append(best)
            }
        }
        // Winning the domestic cup earns a European route too, even for a
        // club that isn't the country's biggest name — the same real-world
        // rule that lets a cup upset punch above its prestige.
        for winner in foreignCupWinnerIndices where !candidates.contains(winner) {
            candidates.append(winner)
        }
        return candidates
    }

    func allocateForeignClubsForSeason() {
        let shuffled = europeanCandidateIndices.shuffled()
        seasonForeignAllocation = (Array(shuffled.prefix(4)), Array(shuffled.dropFirst(4).prefix(4)))
    }

    /// The non-playable countries' own domestic cups, resolved abstractly
    /// at season's end — not a full bracket, just a plausible winner
    /// weighted by prestige (upsets can and do happen), whose reward is a
    /// genuine route into next season's European qualification pool.
    func resolveForeignDomesticCups() {
        let cups: [(country: String, name: String, tiers: [Int])] = [
            ("Spain", "Copa del Rey", [ForeignLeagues.spainTier1, ForeignLeagues.spainTier2]),
            ("Italy", "Coppa Italia", [ForeignLeagues.italyTier1, ForeignLeagues.italyTier2]),
            ("Germany", "DFB-Pokal", [ForeignLeagues.germanyTier1, ForeignLeagues.germanyTier2]),
            ("France", "Coupe de France", [ForeignLeagues.franceTier1, ForeignLeagues.franceTier2]),
        ]
        var winners: [Int] = []
        for cup in cups {
            let candidates = clubs.indices.filter { cup.tiers.contains(clubs[$0].divisionTier) }
            guard let winnerIndex = weightedRandomIndex(from: candidates, weight: { Double(clubs[$0].prestige * clubs[$0].prestige) })
            else { continue }
            winners.append(winnerIndex)
            addNews(.world, "\(cup.name) winners",
                    "\(clubs[winnerIndex].name) win the \(cup.name), securing a route into next season's European draw.")
            bumpForeignPrestige(clubIndex: winnerIndex, by: 1)
        }
        foreignCupWinnerIndices = winners
    }

    /// A small, capped prestige nudge for a foreign (non-playable) club's
    /// silverware — so a country's footballing landscape drifts over a
    /// long career instead of staying frozen at its 2000/01 snapshot.
    /// Playable English-pyramid clubs are untouched; their prestige only
    /// moves via the deliberate, one-off ownership-change events.
    func bumpForeignPrestige(clubIndex: Int, by amount: Int) {
        guard clubs[clubIndex].divisionTier >= 4 else { return }
        clubs[clubIndex].prestige = min(95, clubs[clubIndex].prestige + amount)
    }

    func makeEuroTies(from indices: [Int], round: Int) -> [CupTie] {
        var ties: [CupTie] = []
        var i = 0
        while i + 1 < indices.count {
            ties.append(CupTie(round: round, homeIndex: indices[i], awayIndex: indices[i + 1]))
            i += 2
        }
        return ties
    }

    /// Auto-plays a due European round unless the user is in it (they play live).
    func maybeProcessEuroRound() {
        guard euroRound > 0, euroWinnerName == nil, !euroTies.isEmpty else { return }
        guard currentDate >= euroRoundDate(euroRound) else { return }
        guard euroTies.contains(where: { !$0.played }) else { return }
        guard nextUserEuroTie == nil else { return }   // user plays their tie live
        concludeEuroRound()
    }

    func concludeEuroRound() {
        for index in euroTies.indices where !euroTies[index].played {
            let result = simCupTie(euroTies[index].homeIndex, euroTies[index].awayIndex)
            euroTies[index].homeGoals = result.hg
            euroTies[index].awayGoals = result.ag
            euroTies[index].winnerIndex = result.winner
            euroTies[index].onPenalties = result.pens
            euroTies[index].played = true
        }

        if let tie = euroTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
            let advanced = tie.winnerIndex == userClubIndex
            addNews(.result, "\(Self.euroName): \(euroRoundName(tieCount: euroTies.count))",
                    "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(tie.onPenalties ? " (pens)" : ""). "
                    + "\(userClub.name) \(advanced ? "go through vs \(opponent.shortName)." : "are out, beaten by \(opponent.shortName).")")
        }

        let winners = euroTies.map { $0.winnerIndex }
        if winners.count == 1 {
            euroWinnerName = clubs[winners[0]].name
            euroWinnerID = clubs[winners[0]].id
            clubs[winners[0]].transferBudget += 6_500
            bumpForeignPrestige(clubIndex: winners[0], by: 3)
            addNews(.board, "\(Self.euroName) winners", "\(euroWinnerName!) are champions of Europe!")
            if winners[0] == userClubIndex { unlock(.europeanGlory) }
        } else {
            euroRound += 1
            euroTies = makeEuroTies(from: winners, round: euroRound)
        }
    }

    /// Commits the user's finished live European tie, then resolves the round.
    func finishLiveEuroTie(_ match: LiveMatch) {
        if let index = euroTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            euroTies[index].homeGoals = match.homeGoals
            euroTies[index].awayGoals = match.awayGoals
            euroTies[index].winnerIndex = winner
            euroTies[index].onPenalties = pens
            euroTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeEuroRound()
        live = nil
        persist()
    }

    // MARK: - Midweek Cup

    /// The date a Midweek Cup round is played — offset from the European
    /// Cup's own rounds so the two competitions don't collide.
    func uefaCupRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 45 + (round - 1) * 42
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    func uefaCupRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:     return "Final"
        case 2:     return "Semi-finals"
        case 3...4: return "Quarter-finals"
        default:    return "Round \(uefaCupRound)"
        }
    }

    var uefaCupRoundLabel: String {
        uefaCupWinnerName != nil ? "Completed" : uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count)
    }

    /// Whether the user's club is in this season's Midweek Cup.
    var userInUefaCup: Bool {
        uefaCupTies.contains { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }
            || uefaCupWinnerName != nil && uefaCupQualifierIDs.contains(userClub.id)
    }

    /// Seeds the Midweek Cup with the next-best English clubs (those who just
    /// missed out on the Continental Cup) plus this season's other four
    /// foreign giants.
    func startUefaCup() {
        uefaCupWinnerName = nil
        uefaCupWinnerID = nil
        uefaCupRound = 0
        uefaCupTies = []
        var english = uefaCupQualifierIDs.compactMap { id in clubs.firstIndex { $0.id == id } }
        if english.count < 4 {
            // Season one: seed by prestige, just below the Continental Cup qualifiers.
            english = Array(clubIndices(inTier: 0).sorted { clubs[$0].prestige > clubs[$1].prestige }
                .dropFirst(4).prefix(4))
        }
        english = Array(english.prefix(4))
        let field = english + seasonForeignAllocation.uefa
        guard field.count >= 2 else { return }
        uefaCupRound = 1
        uefaCupTies = makeCupTies(from: field, round: 1)
    }

    /// The user's live Midweek Cup tie in the current round (excludes byes), if any.
    var nextUserUefaCupTie: CupTie? {
        guard uefaCupWinnerName == nil else { return nil }
        return uefaCupTies.first { !$0.played && !$0.isBye && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    var nextUserUefaCupDate: Date? {
        nextUserUefaCupTie.map { uefaCupRoundDate($0.round) }
    }

    var isUserUefaCupToday: Bool {
        guard let date = nextUserUefaCupDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    /// The Midweek Cup ties scheduled on a given day, for the calendar.
    func uefaCupTies(onDate day: Date) -> [CupTie] {
        guard uefaCupRound > 0, Self.calendar.isDate(uefaCupRoundDate(uefaCupRound), inSameDayAs: day) else { return [] }
        return uefaCupTies
    }

    /// Auto-plays a due Midweek Cup round unless the user is in it.
    func maybeProcessUefaCupRound() {
        guard uefaCupRound > 0, uefaCupWinnerName == nil, !uefaCupTies.isEmpty else { return }
        guard currentDate >= uefaCupRoundDate(uefaCupRound) else { return }
        guard uefaCupTies.contains(where: { !$0.played }) else { return }
        guard nextUserUefaCupTie == nil else { return }
        concludeUefaCupRound()
    }

    func concludeUefaCupRound() {
        for index in uefaCupTies.indices where !uefaCupTies[index].played {
            let result = simCupTie(uefaCupTies[index].homeIndex, uefaCupTies[index].awayIndex)
            uefaCupTies[index].homeGoals = result.hg
            uefaCupTies[index].awayGoals = result.ag
            uefaCupTies[index].winnerIndex = result.winner
            uefaCupTies[index].onPenalties = result.pens
            uefaCupTies[index].played = true
        }

        if let tie = uefaCupTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let roundName = uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count)
            if tie.isBye {
                addNews(.result, "\(Self.uefaCupName): \(roundName)", "\(userClub.name) receive a bye to the next round.")
            } else {
                let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
                let advanced = tie.winnerIndex == userClubIndex
                let pens = tie.onPenalties ? " (on penalties)" : ""
                addNews(.result, "\(Self.uefaCupName): \(roundName)",
                        "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(pens). "
                        + "\(userClub.name) \(advanced ? "advance vs \(opponent.shortName)." : "are knocked out by \(opponent.shortName).")")
            }
        }

        let winners = uefaCupTies.map { $0.winnerIndex }
        if winners.count == 1 {
            let winnerIndex = winners[0]
            uefaCupWinnerName = clubs[winnerIndex].name
            uefaCupWinnerID = clubs[winnerIndex].id
            clubs[winnerIndex].transferBudget += 3_500
            bumpForeignPrestige(clubIndex: winnerIndex, by: 2)
            addNews(.board, "\(Self.uefaCupName) winners", "\(uefaCupWinnerName!) win the \(Self.uefaCupName)!")
            if winnerIndex == userClubIndex { unlock(.europeanGlory) }
        } else {
            uefaCupRound += 1
            uefaCupTies = makeCupTies(from: winners, round: uefaCupRound)
        }
    }

    func finishLiveUefaCupTie(_ match: LiveMatch) {
        if let index = uefaCupTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            uefaCupTies[index].homeGoals = match.homeGoals
            uefaCupTies[index].awayGoals = match.awayGoals
            uefaCupTies[index].winnerIndex = winner
            uefaCupTies[index].onPenalties = pens
            uefaCupTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeUefaCupRound()
        live = nil
        persist()
    }

    // MARK: - Continental Super Cup

    /// The Continental Super Cup is played early in the pre-season, after the FA
    /// Community Shield.
    func uefaSuperCupDate() -> Date {
        Self.calendar.date(byAdding: .day, value: 31, to: seasonStartDate) ?? seasonStartDate
    }

    /// Sets up the Continental Super Cup between last season's Continental Cup and
    /// Midweek Cup winners, if both are known.
    func startUefaSuperCup() {
        uefaSuperCupTie = nil
        uefaSuperCupWinnerName = nil
        guard let euroWinnerID = lastSeasonEuroWinnerID, let uefaWinnerID = lastSeasonUefaCupWinnerID,
              let homeIndex = clubs.firstIndex(where: { $0.id == euroWinnerID }),
              let awayIndex = clubs.firstIndex(where: { $0.id == uefaWinnerID }), homeIndex != awayIndex
        else { return }
        uefaSuperCupTie = CupTie(round: 1, homeIndex: homeIndex, awayIndex: awayIndex)
    }

    var nextUserUefaSuperCupTie: CupTie? {
        guard let tie = uefaSuperCupTie, !tie.played,
              tie.homeIndex == userClubIndex || tie.awayIndex == userClubIndex else { return nil }
        return tie
    }

    var isUserUefaSuperCupToday: Bool {
        guard nextUserUefaSuperCupTie != nil else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: uefaSuperCupDate())
    }

    /// The Continental Super Cup tie, if it's played on the given day.
    func uefaSuperCupTie(onDate day: Date) -> CupTie? {
        guard let tie = uefaSuperCupTie, Self.calendar.isDate(uefaSuperCupDate(), inSameDayAs: day) else { return nil }
        return tie
    }

    /// Auto-plays the Continental Super Cup once its date arrives, unless the user is in it.
    func maybeProcessUefaSuperCup() {
        guard let tie = uefaSuperCupTie, !tie.played else { return }
        guard currentDate >= uefaSuperCupDate() else { return }
        guard nextUserUefaSuperCupTie == nil else { return }
        resolveUefaSuperCup(homeGoals: nil, awayGoals: nil)
    }

    func resolveUefaSuperCup(homeGoals: Int?, awayGoals: Int?) {
        guard var tie = uefaSuperCupTie else { return }
        let result: (hg: Int, ag: Int, winner: Int, pens: Bool)
        if let homeGoals, let awayGoals {
            if homeGoals != awayGoals {
                result = (homeGoals, awayGoals, homeGoals > awayGoals ? tie.homeIndex : tie.awayIndex, false)
            } else {
                let hs = strengthValue(bestXI(for: clubs[tie.homeIndex], formation: aiFormation(for: clubs[tie.homeIndex]))) + 20
                let aws = strengthValue(bestXI(for: clubs[tie.awayIndex], formation: aiFormation(for: clubs[tie.awayIndex])))
                let winner = Double.random(in: 0..<1) < hs / (hs + aws) ? tie.homeIndex : tie.awayIndex
                result = (homeGoals, awayGoals, winner, true)
            }
        } else {
            result = simCupTie(tie.homeIndex, tie.awayIndex)
        }
        tie.homeGoals = result.hg
        tie.awayGoals = result.ag
        tie.winnerIndex = result.winner
        tie.onPenalties = result.pens
        tie.played = true
        uefaSuperCupTie = tie
        uefaSuperCupWinnerName = clubs[result.winner].name
        addNews(.result, "\(Self.uefaSuperCupName)",
                "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(tie.onPenalties ? " (pens)" : "") — \(uefaSuperCupWinnerName!) win the \(Self.uefaSuperCupName).")
    }

    func finishLiveUefaSuperCup(_ match: LiveMatch) {
        resolveUefaSuperCup(homeGoals: match.homeGoals, awayGoals: match.awayGoals)
        live = nil
        persist()
    }

}
