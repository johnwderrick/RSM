//
//  LegendsPlayerDetailStateTests.swift
//  Retro Season ManagerTests
//
//  Focused coverage for the redesigned player-detail presentation state:
//  every fact the detail screen reads comes from authoritative store data,
//  so these tests pin the lifecycle/status derivation, duplicate progress,
//  final-season flagging and identity resolution the screen presents.
//  Presentation styling is covered by the UI test; nothing here mutates
//  progression rules.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsPlayerDetailStateTests: XCTestCase {

    /// A fresh store loads the shared on-disk save (xcodebuild test is not
    /// sandboxed per-test), so every test resets the profile to a known
    /// starter shape before arranging its own state.
    private func makeStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        store.profile.ownedPlayerRecords = [:]
        store.profile.playerCareers = [:]
        store.profile.legendsHall = []
        return store
    }

    private func card(_ id: String) -> LegendsCard {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }) else {
            XCTFail("Missing card \(id)")
            return LegendsCardDatabase.all[0]
        }
        return card
    }

    // MARK: - Lifecycle states the detail screen presents

    func testLifecycleStatesCoverEveryDetailBranch() async throws {
        let store = await makeStore()
        let unsigned = card("maldinho-9596")
        store.profile.ownedCardIDs.insert(unsigned.id)

        // Owned-but-unsigned: detail shows UNSIGNED with a frozen age.
        XCTAssertTrue(store.isUnsigned(unsigned))
        XCTAssertFalse(store.isSigned(unsigned))
        XCTAssertEqual(store.effectiveAge(for: unsigned), unsigned.age)

        // Not-owned: detail shows the NOT OWNED branch.
        let notOwned = card("kahnwald-0001")
        XCTAssertEqual(store.ownedPlayerState(for: notOwned), .unsigned)
        XCTAssertFalse(store.profile.ownedCardIDs.contains(notOwned.id))

        // Signed: signing moves the card into the signed state and starts
        // the career record the detail screen reads. (Plain ownership first:
        // migration records it unsigned because it is neither assigned nor
        // activated, so signPlayer's unsigned-only gate accepts it.)
        store.profile.ownedCardIDs.insert(unsigned.id)
        store.signPlayer(cardID: unsigned.id)
        XCTAssertTrue(store.isSigned(unsigned))
        XCTAssertNotNil(store.careerState(for: unsigned))
        XCTAssertEqual(store.assignment(for: unsigned), .reserves)
    }

    func testAssignmentReflectsStartingXIBenchAndReserves() async throws {
        let store = await makeStore()
        // The starter profile fields a full XI; pick two signed starters
        // and prove the assignment derivation the status card shows.
        let xiID = try XCTUnwrap(store.profile.startingXICardIDs.compactMap { $0 }.first)
        let xiCard = try XCTUnwrap(LegendsCardDatabase.all.first { $0.id == xiID })
        XCTAssertEqual(store.assignment(for: xiCard), .startingXI)

        // Move them to the bench, then reserves. The starter bench is
        // full, so free a slot first — the same path the Squad screen uses.
        store.moveToReserves(cardID: xiCard.id)
        XCTAssertEqual(store.assignment(for: xiCard), .reserves)
        store.clearBenchSlot(0)
        store.assign(cardID: xiCard.id, toBenchSlot: 0)
        XCTAssertEqual(store.assignment(for: xiCard), .bench)
    }

    // MARK: - Final-season + retirement flags

    func testFinalSeasonAndRetirementFlagsFollowAgingRules() async throws {
        let store = await makeStore()
        store.profile.ownedCardIDs.insert("cantina-9596")
        store.signPlayer(cardID: "cantina-9596")
        let cantina = card("cantina-9596")
        let career = try XCTUnwrap(store.careerState(for: cantina))

        // Early career: no final-season warning, not retired.
        XCTAssertFalse(store.isFinalSeason(cantina))
        XCTAssertFalse(store.isRetired(cantina))

        // One season before the intended retirement age (age is driven by
        // cardAgeOffsets, exactly as advanceSeasonIfNeeded ages careers):
        // final-season true, not yet retired.
        store.profile.cardAgeOffsets[cantina.id] = career.intendedRetirementAge - cantina.age - 1
        XCTAssertTrue(store.isFinalSeason(cantina))
        XCTAssertFalse(store.isRetired(cantina))

        // At the intended retirement age: retired.
        store.profile.cardAgeOffsets[cantina.id] = career.intendedRetirementAge - cantina.age
        XCTAssertTrue(store.isRetired(cantina))
    }

    func testAgingExemptErasNeverRetire() async throws {
        let store = await makeStore()
        store.profile.ownedCardIDs.insert("kahnwald-0001") // era: .legends
        store.signPlayer(cardID: "kahnwald-0001")
        let immortal = card("kahnwald-0001")
        store.profile.cardAgeOffsets[immortal.id] = 400
        XCTAssertFalse(store.isRetired(immortal), "Legends/Icons era cards are aging-exempt")
        XCTAssertFalse(store.isFinalSeason(immortal))
    }

    // MARK: - Duplicate progress + upgrades the duplicate card shows

    func testDuplicateProgressAndUpgradesUseAuthoritativeCounters() async {
        let store = await makeStore()
        XCTAssertEqual(LegendsStore.duplicatesPerUpgrade, 3)
        XCTAssertEqual(LegendsStore.maxCardUpgrade, 3)
        let cantina = card("cantina-9596")
        store.profile.duplicateProgress[cantina.id] = 2
        store.profile.cardUpgrades[cantina.id] = 1
        XCTAssertEqual(store.profile.duplicateProgress[cantina.id], 2)
        XCTAssertEqual(store.profile.cardUpgrades[cantina.id], 1)
        XCTAssertEqual(store.effectiveOverall(for: cantina),
                       cantina.overall + 1 + store.developmentBonus(for: cantina) + store.formBoost(for: cantina),
                       "An applied upgrade must shift the presented effective OVR by exactly +1")
    }

    // MARK: - Identity/biography fields

    func testIdentityProfileProvidesBiographyFootAndArchetype() async throws {
        let store = await makeStore()
        let cantina = card("cantina-9596")
        let profile = store.identityProfile(for: cantina)
        XCTAssertEqual(profile.identity.biography, cantina.biography)
        XCTAssertFalse(profile.identity.preferredFoot.rawValue.isEmpty)
        // Striker maps to the FINISHER archetype via the deterministic engine.
        XCTAssertEqual(profile.identity.archetype.rawValue, "FINISHER")

        // Same person across card variants resolves to one stable person ID.
        let retro = card("cantina-9596-retro")
        XCTAssertEqual(profile.identity.personID,
                       store.identityProfile(for: retro).identity.personID)
    }

    // MARK: - Condition panel inputs

    func testConditionDefaultsAreConsistentForSignedPlayers() async throws {
        let store = await makeStore()
        let unsigned = card("maldinho-9596")
        store.profile.ownedCardIDs.insert(unsigned.id)
        store.signPlayer(cardID: unsigned.id)
        let condition = store.condition(for: unsigned)
        for (name, value) in [("form", condition.form), ("morale", condition.morale),
                              ("teamwork", condition.teamwork), ("fame", condition.fame)] {
            XCTAssertTrue((0...100).contains(value), "\(name) must be a percentage, got \(value)")
        }
        // Unsigned cards have no career record, so the condition block is hidden.
        XCTAssertNil(store.careerState(for: card("kahnwald-0001")))
    }

    // MARK: - Goalkeeper presentation inputs

    func testGoalkeeperCardsExposeGoalkeepingAttributeGroup() async throws {
        let store = await makeStore()
        let keeper = card("cechinho-0607")
        XCTAssertEqual(keeper.position.broad, .goalkeeper)
        let detailed = store.effectiveDetailedAttributes(for: keeper)
        let handling = try XCTUnwrap(detailed.values(in: .goalkeeping).first { $0.0 == "Handling" })
        XCTAssertGreaterThan(handling.1, 0, "Keepers get meaningful goalkeeping attributes")
        // Outfielders keep zero goalkeeping attributes so the group is hidden.
        let striker = card("cantina-9596")
        let strikerAttrs = store.effectiveDetailedAttributes(for: striker)
        XCTAssertTrue(strikerAttrs.values(in: .goalkeeping).allSatisfy { $0.1 == 0 })
    }
}
