//
//  GameStore+UITestFixture.swift
//  Retro Season Manager
//
//  DEBUG-only deterministic Career fixture for UI tests, launched with the
//  `UITEST_CAREER_NAVIGATION` argument. It builds a fresh, saved career
//  (a brand-new game with its own save ID — real player saves are never
//  read or modified; the argument is only ever set by the UI-test runner)
//  and then adds deterministic state the navigation tests depend on:
//
//  - several long-term injuries, so the Home dashboard's Medical Centre
//    panel and the full Medical Centre sheet have real, lower,
//    scroll-to-reach content (worst first, matching the panel's
//    own ordering),
//  - a very long inbox article plus routine messages, so the Inbox
//    destination and its detail sheet have real scrolling content.
//

import Foundation

#if DEBUG
extension GameStore {
    /// Builds the deterministic Career navigation fixture and returns the
    /// store so `ContentView.init` can seed `experience` in one call.
    @discardableResult
    func prepareCareerNavigationFixtureForDebug() -> GameStore {
        // 1. A deterministic fresh career for a known club.
        let catalogue = Self.catalogueEntries()
        let clubIndex = catalogue.firstIndex { $0.name == "Old Trafford Reds" } ?? 0
        newGame(clubIndex: clubIndex, managerName: "Nav Fixture Manager")

        // 2. Long-term injuries across the squad so the Medical Centre
        //    panel and the full Medical Centre sheet have real, lower,
        //    scroll-to-reach content (worst first, matching the panel's
        //    own ordering).
        let squadSize = clubs[userClubIndex].players.count
        for offset in 0..<min(8, squadSize) {
            clubs[userClubIndex].players[offset].injuryWeeks = 9 - offset   // 9…2 weeks out
            clubs[userClubIndex].players[offset].injuriesThisSeason = 2
        }

        // 3 & 4. Deterministic league state: three rounds played through
        //    the real standings path. The user's sequence is deliberately
        //    W-D-L so the redesigned table can prove its summary, form
        //    guide, recent-results badges and next-fixture split against
        //    useful authoritative data.
        for fixtureIndex in fixtures.indices where fixtures[fixtureIndex].matchday <= 3 {
            let fixture = fixtures[fixtureIndex]
            let involvesUser = fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex
            let homeGoals: Int
            let awayGoals: Int

            if involvesUser {
                let userIsHome = fixture.homeIndex == userClubIndex
                switch fixture.matchday {
                case 1:
                    homeGoals = userIsHome ? 2 : 0
                    awayGoals = userIsHome ? 0 : 2
                case 2:
                    homeGoals = 1
                    awayGoals = 1
                default:
                    homeGoals = userIsHome ? 0 : 1
                    awayGoals = userIsHome ? 1 : 0
                }
            } else {
                homeGoals = (fixture.homeIndex + fixture.matchday) % 3
                awayGoals = (fixture.awayIndex + fixture.matchday + 1) % 2
            }

            fixtures[fixtureIndex].played = true
            fixtures[fixtureIndex].homeGoals = homeGoals
            fixtures[fixtureIndex].awayGoals = awayGoals
            applyResult(clubIndex: fixture.homeIndex, scored: homeGoals, conceded: awayGoals,
                        isHome: true, opponentIndex: fixture.awayIndex)
            applyResult(clubIndex: fixture.awayIndex, scored: awayGoals, conceded: homeGoals,
                        isHome: false, opponentIndex: fixture.homeIndex)
        }
        currentMatchday = 4
        currentDate = date(forMatchday: currentMatchday)

        // 5. The deterministic inbox, seeded AFTER the matchday simulation
        //    so the fixture's items sit newest-first at the top of the
        //    feed (match-generated stories land beneath them). One very
        //    long article (the scroll target), a spread of every supported
        //    category folder, read AND unread items, and a player-context
        //    story — enough to prove the summary counts, every filter, the
        //    unread treatment and the article reader's snapshot card.
        //    Items go through the store's real `addNews` creation path
        //    (unread state, ordering and the 60-item cap all behave as in
        //    normal play); everything the engine itself generated becomes
        //    read history, and exactly the four routine fixture items are
        //    then marked read through the real mechanism — leaving a
        //    deterministic unread mix whatever the engine added this run.
        let longBody = Array(repeating:
            "The chairman has asked for a full review of training ground facilities, scouting coverage and the medical department's turnaround times. Staff have been briefed to expect changes before the next transfer window, and supporters' groups have been invited to comment on the proposals before anything is finalised. ",
            count: 12).joined()
        let profiledPlayer = clubs[userClubIndex].players[10]
        // (read in insertion order so newest lands first)
        let items: [(NewsCategory, String, String, Player?)] = [
            (.board, "Board reviews season objectives",
             "The board is pleased with early progress but expects continued improvement.", nil),
            (.injury, "Medical report filed",
             "The physio room expects a busy week with several players in rehabilitation.", nil),
            (.transfer, "Transfer window opens",
             "The transfer window is now open. Scouts have circulated the first lists of available targets.", nil),
            (.result, "Season opener ends level",
             "The league campaign opened with a hard-fought draw in front of a full house.", nil),
            (.board, "Star signs contract extension",
             "\(profiledPlayer.name) has committed his future to the club, signing a deal that keeps him here through the rest of the season and beyond.",
             profiledPlayer),
            (.world, "Title race tightening across Europe",
             "Rival clubs dropped points this weekend, keeping the table congested.", nil),
            (.info, "DETERMINISTIC LONG ARTICLE", longBody, nil),
        ]
        for existing in news { markNewsRead(existing) }
        for (category, title, body, player) in items {
            addNews(category, title, body, player: player, clubName: userClub.name)
        }
        let readTitles: Set<String> = ["Season opener ends level", "Transfer window opens",
                                       "Medical report filed", "Board reviews season objectives"]
        for item in news where readTitles.contains(item.title) {
            markNewsRead(item)
        }

        // 5. Persist exactly once so the save on disk matches memory.
        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with exactly what
    /// the redesigned Settings screen presents: transfer history through
    /// the real logging path, at least one printed front page, one
    /// achievement through the real unlock path, a previous season in the
    /// history table, and one seeded preference. Autosave is deliberately
    /// left at its default (on) so save-related UI tests toggle it
    /// themselves and assert against a known default.
    @discardableResult
    func prepareCareerSettingsFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 1. Transfer history through the authoritative logging API —
        //    newest first, exactly as the live game records moves.
        logTransferHistory("Danny Draper", action: "Signed", otherClub: "Riverton FC", fee: 850)
        logTransferHistory("Marcus Bidwell", action: "Sold", otherClub: "Old Athletic", fee: 1200)
        logTransferHistory("Tom Tinker", action: "Released", otherClub: nil, fee: nil)

        // 2. One printed front page through the real newspaper path
        //    (addNews classifies + prints + links the story).
        let archiveStar = clubs[userClubIndex].players[3]
        addNews(.result, "DETERMINISTIC ARCHIVE STORY",
                "A dominant home performance in front of a packed ground, with \(archiveStar.name) irresistible on the wing.",
                player: archiveStar, clubName: userClub.name)
        // The headline story stays unread only if the seed allows it —
        // read it here so the Settings fixture never fights the Inbox
        // fixture's unread accounting when both launch in one suite run.
        for item in news where item.title == "DETERMINISTIC ARCHIVE STORY" {
            markNewsRead(item)
        }

        // 3. One achievement through the real unlock path (it also emits
        //    its own board story). The celebration overlay is a full-screen
        //    cover in normal play — clear it so the fixture boots straight
        //    into the shell with no modal in the way.
        unlock(.wins50)
        pendingAchievementCelebration = nil

        // 4. A completed previous season through the real rollover record
        //    shape, so Season History and the records card have content.
        history.append(SeasonRecord(
            season: season - 1, label: seasonLabel,
            userClub: userClub.name, userDivision: divisionName(userDivisionTier), userPosition: 4,
            champion: "Riverton FC", cupWinner: "Old Athletic", euroWinner: "Continental Kings",
            communityShieldWinner: "—"))

        // 5. One seeded preference (the UI tests assert the others from
        //    their defaults and toggle freely).
        autoPickAssist = true

        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with a predictable
    /// mix of complete, in-progress and unscouted transfer targets. The
    /// product scouting APIs still own every state; this only removes
    /// randomness from the UI test's starting point.
    @discardableResult
    func prepareCareerScoutFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        let targets = transferMarket.sorted {
            if $0.player.rating == $1.player.rating { return $0.player.name < $1.player.name }
            return $0.player.rating > $1.player.rating
        }
        guard !targets.isEmpty else { return self }

        scoutedReports = [:]
        scoutingDue = [:]
        shortlistedPlayerIDs = []

        let reported = targets[0]
        scoutedReports[reported.id] = ScoutReport(
            playerID: reported.player.id,
            playerName: reported.player.name,
            potential: min(95, reported.player.rating + 6),
            verdict: "A first-team player with room to improve.",
            note: "Deterministic Career Scout fixture report.",
            valueRangeLow: max(1, Int(Double(reported.player.value) * 0.85)),
            valueRangeHigh: max(2, Int(Double(reported.player.value) * 1.15)),
            confidence: 79
        )
        shortlistedPlayerIDs.insert(reported.player.id)

        if targets.count > 1 {
            scoutingDue[targets[1].id] = Self.calendar.date(byAdding: .day, value: 2, to: currentDate)
        }

        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with a deterministic
    /// Transfer Centre state: a fully-scouted shortlisted target, an
    /// in-progress scouting assignment, an affordable target, an unaffordable
    /// one (budget clipped far below its asking price), a free agent and an
    /// incoming offer for a squad player. Every state goes through the real
    /// transfer/scouting data structures — this only seeds them
    /// deterministically; no second transfer implementation exists.
    @discardableResult
    func prepareCareerTransfersFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        scoutedReports = [:]
        scoutingDue = [:]
        shortlistedPlayerIDs = []
        pendingOffers = []

        let targets = transferMarket.sorted {
            if $0.player.rating == $1.player.rating { return $0.player.name < $1.player.name }
            return $0.player.rating > $1.player.rating
        }
        guard targets.count >= 2 else { return self }

        // 2. An in-progress scouting assignment (report due in two days).
        if targets.count > 1 {
            scoutingDue[targets[1].id] = Self.calendar.date(byAdding: .day, value: 2, to: currentDate)
        }

        // 3. An unaffordable target: clip the budget far below its asking
        //    price so the OVER BUDGET state is guaranteed. Any club-listed
        //    target beyond the first two works; fall back to raising its
        //    asking price only if the world offers nothing expensive enough.
        if let expensive = targets.dropFirst(2).first(where: { $0.sellingClubIndex != nil && $0.askingPrice > userClub.transferBudget }) {
            unaffordableTargetIDForUITests = expensive.id
        } else if let listed = targets.first(where: { $0.sellingClubIndex != nil && $0.id != targets[0].id && $0.id != targets[1].id }) {
            transferMarket = transferMarket.map { target in
                target.id == listed.id
                    ? TransferTarget(player: target.player, sellingClubIndex: target.sellingClubIndex,
                                     askingPrice: userClub.transferBudget + 5_000)
                    : target
            }
            unaffordableTargetIDForUITests = listed.id
        }

        // 4. An incoming offer for a squad player (the seller-side flow).
        if let candidate = clubs[userClubIndex].players
            .filter({ !userStarterIDs.contains($0.id) && $0.position != .goalkeeper })
            .sorted(by: { $0.rating > $1.rating }).first,
            clubs.indices.count > 1 {
            let buyerIndex = clubs.indices.first { $0 != userClubIndex } ?? 0
            // Deterministic buyer with real funds for the offer.
            clubs[buyerIndex].transferBudget += candidate.value * 3
            let expiry = Self.calendar.date(byAdding: .day, value: 6, to: currentDate) ?? currentDate
            pendingOffers.append(TransferOffer(playerID: candidate.id, playerName: candidate.name,
                                               fromClubIndex: buyerIndex, amount: max(candidate.value, 100),
                                               expiryDate: expiry))
        }

        // 5. Give one free agent a deterministic, searchable name so the UI
        //    test can find him without scrolling a 40-card list (free
        //    agents sort low under the OVR sort). In-memory DEBUG rename
        //    only — no save-format impact.
        if let firstFree = targets.first(where: { $0.sellingClubIndex == nil }) {
            transferMarket = transferMarket.map { target in
                target.id == firstFree.id
                    ? TransferTarget(player: Player(id: target.player.id, name: "Bjorn Freehold",
                                                    position: target.player.position,
                                                    detailedPosition: target.player.detailedPosition,
                                                    secondaryPositions: target.player.secondaryPositions,
                                                    age: target.player.age, rating: target.player.rating),
                                     sellingClubIndex: nil, askingPrice: target.askingPrice)
                    : target
            }
        }

        // 6. A deterministic NEGOTIATION target, found by name search in the
        //    UI test: the top-rated CLUB-LISTED target, renamed, whose
        //    seller is pinned to the `.flexible` stance and whose asking
        //    price is pinned to a tenth of the transfer budget. With a
        //    flexible seller the accept threshold is 0.8 × asking price and
        //    the bid sheet's OPENING offer is already 0.85 × asking — so
        //    the very first MAKE OFFER tap is deterministically ACCEPTED
        //    and creates a pending deal. `proposeBid` itself contains no
        //    randomness, but the generated asking price is random, so
        //    without the price pin the 0.85 × asking opening offer can
        //    exceed the budget and bounce off the budget guard ("Not
        //    enough transfer budget") before the stance is ever consulted.
        //    Pinning the price to budget/10 keeps the offer affordable at
        //    every roll.
        //    NOTE: TransferTarget identity is now DERIVED from the player
        //    id (stableID(for:)), so rebuilding a target in place keeps its
        //    identity — scout reports, in-progress assignments and
        //    shortlist entries all survive this mutation.
        var negotiationPlayerID: UUID?
        if let negotiable = targets.first(where: { $0.sellingClubIndex != nil }),
           let sellerIndex = negotiable.sellingClubIndex,
           clubNegotiationStances.indices.contains(sellerIndex) {
            clubNegotiationStances[sellerIndex] = .flexible
            negotiationPlayerID = negotiable.player.id
        }
        if let negotiationPlayerID {
            transferMarket = transferMarket.map { target in
                target.player.id == negotiationPlayerID
                    ? TransferTarget(player: Player(id: target.player.id, name: "Marcus Bidwell",
                                                    position: target.player.position,
                                                    detailedPosition: target.player.detailedPosition,
                                                    secondaryPositions: target.player.secondaryPositions,
                                                    age: target.player.age, rating: target.player.rating),
                                     sellingClubIndex: target.sellingClubIndex,
                                     askingPrice: max(1_000, userClub.transferBudget / 10))
                    : target
            }
        }

        // 1 & 5. The fully-scouted shortlisted target — seeded here for this
        //    session AND re-asserted on every launch below, because the
        //    persisted IDs cannot survive a relaunch (see the doc comment).
        ensureTransfersFixtureStateForDebug()

        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with exactly what
    /// the contract/confirmation sheet flows need, all through the real
    /// store paths:
    ///
    /// - "Danny Draper": a high-morale 31-year-old striker whose wage
    ///   demand is far below the wage-budget headroom — a renewal offer at
    ///   his demand is deterministically ACCEPTED (the acceptance chance
    ///   formula is comfortably above the 0.97 clamp, so the roll cannot
    ///   fail).
    /// - "Sammy Stalwart": an unsettled 34-year-old backup — satisfies
    ///   `canTerminateContract` (wantsToLeave) so the release confirmation
    ///   is reachable, and is 15+ slots above the minimum-squad guard.
    /// - A pending deal for "Ivan Ongo" — reachable through the real
    ///   `proposeBid` path with a flexible seller, so withdrawal has real
    ///   state to act on.
    /// - Budget headroom everywhere so insufficient-funds validation is
    ///   exercised in unit tests by *removing* headroom, not by assuming it.
    @discardableResult
    func prepareCareerSheetsFixtureForDebug(forceRenewalBudgetDecline: Bool = false) -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 1. Danny Draper — a high-probability renewal. Age 31 avoids
        //    both age penalties; morale 95 and a wage at/above demand
        //    push acceptance to the 0.97 cap. The separate budget-guard
        //    fixture below forces a deterministic decline when needed.
        let striker = clubs[userClubIndex].players.first(where: { $0.position == .forward })
            ?? clubs[userClubIndex].players[0]
        let strikerIndex = clubs[userClubIndex].players.firstIndex { $0.id == striker.id }!
        var draper = clubs[userClubIndex].players[strikerIndex]
        draper = Player(id: draper.id, name: "Danny Draper", position: draper.position,
                        detailedPosition: draper.detailedPosition, secondaryPositions: draper.secondaryPositions,
                        age: 31, rating: 78)
        draper.morale = 95
        draper.contractYears = 1
        draper.wage = 900
        draper.releaseClause = nil
        draper.value = max(draper.value, 1_000)
        clubs[userClubIndex].players[strikerIndex] = draper
        // A modest wage budget gives the renewal real headroom.
        clubs[userClubIndex].wageBudget = max(userClub.wageBill + 3_000, userClub.wageBudget)

        // 2. Sammy Stalwart — the release candidate (unsettled veteran).
        let veteran = clubs[userClubIndex].players.first(where: { $0.position != .forward && $0.position != .goalkeeper && $0.onLoanFromClubIndex == nil })
            ?? clubs[userClubIndex].players.last!
        let veteranIndex = clubs[userClubIndex].players.firstIndex { $0.id == veteran.id }!
        var stalwart = clubs[userClubIndex].players[veteranIndex]
        stalwart = Player(id: stalwart.id, name: "Sammy Stalwart", position: stalwart.position,
                          detailedPosition: stalwart.detailedPosition, secondaryPositions: stalwart.secondaryPositions,
                          age: 34, rating: stalwart.rating)
        stalwart.wantsToLeave = true
        stalwart.wage = 400
        stalwart.onLoanFromClubIndex = nil
        clubs[userClubIndex].players[veteranIndex] = stalwart
        clubs[userClubIndex].transferBudget = max(userClub.transferBudget, max(50, 400 * 4) + 1_000)

        // 3. A pending deal for "Ivan Ongo" through the REAL bid path —
        //    flexible seller, cheap target, so the first bid is accepted
        //    and the deal is pending with no personal terms agreed.
        let targets = transferMarket.sorted {
            if $0.player.rating == $1.player.rating { return $0.player.name < $1.player.name }
            return $0.player.rating > $1.player.rating
        }
        if let negotiable = targets.first(where: { $0.sellingClubIndex != nil && $0.player.position != .goalkeeper }),
           let sellerIndex = negotiable.sellingClubIndex,
           clubNegotiationStances.indices.contains(sellerIndex) {
            clubNegotiationStances[sellerIndex] = .flexible
            let asking = max(1_000, userClub.transferBudget / 10)
            // Rename the underlying club player too, so the pending deal
            // created by the real bid path keeps the deterministic name.
            if let playerIndex = clubs[sellerIndex].players.firstIndex(where: { $0.id == negotiable.player.id }) {
                let original = clubs[sellerIndex].players[playerIndex]
                let renamed = Player(id: original.id, name: "Ivan Ongo", position: original.position,
                                     detailedPosition: original.detailedPosition,
                                     secondaryPositions: original.secondaryPositions,
                                     age: original.age, rating: original.rating)
                clubs[sellerIndex].players[playerIndex] = renamed
            }
            transferMarket = transferMarket.map { target in
                target.player.id == negotiable.player.id
                    ? TransferTarget(player: Player(id: target.player.id, name: "Ivan Ongo",
                                                    position: target.player.position,
                                                    detailedPosition: target.player.detailedPosition,
                                                    secondaryPositions: target.player.secondaryPositions,
                                                    age: target.player.age, rating: target.player.rating),
                                     sellingClubIndex: target.sellingClubIndex,
                                     askingPrice: asking)
                    : target
            }
            if let live = transferMarket.first(where: { $0.player.name == "Ivan Ongo" }) {
                _ = proposeBid(live, amount: asking)
            }
        }

        if forceRenewalBudgetDecline {
            // A separate UI-test launch proves the declined banner's
            // accessibility contract through the real budget guard.
            clubs[userClubIndex].wageBudget = 0
        }
        persist()
        return self
    }

    /// Idempotent re-assertion of the fixture's shortlist + scout-report
    /// state, kept as a safety net for the UI tests. With stable target
    /// identity and a persisted market this state now survives relaunches
    /// on its own — the re-assertion is a no-op when the save already
    /// carries it (the same player id resolves to the same stable target
    /// id, and the report is overwritten with identical values).
    @discardableResult
    func ensureTransfersFixtureStateForDebug() -> GameStore {
        guard let reported = transferMarket.sorted(by: {
            if $0.player.rating == $1.player.rating { return $0.player.name < $1.player.name }
            return $0.player.rating > $1.player.rating
        }).first(where: { $0.sellingClubIndex != nil }) else { return self }

        shortlistedPlayerIDs.insert(reported.player.id)
        scoutedReports[reported.id] = ScoutReport(
            playerID: reported.player.id,
            playerName: reported.player.name,
            potential: min(95, reported.player.rating + 6),
            verdict: "A first-team player with room to improve.",
            note: "Deterministic Career Transfers fixture report.",
            valueRangeLow: max(1, Int(Double(reported.player.value) * 0.85)),
            valueRangeHigh: max(2, Int(Double(reported.player.value) * 1.15)),
            confidence: 82
        )
        return self
    }

    /// Builds on the shared Career navigation fixture with exactly what
    /// the redesigned Supporter Zone and Season Objectives screens
    /// present, all through the real store data:
    ///
    /// - four REAL pool objectives (rolled by `setSeasonObjectives()`,
    ///   then pinned to a known selection so card identifiers and the
    ///   completion count are stable), one already completed,
    /// - deterministic fan confidence/trend/patience (the values the
    ///   summary band and confidence bars render),
    /// - three banked previous-season attendance averages (the same
    ///   shape the season rollover banks),
    /// - four fan reactions through the REAL `postSocialReaction` path
    ///   (one per sentiment family, so every accent colour renders).
    ///
    /// Season-ticket holders and ground capacity are left at the values
    /// `newGame()` already derived — the screens must show those as-is.
    @discardableResult
    func prepareCareerSupporterFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 1. Roll the real objectives, then pin the deterministic four.
        //    The pool entries are keyed by their stable ids; titles and
        //    descriptions interpolate the rival name exactly as the
        //    store's own pool builder does.
        setSeasonObjectives()
        let rivalName = rivalClubIndex.map { clubs[$0].name } ?? "your rivals"
        seasonObjectives = [
            SeasonObjective(id: "beat-rival", title: "Settle the Score",
                            description: "Beat \(rivalName) this season.", kind: .beatRival),
            SeasonObjective(id: "clean-sheet-wall", title: "Clean Sheet Wall",
                            description: "Keep 8 clean sheets this season.", kind: .cleanSheetWall(8)),
            SeasonObjective(id: "sign-young-player", title: "Ones to Watch",
                            description: "Sign a player aged 21 or younger.", kind: .signYoungPlayer(maxAge: 21)),
            SeasonObjective(id: "improve-fan-confidence", title: "Winning Them Over",
                            description: "End the season with higher fan confidence than you started with.",
                            kind: .improveFanConfidence),
        ]
        completedSeasonObjectiveIDs = ["sign-young-player"]
        fanConfidenceAtSeasonStart = fanConfidence

        // 2. Deterministic fan mood for the summary band and bars.
        fanConfidence = 71
        fanConfidenceTrend = 4
        fanPatience = 55

        // 3. Two previous seasons of banked attendance averages — the
        //    same shape the season rollover appends (see SeasonObjectives
        //    extension). Direct-seeded like the settings fixture's
        //    SeasonRecord.
        attendanceHistory = [22_400, 21_650]

        // 4. Fan reactions through the REAL pipeline (handle + date come
        //    from it; only the text is pinned).
        socialFeed = []
        postSocialReaction(.hype, "Three points and a clean sheet — this is what we came for!")
        postSocialReaction(.pride, "The academy kid looked a player tonight. More of that please.")
        postSocialReaction(.banter, "I've seen better touches in a chip shop, but I'll take the win.")
        postSocialReaction(.concern, "We need another body in midfield before the window shuts.")

        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with a deterministic
    /// facilities starting point: a mid-level spread across the eight
    /// facilities, one maxed facility, and a transfer budget that affords
    /// exactly the museum and training-ground next steps — so the UI tests
    /// can exercise the affordable, insufficient-budget and max-level card
    /// states without touching any upgrade maths. Levels and budget are
    /// seeded directly onto the same club fields `investInFacility` itself
    /// mutates; costs and effects stay owned by the store APIs.
    @discardableResult
    func prepareCareerFacilitiesFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 1. A mid-level spread: nothing at zero, one facility maxed so
        //    the MAX LEVEL state renders without spending £32M+ of taps.
        clubs[userClubIndex].trainingGroundLevel = 1
        clubs[userClubIndex].youthFacilityLevel = 1
        clubs[userClubIndex].medicalCentreLevel = 2
        clubs[userClubIndex].scoutingNetworkLevel = 1
        clubs[userClubIndex].stadiumExpansionLevel = 5
        clubs[userClubIndex].hospitalityLevel = 1
        clubs[userClubIndex].museumLevel = 1
        clubs[userClubIndex].clubShopLevel = 2

        // 2. Transfer budget £3.0M — at these levels exactly two next
        //    steps are affordable (museum £2.4M, training £2.8M) and the
        //    rest are blocked (scouting £3.4M, youth £3.6M, hospitality
        //    £4.0M, club shop £6.75M, medical £7.2M).
        clubs[userClubIndex].transferBudget = 3_000

        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with a populated
    /// career story for the Manager Office: a career now in season 3 with
    /// two completed previous seasons through the real rollover record
    /// shape (real saves only ever record seasons ≥ 1 — the rollover
    /// appends before incrementing), honours in the exact log format the
    /// story parser reads, a seeded club career record, two storied
    /// achievements through the REAL `unlock` path (they generate their
    /// own timeline beats and autobiography sentences), and two historic
    /// front pages of the same shape the newspaper system archives (the
    /// generator itself is fileprivate to its file and `historic` pages
    /// only occur on title-winning events, so they are seeded directly —
    /// the scrapbook only ever READS this archive).
    @discardableResult
    func prepareCareerOfficeFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 0. The career is now in season 3; re-derive the stored date so
        //    every season-derived value stays coherent after the bump.
        season = 3
        currentMatchday = 4
        currentDate = date(forMatchday: currentMatchday)

        // 1. Two completed previous seasons at this club (the SeasonRecord
        //    shape the season rollover appends).
        let labelOne = officeSeasonLabel(for: 2)
        let labelTwo = officeSeasonLabel(for: 1)
        let division = divisionName(userDivisionTier)
        history.append(SeasonRecord(
            season: 1, label: labelTwo,
            userClub: userClub.name, userDivision: division, userPosition: 8,
            champion: "Riverton FC", cupWinner: "Old Athletic", euroWinner: "Continental Kings",
            communityShieldWinner: "—"))
        history.append(SeasonRecord(
            season: 2, label: labelOne,
            userClub: userClub.name, userDivision: division, userPosition: 2,
            champion: "Riverton FC", cupWinner: userClub.name, euroWinner: "Continental Kings",
            communityShieldWinner: "—"))

        // 2. Honours in the exact `careerHonours` log format the story
        //    parser consumes (emoji + name + "(season label)") — a title
        //    and cup double last season, a cup the season before.
        careerHonours.append("🏆 \(division) title (\(labelOne))")
        careerHonours.append("🏆 \(Self.cupName) (\(labelOne))")
        careerHonours.append("🏆 \(Self.cupName) (\(labelTwo))")
        // An unclassified honour must remain visible on the shelf even
        // when TrophyKind cannot infer a bespoke trophy silhouette.
        careerHonours.append("🏅 Fair Play Award (\(labelOne))")

        // 3. The club's cumulative match record (the CV and win-rate
        //    figures read `careerRecordByClub`).
        careerRecordByClub[userClub.name] = ClubCareerRecord(wins: 46, draws: 12, losses: 12)

        // 4. European qualification last season (the beat the timeline
        //    and autobiography both read).
        firstEuropeQualificationSeason = 2

        // 5. Two storied achievements through the REAL unlock path —
        //    biography-worthy kinds, so they generate their own timeline
        //    beats, scrapbook photos and prose. The celebration overlay is
        //    cleared so the fixture boots straight into the shell.
        unlock(.giantKiller)
        unlock(.youthRevolution)
        pendingAchievementCelebration = nil

        // 6. Historic front pages (same shape the newspaper system
        //    archives; scrapbook FRONT PAGES filters `importance == .historic`).
        let clubName = userClub.name
        newspapers = [
            Newspaper(
                date: date(forMatchday: 30), season: 2,
                outlet: .national, masthead: "THE NATIONAL FOOTBALL POST",
                headline: "\(clubName.uppercased()) CROWNED CHAMPIONS",
                standfirst: "A title race decided on the final afternoon — and the underdogs held their nerve.",
                body: """
                Nobody gave them a chance in August. By May, the \(division) trophy was coming home.

                A season built on relentless pressure, an unbreakable home record and a squad that
                refused to read the script. When the final whistle went, the pitch disappeared under
                a sea of supporters who had waited a generation for this afternoon.

                The manager called it a triumph of organisation and belief. The dressing room called
                it a promise kept. History will simply call them champions.
                """,
                category: .result, importance: .historic, clubName: clubName),
            Newspaper(
                date: date(forMatchday: 30), season: 1,
                outlet: .magazine, masthead: "THE MANAGER'S GAME",
                headline: "THE GIANT KILLERS OF \(labelTwo)",
                standfirst: "How a small club kept felling the game's biggest names — and what it taught football about fear.",
                body: """
                Cup weekends belong to the underdogs, and no club owned them quite like \(clubName).

                Round after round, the drawn giants arrived as favourites and left as punchlines.
                The tactics were unfashionable and absolutely immovable: a low block, a sprinting
                counter-attack, and a belief that grew with every scalp.

                By the time the run ended, the club had something money cannot buy — a reputation.
                """,
                category: .result, importance: .historic, clubName: clubName),
        ]

        persist()
        return self
    }

    /// The season label for an arbitrary season number (the same formula
    /// as `seasonLabel`, parameterised — fixture-local helper).
    private func officeSeasonLabel(for seasonNumber: Int) -> String {
        let start = (startYear - 1) + seasonNumber
        return "\(start)/\(String(format: "%02d", (start + 1) % 100))"
    }
}
#endif
