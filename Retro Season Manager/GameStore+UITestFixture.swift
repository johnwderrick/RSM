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

        // 3. A deterministic inbox: one very long article (the scroll
        //    target) followed by routine items, newest first.
        let longBody = Array(repeating:
            "The chairman has asked for a full review of training ground facilities, scouting coverage and the medical department's turnaround times. Staff have been briefed to expect changes before the next transfer window, and supporters' groups have been invited to comment on the proposals before anything is finalised. ",
            count: 12).joined()
        let items: [(NewsCategory, String, String)] = [
            (.info, "DETERMINISTIC LONG ARTICLE", longBody),
            (.world, "Title race tightening across Europe", "Rival clubs dropped points this weekend, keeping the table congested."),
            (.injury, "Medical report filed", "The physio room expects a busy week with several players in rehabilitation."),
            (.board, "Board reviews season objectives", "The board is pleased with early progress but expects continued improvement."),
        ]
        for (category, title, body) in items.reversed() {
            news.insert(NewsItem(date: currentDate, category: category, title: title, body: body), at: 0)
        }

        // 4. Complete three league rounds through the real standings path.
        //    The user's sequence is deliberately W-D-L so the redesigned
        //    table can prove its summary, form guide, recent-results badges
        //    and next-fixture split against useful authoritative data.
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

        // 5. Persist exactly once so the save on disk matches memory.
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
}
#endif
