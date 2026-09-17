import XCTest
@testable import Retro_Season_Manager

/// Focused coverage for the Legends Balance economy rebalance: the pounds
/// scale on every reward/cost surface, the one-time legacy-save migration,
/// and football-money formatting including accessibility text.
@MainActor
final class LegendsBalanceEconomyTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.facilityLevels = [:]
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.signAllOwnedCardsForTesting()
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        store.profile.coins = 0
        store.profile.packTokens = 0
        store.profile.managerLevel = 1
        store.profile.managerXP = 0
        // LegendsStore() loads whatever is on disk (e.g. from a manual
        // Simulator run) — season/division state leaks into match tests
        // otherwise, so reset it exactly like LegendsMatchTests does.
        store.profile.division = .division10
        store.profile.divisionWins = 0
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = 0
        // Pre-complete every challenge so the match-reward math below is
        // exact: `recordMatchResult` never re-grants a completed challenge.
        store.profile.completedPermanentChallengeIDs = Set(LegendsChallengeDatabase.all.filter { $0.cadence == .permanent }.map(\.id))
        store.profile.completedDailyChallengeIDs = Set(LegendsChallengeDatabase.all.filter { $0.cadence == .daily }.map(\.id))
        store.profile.completedWeeklyChallengeIDs = Set(LegendsChallengeDatabase.all.filter { $0.cadence == .weekly }.map(\.id))
        store.profile.lastDailyReset = Date()
        store.profile.lastWeeklyReset = Date()
        return store
    }

    // MARK: - Scale

    func testStarterProfileUsesThePoundsScale() {
        let starter = LegendsProfile.starter()
        XCTAssertEqual(starter.coins, 5_000_000, "A new club starts with £5,000,000 Balance")
        XCTAssertEqual(starter.packTokens, 3, "Starting pack tokens are unchanged by the Balance rebalance")
        XCTAssertEqual(starter.balanceEconomyVersion, LegendsBalance.currentEconomyVersion,
                       "New profiles are created directly in the current economy")
    }

    func testMatchRewardsUseThePoundsScale() async {
        let store = await freshStore()

        let win = store.applyMatchOutcome(opponent: LegendsOpponent(name: "Rival XI", rating: 50),
                                          result: LegendsMatchEngine.Result(teamGoals: 2, opponentGoals: 0))
        XCTAssertEqual(win.coinsEarned, 500_000, "A win pays £500,000")
        XCTAssertEqual(store.profile.coins, 500_000, "Only the base match reward lands — challenges are pre-completed in this fixture")

        let draw = store.applyMatchOutcome(opponent: LegendsOpponent(name: "Rival XI", rating: 50),
                                           result: LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 1))
        XCTAssertEqual(draw.coinsEarned, 200_000, "A draw pays £200,000")

        let loss = store.applyMatchOutcome(opponent: LegendsOpponent(name: "Rival XI", rating: 50),
                                           result: LegendsMatchEngine.Result(teamGoals: 0, opponentGoals: 2))
        XCTAssertEqual(loss.coinsEarned, 100_000, "A loss pays £100,000")
        XCTAssertEqual(store.profile.coins, 800_000)
    }

    func testSeasonRewardsUseThePoundsScale() {
        XCTAssertEqual(LegendsStore.seasonReward(for: .champion).coins, 3_000_000)
        XCTAssertEqual(LegendsStore.seasonReward(for: .promoted).coins, 2_200_000)
        XCTAssertEqual(LegendsStore.seasonReward(for: .retained).coins, 1_000_000)
        XCTAssertEqual(LegendsStore.seasonReward(for: .relegated).coins, 500_000)
        let tokenRewards: [(LegendsDivisionSeasonOutcome, Int)] = [(.champion, 3), (.promoted, 2), (.retained, 1), (.relegated, 0)]
        for (outcome, tokens) in tokenRewards {
            XCTAssertEqual(LegendsStore.seasonReward(for: outcome).tokens, tokens,
                           "\(outcome.rawValue) keeps its accepted season token reward")
        }
    }

    func testChallengeBalanceRewardsUseThePoundsScale() {
        for challenge in LegendsChallengeDatabase.all {
            if challenge.coinReward > 0 {
                XCTAssertGreaterThanOrEqual(challenge.coinReward, 300_000,
                                            "\(challenge.id) pays at least a £300,000-style professional reward")
                XCTAssertEqual(challenge.coinReward % 100_000, 0,
                               "\(challenge.id) stays on the accepted reward grid at the pounds scale")
            } else {
                XCTAssertEqual(challenge.coinReward, 0)
            }
            XCTAssertGreaterThanOrEqual(challenge.tokenReward, 0)
        }
        XCTAssertEqual(LegendsChallengeDatabase.all.first { $0.id == "first-win" }?.coinReward, 1_000_000)
        XCTAssertEqual(LegendsChallengeDatabase.all.first { $0.id == "streak-5" }?.coinReward, 4_000_000)
    }

    func testEveryFacilityUpgradeCostUsesThePoundsScale() {
        let expectedBase: [LegendsFacilityKind: Int] = [
            .trainingCentre: 1_000_000, .youthAcademy: 1_200_000,
            .scoutingNetwork: 1_400_000, .clubStadium: 1_600_000,
        ]
        for kind in LegendsFacilityKind.allCases {
            for level in 0..<kind.maxLevel {
                let cost = kind.upgradeCost(at: level)
                XCTAssertEqual(cost, expectedBase[kind]! * (level + 1),
                               "\(kind.displayName) level \(level) → \(level + 1) costs £\((expectedBase[kind]! * (level + 1))/1_000_000)M")
                XCTAssertGreaterThanOrEqual(cost ?? 0, 1_000_000,
                                            "\(kind.displayName) costs millions at every level")
            }
            XCTAssertNil(kind.upgradeCost(at: kind.maxLevel))
        }
        // The accepted relative cost order is preserved.
        XCTAssertLessThan(LegendsFacilityKind.trainingCentre.baseUpgradeCost, LegendsFacilityKind.youthAcademy.baseUpgradeCost)
        XCTAssertLessThan(LegendsFacilityKind.youthAcademy.baseUpgradeCost, LegendsFacilityKind.scoutingNetwork.baseUpgradeCost)
        XCTAssertLessThan(LegendsFacilityKind.scoutingNetwork.baseUpgradeCost, LegendsFacilityKind.clubStadium.baseUpgradeCost)
    }

    // MARK: - Transactions

    func testFacilityUpgradeDeductsExactBalanceOnceAndLeavesTokensAlone() async {
        let store = await freshStore()
        store.profile.coins = 5_000_000
        store.profile.packTokens = 12

        guard case .upgraded(.trainingCentre, from: 0, to: 1, cost: 1_000_000) = store.upgradeFacility(.trainingCentre) else {
            return XCTFail("The first Training Centre upgrade should cost exactly £1,000,000")
        }
        XCTAssertEqual(store.profile.coins, 4_000_000, "Exactly £1,000,000 is deducted once")
        XCTAssertEqual(store.profile.packTokens, 12, "Pack tokens are never touched by facility upgrades")
    }

    func testInsufficientBalanceRejectsUpgradeAndKeepsBothCurrencies() async {
        let store = await freshStore()
        store.profile.coins = 999_999
        store.profile.packTokens = 4

        let result = store.upgradeFacility(.clubStadium)
        XCTAssertEqual(result, .insufficientBalance(required: 1_600_000, available: 999_999))
        XCTAssertEqual(store.profile.coins, 999_999)
        XCTAssertEqual(store.profile.packTokens, 4)
        XCTAssertEqual(store.facilityLevel(.clubStadium), 0)
    }

    func testPacksRemainTokenOnlyAcrossTheRebalance() async throws {
        let store = await freshStore()
        let bronze = LegendsPackDatabase.all.first { $0.id == "bronze" }!
        store.profile.packTokens = bronze.cost + 2
        store.profile.coins = 7_000_000

        let opened = try store.openPack(bronze)
        XCTAssertFalse(opened.isEmpty, "Token-funded pack opening still works")
        XCTAssertEqual(store.profile.packTokens, bronze.cost + 2 - bronze.cost, "Only tokens are spent")
        XCTAssertEqual(store.profile.coins, 7_000_000, "Balance is never spent on packs")
    }

    // MARK: - Migration

    private func legacyJSON(coins: Int) -> Data {
        """
        {
            "clubName": "Legacy FC", "crestShort": "LFC", "crestColorRGB": [0.1, 0.2, 0.3],
            "managerLevel": 2, "managerXP": 40, "coins": \(coins), "packTokens": 5,
            "division": 8, "teamRating": 62
        }
        """.data(using: .utf8)!
    }

    func testLegacySaveMigratesBalanceExactlyOnce() throws {
        let profile = try JSONDecoder().decode(LegendsProfile.self, from: legacyJSON(coins: 300))
        XCTAssertEqual(profile.coins, 3_000_000, "Legacy unit credits convert to the pounds scale")
        XCTAssertEqual(profile.balanceEconomyVersion, LegendsBalance.currentEconomyVersion)
        XCTAssertEqual(profile.packTokens, 5, "Pack tokens are preserved unchanged")

        let roundTripped = try JSONDecoder().decode(LegendsProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(roundTripped.coins, 3_000_000, "Re-decoding a migrated save must not multiply Balance again")
        XCTAssertEqual(roundTripped.balanceEconomyVersion, LegendsBalance.currentEconomyVersion)
    }

    func testRepeatedEncodeDecodeCyclesNeverMultiplyBalance() throws {
        var profile = try JSONDecoder().decode(LegendsProfile.self, from: legacyJSON(coins: 120))
        XCTAssertEqual(profile.coins, 1_200_000)

        for cycle in 1...5 {
            let data = try JSONEncoder().encode(profile)
            profile = try JSONDecoder().decode(LegendsProfile.self, from: data)
            XCTAssertEqual(profile.coins, 1_200_000, "Cycle \(cycle) must leave the migrated Balance unchanged")
        }
    }

    func testAlreadyMigratedSaveDecodesWithoutRescaling() throws {
        let migrated = LegendsProfile.starter()
        let data = try JSONEncoder().encode(migrated)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertEqual(decoded.coins, 5_000_000, "A save already carrying the marker decodes at face value")
    }

    func testNewProfileRoundTripKeepsScaleAndTokens() throws {
        let starter = LegendsProfile.starter()
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: JSONEncoder().encode(starter))
        XCTAssertEqual(decoded.coins, 5_000_000)
        XCTAssertEqual(decoded.packTokens, 3)
        XCTAssertEqual(decoded.balanceEconomyVersion, LegendsBalance.currentEconomyVersion)
    }

    // MARK: - Formatting

    func testFullFormattingUsesGroupedPounds() {
        XCTAssertEqual(LegendsBalance.full(850_000), "£850,000")
        XCTAssertEqual(LegendsBalance.full(1_000_000), "£1,000,000")
        XCTAssertEqual(LegendsBalance.full(12_500_000), "£12,500,000")
        XCTAssertEqual(LegendsBalance.full(0), "£0")
    }

    func testCompactFormattingUsesFootballMoney() {
        XCTAssertEqual(LegendsBalance.compact(850_000), "£850,000", "Sub-million amounts stay fully grouped")
        XCTAssertEqual(LegendsBalance.compact(1_000_000), "£1M")
        XCTAssertEqual(LegendsBalance.compact(1_200_000), "£1.2M")
        XCTAssertEqual(LegendsBalance.compact(12_500_000), "£12.5M")
        XCTAssertEqual(LegendsBalance.compact(4_000_000), "£4M")
    }

    func testAccessibilityTextAnnouncesTheFullMonetaryValue() {
        XCTAssertEqual(LegendsBalance.spoken(1_000_000), "£1,000,000")
        XCTAssertEqual(LegendsBalance.spoken(300_000), "£300,000")
        XCTAssertNotEqual(LegendsBalance.spoken(1_200_000), LegendsBalance.compact(1_200_000),
                          "Accessibility uses the full value where the display may be compact")
    }
}
