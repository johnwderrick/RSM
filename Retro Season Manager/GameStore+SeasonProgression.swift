//
//  GameStore+SeasonProgression.swift
//  Retro Season Manager
//
//  Rolling from one season into the next.
//

import Foundation

extension GameStore {

    // MARK: - Season progression

    /// The relative worth of each division, top-heavy like the real game's
    /// finances — a First Division budget dwarfs a Fourth Division one.
    static let tierBudgetScale: [Double] = [1.0, 0.30, 0.10, 0.035]

    /// Pays end-of-season prize money by final position, scaled down within
    /// each division so lower tiers stay small relative to the top flight.
    static func seasonBudgetBonus(tier: Int, position: Int, startYear: Int = 2000) -> Int {
        let scale = tierBudgetScale[min(tier, tierBudgetScale.count - 1)]
        let base = 5_500.0 * scale
        let positionFactor = Double(divisionSize - position + 1) / Double(divisionSize)
        return max(30, Int(base * (0.4 + 0.6 * positionFactor) * economyMultiplier(startYear: startYear)))
    }

    /// A one-off bonus for silverware won this season, folded into the
    /// budget reset below rather than left as the old permanent add-on —
    /// most finals land after the transfer window has already closed, so
    /// the reward is really about strengthening the squad next season.
    func seasonTrophyBonus(for club: Club) -> Int {
        var bonus = 0
        if cupWinnerID == club.id { bonus += 1_300 }
        if leagueCupWinnerID == club.id { bonus += 700 }
        if euroWinnerID == club.id { bonus += 3_500 }
        if uefaCupWinnerID == club.id { bonus += 1_800 }
        if communityShieldWinnerName == club.name { bonus += 300 }
        if uefaSuperCupWinnerName == club.name { bonus += 500 }
        return Int(Double(bonus) * economyMultiplier(startYear: startYear))
    }

    /// Resets every English-pyramid club's transfer budget for the new
    /// season, rather than letting it accumulate forever. Built from
    /// several factors: the club's underlying stature (prestige), how it
    /// finished the season just gone, any silverware it picked up, and a
    /// small board-mood swing (a strong sponsor renewal, an unexpectedly
    /// costly injury crisis) so it isn't perfectly predictable.
    func resetTransferBudgets() {
        for tier in 0..<Self.divisionNames.count {
            for (position, club) in leagueTable(tier: tier).enumerated() {
                guard let index = clubs.firstIndex(where: { $0.id == club.id }) else { continue }
                let baseline = Self.transferBudget(forPrestige: club.prestige, startYear: startYear)
                let positionBonus = Self.seasonBudgetBonus(tier: tier, position: position + 1, startYear: startYear)
                let trophyBonus = seasonTrophyBonus(for: club)
                let commercial = Self.commercialRevenue(forPrestige: club.prestige, startYear: startYear, clubShopLevel: club.clubShopLevel)
                let boardMood = Double.random(in: 0.85...1.15)
                let newBudget = max(50, Int(Double(baseline + positionBonus + trophyBonus + commercial) * boardMood))
                clubs[index].transferBudget = newBudget
                clubs[index].wageBudget += positionBonus / 4
                // A museum builds heritage and matchday appeal over time —
                // a small, permanent prestige trickle, plus deeper loyalty
                // at the user's own club specifically.
                if club.museumLevel > 0 {
                    clubs[index].prestige = min(99, clubs[index].prestige + club.museumLevel / 2)
                    if index == userClubIndex {
                        seasonTicketHolders += club.museumLevel * 20
                    }
                }
            }
        }
    }

    /// A season's kit-sponsorship income, scaled by prestige — bigger
    /// clubs land bigger commercial deals. Folded into the season budget
    /// reset alongside prize money and cup form.
    static func commercialRevenue(forPrestige prestige: Int, startYear: Int = 2000, clubShopLevel: Int = 0) -> Int {
        let base = pow(Double(prestige) / 45.0, 5.0) * 60.0
        let shopMultiplier = 1.0 + 0.05 * Double(clubShopLevel)
        return max(20, Int(base * economyMultiplier(startYear: startYear) * shopMultiplier))
    }

    /// Flavour end-of-season news: the top division's champions, and the
    /// pyramid's outright top scorer — run before `startNewSeason` resets
    /// records, so this season's tallies are still live.
    func awardSeasonHonours() {
        if let champion = leagueTable(tier: 0).first, let index = clubs.firstIndex(where: { $0.id == champion.id }) {
            addNews(.board, "Team of the Season",
                    "\(champion.name) are crowned \(divisionName(0)) champions under \(managers[index]), finishing on \(champion.points) points.")
        }
        let scorers = clubs.indices.filter { clubs[$0].divisionTier < 4 }
            .flatMap { clubIndex in clubs[clubIndex].players.map { (player: $0, clubName: clubs[clubIndex].name) } }
        if let top = scorers.filter({ $0.player.goals > 0 }).max(by: { $0.player.goals < $1.player.goals }) {
            addNews(.board, "Golden Boot",
                    "\(top.player.name) (\(top.clubName)) finishes the season as the pyramid's top scorer with \(top.player.goals) goals.")
        }
        awardManagerOfTheSeason()
        awardYoungPlayerOfTheSeason()
    }

    /// The pyramid's best young performer this season — any player 23 or
    /// under, ranked by season average match rating (a minimum handful of
    /// appearances so it isn't decided by one or two good cameos).
    func awardYoungPlayerOfTheSeason() {
        let candidates = clubs.indices.filter { clubs[$0].divisionTier < 4 }
            .flatMap { clubIndex in clubs[clubIndex].players.map { (player: $0, clubName: clubs[clubIndex].name) } }
            .filter { $0.player.age <= 23 && $0.player.apps >= 10 }
        guard let best = candidates.max(by: { ($0.player.averageRating ?? 0) < ($1.player.averageRating ?? 0) }) else { return }
        addNews(.board, "Young Player of the Season",
                "\(best.player.name) (\(best.clubName)), age \(best.player.age), is named the pyramid's Young Player of the Season.")
    }

    /// The pyramid's Manager of the Season: whoever's club finished
    /// furthest above where their squad's raw prestige would have
    /// predicted — a reward for a genuine overachievement, across any
    /// division, not just whoever happened to win the biggest one.
    func awardManagerOfTheSeason() {
        var best: (clubName: String, manager: String, overachievement: Int)?
        for tier in 0..<Self.divisionNames.count {
            let byPrestige = clubs.filter { $0.divisionTier == tier }.sorted { $0.prestige > $1.prestige }
            let table = leagueTable(tier: tier)
            for (actualIndex, club) in table.enumerated() {
                guard let prestigeRank = byPrestige.firstIndex(where: { $0.id == club.id }),
                      let clubIndex = clubs.firstIndex(where: { $0.id == club.id }) else { continue }
                let overachievement = prestigeRank - actualIndex
                if overachievement > (best?.overachievement ?? 0) {
                    best = (club.name, managers[clubIndex], overachievement)
                }
            }
        }
        guard let best, best.overachievement > 0 else { return }
        addNews(.board, "Manager of the Season",
                "\(best.manager) (\(best.clubName)) takes Manager of the Season, defying expectations by finishing \(best.overachievement) place\(best.overachievement == 1 ? "" : "s") higher than their squad's reputation suggested.")
    }

    /// Auto-promotes the top two, promotes a play-off winner (from 3rd–6th),
    /// and relegates the bottom three of each division.
    func applyPromotionRelegation() {
        var moves: [(id: UUID, newTier: Int)] = []
        var playoffMessages: [(title: String, body: String)] = []

        for tier in 0..<Self.divisionNames.count {
            let table = leagueTable(tier: tier)
            if tier > 0 {
                // Automatic promotion.
                for club in table.prefix(2) { moves.append((club.id, tier - 1)) }
                // Play-offs for positions 3–6.
                let contenders = Array(table.dropFirst(2).prefix(4))
                if let winner = simulatePlayoff(contenders) {
                    moves.append((winner.id, tier - 1))
                    playoffMessages.append(("\(divisionName(tier)) play-offs",
                        "\(winner.name) win the play-off final and are promoted to the \(divisionName(tier - 1))!"))
                }
            }
            if tier < Self.divisionNames.count - 1 {
                for club in table.suffix(3) { moves.append((club.id, tier + 1)) }
            }
        }

        let userOldTier = userDivisionTier
        for move in moves {
            if let index = clubs.firstIndex(where: { $0.id == move.id }) {
                clubs[index].divisionTier = move.newTier
            }
        }
        for message in playoffMessages { addNews(.result, message.title, message.body) }

        let userNewTier = userDivisionTier
        if userNewTier < userOldTier {
            addNews(.board, "Promotion!", "\(userClub.name) are promoted to the \(divisionName(userNewTier))!")
            celebratePromotion()
        } else if userNewTier > userOldTier {
            addNews(.board, "Relegation", "\(userClub.name) are relegated to the \(divisionName(userNewTier)).")
        }
    }

    /// Simulates a four-team play-off (3v6, 4v5, then final) and returns the
    /// promoted club, weighting each tie by squad strength.
    func simulatePlayoff(_ contenders: [Club]) -> Club? {
        guard contenders.count >= 4 else { return contenders.first }
        let semi1 = playoffWinner(contenders[0], contenders[3])   // 3rd v 6th
        let semi2 = playoffWinner(contenders[1], contenders[2])   // 4th v 5th
        return playoffWinner(semi1, semi2)
    }

    func playoffWinner(_ a: Club, _ b: Club) -> Club {
        let strengthA = strengthValue(bestXI(for: a, formation: aiFormation(for: a)))
        let strengthB = strengthValue(bestXI(for: b, formation: aiFormation(for: b)))
        let probabilityA = strengthA / (strengthA + strengthB)
        return Double.random(in: 0..<1) < probabilityA ? a : b
    }

    /// Ages every player a year, develops the young, declines the old,
    /// retires veterans and refreshes squads with youth intake.
    ///
    /// Mutates each surviving player in place rather than rebuilding them
    /// via `makePlayer` — that used to hand out a fresh random `id` and a
    /// re-rolled `detailedPosition`/`secondaryPositions` for every player,
    /// every season. The new `id` orphaned anything that remembered the
    /// old one (the shortlist, captain/penalty/free-kick roles), and the
    /// random role reassignment meant a real player's known position
    /// (e.g. a converted winger at right wing) silently scrambled after one season.
    func progressSquads() {
        for clubIndex in clubs.indices {
            // A youth developer squeezes extra growth out of every young
            // player on the books, not just the odd standout prospect.
            let isYouthDeveloper = personality(forClubIndex: clubIndex) == .youthDeveloper
            let trainingBonus = clubs[clubIndex].trainingGroundLevel / 2
            var kept: [Player] = []
            var retirees: [Player] = []
            for var player in clubs[clubIndex].players {
                let age = player.age + 1
                var rating = player.rating
                // A strong work ethic squeezes extra growth out of a young
                // season; high consistency softens the erratic swings of
                // an ageing one — a reliable pro declines more gracefully.
                let workEthicBonus = age < 24 && player.traits.workEthic >= 70 ? 1 : 0
                let consistencyEase = player.traits.consistency >= 75 ? 1 : 0
                switch age {
                case ..<24:   rating += Int.random(in: 0...2) + (isYouthDeveloper ? 1 : 0) + trainingBonus + workEthicBonus
                case 24...29: rating += Int.random(in: -1...1)
                case 30...32: rating -= max(0, Int.random(in: 0...2) - consistencyEase)
                default:      rating -= max(0, Int.random(in: 1...3) - consistencyEase)
                }
                rating = min(94, max(40, rating))
                // Veterans retire; a true professional takes better care of
                // himself and tends to play on longer than a less dedicated
                // teammate of the same age — the coin-flip band's odds
                // shift around the original 50/50 rather than replacing it.
                let earlyRetireChance = 0.5 - Double(player.traits.professionalism - 50) / 200.0
                if age >= 38 || (age >= 35 && Double.random(in: 0..<1) < earlyRetireChance) {
                    var retiree = player
                    retiree.age = age
                    retirees.append(retiree)
                    continue
                }
                player.age = age
                player.rating = rating
                player.value = playerValue(rating: rating, age: age, startYear: startYear)
                player.wage = playerWage(rating: rating, age: age, startYear: startYear)
                player.attributes = makeAttributes(position: player.position, rating: rating)
                player.isTransferListed = false
                player.wantsToLeave = false
                kept.append(player)
            }
            clubs[clubIndex].players = kept
            ensureSquad(clubIndex: clubIndex)

            // Only worth a headline for the user's own club, and only for
            // players who actually made a mark — not every departing
            // squad-filler youth-team player.
            if clubIndex == userClubIndex {
                for retiree in retirees where retiree.rating >= 65 {
                    // Real career totals, not just flavour — allTimeAppearances/
                    // allTimeScorers already include this final season's stats,
                    // since recordSeasonHonours() accumulates them before this
                    // retirement pass ever runs. Passing `player:` also unlocks
                    // the existing bespoke "LEGEND ANNOUNCES RETIREMENT"/"HANGS
                    // UP HIS BOOTS" newspaper templates, previously dead code
                    // for the user's own retirees since this call never passed it.
                    let apps = allTimeAppearances[retiree.name] ?? retiree.apps
                    let goals = allTimeScorers[retiree.name] ?? retiree.goals
                    let statsLine = goals > 0
                        ? "He leaves after \(apps) appearance\(apps == 1 ? "" : "s") and \(goals) goal\(goals == 1 ? "" : "s") for \(clubs[clubIndex].name)."
                        : "He leaves after \(apps) appearance\(apps == 1 ? "" : "s") for \(clubs[clubIndex].name)."
                    addNews(.board, "Retirement",
                            "\(retiree.name) has announced his retirement from professional football, at \(retiree.age). \(statsLine)",
                            player: retiree, clubName: clubs[clubIndex].name)
                }
                // Legend induction needs `clubTenureStart` before it's
                // pruned to currently-kept players below.
                for retiree in retirees {
                    evaluateForLegendStatus(retiree, clubName: clubs[clubIndex].name)
                }
                // Ten years' unbroken service earns a testimonial — tenure is
                // only tracked from when this save started, so a player
                // already long-serving when a career begins won't be
                // credited for time served before that.
                for player in kept {
                    if clubTenureStart[player.id] == nil {
                        clubTenureStart[player.id] = season
                    } else if let start = clubTenureStart[player.id], season - start == 10 {
                        let bonus = 400
                        clubs[clubIndex].transferBudget += bonus
                        logLedger("Testimonial", amount: bonus, "\(player.name)'s testimonial match")
                        addNews(.board, "Testimonial match",
                                "\(player.name) is awarded a testimonial match for ten years' service to \(userClub.name) — gate proceeds boost the transfer budget.")
                    }
                }
                let currentIDs = Set(kept.map { $0.id })
                clubTenureStart = clubTenureStart.filter { currentIDs.contains($0.key) }
            } else {
                // Rival clubs don't track career stats the way the user's
                // own does, so there's no real data to induct them into a
                // Hall of Fame on — but a genuine standout hanging up his
                // boots is still a story worth telling.
                for retiree in retirees where retiree.rating >= 78 {
                    addNews(.world, "Retirement",
                            "\(retiree.name) has announced his retirement from professional football, at \(retiree.age).",
                            player: retiree, clubName: clubs[clubIndex].name)
                }
            }
        }
    }

    /// Tops up a club with generated youngsters to keep a full squad.
    func ensureSquad(clubIndex: Int) {
        let minimums: [(Position, Int)] = [(.goalkeeper, 2), (.defender, 6), (.midfielder, 6), (.forward, 4)]
        for (position, minimum) in minimums {
            var count = clubs[clubIndex].players.filter { $0.position == position }.count
            while count < minimum {
                let rating = Self.clampRating(clubs[clubIndex].prestige + Int.random(in: -20 ... -3))
                clubs[clubIndex].players.append(
                    Self.makePlayer(position: position, age: Int.random(in: 17...20), rating: rating, startYear: startYear))
                count += 1
            }
        }
    }

}
