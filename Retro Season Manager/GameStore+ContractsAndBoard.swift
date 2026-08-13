//
//  GameStore+ContractsAndBoard.swift
//  Retro Season Manager
//
//  Contract renewals and squad morale, the news feed, and the
//  board's confidence in the manager.
//

import Foundation

extension GameStore {

    // MARK: - Contracts & morale

    /// The user's own players with a year or less left on their deal —
    /// worth renewing proactively on your own terms, even though a
    /// contract can no longer just run out and cost you the player.
    var expiringContracts: [Player] {
        userClub.players
            .filter { $0.contractYears <= 1 }
            .sorted { $0.contractYears != $1.contractYears ? $0.contractYears < $1.contractYears : $0.rating > $1.rating }
    }

    /// A player's standing in the pecking order right now — ability-based,
    /// with a boost for anyone nailed on in the user's own starting XI and
    /// an override for clear academy prospects. Computed rather than
    /// stored so it always reflects the squad's current shape.
    func squadRole(for player: Player) -> SquadRole {
        if player.age <= 20 && player.rating < 78 { return .youthProspect }
        let isOwnStarter = userStarterIDs.contains(player.id)
        switch player.rating {
        case 85...:
            return .starPlayer
        case 75..<85:
            return isOwnStarter ? .starPlayer : .firstTeamRegular
        case 65..<75:
            return isOwnStarter ? .firstTeamRegular : .rotation
        default:
            return isOwnStarter ? .rotation : .backup
        }
    }

    /// The wage a player would demand to renew, for the negotiation UI —
    /// scaled by their squad role rather than a flat markup, so a star's
    /// demands and a fringe player's are genuinely different conversations.
    func renewalDemand(_ player: Player) -> Int {
        Int(Double(player.wage) * squadRole(for: player).wageDemandMultiplier) + 1
    }

    /// The result of putting a contract offer to a player. A rejection
    /// carries the specific reason, and — when wage was the sticking
    /// point — a counter-offer figure the player would likely accept.
    enum ContractOutcome {
        case accepted(String)
        case rejected(reason: String, counterWage: Int?)
    }

    /// Puts a wage-and-length offer to a squad player. Whether they accept
    /// depends on how the wage compares to their demand, their current
    /// morale, and — for longer or very short deals — their age.
    @discardableResult
    func proposeRenewal(_ player: Player, wage: Int, years: Int, releaseClause: Int? = nil, signingOnFee: Int = 0) -> ContractOutcome {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return .rejected(reason: "That player is not in your squad.", counterWage: nil)
        }
        let projectedBill = userClub.wageBill - player.wage + wage
        guard projectedBill <= userClub.wageBudget else {
            return .rejected(reason: "The board won't sanction that wage — it would break the club's wage budget.", counterWage: nil)
        }
        guard signingOnFee <= userClub.transferBudget else {
            return .rejected(reason: "The board won't sanction a signing-on fee of that size — it would exceed the transfer budget.", counterWage: nil)
        }
        let demand = renewalDemand(player)
        let wageRatio = Double(wage) / Double(max(demand, 1))
        var chance = 0.5 + (wageRatio - 1.0) * 1.2
        chance += (Double(player.morale) - 50) / 250
        if years <= 1 && player.age < 30 { chance -= 0.12 }
        if years >= 4 && player.age >= 32 { chance -= 0.15 }
        chance += player.personality.renewalChanceAdjustment
        // Loyalty makes staying an easier yes; ambition pulls the other way.
        chance += Double(player.traits.loyalty - player.traits.ambition) / 300
        chance += min(0.08, Double(signingOnFee) / Double(max(demand, 1)) * 0.02)
        chance = min(0.97, max(0.03, chance))

        if Double.random(in: 0..<1) < chance {
            clubs[userClubIndex].players[index].contractYears = years
            clubs[userClubIndex].players[index].wage = wage
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 12)
            clubs[userClubIndex].players[index].wantsToLeave = false
            clubs[userClubIndex].players[index].releaseClause = releaseClause
            if signingOnFee > 0 {
                clubs[userClubIndex].transferBudget -= signingOnFee
            }
            var message = "\(player.name) signed a new \(years)-year deal at \(formatMoney(wage))/wk."
            if signingOnFee > 0 {
                message += " Signing-on fee: \(formatMoney(signingOnFee))."
            }
            if let releaseClause {
                message += " Release clause: \(formatMoney(releaseClause))."
            }
            addNews(.board, "Contract renewed", message, player: clubs[userClubIndex].players[index], clubName: userClub.name)
            persist()
            return .accepted(message)
        } else {
            clubs[userClubIndex].players[index].morale = max(0, clubs[userClubIndex].players[index].morale - 4)
            persist()

            // The single biggest reason, so the decline actually explains
            // itself instead of always blaming the wage.
            let reason: String
            if wageRatio < 0.9 {
                reason = "\(player.name) felt \(formatMoney(wage))/wk fell well short of his valuation."
            } else if years <= 1 && player.age < 30 {
                reason = "\(player.name) wants a longer commitment than \(years) year\(years == 1 ? "" : "s") at his age."
            } else if years >= 4 && player.age >= 32 {
                reason = "\(player.name) felt \(years) years was too long a deal at his age."
            } else if player.morale < 45 {
                reason = "\(player.name) is unhappy at the club right now and isn't ready to commit."
            } else {
                reason = "\(player.name) turned down the offer — wanted a little more."
            }

            // A counter only makes sense if wage was actually the sticking
            // point, and the club could plausibly afford to go higher.
            let counterWage: Int?
            if wageRatio < 1.05 {
                let proposed = Int(Double(demand) * 1.08)
                counterWage = (userClub.wageBill - player.wage + proposed <= userClub.wageBudget) ? proposed : nil
            } else {
                counterWage = nil
            }
            return .rejected(reason: reason, counterWage: counterWage)
        }
    }

    /// A negotiated transfer fee for signing any player directly (e.g. from
    /// search) — their base value (already driven by ability and age) with
    /// a premium or discount for how much contract time their club has left
    /// to hold them to. A long deal costs more to prise them out of; an
    /// expiring one costs much less, since the club's leverage is gone.
    func negotiatedFee(for player: Player) -> Int {
        let contractFactor: Double
        switch player.contractYears {
        case ...0: contractFactor = 0.45
        case 1:    contractFactor = 0.7
        case 2:    contractFactor = 1.0
        case 3:    contractFactor = 1.2
        default:   contractFactor = 1.45
        }
        return max(50, Int(Double(player.value) * contractFactor))
    }

    /// Signs a player found via search straight from their club, at a
    /// negotiated fee. Unlike the transfer market, this isn't limited to
    /// pre-generated targets — any player at any club is fair game.
    @discardableResult
    func signFromSearch(clubIndex: Int, playerID: UUID) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard clubIndex != userClubIndex else { return "\(userClub.name) can't buy from itself." }
        guard clubs.indices.contains(clubIndex),
              let playerIndex = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return "That player is no longer available."
        }
        let player = clubs[clubIndex].players[playerIndex]
        let fee = negotiatedFee(for: player)
        guard userClub.transferBudget >= fee else {
            return "Not enough transfer budget (need \(formatMoney(fee)))."
        }
        guard userClub.wageBill + player.wage <= userClub.wageBudget else {
            return "Wage budget won't stretch that far (\(formatMoney(player.wage))/wk needed, \(formatMoney(max(0, userClub.wageBudget - userClub.wageBill)))/wk free)."
        }
        guard userClub.players.count < 30 else { return "Your squad is full (30 players)." }

        clubs[clubIndex].players.remove(at: playerIndex)
        clubs[clubIndex].transferBudget += fee
        var signing = player
        signing.morale = 75
        signing.isTransferListed = false
        clubs[userClubIndex].players.append(signing)
        clubs[userClubIndex].transferBudget -= fee
        addNews(.transfer, "Signing complete", "You signed \(player.name) from \(clubs[clubIndex].name) for \(formatMoney(fee)).",
               player: signing, clubName: clubs[clubIndex].name)
        reactToUserSigning(signing, fee: fee)
        logLedger("Transfer in", amount: -fee, "Signed \(player.name) from \(clubs[clubIndex].name)")
        logTransferHistory(player.name, action: "Signed", otherClub: clubs[clubIndex].name, fee: fee)
        persist()
        return "Signed \(player.name) from \(clubs[clubIndex].name) for \(formatMoney(fee))."
    }

    /// The wage a free agent (or a player whose contract has already run
    /// out) would want to sign — there's no club to negotiate a fee with,
    /// so the whole negotiation is just personal terms.
    func freeAgentWageDemand(_ player: Player) -> Int {
        Int(Double(player.wage) * 1.1) + 1
    }

    /// Signs a player who costs no transfer fee at all — a genuine free
    /// agent from the market, or someone found via search whose contract
    /// has already expired — on agreed personal terms. Mirrors
    /// `proposeRenewal`'s negotiation math since it's fundamentally the
    /// same kind of conversation, just landing the player at a new club.
    @discardableResult
    func signFreeAgent(_ player: Player, fromClubIndex: Int?, wage: Int, years: Int, signingOnFee: Int = 0) -> ContractOutcome {
        guard transferWindowOpen else { return .rejected(reason: "The transfer window is closed.", counterWage: nil) }
        guard userClub.players.count < 30 else { return .rejected(reason: "Your squad is full (30 players).", counterWage: nil) }
        let projectedBill = userClub.wageBill + wage
        guard projectedBill <= userClub.wageBudget else {
            return .rejected(reason: "The board won't sanction that wage — it would break the club's wage budget.", counterWage: nil)
        }
        guard signingOnFee <= userClub.transferBudget else {
            return .rejected(reason: "The board won't sanction a signing-on fee of that size — it would exceed the transfer budget.", counterWage: nil)
        }

        let demand = freeAgentWageDemand(player)
        let wageRatio = Double(wage) / Double(max(demand, 1))
        var chance = 0.55 + (wageRatio - 1.0) * 1.2
        chance += (Double(player.morale) - 50) / 300
        chance += player.personality.renewalChanceAdjustment
        chance += min(0.08, Double(signingOnFee) / Double(max(demand, 1)) * 0.02)
        chance = min(0.97, max(0.05, chance))

        guard Double.random(in: 0..<1) < chance else {
            let reason = wageRatio < 0.9
                ? "\(player.name) felt \(formatMoney(wage))/wk fell well short of what he could get elsewhere."
                : "\(player.name) wasn't quite convinced by those terms."
            let counterWage = wageRatio < 1.05 ? Int(Double(demand) * 1.08) : nil
            return .rejected(reason: reason, counterWage: counterWage)
        }

        if let fromClubIndex, clubs.indices.contains(fromClubIndex),
           let playerIndex = clubs[fromClubIndex].players.firstIndex(where: { $0.id == player.id }) {
            clubs[fromClubIndex].players.remove(at: playerIndex)
        }
        var signing = player
        signing.wage = wage
        signing.contractYears = years
        signing.morale = 78
        signing.isTransferListed = false
        clubs[userClubIndex].players.append(signing)
        if signingOnFee > 0 {
            clubs[userClubIndex].transferBudget -= signingOnFee
        }
        transferMarket.removeAll { $0.player.id == player.id }
        let otherClub = fromClubIndex.flatMap { clubs.indices.contains($0) ? clubs[$0].name : nil }
        var message = "\(player.name) signed on a free transfer — a \(years)-year deal at \(formatMoney(wage))/wk."
        if signingOnFee > 0 {
            message += " Signing-on fee: \(formatMoney(signingOnFee))."
        }
        addNews(.transfer, "Free transfer complete", message, player: signing, clubName: otherClub)
        logTransferHistory(player.name, action: "Signed (free)", otherClub: otherClub, fee: nil)
        persist()
        return .accepted(message)
    }

    /// After a match, players who didn't feature lose a little morale; the
    /// unhappy and repeatedly-benched may ask to leave.
    func updateSquadMorale(appearedIDs: Set<UUID>) {
        for index in clubs[userClubIndex].players.indices {
            let player = clubs[userClubIndex].players[index]
            guard !appearedIDs.contains(player.id), !player.isInjured, !player.isSuspended else { continue }
            let drop = player.rating >= 74 ? Int.random(in: 2...5) : 1
            clubs[userClubIndex].players[index].morale = max(0, player.morale - drop)
            // An ambitious player grows restless sooner when he isn't
            // playing; a loyal one takes longer to reach the same point.
            let unhappyThreshold = min(40, max(10, 25 + (player.traits.ambition - player.traits.loyalty) / 10))
            if clubs[userClubIndex].players[index].morale <= unhappyThreshold,
               player.rating >= 72,
               !clubs[userClubIndex].players[index].wantsToLeave {
                clubs[userClubIndex].players[index].wantsToLeave = true
                let calmPhrasing = "\(player.name) is frustrated by a lack of game time and has asked to leave. Respond from his profile — talk him round, or list him for sale."
                let volatilePhrasing = "\(player.name) has stormed into the manager's office demanding a move, furious at being left out. Respond from his profile — talk him round, or list him for sale."
                addNews(.board, "Transfer request",
                        player.traits.temperament < 35 ? volatilePhrasing : calmPhrasing)
            }
        }
    }

    /// At season's end, decrements contracts; user players who run down their
    /// deal leave on a free, while rivals quietly re-sign their own.
    /// At season's end, decrements every contract. A club never loses a
    /// player just because a deal quietly ran down in the background — an
    /// expiring contract auto-renews for another 2-4 years, the same as
    /// any AI club re-signing its own. For the user's club this is worth
    /// a heads-up, since they may still want to sell or renegotiate; it's
    /// never an automatic, unwanted departure.
    func processContracts() {
        for clubIndex in clubs.indices {
            // A loyal manager ties players down for the long haul; a
            // money-saver or journeyman keeps deals short — never building
            // up long-term wage commitments they might not be around for.
            let renewalRange: ClosedRange<Int>
            switch personality(forClubIndex: clubIndex) {
            case .loyal:                       renewalRange = 3...5
            case .moneySaver, .journeyman:      renewalRange = 1...3
            default:                            renewalRange = 2...4
            }
            for index in clubs[clubIndex].players.indices {
                clubs[clubIndex].players[index].contractYears -= 1
                if clubs[clubIndex].players[index].contractYears <= 0 {
                    let newYears = Int.random(in: renewalRange)
                    clubs[clubIndex].players[index].contractYears = newYears
                    if clubIndex == userClubIndex {
                        addNews(.board, "Contract auto-renewed",
                                "\(clubs[clubIndex].players[index].name)'s deal ran down and the club quietly tied him to a new \(newYears)-year contract. Sell or renegotiate any time from the squad screen.")
                    }
                }
            }
        }
    }

    // MARK: - News feed

    func addNews(_ category: NewsCategory, _ title: String, _ body: String, player: Player? = nil, clubName: String? = nil) {
        var item = NewsItem(date: currentDate, category: category, title: title, body: body,
                            playerName: player?.name, playerRating: player?.rating,
                            playerPosition: player?.position, playerAge: player?.age,
                            clubName: clubName)
        if let paper = generateNewspaper(category: category, title: title, body: body, player: player, clubName: clubName) {
            newspapers.insert(paper, at: 0)
            if newspapers.count > Self.newspaperArchiveCap {
                newspapers.removeLast(newspapers.count - Self.newspaperArchiveCap)
            }
            item.newspaperID = paper.id
        }
        news.insert(item, at: 0)
        unreadNewsIDs.insert(item.id)
        if news.count > 60 {
            for dropped in news.suffix(news.count - 60) { unreadNewsIDs.remove(dropped.id) }
            news.removeLast(news.count - 60)
        }
    }

    func markNewsRead(_ item: NewsItem) {
        unreadNewsIDs.remove(item.id)
    }

    func markAllNewsRead() {
        unreadNewsIDs.removeAll()
    }

    // MARK: - Board

    /// A rough preview of what a club's board would expect, for comparing
    /// job offers — the same ladder logic as `setBoardObjective`, without
    /// the reputation-driven ambition creep (that's specific to a job
    /// already held, not a hypothetical new one).
    func previewObjective(forClubIndex index: Int) -> String {
        let tier = clubs[index].divisionTier
        let division = clubs.filter { $0.divisionTier == tier }.sorted { $0.prestige > $1.prestige }
        let rank = (division.firstIndex { $0.id == clubs[index].id } ?? 0) + 1
        let ladder: [String]
        let baseIndex: Int
        if tier == 0 {
            ladder = ["Avoid relegation", "Finish in the top half", "Qualify for Europe (top 4)", "Win the league"]
            baseIndex = rank <= 1 ? 3 : (rank <= 4 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        } else {
            let bottomLabel = tier == Self.divisionNames.count - 1 ? "Finish mid-table" : "Avoid relegation"
            ladder = [bottomLabel, "Finish in the top half", "Reach the play-offs (top 6)", "Win automatic promotion (top 2)"]
            baseIndex = rank <= 2 ? 3 : (rank <= 6 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        }
        return ladder[baseIndex]
    }

    func setBoardObjective() {
        // Rank the user's prestige within their own division.
        let division = clubs.filter { $0.divisionTier == userDivisionTier }.sorted { $0.prestige > $1.prestige }
        let rank = (division.firstIndex { $0.id == userClub.id } ?? 0) + 1
        let tier = userDivisionTier

        let ladder: [String]
        let baseIndex: Int
        if tier == 0 {
            ladder = ["Avoid relegation", "Finish in the top half", "Qualify for Europe (top 4)", "Win the league"]
            baseIndex = rank <= 1 ? 3 : (rank <= 4 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        } else {
            let bottomLabel = tier == Self.divisionNames.count - 1 ? "Finish mid-table" : "Avoid relegation"
            ladder = [bottomLabel, "Finish in the top half", "Reach the play-offs (top 6)", "Win automatic promotion (top 2)"]
            baseIndex = rank <= 2 ? 3 : (rank <= 6 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        }
        // Ambition creep: sustained success raises reputation, and a board
        // that's grown used to winning starts expecting more than the raw
        // squad strength alone would suggest.
        let escalation = managerReputation >= 90 ? 2 : (managerReputation >= 75 ? 1 : 0)
        let index = min(ladder.count - 1, baseIndex + escalation)
        boardObjective = ladder[index]
        boardConfidence = 60
    }

    func updateBoard(userWon: Bool, draw: Bool, isHome: Bool) {
        // A good assistant manager softens how badly a defeat lands with
        // both the board and the fans, without blunting the credit for a win.
        let assistantCushion = 1.0 - Double(staffLevel(.assistantManager)) * 0.12
        let delta = userWon ? 6 : (draw ? 1 : -Int((5.0 * difficulty.boardLossHarshness * assistantCushion).rounded()))
        let beforeConfidence = boardConfidence
        boardConfidence = min(100, max(0, boardConfidence + delta))
        let fanDelta = userWon ? 5 : (draw ? -1 : -Int((6.0 * assistantCushion).rounded()))
        let beforeFan = fanConfidence
        fanConfidence = min(100, max(0, fanConfidence + fanDelta))
        fanConfidenceTrend = fanConfidence - beforeFan
        // The fans' own mood feeds back into the board's, on top of
        // whatever the result itself already earned or cost.
        boardConfidence = min(100, max(0, boardConfidence + fanInfluenceOnBoard()))
        boardConfidenceTrend = boardConfidence - beforeConfidence

        var record = careerRecordByClub[userClub.name] ?? ClubCareerRecord()
        if userWon { record.wins += 1 } else if draw { record.draws += 1 } else { record.losses += 1 }
        if isHome {
            if userWon { record.homeWins += 1 } else if draw { record.homeDraws += 1 } else { record.homeLosses += 1 }
        } else {
            if userWon { record.awayWins += 1 } else if draw { record.awayDraws += 1 } else { record.awayLosses += 1 }
        }
        careerRecordByClub[userClub.name] = record
    }

    /// A board verdict on the window's business, once it closes — net
    /// spend against what was available, coloured by whether the squad
    /// clearly needed reinforcement.
    func reviewTransferWindowClose() {
        let net = transferBudgetAtWindowOpen - userClub.transferBudget
        let ratio = transferBudgetAtWindowOpen > 0 ? Double(net) / Double(transferBudgetAtWindowOpen) : 0
        let pressingNeed = !squadNeeds().isEmpty
        let verdict: String
        if net < 0 {
            verdict = "The board are pleased with the business — you banked \(formatMoney(-net)) more than you spent this window."
        } else if ratio >= 0.7 {
            verdict = "The board are pleased to see the club back you in the market, with \(formatMoney(net)) spent this window."
        } else if ratio <= 0.15 && pressingNeed {
            verdict = "The board privately question why so little was done given the squad's needs — only \(formatMoney(net)) spent this window."
        } else if ratio <= 0.15 {
            verdict = "The board are content with a quiet window — \(formatMoney(net)) spent, with the squad already in good shape."
        } else {
            verdict = "The board see this as sensible business — \(formatMoney(net)) spent this window."
        }
        addNews(.board, "Transfer window review", verdict)
    }

    /// A short read on the fanbase's current mood.
    var fanMoodLabel: String {
        switch fanConfidence {
        case 75...:   return "Buzzing"
        case 50..<75: return "Content"
        case 25..<50: return "Restless"
        default:      return "Furious"
        }
    }

    /// A short read on the manager's job security.
    var jobSecurity: String {
        switch boardConfidence {
        case 70...:   return "Secure"
        case 45..<70: return "Stable"
        case 25..<45: return "Under pressure"
        default:      return "At risk"
        }
    }

    /// The calendar year a player's contract runs out, e.g. 2003 for a deal
    /// that lapses at the end of the 2002/03 season.
    func contractExpiryYear(_ player: Player) -> Int {
        (startYear - 1) + season + player.contractYears
    }

}
