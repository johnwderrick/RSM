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
            let chance = 0.008 + Double(clubs[index].prestige) * 0.0002
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
        for index in aiClubs where clubs[index].prestige < 85 && Double.random(in: 0..<1) < 0.01 {
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
        for index in aiClubs where Double.random(in: 0..<1) < 0.012 {
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
        for index in aiClubs where Double.random(in: 0..<1) < 0.02 {
            let youngsters = clubs[index].players.indices.filter { clubs[index].players[$0].age <= 19 && clubs[index].players[$0].rating < 80 }
            guard let target = youngsters.max(by: { clubs[index].players[$0].rating < clubs[index].players[$1].rating }) else { continue }
            var player = clubs[index].players[target]
            player.rating = min(85, player.rating + Int.random(in: 8...16))
            player.value = playerValue(rating: player.rating, age: player.age, startYear: startYear)
            player.wage = playerWage(rating: player.rating, age: player.age, startYear: startYear)
            player.attributes = makeAttributes(position: player.position, rating: player.rating)
            clubs[index].players[target] = player
            addNews(.world, "Wonderkid emerges",
                    "\(player.name) (\(player.age)) has broken into \(clubs[index].name)'s first team and is being talked about as one of the country's brightest young talents.",
                    player: player, clubName: clubs[index].name)
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
        dynamicRivalries.append(RivalryPair(clubA: clubs[a].name, clubB: clubs[b].name))
        let reasons = ["a fiercely contested title race", "back-to-back play-off eliminations",
                       "a string of ill-tempered meetings", "a controversial transfer between the two clubs"]
        addNews(.world, "Rivalry forming",
                "\(clubs[a].name) and \(clubs[b].name) are developing a genuine rivalry after \(reasons.randomElement()!).")
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
