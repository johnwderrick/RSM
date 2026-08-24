//
//  GameStore+SquadManagement.swift
//  Retro Season Manager
//
//  Squad status, squad generation, fixture generation, starting XI
//  selection, squad roles and the youth academy.
//

import Foundation

extension GameStore {

    // MARK: - Squad status & scouting a team

    /// A player's standing in the user's squad at their position.
    func squadStatus(for player: Player) -> String {
        let group = userClub.players
            .filter { $0.position == player.position }
            .sorted { $0.rating > $1.rating }
        guard let rank = group.firstIndex(where: { $0.id == player.id }) else { return "Squad player" }
        let starters = slots(for: player.position)
        if rank == 0 { return "Key player" }
        if rank < starters { return "First team" }
        if rank < starters + 1 { return "Rotation" }
        return "Backup"
    }

    /// The averaged outfield attributes of a club's best XI, high to low.
    func rankedTeamAttributes(forClubIndex index: Int) -> [(name: String, value: Double)] {
        let xi = bestXI(for: clubs[index], formation: aiFormation(for: clubs[index]))
            .filter { $0.position != .goalkeeper }
        guard !xi.isEmpty else { return [] }
        return Player.outfieldAttributes.map { name in
            let total = xi.reduce(0.0) { $0 + Double($1.attributes[name] ?? 0) }
            return (name, total / Double(xi.count))
        }
        .sorted { $0.value > $1.value }
    }

    func teamStrengths(forClubIndex index: Int) -> [String] {
        rankedTeamAttributes(forClubIndex: index).prefix(3).map { $0.name }
    }

    func teamWeaknesses(forClubIndex index: Int) -> [String] {
        rankedTeamAttributes(forClubIndex: index).suffix(2).map { $0.name }.reversed()
    }

    /// A club's average squad morale, 0...100.
    func teamMorale(forClubIndex index: Int) -> Int {
        let squad = clubs[index].players
        guard !squad.isEmpty else { return 70 }
        return squad.reduce(0) { $0 + $1.morale } / squad.count
    }

    /// A short read on squad mood, for the UI.
    func teamMoraleLabel(forClubIndex index: Int) -> String {
        switch teamMorale(forClubIndex: index) {
        case 80...:   return "Buoyant"
        case 60..<80: return "Settled"
        case 40..<60: return "Uneasy"
        case 20..<40: return "Unhappy"
        default:      return "Mutinous"
        }
    }

    /// The best-rated player in a club's starting XI.
    func keyPlayer(forClubIndex index: Int) -> Player? {
        bestXI(for: clubs[index], formation: aiFormation(for: clubs[index])).max { $0.rating < $1.rating }
    }

    /// The natural formation name a club lines up in.
    func formationName(forClubIndex index: Int) -> String {
        aiFormation(for: clubs[index]).name
    }

    /// A one-word playing style based on a club's shape.
    func playStyle(forClubIndex index: Int) -> String {
        let formation = aiFormation(for: clubs[index])
        if formation.forwards >= 3 { return "Attacking" }
        if formation.forwards <= 1 { return "Defensive" }
        return "Balanced"
    }

    /// A pre-match prediction for the user's next fixture.
    func matchPrediction() -> String {
        guard let fixture = nextUserFixture else { return "" }
        let probs = outcomeProbabilities(homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex)
        let isHome = fixture.homeIndex == userClubIndex
        let userWin = isHome ? probs.home : probs.away
        let oppWin = isHome ? probs.away : probs.home
        let opponent = clubs[isHome ? fixture.awayIndex : fixture.homeIndex]
        if userWin > oppWin + 0.2 {
            return "\(userClub.name) should have too much quality for \(opponent.name) in this one."
        } else if oppWin > userWin + 0.2 {
            return "\(opponent.name) are favourites — this will be a real test for \(userClub.name)."
        }
        return "A finely balanced contest between \(userClub.name) and \(opponent.name)."
    }

    // MARK: - Squad generation

    /// First names common among English pros born in the late 1970s/early
    /// 1980s — the generation filling the pyramid's lower divisions in 2000/01.
    static let firstNames = [
        "Jack", "Harry", "Tom", "Danny", "Wayne", "Frank", "Lee", "Craig",
        "Steven", "Michael", "Alan", "Paul", "Gary", "Nigel", "Ashley",
        "Kevin", "Darren", "Jamie", "Marcus", "Simon", "Phil", "Neil",
        "Matthew", "Mark", "Jordan", "Kyle", "Luke", "Carl", "Callum",
        "Ian", "Scott", "Chris", "David", "Richard", "Adam",
    ]

    static let lastNames = [
        "Smith", "Jones", "Taylor", "Brown", "Wilson", "Evans", "Roberts",
        "Walker", "Wright", "Hughes", "Green", "Clarke", "Hall", "Wood",
        "Turner", "Hill", "Ward", "Hargate", "Fenshaw", "Millbrook", "Corrigan",
        "Ratcliffe", "Sowerby", "Pentland", "Ashdown", "Crowther", "Selwood",
        "Kearns", "Whitfield", "Osborne", "Dysart", "Marshall", "Bishop", "Grant",
    ]

    /// A loose (not researched) pool of continental European first/last
    /// names, used only to flavour the occasional overseas wonderkid in the
    /// youth intake — a nationality hook, not a researched name.
    static let foreignFirstNames = [
        "Mateo", "Diego", "Luca", "Marco", "Nils", "Lars", "Pierre",
        "Antoine", "Rafael", "Bruno", "Emil", "Anders", "Théo", "Hugo",
        "Adrien", "Jonas", "Fabio", "Sven", "Mikkel", "Rico",
    ]
    static let foreignLastNames = [
        "Fernández", "Novak", "Bergqvist", "Rinaldi", "Dubois", "Weber",
        "Larsen", "Moreau", "Andersen", "Salvi", "Van Houten", "Meyer",
        "Beaumont", "Nilsson", "Berg", "Chastain", "Krause", "Silva",
    ]

    static func randomForeignName() -> String {
        "\(foreignFirstNames.randomElement()!) \(foreignLastNames.randomElement()!)"
    }

    /// A loose pool of plausible nations for flavour — like the foreign
    /// names above, not researched, just enough variety for the player
    /// profile and Hall of Fame screens to feel less uniformly English.
    static let nationalityPool = [
        "Spain", "Italy", "Germany", "France", "Netherlands", "Portugal",
        "Brazil", "Argentina", "Belgium", "Sweden", "Denmark", "Norway",
        "Republic of Ireland", "Scotland", "Wales",
    ]

    /// Rolls a nation — a hand-named player (a historical squad entry, a
    /// foreign star, a marquee signing) is far more likely to be foreign
    /// than a fully generated squad-filler, so `preferForeign` biases the
    /// roll rather than always defaulting to England.
    static func randomNationality(preferForeign: Bool) -> String {
        let foreignChance = preferForeign ? 0.8 : 0.12
        return Double.random(in: 0..<1) < foreignChance ? nationalityPool.randomElement()! : "England"
    }

    /// Every hand-authored career start year, each mapped to its own
    /// club-name-keyed squad book. Adding a further start year later is
    /// just adding another entry here (plus a matching
    /// `HistoricalSquadsYYYY`/`EuropeanSquadsYYYY` data file) — nothing
    /// else in the engine needs to change.
    static let historicalEras: [Int: [String: [HistoricalPlayer]]] = [
        2000: HistoricalSquads2000.squads.merging(EuropeanSquads2000.squads) { existing, _ in existing },
        2010: HistoricalSquads2010.squads.merging(EuropeanSquads2010.squads) { existing, _ in existing },
        2020: HistoricalSquads2020.squads.merging(EuropeanSquads2020.squads) { existing, _ in existing },
    ]

    /// Every start year offered on the New Game screen, oldest first.
    static let availableStartYears: [Int] = historicalEras.keys.sorted()

    /// Creates a full squad for a club, using its hand-authored roster for
    /// the chosen start year when one is known, and otherwise generating
    /// one from the club's prestige (as every non-top-flight club always
    /// has, regardless of era).
    static func makeSquad(name: String, prestige: Int, startYear: Int) -> [Player] {
        if let historical = historicalEras[startYear]?[name] {
            return historical.map { entry in
                var player = makePlayer(name: entry.name, position: entry.detailedPosition.broad,
                                        detailedPosition: entry.detailedPosition,
                                        secondaryPositions: entry.secondaryPositions,
                                        age: entry.age, rating: entry.rating, startYear: startYear)
                player.contractYears = Int.random(in: 1...4)
                return player
            }
        }
        return makeSquad(prestige: prestige, startYear: startYear)
    }

    /// Creates a full generated squad for a club of the given prestige.
    static func makeSquad(prestige: Int, startYear: Int = 2000) -> [Player] {
        var players: [Player] = []
        // Roughly a realistic distribution across the pitch.
        let plan: [(Position, Int)] = [
            (.goalkeeper, 2),
            (.defender, 6),
            (.midfielder, 6),
            (.forward, 4),
        ]
        for (position, count) in plan {
            for _ in 0..<count {
                let rating = clampRating(prestige + Int.random(in: -14...8))
                let age = Int.random(in: 18...34)
                var player = makePlayer(position: position, age: age, rating: rating, startYear: startYear)
                player.contractYears = Int.random(in: 1...4)
                players.append(player)
            }
        }
        return players
    }

    /// Drops in any real players known for this club (see `ForeignStars`),
    /// each replacing the weakest generated player in the matching broad
    /// position so squad size and shape stay untouched.
    static func applyForeignStars(to club: inout Club, startYear: Int = 2000) {
        for star in ForeignStars.all where star.club == club.name {
            let broad = star.detailedPosition.broad
            guard let weakestIndex = club.players.indices
                .filter({ club.players[$0].position == broad })
                .min(by: { club.players[$0].rating < club.players[$1].rating })
            else { continue }
            var player = makePlayer(name: star.name, position: broad, detailedPosition: star.detailedPosition,
                                    age: star.age, rating: star.rating, startYear: startYear)
            player.contractYears = Int.random(in: 1...4)
            club.players[weakestIndex] = player
        }
    }

    /// Builds a player with value, wage, attributes and a preferred foot.
    /// When no detailed position is supplied, one is picked at random from
    /// those plausible for the broad `position`, with a modest chance of a
    /// secondary role — most players have a single specialism.
    static func makePlayer(name: String? = nil, position: Position, detailedPosition: DetailedPosition? = nil,
                           secondaryPositions: [DetailedPosition]? = nil, age: Int, rating: Int, startYear: Int = 2000) -> Player {
        let role = detailedPosition ?? DetailedPosition.plausibleRoles(for: position).randomElement()!
        var player = Player(name: name ?? randomName(),
                            position: position,
                            detailedPosition: role,
                            age: age,
                            rating: rating,
                            value: playerValue(rating: rating, age: age, startYear: startYear),
                            wage: playerWage(rating: rating, age: age, startYear: startYear))
        player.secondaryPositions = secondaryPositions ?? randomSecondaryPositions(for: role)
        player.attributes = makeAttributes(position: position, rating: rating)
        let footRoll = Int.random(in: 0..<100)
        player.foot = footRoll < 68 ? "Right" : (footRoll < 92 ? "Left" : "Both")
        let durabilityRoll = Int.random(in: 0..<100)
        player.durability = durabilityRoll < 18 ? .robust : (durabilityRoll < 82 ? .normal : .fragile)
        let personalityRoll = Int.random(in: 0..<100)
        player.personality = personalityRoll < 40 ? .professional
            : (personalityRoll < 65 ? .loyal : (personalityRoll < 85 ? .ambitious : .volatile))
        player.traits = Self.randomTraits(personality: player.personality)
        player.nationality = Self.randomNationality(preferForeign: name != nil)
        return player
    }

    /// Rolls the 8 hidden personality values independently (so two
    /// players sharing a `Personality` archetype still feel distinct),
    /// with a light bias toward whichever trait that archetype implies —
    /// enough for narrative consistency without tightly coupling the two
    /// systems.
    static func randomTraits(personality: Personality) -> PlayerTraits {
        func roll(bias: Int = 0) -> Int { min(100, max(0, Int.random(in: 10...90) + bias)) }
        var professionalism = roll()
        let leadership = roll()
        var temperament = roll()
        var loyalty = roll()
        var ambition = roll()
        let pressure = roll()
        let consistency = roll()
        var workEthic = roll()
        switch personality {
        case .professional: professionalism = roll(bias: 15); workEthic = roll(bias: 10)
        case .loyal:         loyalty = roll(bias: 20)
        case .ambitious:     ambition = roll(bias: 20)
        case .volatile:      temperament = roll(bias: -20)
        }
        return PlayerTraits(professionalism: professionalism, leadership: leadership, temperament: temperament,
                            loyalty: loyalty, ambition: ambition, pressure: pressure,
                            consistency: consistency, workEthic: workEthic)
    }

    /// A plausible secondary role for a generated player — not every
    /// specialist can deputise elsewhere, so this is often empty.
    static func randomSecondaryPositions(for role: DetailedPosition) -> [DetailedPosition] {
        let candidates: [(DetailedPosition, Double)]
        switch role {
        case .goalkeeper:   candidates = []
        case .centreBack:   candidates = [(.leftBack, 0.08), (.rightBack, 0.08)]
        case .leftBack:     candidates = [(.leftWing, 0.30), (.centreBack, 0.20)]
        case .rightBack:    candidates = [(.rightWing, 0.30), (.centreBack, 0.20)]
        case .holding:      candidates = [(.centreBack, 0.15), (.centralMid, 0.30)]
        case .centralMid:   candidates = [(.holding, 0.25), (.attackingMid, 0.20)]
        case .attackingMid: candidates = [(.leftWing, 0.15), (.rightWing, 0.15), (.centralMid, 0.20)]
        case .leftWing:     candidates = [(.leftBack, 0.20), (.attackingMid, 0.25), (.striker, 0.15)]
        case .rightWing:    candidates = [(.rightBack, 0.20), (.attackingMid, 0.25), (.striker, 0.15)]
        case .leftMid:      candidates = [(.leftBack, 0.25), (.centralMid, 0.25), (.leftWing, 0.20)]
        case .rightMid:     candidates = [(.rightBack, 0.25), (.centralMid, 0.25), (.rightWing, 0.20)]
        case .striker:      candidates = [(.leftWing, 0.10), (.rightWing, 0.10)]
        }
        for (candidate, chance) in candidates where Double.random(in: 0..<1) < chance {
            return [candidate]
        }
        return []
    }

    /// A free agent available on the transfer market.
    static func makeFreeAgent(startYear: Int = 2000) -> Player {
        let position = Position.allCases.randomElement()!
        var player = makePlayer(position: position,
                                age: Int.random(in: 24...34),
                                rating: Int.random(in: 55...78),
                                startYear: startYear)
        player.contractYears = Int.random(in: 1...2)
        return player
    }

    static func randomName() -> String {
        "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }

    static func randomManagerName() -> String {
        // Initial + surname, in the classic manager style.
        "\(firstNames.randomElement()!.prefix(1)). \(lastNames.randomElement()!)"
    }

    /// The manager of the club at the given index.
    func manager(forClubIndex index: Int) -> String {
        managers.indices.contains(index) ? managers[index] : "—"
    }

    static func clampRating(_ value: Int) -> Int {
        min(94, max(45, value))
    }

    // MARK: - Fixtures (double round-robin)

    /// Generates a home-and-away schedule using the circle method.
    /// Builds a double round-robin for every division, all sharing matchdays.
    func makeAllFixtures() -> [Fixture] {
        var all: [Fixture] = []
        for tier in 0..<Self.divisionNames.count {
            all += Self.roundRobin(indices: clubIndices(inTier: tier))
        }
        return all
    }

    /// A home-and-away schedule for the given club indices (circle method).
    static func roundRobin(indices global: [Int]) -> [Fixture] {
        var indices = global
        let count = indices.count
        guard count >= 2 else { return [] }
        var rounds: [[(Int, Int)]] = []
        let firstHalf = count - 1

        for _ in 0..<firstHalf {
            var pairs: [(Int, Int)] = []
            for i in 0..<(count / 2) {
                pairs.append((indices[i], indices[count - 1 - i]))
            }
            rounds.append(pairs)
            let last = indices.removeLast()
            indices.insert(last, at: 1)
        }

        var fixtures: [Fixture] = []
        for (round, pairs) in rounds.enumerated() {
            for (home, away) in pairs {
                fixtures.append(Fixture(matchday: round + 1, homeIndex: home, awayIndex: away))
            }
        }
        for (round, pairs) in rounds.enumerated() {
            for (home, away) in pairs {
                fixtures.append(Fixture(matchday: round + 1 + firstHalf, homeIndex: away, awayIndex: home))
            }
        }
        return fixtures
    }

    // MARK: - Strength & selection

    /// Returns the best starting XI for a club under a formation. Each slot
    /// prefers a player whose natural or secondary role fits it — a natural
    /// full-back beats a higher-rated centre-back for a wing-back slot —
    /// with the wide/specific slots resolved before the central ones.
    /// The strongest available XI in a formation. `restBias` (0 by default)
    /// lets the auto-pick assist nudge tired players out in favour of
    /// fresher squad depth ahead of a bigger match soon — 0 reproduces the
    /// plain "best available" pick used everywhere else.
    func bestXI(for club: Club, formation: Formation, restBias: Double = 0) -> [Player] {
        func top(_ position: Position, _ count: Int) -> [Player] {
            guard count > 0 else { return [] }
            var pool = club.players.filter { $0.position == position && $0.isAvailable }
            var chosen: [Player?] = Array(repeating: nil, count: count)
            let order = Array(0..<count).sorted { a, b in
                let aEdge = a == 0 || a == count - 1
                let bEdge = b == 0 || b == count - 1
                if aEdge != bEdge { return aEdge }
                return a < b
            }
            for index in order {
                let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: formation.wideMidfieldersAreWingers)
                func score(_ p: Player) -> Double {
                    let fitnessFactor = 0.9 + 0.1 * Double(p.fitness) / 100
                    let moraleFactor = 0.96 + 0.04 * Double(p.morale) / 100
                    let restPenalty = restBias * Double(100 - p.fitness)
                    return Double(p.effectiveRating(for: role)) * fitnessFactor * moraleFactor - restPenalty
                }
                guard let best = pool.max(by: { score($0) < score($1) }) else { continue }
                chosen[index] = best
                pool.removeAll { $0.id == best.id }
            }
            return chosen.compactMap { $0 }
        }
        var xi: [Player] = []
        xi += top(.goalkeeper, 1)
        xi += top(.defender, formation.defenders)
        xi += top(.midfielder, formation.midfielders)
        xi += top(.forward, formation.forwards)
        return xi
    }

    /// The number of starting slots a formation gives to a position.
    func slots(for position: Position) -> Int {
        switch position {
        case .goalkeeper: return 1
        case .defender:   return formation.defenders
        case .midfielder: return formation.midfielders
        case .forward:    return formation.forwards
        }
    }

    /// The user's current starting XI, in back-to-front order.
    /// Falls back to the best XI if the hand-picked side is incomplete.
    func userStartingXI() -> [Player] {
        // Injured or suspended players can't take the field even if still selected.
        let chosen = userClub.players.filter { userStarterIDs.contains($0.id) && $0.isAvailable }
        let xi = isValidLineup(chosen)
            ? chosen.sorted { $0.position.order < $1.position.order }
            : bestXI(for: userClub, formation: formation)
        let familiarity = formationFamiliarity
        guard familiarity < 1.0 else { return xi }
        return xi.map { player in
            var adjusted = player
            adjusted.rating = max(1, Int((Double(player.rating) * familiarity).rounded()))
            return adjusted
        }
    }

    /// True when the given players exactly fill every slot in the formation.
    func isValidLineup(_ players: [Player]) -> Bool {
        guard players.count == 11 else { return false }
        for position in Position.allCases {
            if players.filter({ $0.position == position }).count != slots(for: position) {
                return false
            }
        }
        return true
    }

    /// Empties the user's starting XI so it can be rebuilt by hand.
    func clearLineup() {
        userStarterIDs = []
    }

    /// Replaces the user's starting XI with the best available side.
    func autoPickLineup() {
        guard userClubIndex < clubs.count else { return }
        userStarterIDs = Set(bestXI(for: userClub, formation: formation).map { $0.id })
        validateRoles()
    }

    /// The cost to hire a staff member at a given level (1...3), in £000s.
    func staffHireCost(level: Int) -> Int { 300 * level * level }

    /// Hires (or replaces) a backroom appointment, paid as a one-off fee
    /// from the transfer budget, the same as a stadium or academy upgrade.
    @discardableResult
    func hireStaff(role: StaffRole, level: Int) -> String {
        let cost = staffHireCost(level: level)
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget to hire (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        let name = Self.randomManagerName()
        backroomStaff.removeAll { $0.role == role }
        backroomStaff.append(StaffMember(role: role, name: name, level: level))
        logLedger("Staff", amount: -cost, "Hired \(name) as \(role.rawValue)")
        addNews(.board, "New backroom appointment", "\(userClub.name) appoint \(name) as \(role.rawValue).")
        persist()
        return "\(name) appointed as \(role.rawValue)."
    }

    /// The staff level for a role, or 0 if nobody's been hired.
    func staffLevel(_ role: StaffRole) -> Int {
        backroomStaff.first { $0.role == role }?.level ?? 0
    }

    /// A rough "how much does this match matter" score: competition weight
    /// plus a nudge for a tougher opponent — used only to compare today's
    /// game against what's coming up next, not as a literal probability.
    func matchImportance(_ info: UserMatchInfo) -> Double {
        let opponentIndex = info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex
        let opponentPrestige = clubs.indices.contains(opponentIndex) ? Double(clubs[opponentIndex].prestige) : 60
        let competitionWeight: Double
        if !info.isCup {
            competitionWeight = 10
        } else if info.label.hasPrefix(Self.euroName) || info.label.hasPrefix(Self.uefaCupName) {
            competitionWeight = 9
        } else if info.label.hasPrefix(Self.communityShieldName) || info.label.hasPrefix(Self.uefaSuperCupName) {
            competitionWeight = 7
        } else if info.label.hasPrefix(Self.cupName) {
            competitionWeight = 6
        } else {
            competitionWeight = 4   // League Trophy
        }
        return competitionWeight + opponentPrestige / 10
    }

    /// Auto-picks today's starting XI the way a competent assistant coach
    /// would: the strongest available side by default, but easing off
    /// players who are short of full fitness when a clearly bigger match
    /// is coming up within the next few days — a cup replay midweek before
    /// a title-race league game at the weekend, say.
    func smartAutoPick() {
        guard userClubIndex < clubs.count else { return }
        let upcoming = upcomingUserMatches
        guard let today = upcoming.first else { autoPickLineup(); return }
        var restBias = 0.0
        if let next = upcoming.dropFirst().first {
            let daysUntilNext = Self.calendar.dateComponents([.day], from: today.date, to: next.date).day ?? 99
            let importanceGap = matchImportance(next.info) - matchImportance(today.info)
            if daysUntilNext <= 4 && importanceGap > 1.5 {
                restBias = min(0.12, importanceGap * 0.02)
            }
        }
        userStarterIDs = Set(bestXI(for: userClub, formation: formation, restBias: restBias).map { $0.id })
        validateRoles()
    }

    // MARK: - Squad roles

    /// Assigns any missing roles automatically and drops roles for players who
    /// have left the club.
    func validateRoles() {
        let squad = userClub.players
        func exists(_ id: UUID?) -> Bool { id != nil && squad.contains { $0.id == id } }

        if !exists(captainID) {
            // Ability still matters most, but a natural leader edges out a
            // similarly-rated teammate who isn't — not just the single
            // highest-rated outfield player regardless of temperament.
            let previousCaptainID = captainID
            captainID = squad.filter { $0.position != .goalkeeper }.max {
                (Double($0.rating) + Double($0.traits.leadership) * 0.3) < (Double($1.rating) + Double($1.traits.leadership) * 0.3)
            }?.id
            // Only a real moment when a departing captain is being
            // replaced — the very first assignment on a new save is just
            // squad setup, not a story worth telling.
            if previousCaptainID != nil, let newCaptain = squad.first(where: { $0.id == captainID }) {
                addNews(.board, "New captain", "\(newCaptain.name) has been named the new \(userClub.name) captain.",
                        player: newCaptain, clubName: userClub.name)
            }
        }
        if !exists(penaltyTakerID) {
            penaltyTakerID = squad.max { ($0.attributes["Shooting"] ?? 0) < ($1.attributes["Shooting"] ?? 0) }?.id
        }
        if !exists(freeKickTakerID) {
            freeKickTakerID = squad.max {
                (($0.attributes["Shooting"] ?? 0) + ($0.attributes["Passing"] ?? 0))
                    < (($1.attributes["Shooting"] ?? 0) + ($1.attributes["Passing"] ?? 0))
            }?.id
        }
        if !exists(cornerTakerID) {
            cornerTakerID = squad.max { ($0.attributes["Passing"] ?? 0) < ($1.attributes["Passing"] ?? 0) }?.id
        }
    }

    // MARK: - Youth academy

    /// Generates this season's crop of youth prospects for the user's club.
    func generateYouthIntake() {
        let base = userClub.prestige
        let level = userClub.youthFacilityLevel
        var sawForeignTalent = false
        // A Youth Factory club produces a bigger, better crop every year
        // regardless of the facility level itself — its hidden identity,
        // not something the manager built.
        let isYouthFactory = clubIdentity(forClubIndex: userClubIndex) == .youthFactory
        let count = Int.random(in: 3...5) + (level >= 3 ? 1 : 0) + (level >= 5 ? 1 : 0) + (isYouthFactory ? 1 : 0)
        // Better facilities narrow the usual below-first-team gap and
        // improve the odds of a scout unearthing talent from overseas.
        let identityPenaltyRelief = isYouthFactory ? 6 : 0
        let penaltyRange = (-28 + level * 3 + identityPenaltyRelief)...(-8 + level * 2 + identityPenaltyRelief)
        let foreignChance = 0.15 + Double(level) * 0.05
        let freshIntake: [Player] = (0..<count).map { _ in
            let position = Position.allCases.randomElement()!
            let rating = Self.clampRating(base + Int.random(in: penaltyRange))
            // A big academy's scouting network occasionally turns up a
            // prospect from overseas rather than the usual local intake.
            let isForeign = Double.random(in: 0..<1) < foreignChance
            let name = isForeign ? Self.randomForeignName() : Self.randomName()
            var player = Self.makePlayer(name: name, position: position, age: Int.random(in: 15...18), rating: rating, startYear: startYear)
            player.contractYears = Int.random(in: 2...3)
            player.isAcademyProduct = true
            if isForeign { sawForeignTalent = true }
            return player
        }

        // Prospects the manager hasn't promoted (or lost interest in)
        // don't just vanish at the next intake — a year of academy
        // coaching genuinely develops them, so they stick around, age up
        // and improve, until either promoted or they age out of the
        // academy entirely at 21.
        let developedHoldovers: [Player] = youthProspects.compactMap { prospect in
            var developed = prospect
            developed.age += 1
            guard developed.age <= 20 else { return nil }
            let growth = Int.random(in: 1...4) + (level >= 4 ? 1 : 0)
            developed.rating = Self.clampRating(developed.rating + growth)
            return developed
        }

        // Cap the pool so it can't grow without bound — keep the best
        // prospects if the combined list runs over a sensible academy size.
        let combined = (developedHoldovers + freshIntake).sorted { $0.rating > $1.rating }
        youthProspects = Array(combined.prefix(12))

        if sawForeignTalent {
            addNews(.info, "Academy news", "This year's youth intake includes a prospect spotted by the club's scouts overseas.")
        }
    }

    /// Promotes a youth prospect to the senior squad.
    @discardableResult
    func promoteYouth(_ player: Player) -> String {
        guard userClub.players.count < 30 else { return "Squad is full (30 players)." }
        guard let index = youthProspects.firstIndex(where: { $0.id == player.id }) else { return "No longer available." }
        let prospect = youthProspects.remove(at: index)
        clubs[userClubIndex].players.append(prospect)
        youthPromotedThisSeasonIDs.insert(prospect.id)
        addNews(.transfer, "Youth promoted", "\(prospect.name) (\(prospect.age)) has been promoted to the first team.",
               player: prospect, clubName: userClub.name)
        persist()
        return "\(prospect.name) promoted to the senior squad."
    }

    /// Releases a youth prospect.
    @discardableResult
    func releaseYouth(_ player: Player) -> String {
        youthProspects.removeAll { $0.id == player.id }
        persist()
        return "\(player.name) released."
    }

    // MARK: - Squad roles

    func setCaptain(_ player: Player) {
        guard captainID != player.id else { return }
        captainID = player.id
        addNews(.board, "New captain", "\(player.name) has been named the new \(userClub.name) captain.",
                player: player, clubName: userClub.name)
    }
    func setPenaltyTaker(_ player: Player) { penaltyTakerID = player.id }
    func setFreeKickTaker(_ player: Player) { freeKickTakerID = player.id }
    func setCornerTaker(_ player: Player) { cornerTakerID = player.id }

    /// Short role markers for a player (C / P / FK / CK).
    func roleMarkers(for id: UUID) -> [String] {
        var markers: [String] = []
        if id == captainID { markers.append("C") }
        if id == penaltyTakerID { markers.append("P") }
        if id == freeKickTakerID { markers.append("FK") }
        if id == cornerTakerID { markers.append("CK") }
        return markers
    }

    /// Result of trying to change a player's selection.
    enum SelectionChange {
        case added
        case removed
        case blocked(String)
    }

    /// Toggles a player in or out of the user's starting XI, respecting the
    /// formation's positional limits. Returns what happened so the UI can
    /// give feedback.
    @discardableResult
    func toggleStarter(_ player: Player) -> SelectionChange {
        if userStarterIDs.contains(player.id) {
            userStarterIDs.remove(player.id)
            return .removed
        }
        guard !player.isInjured else {
            return .blocked("\(player.name) is injured and unavailable.")
        }
        guard !player.isSuspended else {
            return .blocked("\(player.name) is suspended for \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es").")
        }
        let inPosition = userClub.players.filter {
            userStarterIDs.contains($0.id) && $0.position == player.position
        }.count
        guard inPosition < slots(for: player.position) else {
            let label = player.position == .goalkeeper ? "goalkeeper" : "\(player.position.rawValue) slots"
            return .blocked("No free \(label) — remove one first.")
        }
        userStarterIDs.insert(player.id)
        return .added
    }

    /// Puts a specific player into the starting XI for a given detailed
    /// role — the "quick select" action from the pitch screen. If that
    /// broad position's slots are already full, the weakest fit for the
    /// role is dropped to make room.
    @discardableResult
    func assignStarter(_ player: Player, forRole role: DetailedPosition) -> SelectionChange {
        guard !player.isInjured else {
            return .blocked("\(player.name) is injured and unavailable.")
        }
        guard !player.isSuspended else {
            return .blocked("\(player.name) is suspended for \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es").")
        }
        if userStarterIDs.contains(player.id) { return .added }
        let group = userClub.players.filter { userStarterIDs.contains($0.id) && $0.position == role.broad }
        if group.count >= slots(for: role.broad), let weakest = group.min(by: {
            $0.effectiveRating(for: role) < $1.effectiveRating(for: role)
        }) {
            userStarterIDs.remove(weakest.id)
        }
        userStarterIDs.insert(player.id)
        return .added
    }

    /// The strength of a set of players, used by the match engine. Happy,
    /// fresh players play closer to their rating; unhappy or tired ones
    /// undershoot it.
    func strengthValue(_ players: [Player]) -> Double {
        players.reduce(0.0) {
            let moraleFactor = 0.85 + 0.15 * Double($1.morale) / 100
            let fitnessFactor = 0.9 + 0.1 * Double($1.fitness) / 100
            return $0 + Double($1.rating) * moraleFactor * fitnessFactor
        }
    }

    /// The XI a club fields in a match: the user's hand-picked side for the
    /// managed club, or the best XI in its strongest formation for the AI.
    func matchXI(forClubIndex index: Int) -> [Player] {
        if index == userClubIndex {
            return userStartingXI()
        }
        let club = clubs[index]
        return bestXI(for: club, formation: aiFormation(for: club))
    }

    /// The formation the AI uses for a non-user club (its natural best).
    /// The shape a club's manager sets up in. With no `personality` given
    /// (or a neutral one), it's always whichever shape gets the strongest
    /// possible XI out of the squad. An aggressive or defensive manager
    /// instead picks the most attack-/defence-loaded shape among every
    /// formation that comes within 3% of that peak strength — a real
    /// stylistic choice, not just whatever's objectively best.
    func aiFormation(for club: Club, personality: ManagerPersonality? = nil) -> Formation {
        let ranked = Formation.all.sorted {
            strengthValue(bestXI(for: club, formation: $0)) > strengthValue(bestXI(for: club, formation: $1))
        }
        guard let best = ranked.first else { return Formation.all[0] }
        guard personality == .aggressive || personality == .defensive else { return best }
        let bestStrength = strengthValue(bestXI(for: club, formation: best))
        let viable = ranked.filter { strengthValue(bestXI(for: club, formation: $0)) >= bestStrength * 0.97 }
        if personality == .aggressive {
            return viable.max { $0.forwards < $1.forwards } ?? best
        }
        return viable.max { $0.defenders < $1.defenders } ?? best
    }

    /// The shape that gets the strongest XI out of the user's current
    /// squad — the same "best fit" logic the AI uses for itself, surfaced
    /// as a one-tap suggestion on the Tactics screen rather than something
    /// only rival managers benefit from.
    var recommendedFormation: Formation {
        aiFormation(for: userClub)
    }

}
