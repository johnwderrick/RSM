//
//  GameStore+Transfers.swift
//  Retro Season Manager
//
//  The transfer market: bids, AI-to-AI business, the shortlist,
//  scouting and loans.
//

import Foundation

extension GameStore {

    // MARK: - Transfer market

    /// Builds a fresh market of surplus players and free agents.
    func generateTransferMarket() {
        var targets: [TransferTarget] = []
        for index in clubs.indices where index != userClubIndex && clubs[index].divisionTier < 4 {
            let surplus = clubs[index].players.sorted { $0.rating < $1.rating }.prefix(3)
            for player in surplus {
                targets.append(TransferTarget(player: player, sellingClubIndex: index,
                                              askingPrice: Int(Double(player.value) * Double.random(in: 1.1...1.5))))
            }
        }
        for _ in 0..<6 {
            let player = Self.makeFreeAgent(startYear: startYear)
            targets.append(TransferTarget(player: player, sellingClubIndex: nil, askingPrice: player.value))
        }
        transferMarket = targets.shuffled()
        scoutedReports = [:]
        scoutingDue = [:]
        negotiationRounds = [:]
        sellNegotiationRounds = [:]
    }

    /// English football's transfer deadline in 2000/01 was a single date —
    /// 31 March — not the two-window (summer/January) system, which wasn't
    /// introduced until the 2002/03 season.
    var transferDeadlineDate: Date {
        let deadlineYear = Self.calendar.component(.year, from: seasonStartDate) + 1
        return Self.calendar.date(from: DateComponents(year: deadlineYear, month: 3, day: 31)) ?? seasonStartDate
    }

    var transferWindowOpen: Bool {
        currentDate <= transferDeadlineDate
    }

    /// Days left until the window shuts, while it's still open.
    var daysUntilTransferDeadline: Int? {
        guard transferWindowOpen else { return nil }
        let days = Self.calendar.dateComponents([.day], from: currentDate, to: transferDeadlineDate).day ?? 0
        return max(0, days)
    }

    /// The final couple of days before the deadline — AI activity spikes.
    var isDeadlineDayRush: Bool {
        guard let days = daysUntilTransferDeadline else { return false }
        return days <= 2
    }

    /// A label for the window state.
    var transferWindowStatus: String {
        guard transferWindowOpen else { return "CLOSED — reopens for the new season" }
        if let days = daysUntilTransferDeadline, days <= 2 {
            return days == 0 ? "DEADLINE DAY" : "OPEN — \(days) day\(days == 1 ? "" : "s") to deadline"
        }
        return "OPEN — until the 31 March deadline"
    }

    /// Signs a player from the market. Returns a message for the UI.
    @discardableResult
    func buyPlayer(_ target: TransferTarget) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard transferMarket.contains(where: { $0.id == target.id }) else {
            return "That player is no longer available."
        }
        guard userClub.transferBudget >= target.askingPrice else {
            return "Not enough transfer budget (need \(formatMoney(target.askingPrice)))."
        }
        guard userClub.wageBill + target.player.wage <= userClub.wageBudget else {
            return "Wage budget won't stretch that far (\(formatMoney(target.player.wage))/wk needed, \(formatMoney(max(0, userClub.wageBudget - userClub.wageBill)))/wk free)."
        }
        guard userClub.players.count < 30 else { return "Your squad is full (30 players)." }
        return beginPersonalTermsWait(target, price: target.askingPrice, sellOnPercentage: 0, buyBackFee: 0, includedPlayer: nil)
    }

    /// Moves a deal from "fee agreed" to "medical & personal terms
    /// pending" — the player leaves the seller's squad right away (a club
    /// doesn't keep playing someone it's agreed to sell) but doesn't join
    /// yours until personal terms are actually settled days later, same as
    /// a real transfer. No money changes hands yet.
    func beginPersonalTermsWait(_ target: TransferTarget, price: Int, sellOnPercentage: Int, buyBackFee: Int, includedPlayer: Player?) -> String {
        guard let sellerIndex = target.sellingClubIndex,
              let playerIndex = clubs[sellerIndex].players.firstIndex(where: { $0.id == target.player.id }) else {
            return "That deal has fallen through."
        }
        let player = clubs[sellerIndex].players.remove(at: playerIndex)
        transferMarket.removeAll { $0.id == target.id }
        let readyDate = Self.calendar.date(byAdding: .day, value: Int.random(in: 1...3), to: currentDate) ?? currentDate
        let deal = PendingTransferDeal(id: UUID(), player: player, sellingClubIndex: sellerIndex,
                                       sellingClubName: clubs[sellerIndex].name, agreedFee: price,
                                       sellOnPercentage: sellOnPercentage, buyBackFee: buyBackFee,
                                       includedPlayerID: includedPlayer?.id, includedPlayerName: includedPlayer?.name,
                                       readyDate: readyDate)
        pendingTransferDeals.append(deal)
        let message = "Fee of \(formatMoney(price)) agreed with \(clubs[sellerIndex].name) for \(player.name) — medical and personal terms to follow."
        addNews(.transfer, "Fee agreed", message, player: player, clubName: clubs[sellerIndex].name)
        persist()
        return message
    }

    /// Checks every pending deal's medical/paperwork clock, called once a
    /// day — when it runs out, the manager is told the player's ready to
    /// actually discuss personal terms.
    func checkPendingTransferDeals() {
        for index in pendingTransferDeals.indices
        where !pendingTransferDeals[index].isReady && currentDate >= pendingTransferDeals[index].readyDate {
            pendingTransferDeals[index].isReady = true
            let deal = pendingTransferDeals[index]
            addNews(.transfer, "\(deal.player.name) ready to talk terms",
                    "\(deal.player.name)'s medical is done — he's ready to discuss personal terms about his move from \(deal.sellingClubName).",
                    player: deal.player, clubName: deal.sellingClubName)
        }
    }

    /// The wage a player would want to actually sign for a new club, for
    /// the personal-terms negotiation UI — a modest step up on what he was
    /// on before, same shape as `freeAgentWageDemand`.
    func transferWageDemand(_ player: Player) -> Int {
        Int(Double(player.wage) * 1.15) + 1
    }

    /// Settles personal terms on a pending transfer deal — the step that
    /// actually completes the move. Money, the player and any makeweight
    /// only move on success; a rejection leaves the deal open to retry
    /// (or to walk away from via `withdrawPendingDeal`).
    @discardableResult
    func finalizePersonalTerms(_ deal: PendingTransferDeal, wage: Int, years: Int, signingOnFee: Int = 0) -> ContractOutcome {
        guard let dealIndex = pendingTransferDeals.firstIndex(where: { $0.id == deal.id }) else {
            return .rejected(reason: "That deal is no longer on the table.", counterWage: nil)
        }
        guard pendingTransferDeals[dealIndex].isReady else {
            return .rejected(reason: "\(deal.player.name) isn't ready to talk terms yet.", counterWage: nil)
        }
        guard userClub.wageBill + wage <= userClub.wageBudget else {
            return .rejected(reason: "The board won't sanction that wage — it would break the club's wage budget.", counterWage: nil)
        }
        guard userClub.transferBudget >= deal.agreedFee + signingOnFee else {
            return .rejected(reason: "The transfer budget can no longer cover the \(formatMoney(deal.agreedFee)) fee plus that signing-on fee.", counterWage: nil)
        }
        guard userClub.players.count < 30 else {
            return .rejected(reason: "Your squad is full (30 players).", counterWage: nil)
        }

        let demand = transferWageDemand(deal.player)
        let wageRatio = Double(wage) / Double(max(demand, 1))
        var chance = 0.55 + (wageRatio - 1.0) * 1.2
        chance += (Double(deal.player.morale) - 50) / 300
        chance += deal.player.personality.renewalChanceAdjustment
        // An ambitious player is a little more open to a fresh move; a
        // loyal one is a little harder to prise from his current club.
        chance += Double(deal.player.traits.ambition - deal.player.traits.loyalty) / 400
        chance += min(0.08, Double(signingOnFee) / Double(max(demand, 1)) * 0.02)
        chance = min(0.97, max(0.05, chance))

        guard Double.random(in: 0..<1) < chance else {
            let reason = wageRatio < 0.9
                ? "\(deal.player.name) felt \(formatMoney(wage))/wk fell well short of what he wanted to make the move."
                : "\(deal.player.name) wasn't quite convinced by those personal terms."
            let counterWage = wageRatio < 1.05 ? Int(Double(demand) * 1.08) : nil
            return .rejected(reason: reason, counterWage: counterWage)
        }

        var extras = ""
        clubs[deal.sellingClubIndex].transferBudget += deal.agreedFee
        if let includedPlayerID = deal.includedPlayerID,
           let ownIndex = clubs[userClubIndex].players.firstIndex(where: { $0.id == includedPlayerID }) {
            var makeweight = clubs[userClubIndex].players.remove(at: ownIndex)
            makeweight.morale = 65
            makeweight.isTransferListed = false
            clubs[deal.sellingClubIndex].players.append(makeweight)
            userStarterIDs.remove(makeweight.id)
            validateRoles()
            extras += " \(makeweight.name) moved the other way as part of the deal."
        }
        var signing = deal.player
        signing.wage = wage
        signing.contractYears = years
        signing.morale = 78
        signing.isTransferListed = false
        if deal.sellOnPercentage > 0 {
            signing.sellOnClause = SellOnClause(club: deal.sellingClubName, percentage: deal.sellOnPercentage)
            extras += " \(deal.sellingClubName) retain a \(deal.sellOnPercentage)% sell-on clause."
        }
        if deal.buyBackFee > 0 {
            signing.buyBackClause = BuyBackClause(club: deal.sellingClubName, fee: deal.buyBackFee)
            extras += " \(deal.sellingClubName) hold a \(formatMoney(deal.buyBackFee)) buy-back option."
        }
        clubs[userClubIndex].players.append(signing)
        clubs[userClubIndex].transferBudget -= (deal.agreedFee + signingOnFee)
        if signingOnFee > 0 {
            extras += " Signing-on fee: \(formatMoney(signingOnFee))."
        }
        pendingTransferDeals.remove(at: dealIndex)
        let message = "Signed \(deal.player.name) from \(deal.sellingClubName) for \(formatMoney(deal.agreedFee))." + extras
        addNews(.transfer, "Signing complete", message, player: signing, clubName: deal.sellingClubName)
        reactToUserSigning(signing, fee: deal.agreedFee)
        logLedger("Transfer in", amount: -deal.agreedFee, "Signed \(deal.player.name)")
        logTransferHistory(deal.player.name, action: "Signed", otherClub: deal.sellingClubName, fee: deal.agreedFee)
        persist()
        return .accepted(message)
    }

    /// Walks away from a pending deal before personal terms are settled —
    /// the player simply returns to the selling club, since nothing about
    /// the move was ever finalised.
    @discardableResult
    func withdrawPendingDeal(_ deal: PendingTransferDeal) -> String {
        guard let dealIndex = pendingTransferDeals.firstIndex(where: { $0.id == deal.id }) else {
            return "That deal is no longer on the table."
        }
        let removed = pendingTransferDeals.remove(at: dealIndex)
        if clubs.indices.contains(removed.sellingClubIndex) {
            clubs[removed.sellingClubIndex].players.append(removed.player)
        }
        persist()
        return "Talks with \(removed.player.name) broken off."
    }

    /// The result of putting a cash bid to a selling club: either they
    /// accept outright, or knock it back — sometimes with a counter figure
    /// they'd actually listen to, sometimes dismissing it entirely.
    enum BidOutcome {
        case accepted(String)
        case rejected(reason: String, counterPrice: Int?)
    }

    /// Proposes a transfer fee below (or at) the asking price. A genuine
    /// multi-round negotiation, not a single accept/reject roll: the gap
    /// narrows with each round rather than the club repeating the same
    /// counter forever, a club under real financial pressure will settle
    /// for less than a wealthy one, and dragging it out too long — or
    /// lowballing too hard — makes them walk away from the table entirely
    /// for the rest of this window.
    @discardableResult
    func proposeBid(_ target: TransferTarget, amount: Int, sellOnPercentage: Int = 0, buyBackFee: Int = 0, includedPlayer: Player? = nil) -> BidOutcome {
        guard transferWindowOpen else { return .rejected(reason: "The transfer window is closed.", counterPrice: nil) }
        guard transferMarket.contains(where: { $0.id == target.id }) else {
            return .rejected(reason: "That deal has fallen through — they're no longer willing to talk.", counterPrice: nil)
        }
        guard userClub.players.count < 30 else { return .rejected(reason: "Your squad is full (30 players).", counterPrice: nil) }
        guard userClub.transferBudget >= amount else {
            return .rejected(reason: "Not enough transfer budget to make that offer.", counterPrice: nil)
        }
        if let includedPlayer {
            guard userClub.players.contains(where: { $0.id == includedPlayer.id }) else {
                return .rejected(reason: "\(includedPlayer.name) is no longer available to include in the deal.", counterPrice: nil)
            }
        }

        // Free agents don't cost a fee at all — they're signed on personal
        // terms via `signFreeAgent` instead, so this path is club-to-club only.
        guard let sellerIndex = target.sellingClubIndex else {
            return .rejected(reason: "\(target.player.name) is a free agent — sort a contract with him instead of a fee.", counterPrice: nil)
        }

        let seller = clubs[sellerIndex]
        // A club whose transfer budget is thin next to its wage bill has
        // real financial pressure and less leverage to hold out for full price.
        let underPressure = seller.transferBudget < seller.wageBill * 8
        let stance = clubNegotiationStances.indices.contains(sellerIndex) ? clubNegotiationStances[sellerIndex] : .balanced
        let hardness = stance.hardnessMultiplier * stance.starPlayerHardness(rating: target.player.rating)
        let acceptThreshold = (underPressure ? 0.90 : 1.0) * hardness
        let walkAwayThreshold = (underPressure ? 0.55 : 0.68) * hardness

        // A makeweight player adds real value to the deal from the seller's
        // side; a sell-on cut or a stingy buy-back fee sweetens it further —
        // each nudges their willingness to say yes without changing the cash
        // gap that drives the counter-offer figure shown back to the user.
        let effectiveOffer = amount + (includedPlayer?.value ?? 0)
        var ratio = Double(effectiveOffer) / Double(max(target.askingPrice, 1))
        ratio += Double(sellOnPercentage) / 100.0 * 0.15
        if buyBackFee > 0 {
            let discount = max(0, 1 - Double(buyBackFee) / Double(max(target.player.value, 1)))
            ratio += discount * 0.12
        }

        let attempt = (negotiationRounds[target.id] ?? 0) + 1
        negotiationRounds[target.id] = attempt

        if ratio >= acceptThreshold {
            negotiationRounds[target.id] = nil
            return .accepted(beginPersonalTermsWait(target, price: amount, sellOnPercentage: sellOnPercentage, buyBackFee: buyBackFee, includedPlayer: includedPlayer))
        }

        if attempt >= 4 || ratio < walkAwayThreshold {
            negotiationRounds[target.id] = nil
            transferMarket.removeAll { $0.id == target.id }
            return .rejected(reason: "\(seller.name) have walked away from the table — that's the end of this deal, for now.", counterPrice: nil)
        }

        let gap = Double(target.askingPrice) - Double(amount)
        let concession = min(0.55, (0.22 + Double(attempt) * 0.08) / hardness)
        let counter = min(target.askingPrice, amount + Int(gap * concession))
        let roundLabel = attempt >= 3 ? "final offer" : "counter"
        return .rejected(reason: "\(seller.name) turned that down — their \(roundLabel) is \(formatMoney(counter)).", counterPrice: counter)
    }

    /// A real profit, not a rounding error — sold for comfortably more
    /// than whatever this same player originally cost, per the club's own
    /// transfer history. Five such sales in a career is a real pattern,
    /// not luck.
    private func checkTransferGenius(playerName: String, soldFee: Int) {
        guard soldFee > 0,
              let signedEntry = transferHistory.last(where: { $0.playerName == playerName && $0.action.hasPrefix("Signed") }),
              let boughtFee = signedEntry.fee, boughtFee > 0,
              Double(soldFee) >= Double(boughtFee) * 1.8 else { return }
        profitableSalesCount += 1
        if profitableSalesCount >= 5 { unlock(.transferGenius) }
    }

    /// Sells one of the user's players. Returns a message for the UI.
    @discardableResult
    func sellPlayer(_ player: Player) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard userClub.players.count > 15 else { return "You must keep at least 16 players." }
        let cover = userClub.players.filter { $0.position == player.position }.count
        let minimumCover = player.position == .goalkeeper ? 2 : 3
        guard cover > minimumCover else { return "Not enough cover at \(player.position.rawValue) to sell." }
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return "That player is not in your squad."
        }
        let marketFee = Int(Double(player.value) * 0.9)
        var fee = marketFee
        var extras = ""
        if let clause = player.buyBackClause, clause.fee < marketFee {
            fee = clause.fee
            extras += " \(clause.club) triggered their \(formatMoney(clause.fee)) buy-back clause."
        }
        if let clause = player.sellOnClause {
            let cut = Int(Double(fee) * Double(clause.percentage) / 100.0)
            if cut > 0, let clubIndex = clubs.firstIndex(where: { $0.name == clause.club }) {
                clubs[clubIndex].transferBudget += cut
                fee -= cut
                extras += " \(clause.club) took a \(clause.percentage)% sell-on cut of \(formatMoney(cut))."
            }
        }
        clubs[userClubIndex].players.remove(at: index)
        clubs[userClubIndex].transferBudget += fee
        userStarterIDs.remove(player.id)
        validateRoles()
        let message = "Sold \(player.name) for \(formatMoney(fee))." + extras
        addNews(.transfer, "Player sold", message, player: player)
        reactToSellingFanFavourite(player)
        logLedger("Transfer out", amount: fee, "Sold \(player.name)")
        logTransferHistory(player.name, action: "Sold", otherClub: nil, fee: fee)
        checkTransferGenius(playerName: player.name, soldFee: fee)
        persist()
        return message
    }

    /// Toggles whether one of the user's players is listed for sale.
    func toggleTransferList(_ player: Player) {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else { return }
        clubs[userClubIndex].players[index].isTransferListed.toggle()
    }

    /// Returns the current, possibly-updated version of a squad player.
    func currentPlayer(_ id: UUID) -> Player? {
        clubs[userClubIndex].players.first { $0.id == id }
    }

    // MARK: - AI transfers & offers

    /// One rival-to-rival transfer, keeping the world's squads moving.
    /// Picks an index with probability proportional to `weight`, so richer
    /// or more prestigious clubs act more often without ever excluding the
    /// smaller ones. Falls back to a plain random pick if all weights are 0.
    func weightedRandomIndex(from indices: [Int], weight: (Int) -> Double) -> Int? {
        let weights = indices.map { max(0.1, weight($0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return indices.randomElement() }
        var roll = Double.random(in: 0..<total)
        for (index, w) in zip(indices, weights) {
            if roll < w { return index }
            roll -= w
        }
        return indices.last
    }

    /// A rich, in-form club buys more often and can reach further up a
    /// seller's squad list — a squad genuinely gets stronger after a big
    /// ownership-driven budget boost, rather than sitting static forever.
    /// Names that follow a scripted real-world path (`MarqueePlayers`) and
    /// so must never get swept up in ordinary random AI transfer activity
    /// — otherwise Ronaldo Basso could end up wherever the random churn sends
    /// him instead of Old Trafford Reds, Bernabéu Whites, and so on.
    static let marqueeProtectedNames: Set<String> = {
        Set(MarqueePlayers.arrivals.map { $0.name } + MarqueePlayers.transfers.map { $0.name })
    }()

    /// This club's hidden manager trait, if the array's in sync with `clubs`
    /// (always true post-setup; older saves fall back gracefully to nil).
    func personality(forClubIndex index: Int) -> ManagerPersonality? {
        managerPersonalities.indices.contains(index) ? managerPersonalities[index] : nil
    }

    private func aiBuyerWeight(forClubIndex index: Int) -> Double {
        let base = sqrt(Double(clubs[index].transferBudget))
        switch personality(forClubIndex: index) {
        case .bigSpender: return base * 1.8
        case .moneySaver: return base * 0.5
        default:          return base
        }
    }

    func processAITransfer() {
        let aiClubs = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 }
        guard let buyer = weightedRandomIndex(from: aiClubs, weight: { aiBuyerWeight(forClubIndex: $0) }) else { return }
        guard let seller = aiClubs.filter({ $0 != buyer }).randomElement() else { return }
        let ranked = clubs[seller].players.sorted { $0.rating > $1.rating }
        guard ranked.count > 15 else { return }
        let buyerPersonality = personality(forClubIndex: buyer)
        // A well-funded buyer can shop closer to the seller's best XI; a
        // modest one is limited to squad depth — a money-saver always
        // shops that bargain end, whatever its actual budget.
        let skip = buyerPersonality == .moneySaver ? 9 : (clubs[buyer].transferBudget > 20_000 ? 3 : 9)
        var pool = Array(ranked.dropFirst(skip)).filter { !Self.marqueeProtectedNames.contains($0.name) }
        switch buyerPersonality {
        case .youthDeveloper:
            let young = pool.filter { $0.age <= 23 }
            if !young.isEmpty { pool = young }
        case .aggressive:
            let attackers = pool.filter { $0.position == .forward || $0.position == .midfielder }
            if !attackers.isEmpty { pool = attackers }
        case .defensive:
            let defenders = pool.filter { $0.position == .defender || $0.position == .goalkeeper }
            if !defenders.isEmpty { pool = defenders }
        default:
            break
        }
        guard let target = weightedRandomIndex(from: pool.indices.map { $0 }, weight: { Double(pool[$0].rating) * Double(pool[$0].rating) })
            .map({ pool[$0] }) else { return }
        // A big spender pays well over the odds; a money-saver rarely pays a premium at all.
        let priceCeiling: ClosedRange<Double> = buyerPersonality == .bigSpender ? 1.1...1.7
            : (buyerPersonality == .moneySaver ? 0.9...1.15 : 1.0...1.4)
        let price = Int(Double(target.value) * Double.random(in: priceCeiling))
        guard clubs[buyer].transferBudget >= price else { return }

        if let index = clubs[seller].players.firstIndex(where: { $0.id == target.id }) {
            clubs[seller].players.remove(at: index)
        }
        clubs[seller].transferBudget += price
        clubs[buyer].players.append(target)
        clubs[buyer].transferBudget -= price
        transferMarket.removeAll { $0.player.id == target.id }
        addNews(.transfer, "Transfer completed",
                "\(clubs[buyer].name) sign \(target.name) from \(clubs[seller].name) for \(formatMoney(price)).")
    }

    /// How keen a given rival is to bid for this specific target, given
    /// their hidden trait — a big spender chases anyone, a money-saver
    /// rarely bothers, and youth/aggressive/defensive managers lean toward
    /// targets that fit their profile.
    private func bidWeight(forClubIndex index: Int, target: Player) -> Double {
        switch personality(forClubIndex: index) {
        case .bigSpender:      return 2.0
        case .moneySaver:      return 0.4
        case .youthDeveloper:  return target.age <= 23 ? 2.2 : 0.6
        case .aggressive:      return (target.position == .forward || target.position == .midfielder) ? 1.6 : 0.8
        case .defensive:       return (target.position == .defender || target.position == .goalkeeper) ? 1.6 : 0.8
        default:                return 1.0
        }
    }

    /// A rival club bids for one of the user's players.
    func generateOfferForUser() {
        let listed = userClub.players.filter { $0.isTransferListed }
        let pool = listed.isEmpty ? userClub.players.filter { $0.rating >= 72 } : listed
        guard let target = pool.randomElement() else { return }
        // A release clause is a contractual floor — any bid meets it or beats it.
        let price = max(target.releaseClause ?? 0, Int(Double(target.value) * Double.random(in: 1.0...1.5)))
        let buyers = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 && clubs[$0].transferBudget >= price }
        guard let buyer = weightedRandomIndex(from: buyers, weight: { bidWeight(forClubIndex: $0, target: target) }) else { return }
        let expiry = Self.calendar.date(byAdding: .day, value: 6, to: currentDate) ?? currentDate
        pendingOffers.append(TransferOffer(playerID: target.id, playerName: target.name,
                                           fromClubIndex: buyer, amount: price, expiryDate: expiry))
        let clauseNote = target.releaseClause != nil ? " — his release clause has been triggered" : ""
        addNews(.offer, "Bid received",
                "\(clubs[buyer].name) have bid \(formatMoney(price)) for \(target.name)\(clauseNote). Respond in Transfers.")
    }

    /// Drops offers that have passed their deadline.
    func expireOffers() {
        let live = pendingOffers.filter { $0.expiryDate >= currentDate }
        if live.count != pendingOffers.count { pendingOffers = live }
    }

    /// Accepts a rival's bid: sells the player and banks the fee.
    @discardableResult
    func acceptOffer(_ offer: TransferOffer) -> String {
        guard pendingOffers.contains(where: { $0.id == offer.id }) else { return "Offer withdrawn." }
        if let failure = completeSale(offer: offer, price: offer.amount) { return failure }
        return "Sold \(offer.playerName) for \(formatMoney(offer.amount))."
    }

    /// The actual mechanics of selling to a rival club at an agreed price —
    /// shared by `acceptOffer` (accepting as-is) and `counterSellOffer`
    /// (accepting after a successful counter). Returns nil on success, or
    /// a user-facing failure message.
    private func completeSale(offer: TransferOffer, price: Int) -> String? {
        guard let playerIndex = clubs[userClubIndex].players.firstIndex(where: { $0.id == offer.playerID }) else {
            pendingOffers.removeAll { $0.id == offer.id }
            return "That player has already left."
        }
        let player = clubs[userClubIndex].players[playerIndex]
        let cover = userClub.players.filter { $0.position == player.position }.count
        let minimumCover = player.position == .goalkeeper ? 2 : 3
        guard userClub.players.count > 15, cover > minimumCover else {
            return "Can't sell \(player.name) — not enough squad cover."
        }
        guard clubs.indices.contains(offer.fromClubIndex) else {
            pendingOffers.removeAll { $0.id == offer.id }
            return "That club is no longer interested."
        }
        clubs[userClubIndex].players.remove(at: playerIndex)
        clubs[userClubIndex].transferBudget += price
        clubs[offer.fromClubIndex].players.append(player)
        clubs[offer.fromClubIndex].transferBudget = max(0, clubs[offer.fromClubIndex].transferBudget - price)
        userStarterIDs.remove(player.id)
        validateRoles()
        pendingOffers.removeAll { $0.id == offer.id }
        sellNegotiationRounds.removeValue(forKey: offer.id)
        addNews(.transfer, "Player sold",
                "You accepted \(clubs[offer.fromClubIndex].name)'s \(formatMoney(price)) bid for \(player.name).",
                player: player, clubName: clubs[offer.fromClubIndex].name)
        logLedger("Transfer out", amount: price, "Sold \(player.name) to \(clubs[offer.fromClubIndex].name)")
        logTransferHistory(player.name, action: "Sold", otherClub: clubs[offer.fromClubIndex].name, fee: price)
        checkTransferGenius(playerName: player.name, soldFee: price)
        persist()
        return nil
    }

    /// Counters a rival's bid with a higher asking price — the seller's
    /// side of a real negotiation, mirroring `proposeBid` from the buyer's
    /// perspective: the rival can accept outright, come back with an
    /// improved (but still short) offer, or walk away entirely.
    @discardableResult
    func counterSellOffer(_ offer: TransferOffer, askingAmount: Int) -> BidOutcome {
        guard let index = pendingOffers.firstIndex(where: { $0.id == offer.id }) else {
            return .rejected(reason: "That offer is no longer available.", counterPrice: nil)
        }
        guard let player = userClub.players.first(where: { $0.id == offer.playerID }) else {
            pendingOffers.remove(at: index)
            return .rejected(reason: "That player is no longer available.", counterPrice: nil)
        }
        guard clubs.indices.contains(offer.fromClubIndex) else {
            pendingOffers.remove(at: index)
            return .rejected(reason: "That club is no longer interested.", counterPrice: nil)
        }
        let buyer = clubs[offer.fromClubIndex]
        let attempt = (sellNegotiationRounds[offer.id] ?? 0) + 1
        sellNegotiationRounds[offer.id] = attempt

        // As a buyer, hardness resists paying above value rather than
        // demanding above it — the multiplier divides instead of multiplies.
        let stance = clubNegotiationStances.indices.contains(offer.fromClubIndex) ? clubNegotiationStances[offer.fromClubIndex] : .balanced
        let hardness = stance.hardnessMultiplier * stance.starPlayerHardness(rating: player.rating)
        let ratio = Double(askingAmount) / Double(max(player.value, 1))
        let acceptThreshold = 1.15 / hardness
        let walkAwayThreshold = 1.6 / hardness

        if ratio <= acceptThreshold, buyer.transferBudget >= askingAmount {
            if let failure = completeSale(offer: offer, price: askingAmount) {
                return .rejected(reason: failure, counterPrice: nil)
            }
            return .accepted("\(buyer.name) agree to your asking price of \(formatMoney(askingAmount)).")
        }
        guard attempt < 4, ratio < walkAwayThreshold, buyer.transferBudget >= offer.amount else {
            pendingOffers.remove(at: index)
            sellNegotiationRounds.removeValue(forKey: offer.id)
            return .rejected(reason: "\(buyer.name) have walked away — your price was too high.", counterPrice: nil)
        }
        let gap = askingAmount - offer.amount
        let concession = min(0.5, (0.2 + Double(attempt) * 0.08) / hardness)
        let counter = min(askingAmount, min(buyer.transferBudget, offer.amount + Int(Double(gap) * concession)))
        pendingOffers[index].amount = counter
        return .rejected(reason: "\(buyer.name) improve their offer to \(formatMoney(counter)).", counterPrice: counter)
    }

    /// Rejects a rival's bid.
    func rejectOffer(_ offer: TransferOffer) {
        pendingOffers.removeAll { $0.id == offer.id }
        addNews(.info, "Bid rejected", "You turned down the bid for \(offer.playerName).")
    }

    // MARK: - Shortlist

    func isShortlisted(_ playerID: UUID) -> Bool {
        shortlistedPlayerIDs.contains(playerID)
    }

    /// Adds or removes a player from the watchlist.
    func toggleShortlist(_ playerID: UUID) {
        if shortlistedPlayerIDs.contains(playerID) {
            shortlistedPlayerIDs.remove(playerID)
        } else {
            shortlistedPlayerIDs.insert(playerID)
        }
        persist()
    }

    /// Every shortlisted player still found in the world, with their current club.
    var shortlistedResults: [(player: Player, clubIndex: Int)] {
        guard !shortlistedPlayerIDs.isEmpty else { return [] }
        var results: [(player: Player, clubIndex: Int)] = []
        for (index, club) in clubs.enumerated() {
            for player in club.players where shortlistedPlayerIDs.contains(player.id) {
                results.append((player, index))
            }
        }
        return results.sorted { $0.player.rating > $1.player.rating }
    }

    // MARK: - Scouting

    /// The scouting state of a transfer target.
    enum ScoutState { case unscouted, inProgress, scouted(ScoutReport) }

    func scoutState(for target: TransferTarget) -> ScoutState {
        if let report = scoutedReports[target.id] { return .scouted(report) }
        if scoutingDue[target.id] != nil { return .inProgress }
        return .unscouted
    }

    /// Sends a scout to assess a target; the report takes three days.
    func scout(_ target: TransferTarget) {
        guard scoutedReports[target.id] == nil, scoutingDue[target.id] == nil else { return }
        let days = max(1, 3 - staffLevel(.chiefScout) - userClub.scoutingNetworkLevel / 2)
        scoutingDue[target.id] = Self.calendar.date(byAdding: .day, value: days, to: currentDate) ?? currentDate
        addNews(.info, "Scout assigned", "A scout is watching \(target.player.name). Report in ~\(days) day\(days == 1 ? "" : "s").")
    }

    /// Finalises any scouting assignments whose deadline has passed.
    func completeScouting() {
        let ready = scoutingDue.filter { $0.value <= currentDate }
        guard !ready.isEmpty else { return }
        for (id, _) in ready {
            scoutingDue.removeValue(forKey: id)
            guard let target = transferMarket.first(where: { $0.id == id }) else { continue }
            let report = makeScoutReport(for: target.player)
            scoutedReports[id] = report
            addNews(.info, "Scout report: \(target.player.name)", report.verdict)
        }
    }

    func makeScoutReport(for player: Player) -> ScoutReport {
        let growth: Int
        switch player.age {
        case ..<21:   growth = Int.random(in: 4...12)
        case 21...24: growth = Int.random(in: 1...7)
        case 25...28: growth = Int.random(in: 0...3)
        default:      growth = -Int.random(in: 0...3)
        }
        let potential = min(95, max(player.rating, player.rating + growth))

        let squadAverage = averageRating(atPosition: player.position, forClubIndex: userClubIndex)
        let verdict: String
        if player.rating >= squadAverage + 3 {
            verdict = "Clear upgrade on your current \(player.position.rawValue) options."
        } else if player.rating >= squadAverage - 2 {
            verdict = "A useful squad player at \(player.position.rawValue)."
        } else if potential >= squadAverage + 2 {
            verdict = "Raw, but strong potential — one for the future."
        } else {
            verdict = "Below the level of your current squad."
        }
        let note = "Age \(player.age) · current \(player.rating) · potential ~\(potential)."

        // A better scouting network narrows the estimate and firms up
        // confidence — never an exact hidden number handed straight over.
        let networkLevel = userClub.scoutingNetworkLevel
        let widthFraction = max(0.10, 0.35 - Double(networkLevel) * 0.05)
        let valueRangeLow = Int(Double(player.value) * (1 - widthFraction))
        let valueRangeHigh = Int(Double(player.value) * (1 + widthFraction))
        let confidence = min(95, 55 + networkLevel * 8)

        return ScoutReport(playerID: player.id, playerName: player.name, potential: potential, verdict: verdict, note: note,
                           valueRangeLow: valueRangeLow, valueRangeHigh: valueRangeHigh, confidence: confidence)
    }

    /// Sends the scouting network out into the wider world (or specifically
    /// after youth talent) rather than waiting on a single named target —
    /// surfaces a handful of players from other clubs who weren't already
    /// on the market, adds them as biddable targets at a premium (their
    /// club isn't actively trying to sell), and has a full report ready
    /// immediately, since this is the payoff of an active scouting mission
    /// rather than a report on someone already spotted.
    @discardableResult
    func scoutTheWorld(youthOnly: Bool) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        let alreadyListedIDs = Set(transferMarket.map { $0.player.id })
        var candidates: [(clubIndex: Int, player: Player)] = []
        for (index, club) in clubs.enumerated() where index != userClubIndex {
            for player in club.players where !alreadyListedIDs.contains(player.id) {
                if youthOnly && player.age > 20 { continue }
                candidates.append((index, player))
            }
        }
        guard !candidates.isEmpty else {
            return youthOnly ? "No fresh young talent turned up this time — try again soon."
                              : "Nothing new turned up this time — try again soon."
        }
        // Bias toward the more promising finds without it always being
        // the single best player in the pyramid.
        let sorted = candidates.sorted { $0.player.rating > $1.player.rating }
        // A bigger scouting network widens both the shortlist it draws
        // from and how many genuine finds come back from one mission.
        let shortlistSize = 14 + userClub.scoutingNetworkLevel * 2
        let pool = Array(sorted.prefix(min(sorted.count, shortlistSize))).shuffled()
        let picks = Array(pool.prefix(Int.random(in: 1...(3 + userClub.scoutingNetworkLevel / 2))))

        var names: [String] = []
        for pick in picks {
            let target = TransferTarget(player: pick.player, sellingClubIndex: pick.clubIndex,
                                        askingPrice: Int(Double(pick.player.value) * Double.random(in: 1.4...1.9)))
            transferMarket.append(target)
            scoutedReports[target.id] = makeScoutReport(for: pick.player)
            names.append(pick.player.name)
        }
        let headline = youthOnly ? "Youth scouting mission" : "World scouting mission"
        let body = "Your scouts turned up \(names.count) player\(names.count == 1 ? "" : "s"): \(names.joined(separator: ", "))."
        addNews(.info, headline, body)
        return "Found \(names.count) new target\(names.count == 1 ? "" : "s") — check your scout reports."
    }

    func averageRating(atPosition position: Position, forClubIndex index: Int) -> Int {
        let group = clubs[index].players.filter { $0.position == position }
        guard !group.isEmpty else { return 60 }
        return group.reduce(0) { $0 + $1.rating } / group.count
    }

    // MARK: - Loans

    /// Loans a player in from a rival for the season (wages only, no fee).
    @discardableResult
    func loanIn(_ target: TransferTarget) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard let sellerIndex = target.sellingClubIndex else { return "Free agents can't be loaned." }
        guard userClub.players.count < 30 else { return "Your squad is full (30 players)." }
        guard let marketIndex = transferMarket.firstIndex(where: { $0.id == target.id }) else {
            return "That player is no longer available."
        }
        guard let playerIndex = clubs[sellerIndex].players.firstIndex(where: { $0.id == target.player.id }) else {
            return "That player is no longer available."
        }
        var player = clubs[sellerIndex].players.remove(at: playerIndex)
        player.onLoanFromClubIndex = sellerIndex
        player.isTransferListed = false
        player.wantsToLeave = false
        clubs[userClubIndex].players.append(player)
        transferMarket.remove(at: marketIndex)
        addNews(.transfer, "Loan agreed", "You loaned \(player.name) from \(clubs[sellerIndex].name) for the season.")
        persist()
        return "Loaned \(player.name) for the season."
    }

    /// The result of approaching a club about taking a loanee: either they
    /// agree, or they pass with a reason.
    enum LoanOutcome {
        case accepted(String)
        case rejected(reason: String)
    }

    /// Rival clubs plausibly willing to take a loanee — weighted toward
    /// clubs genuinely short at his position rather than just anyone with
    /// a spare squad slot, so the shortlist reads like real interest
    /// instead of a random pick. Falls back to any club with room if
    /// nobody's especially short there.
    func loanCandidates(for player: Player) -> [Int] {
        let needy = clubs.indices.filter { index in
            guard index != userClubIndex, clubs[index].players.count < 30 else { return false }
            return clubs[index].players.filter { $0.position == player.position }.count <= 5
        }
        let pool = needy.isEmpty
            ? clubs.indices.filter { $0 != userClubIndex && clubs[$0].players.count < 30 }
            : needy
        return Array(pool.shuffled().prefix(4))
    }

    /// Proposes loaning a squad player out to a specific club. Real loan
    /// logic: they need genuine space at his position and the wage budget
    /// to carry him for the loan, and a requested fee makes them think
    /// twice. Loans move fast in real football, so this is a single
    /// yes/no per approach rather than a haggling negotiation — a rejected
    /// fee can simply be tried again lower.
    @discardableResult
    func proposeLoanOut(_ player: Player, toClubIndex: Int, fee: Int = 0) -> LoanOutcome {
        guard transferWindowOpen else { return .rejected(reason: "The transfer window is closed.") }
        guard !player.isOnLoan else { return .rejected(reason: "You can't loan out a loanee.") }
        guard userClub.players.count > 15 else { return .rejected(reason: "You must keep at least 16 players.") }
        guard let playerIndex = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return .rejected(reason: "That player is not in your squad.")
        }
        guard clubs.indices.contains(toClubIndex), toClubIndex != userClubIndex else {
            return .rejected(reason: "That club isn't a valid destination.")
        }
        let destination = clubs[toClubIndex]
        guard destination.players.count < 30 else {
            return .rejected(reason: "\(destination.name)'s squad is already full.")
        }
        guard destination.wageBill + player.wage <= destination.wageBudget else {
            return .rejected(reason: "\(destination.name) can't fit \(formatMoney(player.wage))/wk into their wage budget.")
        }
        guard destination.transferBudget >= fee else {
            return .rejected(reason: "\(destination.name) won't stretch to a \(formatMoney(fee)) loan fee.")
        }

        let positionCount = destination.players.filter { $0.position == player.position }.count
        let needFactor = max(0, 6 - positionCount)
        var chance = 0.35 + Double(needFactor) * 0.1
        chance -= Double(fee) / Double(max(player.value, 1)) * 0.6
        chance += (Double(destination.prestige) - Double(userClub.prestige)) / 300
        chance = min(0.92, max(0.05, chance))

        guard Double.random(in: 0..<1) < chance else {
            let reason = positionCount > 5
                ? "\(destination.name) already have enough cover at \(player.position.rawValue) and passed."
                : (fee > 0 ? "\(destination.name) weren't willing to pay a fee for the loan." : "\(destination.name) weren't convinced and passed on the move.")
            return .rejected(reason: reason)
        }

        var loanee = clubs[userClubIndex].players.remove(at: playerIndex)
        loanee.onLoanFromClubIndex = userClubIndex
        clubs[toClubIndex].players.append(loanee)
        if fee > 0 {
            clubs[toClubIndex].transferBudget -= fee
            clubs[userClubIndex].transferBudget += fee
        }
        userStarterIDs.remove(player.id)
        validateRoles()
        var message = "\(player.name) joined \(destination.name) on loan for the season."
        if fee > 0 { message += " Loan fee: \(formatMoney(fee))." }
        addNews(.transfer, "Loan out agreed", message, player: loanee, clubName: destination.name)
        logTransferHistory(player.name, action: "Loaned out", otherClub: destination.name, fee: fee > 0 ? fee : nil)
        persist()
        return .accepted(message)
    }

    /// Everyone the user's club currently has out on loan, and where.
    func playersOnLoanFromUser() -> [(player: Player, clubIndex: Int)] {
        clubs.indices.flatMap { clubIndex in
            clubs[clubIndex].players
                .filter { $0.onLoanFromClubIndex == userClubIndex }
                .map { (player: $0, clubIndex: clubIndex) }
        }
    }

    /// Recalls a loanee back to the parent club early, ending the loan.
    @discardableResult
    func recallFromLoan(_ player: Player) -> String {
        guard let hostIndex = clubs.firstIndex(where: { club in
            club.players.contains { $0.id == player.id && $0.onLoanFromClubIndex == userClubIndex }
        }) else {
            return "\(player.name) isn't out on loan from your club."
        }
        guard let playerIndex = clubs[hostIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return "\(player.name) isn't out on loan from your club."
        }
        var recalled = clubs[hostIndex].players.remove(at: playerIndex)
        let formerClub = clubs[hostIndex].name
        recalled.onLoanFromClubIndex = nil
        clubs[userClubIndex].players.append(recalled)
        addNews(.transfer, "Loan recalled", "\(recalled.name) has been recalled from \(formerClub) back to \(userClub.name).")
        persist()
        return "\(recalled.name) recalled from \(formerClub)."
    }

    /// Whether this player can be released by mutual consent — real clubs
    /// don't just give away a happy, effective squad member for nothing,
    /// so this only applies to the unsettled or the ageing.
    func canTerminateContract(_ player: Player) -> Bool {
        player.wantsToLeave || player.age >= 33
    }

    /// Responds to a player's transfer request: either agree to list him
    /// for sale, or try to talk him round. Talking round isn't guaranteed —
    /// it depends on his personality — and failing leaves him just as
    /// unhappy as before, so ignoring a request isn't a free option.
    @discardableResult
    func respondToTransferRequest(_ player: Player, agreeToList: Bool) -> String {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }),
              clubs[userClubIndex].players[index].wantsToLeave else {
            return "\(player.name) hasn't asked to leave."
        }
        if agreeToList {
            clubs[userClubIndex].players[index].isTransferListed = true
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 8)
            addNews(.board, "Transfer request granted",
                    "\(player.name) has been listed for sale after asking to leave.")
            persist()
            return "\(player.name) has been listed for sale."
        }
        let chance = 0.4 + clubs[userClubIndex].players[index].personality.renewalChanceAdjustment
            + Double(clubs[userClubIndex].players[index].traits.loyalty - 50) / 300
        if Double.random(in: 0..<1) < chance {
            clubs[userClubIndex].players[index].wantsToLeave = false
            clubs[userClubIndex].players[index].isTransferListed = false
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 15)
            addNews(.board, "Player talked round",
                    "\(player.name) has agreed to stay and fight for his place.")
            persist()
            return "\(player.name) has agreed to stay, for now."
        } else {
            clubs[userClubIndex].players[index].morale = max(0, clubs[userClubIndex].players[index].morale - 10)
            addNews(.board, "Still unhappy",
                    "\(player.name) wasn't convinced by the talk — he still wants to leave.")
            persist()
            return "\(player.name) wasn't convinced. He still wants out."
        }
    }

    /// Releases a player early, outside the transfer market entirely — no
    /// fee comes in, and the club pays a severance package, but it frees
    /// the wage budget immediately rather than waiting out the contract.
    @discardableResult
    func terminateContract(_ player: Player) -> String {
        guard userClub.players.count > 15 else { return "You must keep at least 16 players." }
        guard canTerminateContract(player) else {
            return "\(player.name) has no interest in leaving — this only works for unsettled or veteran players."
        }
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return "That player is not in your squad."
        }
        let severance = max(50, player.wage * 4)
        guard userClub.transferBudget >= severance else {
            return "The club can't afford the severance package (\(formatMoney(severance)))."
        }
        clubs[userClubIndex].players.remove(at: index)
        clubs[userClubIndex].transferBudget -= severance
        userStarterIDs.remove(player.id)
        validateRoles()
        logLedger("Contract termination", amount: -severance, "\(player.name) released by mutual consent")
        logTransferHistory(player.name, action: "Released", otherClub: nil, fee: nil)
        addNews(.transfer, "Contract terminated",
                "\(player.name) has left \(userClub.name) by mutual consent, with a severance payment of \(formatMoney(severance)).")
        persist()
        return "\(player.name) released by mutual consent."
    }

    /// Returns every loanee to their parent club at season's end.
    func returnLoans() {
        var returning: [Player] = []
        for clubIndex in clubs.indices {
            let (loanees, kept) = clubs[clubIndex].players.reduce(into: ([Player](), [Player]())) { result, player in
                if player.isOnLoan { result.0.append(player) } else { result.1.append(player) }
            }
            clubs[clubIndex].players = kept
            returning.append(contentsOf: loanees)
        }
        for var player in returning {
            let parent = player.onLoanFromClubIndex ?? userClubIndex
            player.onLoanFromClubIndex = nil
            if clubs.indices.contains(parent) { clubs[parent].players.append(player) }
        }
    }

}
