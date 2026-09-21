//
//  InboxFixtureTests.swift
//  Retro Season ManagerTests
//
//  Verifies the deterministic Career Inbox fixture against the real
//  store: ordering, category spread, the read/unread mix, the long
//  article and the player-context story — plus that the store's
//  authoritative read-state queries (the exact ones the redesigned
//  Inbox's filters and summary render) move only through markNewsRead
//  and markAllNewsRead.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class InboxFixtureTests: XCTestCase {

    func testInboxFixtureProvidesDeterministicCategoriesAndReadMix() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerNavigationFixtureForDebug()

        // The seven fixture items sit newest-first at the very top of the
        // feed; engine-generated stories (welcome, match events — variable
        // in count) land beneath them as read history.
        let expectedOrder = ["DETERMINISTIC LONG ARTICLE",
                             "Title race tightening across Europe",
                             "Star signs contract extension",
                             "Season opener ends level",
                             "Transfer window opens",
                             "Medical report filed",
                             "Board reviews season objectives"]
        XCTAssertGreaterThanOrEqual(store.news.count, expectedOrder.count,
                                    "Fixture should seed the full deterministic block")
        XCTAssertEqual(store.news.prefix(expectedOrder.count).map { $0.title }, expectedOrder,
                       "Newest-first ordering must match addNews's contract")

        // Every supported category folder is represented by the fixture
        // block (ALL is a view filter, not a filing folder).
        let fixtureFolders = Set(store.news.prefix(expectedOrder.count).map { $0.category.folder })
        XCTAssertEqual(fixtureFolders, [.results, .transfers, .board, .club, .world],
                       "Fixture block should cover every category folder")

        // Exactly three unread — the long article, the world story and the
        // player story — whatever the engine generated this run.
        XCTAssertEqual(store.unreadNewsIDs.count, 3, "Fixture should leave exactly three unread")
        let unreadTitles = Set(store.news.filter { store.unreadNewsIDs.contains($0.id) }.map { $0.title })
        XCTAssertEqual(unreadTitles, ["DETERMINISTIC LONG ARTICLE",
                                      "Title race tightening across Europe",
                                      "Star signs contract extension"])

        // The long article is genuinely long enough to need scrolling.
        let longArticle = store.news.first { $0.title == "DETERMINISTIC LONG ARTICLE" }
        XCTAssertGreaterThan(longArticle?.body.count ?? 0, 1_500,
                             "The long article must exceed one compact screen")

        // The player-context story carries a real squad player snapshot.
        let playerStory = store.news.first { $0.title == "Star signs contract extension" }
        XCTAssertNotNil(playerStory?.playerName, "Player story should carry the player snapshot")
        XCTAssertNotNil(playerStory?.clubName, "Player story should carry the club context")
        XCTAssertTrue(store.clubs[store.userClubIndex].players.contains { $0.name == playerStory?.playerName },
                      "The story's player must exist in the user's squad for the profile tag")
    }

    func testReadStateQueriesMoveOnlyThroughAuthoritativeMechanisms() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerNavigationFixtureForDebug()

        guard let item = store.news.first(where: { store.unreadNewsIDs.contains($0.id) }) else {
            return XCTFail("Fixture should start with unread items")
        }

        // The UNREAD filter's exact query.
        var unreadItems = store.news.filter { store.unreadNewsIDs.contains($0.id) }
        XCTAssertEqual(unreadItems.count, 3)

        // markNewsRead is the only single-message read path.
        store.markNewsRead(item)
        unreadItems = store.news.filter { store.unreadNewsIDs.contains($0.id) }
        XCTAssertEqual(unreadItems.count, 2, "markNewsRead should remove exactly the read item")

        // markAllNewsRead is the only bulk read path.
        store.markAllNewsRead()
        XCTAssertTrue(store.unreadNewsIDs.isEmpty, "markAllNewsRead should clear the unread set")

        // Filtering an empty unread set yields the caught-up empty state
        // (the view renders its NO-UNREAD copy for this exact result).
        XCTAssertEqual(store.news.filter { store.unreadNewsIDs.contains($0.id) }.count, 0)
    }

    func testCategoryFoldersMatchNewsCategoriesExactly() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerNavigationFixtureForDebug()

        // The folder filter's exact query: a category can only ever file
        // under one folder, and the fixture exercises all of them.
        for item in store.news {
            switch item.category {
            case .result: XCTAssertEqual(item.category.folder, .results)
            case .transfer, .offer: XCTAssertEqual(item.category.folder, .transfers)
            case .board: XCTAssertEqual(item.category.folder, .board)
            case .injury, .info: XCTAssertEqual(item.category.folder, .club)
            case .world: XCTAssertEqual(item.category.folder, .world)
            }
        }
    }
}
