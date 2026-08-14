import XCTest
@testable import Retro_Season_Manager

/// `classifyStory`/`bespokeDraft`/`genericDraft` are `fileprivate` to
/// `GameStore+Newspaper.swift`, so `@testable import` can't reach them
/// directly — even from this file, `fileprivate` stays scoped to the
/// declaring file, unlike `private`/`internal`. `generateNewspaper(...)`,
/// the function that calls them, is the actual public (internal) entry
/// point, and exercises exactly the same classification logic — so these
/// tests go through it rather than loosening access purely for testing.
final class NewspaperClassifierTests: XCTestCase {
    private func setupStore() async -> GameStore {
        let store = await makeTestStore()
        await MainActor.run {
            store.clubs = [Club(name: "Test Club", shortName: "TST", players: [])]
            store.userClubIndex = 0
        }
        return store
    }

    func testRoutineResultStoryPrintsNoFrontPage() async {
        // .result stories are `.minor` by default in the generic
        // classifier — routine housekeeping, not news.
        let store = await setupStore()
        let paper = await MainActor.run {
            store.generateNewspaper(category: .result, title: "Match report",
                                    body: "Test Club won 2-1.", player: nil, clubName: nil)
        }
        XCTAssertNil(paper)
    }

    func testBoardStoryAlwaysPrintsATNotableLocalFrontPage() async {
        let store = await setupStore()
        let paper = await MainActor.run {
            store.generateNewspaper(category: .board, title: "New contract",
                                    body: "The board have extended your deal.", player: nil, clubName: nil)
        }
        XCTAssertEqual(paper?.outlet, .local)
        XCTAssertEqual(paper?.importance, .notable)
    }

    func testPromotionIsABespokeHistoricNationalFrontPage() async {
        // A recognized bespoke title ("Promotion!") should route through
        // `bespokeDraft`, not fall through to the generic classifier —
        // national outlet, historic importance, not just "notable".
        let store = await setupStore()
        let paper = await MainActor.run {
            store.generateNewspaper(category: .board, title: "Promotion!",
                                    body: "Test Club have won promotion.", player: nil, clubName: nil)
        }
        XCTAssertEqual(paper?.outlet, .national)
        XCTAssertEqual(paper?.importance, .historic)
        XCTAssertTrue(paper?.headline.contains("TEST CLUB") ?? false)
    }

    func testGiantKillingExtractsTheOpponentNameIntoTheHeadline() async {
        let store = await setupStore()
        let paper = await MainActor.run {
            store.generateNewspaper(category: .result, title: "Giant-killing!",
                                    body: "much-fancied Rival FC turns heads after a shock exit.",
                                    player: nil, clubName: nil)
        }
        XCTAssertEqual(paper?.importance, .historic)
        XCTAssertTrue(paper?.headline.contains("RIVAL FC") ?? false, paper?.headline ?? "nil")
    }

    func testEuropeanWorldNewsUsesTheEuropeanOutlet() async {
        let store = await setupStore()
        let paper = await MainActor.run {
            store.generateNewspaper(category: .world, title: "European draw made",
                                    body: "The \(GameStore.euroName) group stage draw has been made.",
                                    player: nil, clubName: nil)
        }
        XCTAssertEqual(paper?.outlet, .european)
    }
}
