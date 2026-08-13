//
//  GameStore+Newspaper.swift
//  Retro Season Manager
//
//  Dresses up newsworthy stories from addNews(...) as generated newspaper
//  front pages — the presentation layer over NewsItem, and (since these are
//  archived rather than pruned like the inbox) part of the permanent season
//  history record.
//

import Foundation

extension GameStore {

    // MARK: - Newspaper generation

    fileprivate struct NewspaperDraft {
        let outlet: NewspaperOutlet
        let importance: NewspaperImportance
        let headline: String
        let standfirst: String
    }

    fileprivate enum SigningTier { case worldRecord, marquee, routine }

    /// Turns a freshly-created story into a front page, when it's judged
    /// newspaper-worthy — bespoke templates cover the marquee moments
    /// (title wins, transfers, retirements, sackings, giant-killings...)
    /// using the real names already passed to `addNews`; everything else
    /// still gets a properly styled page via a dressed-up generic headline,
    /// unless it's judged too minor to be worth printing at all (routine
    /// admin chatter — transfer windows opening, scouts being assigned).
    func generateNewspaper(category: NewsCategory, title: String, body: String,
                            player: Player?, clubName: String?) -> Newspaper? {
        guard let draft = classifyStory(category: category, title: title, body: body,
                                         player: player, clubName: clubName) else { return nil }
        return Newspaper(date: currentDate, season: season, outlet: draft.outlet,
                          masthead: masthead(for: draft.outlet, clubName: clubName ?? userClub.name),
                          headline: draft.headline, standfirst: draft.standfirst, body: body,
                          category: category, importance: draft.importance,
                          playerName: player?.name, playerPosition: player?.position,
                          playerAge: player?.age, clubName: clubName)
    }

    fileprivate func classifyStory(category: NewsCategory, title: String, body: String,
                                    player: Player?, clubName: String?) -> NewspaperDraft? {
        let draft = bespokeDraft(category: category, title: title, body: body, player: player, clubName: clubName)
            ?? genericDraft(category: category, title: title, body: body)
        // A story that only earns "minor" from the generic classifier is
        // routine housekeeping, not news — no front page gets printed.
        return draft.importance == .minor ? nil : draft
    }

    // MARK: - Marquee stories

    fileprivate func bespokeDraft(category: NewsCategory, title: String, body: String,
                                   player: Player?, clubName: String?) -> NewspaperDraft? {
        if title == "Giant-killing!" {
            let opponent = extract(body, between: "much-fancied ", and: " turns heads") ?? "the league's finest"
            return NewspaperDraft(outlet: .national, importance: .historic,
                                   headline: "GIANT KILLERS STUN \(opponent.uppercased())",
                                   standfirst: body)
        }

        if title == "Club record!" {
            return NewspaperDraft(outlet: .local, importance: .major,
                                   headline: "\(userClub.name.uppercased()) SET NEW CLUB RECORD",
                                   standfirst: body)
        }

        if title == "Promotion!" {
            let topScorer = clubs[userClubIndex].players.filter { $0.goals > 0 }.max { $0.goals < $1.goals }
            let headline: String
            if let topScorer, topScorer.goals >= 10 {
                let epithets = ["LOCAL HERO", topScorer.name.uppercased(), "TOP SCORER \(topScorer.name.uppercased())"]
                let epithet = epithets[abs(Self.stableHash(topScorer.name)) % epithets.count]
                headline = "\(epithet) FIRES \(userClub.shortName.uppercased()) TO PROMOTION"
            } else {
                headline = "\(userClub.name.uppercased()) SEAL PROMOTION"
            }
            return NewspaperDraft(outlet: .national, importance: .historic, headline: headline, standfirst: body)
        }

        if title == "Relegation" {
            return NewspaperDraft(outlet: .national, importance: .major,
                                   headline: "RELEGATION HEARTBREAK FOR \(userClub.name.uppercased())",
                                   standfirst: body)
        }

        if title == "Retirement", let player {
            if player.rating >= 80 {
                return NewspaperDraft(outlet: .magazine, importance: .historic,
                                       headline: "LEGEND ANNOUNCES RETIREMENT",
                                       standfirst: "\(player.name) calls time on a career that will be remembered at \(userClub.name).")
            }
            return NewspaperDraft(outlet: .local, importance: .notable,
                                   headline: "\(player.name.uppercased()) HANGS UP HIS BOOTS",
                                   standfirst: body)
        }

        if title == "Club Legend" || title == "Global Hall of Fame", let player {
            let scope = title == "Global Hall of Fame" ? "GLOBAL HALL OF FAME" : "\((clubName ?? userClub.name).uppercased()) HALL OF FAME"
            return NewspaperDraft(outlet: .magazine, importance: .historic,
                                   headline: "\(player.name.uppercased()) ENTERS THE \(scope)",
                                   standfirst: body)
        }

        if ["Signing complete", "Transfer completed", "Free transfer complete"].contains(title) {
            switch signingTier(player: player, body: body) {
            case .worldRecord:
                return NewspaperDraft(outlet: .national, importance: .historic,
                                       headline: "WORLD RECORD TRANSFER COMPLETED", standfirst: body)
            case .marquee:
                return NewspaperDraft(outlet: .national, importance: .major,
                                       headline: "\((clubName ?? userClub.name).uppercased()) LAND MARQUEE SIGNING",
                                       standfirst: body)
            case .routine:
                return NewspaperDraft(outlet: .local, importance: .notable,
                                       headline: "\((player?.name ?? "NEW ARRIVAL").uppercased()) COMPLETES MOVE",
                                       standfirst: body)
            }
        }

        if title == "Player sold", let player {
            return NewspaperDraft(outlet: .local, importance: player.rating >= 80 ? .major : .notable,
                                   headline: "\(player.name.uppercased()) LEAVES \(userClub.shortName.uppercased())",
                                   standfirst: body)
        }

        if title == "Sacked" {
            return NewspaperDraft(outlet: .national, importance: .major,
                                   headline: "\(userClub.name.uppercased()) PULL THE TRIGGER",
                                   standfirst: body)
        }

        if title == "New job agreed" {
            return NewspaperDraft(outlet: .national, importance: .major,
                                   headline: "NEW MANAGER CONFIRMED", standfirst: body)
        }

        if title == "Clear-the-air meeting" {
            let reassured = body.contains("reassured")
            return NewspaperDraft(outlet: .local, importance: .notable,
                                   headline: reassured ? "BOARD BACKS MANAGER" : "BOARD PATIENCE WEARING THIN",
                                   standfirst: body)
        }

        if title.hasSuffix("winners") {
            let winner = body.components(separatedBy: " lift the ").first ?? (clubName ?? userClub.name)
            let isEuropean = title.contains(Self.euroName) || title.contains(Self.uefaCupName)
            let isWinnerUser = winner == userClub.name
            return NewspaperDraft(outlet: isEuropean ? .european : .national, importance: .historic,
                                   headline: isWinnerUser ? "\(winner.uppercased()) LIFT THE TROPHY" : "\(winner.uppercased()) CROWNED CHAMPIONS",
                                   standfirst: body)
        }

        if ["Team of the Season", "Manager of the Season", "Golden Boot", "Young Player of the Season"].contains(title) {
            return NewspaperDraft(outlet: .magazine, importance: .major,
                                   headline: "\(title.uppercased()): THE FULL STORY", standfirst: body)
        }

        if ["Achievement unlocked", "Milestone reached", "Reputation milestone"].contains(title) {
            return NewspaperDraft(outlet: .magazine, importance: .notable,
                                   headline: title.uppercased(), standfirst: body)
        }

        if title == "Club takeover" {
            return NewspaperDraft(outlet: .national, importance: .major,
                                   headline: "\((clubName ?? "CLUB").uppercased()) TAKEOVER COMPLETED",
                                   standfirst: body)
        }

        if title == "Financial crisis" {
            return NewspaperDraft(outlet: .national, importance: .major,
                                   headline: "FINANCIAL CRISIS ENGULFS \((clubName ?? "CLUB").uppercased())",
                                   standfirst: body)
        }

        if title == "Club bankruptcy" {
            return NewspaperDraft(outlet: .national, importance: .historic,
                                   headline: "\((clubName ?? "CLUB").uppercased()) DECLARED BANKRUPT",
                                   standfirst: body)
        }

        if title == "Wonderkid emerges", let player {
            return NewspaperDraft(outlet: .magazine, importance: .major,
                                   headline: "WONDERKID EMERGES: \(player.name.uppercased())",
                                   standfirst: body)
        }

        if title == "Stadium expansion" {
            return NewspaperDraft(outlet: .local, importance: .notable,
                                   headline: "\((clubName ?? "CLUB").uppercased()) COMPLETE STADIUM EXPANSION",
                                   standfirst: body)
        }

        if title == "Rivalry forming" {
            return NewspaperDraft(outlet: .national, importance: .major,
                                   headline: "NEW RIVALRY BREWING", standfirst: body)
        }

        if category == .result, title.hasPrefix("Derby") {
            let result = title.contains("win") ? "TRIUMPH" : (title.contains("draw") ? "SHARE THE SPOILS" : "FALL SHORT")
            return NewspaperDraft(outlet: .local, importance: .major,
                                   headline: "DERBY DRAMA AS \(userClub.shortName.uppercased()) \(result)",
                                   standfirst: body)
        }

        return nil
    }

    fileprivate func signingTier(player: Player?, body: String) -> SigningTier {
        if let player {
            if player.rating >= 85 { return .worldRecord }
            if player.rating >= 78 { return .marquee }
            return .routine
        }
        if let millions = extractMillions(from: body) {
            if millions >= 40 { return .worldRecord }
            if millions >= 15 { return .marquee }
        }
        return .routine
    }

    // MARK: - Generic fallback

    /// A story with no bespoke template still gets a properly styled page —
    /// outlet and importance come from its category, and the headline is
    /// the existing (already newsy) title, dressed up with a plain,
    /// exclamatory, or "BREAKING"/"OFFICIAL" frame depending on weight.
    fileprivate func genericDraft(category: NewsCategory, title: String, body: String) -> NewspaperDraft {
        let outlet: NewspaperOutlet
        let importance: NewspaperImportance
        switch category {
        case .board:
            outlet = .local; importance = .notable
        case .result:
            outlet = .local; importance = .minor
        case .transfer, .offer:
            outlet = .local; importance = .minor
        case .world:
            let european = title.contains(Self.euroName) || title.contains(Self.uefaCupName) || body.contains(Self.euroName) || body.contains(Self.uefaCupName)
            outlet = european ? .european : .national
            importance = .notable
        case .injury:
            outlet = .local; importance = .minor
        case .info:
            outlet = .local; importance = .minor
        }
        let frames: [String]
        switch importance {
        case .historic, .major: frames = ["BREAKING: %@", "%@!", "OFFICIAL: %@"]
        case .notable:          frames = ["%@", "%@!"]
        case .minor:             frames = ["%@"]
        }
        let frame = frames[abs(Self.stableHash(title)) % frames.count]
        return NewspaperDraft(outlet: outlet, importance: importance,
                               headline: String(format: frame, title.uppercased()), standfirst: body)
    }

    // MARK: - Masthead naming

    /// A local paper is a recurring hometown institution, so its name stays
    /// stable for a given club (a hash of the club name, not randomised) —
    /// national/European/magazine mastheads vary story to story instead,
    /// the way several different outlets plausibly cover the same event.
    fileprivate func masthead(for outlet: NewspaperOutlet, clubName: String) -> String {
        switch outlet {
        case .local:
            let suffixes = ["HERALD", "EVENING STAR", "GAZETTE", "ECHO", "CHRONICLE", "POST"]
            let suffix = suffixes[abs(Self.stableHash(clubName)) % suffixes.count]
            return "THE \(clubName.uppercased()) \(suffix)"
        case .national:
            return ["THE NATIONAL GAME", "DAILY KICK-OFF", "THE SPORTING TIMES", "MATCH REPORT DAILY", "THE FOOTBALL POST"].randomElement()!
        case .european:
            return ["CONTINENTAL FOOTBALL TIMES", "EURO SPORT WEEKLY", "THE EUROPEAN GAME", "CONTINENTAL PRESS"].randomElement()!
        case .magazine:
            return ["MATCHDAY MAGAZINE", "THE SATURDAY REVIEW", "GLOBAL FOOTBALL WEEKLY", "THE TACTICS BOARD"].randomElement()!
        }
    }

    // MARK: - Small text helpers

    fileprivate func extract(_ text: String, between prefix: String, and suffix: String) -> String? {
        guard let prefixRange = text.range(of: prefix),
              let suffixRange = text.range(of: suffix, range: prefixRange.upperBound..<text.endIndex) else { return nil }
        return String(text[prefixRange.upperBound..<suffixRange.lowerBound])
    }

    fileprivate func extractMillions(from body: String) -> Double? {
        guard let range = body.range(of: #"£([0-9]+(\.[0-9]+)?)M"#, options: .regularExpression) else { return nil }
        let digits = body[range].dropFirst().dropLast()
        return Double(digits)
    }

    /// A deterministic (non-randomised) hash, so masthead/headline framing
    /// choices stay identical across app launches for the same story text —
    /// `String.hashValue` is seed-randomised per process and would flicker.
    fileprivate static func stableHash(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
    }
}
