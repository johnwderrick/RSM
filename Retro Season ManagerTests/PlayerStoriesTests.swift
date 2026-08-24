//
//  PlayerStoriesTests.swift
//  Retro Season ManagerTests
//
//  Guards item 6 of the improvement directive: the season-end player-
//  story sweeps (academy breakthrough, fan favourite, homegrown wonderkid
//  breakout reusing item 4's wonderkidWatchlist/checkWonderkidFollowUps),
//  the retirement addNews bug fix, and the captaincy-moment additions.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class PlayerStoriesTests: XCTestCase {

    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Player Stories Test")
        return store
    }

    // MARK: - Academy graduate breakthroughs

    func testAcademyGraduateBreakthroughFiresAtFiftyAppearances() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.isAcademyProduct = true
        store.clubs[store.userClubIndex].players[0] = player
        store.allTimeAppearances[player.name] = 50

        store.checkAcademyGraduateBreakthroughs()

        XCTAssertTrue(store.academyGraduateMilestoneIDs.contains(player.id))
        XCTAssertTrue(store.news.contains { $0.title == "Academy graduate breakthrough" && $0.body.contains(player.name) })
    }

    func testAcademyGraduateBreakthroughDoesNotFireBelowFifty() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.isAcademyProduct = true
        store.clubs[store.userClubIndex].players[0] = player
        store.allTimeAppearances[player.name] = 49

        store.checkAcademyGraduateBreakthroughs()

        XCTAssertFalse(store.academyGraduateMilestoneIDs.contains(player.id))
        XCTAssertFalse(store.news.contains { $0.title == "Academy graduate breakthrough" })
    }

    func testNonAcademyPlayerNeverGetsABreakthroughStory() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.isAcademyProduct = false
        store.clubs[store.userClubIndex].players[0] = player
        store.allTimeAppearances[player.name] = 200

        store.checkAcademyGraduateBreakthroughs()

        XCTAssertFalse(store.news.contains { $0.title == "Academy graduate breakthrough" })
    }

    func testAcademyGraduateBreakthroughIsIdempotent() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.isAcademyProduct = true
        store.clubs[store.userClubIndex].players[0] = player
        store.allTimeAppearances[player.name] = 50

        store.checkAcademyGraduateBreakthroughs()
        store.checkAcademyGraduateBreakthroughs()

        XCTAssertEqual(store.news.filter { $0.title == "Academy graduate breakthrough" }.count, 1)
    }

    // MARK: - Fan favourites

    func testFanFavouriteIsRecognizedOnceAndNotAgain() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.rating = 80 // clears isFanFavourite's rating threshold
        store.clubs[store.userClubIndex].players[0] = player

        // The rest of a realistic squad can easily contain other players
        // who already clear isFanFavourite's own bar (rating >= 78) — so
        // scope every assertion to this specific player's story, not a
        // total count across the whole squad.
        store.checkFanFavourites()
        XCTAssertTrue(store.recognizedFanFavouriteIDs.contains(player.id))
        XCTAssertEqual(store.news.filter { $0.title == "Fan favourite" && $0.body.contains(player.name) }.count, 1)

        store.checkFanFavourites()
        XCTAssertEqual(store.news.filter { $0.title == "Fan favourite" && $0.body.contains(player.name) }.count, 1,
                       "A player already recognized shouldn't be celebrated again")
    }

    func testOrdinaryPlayerIsNeverRecognizedAsAFanFavourite() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.rating = 60
        store.clubs[store.userClubIndex].players[0] = player
        // Not the captain, and no tenure recorded — none of isFanFavourite's conditions hold.

        store.checkFanFavourites()

        XCTAssertFalse(store.recognizedFanFavouriteIDs.contains(player.id))
    }

    // MARK: - Homegrown wonderkid breakout (reuses item 4's wonderkidWatchlist)

    func testUserWonderkidBreakthroughInsertsIntoTheSharedWatchlistAndResolvesLater() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.age = 19
        player.apps = 20
        player.rating = 75
        store.clubs[store.userClubIndex].players[0] = player

        store.checkUserWonderkidBreakthroughs()

        XCTAssertNotNil(store.wonderkidWatchlist[player.id], "A user-club breakout should land in the same watchlist item 4's AI system uses")
        XCTAssertTrue(store.news.contains { $0.title == "Breakout season" && $0.body.contains(player.name) })

        // A season later, bump the rating and let the existing (unmodified)
        // follow-up checker resolve it — proving the reuse actually works
        // end-to-end, not just that an entry was inserted.
        store.season += 1
        store.clubs[store.userClubIndex].players[0].rating = 80
        store.simulateWorldEvents()

        XCTAssertNil(store.wonderkidWatchlist[player.id], "The follow-up should resolve and remove the entry")
        XCTAssertTrue(store.news.contains { $0.title == "Star in the making" && $0.body.contains(player.name) })
    }

    func testUserWonderkidBreakthroughDoesNotFireForAnEstablishedPlayer() async {
        let store = await freshStore()
        var player = store.clubs[store.userClubIndex].players[0]
        player.age = 28
        player.apps = 20
        player.rating = 75
        store.clubs[store.userClubIndex].players[0] = player

        store.checkUserWonderkidBreakthroughs()

        XCTAssertNil(store.wonderkidWatchlist[player.id])
    }

    // MARK: - Retirement fix

    func testRetirementNewsNowCarriesThePlayerReference() async {
        let store = await freshStore()
        var retiree = store.clubs[store.userClubIndex].players[0]
        retiree.age = 39 // guarantees retirement this rollover
        retiree.rating = 70
        store.clubs[store.userClubIndex].players[0] = retiree

        store.progressSquads()

        guard let retirementNews = store.news.first(where: { $0.title == "Retirement" && $0.body.contains(retiree.name) }) else {
            return XCTFail("Expected a Retirement news item mentioning \(retiree.name)")
        }
        XCTAssertEqual(retirementNews.playerName, retiree.name,
                       "Passing player: unlocks the bespoke retirement newspaper templates, previously dead code for the user's own retirees")
    }

    // MARK: - Captaincy moments

    func testCaptaincyChangeFiresExactlyOneNewCaptainStoryAndIsNotDoubleFired() async {
        let store = await freshStore()
        // The initial auto-assignment on a fresh save is squad setup, not a story.
        XCTAssertFalse(store.news.contains { $0.title == "New captain" })
        guard let newCaptain = store.userClub.players.first(where: { $0.id != store.captainID }) else {
            return XCTFail("Expected at least two squad players")
        }

        store.setCaptain(newCaptain)
        XCTAssertEqual(store.news.filter { $0.title == "New captain" }.count, 1)

        store.setCaptain(newCaptain)
        XCTAssertEqual(store.news.filter { $0.title == "New captain" }.count, 1,
                       "Re-confirming the same captain shouldn't fire another story")
    }
}
