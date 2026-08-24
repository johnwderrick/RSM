//
//  GameStore+FanEngagement.swift
//  Retro Season Manager
//
//  Item 9 of the improvement directive: fan polls, fan campaigns, a
//  season-end read on tactical style, and a youth-debut moment — all
//  routed through the same addNews(...)/postSocialReaction(...) pipeline
//  `GameStore+SupporterSystem.swift` already established, not a parallel
//  reaction system.
//

import Foundation

extension GameStore {

    // MARK: - Fan polls

    /// One of three fan-poll types, picked at random each month — a
    /// result announcement like every other news-driven story in the
    /// game, not an interactive vote. Covers three directive items at
    /// once: "Favourite players" (via the player-of-the-season poll),
    /// "Most disliked rivals" (via the existing `rivalClubIndex`), and
    /// "Fan polls" itself.
    func checkFanPoll() {
        switch Int.random(in: 0..<3) {
        case 0:
            guard let best = userClub.players.filter({ $0.apps >= 5 })
                .max(by: { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }) else { return }
            addNews(.info, "Fan poll",
                    "Fans have voted \(best.name) their Player of the Season so far.",
                    player: best, clubName: userClub.name)
        case 1:
            guard let rivalIndex = rivalClubIndex else { return }
            addNews(.info, "Fan poll",
                    "In this month's fan poll, \(clubs[rivalIndex].name) were voted the fanbase's most disliked rivals.")
        default:
            guard let signing = transferHistory.last(where: { $0.action.hasPrefix("Signed") }) else { return }
            addNews(.info, "Fan poll", "Fans named \(signing.playerName) their favourite signing of the window.")
        }
    }

    // MARK: - Fan campaigns

    /// Fires once a season, when `fanPatience` (a deliberately slow
    /// meter, see `GameStore.swift`) has genuinely worn thin — the
    /// previously-invisible `fanInfluenceOnBoard()` pressure finally gets
    /// a real, visible moment, and the long-dead `ChantBook.relegationFearChant`
    /// finally gets a real event to fire from.
    func checkFanCampaign() {
        guard fanPatience < 30, !fanCampaignFiredThisSeason else { return }
        fanCampaignFiredThisSeason = true
        let relegationThreatened = userPosition > Self.divisionSize - 3
        let body = relegationThreatened
            ? "\"\(ChantBook.relegationFearChant(clubShortName: userClub.shortName))\" — fans are growing anxious as the drop zone looms."
            : "Supporters are organising to make their voice heard — patience with the board is wearing thin."
        addNews(.board, "Fan campaign", body)
        postSocialReaction(.concern, "Time to back the manager. Enough is enough. #\(userClub.shortName)")
    }

    // MARK: - Style

    /// A season-end read on the manager's chosen approach — the
    /// directive's "style" reaction item, kept to one bounded end-of-season
    /// check rather than new per-match tracking. Only fires on a good
    /// season — style doesn't buy goodwill on its own if results are poor.
    func checkSeasonStyleReaction() {
        guard userPosition <= Self.divisionSize / 2 else { return }
        switch preferredMentality {
        case .attacking:
            fanConfidence = min(100, fanConfidence + 5)
            postSocialReaction(.hype, "Say what you want, but watching this team go forward every week has been an absolute joy.")
        case .defensive:
            fanConfidence = min(100, fanConfidence + 2)
            postSocialReaction(.pride, "Not always pretty, but efficient — and the results speak for themselves.")
        case .balanced:
            break
        }
    }

    // MARK: - Youth

    /// Fires the first time an academy-raised teenager makes their senior
    /// starting debut — distinct from item 6's 50-appearance breakthrough
    /// milestone, this is the very first "the fans loved seeing him get a
    /// chance" moment. Called from `beginUserMatch()`.
    func checkYouthBlooding() {
        for player in userStartingXI() where player.isAcademyProduct && player.age <= 20 && !bloodedYouthIDs.contains(player.id) {
            bloodedYouthIDs.insert(player.id)
            fanConfidence = min(100, fanConfidence + 4)
            fanPatience = min(100, fanPatience + 6)
            addNews(.board, "Academy debut",
                    "\(player.name) (\(player.age)) makes his first senior start for \(userClub.name) today — the fans have been waiting for this.",
                    player: player, clubName: userClub.name)
            postSocialReaction(.pride, "One of our own starting today. \(player.name), give it everything.")
        }
    }

    // MARK: - Season ticket attrition

    /// Implements what `seasonTicketHolders`'s own doc comment already
    /// claimed ("shrinks in bad times") but no code ever actually did —
    /// a sustained low-patience season costs the club some of its loyal core.
    func applySeasonTicketAttrition() {
        guard fanPatience < 30 else { return }
        seasonTicketHolders = max(0, Int(Double(seasonTicketHolders) * 0.92))
    }
}
