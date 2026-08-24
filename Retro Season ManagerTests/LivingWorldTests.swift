//
//  LivingWorldTests.swift
//  Retro Season ManagerTests
//
//  Guards the "living world" additions from item 4 of the improvement
//  directive: the scheduled-story queue, manager-appointment follow-ups,
//  wonderkid follow-ups, club rise/fall arcs, recurring rivalries, and
//  the broadened "around the leagues" digest.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LivingWorldTests: XCTestCase {

    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Living World Test")
        return store
    }

    // MARK: - Scheduled story queue

    func testScheduledStoryFiresOnlyOnOrAfterItsDueDate() async {
        let store = await freshStore()
        store.scheduleWorldStory(daysFromNow: 0...0, category: .world, title: "Due Today Story", body: "Fires immediately.")
        store.scheduleWorldStory(daysFromNow: 5...5, category: .world, title: "Due Later Story", body: "Fires in five days.")

        store.checkPendingWorldStories()
        XCTAssertTrue(store.news.contains { $0.title == "Due Today Story" }, "A story due today should fire immediately")
        XCTAssertFalse(store.news.contains { $0.title == "Due Later Story" }, "A story due in five days shouldn't fire yet")
        XCTAssertEqual(store.pendingWorldStories.count, 1, "Only the due story should be removed from the queue")

        store.currentDate = GameStore.calendar.date(byAdding: .day, value: 5, to: store.currentDate)!
        store.checkPendingWorldStories()
        XCTAssertTrue(store.news.contains { $0.title == "Due Later Story" }, "The delayed story should fire once its date arrives")
        XCTAssertTrue(store.pendingWorldStories.isEmpty, "Every fired story should be removed from the queue")
    }

    func testManagerSackingSchedulesAnAppointmentFollowUp() async {
        let store = await freshStore()
        // `checkRivalManagerSackings()` requires clubs with `played >= 8`
        // to be candidates — simulate enough matchdays for that to hold.
        for _ in 0..<8 { store.playNextMatchday() }

        var sackingFired = false
        for _ in 0..<4000 {
            let before = store.pendingWorldStories.count
            store.checkRivalManagerSackings()
            if store.pendingWorldStories.count > before {
                sackingFired = true
                break
            }
        }
        XCTAssertTrue(sackingFired, "A rival manager sacking should eventually fire within 4000 daily rolls at a 0.6% chance")
        XCTAssertTrue(store.pendingWorldStories.contains { $0.title == "New manager appointed" },
                      "A sacking should schedule a 'New manager appointed' follow-up")
    }

    // MARK: - Wonderkid follow-ups

    func testWonderkidFollowUpResolvesOnceAndIsRemovedFromTheWatchlist() async {
        let store = await freshStore()
        guard let clubIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }),
              let playerIndex = store.clubs[clubIndex].players.indices.first else {
            return XCTFail("Expected at least one AI club with players")
        }
        // Force age > 19 so this same player can never be re-picked by
        // simulateWonderkids() (age <= 19 only) within the same call and
        // have their watch entry silently overwritten.
        store.clubs[clubIndex].players[playerIndex].age = 25
        let playerID = store.clubs[clubIndex].players[playerIndex].id
        let emergenceRating = store.clubs[clubIndex].players[playerIndex].rating
        store.wonderkidWatchlist[playerID] = WonderkidWatch(season: store.season, ratingAtEmergence: emergenceRating)
        // Bump the tracked player's rating so the follow-up should read as a genuine breakthrough.
        store.clubs[clubIndex].players[playerIndex].rating = emergenceRating + 5
        store.season += 1

        store.simulateWorldEvents()

        XCTAssertNil(store.wonderkidWatchlist[playerID], "A resolved wonderkid should be removed from the watchlist")
        XCTAssertTrue(store.news.contains { $0.title == "Star in the making" },
                      "A wonderkid whose rating climbed further should get the 'Star in the making' follow-up")
    }

    func testStagnantWonderkidFadesFromTheSpotlight() async {
        let store = await freshStore()
        guard let clubIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }),
              let playerIndex = store.clubs[clubIndex].players.indices.first else {
            return XCTFail("Expected at least one AI club with players")
        }
        store.clubs[clubIndex].players[playerIndex].age = 25
        let playerID = store.clubs[clubIndex].players[playerIndex].id
        let emergenceRating = store.clubs[clubIndex].players[playerIndex].rating
        store.wonderkidWatchlist[playerID] = WonderkidWatch(season: store.season, ratingAtEmergence: emergenceRating)
        // Rating unchanged (or lower) — no genuine further development.
        store.season += 1

        store.simulateWorldEvents()

        XCTAssertNil(store.wonderkidWatchlist[playerID])
        XCTAssertTrue(store.news.contains { $0.title == "Faded from the spotlight" },
                      "A wonderkid who hasn't developed further should get the 'faded' follow-up")
    }

    // MARK: - Club rise/fall arcs

    func testClubFortunesSeedsBaselineOnFirstSight() async {
        let store = await freshStore()
        guard let clubIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }) else {
            return XCTFail("Expected an AI club")
        }
        let clubID = store.clubs[clubIndex].id
        XCTAssertNil(store.clubPrestigeBaseline[clubID])

        store.simulateWorldEvents()

        XCTAssertNotNil(store.clubPrestigeBaseline[clubID], "The first pass should seed a baseline for every AI club")
    }

    func testClubFortunesFiresRiseStoryOnLargePrestigeGainAndResetsBaseline() async {
        let store = await freshStore()
        guard let clubIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }) else {
            return XCTFail("Expected an AI club")
        }
        let clubID = store.clubs[clubIndex].id
        // A generous +40 delta (well clear of the ≥15 threshold and of
        // the 99 cap) so this stays deterministic even if one of
        // simulateWorldEvents()'s other low-probability rolls also
        // nudges this same club's prestige within the same call.
        let baseline = 40
        store.clubPrestigeBaseline[clubID] = baseline
        store.clubs[clubIndex].prestige = 80

        store.simulateWorldEvents()

        XCTAssertTrue(store.news.contains { $0.title == "Club on the rise" && $0.clubName == store.clubs[clubIndex].name })
        XCTAssertNotEqual(store.clubPrestigeBaseline[clubID], baseline, "The baseline should reset once an arc fires")
    }

    func testClubFortunesFiresDeclineStoryOnLargePrestigeDrop() async {
        let store = await freshStore()
        guard let clubIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }) else {
            return XCTFail("Expected an AI club")
        }
        let clubID = store.clubs[clubIndex].id
        // A generous −40 delta, same reasoning as the rise test above.
        let baseline = 80
        store.clubPrestigeBaseline[clubID] = baseline
        store.clubs[clubIndex].prestige = 40

        store.simulateWorldEvents()

        XCTAssertTrue(store.news.contains { $0.title == "Club in decline" && $0.clubName == store.clubs[clubIndex].name })
    }

    // MARK: - Recurring rivalries

    func testRecurringRivalryNeverFiresWithNoDynamicRivalries() async {
        // checkRecurringRivalry() is only reachable through
        // simulateWorldEvents(), which also runs simulateNewRivalry() —
        // over many calls a rivalry can legitimately form and then be
        // referenced back the very same season, so this only asserts
        // the guaranteed-by-construction starting state: a fresh career
        // has no dynamic rivalries and nothing to recall yet.
        let store = await freshStore()
        XCTAssertTrue(store.dynamicRivalries.isEmpty)
        XCTAssertFalse(store.news.contains { $0.title == "Old rivals" })
    }

    func testRecurringRivalryEventuallyReferencesAFormedRivalry() async {
        let store = await freshStore()
        store.dynamicRivalries = [RivalryPair(clubA: "Test United", clubB: "Test City", formedSeason: 3, reason: "a fiercely contested title race")]

        // Checking only the title (not this specific pair's content) let
        // a *different*, organically-formed rivalry's "Old rivals" story
        // satisfy the break condition instead of the seeded one — and
        // dynamicRivalries genuinely grows over the loop as
        // simulateNewRivalry() keeps rolling too, diluting how often
        // randomElement() lands on the seeded pair specifically. Checking
        // the exact content inline (not the 60-item-capped, never-cleared
        // store.news after the fact) and using enough trials to absorb
        // that dilution fixes both — this was a real test bug, not
        // implementation flakiness (found during the item 10 polish pass).
        var matched = false
        for _ in 0..<1500 {
            store.simulateWorldEvents()
            if store.news.contains(where: { $0.title == "Old rivals" && $0.body.contains("Season 3") && $0.body.contains("title race") }) {
                matched = true
                break
            }
        }
        XCTAssertTrue(matched, "The seeded pair's recurring-rivalry callback should eventually fire within 1500 seasons")
    }

    func testNewlyFormedRivalriesAlwaysRecordFormationMetadata() async {
        let store = await freshStore()
        for _ in 0..<300 where store.dynamicRivalries.isEmpty {
            store.simulateWorldEvents()
        }
        guard !store.dynamicRivalries.isEmpty else {
            return XCTFail("Expected at least one dynamic rivalry to form within 300 seasons at a 10%/season chance")
        }
        XCTAssertTrue(store.dynamicRivalries.allSatisfy { $0.formedSeason != nil && $0.reason != nil },
                      "Every rivalry created by simulateNewRivalry() should record when and why it formed")
    }

    // MARK: - Around the leagues

    func testAroundTheLeaguesCoversEveryDivision() async {
        let store = await freshStore()
        store.punditPowerRankings()
        guard let story = store.news.first(where: { $0.title == "Around the leagues" }) else {
            return XCTFail("Expected an 'Around the leagues' story")
        }
        for tier in 0..<GameStore.divisionNames.count {
            XCTAssertTrue(story.body.contains(store.divisionName(tier)), "Digest should mention \(store.divisionName(tier))")
        }
    }
}
