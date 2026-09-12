//
//  LegendsManagersAndStadiumsTests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 9 Manager/Stadium catalogs and their integration
//  with match strength, chemistry, and Play Match's reward roll.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsManagersAndStadiumsDatabaseTests: XCTestCase {
    func testEveryManagerHasAUniqueID() {
        let ids = LegendsManagerDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryStadiumHasAUniqueID() {
        let ids = LegendsStadiumDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    /// Regression guard: a manager's affinityClub only ever does
    /// anything if some card in the database actually belongs to that
    /// club — same class of bug as the Phase 8 "unreachable challenge"
    /// catch.
    func testEveryManagerAffinityClubExistsInTheCardDatabase() {
        let realClubs = Set(LegendsCardDatabase.all.map(\.club))
        for manager in LegendsManagerDatabase.all {
            XCTAssertTrue(realClubs.contains(manager.affinityClub), "\(manager.id)'s affinity club '\(manager.affinityClub)' has no cards")
        }
    }

    func testEveryStadiumClubExistsInTheCardDatabase() {
        let realClubs = Set(LegendsCardDatabase.all.map(\.club))
        for stadium in LegendsStadiumDatabase.all {
            XCTAssertTrue(realClubs.contains(stadium.club), "\(stadium.id)'s club '\(stadium.club)' has no cards")
        }
    }

    func testEveryBonusIsPositive() {
        for manager in LegendsManagerDatabase.all { XCTAssertGreaterThan(manager.tacticalBonus, 0) }
        for stadium in LegendsStadiumDatabase.all { XCTAssertGreaterThan(stadium.gameplayBonus, 0) }
    }
}

@MainActor
final class LegendsStoreManagersAndStadiumsTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.signAllOwnedCardsForTesting()
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.ownedManagerIDs = []
        store.profile.activeManagerID = nil
        store.profile.ownedStadiumIDs = []
        store.profile.activeStadiumID = nil
        // LegendsStore() loads whatever's actually on disk — the
        // near-certain-win fillStrongXI-style sort below uses
        // effectiveOverall(), which also subtracts an aging penalty, so a
        // real playthrough's cardAgeOffsets otherwise leaks in here.
        store.profile.cardAgeOffsets = [:]
        return store
    }

    func testCannotActivateAnUnownedManager() async {
        let store = await freshStore()
        let manager = LegendsManagerDatabase.all.first!
        store.setActiveManager(manager.id)
        XCTAssertNil(store.profile.activeManagerID)
    }

    func testActivatingAnOwnedManagerSucceeds() async {
        let store = await freshStore()
        let manager = LegendsManagerDatabase.all.first!
        store.profile.ownedManagerIDs.insert(manager.id)
        store.setActiveManager(manager.id)
        XCTAssertEqual(store.profile.activeManagerID, manager.id)
        XCTAssertEqual(store.activeManager?.id, manager.id)
    }

    func testMatchStrengthBonusCombinesManagerAndStadium() async {
        let store = await freshStore()
        XCTAssertEqual(store.matchStrengthBonus, 0)

        let manager = LegendsManagerDatabase.all.first!
        store.profile.ownedManagerIDs.insert(manager.id)
        store.setActiveManager(manager.id)

        let stadium = LegendsStadiumDatabase.all.first!
        store.profile.ownedStadiumIDs.insert(stadium.id)
        store.setActiveStadium(stadium.id)

        XCTAssertEqual(store.matchStrengthBonus, Double(manager.tacticalBonus + stadium.gameplayBonus))
    }

    func testManagerAffinityBoostsChemistryForAMatchingClubCard() async {
        let store = await freshStore()
        let manager = LegendsManagerDatabase.all.first!
        let affinityCard = LegendsCardDatabase.all.first { $0.club == manager.affinityClub }!
        // Use a same-broad-position slot (not necessarily an exact
        // match) so Formation Fit never zeroes this out regardless of
        // the affinity card's specific role.
        let slots = store.startingXISlots
        let slotIndex = slots.firstIndex(of: affinityCard.position) ?? slots.firstIndex { $0.broad == affinityCard.position.broad } ?? 0
        store.assign(cardID: affinityCard.id, toXISlot: slotIndex)

        let starsWithoutManager = store.chemistryStars(forXISlot: slotIndex)

        store.profile.ownedManagerIDs.insert(manager.id)
        store.setActiveManager(manager.id)
        let starsWithManager = store.chemistryStars(forXISlot: slotIndex)

        XCTAssertGreaterThanOrEqual(starsWithManager, starsWithoutManager)
        XCTAssertGreaterThan(starsWithManager, 0, "A lone affinity-club player should get some chemistry credit from their manager")
    }

    func testWinningEnoughMatchesEventuallyGrantsAManagerOrStadium() async {
        let store = await freshStore()
        let slots = store.startingXISlots
        // Only one card per real-ish player at once (LegendsStore+Squad.swift's
        // name-based dedup) — dedupe by name before taking the top N.
        var seenNames = Set<String>()
        let sorted = LegendsCardDatabase.all
            .sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) }
            .filter { seenNames.insert($0.name).inserted }
        for (index, _) in slots.enumerated() {
            store.assign(cardID: sorted[index].id, toXISlot: index)
        }
        store.profile.division = .division10  // weakest opponents, near-certain wins

        var grantedSomething = false
        for _ in 0..<60 {
            guard let summary = store.playMatch() else { break }
            if summary.newManager != nil || summary.newStadium != nil { grantedSomething = true; break }
        }
        XCTAssertTrue(grantedSomething, "Expected at least one Manager/Stadium card within 60 near-certain wins")
    }
}

@MainActor
final class LegendsFacilitiesTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.facilityLevels = [:]
        store.profile.coins = 0
        store.profile.packTokens = 0
        store.profile.ownedManagerIDs = []
        store.profile.activeManagerID = nil
        store.profile.ownedStadiumIDs = []
        store.profile.activeStadiumID = nil
        store.profile.playerCareers = [:]
        store.profile.activatedCardIDs = []
        store.profile.ownedCardIDs = []
        return store
    }

    func testFacilityUpgradeCostsIncreasePredictablyByLevel() {
        for kind in LegendsFacilityKind.allCases {
            XCTAssertEqual(kind.upgradeCost(at: 0), kind.baseUpgradeCost)
            XCTAssertEqual(kind.upgradeCost(at: 1), kind.baseUpgradeCost * 2)
            XCTAssertEqual(kind.upgradeCost(at: 2), kind.baseUpgradeCost * 3)
            XCTAssertNil(kind.upgradeCost(at: kind.maxLevel))
        }
    }

    func testUpgradeDeductsExactBalanceOnceAndNeverSpendsPackTokens() async {
        let store = await freshStore()
        store.profile.coins = 1_000
        store.profile.packTokens = 7

        guard case .upgraded(.trainingCentre, from: 0, to: 1, cost: 100) = store.upgradeFacility(.trainingCentre) else {
            return XCTFail("The first Training Centre upgrade should cost exactly 100 Balance")
        }
        XCTAssertEqual(store.profile.coins, 900)
        XCTAssertEqual(store.profile.packTokens, 7)

        guard case .upgraded(.trainingCentre, from: 1, to: 2, cost: 200) = store.upgradeFacility(.trainingCentre) else {
            return XCTFail("The second Training Centre upgrade should cost exactly 200 Balance")
        }
        XCTAssertEqual(store.profile.coins, 700)
        XCTAssertEqual(store.profile.packTokens, 7)
        XCTAssertEqual(store.facilityLevel(.trainingCentre), 2)
    }

    func testInsufficientBalanceRejectsUpgradeWithoutMutation() async {
        let store = await freshStore()
        let cost = LegendsFacilityKind.clubStadium.upgradeCost(at: 0)!
        store.profile.coins = cost - 1
        store.profile.packTokens = 11

        let result = store.upgradeFacility(.clubStadium)
        XCTAssertEqual(result, .insufficientBalance(required: cost, available: cost - 1))
        XCTAssertEqual(store.profile.coins, cost - 1)
        XCTAssertEqual(store.profile.packTokens, 11)
        XCTAssertEqual(store.facilityLevel(.clubStadium), 0)
    }

    func testMaximumLevelRejectsUpgradeWithoutMutation() async {
        let store = await freshStore()
        store.profile.coins = 99_999
        store.profile.facilityLevels[LegendsFacilityKind.scoutingNetwork.rawValue] = LegendsFacilityKind.scoutingNetwork.maxLevel

        XCTAssertEqual(store.upgradeFacility(.scoutingNetwork), .maximumLevel)
        XCTAssertEqual(store.facilityLevel(.scoutingNetwork), LegendsFacilityKind.scoutingNetwork.maxLevel)
        XCTAssertEqual(store.profile.coins, 99_999)
    }

    func testFacilityLevelsPersistThroughSaveAndLoad() async {
        let store = await Task { @MainActor in LegendsStore() }.value
        let original = store.profile
        defer {
            store.profile = original
            store.persist()
        }

        store.profile.facilityLevels = [:]
        store.profile.coins = 500
        _ = store.upgradeFacility(.trainingCentre)
        _ = store.upgradeFacility(.youthAcademy)

        let reloaded = await Task { @MainActor in LegendsStore() }.value
        XCTAssertEqual(reloaded.profile.facilityLevels[LegendsFacilityKind.trainingCentre.rawValue], 1)
        XCTAssertEqual(reloaded.profile.facilityLevels[LegendsFacilityKind.youthAcademy.rawValue], 1)
        XCTAssertEqual(reloaded.profile.coins, 280)
    }

    func testTrainingCentreBenefitRaisesTrainingProgressMultiplier() async {
        let store = await freshStore()
        XCTAssertEqual(store.trainingCentreProgressMultiplier, 1.0, accuracy: 0.0001)
        store.profile.facilityLevels[LegendsFacilityKind.trainingCentre.rawValue] = 3
        XCTAssertEqual(store.trainingCentreProgressMultiplier, 1.15, accuracy: 0.0001)
    }

    func testYouthAcademyBenefitRaisesPotentialForNewYoungCareers() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first { $0.age <= 23 }!
        let baseline = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        store.profile.facilityLevels[LegendsFacilityKind.youthAcademy.rawValue] = 2
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        store.startCareerIfNeeded(for: card)

        XCTAssertEqual(store.profile.playerCareers[card.id]?.potential, min(99, baseline.potential + 2))
    }

    func testScoutingNetworkBenefitImprovesPotentialReport() async {
        let store = await freshStore()
        let card = LegendsCardDatabase.all.first!
        let career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        store.profile.playerCareers[card.id] = career

        store.profile.facilityLevels[LegendsFacilityKind.scoutingNetwork.rawValue] = 0
        let broadReport = store.scoutingReport(for: card)
        store.profile.facilityLevels[LegendsFacilityKind.scoutingNetwork.rawValue] = 3
        let exactReport = store.scoutingReport(for: card)

        XCTAssertNotEqual(broadReport, exactReport)
        XCTAssertEqual(exactReport, "EST. CEILING \(career.potential)")
    }

    func testClubStadiumBenefitIsAddedOnlyForTheUserHomeFixture() async {
        let store = await freshStore()
        store.profile.facilityLevels[LegendsFacilityKind.clubStadium.rawValue] = 4
        store.ensureDivisionSchedule()
        let homeFixture = store.profile.divisionSchedule.first { $0.homeTeamID == store.profile.clubName }!
        let awayFixture = store.profile.divisionSchedule.first { $0.awayTeamID == store.profile.clubName }!

        let homeOpponent = LegendsOpponent(name: homeFixture.awayTeamID, rating: 60, fixtureID: homeFixture.id)
        let awayOpponent = LegendsOpponent(name: awayFixture.homeTeamID, rating: 60, fixtureID: awayFixture.id)
        let unscheduledOpponent = LegendsOpponent(name: "Unscheduled Rival", rating: 60)

        XCTAssertEqual(store.matchStrengthBonus(for: homeOpponent), 4)
        XCTAssertEqual(store.matchStrengthBonus(for: awayOpponent), 0)
        XCTAssertEqual(store.matchStrengthBonus(for: unscheduledOpponent), 0)
        XCTAssertEqual(store.clubStadiumMatchStrengthBonus, 4,
                       "The facility value itself remains available; fixture context decides whether it applies")
    }

    func testInstantAndLivePathsUseTheSameHomeFixtureBonusRule() async {
        let store = await freshStore()
        store.profile.facilityLevels[LegendsFacilityKind.clubStadium.rawValue] = 3
        store.ensureDivisionSchedule()
        let homeFixture = store.profile.divisionSchedule.first { $0.homeTeamID == store.profile.clubName }!
        let awayFixture = store.profile.divisionSchedule.first { $0.awayTeamID == store.profile.clubName }!

        let homeOpponent = LegendsOpponent(name: homeFixture.awayTeamID, rating: 60, fixtureID: homeFixture.id)
        let awayOpponent = LegendsOpponent(name: awayFixture.homeTeamID, rating: 60, fixtureID: awayFixture.id)

        let homeLive = LegendsLiveMatch(store: store, opponent: homeOpponent, rng: SeededGenerator(seed: "facility-home"))
        let awayLive = LegendsLiveMatch(store: store, opponent: awayOpponent, rng: SeededGenerator(seed: "facility-away"))
        XCTAssertEqual(homeLive.appliedMatchStrengthBonus, store.matchChemistryBonus(for: homeOpponent))
        XCTAssertEqual(awayLive.appliedMatchStrengthBonus, store.matchChemistryBonus(for: awayOpponent))

        XCTAssertEqual(store.matchChemistryBonus(for: homeOpponent) - store.matchChemistryBonus(for: awayOpponent), 3)
        XCTAssertEqual(store.matchChemistryBonus(for: LegendsOpponent(name: "Fallback", rating: 60)) - Double(store.totalChemistry) * 0.3, 0)
    }

    func testScoutingNetworkMaximumLevelIsThreeAndHigherSavedValuesClamp() async {
        let store = await freshStore()
        XCTAssertEqual(LegendsFacilityKind.scoutingNetwork.maxLevel, 3)
        store.profile.facilityLevels[LegendsFacilityKind.scoutingNetwork.rawValue] = 99
        XCTAssertEqual(store.facilityLevel(.scoutingNetwork), 3)
        XCTAssertNil(LegendsFacilityKind.scoutingNetwork.upgradeCost(at: 3))
        XCTAssertEqual(store.upgradeFacility(.scoutingNetwork), .maximumLevel)
    }

    func testSavedFacilityLevelsClampAgainstEachFacilityMaximum() throws {
        let payload: [String: Any] = [
            "clubName": "Clamp FC", "crestShort": "CLP", "crestColorRGB": [0.1, 0.2, 0.3],
            "managerLevel": 1, "managerXP": 0, "coins": 0, "packTokens": 0,
            "division": 10, "teamRating": 0,
            "facilityLevels": [
                LegendsFacilityKind.trainingCentre.rawValue: 99,
                LegendsFacilityKind.youthAcademy.rawValue: -4,
                LegendsFacilityKind.scoutingNetwork.rawValue: 99,
                LegendsFacilityKind.clubStadium.rawValue: 99,
                "unknownFacility": 7
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let profile = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertEqual(profile.facilityLevels[LegendsFacilityKind.trainingCentre.rawValue], 5)
        XCTAssertEqual(profile.facilityLevels[LegendsFacilityKind.youthAcademy.rawValue], 0)
        XCTAssertEqual(profile.facilityLevels[LegendsFacilityKind.scoutingNetwork.rawValue], 3)
        XCTAssertEqual(profile.facilityLevels[LegendsFacilityKind.clubStadium.rawValue], 5)
        XCTAssertNil(profile.facilityLevels["unknownFacility"])
    }
}
