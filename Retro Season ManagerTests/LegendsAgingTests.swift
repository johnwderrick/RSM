//
//  LegendsAgingTests.swift
//  Retro Season ManagerTests
//
//  Guards the seasonal aging/decline/retirement system in
//  LegendsStore+Aging.swift: exempt eras never decline, decline only
//  starts past the peak age, retirement is a hard cutoff that clears
//  squad slots and captaincy, and a retired card can't be reassigned.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsAgingTests: XCTestCase {
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = 0
        store.profile.cardAgeOffsets = [:]
        store.profile.activatedCardIDs = []
        // LegendsStore() loads whatever's actually on disk (e.g. from a
        // manual Simulator run) — reset every field aging/retirement math
        // could be sensitive to, not just the ones this file's tests set
        // directly, or a stray real duplicate-upgrade poisons the numbers.
        store.profile.cardUpgrades = [:]
        store.profile.duplicateProgress = [:]
        store.profile.playerCareers = [:]
        store.profile.legendsHall = []
        store.signAllOwnedCardsForTesting()
        return store
    }

    private func card(_ id: String) -> LegendsCard {
        LegendsCardDatabase.all.first { $0.id == id }!
    }

    func testExemptErasNeverDeclineOrRetireRegardlessOfOffset() async {
        let store = await freshStore()
        let iconCard = card("maldinho-icon")
        XCTAssertTrue(LegendsStore.agingExemptEras.contains(iconCard.era))
        store.profile.cardAgeOffsets[iconCard.id] = 50
        XCTAssertEqual(store.agingPenalty(for: iconCard), 0)
        XCTAssertFalse(store.isRetired(iconCard))
        XCTAssertEqual(store.effectiveOverall(for: iconCard), iconCard.overall)
    }

    func testDeclineOnlyStartsPastThePeakAge() async {
        let store = await freshStore()
        // miessi-0506 is age 18, non-exempt (2000s era) — plenty of room
        // before LegendsStore.declineStartAge (30).
        let young = card("miessi-0506")
        XCTAssertFalse(LegendsStore.agingExemptEras.contains(young.era))
        XCTAssertEqual(store.agingPenalty(for: young), 0)

        store.profile.cardAgeOffsets[young.id] = LegendsStore.declineStartAge - young.age
        XCTAssertEqual(store.effectiveAge(for: young), LegendsStore.declineStartAge)
        XCTAssertEqual(store.agingPenalty(for: young), 0, "No penalty exactly at the peak-age ceiling")

        store.profile.cardAgeOffsets[young.id] = (LegendsStore.declineStartAge - young.age) + 3
        XCTAssertEqual(store.agingPenalty(for: young), 3 * LegendsStore.declinePerYearOverPeak)
    }

    // The old universal age-36 ceiling was superseded by profile-based
    // career lengths. These assertions protect the authoritative ranges.
    func testProfileRetirementRangesAndDeterministicTargets() async {
        let store = await freshStore()
        let cards = LegendsCardDatabase.all.filter { !LegendsStore.agingExemptEras.contains($0.era) }
        for profile in LegendsCareerLifecyclePolicy.DevelopmentProfile.allCases {
            let policy = LegendsCareerLifecyclePolicy.configuration(for: profile)
            for card in cards {
                let target = LegendsCareerLifecyclePolicy.retirementAge(for: card.id, position: card.position, profile: profile)
                if card.position.broad == .goalkeeper {
                    XCTAssertGreaterThanOrEqual(target, policy.minimumRetirementAge + 2)
                    XCTAssertLessThanOrEqual(target, 41)
                } else {
                    XCTAssertTrue(policy.retirementAgeRange.contains(target))
                }
                let second = LegendsCareerLifecyclePolicy.retirementAge(for: card.id, position: card.position, profile: profile)
                XCTAssertEqual(target, second)
                let state = LegendsStore.makeCareerState(for: card, signedSeason: 1)
                if state.lifecycleProfile == profile {
                    XCTAssertGreaterThan(target, state.peakEndAge)
                }
            }
        }
    }

    func testCareerIsFinalSeasonBeforeRetirementAndArchivesOnce() async {
        let store = await freshStore()
        let card = card("miessi-0506")
        store.profile.ownedCardIDs = [card.id]
        store.signAllOwnedCardsForTesting()
        store.startCareerIfNeeded(for: card)
        let targetAge = 35
        var configuredCareer = store.profile.playerCareers[card.id]!
        configuredCareer.intendedRetirementAge = targetAge
        store.profile.playerCareers[card.id] = configuredCareer
        let target = targetAge
        store.profile.cardAgeOffsets[card.id] = target - 2 - card.age
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.activatedCardIDs.insert(card.id)
        XCTAssertFalse(store.isRetired(card))
        XCTAssertFalse(store.isFinalSeason(card))
        XCTAssertEqual(store.effectiveAge(for: card), target - 2)
        XCTAssertEqual(store.profile.cardAgeOffsets[card.id], target - 2 - card.age)
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        for _ in 0..<LegendsStore.matchesPerSeason {
            _ = store.advanceSeasonIfNeeded()
        }
        XCTAssertTrue(store.isFinalSeason(card))
        XCTAssertEqual(store.effectiveAge(for: card), target - 1)
        XCTAssertEqual(store.profile.legendsHall.filter { $0.cardID == card.id }.count, 0)
        for _ in 0..<LegendsStore.matchesPerSeason {
            _ = store.advanceSeasonIfNeeded()
        }
        XCTAssertEqual(store.profile.legendsHall.filter { $0.cardID == card.id }.count, 1)
        XCTAssertNil(store.profile.playerCareers[card.id])
        XCTAssertFalse(store.profile.ownedCardIDs.contains(card.id))
    }

    func testSeasonOnlyAdvancesEveryMatchesPerSeasonCalls() async {
        let store = await freshStore()
        for _ in 0..<(LegendsStore.matchesPerSeason - 1) {
            XCTAssertNil(store.advanceSeasonIfNeeded())
        }
        XCTAssertEqual(store.profile.matchesPlayedThisSeason, LegendsStore.matchesPerSeason - 1)

        let result = store.advanceSeasonIfNeeded()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.newSeason, 2)
        XCTAssertEqual(store.profile.currentSeason, 2)
        XCTAssertEqual(store.profile.matchesPlayedThisSeason, 0)
    }

    func testSeasonAdvanceAgesActivatedCardsButNotLibraryCards() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        let iconCard = card("maldinho-icon")
        store.assign(cardID: young.id, toXISlot: 0)
        for _ in 0..<LegendsStore.matchesPerSeason { store.advanceSeasonIfNeeded() }

        XCTAssertEqual(store.profile.cardAgeOffsets[young.id], 1)
        XCTAssertNil(store.profile.cardAgeOffsets[iconCard.id], "Icons era shouldn't accumulate an age offset at all")
        let libraryCard = card("renaldo-0405")
        XCTAssertFalse(store.profile.activatedCardIDs.contains(libraryCard.id))
        XCTAssertNil(store.profile.cardAgeOffsets[libraryCard.id], "Unsigned library cards stay frozen")
    }

    func testRetiredCardIsAutoClearedFromSquadAndCaptaincy() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.profile.ownedCardIDs = [young.id]
        store.signAllOwnedCardsForTesting()
        store.startCareerIfNeeded(for: young)
        store.assign(cardID: young.id, toXISlot: 0)
        store.setCaptain(cardID: young.id)
        XCTAssertEqual(store.profile.captainCardID, young.id)

        // Age the card to Final Season, confirming it remains fielded for
        // the complete T-1 season before the retirement rollover.
        var configuredCareer = store.profile.playerCareers[young.id]!
        configuredCareer.intendedRetirementAge = 35
        store.profile.playerCareers[young.id] = configuredCareer
        let target = configuredCareer.intendedRetirementAge
        let seasonsToRetirement = target - young.age
        store.profile.cardAgeOffsets[young.id] = target - 1 - young.age
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        for _ in 0..<0 {
            store.advanceSeasonIfNeeded()
        }
        XCTAssertEqual(store.profile.startingXICardIDs[0], young.id, "Still fielded a season before retiring")
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1

        // The season that actually crosses the retirement age.
        var result: LegendsSeasonAdvanceResult?
        for _ in 0..<LegendsStore.matchesPerSeason {
            result = store.advanceSeasonIfNeeded() ?? result
        }
        XCTAssertNil(store.profile.startingXICardIDs[0], "Cleared from the XI the moment it retires")
        XCTAssertNil(store.profile.captainCardID, "Captaincy cleared along with the retired captain")
        XCTAssertEqual(result?.retiredCards.map(\.id), [young.id])
    }

    func testRetiredCardCannotBeAssigned() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.profile.activatedCardIDs.insert(young.id)
        store.startCareerIfNeeded(for: young)
        store.profile.ownedCardIDs = [young.id]
        store.profile.activatedCardIDs = [young.id]
        store.startCareerIfNeeded(for: young)
        var career = store.profile.playerCareers[young.id]!
        career.intendedRetirementAge = LegendsStore.retirementAge
        store.profile.playerCareers[young.id] = career
        store.profile.cardAgeOffsets[young.id] = LegendsStore.retirementAge - young.age
        XCTAssertTrue(store.isRetired(young))

        store.assign(cardID: young.id, toXISlot: 0)
        XCTAssertNil(store.profile.startingXICardIDs[0])

        store.assign(cardID: young.id, toBenchSlot: 0)
        XCTAssertNil(store.profile.benchCardIDs[0])
    }

    func testUnsignedCollectionCardStaysFrozenAndHasNoCareer() async {
        let store = await freshStore()
        let card = card("miessi-0506")
        store.profile.ownedCardIDs = [card.id]
        store.signAllOwnedCardsForTesting()
        for _ in 0..<(LegendsStore.matchesPerSeason * 3) {
            _ = store.advanceSeasonIfNeeded()
        }
        XCTAssertNil(store.profile.playerCareers[card.id])
        XCTAssertNil(store.profile.cardAgeOffsets[card.id])
        XCTAssertEqual(store.effectiveAge(for: card), card.age)
        XCTAssertFalse(store.isCareerStarted(card))
    }

    func testSigningStartsCareerOnlyOnceAndMakesItPermanent() async {
        let store = await freshStore()
        let card = card("miessi-0506")
        store.profile.ownedCardIDs = [card.id]
        store.signAllOwnedCardsForTesting()
        store.startCareerIfNeeded(for: card)
        store.assign(cardID: card.id, toXISlot: 1)
        let firstCareer = store.profile.playerCareers[card.id]
        XCTAssertNotNil(firstCareer)
        store.clearXISlot(1)
        XCTAssertTrue(store.profile.activatedCardIDs.contains(card.id))
        store.assign(cardID: card.id, toXISlot: 1)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.careerID, firstCareer?.careerID)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.startingAge, card.age)
    }

    func testMatchesAndTrainingDevelopAYoungSignedCareer() async {
        let store = await freshStore()
        let card = card("miessi-0506")
        store.profile.ownedCardIDs = [card.id]
        store.signAllOwnedCardsForTesting()
        store.startCareerIfNeeded(for: card)
        store.assign(cardID: card.id, toXISlot: 1)
        let initial = store.effectiveOverall(for: card)
        XCTAssertTrue(store.trainPlayer(card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        XCTAssertFalse(store.trainPlayer(card.id), "Training is capped per season")
        for _ in 0..<10 {
            store.recordCareerMatch(LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 0))
        }
        XCTAssertGreaterThan(store.effectiveOverall(for: card), initial)
        XCTAssertGreaterThan(store.profile.playerCareers[card.id]?.appearances ?? 0, 0)
    }

    func testRetirementAnnouncementPrecedesHallEntryAndAllowsNewGeneration() async {
        let store = await freshStore()
        let card = card("miessi-0506")
        store.profile.ownedCardIDs = [card.id]
        store.signAllOwnedCardsForTesting()
        store.startCareerIfNeeded(for: card)
        store.assign(cardID: card.id, toXISlot: 1)
        // Bring the signed career to T-2, then observe Final Season at
        // T-1 before Hall archival at the following rollover.
        var configuredCareer = store.profile.playerCareers[card.id]!
        configuredCareer.intendedRetirementAge = 35
        store.profile.playerCareers[card.id] = configuredCareer
        let target = configuredCareer.intendedRetirementAge
        store.profile.cardAgeOffsets[card.id] = target - 2 - card.age
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        var announcement: LegendsSeasonAdvanceResult?
        for _ in 0..<LegendsStore.matchesPerSeason {
            announcement = store.advanceSeasonIfNeeded() ?? announcement
        }
        XCTAssertEqual(announcement?.retirementAnnouncements.map(\.id), [card.id])
        XCTAssertTrue(store.profile.ownedCardIDs.contains(card.id))

        var completion: LegendsSeasonAdvanceResult?
        for _ in 0..<LegendsStore.matchesPerSeason {
            completion = store.advanceSeasonIfNeeded() ?? completion
        }
        XCTAssertEqual(completion?.retiredCards.map(\.id), [card.id])
        XCTAssertEqual(store.profile.legendsHall.count, 1)
        XCTAssertEqual(store.profile.legendsHall.first?.finalAge, target)
        XCTAssertFalse(store.profile.ownedCardIDs.contains(card.id))
        XCTAssertNil(store.profile.playerCareers[card.id])

        // A later pull of the same database card is a new career, not the
        // retired record being resurrected.
        store.profile.ownedCardIDs.insert(card.id)
        store.assign(cardID: card.id, toXISlot: 1)
        XCTAssertNotEqual(store.profile.playerCareers[card.id]?.careerID,
                          store.profile.legendsHall.first?.id)
    }
}
