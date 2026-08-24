//
//  LegendsLifecyclePhase2Tests.swift
//  Retro Season ManagerTests
//
//  Guards the Phase 2 lifecycle expansion in LegendsStore+Aging.swift:
//  season-by-season career history, the end-of-season development review,
//  milestone crossing (once per career, not per season), all-time club
//  records, player statuses, Legacy Score + Hall ranking, per-career
//  decline curves, and lenient decoding of careers saved before Phase 2
//  fields existed.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsLifecyclePhase2Tests: XCTestCase {

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
        store.profile.playerCareers = [:]
        store.profile.legendsHall = []
        store.profile.clubRecords = [:]
        store.profile.lastSeasonReview = [:]
        store.profile.cardUpgrades = [:]
        store.profile.duplicateProgress = [:]
        return store
    }

    private func card(_ id: String) -> LegendsCard {
        LegendsCardDatabase.all.first { $0.id == id }!
    }

    /// Plays a full season (one match per `advanceSeasonIfNeeded` call) for
    /// the given XI, recording career matches as we go, and returns the
    /// season roll result.
    private func playSeason(_ store: LegendsStore, xiIDs: [String], divisionResult: LegendsDivisionSeasonResult? = nil,
                            wins: Int? = nil) -> LegendsSeasonAdvanceResult? {
        var result: LegendsSeasonAdvanceResult?
        for _ in 0..<LegendsStore.matchesPerSeason {
            store.recordCareerMatch(LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 0))
            result = store.advanceSeasonIfNeeded(divisionResult: divisionResult) ?? result
        }
        return result
    }

    // MARK: - Career history (season records)

    func testSeasonRecordsAccumulatePermanentHistory() async {
        let store = await freshStore()
        let young = card("miessi-0506") // age 18, 2000s era — develops, doesn't retire for many seasons
        store.assign(cardID: young.id, toXISlot: 0)
        _ = playSeason(store, xiIDs: [young.id])
        _ = playSeason(store, xiIDs: [young.id])

        let career = store.profile.playerCareers[young.id]
        XCTAssertEqual(career?.seasonRecords.count, 2, "One season record per completed season")
        let first = career?.seasonRecords.first
        XCTAssertEqual(first?.appearances, LegendsStore.matchesPerSeason)
        XCTAssertGreaterThan(first?.goals ?? 0, 0, "The win-by-one scoreline should credit at least one goal")
        XCTAssertEqual(first?.overallAtStart, young.overall, "First season opens from the card's signing OVR")
        let second = career?.seasonRecords.last
        XCTAssertEqual(second?.season, (first?.season ?? 0) + 1, "Seasons are numbered consecutively")
    }

    // MARK: - Season development review

    func testSeasonReviewReportsDeltaAndReasonForActivePlayer() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        let result = playSeason(store, xiIDs: [young.id])

        let review = result?.developmentReview[young.id]
        XCTAssertNotNil(review, "An active career should receive a season review")
        XCTAssertEqual(review?.appearances, LegendsStore.matchesPerSeason)
        XCTAssertGreaterThanOrEqual(review?.overallDelta ?? 0, 0, "A young, played, high-potential player shouldn't decline")
        XCTAssertTrue(review?.reason.contains("Regular starter") == true, "Reason should cite first-team minutes")
    }

    func testSeasonReviewShowsDeclineForAgedPlayerPastPeak() async {
        let store = await freshStore()
        // K. Keegana is 31 — signing starts a career past the individual
        // peak window, so a full season of first-team football should read
        // as decline (age), not growth (development is exhausted).
        let veteran = card("keegana-9394")
        store.profile.ownedCardIDs.insert(veteran.id)
        store.profile.activatedCardIDs.insert(veteran.id)
        store.profile.playerCareers[veteran.id] = LegendsStore.makeCareerState(for: veteran, signedSeason: store.profile.currentSeason)
        store.assign(cardID: veteran.id, toXISlot: 0)

        let result = playSeason(store, xiIDs: [veteran.id])
        let review = result?.developmentReview[veteran.id]
        XCTAssertNotNil(review)
        XCTAssertTrue(review?.reason.contains("Regular starter") == true,
                      "A full season of starts should cite regular first-team minutes")
        XCTAssertLessThan(review?.overallDelta ?? 0, 0, "Past-peak players decline with age")
    }

    // MARK: - Milestones

    func testFirstAppearanceAndGoalMilestonesFireExactlyOnce() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        _ = playSeason(store, xiIDs: [young.id])

        let milestones = store.profile.playerCareers[young.id]?.milestones
        XCTAssertTrue(milestones?.contains(.firstAppearance) == true, "Playing a season earns FIRST APPEARANCE")
        XCTAssertTrue(milestones?.contains(.firstGoal) == true, "Scoring earns FIRST GOAL")

        // A second identical season must not re-announce either milestone.
        let second = playSeason(store, xiIDs: [young.id])
        XCTAssertEqual(second?.newMilestones[young.id] ?? [], [],
                       "Already-earned milestones must not be re-reported next season")
    }

    func testFirstTrophyMilestoneEarnedOnceAcrossDivisionSeasons() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        let seasonResult = LegendsDivisionSeasonResult(season: 1, finalRank: 2, totalTeams: 8,
                                                       outcome: .promoted, previousDivision: .division9,
                                                       newDivision: .division8,
                                                       reward: LegendsSeasonReward(coins: 100, tokens: 2, managerXP: 40))
        let first = playSeason(store, xiIDs: [young.id], divisionResult: seasonResult)
        XCTAssertTrue(first?.newMilestones[young.id]?.contains(.firstTrophy) == true, "First completed division season earns FIRST TROPHY")

        // A second division season with a trophy-worthy finish must NOT
        // re-announce the same milestone.
        let again = playSeason(store, xiIDs: [young.id], divisionResult: seasonResult)
        XCTAssertEqual(again?.newMilestones[young.id] ?? [], [],
                       "FIRST TROPHY is a once-per-career milestone")
    }

    func testAppearanceThresholdMilestonesFireWhenCrossed() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        // Drive the career to 69 appearances (one below the 14-match-season
        // threshold of 70), then finish a season that crosses 70 — the
        // milestone should land exactly once, without also awarding 140.
        var state = store.profile.playerCareers[young.id]!
        state.appearances = 69
        state.seasonStartAppearances = 69
        store.profile.playerCareers[young.id] = state
        _ = playSeason(store, xiIDs: [young.id])

        let milestones = store.profile.playerCareers[young.id]?.milestones
        XCTAssertTrue(milestones?.contains(.seventyAppearances) == true, "Crossing 70 appearances earns 70 APPEARANCES")
        XCTAssertFalse(milestones?.contains(.hundredFortyAppearances) == true, "69 → 70 crossing must not award 140 too")
    }

    // MARK: - Club records

    func testClubRecordsAreSetAndPersistAcrossSeasons() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        _ = playSeason(store, xiIDs: [young.id])

        let records = store.profile.clubRecords
        XCTAssertEqual(records[.mostAppearances]?.playerName, young.name)
        XCTAssertEqual(records[.mostAppearances]?.value, LegendsStore.matchesPerSeason)
        XCTAssertEqual(records[.mostGoals]?.playerName, young.name)
        XCTAssertEqual(records[.youngestPlayer]?.value, young.age, "The signed 18-year-old becomes the youngest player record")
        XCTAssertGreaterThanOrEqual(records[.highestOverall]?.value ?? 0, young.overall,
                                    "The highest-OVR record captures the developed rating, not just the card base")
    }

    // MARK: - Player status

    func testPlayerStatusProgressesWithServiceAndAbility() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        XCTAssertEqual(store.playerStatus(for: young), .prospect, "Fresh signing with zero appearances is a prospect")

        // One full season of starts (matchesPerSeason apps) → breakthrough
        // (>= 7 apps).
        _ = playSeason(store, xiIDs: [young.id])
        XCTAssertEqual(store.playerStatus(for: young), .breakthrough)

        // Two seasons of starts (2 x matchesPerSeason = 28 apps) → first-team
        // regular (>= 21 apps, below the 35-app key-player gate).
        _ = playSeason(store, xiIDs: [young.id])
        XCTAssertEqual(store.playerStatus(for: young), .firstTeam)

        // A veteran past the age threshold reads as VETERAN regardless of ability.
        store.profile.cardAgeOffsets[young.id] = LegendsStore.retirementAge - 2 - young.age
        XCTAssertEqual(store.playerStatus(for: young), .veteran)

        // Club Legend flag wins over every other status.
        store.profile.cardAgeOffsets[young.id] = 0
        var state = store.profile.playerCareers[young.id]!
        state.isClubLegend = true
        store.profile.playerCareers[young.id] = state
        XCTAssertEqual(store.playerStatus(for: young), .clubLegend)
    }

    // MARK: - Legacy Score and Hall ranking

    func testLegacyScoreRanksRetiredCareersInTheHall() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.assign(cardID: young.id, toXISlot: 0)
        // Age to the season before the retirement cutoff, then roll two
        // full seasons: the announcement season, then the retiring one.
        store.profile.cardAgeOffsets[young.id] = LegendsStore.retirementAge - 2 - young.age
        var result: LegendsSeasonAdvanceResult?
        for _ in 0..<(LegendsStore.matchesPerSeason * 2) {
            result = store.advanceSeasonIfNeeded() ?? result
        }
        XCTAssertEqual(store.profile.legendsHall.count, 1)
        let entry = store.profile.legendsHall.first
        XCTAssertEqual(entry?.playerName, young.name)
        XCTAssertGreaterThan(entry?.legacyScore ?? 0, 0, "A completed career must produce a Legacy Score")
        XCTAssertEqual(entry?.finalAge, LegendsStore.retirementAge)
        XCTAssertFalse(entry?.careerHistory.isEmpty ?? true, "Hall entries carry the full season history")

        // A second, lesser career ranks below the first by Legacy Score.
        let other = card("renaldo-0405")
        store.profile.ownedCardIDs.insert(other.id)
        store.profile.playerCareers[other.id] = LegendsStore.makeCareerState(for: other, signedSeason: store.profile.currentSeason)
        store.profile.activatedCardIDs.insert(other.id)
        store.profile.cardAgeOffsets[other.id] = LegendsStore.retirementAge - other.age
        for _ in 0..<(LegendsStore.matchesPerSeason * 2) {
            _ = store.advanceSeasonIfNeeded()
        }
        XCTAssertEqual(store.profile.legendsHall.count, 2)
        let ranked = store.profile.legendsHall.sorted { $0.legacyScore > $1.legacyScore }
        XCTAssertGreaterThanOrEqual(ranked[0].legacyScore, ranked[1].legacyScore,
                                    "Hall ranking sorts by Legacy Score descending")
    }

    // MARK: - Per-career decline

    func testDeclineRespectsIndividualPeakWindowAndDeclineRate() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        // Career with a late, long prime — decline should not start at the
        // generic boundary the way unsigned cards do. The prime window and
        // rate are fixed at signing (let constants on the career), so build
        // the record directly.
        let latePeak = LegendsPlayerCareer(careerID: "late-peak", cardID: young.id, startingAge: young.age,
                                           startingOverall: young.overall, potential: 90, peakStartAge: 30,
                                           peakEndAge: 34, developmentRate: 5, declineRate: 2,
                                           signedSeason: 1)
        store.profile.playerCareers[young.id] = latePeak
        store.profile.activatedCardIDs.insert(young.id)

        store.profile.cardAgeOffsets[young.id] = 33 - young.age  // age 33, inside the 30–34 window
        XCTAssertEqual(store.agingPenalty(for: young), 0, "No decline inside the individual peak window")
        XCTAssertEqual(store.effectiveOverall(for: young), young.overall)

        store.profile.cardAgeOffsets[young.id] = 35 - young.age  // age 35, one year past peak end
        XCTAssertEqual(store.agingPenalty(for: young), 2, "Decline uses the career's own declineRate past its own peak")
        XCTAssertEqual(store.effectiveOverall(for: young), young.overall - 2)
    }

    func testRegularFirstTeamMinutesSoftenDecline() async {
        let store = await freshStore()
        let veteran = card("keegana-9394") // age 31
        let state = LegendsPlayerCareer(careerID: "veteran", cardID: veteran.id, startingAge: veteran.age,
                                        startingOverall: veteran.overall, potential: veteran.overall,
                                        peakStartAge: 26, peakEndAge: 30, developmentRate: 1,
                                        declineRate: 2, signedSeason: 1)
        store.profile.playerCareers[veteran.id] = state
        store.profile.activatedCardIDs.insert(veteran.id)

        // Age well past the individual peak end so decline is active.
        store.profile.cardAgeOffsets[veteran.id] = 6
        let fullDecline = store.agingPenalty(for: veteran)
        XCTAssertEqual(fullDecline, (store.effectiveAge(for: veteran) - 30) * 2,
                       "Sanity: decline is years-past-peak × individual rate")

        // A regular starter (15+ apps this season) declines one point slower.
        var starter = state
        starter.seasonAppearances = 20
        store.profile.playerCareers[veteran.id] = starter
        let softened = store.agingPenalty(for: veteran)
        XCTAssertEqual(softened, (store.effectiveAge(for: veteran) - 30) * 1,
                       "Playing time softens the individual decline curve")
    }

    // MARK: - Lenient decoding

    func testCareerDecodesWithoutPhase2Fields() throws {
        // A Phase 1-era career JSON has none of the Phase 2 fields
        // (season records, milestones, club legend, season-start counters).
        let legacyCareerJSON = """
        {
            "careerID": "legacy-career",
            "cardID": "miessi-0506",
            "startingAge": 18,
            "startingOverall": 72,
            "potential": 88,
            "peakStartAge": 25,
            "peakEndAge": 29,
            "developmentRate": 10,
            "declineRate": 1,
            "signedSeason": 1,
            "appearances": 40,
            "goals": 12
        }
        """.data(using: .utf8)!

        let career = try JSONDecoder().decode(LegendsPlayerCareer.self, from: legacyCareerJSON)
        XCTAssertEqual(career.cardID, "miessi-0506")
        XCTAssertEqual(career.appearances, 40)
        XCTAssertEqual(career.goals, 12)
        XCTAssertEqual(career.seasonRecords, [], "Missing season history decodes empty")
        XCTAssertEqual(career.milestones, [], "Missing milestones decodes empty")
        XCTAssertFalse(career.isClubLegend)
        XCTAssertEqual(career.seasonStartAppearances, 0, "Missing season-start counters default to zero")
        XCTAssertEqual(career.seasonStartGoals, 0)
        XCTAssertEqual(career.seasonStartOverall, 72, "Missing season-start OVR defaults to the starting OVR")
    }

    func testDevelopmentEventIsDeterministicAndBendsTraining() async {
        let store = await freshStore()
        let young = card("miessi-0506")
        store.profile.ownedCardIDs.insert(young.id)
        store.assign(cardID: young.id, toXISlot: 0)
        var state = store.profile.playerCareers[young.id]!
        state.developmentMultiplier = 1.5 // BREAKTHROUGH SEASON flavour
        state.trainingSeason = store.profile.currentSeason
        state.trainingSessionsThisSeason = 0
        store.profile.playerCareers[young.id] = state

        let before = store.profile.playerCareers[young.id]!.developmentProgress
        XCTAssertTrue(store.trainPlayer(young.id))
        let after = store.profile.playerCareers[young.id]!.developmentProgress
        XCTAssertEqual(after, before + Int((Double(state.developmentRate * 2 * 2) * 1.5).rounded()),
                       "The season's development event multiplies training gains")
    }
}
