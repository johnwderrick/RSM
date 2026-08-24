//
//  LegendsProfileRoundTripTests.swift
//  Retro Season ManagerTests
//
//  RSM Legends' own save format (LegendsProfile → legends_profile.json,
//  see LegendsStore.swift) reinvents the same lenient-decode discipline
//  SaveState uses, but — like SaveState before this file existed — had no
//  automated check that either the round trip or the "missing field"
//  fallback path actually works. Mirrors SaveStateRoundTripTests.swift's
//  two cases for Career Mode's save format.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsProfileRoundTripTests: XCTestCase {

    /// `LegendsStore.fileURL` is private (deliberately — there's only ever
    /// one profile file, unlike Career Mode's per-slot saves), so this
    /// round-trips entirely through the real public API: mutate `profile`,
    /// call `persist()`, construct a fresh store and read `profile` back.
    /// The original on-disk profile (whatever it was before this test ran)
    /// is restored afterwards so repeat runs don't compound state.
    func testProfileRoundTripsThroughPersistAndLoad() async {
        let original = await Task { @MainActor in LegendsStore() }.value.profile
        defer {
            Task { @MainActor in
                let restore = LegendsStore()
                restore.profile = original
                restore.persist()
            }
        }

        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.coins = 4242
        store.profile.packTokens = 9
        store.profile.division = .division3
        store.profile.teamRating = 81
        store.profile.ownedCardIDs = ["ronaldo-2004", "messi-2011"]
        store.profile.totalWins = 17
        store.profile.clubName = "Round Trip FC"
        store.profile.preferredMentality = .attacking
        let lifecycleCard = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        let lifecycle = LegendsStore.makeCareerState(for: lifecycleCard, signedSeason: 2)
        store.profile.activatedCardIDs = [lifecycleCard.id]
        store.profile.playerCareers = [lifecycleCard.id: lifecycle]
        store.profile.legendsHall = [LegendsHallEntry(id: "hall-career", cardID: lifecycleCard.id,
                                                        playerName: lifecycleCard.name, position: lifecycleCard.position,
                                                        nation: lifecycleCard.nation, startingAge: 18, startingOverall: 84,
                                                        highestOverall: 92, finalAge: 36, appearances: 100, goals: 20,
                                                        assists: 15, cleanSheets: 0, seasonsAtClub: 18,
                                                        signedSeason: 2, retiredSeason: 20)]
        store.persist()

        let reloaded = await Task { @MainActor in LegendsStore() }.value
        XCTAssertEqual(reloaded.profile.coins, 4242)
        XCTAssertEqual(reloaded.profile.packTokens, 9)
        XCTAssertEqual(reloaded.profile.division, .division3)
        XCTAssertEqual(reloaded.profile.teamRating, 81)
        XCTAssertEqual(reloaded.profile.ownedCardIDs, ["ronaldo-2004", "messi-2011"])
        XCTAssertEqual(reloaded.profile.totalWins, 17)
        XCTAssertEqual(reloaded.profile.clubName, "Round Trip FC")
        XCTAssertEqual(reloaded.profile.preferredMentality, .attacking)
        XCTAssertEqual(reloaded.profile.playerCareers[lifecycleCard.id]?.potential, lifecycle.potential)
        XCTAssertEqual(reloaded.profile.playerCareers[lifecycleCard.id]?.developmentProgress, lifecycle.developmentProgress)
        XCTAssertEqual(reloaded.profile.legendsHall.first?.playerName, lifecycleCard.name)
        XCTAssertEqual(reloaded.profile.legendsHall.first?.highestOverall, 92)
    }

    /// Exercises `LegendsProfile.init(from:)` directly against a hand-built
    /// JSON blob that only has the fields present at Phase 1 — simulating a
    /// profile saved before every later phase's fields (squad builder,
    /// challenges, managers & stadiums, ...) existed — and checks every
    /// missing field comes back as its documented default rather than
    /// failing the decode.
    func testDecodingProfileMissingLaterPhaseFieldsUsesDocumentedDefaults() throws {
        let earlyProfileJSON = """
        {
            "clubName": "Old Save FC",
            "crestShort": "OSF",
            "crestColorRGB": [0.1, 0.2, 0.3],
            "managerLevel": 4,
            "managerXP": 250,
            "coins": 1200,
            "packTokens": 2,
            "division": 5,
            "teamRating": 0
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(LegendsProfile.self, from: earlyProfileJSON)

        // Fields present in the JSON decode as written.
        XCTAssertEqual(profile.clubName, "Old Save FC")
        XCTAssertEqual(profile.coins, 1200)
        XCTAssertEqual(profile.division, .division5)

        // Everything added in a later phase falls back to its documented default.
        XCTAssertEqual(profile.ownedCardIDs, [], "ownedCardIDs should default to empty when absent")
        XCTAssertEqual(profile.playerCareers, [:], "playerCareers should default to empty when absent")
        XCTAssertEqual(profile.legendsHall, [], "legendsHall should default to empty when absent")
        XCTAssertEqual(profile.duplicateProgress, [:], "duplicateProgress should default to empty when absent")
        XCTAssertEqual(profile.cardUpgrades, [:], "cardUpgrades should default to empty when absent")
        XCTAssertEqual(profile.formationName, "4-4-2", "formationName should default to 4-4-2 when absent")
        XCTAssertEqual(profile.startingXICardIDs.count, 11, "startingXICardIDs should default to 11 empty slots when absent")
        XCTAssertTrue(profile.startingXICardIDs.allSatisfy { $0 == nil })
        XCTAssertEqual(profile.benchCardIDs.count, LegendsStore.benchSize, "benchCardIDs should default to benchSize empty slots when absent")
        XCTAssertNil(profile.captainCardID)
        XCTAssertEqual(profile.divisionWins, 0)
        XCTAssertEqual(profile.totalWins, 0)
        XCTAssertEqual(profile.currentWinStreak, 0)
        XCTAssertEqual(profile.lastDailyReset, .distantPast)
        XCTAssertEqual(profile.lastWeeklyReset, .distantPast)
        XCTAssertEqual(profile.completedPermanentChallengeIDs, [])
        XCTAssertEqual(profile.completedDailyChallengeIDs, [])
        XCTAssertEqual(profile.completedWeeklyChallengeIDs, [])
        XCTAssertEqual(profile.ownedManagerIDs, [])
        XCTAssertNil(profile.activeManagerID)
        XCTAssertEqual(profile.ownedStadiumIDs, [])
        XCTAssertNil(profile.activeStadiumID)
        XCTAssertEqual(profile.preferredMentality, .balanced, "preferredMentality should default to .balanced when absent")
    }

    /// A brand-new club (`.starter()` — used both on first launch and by
    /// Delete Club) should be playable immediately: a full, legal Starting
    /// XI and bench, not an empty squad the player has to build from packs
    /// before they can play a single match.
    func testStarterProfileHasAFullLegalStartingSquadOfLowRatedCards() {
        let profile = LegendsProfile.starter()

        XCTAssertEqual(profile.startingXICardIDs.count, 11)
        XCTAssertTrue(profile.startingXICardIDs.allSatisfy { $0 != nil }, "Every Starting XI slot should be filled")
        XCTAssertEqual(profile.benchCardIDs.count, LegendsStore.benchSize)
        XCTAssertTrue(profile.benchCardIDs.allSatisfy { $0 != nil }, "Every bench slot should be filled")

        let xiIDs = profile.startingXICardIDs.compactMap { $0 }
        let benchIDs = profile.benchCardIDs.compactMap { $0 }
        XCTAssertEqual(Set(xiIDs).count, xiIDs.count, "No card should be double-booked in the XI")
        XCTAssertTrue(Set(xiIDs).isDisjoint(with: Set(benchIDs)), "No card should be in both the XI and the bench")

        let squadCards = (xiIDs + benchIDs).compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        XCTAssertEqual(squadCards.count, 18)
        XCTAssertEqual(Set(squadCards.map(\.name)).count, 18, "One card per real player, matching the squad's own uniqueness rule")
        XCTAssertTrue(squadCards.allSatisfy { $0.rarity.tier <= 2 }, "Starter cards should be Common/Rare/Elite — genuinely bad, not a free head start")
        XCTAssertEqual(profile.ownedCardIDs, Set(xiIDs + benchIDs))

        // A goalkeeper must actually be fielded in goal, matching the
        // Squad screen's own expectation that slot 0 is always the GK.
        let goalkeeper = squadCards.first { profile.startingXICardIDs[0] == $0.id }
        XCTAssertEqual(goalkeeper?.position, .goalkeeper)
    }
}
