//
//  GameStore+SupporterSystem.swift
//  Retro Season Manager
//
//  The supporter system: fan happiness, attendance/atmosphere framing,
//  season ticket holders, expectations, and the events that move fan
//  sentiment — big wins, poor transfers, selling a fan favourite,
//  promotion, and fans' own influence back on the board.
//

import Foundation

extension GameStore {

    private static let fanHandles = [
        "@ClubTillIDie92", "@TerraceTalk", "@YellowCardYaz", "@BoxToBoxBex",
        "@TheKopEnd_", "@MidweekMuppet", "@FullTimeFrank", "@StatsAndSeats",
        "@AwayDayAndy", "@NorthStandNoise", "@GroundhogDayFan", "@OldSchoolTerrace",
    ]

    /// Appends a generated fan reaction to the social feed.
    func postSocialReaction(_ sentiment: SocialSentiment, _ text: String) {
        let likeRange = sentiment == .outrage || sentiment == .hype ? 40...900 : 5...400
        let post = SocialPost(handle: Self.fanHandles.randomElement()!, text: text, date: currentDate,
                              likeCount: Int.random(in: likeRange), sentiment: sentiment)
        socialFeed.insert(post, at: 0)
        if socialFeed.count > Self.socialFeedCap {
            socialFeed.removeLast(socialFeed.count - Self.socialFeedCap)
        }
    }

    // MARK: - Fan favourites

    /// Whether the fanbase would consider this player one of their own —
    /// a genuine standout, a long server, or the captain. Computed from
    /// signals already tracked elsewhere rather than a new stored flag.
    func isFanFavourite(_ player: Player) -> Bool {
        if player.rating >= 78 { return true }
        if player.id == captainID { return true }
        if let joined = clubTenureStart[player.id], season - joined >= 3 { return true }
        return false
    }

    // MARK: - Expectations & atmosphere

    /// What the fans expect this season — always a notch more ambitious
    /// than the board's own official objective; fans want more than
    /// "avoid relegation," whatever the board is prepared to say publicly.
    func fanExpectation() -> String {
        // A Community Club's fans stay content regardless of table
        // position — their identity, not a function of current form.
        if clubIdentity(forClubIndex: userClubIndex) == .communityClub {
            return "Just give it everything and enjoy the ride — no one's expecting miracles."
        }
        let tier = userClub.divisionTier
        let table = clubs.filter { $0.divisionTier == tier }.sorted { $0.prestige > $1.prestige }
        let rank = (table.firstIndex { $0.id == userClub.id } ?? 0) + 1
        // A Historic Giant's fans expect the very top regardless of
        // current rank — a club used to winning, not just currently good.
        let isHistoricGiant = clubIdentity(forClubIndex: userClubIndex) == .historicGiant
        if tier == 0 {
            if isHistoricGiant || rank <= 2 { return "Nothing but the title will do." }
            if rank <= 6 { return "A serious push for Europe." }
            return "Mid-table respectability — and no relegation scare, please."
        } else {
            if isHistoricGiant || rank <= 2 { return "Automatic promotion, no play-off drama." }
            if rank <= 6 { return "At least a play-off push." }
            return "Steady progress — just don't go backwards."
        }
    }

    /// A rough read on how a fixture will feel in the stands — attendance
    /// fill, whether it's a derby, and (for the user's own ground) current
    /// fan mood all feed in.
    func matchAtmosphere(homeIndex: Int, awayIndex: Int) -> String {
        let capacity = max(1, stadiumInfo(forClubIndex: homeIndex).capacity)
        let fill = Double(expectedAttendance(homeIndex: homeIndex, awayIndex: awayIndex, isCup: false)) / Double(capacity)
        let derby = areRivals(clubs[homeIndex].name, clubs[awayIndex].name)
        var score = fill + (derby ? 0.25 : 0)
        if homeIndex == userClubIndex { score += Double(fanConfidence - 50) / 400 }
        switch score {
        case 1.05...:    return "🔥 Electric"
        case 0.9..<1.05: return "📣 Bouncing"
        case 0.7..<0.9:  return "👏 Lively"
        case 0.5..<0.7:  return "😐 Subdued"
        default:         return "🦗 Flat"
        }
    }

    // MARK: - Fan → board feedback

    /// A small, ongoing nudge on the board's mood from how the fans feel —
    /// happy stands buy a manager patience, an unhappy ground erodes it,
    /// on top of whatever the result itself already does. Called from
    /// `updateBoard`, the same natural per-match cadence.
    func fanInfluenceOnBoard() -> Int {
        Int((Double(fanConfidence - 50) * 0.06).rounded())
    }

    // MARK: - Big wins

    /// Beating someone comfortably ought to feel different from scraping
    /// past them — an extra jolt of excitement (and season ticket
    /// interest) on top of the flat per-result delta `updateBoard` applies.
    func boostFanExcitement(margin: Int, topPerformerName: String? = nil) {
        guard margin >= 3 else { return }
        let bonus = min(12, 3 + margin)
        fanConfidence = min(100, fanConfidence + bonus)
        seasonTicketHolders += margin >= 5 ? 15 : 6
        postSocialReaction(.hype, "\(userClub.shortName) just put \(margin) past them. \(["INCREDIBLE.", "Where has this been all season?!", "Get in there!!", "That's an absolute statement."].randomElement()!)")
        if let topPerformerName, !topPerformerName.isEmpty, Double.random(in: 0..<1) < 0.2 {
            postSocialReaction(.pride, ChantBook.goalChant(playerName: topPerformerName))
        } else if Double.random(in: 0..<1) < 0.5 {
            postSocialReaction(.pride, ChantBook.winChant(clubShortName: userClub.shortName))
        }
    }

    // MARK: - Poor transfers

    /// Fans notice when the club pays well over the odds — the fee vs.
    /// the player's rating-based value is the same signal a real fanbase
    /// would grumble about on the way out of the ground.
    func reactToUserSigning(_ player: Player, fee: Int) {
        guard fee > 0, player.value > 0 else { return }
        let ratio = Double(fee) / Double(player.value)
        // A Financial Powerhouse's fans expect big spending and aren't
        // fazed by it; a Crisis Club/Selling Club's fans are anxious
        // about financial overreach and grumble far sooner.
        let threshold: Double
        switch clubIdentity(forClubIndex: userClubIndex) {
        case .financialPowerhouse: threshold = 1.6
        case .crisisClub, .sellingClub: threshold = 1.15
        default: threshold = 1.35
        }
        guard ratio > threshold else { return }
        let dip = min(10, Int((ratio - threshold) * 12))
        guard dip > 0 else { return }
        fanConfidence = max(0, fanConfidence - dip)
        postSocialReaction(.concern, [
            "\(formatMoney(fee)) for \(player.name)?? Someone check the board's calculator.",
            "We've been done here. \(formatMoney(fee)) is miles over the odds for \(player.name).",
            "Hope \(player.name) is worth it, because that fee was NOT value for money.",
        ].randomElement()!)
    }

    // MARK: - Selling a fan favourite

    /// Cashing in on someone the stands actually love — a real hit to fan
    /// confidence (scaled by how loved they are), a small knock to board
    /// confidence too (the fans' own influence, not the result itself),
    /// and a chant of protest.
    func reactToSellingFanFavourite(_ player: Player) {
        guard isFanFavourite(player) else { return }
        soldFanFavouriteThisSeason = true
        let dip = min(20, 8 + max(0, player.rating - 70))
        fanConfidence = max(0, fanConfidence - dip)
        boardConfidence = max(0, boardConfidence - dip / 3)
        addNews(.world, "Fan backlash",
                "Supporters are furious at the sale of \(player.name) — \"\(ChantBook.legendSaleChant())\" rang around the ground at the next home game.",
                player: player, clubName: userClub.name)
        postSocialReaction(.outrage, [
            "Selling \(player.name)?! Absolutely unforgivable.",
            "\(player.name) gave us everything and this is how the club repays him.",
            "I'm done. Selling \(player.name) is the final straw.",
        ].randomElement()!)
    }

    // MARK: - Promotion

    /// The single biggest fan-happiness event in the game — huge, mostly
    /// permanent gains in confidence and season ticket interest, plus a
    /// burst of celebratory reactions.
    func celebratePromotion() {
        fanConfidence = min(100, fanConfidence + 25)
        seasonTicketHolders += Int(Double(stadiumInfo(forClubIndex: userClubIndex).capacity) * 0.08)
        for _ in 0..<Int.random(in: 2...3) {
            postSocialReaction(.hype, [
                "WE ARE GOING UP!!! \(userClub.shortName) 'til I die!!",
                "Never doubted it. \(userClub.shortName) — promotion heroes.",
                ChantBook.promotionChant(clubShortName: userClub.shortName),
                "Can't stop crying. What a season to be a \(userClub.shortName) fan.",
            ].randomElement()!)
        }
    }
}
