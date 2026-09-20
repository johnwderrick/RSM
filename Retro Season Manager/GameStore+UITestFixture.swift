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
//    panel and its full-sheet content are populated and scrollable,
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
}
#endif
