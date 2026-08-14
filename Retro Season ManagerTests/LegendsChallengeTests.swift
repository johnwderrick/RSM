//
//  LegendsChallengeTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 8 challenge catalog and LegendsStore+Challenges'
//  progress/reward/cadence-reset logic.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsChallengeDatabaseTests: XCTestCase {
    func testEveryChallengeHasAUniqueID() {
        let ids = LegendsChallengeDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate challenge IDs")
    }

    func testEveryChallengeHasNonEmptyText() {
        for challenge in LegendsChallengeDatabase.all {
            XCTAssertFalse(challenge.title.isEmpty, "\(challenge.id) has an empty title")
            XCTAssertFalse(challenge.description.isEmpty, "\(challenge.id) has an empty description")
        }
    }

    func testEveryChallengeOffersAtLeastOneReward() {
        for challenge in LegendsChallengeDatabase.all {
            XCTAssertTrue(challenge.coinReward > 0 || challenge.tokenReward > 0, "\(challenge.id) grants nothing")
        }
    }

    /// Regression guard: the "core XI" challenges (One Flag/One Era/
    /// Historic XI) require LegendsStore.xiShareThreshold players to
    /// share a nation/era/club. If the card database ever shrinks, or
    /// the threshold is raised, this catches the challenge silently
    /// becoming impossible to complete — exactly the bug this test was
    /// added to catch: a literal "all 11" version of these challenges
    /// was unreachable, since no nation/era/club has 11 cards.
    func testXIShareChallengesAreAchievableWithTheCurrentDatabase() {
        func maxCount<T: Hashable>(_ key: (LegendsCard) -> T) -> Int {
            Dictionary(grouping: LegendsCardDatabase.all, by: key).map(\.value.count).max() ?? 0
        }
        XCTAssertGreaterThanOrEqual(maxCount(\.nation), LegendsStore.xiShareThreshold)
        XCTAssertGreaterThanOrEqual(maxCount(\.era), LegendsStore.xiShareThreshold)
        XCTAssertGreaterThanOrEqual(maxCount(\.club), LegendsStore.xiShareThreshold)
    }
}

@MainActor
final class LegendsStoreChallengeTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.coins = 0
        store.profile.packTokens = 0
        store.profile.totalWins = 0
        store.profile.currentWinStreak = 0
        store.profile.matchesToday = 0
        store.profile.winsToday = 0
        store.profile.winsThisWeek = 0
        store.profile.goalsThisWeek = 0
        store.profile.lastDailyReset = Date()
        store.profile.lastWeeklyReset = Date()
        store.profile.completedPermanentChallengeIDs = []
        store.profile.completedDailyChallengeIDs = []
        store.profile.completedWeeklyChallengeIDs = []
        return store
    }

    private func winSummary(teamGoals: Int = 2, opponentGoals: Int = 0, promoted: Bool = false) -> LegendsMatchOutcomeSummary {
        LegendsMatchOutcomeSummary(opponent: LegendsOpponent(name: "Rival XI", rating: 50),
                                    result: LegendsMatchEngine.Result(teamGoals: teamGoals, opponentGoals: opponentGoals),
                                    coinsEarned: 50, tokensEarned: 1, xpEarned: 30,
                                    leveledUp: false, promoted: promoted, newDivision: .division10)
    }

    private func lossSummary() -> LegendsMatchOutcomeSummary {
        LegendsMatchOutcomeSummary(opponent: LegendsOpponent(name: "Rival XI", rating: 90),
                                    result: LegendsMatchEngine.Result(teamGoals: 0, opponentGoals: 2),
                                    coinsEarned: 10, tokensEarned: 0, xpEarned: 5,
                                    leveledUp: false, promoted: false, newDivision: .division10)
    }

    func testFirstWinChallengeGrantsExactlyOnce() async {
        let store = await freshStore()
        let firstWin = LegendsChallengeDatabase.all.first { $0.id == "first-win" }!

        let completions1 = store.recordMatchResult(winSummary())
        XCTAssertTrue(completions1.contains { $0.challenge.id == "first-win" })
        XCTAssertTrue(store.isCompleted(firstWin))
        let coinsAfterFirst = store.profile.coins

        let completions2 = store.recordMatchResult(winSummary())
        XCTAssertFalse(completions2.contains { $0.challenge.id == "first-win" }, "Permanent challenge should not re-grant")
        XCTAssertEqual(store.profile.coins, coinsAfterFirst, "No second reward for an already-completed permanent challenge")
    }

    func testCleanSheetChallengeRequiresNoGoalsConceded() async {
        let store = await freshStore()
        _ = store.recordMatchResult(winSummary(teamGoals: 1, opponentGoals: 1))
        let cleanSheet = LegendsChallengeDatabase.all.first { $0.id == "clean-sheet" }!
        XCTAssertFalse(store.isCompleted(cleanSheet), "1-1 draw concedes a goal — shouldn't count as a clean sheet")

        let completions = store.recordMatchResult(winSummary(teamGoals: 2, opponentGoals: 0))
        XCTAssertTrue(completions.contains { $0.challenge.id == "clean-sheet" })
    }

    func testHatTrickChallengeNeedsThreeGoalsInOneMatch() async {
        let store = await freshStore()
        _ = store.recordMatchResult(winSummary(teamGoals: 2, opponentGoals: 0))
        let hatTrick = LegendsChallengeDatabase.all.first { $0.id == "hat-trick" }!
        XCTAssertFalse(store.isCompleted(hatTrick))

        let completions = store.recordMatchResult(winSummary(teamGoals: 3, opponentGoals: 1))
        XCTAssertTrue(completions.contains { $0.challenge.id == "hat-trick" })
    }

    func testWinStreakBreaksOnALoss() async {
        let store = await freshStore()
        _ = store.recordMatchResult(winSummary())
        _ = store.recordMatchResult(winSummary())
        XCTAssertEqual(store.profile.currentWinStreak, 2)
        _ = store.recordMatchResult(lossSummary())
        XCTAssertEqual(store.profile.currentWinStreak, 0)

        _ = store.recordMatchResult(winSummary())
        _ = store.recordMatchResult(winSummary())
        let completions = store.recordMatchResult(winSummary())
        XCTAssertEqual(store.profile.currentWinStreak, 3)
        XCTAssertTrue(completions.contains { $0.challenge.id == "streak-3" })
    }

    func testCoreXIChallengeCompletesWhenEnoughShareANation() async {
        let store = await freshStore()
        let frenchCards = LegendsCardDatabase.all.filter { $0.nation == "France" }
        XCTAssertGreaterThanOrEqual(frenchCards.count, LegendsStore.xiShareThreshold)
        let others = LegendsCardDatabase.all.filter { $0.nation != "France" }
        let slots = store.startingXISlots
        for i in 0..<slots.count {
            let card = i < frenchCards.count ? frenchCards[i] : others[i - frenchCards.count]
            store.assign(cardID: card.id, toXISlot: i)
        }
        let completions = store.recordMatchResult(winSummary())
        XCTAssertTrue(completions.contains { $0.challenge.id == "one-flag" })
    }

    func testDailyCountersResetAfterADayRollsOver() async {
        let store = await freshStore()
        store.profile.lastDailyReset = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.profile.matchesToday = 5
        store.profile.winsToday = 3
        store.profile.completedDailyChallengeIDs = ["daily-match"]

        store.refreshChallengeCadences()

        XCTAssertEqual(store.profile.matchesToday, 0)
        XCTAssertEqual(store.profile.winsToday, 0)
        XCTAssertTrue(store.profile.completedDailyChallengeIDs.isEmpty)
        XCTAssertTrue(Calendar.current.isDateInToday(store.profile.lastDailyReset))
    }

    func testDailyCountersSurviveWithinTheSameDay() async {
        let store = await freshStore()
        store.profile.lastDailyReset = Date()
        store.profile.matchesToday = 2

        store.refreshChallengeCadences()

        XCTAssertEqual(store.profile.matchesToday, 2, "Same-day refresh shouldn't reset progress")
    }

    func testWeeklyCountersResetAfterAWeekRollsOver() async {
        let store = await freshStore()
        store.profile.lastWeeklyReset = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        store.profile.winsThisWeek = 4
        store.profile.goalsThisWeek = 12
        store.profile.completedWeeklyChallengeIDs = ["weekly-wins"]

        store.refreshChallengeCadences()

        XCTAssertEqual(store.profile.winsThisWeek, 0)
        XCTAssertEqual(store.profile.goalsThisWeek, 0)
        XCTAssertTrue(store.profile.completedWeeklyChallengeIDs.isEmpty)
    }

    func testGetPromotedChallengeUsesTheSummarysPromotedFlag() async {
        let store = await freshStore()
        let notPromoted = store.recordMatchResult(winSummary(promoted: false))
        XCTAssertFalse(notPromoted.contains { $0.challenge.id == "promoted" })

        let promoted = store.recordMatchResult(winSummary(promoted: true))
        XCTAssertTrue(promoted.contains { $0.challenge.id == "promoted" })
    }
}
