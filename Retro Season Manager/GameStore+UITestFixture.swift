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

        // 4b. Bring the calendar forward through the real day loop instead
        //     of teleporting to the matchday-4 date: the League Trophy's
        //     first round falls between matchdays 3 and 4, and teleporting
        //     stranded the user's live tie in the past — the round
        //     processors only fire when the user has no tie left, so the
        //     stale tie leaked into `nextUserMatchDate` and the dashboard
        //     counted down to a negative "Next match in -12 days". Walking
        //     like a real CONTINUE tap resolves any cup day in the window
        //     abstractly (the store's own force-resolve path, which plays
        //     the whole round and reports the user's result), so every
        //     competition stays coherent and the next match is always in
        //     the future. The league results above are untouched — the walk
        //     never crosses a league day because `advanceDay` stops there.
        var safety = 0
        while currentDate < date(forMatchday: currentMatchday) && !isSeasonOver && safety < 60 {
            if isUserMatchToday {
                resolveTodaysUserMatchAbstractly()
            } else {
                advanceDay()
            }
            safety += 1
        }

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
    }    /// Builds a fresh, saved career in the fully hand-authored 2020 era
    /// with exactly what the redesigned Squad Depth sheet presents,
    /// deterministically. With everyone available, that squad's exact cover
    /// counts leave Left-Back (Patrice Almada alone) as the only role with
    /// fewer than two fits, so the fixture:
    ///
    /// - injures Rafael Almada and Owen Radcliffe through the real
    ///   availability flag, making Right-Back's available fit count exactly
    ///   one (the amber "1 fit" row), and Patrice Almada, making Left-Back
    ///   available-fit count exactly zero (the red "none fit" row),
    /// - replaces the market with exactly two affordable left-back targets
    ///   — one free agent, one listed at a deliberately affordable fee —
    ///   so the FREE/fee labels and the suggestion card are stable across
    ///   launches.
    ///
    /// It also heals the engine's random seed injuries (only the scripted
    /// ones remain) and restores budget/wage headroom that the club's
    /// baked-in 2005-debt ownership change would otherwise zero at the
    /// 2020 start year.        /// With `fullCover` the fixture instead closes the two thin roles
    /// (Left-Back via a Kacper Duda deputy, Left Midfield via an Antonio
    /// Valera deputy) so every role is covered: the sheet shows its
    /// all-covered state and `suggestedTransferTargets` returns nothing.
    /// The navigation fixture's league/inbox extras are deliberately not
    /// needed here. Real saves are never read or modified; the arguments
    /// are only ever set by the UI-test runner.
    @discardableResult
    func prepareCareerDepthFixtureForDebug(fullCover: Bool = false) -> GameStore {
        // A fresh, saved career for a known club in the hand-authored 2020
        // era (cover counts below are exact for that squad book).
        let catalogue = Self.catalogueEntries()
        let clubIndex = catalogue.firstIndex { $0.name == "Old Trafford Reds" } ?? 0
        newGame(clubIndex: clubIndex, startYear: 2020, managerName: "Depth Fixture Manager")

        // Determinism: `newGame` seeds 0–2 random injuries per club, which
        // could independently strip the scripted Right-Back cover or add
        // accidental cover elsewhere. The depth math below is only exact
        // when the fixture's own injuries are the sole availability noise,
        // so heal the user's squad first. (Other clubs' injuries are
        // irrelevant — `squadNeeds` reads only the user's club.)
        for index in clubs[userClubIndex].players.indices {
            clubs[userClubIndex].players[index].injuryWeeks = 0
            clubs[userClubIndex].players[index].suspensionMatches = 0
        }

        // Deterministic headroom: a 2020 start bakes the Harrow family's
        // 2005 leveraged buyout (see `OwnershipChanges`) into the club's
        // opening finances, which zeroes Old Trafford Reds' budgets —
        // leaving `suggestedTransferTargets` legitimately empty (a club
        // with no budget gets no suggestions). Give the fixture club the
        // same healthy-headroom treatment as the settings fixture so the
        // affordability and wage filters pass exactly as designed. The
        // 20_000 floor clears the free agent's full-value asking price
        // with room to spare.
        clubs[userClubIndex].transferBudget = max(20_000, userClub.transferBudget + 20_000)
        clubs[userClubIndex].wageBudget = max(userClub.wageBill + 3_000, userClub.wageBudget)

        let squad = clubs[userClubIndex].players
        if fullCover {
            // Close the only two thin roles in this squad book: give the
            // lone natural left-back a deputy (Kacper Duda, the left
            // winger) and Left Midfield its second fit (Antonio Valera,
            // the right winger who already covers the left flank). Every
            // role then has at least two available fits.
            for index in squad.indices {
                switch squad[index].name {
                case "Kacper Duda":
                    clubs[userClubIndex].players[index].secondaryPositions.append(.leftBack)
                case "Antonio Valera":
                    clubs[userClubIndex].players[index].secondaryPositions.append(.leftMid)
                default:
                    break
                }
            }
        } else {
            // Deterministic thin cover through the real availability flag:
            // both right-back-shaped players out (Rafael Almada natural RB,
            // Owen Radcliffe CB with an RB secondary) leaves Chris
            // Smallwood as Right-Back's only available fit, and left-back
            // Patrice Almada out leaves Left-Back with nobody.
            let injuredNames: Set<String> = ["Rafael Almada", "Owen Radcliffe", "Patrice Almada"]
            for index in squad.indices where injuredNames.contains(squad[index].name) {
                clubs[userClubIndex].players[index].injuryWeeks = 3
            }

            // Exactly two affordable left-back targets (LB is the red
            // role). Injected players use fixed names so the UI-test
            // target selectors are stable. Ratings of 66–67 keep values
            // and wages far inside a top-flight club's budget and wage
            // headroom at any era.
            var feeLB = Self.makePlayer(name: "Marcus Tyne", position: .defender,
                                        detailedPosition: .leftBack,
                                        secondaryPositions: [.centreBack],
                                        nationality: "England",
                                        age: 24, rating: 67, startYear: startYear)
            feeLB.contractYears = 3
            var freeLB = Self.makePlayer(name: "Karel Dvorak", position: .defender,
                                         detailedPosition: .leftBack,
                                         secondaryPositions: [],
                                         nationality: "Czech Republic",
                                         age: 29, rating: 66, startYear: startYear)
            freeLB.contractYears = 0
            transferMarket = [
                TransferTarget(player: freeLB, sellingClubIndex: nil, askingPrice: freeLB.value),
                TransferTarget(player: feeLB, sellingClubIndex: 1,
                               askingPrice: max(20, feeLB.value / 2)),
            ]
        }

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

        // Opt-in deadline-day rush: fast-forward the store's clock to the
        // real deadline date (the last day of the window, where
        // `isDeadlineDayRush` is true by definition) BEFORE any state is
        // seeded, so every relative date below — the incoming offer's
        // expiry, the scouting due date — derives from it consistently.
        if ProcessInfo.processInfo.arguments.contains("UITEST_TRANSFERS_DEADLINE_RUSH") {
            currentDate = transferDeadlineDate
        }

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

        // 4b. Deadline-day flood: with the rush argument set, AI clubs bid
        //     for MORE of the user's players through the REAL daily
        //     generator (`generateOfferForUser()` — the same call the
        //     clock's deadline scramble makes), topping the live offer
        //     count up to three. Rival budgets are topped up first so a
        //     funded buyer always exists for whatever target the generator
        //     picks (it returns silently otherwise), and its one-bid-per-
        //     player rule keeps every bid on a different player. Each
        //     generated bid posts a real "Bid received" news item.
        if ProcessInfo.processInfo.arguments.contains("UITEST_TRANSFERS_DEADLINE_RUSH") {
            for index in clubs.indices where index != userClubIndex {
                clubs[index].transferBudget += 1_000_000
            }
            var attempts = 0
            while pendingOffers.count < 3 && attempts < 6 {
                generateOfferForUser()
                attempts += 1
            }
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

        // 7. A pending deal at the personal-terms stage for the
        //    NEGOTIATIONS tab — seeded only when the launch argument opts
        //    in, so the negotiation flow test's "exactly one deal" delta
        //    stays exact under the base fixture. The deal is created
        //    through the REAL `beginPersonalTermsWait` path (a club-listed
        //    player outside the user's squad, so it starts NOT ready —
        //    medical & paperwork in progress, like any freshly agreed
        //    fee) and then reaches readiness through the production daily
        //    transition: a DEBUG-only helper fast-forwards the store's
        //    clock past the medical date and runs
        //    `checkPendingTransferDeals()`, including its "ready to talk
        //    terms" news. No readiness flag is ever hand-set.
        if ProcessInfo.processInfo.arguments.contains("UITEST_TRANSFERS_SEED_READY_DEAL"),
           let listed = transferMarket.first(where: {
               $0.sellingClubIndex != nil && $0.player.id != negotiationPlayerID
           }) {
            _ = beginPersonalTermsWait(listed, price: max(1_000, userClub.transferBudget / 4),
                                       sellOnPercentage: 0, buyBackFee: 0, includedPlayer: nil)
            fastForwardPendingDealReadinessForDebug()
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

    /// Builds on the shared Career navigation fixture with exactly what
    /// the redesigned Hall of Fame presents — inducted through the REAL
    /// induction path (`evaluateForLegendStatus` and its scoring, never
    /// seeded by hand), so the fixtures exercise the same bar real
    /// careers are judged against:
    ///
    /// - two Club Legends (distinct legend scores, so wall ordering is
    ///   deterministic) and one Global Hall of Fame legend,
    /// - a completed title-and-cup previous season through the real
    ///   rollover record shape, so each legend's `trophiesWon` and the
    ///   manager exhibit's trophy cabinet have real content,
    /// - deterministic career tallies (the same name-keyed accumulators
    ///   the season-end accounting writes), tenure, captaincy and peak
    ///   ratings for the three retirees.
    ///
    /// The career is rewound to season 2 so a single completed season is
    /// coherent (real saves only ever record seasons ≥ 1).
    @discardableResult
    func prepareCareerHallOfFameFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 1. The career is now in season 2 with one completed season —
        //    re-derive the stored date so season-derived values stay
        //    coherent after the bump, then append the rollover record
        //    shape with the club as champion AND cup winner (the trophy
        //    lines the induction path reads back from `history`).
        season = 2
        currentMatchday = 4
        currentDate = date(forMatchday: currentMatchday)
        let labelOne = officeSeasonLabel(for: 1)
        let division = divisionName(userDivisionTier)
        history.append(SeasonRecord(
            season: 1, label: labelOne,
            userClub: userClub.name, userDivision: division, userPosition: 1,
            champion: userClub.name, cupWinner: userClub.name, euroWinner: "Continental Kings",
            communityShieldWinner: "—"))
        careerHonours.append("🏆 \(division) title (\(labelOne))")
        careerHonours.append("🏆 \(Self.cupName) (\(labelOne))")
        careerRecordByClub[userClub.name] = ClubCareerRecord(wins: 31, draws: 6, losses: 7)

        // 2. Three distinct retirees from the real squad: a striker, a
        //    defender and a goalkeeper, so every goal-weight branch of
        //    the scoring formula is exercised. They are renamed in place
        //    (the same DEBUG-only memberwise-initializer pattern the
        //    transfers fixture uses) so the UI tests can anchor on the
        //    wall/detail identifiers by name; identities, ratings and
        //    squad positions are untouched.
        func renamed(_ player: Player, _ name: String) -> Player {
            Player(id: player.id, name: name, position: player.position,
                   detailedPosition: player.detailedPosition,
                   secondaryPositions: player.secondaryPositions,
                   age: player.age, rating: player.rating)
        }
        let squad = clubs[userClubIndex].players
        let strikerOriginal = squad.first { $0.position == .forward }
        let defenderOriginal = squad.first { $0.position == .defender && $0.id != strikerOriginal?.id }
        let keeperOriginal = squad.first { $0.position == .goalkeeper && $0.id != strikerOriginal?.id && $0.id != defenderOriginal?.id }
        var striker: Player?
        var defender: Player?
        var keeper: Player?
        if let player = strikerOriginal {
            striker = renamed(player, "Rowan Striker")
            clubs[userClubIndex].players[clubs[userClubIndex].players.firstIndex { $0.id == player.id }!] = striker!
        }
        if let player = defenderOriginal {
            defender = renamed(player, "Sam Shield")
            clubs[userClubIndex].players[clubs[userClubIndex].players.firstIndex { $0.id == player.id }!] = defender!
        }
        if let player = keeperOriginal {
            keeper = renamed(player, "Victor Vale")
            clubs[userClubIndex].players[clubs[userClubIndex].players.firstIndex { $0.id == player.id }!] = keeper!
        }

        // 3. Deterministic tallies, tuned so the real formula lands each
        //    player on a known side of the two thresholds:
        //    striker 80 and defender 63 (Club Legends, in that wall
        //    order), keeper 98 (Global Hall of Fame, over the 95 bar).
        //    Every accumulator here is the exact name/uuid-keyed store
        //    field the real accounting writes — no second implementation.
        func seedTallies(_ player: Player, apps: Int, goals: Int, assists: Int,
                         cleanSheets: Int, averageRating: Double, motm: Int,
                         peakRating: Int, captainSeasons: Int) {
            allTimeAppearances[player.name] = apps
            allTimeScorers[player.name] = goals
            allTimeAssists[player.name] = assists
            allTimeCleanSheets[player.name] = cleanSheets
            allTimeRatingPoints[player.name] = averageRating * Double(apps)
            motmTally[player.name] = motm
            hallOfFame[player.name] = HallEntry(name: player.name, position: player.position,
                                                peakRating: peakRating, peakSeason: labelOne)
            clubTenureStart[player.id] = 1
            if captainSeasons > 0 { captainSeasonTally[player.id] = captainSeasons }
        }
        if let striker {
            seedTallies(striker, apps: 220, goals: 120, assists: 20, cleanSheets: 0,
                        averageRating: 71, motm: 4, peakRating: 84, captainSeasons: 2)
            evaluateForLegendStatus(striker, clubName: userClub.name)
        }
        if let defender {
            seedTallies(defender, apps: 260, goals: 12, assists: 8, cleanSheets: 45,
                        averageRating: 69, motm: 3, peakRating: 76, captainSeasons: 0)
            evaluateForLegendStatus(defender, clubName: userClub.name)
        }
        if let keeper {
            seedTallies(keeper, apps: 480, goals: 0, assists: 60, cleanSheets: 110,
                        averageRating: 80, motm: 10, peakRating: 89, captainSeasons: 4)
            evaluateForLegendStatus(keeper, clubName: userClub.name)
        }

        // 4. Induction emits its own board stories through addNews — mark
        //    them read so the fixture never disturbs the shared inbox
        //    accounting the other suites assert against.
        for item in news where (item.title == "Club Legend" || item.title == "Global Hall of Fame") {
            markNewsRead(item)
        }

        persist()
        return self
    }

    /// Builds on the shared Career navigation fixture with exactly what
    /// the redesigned Achievement Gallery presents, all through the REAL
    /// unlock path (`unlock(_:)` — never seeded by hand, so the unlock
    /// records, contexts and career-points total are exactly what real
    /// careers produce):
    ///
    /// - a mixed gallery: one unlocked milestone achievement (its own
    ///   unlock record provides the detail sheet's history), one
    ///   storied achievement (its own generated context), and one
    ///   deliberately unclassified honour flowing nowhere — the gallery
    ///   itself only ever READS authoritative state, so the fixture
    ///   pins exactly what the tests assert.
    /// - the celebration overlay cleared so the fixture boots straight
    ///   into the shell with no modal in the way.
    ///
    /// The career is rewound to season 2 so a single completed season
    /// is coherent (real saves only ever record seasons ≥ 1).
    @discardableResult
    func prepareCareerAchievementsFixtureForDebug() -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // 1. The career is now in season 2 with one completed season —
        //    re-derive the stored date so season-derived values stay
        //    coherent after the bump, then append the rollover record
        //    shape (the unlock contexts interpolate it).
        season = 2
        currentMatchday = 4
        currentDate = date(forMatchday: currentMatchday)
        let labelOne = officeSeasonLabel(for: 1)
        let division = divisionName(userDivisionTier)
        history.append(SeasonRecord(
            season: 1, label: labelOne,
            userClub: userClub.name, userDivision: division, userPosition: 1,
            champion: userClub.name, cupWinner: userClub.name, euroWinner: "Continental Kings",
            communityShieldWinner: "—"))

        // 2. Two achievements through the REAL unlock path — one
        //    milestone, one storied — so the gallery shows a deterministic
        //    unlocked/locked mix and the detail sheet has a real unlock
        //    record (context, season, date) to present. The celebration
        //    overlay is cleared after each so nothing covers the shell.
        unlock(.wins50)
        pendingAchievementCelebration = nil
        unlock(.giantKiller)
        pendingAchievementCelebration = nil

        // 3. The unlock path emits its own board stories through addNews —
        //    mark them read so the fixture never disturbs the shared inbox
        //    accounting the other suites assert against.
        for item in news where item.title == "Achievement unlocked" {
            markNewsRead(item)
        }

        persist()
        return self
    }

    /// Fast-forwards a freshly agreed transfer deal through the medical
    /// wait USING THE STORE'S OWN TRANSITION: the clock is advanced past
    /// the deal's `readyDate` and the production daily check
    /// `checkPendingTransferDeals()` runs — the same call the real game
    /// makes once a day, which flips `isReady` and posts the "ready to
    /// talk terms" news item. Nothing is hand-set; tests launch with a
    /// deal whose readiness came from the real path.
    func fastForwardPendingDealReadinessForDebug() {
        if let dealIndex = pendingTransferDeals.indices.last,
           !pendingTransferDeals[dealIndex].isReady {
            let readyDate = pendingTransferDeals[dealIndex].readyDate
            if currentDate < readyDate {
                currentDate = readyDate
            }
            checkPendingTransferDeals()
        }
    }

    /// Builds on the shared Career navigation fixture with exactly what
    /// the redesigned pre-match hub needs, all through the real store
    /// paths and without touching match outcomes:
    ///
    /// - Lands on a matchday whose fixture is the user's league game
    ///   TODAY, with `pendingTeamTalk` and `pendingPressQuestion`
    ///   deterministic (set after `enterPreMatch()` clears whatever the
    ///   random 50% press roll and delegation left behind),
    /// - the user's lineup intact (a full starting XI lets the tests
    ///   pin `CONFIRMED LINEUPS` and KICK OFF),
    /// - the opponent deterministic in position and name.
    ///
    /// `UITEST_CAREER_PREMATCH_NO_PROMPTS` opts out of the prompt
    /// seeding so the tests can also cover the no-prompts variant of
    /// the hub.
    @discardableResult
    func prepareCareerPreMatchFixtureForDebug(skipPrompts: Bool = false) -> GameStore {
        prepareCareerNavigationFixtureForDebug()

        // The navigation fixture's matchday-4 fixture is not necessarily
        // the user's; walk the real calendar forward with the same
        // stopping rules as the CONTINUE fast-forward (advanceDay's own
        // guard: it never crosses a user match day) until the user has a
        // match TODAY. No user match is ever played — the store lands in
        // the exact state a real CONTINUE tap reaches.
        var safety = 0
        while !isUserMatchToday && !isSeasonOver && safety < 40 {
            advanceDay()
            safety += 1
        }
        guard isUserMatchToday else { return self }

        // The hub opens through the production entry point: this is what
        // seeds the team-talk/press prompts in real play (including the
        // random press roll and any assistant delegation).
        enterPreMatch()

        if !skipPrompts {
            // Make the prompts deterministic: whatever the random roll
            // left behind is replaced with the known real generators, so
            // the tests can assert on a definite team talk AND press
            // conference with stable option labels.
            pendingTeamTalk = makeTeamTalk()
            pendingPressQuestion = makePressQuestion()
        } else {
            // The no-prompts variant: answer any prompts through the
            // production delegation path (the same assistant handling the
            // manager uses), leaving the hub prompt-free exactly as it
            // appears in real play after delegation.
            if let question = pendingPressQuestion,
               let best = question.options.max(by: { ($0.moraleDelta + $0.confidenceDelta) < ($1.moraleDelta + $1.confidenceDelta) }) {
                answerPress(best, headline: "Press conference (assistant)")
            }
            if let talk = pendingTeamTalk,
               let best = talk.options.max(by: { ($0.moraleDelta + $0.confidenceDelta) < ($1.moraleDelta + $1.confidenceDelta) }) {
                answerTeamTalk(best)
            }
        }

        // Freeze the lineup so the tests can pin CONFIRMED LINEUPS and
        // KICK OFF against a full, known XI (the engine's preview uses
        // `matchXIForPreview`, so this only re-asserts what the engine
        // would already field).
        let bestXI = bestXI(for: clubs[userClubIndex],
                            formation: aiFormation(for: clubs[userClubIndex]))
        userStarterIDs = Set(bestXI.map(\.id))

        opponentShortNameForUITests = clubs[opponentIndexForUITests].shortName

        persist()
        return self
    }

    /// The next opponent's club index for the pre-match fixture
    /// (the side the user is not, from the authoritative fixture list).
    private var opponentIndexForUITests: Int {
        guard let match = nextUserMatchInfo else { return userClubIndex }
        return match.homeIndex == userClubIndex ? match.awayIndex : match.homeIndex
    }

    /// The season label for an arbitrary season number (the same formula
    /// as `seasonLabel`, parameterised — fixture-local helper).
    private func officeSeasonLabel(for seasonNumber: Int) -> String {
        let start = (startYear - 1) + seasonNumber
        return "\(start)/\(String(format: "%02d", (start + 1) % 100))"
    }

    // MARK: Football Museum fixture

    /// Deterministic Football Museum fixture for UI tests, launched with
    /// `UITEST_LEGACY_MUSEUM`. Unlike the Career fixtures this boots no
    /// career at all — the museum is reachable from the main menu without
    /// any active save — so it instead seeds the `LegacyArchive` store
    /// (Documents/legacy) with two hand-built careers whose numbers the
    /// tests assert against. Real player saves are never read or modified:
    /// the store is cleared and rebuilt from scratch each launch, so the
    /// archive state is fully deterministic.
    ///
    /// Career A (Ruth Whitmore) is the decorated one — a treble-winning
    /// 8-season spell with legends, records, transfers and two front
    /// pages; Career B (Arthur Booth) is the modest 2-season one with no
    /// honours, legends or pages. The gap gives every wing a real spread:
    /// a highest-score line, a two-row leaderboard, distinct compare
    /// values, both a filled and an empty sub-section, and a delete
    /// target whose removal provably empties the museum.
    static func seedLegacyMuseumFixtureForDebug() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyDir = docs.appendingPathComponent("legacy", isDirectory: true)
        try? FileManager.default.removeItem(at: legacyDir)

        let seasonRecord: (Int, String, String, String) -> SeasonRecord = { season, label, club, division in
            SeasonRecord(season: season, label: label, userClub: club, userDivision: division,
                         userPosition: season <= 2 ? 3 : 1,
                         champion: "Old Trafford Reds", cupWinner: "Riverton FC",
                         euroWinner: "Continental Kings", communityShieldWinner: "—")
        }

        // Career A — Ruth Whitmore at Harbour City (2021–2028, 8 seasons).
        let whitmore = LegacyCareer(
            id: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001")!,
            managerName: "Ruth Whitmore", clubName: "Harbour City", startYear: 2021, endYear: 2028,
            seasonsManaged: 8, finalDivisionName: "Premier Division",
            careerHonours: ["Premier Division title (2025/26)", "National Cup (2026/27)", "Continental Cup (2027/28)"],
            autobiography: "Eight seasons of building. Ruth Whitmore arrived with a plan and left with a trophy cabinet that outgrew its room.",
            timeline: [
                LegacyCareerMoment(season: 1, year: 2021, icon: "📅", headline: "A new era begins", detail: "Took charge ahead of the new season."),
                LegacyCareerMoment(season: 5, year: 2025, icon: "🏆", headline: "Champions at last", detail: "The title came home after five years of building."),
            ],
            achievementUnlocks: [
                AchievementUnlock(kind: .promotion, season: 2, date: Date(timeIntervalSince1970: 1_650_000_000), context: "Promoted in the first attempt."),
                AchievementUnlock(kind: .leagueTitle, season: 5, date: Date(timeIntervalSince1970: 1_750_000_000), context: "Champions at last."),
                AchievementUnlock(kind: .cupWinner, season: 6, date: Date(timeIntervalSince1970: 1_780_000_000), context: "Cup winners at Wembley."),
            ],
            careerAchievementPoints: 120,
            clubLegends: [
                ClubLegend(playerID: UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000001")!,
                           name: "Mara Voss", position: .forward, nationality: "Sweden", clubName: "Harbour City",
                           joinedSeason: 1, retiredSeason: 8, finalAge: 33, appearances: 341, goals: 188, assists: 74,
                           cleanSheets: 0, averageRating: 7.9, seasonsAsCaptain: 4,
                           trophiesWon: ["Premier Division title (2025/26)", "National Cup (2026/27)", "Continental Cup (2027/28)"],
                           individualAwards: 3, peakRating: 92, legendScore: 86, isGlobalLegend: false,
                           biography: "Harbour City's greatest ever goalscorer."),
                ClubLegend(playerID: UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000002")!,
                           name: "Tomas Keller", position: .goalkeeper, nationality: "Germany", clubName: "Harbour City",
                           joinedSeason: 3, retiredSeason: 8, finalAge: 34, appearances: 190, goals: 0, assists: 0,
                           cleanSheets: 71, averageRating: 7.4, seasonsAsCaptain: 1,
                           trophiesWon: ["Premier Division title (2025/26)"],
                           individualAwards: 1, peakRating: 88, legendScore: 61, isGlobalLegend: false,
                           biography: "The safe pair of hands behind the title years."),
            ],
            history: (1...8).map { seasonRecord($0, "Season \($0)", "Harbour City", "Premier Division") },
            careerRecordByClub: [:],
            legacyScore: 500, legacyTier: .legend,
            recordBook: [
                "Mara Voss scored 188 goals across eight seasons.",
                "Tomas Keller kept 71 clean sheets.",
            ],
            archivedDate: Date(timeIntervalSince1970: 1_800_000_000),
            topScorer: LegacyRecordHolder(name: "Mara Voss", value: 188, detail: "188 goals in 341 games"),
            topAppearances: LegacyRecordHolder(name: "Mara Voss", value: 341, detail: "Eight seasons of service"),
            topMOTM: LegacyRecordHolder(name: "Mara Voss", value: 42, detail: "Man of the match awards"),
            recordWin: LegacyRecordHolder(name: "Harbour City", value: 6, detail: "6–0 vs Old Athletic, 2026/27"),
            bestSeason: LegacyRecordHolder(name: "Harbour City", value: 1, detail: "Champions, 2025/26"),
            topTransfers: [
                TransferHistoryEntry(date: Date(timeIntervalSince1970: 1_700_000_000), playerName: "Diego Sarr",
                                     action: "Sold", otherClub: "Old Athletic", fee: 2400),
                TransferHistoryEntry(date: Date(timeIntervalSince1970: 1_650_000_000), playerName: "Danny Draper",
                                     action: "Signed", otherClub: "Riverton FC", fee: 1200),
            ],
            frontPages: [
                Newspaper(date: Date(timeIntervalSince1970: 1_760_000_000), season: 5, outlet: .national,
                          masthead: "THE DAILY WHISTLE", headline: "CHAMPIONS AT LAST",
                          standfirst: "Harbour City end a 30-year wait for the title.",
                          body: "A title won with games to spare, sealed on home turf in front of a disbelieving, delirious full house.",
                          category: .result, importance: .historic, playerName: "Mara Voss",
                          playerPosition: .forward, playerAge: 30, clubName: "Harbour City"),
                Newspaper(date: Date(timeIntervalSince1970: 1_790_000_000), season: 8, outlet: .european,
                          masthead: "THE CONTINENTAL GAME", headline: "EUROPEAN GLORY FOR HARBOUR CITY",
                          standfirst: "The Continental Cup comes home.",
                          body: "A final won on penalties after a night of relentless pressure.",
                          category: .world, importance: .major, clubName: "Harbour City"),
            ])

        // Career B — Arthur Booth at Midfield Rovers (2019–2020, 2 seasons).
        let booth = LegacyCareer(
            id: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000002")!,
            managerName: "Arthur Booth", clubName: "Midfield Rovers", startYear: 2019, endYear: 2020,
            seasonsManaged: 2, finalDivisionName: "Regional League",
            careerHonours: [],
            autobiography: "Two steady seasons at a small club. Arthur Booth kept Midfield Rovers honest and went home content.",
            timeline: [
                LegacyCareerMoment(season: 1, year: 2019, icon: "📅", headline: "A quiet start", detail: "Steadied the side mid-table."),
            ],
            achievementUnlocks: [],
            careerAchievementPoints: 10,
            clubLegends: [],
            history: (1...2).map { seasonRecord($0, "Season \($0)", "Midfield Rovers", "Regional League") },
            careerRecordByClub: [:],
            legacyScore: 74, legacyTier: .journeyman,
            recordBook: [],
            archivedDate: Date(timeIntervalSince1970: 1_700_000_000),
            topScorer: nil, topAppearances: nil, topMOTM: nil, recordWin: nil, bestSeason: nil,
            topTransfers: nil, frontPages: nil)

        LegacyArchive.archive(booth)   // archived first → shown second
        LegacyArchive.archive(whitmore) // archived last → shown first
    }

    /// Builds a fresh, saved career parked exactly at the season-end review:
    /// every league matchday has been played through the engine's real
    /// instant-sim path (`playNextMatchday()`), and the final matchday is
    /// committed through the real live-match path (`beginUserMatch()` →
    /// `skipToEnd()` → `finishLiveMatch()`), which is what fires the
    /// end-of-season pipeline — `recordSeasonHonours()` (honours, European
    /// qualification and job offers), sack-renewal checks and the like —
    /// exactly as a real player's season would end.
    ///
    /// Determinism: the user's own goals are not forced (the live match is
    /// skipped to full time, not scripted), so the fixture pins the review
    /// screen's *structure*, not a specific finishing position. It pins
    /// what the tests must rely on:
    ///
    /// - the season is over on the final matchday (route shows
    ///   SeasonReviewView) with a complete 20-row final table,
    /// - a striker is pushed to the top of the division's scoring charts
    ///   via his real season tally, so the AWARDS panel always has a
    ///   Golden Boot and the user's club has a Player of the Season and a
    ///   Top Scorer,
    /// - manager reputation, board confidence and contract years are set
    ///   so `updateReputation`/`checkForSacking`/`checkManagerContractRenewal`
    ///   deterministically keep the manager employed — wasSacked stays
    ///   false, so the review shows the standard verdict panel and the
    ///   CONTINUE TO SEASON 2 action (no forced job-choice trap).
    ///
    /// In-memory only: a brand-new store with its own save ID. Real player
    /// saves are never read or modified; the launch argument is only ever
    /// set by the UI-test runner.
    @discardableResult
    func prepareCareerSeasonEndFixtureForDebug() -> GameStore {
        // A fresh career for a known club.
        let catalogue = Self.catalogueEntries()
        let clubIndex = catalogue.firstIndex { $0.name == "Old Trafford Reds" } ?? 0
        newGame(clubIndex: clubIndex, managerName: "Season End Fixture Manager")

        // Pin the season-end personnel checks deterministically: a named
        // striker gets a boosted rating (he will be the club's standout
        // performer and its leading scorer whatever the engine rolls) and
        // the club keeps a healthy reputation/board/contract position so
        // the sacking and contract-lapse paths stay dormant.
        let squad = clubs[userClubIndex].players
        let strikerIndex = squad.firstIndex { $0.detailedPosition == .striker } ?? 0
        clubs[userClubIndex].players[strikerIndex].rating = max(88, clubs[userClubIndex].players[strikerIndex].rating)
        managerReputation = 78
        boardConfidence = 88
        managerContractYears = max(3, managerContractYears)

        // Play the season out through the engine's own instant-sim path —
        // the same one the CONTINUE button uses when there is no live
        // match. Every matchday (including the user's) resolves, records
        // and advances exactly as a fast-forwarded season would.
        var matchdays = 0
        while !isSeasonOver && matchdays < totalMatchdays + 5 {
            playNextMatchday()
            matchdays += 1
        }
        assert(isSeasonOver, "Fixture season must be complete")

        // The final matchday has already been instant-simmed by the loop
        // above, so commit the year-end pipeline through the real live
        // path instead: rewind the matchday clock to the last day, begin
        // the user's fixture as a real live match, skip to full time and
        // finish. `finishLiveMatch()` is what fires recordSeasonHonours()
        // at season's end — honours, European qualification and the job
        // offers the review screen advertises — exactly as a real player's
        // final whistle does.
        let finalDay = totalMatchdays
        let finalFixtureIndex = fixtures.firstIndex {
            $0.matchday == finalDay && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex)
        }
        if let index = finalFixtureIndex {
            let fixture = fixtures[index]
            // Roll back the league table for the two clubs involved, then
            // unplay the fixture so the live match re-records it cleanly.
            rollbackResult(for: fixture)
            fixtures[index].played = false
            fixtures[index].homeGoals = 0
            fixtures[index].awayGoals = 0
            // Rewind both the matchday counter and the wall clock onto the
            // final fixture's day — the season walk above already advanced
            // a day past it, and the live-match start requires the fixture
            // to be TODAY.
            currentMatchday = finalDay
            currentDate = date(forMatchday: finalDay)
            live = nil
            beginUserMatch()
            live?.skipToEnd()
            finishLiveMatch()
            assert(isSeasonOver, "Live finish must leave the season complete")
            assert(!wasSacked, "Fixture manager must survive the season review")
        }
        assert(finalFixtureIndex != nil, "The user must have a final-day league fixture")

        // End-of-season job offers are probabilistic in the real pipeline
        // (generateJobOffers rolls 0–2 offers when the objective was met,
        // and coin-flips a single offer when it wasn't). Re-roll through
        // the real generator with reputation headroom raised so the review
        // screen deterministically advertises offers for the audit. The
        // offer set itself stays engine-generated.
        managerReputation = 90
        var offerRolls = 0
        while pendingJobOffers.isEmpty && offerRolls < 20 {
            generateJobOffers()
            offerRolls += 1
        }
        assert(!pendingJobOffers.isEmpty,
               "recordSeasonHonours() must have offered end-of-season job opportunities")

        // The career is persisted exactly once, like a real session.
        persist()
        return self
    }

    /// Removes one fixture's contribution from both clubs' league records
    /// so the live re-play of the final day records it exactly once.
    private func rollbackResult(for fixture: Fixture) {
        func undo(_ scored: Int, _ conceded: Int, clubIndex: Int) {
            guard clubs.indices.contains(clubIndex) else { return }
            clubs[clubIndex].played = max(0, clubs[clubIndex].played - 1)
            // points derive from won*3 + drawn, so removing the result
            // removes the points with it.
            if scored > conceded {
                clubs[clubIndex].won = max(0, clubs[clubIndex].won - 1)
            } else if scored == conceded {
                clubs[clubIndex].drawn = max(0, clubs[clubIndex].drawn - 1)
            } else {
                clubs[clubIndex].lost = max(0, clubs[clubIndex].lost - 1)
            }
            clubs[clubIndex].goalsFor = max(0, clubs[clubIndex].goalsFor - scored)
            clubs[clubIndex].goalsAgainst = max(0, clubs[clubIndex].goalsAgainst - conceded)
        }
        undo(fixture.homeGoals, fixture.awayGoals, clubIndex: fixture.homeIndex)
        undo(fixture.awayGoals, fixture.homeGoals, clubIndex: fixture.awayIndex)
    }
}
#endif
