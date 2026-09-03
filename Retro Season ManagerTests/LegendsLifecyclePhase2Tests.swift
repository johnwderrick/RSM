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
        store.signAllOwnedCardsForTesting()
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
        store.startCareerIfNeeded(for: young)
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
        // Signing/assigning alone doesn't create a career record (see
        // `startCareerIfNeeded`); force it now so we can read the
        // deterministic, profile-specific retirement target the lifecycle
        // system actually assigned this card, instead of assuming the old
        // fixed `LegendsStore.retirementAge` still applies to every player.
        store.startCareerIfNeeded(for: young)
        guard let targetAge = store.profile.playerCareers[young.id]?.intendedRetirementAge else {
            XCTFail("Expected a persisted career state with an intended retirement age for \(young.id)")
            return
        }
        // Age to the season before the retirement cutoff, then roll two
        // full seasons: the announcement season, then the retiring one.
        store.profile.cardAgeOffsets[young.id] = targetAge - 2 - young.age
        var result: LegendsSeasonAdvanceResult?
        for _ in 0..<(LegendsStore.matchesPerSeason * 2) {
            result = store.advanceSeasonIfNeeded() ?? result
        }
        XCTAssertEqual(store.profile.legendsHall.count, 1)
        let entry = store.profile.legendsHall.first
        XCTAssertEqual(entry?.playerName, young.name)
        XCTAssertGreaterThan(entry?.legacyScore ?? 0, 0, "A completed career must produce a Legacy Score")
        XCTAssertEqual(entry?.finalAge, targetAge)
        XCTAssertFalse(entry?.careerHistory.isEmpty ?? true, "Hall entries carry the full season history")

        // A second, lesser career ranks below the first by Legacy Score.
        let other = card("renaldo-0405")
        store.profile.ownedCardIDs.insert(other.id)
        store.profile.playerCareers[other.id] = LegendsStore.makeCareerState(for: other, signedSeason: store.profile.currentSeason)
        store.profile.activatedCardIDs.insert(other.id)
        store.profile.playerCareers[other.id]!.intendedRetirementAge = LegendsStore.retirementAge
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
                                           signedSeason: 1,
                                           condition: LegendsPlayerCondition(form: 50, morale: 50, teamwork: 50, fame: 0))
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
        let baselineStore = await freshStore()
        let boostedStore = await freshStore()
        let young = card("miessi-0506")
        var sharedState = LegendsStore.makeCareerState(for: young, signedSeason: baselineStore.profile.currentSeason)
        sharedState.condition = LegendsPlayerCondition(form: 50, morale: 50, teamwork: 50, fame: 0)
        for store in [baselineStore, boostedStore] {
            store.profile.ownedCardIDs = [young.id]
            store.profile.activatedCardIDs = [young.id]
            store.profile.ownedPlayerRecords = [:]
            store.signAllOwnedCardsForTesting()
            store.profile.playerCareers[young.id] = sharedState
        }
        boostedStore.profile.playerCareers[young.id]!.developmentMultiplier = 1.5

        XCTAssertTrue(baselineStore.trainPlayer(young.id))
        XCTAssertTrue(boostedStore.trainPlayer(young.id))
        let baseline = baselineStore.profile.playerCareers[young.id]!.developmentProgress
        let boosted = boostedStore.profile.playerCareers[young.id]!.developmentProgress
        XCTAssertGreaterThan(boosted, baseline, "A 1.5× lifecycle event should bend bounded training upward")

        let repeated = await freshStore()
        repeated.profile.ownedCardIDs = [young.id]
        repeated.profile.activatedCardIDs = [young.id]
        repeated.profile.ownedPlayerRecords = [:]
        repeated.signAllOwnedCardsForTesting()
        var repeatedState = sharedState
        repeatedState.developmentMultiplier = 1.5
        repeated.profile.playerCareers[young.id] = repeatedState
        XCTAssertTrue(repeated.trainPlayer(young.id))
        XCTAssertEqual(repeated.profile.playerCareers[young.id]?.developmentProgress, boosted,
                       "Fixed career inputs must produce identical bounded progress")
    }
}

@MainActor
final class LegendsPoint3TrainingTests: XCTestCase {
    private func isolatedStore(for card: LegendsCard, career: LegendsPlayerCareer? = nil) async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        store.profile.playerCareers = [:]
        store.profile.ownedPlayerRecords = [:]
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.legendsHall = []
        store.profile.seasonReports = [:]
        store.profile.cardAgeOffsets = [:]
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = 0
        store.signAllOwnedCardsForTesting()
        var state = career ?? LegendsStore.makeCareerState(for: card, signedSeason: 1)
        state.condition = LegendsPlayerCondition(form: 50, morale: 50, teamwork: 50, fame: 0)
        store.profile.playerCareers[card.id] = state
        return store
    }

    private var outfielder: LegendsCard {
        LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
    }

    private var goalkeeper: LegendsCard {
        LegendsCardDatabase.all.first { $0.position.broad == .goalkeeper && $0.age < 25 }!
    }

    func testLegacyCareerDefaultsToBalancedNormalPlanWithoutInventedHistory() throws {
        let json = """
        {"careerID":"legacy","cardID":"legacy-card","startingAge":20,"startingOverall":70,
         "potential":80,"peakStartAge":25,"peakEndAge":30,"developmentRate":8,"declineRate":1,"signedSeason":1}
        """.data(using: .utf8)!
        let career = try JSONDecoder().decode(LegendsPlayerCareer.self, from: json)
        XCTAssertEqual(career.trainingPlan.focus, .balanced)
        XCTAssertEqual(career.trainingPlan.intensity, .normal)
        XCTAssertTrue(career.trainingPlan.history.isEmpty)
        XCTAssertEqual(career.developedAttributes, .zero)
    }

    func testUnsignedPlayerCannotReceiveAPlanOrTrainingProgress() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        store.profile.activatedCardIDs = []
        store.profile.playerCareers = [:]
        XCTAssertFalse(store.trainPlayer(card.id))
        XCTAssertFalse(store.setDevelopmentFocus(.shooting, for: card.id))
        XCTAssertNil(store.trainingPlan(for: card))
    }

    func testFocusIntensityAndSessionsPersistOnTheCareer() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        XCTAssertTrue(store.setDevelopmentFocus(.passing, for: card.id))
        XCTAssertTrue(store.setTrainingIntensity(.intensive, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let career = store.profile.playerCareers[card.id]!
        XCTAssertEqual(career.trainingPlan.focus, .passing)
        XCTAssertEqual(career.trainingPlan.intensity, .intensive)
        XCTAssertEqual(career.trainingSessionsThisSeason, 1)
        XCTAssertEqual(career.trainingSessions, 1)
        XCTAssertEqual(career.trainingPlan.history.count, 1)
        XCTAssertLessThan(career.condition.form, 50)
    }

    func testPassingFocusMutatesRelevantDetailedAttributesUsedByProductionAccessor() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        let before = store.detailedAttributes(for: card)
        XCTAssertTrue(store.setDevelopmentFocus(.passing, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let after = store.detailedAttributes(for: card)
        let improved = ["Passing", "Vision", "Decisions", "Crossing"].filter {
            after.value(for: $0) > before.value(for: $0)
        }
        XCTAssertFalse(improved.isEmpty)
        XCTAssertEqual(store.effectiveDetailedAttributes(for: card).passing,
                       min(99, after.passing + store.formBoost(for: card)))
        XCTAssertEqual(LegendsIdentityEngine.profile(for: card).attributes, before,
                       "The immutable base identity attributes must not be rewritten")
    }

    func testOutfielderCannotSelectGoalkeepingFocusOrGainGoalkeepingAttributes() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        let before = store.detailedAttributes(for: card)
        XCTAssertFalse(store.setDevelopmentFocus(.goalkeeping, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let after = store.detailedAttributes(for: card)
        XCTAssertEqual(after.handling, before.handling)
        XCTAssertEqual(after.reflexes, before.reflexes)
        XCTAssertEqual(after.goalkeeperPositioning, before.goalkeeperPositioning)
    }

    func testGoalkeeperTrainingImprovesGoalkeepingAttributes() async {
        let card = goalkeeper
        let store = await isolatedStore(for: card)
        let before = store.detailedAttributes(for: card)
        XCTAssertTrue(store.setDevelopmentFocus(.goalkeeping, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let after = store.detailedAttributes(for: card)
        let improved = ["Handling", "Reflexes", "One-on-ones", "Goalkeeper positioning", "Aerial reach", "Distribution"].filter {
            after.value(for: $0) > before.value(for: $0)
        }
        XCTAssertFalse(improved.isEmpty)
    }

    func testFourthSessionIsRejectedAndConditionRemainsBounded() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        XCTAssertTrue(store.setTrainingIntensity(.intensive, for: card.id))
        for _ in 0..<LegendsStore.maxTrainingSessionsPerSeason { XCTAssertTrue(store.trainPlayer(card.id)) }
        let afterThree = store.profile.playerCareers[card.id]!
        XCTAssertFalse(store.trainPlayer(card.id))
        let afterFour = store.profile.playerCareers[card.id]!
        XCTAssertEqual(afterFour.trainingSessions, afterThree.trainingSessions)
        XCTAssertTrue((0...100).contains(afterFour.condition.form))
        XCTAssertTrue((0...100).contains(afterFour.condition.morale))
        XCTAssertTrue((0...100).contains(afterFour.condition.teamwork))
        for group in LegendsAttributeGroup.allCases {
            XCTAssertTrue(store.detailedAttributes(for: card).values(in: group).allSatisfy { (0...99).contains($0.1) })
        }
    }

    func testSeasonReportSnapshotsTrainingAndResetsOnlySeasonCounters() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        XCTAssertTrue(store.setDevelopmentFocus(.dribbling, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let lifetimeSessions = store.profile.playerCareers[card.id]!.trainingSessions
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        _ = store.advanceSeasonIfNeeded()
        let entry = store.profile.seasonReports[1]?.entries.first { $0.cardID == card.id }
        XCTAssertEqual(entry?.trainingFocus, .dribbling)
        XCTAssertEqual(entry?.trainingSessions, 1)
        XCTAssertFalse(entry?.trainingAttributeGains.isEmpty ?? true)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.trainingSessionsThisSeason, 0)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.trainingSessions, lifetimeSessions)
    }

    func testRetirementPreservesFinalPlanHistoryAndAttributesInAlumni() async {
        let card = outfielder
        let store = await isolatedStore(for: card)
        XCTAssertTrue(store.setDevelopmentFocus(.shooting, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let trained = store.detailedAttributes(for: card)
        let targetAge = store.profile.playerCareers[card.id]!.intendedRetirementAge
        store.profile.cardAgeOffsets[card.id] = targetAge - 1 - card.age
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        _ = store.advanceSeasonIfNeeded()
        let alumni = store.profile.legendsHall.first { $0.cardID == card.id }
        XCTAssertEqual(alumni?.finalTrainingPlan.focus, .shooting)
        XCTAssertEqual(alumni?.finalTrainingPlan.history.count, 1)
        XCTAssertEqual(alumni?.finalDetailedAttributes, trained)
        XCTAssertNil(store.profile.playerCareers[card.id])
        XCTAssertFalse(store.trainPlayer(card.id))
    }

    func testCurrentCareerRoundTripPreservesPlanAndDevelopedAttributes() async throws {
        let card = outfielder
        let store = await isolatedStore(for: card)
        XCTAssertTrue(store.setDevelopmentFocus(.physical, for: card.id))
        XCTAssertTrue(store.trainPlayer(card.id))
        let original = store.profile.playerCareers[card.id]!
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegendsPlayerCareer.self, from: data)
        XCTAssertEqual(decoded.trainingPlan, original.trainingPlan)
        XCTAssertEqual(decoded.developedAttributes, original.developedAttributes)
        XCTAssertEqual(decoded.trainingSessionsThisSeason, 1)
    }

    func testYoungPlayerAndRegularMinutesIncreaseTrainingEfficiency() async {
        let card = outfielder
        let baselineStore = await isolatedStore(for: card)
        let sharedCareer = baselineStore.profile.playerCareers[card.id]!
        let inactive = await isolatedStore(for: card, career: sharedCareer)
        let regular = await isolatedStore(for: card, career: sharedCareer)
        regular.profile.playerCareers[card.id]!.seasonAppearances = 8
        XCTAssertTrue(inactive.trainPlayer(card.id))
        XCTAssertTrue(regular.trainPlayer(card.id))
        XCTAssertGreaterThan(regular.profile.playerCareers[card.id]!.developmentProgress,
                             inactive.profile.playerCareers[card.id]!.developmentProgress)

        let veteran = await isolatedStore(for: card, career: sharedCareer)
        veteran.profile.cardAgeOffsets[card.id] = max(0, veteran.profile.playerCareers[card.id]!.peakEndAge + 1 - card.age)
        XCTAssertTrue(veteran.trainPlayer(card.id))
        XCTAssertGreaterThan(inactive.profile.playerCareers[card.id]!.developmentProgress,
                             veteran.profile.playerCareers[card.id]!.developmentProgress)
    }

    func testPlayerAtPotentialCannotGenerateFurtherGrowth() async {
        let card = outfielder
        let ceilingCareer = LegendsPlayerCareer(
            careerID: "at-ceiling", cardID: card.id, startingAge: card.age,
            startingOverall: card.overall, potential: card.overall,
            peakStartAge: 25, peakEndAge: 30, developmentRate: 10,
            declineRate: 1, signedSeason: 1,
            condition: LegendsPlayerCondition(form: 50, morale: 50, teamwork: 50, fame: 0)
        )
        let store = await isolatedStore(for: card, career: ceilingCareer)
        let before = store.detailedAttributes(for: card)
        XCTAssertTrue(store.trainPlayer(card.id), "A maintenance session is still consumed at the ceiling")
        let state = store.profile.playerCareers[card.id]!
        XCTAssertEqual(state.developmentProgress, 0)
        XCTAssertEqual(state.developedAttributes, .zero)
        XCTAssertEqual(store.detailedAttributes(for: card), before)
        XCTAssertEqual(state.trainingSessionsThisSeason, 1)
    }

    func testFocusTargetsArePositionAppropriateAndNeverMixGoalkeepingForOutfielders() {
        let card = outfielder
        let archetype = LegendsIdentityEngine.profile(for: card).identity.archetype
        for focus in LegendsDevelopmentFocus.allCases where focus != .goalkeeping {
            let targets = LegendsStore.focusTargets(focus, for: card, archetype: archetype)
            XCTAssertFalse(targets.isEmpty, "\(focus.rawValue) should have outfield targets")
            XCTAssertTrue(Set(targets).isDisjoint(with: ["Handling", "Reflexes", "One-on-ones", "Aerial reach", "Distribution", "Goalkeeper positioning"]))
        }
        XCTAssertTrue(LegendsStore.focusTargets(.goalkeeping, for: card, archetype: archetype).isEmpty)
    }

    func testLegacyReportAndAlumniDecodeWithSafeTrainingDefaults() throws {
        let reportJSON = """
        {"cardID":"legacy","playerName":"Legacy Player","completedSeason":2,
         "ageBefore":24,"ageAfter":25,"overallBefore":75,"overallAfter":76,
         "previousStage":"ACTIVE","newStage":"ACTIVE"}
        """.data(using: .utf8)!
        let report = try JSONDecoder().decode(LegendsSeasonReportEntry.self, from: reportJSON)
        XCTAssertEqual(report.trainingFocus, .balanced)
        XCTAssertEqual(report.trainingIntensity, .normal)
        XCTAssertEqual(report.trainingSessions, 0)
        XCTAssertTrue(report.trainingAttributeGains.isEmpty)

        let alumni = try JSONDecoder().decode(LegendsHallEntry.self, from: Data("{}".utf8))
        XCTAssertEqual(alumni.finalTrainingPlan.focus, .balanced)
        XCTAssertTrue(alumni.finalTrainingPlan.history.isEmpty)
        XCTAssertEqual(alumni.finalDetailedAttributes, .zero)
    }
}
