//
//  GameStore+WorldSimulation.swift
//  Retro Season Manager
//
//  A living football world: every season, clubs the user never manages
//  still get bought, go bankrupt, unearth wonderkids, expand their
//  grounds and fall out with their neighbours — whether or not the
//  player ever opens the inbox to read about it. Each event mutates
//  real, persistent club/player state (not just flavour text) and is
//  reported through the same addNews(...) pipeline as everything else,
//  so it also becomes a front page in the newspaper archive.
//

import Foundation

/// A world-flavour story scheduled to land a few days in the future —
/// the shared mechanism every "event chain"/follow-up below is built on,
/// mirroring `PendingTransferDeal`'s `readyDate` pattern.
struct PendingWorldStory: Identifiable, Codable {
    let id: UUID
    let fireDate: Date
    let category: NewsCategory
    let title: String
    let body: String
    var clubName: String? = nil
}

/// A wonderkid being tracked for a one-time follow-up — the season they
/// emerged and their rating at that moment, so `checkWonderkidFollowUps()`
/// can tell whether they genuinely kept developing or just had one good
/// breakthrough season.
struct WonderkidWatch: Codable {
    let season: Int
    let ratingAtEmergence: Int
}

extension GameStore {

    /// Runs the whole living-world pass for one season — called
    /// unconditionally from `startNextSeason()`, regardless of anything
    /// the player does or checks.
    func simulateWorldEvents() {
        let aiClubs = clubs.indices.filter { $0 != userClubIndex }
        simulateTakeovers(among: aiClubs)
        simulateFinancialDistress(among: aiClubs)
        simulateWonderkids(among: aiClubs)
        simulateStadiumExpansions(among: aiClubs)
        simulateFacilityUpgrades(among: aiClubs)
        simulateNewRivalry(among: aiClubs)
        simulateLeagueRuleChange()
        checkWonderkidFollowUps()
        checkClubFortunes(among: aiClubs)
        checkRecurringRivalry()
    }

    // MARK: - Scheduled follow-up stories

    /// Queues a world-flavour story to fire a few days from now — used
    /// for genuine follow-ups (a sacking today, an appointment next
    /// week) rather than resolving the whole arc in one instant.
    func scheduleWorldStory(daysFromNow: ClosedRange<Int>, category: NewsCategory, title: String, body: String, clubName: String? = nil) {
        let fireDate = Self.calendar.date(byAdding: .day, value: Int.random(in: daysFromNow), to: currentDate) ?? currentDate
        pendingWorldStories.append(PendingWorldStory(id: UUID(), fireDate: fireDate, category: category, title: title, body: body, clubName: clubName))
    }

    /// Fires (and clears) every scheduled story whose date has arrived —
    /// called daily, same cadence as `checkPendingTransferDeals()`.
    func checkPendingWorldStories() {
        for story in pendingWorldStories where story.fireDate <= currentDate {
            addNews(story.category, story.title, story.body, clubName: story.clubName)
        }
        pendingWorldStories.removeAll { $0.fireDate <= currentDate }
    }

    // MARK: - Facility upgrades

    /// Every facility except the stadium (already handled above) gets a
    /// small, prestige-weighted chance to grow one level each season —
    /// never zero even for the smallest club, just rarer — the slow
    /// compounding that lets a real underdog grow into a giant over a
    /// long enough career, not just the already-rich getting richer.
    private func simulateFacilityUpgrades(among aiClubs: [Int]) {
        let kinds: [FacilityKind] = [.trainingGround, .youthAcademy, .medicalCentre, .scoutingNetwork, .hospitality, .museum, .clubShop]
        for index in aiClubs {
            var chance = 0.008 + Double(clubs[index].prestige) * 0.0002
            if clubIdentity(forClubIndex: index) == .financialPowerhouse { chance *= 1.5 }
            guard Double.random(in: 0..<1) < chance, let kind = kinds.randomElement() else { continue }
            let level = kind.level(in: clubs[index])
            guard level < 5 else { continue }
            switch kind {
            case .trainingGround:  clubs[index].trainingGroundLevel += 1
            case .youthAcademy:    clubs[index].youthFacilityLevel += 1
            case .medicalCentre:   clubs[index].medicalCentreLevel += 1
            case .scoutingNetwork: clubs[index].scoutingNetworkLevel += 1
            case .hospitality:     clubs[index].hospitalityLevel += 1
            case .museum:          clubs[index].museumLevel += 1
            case .clubShop:        clubs[index].clubShopLevel += 1
            case .stadium: break
            }
            clubs[index].prestige = min(99, clubs[index].prestige + Int.random(in: 1...4))
            let newLevel = kind.level(in: clubs[index])
            addNews(.world, "\(kind.displayName) upgraded",
                    "\(clubs[index].name) invest in their \(kind.displayName.lowercased()) — now \(kind.tierLabel(newLevel).lowercased()).",
                    clubName: clubs[index].name)
        }
    }

    // MARK: - Club takeovers

    /// A handful of clubs a season attract new ownership — rare enough
    /// that most careers see only a few, real enough that a newly-rich
    /// rival can reshape a division over time. Reserved for clubs that
    /// aren't already among the elite, so it reads as a genuine rise
    /// rather than the same few giants getting richer still.
    private func simulateTakeovers(among aiClubs: [Int]) {
        for index in aiClubs where clubs[index].prestige < 85 && clubIdentity(forClubIndex: index) != .crisisClub {
            // A Financial Powerhouse attracts new investment far more
            // readily; a Crisis Club (guarded above) doesn't plausibly
            // attract a takeover while already in freefall.
            let chance = clubIdentity(forClubIndex: index) == .financialPowerhouse ? 0.02 : 0.01
            guard Double.random(in: 0..<1) < chance else { continue }
            clubs[index].prestige = min(99, clubs[index].prestige + Int.random(in: 10...25))
            clubs[index].transferBudget = min(500_000, Int(Double(clubs[index].transferBudget) * Double.random(in: 1.6...3.0)))
            clubs[index].wageBudget = min(300_000, Int(Double(clubs[index].wageBudget) * Double.random(in: 1.3...1.8)))
            addNews(.world, "Club takeover",
                    "\(clubs[index].name) have been bought by a new ownership group, promising major investment in the squad and facilities.",
                    clubName: clubs[index].name)
        }
    }

    // MARK: - Financial distress

    /// Most crises just tighten the belt; a rare, more severe case tips
    /// into administration — a real points-of-no-return moment, not just
    /// a worse version of the same story, complete with an emergency
    /// fire sale of the club's best asset.
    private func simulateFinancialDistress(among aiClubs: [Int]) {
        for index in aiClubs {
            let chance = clubIdentity(forClubIndex: index) == .crisisClub ? 0.03 : 0.012
            guard Double.random(in: 0..<1) < chance else { continue }
            if Double.random(in: 0..<1) < 0.2 {
                clubs[index].prestige = max(20, clubs[index].prestige - Int.random(in: 15...30))
                clubs[index].transferBudget = Int(Double(clubs[index].transferBudget) * 0.15)
                clubs[index].wageBudget = Int(Double(clubs[index].wageBudget) * 0.4)
                if let starIndex = clubs[index].players.indices.max(by: { clubs[index].players[$0].rating < clubs[index].players[$1].rating }),
                   let buyer = aiClubs.filter({ $0 != index && clubs[$0].transferBudget > clubs[index].players[starIndex].value }).randomElement() {
                    let star = clubs[index].players[starIndex]
                    clubs[index].players.remove(at: starIndex)
                    clubs[buyer].players.append(star)
                    clubs[index].transferBudget += star.value / 2
                    addNews(.world, "Club bankruptcy",
                            "\(clubs[index].name) have entered administration after years of overspending. \(star.name) is sold to \(clubs[buyer].name) in an emergency fire sale.",
                            clubName: clubs[index].name)
                } else {
                    addNews(.world, "Club bankruptcy",
                            "\(clubs[index].name) have entered administration after a severe financial crisis.",
                            clubName: clubs[index].name)
                }
            } else {
                clubs[index].prestige = max(30, clubs[index].prestige - Int.random(in: 5...15))
                clubs[index].transferBudget = Int(Double(clubs[index].transferBudget) * Double.random(in: 0.3...0.6))
                addNews(.world, "Financial crisis",
                        "\(clubs[index].name) are in financial trouble after years of overspending on wages — the transfer budget is slashed.",
                        clubName: clubs[index].name)
            }
        }
    }

    // MARK: - Wonderkids

    /// A promising teenager breaks into the first team and jumps several
    /// levels almost overnight — a real, persistent boost to that player,
    /// not just a headline.
    private func simulateWonderkids(among aiClubs: [Int]) {
        for index in aiClubs {
            // A Youth Factory's academy turns up a genuine breakthrough
            // far more often — the base roll otherwise reads no facility
            // or prestige signal at all.
            let chance = clubIdentity(forClubIndex: index) == .youthFactory ? 0.05 : 0.02
            guard Double.random(in: 0..<1) < chance else { continue }
            let youngsters = clubs[index].players.indices.filter { clubs[index].players[$0].age <= 19 && clubs[index].players[$0].rating < 80 }
            guard let target = youngsters.max(by: { clubs[index].players[$0].rating < clubs[index].players[$1].rating }) else { continue }
            var player = clubs[index].players[target]
            player.rating = min(85, player.rating + Int.random(in: 8...16))
            player.value = playerValue(rating: player.rating, age: player.age, startYear: startYear)
            player.wage = playerWage(rating: player.rating, age: player.age, startYear: startYear)
            player.attributes = makeAttributes(position: player.position, rating: player.rating)
            clubs[index].players[target] = player
            wonderkidWatchlist[player.id] = WonderkidWatch(season: season, ratingAtEmergence: player.rating)
            addNews(.world, "Wonderkid emerges",
                    "\(player.name) (\(player.age)) has broken into \(clubs[index].name)'s first team and is being talked about as one of the country's brightest young talents.",
                    player: player, clubName: clubs[index].name)
        }
    }

    // MARK: - Wonderkid follow-ups

    /// Checks back on each tracked wonderkid exactly once, a season
    /// after they emerged — did they keep developing, or was the
    /// breakthrough a one-off? Resolved players are removed either way,
    /// so this never re-fires for the same player.
    private func checkWonderkidFollowUps() {
        for (playerID, watch) in wonderkidWatchlist where season - watch.season >= 1 {
            wonderkidWatchlist.removeValue(forKey: playerID)
            guard let clubIndex = clubs.firstIndex(where: { club in club.players.contains { $0.id == playerID } }),
                  let player = clubs[clubIndex].players.first(where: { $0.id == playerID }) else { continue }
            if player.rating > watch.ratingAtEmergence {
                addNews(.world, "Star in the making",
                        "\(player.name) has kicked on since bursting onto the scene at \(clubs[clubIndex].name), and is now spoken of as one of the finest young talents in the game.",
                        player: player, clubName: clubs[clubIndex].name)
            } else {
                addNews(.world, "Faded from the spotlight",
                        "\(player.name)'s breakthrough at \(clubs[clubIndex].name) hasn't quite kicked on the way many expected after the initial hype.",
                        player: player, clubName: clubs[clubIndex].name)
            }
        }
    }

    // MARK: - Stadium expansions

    private func simulateStadiumExpansions(among aiClubs: [Int]) {
        for index in aiClubs where clubs[index].stadiumExpansionLevel < 5 && Double.random(in: 0..<1) < 0.015 {
            clubs[index].stadiumExpansionLevel += 1
            clubs[index].prestige = min(99, clubs[index].prestige + Int.random(in: 3...8))
            addNews(.world, "Stadium expansion",
                    "\(clubs[index].name) have completed a stadium expansion, boosting matchday revenue and the club's standing.",
                    clubName: clubs[index].name)
        }
    }

    // MARK: - Rivalries forming

    /// At most one new rivalry a season, world-wide — between two clubs
    /// sharing a division who aren't already rivals — so the pyramid
    /// slowly grows its own history on top of the scripted derbies.
    private func simulateNewRivalry(among aiClubs: [Int]) {
        guard Double.random(in: 0..<1) < 0.1, let tier = (0..<Self.divisionNames.count).randomElement() else { return }
        let inTier = aiClubs.filter { clubs[$0].divisionTier == tier }
        guard inTier.count >= 2, let a = inTier.randomElement(),
              let b = inTier.filter({ $0 != a }).randomElement(),
              !areRivals(clubs[a].name, clubs[b].name) else { return }
        let reasons = ["a fiercely contested title race", "back-to-back play-off eliminations",
                       "a string of ill-tempered meetings", "a controversial transfer between the two clubs"]
        let reason = reasons.randomElement()!
        dynamicRivalries.append(RivalryPair(clubA: clubs[a].name, clubB: clubs[b].name, formedSeason: season, reason: reason))
        addNews(.world, "Rivalry forming",
                "\(clubs[a].name) and \(clubs[b].name) are developing a genuine rivalry after \(reason).")
    }

    // MARK: - Recurring rivalries

    /// A once-a-season chance to remind the player that a rivalry formed
    /// years ago is still very much alive — the one existing procedural
    /// event that persists real state (`dynamicRivalries`) but was never
    /// referenced again narratively.
    private func checkRecurringRivalry() {
        guard Double.random(in: 0..<1) < 0.15, let pair = dynamicRivalries.randomElement() else { return }
        let seasonText = pair.formedSeason.map { "back to Season \($0)'s " } ?? "back several seasons, to "
        let reasonText = pair.reason ?? "a bitter falling out"
        addNews(.world, "Old rivals",
                "\(pair.clubA) and \(pair.clubB)'s rivalry dates \(seasonText)\(reasonText) — and it remains as fierce as ever.")
    }

    // MARK: - Club rise/fall arcs

    /// Compares each AI club's prestige to a baseline snapshot and, once
    /// it's swung far enough either way, tells the story — then resets
    /// the baseline so the next arc measures fresh from here rather than
    /// firing every season off the same stale comparison point.
    private func checkClubFortunes(among aiClubs: [Int]) {
        for index in aiClubs {
            let club = clubs[index]
            guard let baseline = clubPrestigeBaseline[club.id] else {
                clubPrestigeBaseline[club.id] = club.prestige
                continue
            }
            let delta = club.prestige - baseline
            if delta >= 15 {
                addNews(.world, "Club on the rise",
                        "\(club.name) have been transformed in recent times, and are increasingly spoken of as a genuine force.",
                        clubName: club.name)
                clubPrestigeBaseline[club.id] = club.prestige
            } else if delta <= -15 {
                addNews(.world, "Club in decline",
                        "\(club.name) are a shadow of the club they once were, with little sign of the slide being arrested.",
                        clubName: club.name)
                clubPrestigeBaseline[club.id] = club.prestige
            }
        }
    }

    // MARK: - League announcements

    /// Pure world-flavour — the pyramid keeps legislating on itself even
    /// when none of it touches how a match actually plays out.
    private func simulateLeagueRuleChange() {
        guard Double.random(in: 0..<1) < 0.08 else { return }
        let changes = [
            "The league has confirmed VAR will be trialled in cup competitions from next season.",
            "A new financial fair play framework has been announced, with tighter spending controls across the pyramid.",
            "The play-off format is under review after complaints from mid-table clubs.",
            "Squad registration deadlines have been moved forward by two weeks.",
            "A new home-grown quota rule takes effect next season.",
            "The league has approved a winter break for the top two divisions.",
        ]
        addNews(.world, "League announcement", changes.randomElement()!)
    }
}
