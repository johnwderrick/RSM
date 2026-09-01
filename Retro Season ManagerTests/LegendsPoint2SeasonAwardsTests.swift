import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsPoint2SeasonAwardsTests: XCTestCase {
    /// Fresh store with the starter profile stripped down to an empty club,
    /// mirroring the established retirement-timing fixture.
    private func store() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        store.profile.ownedCardIDs = []
        store.profile.activatedCardIDs = []
        store.profile.playerCareers = [:]
        store.profile.ownedPlayerRecords = [:]
        store.profile.legendsHall = []
        store.profile.cardAgeOffsets = [:]
        store.profile.matchesPlayedThisSeason = 0
        for index in store.profile.startingXICardIDs.indices {
            store.profile.startingXICardIDs[index] = nil
        }
        for index in store.profile.benchCardIDs.indices {
            store.profile.benchCardIDs[index] = nil
        }
        store.profile.captainCardID = nil
        return store
    }

    private func championResult(season: Int) -> LegendsDivisionSeasonResult {
        LegendsDivisionSeasonResult(season: season, finalRank: 1, totalTeams: 8,
                                    outcome: .champion, previousDivision: .division5,
                                    newDivision: .division4,
                                    reward: LegendsSeasonReward(coins: 300, tokens: 3, managerXP: 100))
    }

    /// A real `settleDivisionSeason()` result flows through
    /// `applyMatchOutcome` into `advanceSeasonIfNeeded(divisionResult:)`;
    /// calling that same entry point is the production award path.
    private func rollSeason(_ store: LegendsStore, divisionResult: LegendsDivisionSeasonResult?) -> LegendsSeasonAdvanceResult? {
        store.profile.matchesPlayedThisSeason = LegendsStore.matchesPerSeason - 1
        return store.advanceSeasonIfNeeded(divisionResult: divisionResult)
    }

    // MARK: - Team honours

    func testChampionSeasonGeneratesHonourOncePerSignedCareer() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.position.broad != .goalkeeper }!
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.intendedRetirementAge = 40
        store.profile.playerCareers[card.id] = career
        store.profile.cardAgeOffsets[card.id] = 0
        store.migrateOwnedPlayerRecords()

        let finishingSeason = store.profile.currentSeason
        let result = rollSeason(store, divisionResult: championResult(season: finishingSeason))

        XCTAssertNotNil(result)
        let state = store.profile.playerCareers[card.id]
        XCTAssertNotNil(state, "A champion-season player must stay active after the rollover")
        XCTAssertEqual(state?.honours.count, 1)
        XCTAssertEqual(state?.honours.first?.type, "LEAGUE CHAMPION")
        XCTAssertEqual(state?.honours.first?.season, finishingSeason)
        XCTAssertEqual(state?.honours.first?.careerID, career.careerID)
        XCTAssertEqual(state?.honours.first?.cardID, card.id)
        XCTAssertEqual(state?.condition.fame, LegendsPlayerCondition().fame + LegendsStore.fameForLeagueChampion)

        // Re-running the same season's finalisation duplicates nothing and
        // never re-grants fame.
        let inserted = store.finalizeSeasonAwards(divisionResult: championResult(season: finishingSeason),
                                                  finishingSeason: finishingSeason)
        XCTAssertTrue(inserted.isEmpty)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.honours.count, 1)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.condition.fame,
                       LegendsPlayerCondition().fame + LegendsStore.fameForLeagueChampion)
    }

    func testNonChampionSeasonGeneratesNoTeamHonour() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.position.broad != .goalkeeper }!
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.intendedRetirementAge = 40
        store.profile.playerCareers[card.id] = career
        store.profile.cardAgeOffsets[card.id] = 0
        store.migrateOwnedPlayerRecords()

        let retained = LegendsDivisionSeasonResult(season: store.profile.currentSeason, finalRank: 5,
                                                   totalTeams: 8, outcome: .retained,
                                                   previousDivision: .division5, newDivision: .division5,
                                                   reward: LegendsSeasonReward(coins: 100, tokens: 1, managerXP: 40))
        _ = rollSeason(store, divisionResult: retained)

        XCTAssertEqual(store.profile.playerCareers[card.id]?.honours, [])
        // A retained season still produces individual awards from real stats.
        XCTAssertTrue(store.profile.playerCareers[card.id]?.individualAwards.isEmpty == true,
                      "No appearances this season means no award eligibility")
    }

    // MARK: - Individual awards

    func testTopScorerAndPlayerOfSeasonComeFromRealSeasonAccumulators() async {
        let store = await store()
        guard let striker = LegendsCardDatabase.all.first(where: { $0.position.broad == .forward }),
              let defender = LegendsCardDatabase.all.first(where: { $0.position.broad == .defender }) else {
            return XCTFail("Database must contain forward and defender cards")
        }
        store.profile.ownedCardIDs = [striker.id, defender.id]
        store.profile.activatedCardIDs = [striker.id, defender.id]
        var strikerCareer = LegendsPlayerCareer(careerID: "career-a", cardID: striker.id,
                                                startingAge: striker.age, startingOverall: striker.overall,
                                                potential: striker.overall + 5, peakStartAge: 27, peakEndAge: 31,
                                                developmentRate: 5, declineRate: 1, signedSeason: 1)
        var defenderCareer = LegendsPlayerCareer(careerID: "career-b", cardID: defender.id,
                                                 startingAge: defender.age, startingOverall: defender.overall,
                                                 potential: defender.overall + 5, peakStartAge: 27, peakEndAge: 31,
                                                 developmentRate: 5, declineRate: 1, signedSeason: 1)
        defenderCareer.intendedRetirementAge = 40
        strikerCareer.intendedRetirementAge = 40
        store.profile.playerCareers = [striker.id: strikerCareer, defender.id: defenderCareer]
        store.profile.cardAgeOffsets = [striker.id: 0, defender.id: 0]
        store.migrateOwnedPlayerRecords()
        // The completed season's real accumulators, as recordCareerMatch
        // would have fed them: tied goals, defender with more volume.
        store.profile.playerCareers[striker.id]?.seasonGoals = 5
        store.profile.playerCareers[striker.id]?.seasonAppearances = 8
        store.profile.playerCareers[defender.id]?.seasonGoals = 5
        store.profile.playerCareers[defender.id]?.seasonAppearances = 12
        // The award's stored value is the production performance score of the
        // pre-rollover season; the rollover resets the accumulators after it.
        let defenderPotSScore = LegendsStore.playerOfTheSeasonScore(store.profile.playerCareers[defender.id]!)

        _ = rollSeason(store, divisionResult: nil)

        let strikerState = store.profile.playerCareers[striker.id]
        let defenderState = store.profile.playerCareers[defender.id]
        // Top Scorer tie (5 = 5) is broken by fewer appearances → striker.
        XCTAssertEqual(strikerState?.individualAwards.filter { $0.type == "TOP SCORER" }.count, 1)
        XCTAssertEqual(strikerState?.individualAwards.first { $0.type == "TOP SCORER" }?.value, 5)
        XCTAssertEqual(defenderState?.individualAwards.filter { $0.type == "TOP SCORER" }.count, 0)
        // Player of the Season score: defender 15+12=27 beats striker 15+8=23.
        XCTAssertEqual(defenderState?.individualAwards.filter { $0.type == "PLAYER OF THE SEASON" }.count, 1)
        XCTAssertEqual(defenderState?.individualAwards.first { $0.type == "PLAYER OF THE SEASON" }?.value,
                       defenderPotSScore)
        // closeSeason adds +2 fame only at 10+ appearances: striker 8 → 4,
        // defender 12 → 5 + 2.
        XCTAssertEqual(strikerState?.condition.fame, LegendsStore.fameForTopScorerAward)
        XCTAssertEqual(defenderState?.condition.fame, LegendsStore.fameForPlayerOfSeasonAward + 2)
    }

    func testFullyTiedSeasonBreaksWithStableCareerID() async {
        let store = await store()
        guard let striker = LegendsCardDatabase.all.first(where: { $0.position.broad == .forward }),
              let defender = LegendsCardDatabase.all.first(where: { $0.position.broad == .defender }) else {
            return XCTFail("Database must contain forward and defender cards")
        }
        store.profile.ownedCardIDs = [striker.id, defender.id]
        store.profile.activatedCardIDs = [striker.id, defender.id]
        var strikerCareer = LegendsPlayerCareer(careerID: "career-a", cardID: striker.id,
                                                startingAge: striker.age, startingOverall: striker.overall,
                                                potential: striker.overall + 5, peakStartAge: 27, peakEndAge: 31,
                                                developmentRate: 5, declineRate: 1, signedSeason: 1)
        var defenderCareer = LegendsPlayerCareer(careerID: "career-b", cardID: defender.id,
                                                 startingAge: defender.age, startingOverall: defender.overall,
                                                 potential: defender.overall + 5, peakStartAge: 27, peakEndAge: 31,
                                                 developmentRate: 5, declineRate: 1, signedSeason: 1)
        strikerCareer.intendedRetirementAge = 40
        defenderCareer.intendedRetirementAge = 40
        store.profile.playerCareers = [striker.id: strikerCareer, defender.id: defenderCareer]
        store.profile.cardAgeOffsets = [striker.id: 0, defender.id: 0]
        store.migrateOwnedPlayerRecords()
        store.profile.playerCareers[striker.id]?.seasonGoals = 5
        store.profile.playerCareers[striker.id]?.seasonAppearances = 10
        store.profile.playerCareers[defender.id]?.seasonGoals = 5
        store.profile.playerCareers[defender.id]?.seasonAppearances = 10

        _ = rollSeason(store, divisionResult: nil)

        // Identical stats: the smaller stable career ID ("career-a") wins
        // both awards, deterministically, regardless of dictionary order.
        let winner = store.profile.playerCareers[striker.id]
        XCTAssertEqual(winner?.individualAwards.filter { $0.type == "TOP SCORER" }.count, 1)
        XCTAssertEqual(winner?.individualAwards.filter { $0.type == "PLAYER OF THE SEASON" }.count, 1)
        XCTAssertTrue(store.profile.playerCareers[defender.id]?.individualAwards.isEmpty == true)
        // 10 appearances → closeSeason's +2 fame on top of both awards.
        XCTAssertEqual(winner?.condition.fame,
                       LegendsStore.fameForTopScorerAward + LegendsStore.fameForPlayerOfSeasonAward + 2)
    }

    // MARK: - Insertion protections

    func testInsertionProtectsUnsignedCardsAndClampsFame() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.position.broad != .goalkeeper }!
        let honour = LegendsHonour(id: "H-test-1", season: 1, competitionID: "legends.division.5",
                                   competitionName: "DIVISION 5 TITLE", type: "LEAGUE CHAMPION",
                                   clubName: store.profile.clubName, cardID: card.id, careerID: "career-1")

        // Owned but never activated → unsigned library card is frozen.
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = []
        XCTAssertFalse(store.insertHonour(honour, fameGain: LegendsStore.fameForLeagueChampion))
        XCTAssertNil(store.profile.playerCareers[card.id])

        // Active career at the fame ceiling clamps instead of overflowing.
        store.profile.activatedCardIDs = [card.id]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.intendedRetirementAge = 40
        career.condition.fame = 98
        store.profile.playerCareers[card.id] = career
        store.migrateOwnedPlayerRecords()
        XCTAssertTrue(store.insertHonour(honour, fameGain: LegendsStore.fameForLeagueChampion))
        XCTAssertEqual(store.profile.playerCareers[card.id]?.condition.fame, 100)
        // Duplicate IDs never re-grant fame.
        XCTAssertFalse(store.insertHonour(honour, fameGain: LegendsStore.fameForLeagueChampion))
        XCTAssertEqual(store.profile.playerCareers[card.id]?.condition.fame, 100)
        // A second, distinct honour accumulates normally.
        let second = LegendsHonour(id: "H-test-2", season: 2, competitionID: "legends.division.4",
                                   competitionName: "DIVISION 4 TITLE", type: "LEAGUE CHAMPION",
                                   clubName: store.profile.clubName, cardID: card.id, careerID: career.careerID)
        XCTAssertTrue(store.insertHonour(second, fameGain: LegendsStore.fameForLeagueChampion))
        XCTAssertEqual(store.profile.playerCareers[card.id]?.honours.count, 2)
        XCTAssertEqual(store.profile.playerCareers[card.id]?.condition.fame, 100)
    }

    // MARK: - Award-then-retire ordering

    func testFinalSeasonRetireeBanksAwardsBeforeArchival() async {
        let store = await store()
        let card = LegendsCardDatabase.all.first { $0.id == "miessi-0506" }!
        store.profile.ownedCardIDs = [card.id]
        store.profile.activatedCardIDs = [card.id]
        var career = LegendsStore.makeCareerState(for: card, signedSeason: 1)
        career.intendedRetirementAge = 35
        store.profile.playerCareers[card.id] = career
        store.profile.cardAgeOffsets[card.id] = 34 - card.age
        store.migrateOwnedPlayerRecords()
        store.profile.playerCareers[card.id]?.seasonGoals = 5
        store.profile.playerCareers[card.id]?.seasonAppearances = 10
        store.profile.startingXICardIDs[0] = card.id
        store.profile.captainCardID = card.id

        let finishingSeason = store.profile.currentSeason
        let result = rollSeason(store, divisionResult: championResult(season: finishingSeason))

        XCTAssertEqual(result?.retiredCards.map(\.id), [card.id])
        XCTAssertEqual(store.profile.legendsHall.filter { $0.cardID == card.id }.count, 1)
        guard let entry = store.profile.legendsHall.first else { return XCTFail("Alumni record must exist") }
        // Achievements generated before archival land in the Hall snapshot.
        XCTAssertEqual(entry.honours.count, 1)
        XCTAssertEqual(entry.honours.first?.type, "LEAGUE CHAMPION")
        XCTAssertTrue(entry.individualAwards.contains { $0.type == "TOP SCORER" && $0.value == 5 })
        XCTAssertTrue(entry.individualAwards.contains { $0.type == "PLAYER OF THE SEASON" })
        XCTAssertEqual(entry.finalCondition.fame,
                       LegendsStore.fameForLeagueChampion + LegendsStore.fameForTopScorerAward
                       + LegendsStore.fameForPlayerOfSeasonAward)
        XCTAssertEqual(entry.honours.first?.season, finishingSeason)
        // Re-running the same season's finalisation creates nothing further.
        let inserted = store.finalizeSeasonAwards(divisionResult: championResult(season: finishingSeason),
                                                  finishingSeason: finishingSeason)
        XCTAssertTrue(inserted.isEmpty)
        XCTAssertEqual(store.profile.legendsHall.filter { $0.cardID == card.id }.count, 1)
        XCTAssertFalse(store.profile.ownedCardIDs.contains(card.id),
                       "A retired card never returns to the active collection")
    }

    // MARK: - Condition integration through recordCareerMatch

    func testRecordedGoalsAndAssistsFeedConditionExactlyOncePerContribution() async {
        let store = await store()
        guard let striker = LegendsCardDatabase.all.first(where: { $0.position.broad == .forward }),
              let creator = LegendsCardDatabase.all.first(where: { $0.position.broad == .midfielder }),
              let keeper = LegendsCardDatabase.all.first(where: { $0.position.broad == .goalkeeper }) else {
            return XCTFail("Database must contain forward, midfielder and goalkeeper cards")
        }
        store.profile.ownedCardIDs = [striker.id, creator.id, keeper.id]
        store.profile.activatedCardIDs = [striker.id, creator.id, keeper.id]
        store.profile.startingXICardIDs[0] = striker.id
        store.profile.startingXICardIDs[1] = creator.id
        store.profile.startingXICardIDs[2] = keeper.id

        // Two completed matches, one goal and a clean sheet in each. The
        // engine's goal distribution gives one goal per XI forward per match,
        // so two matches prove every contribution lands exactly once.
        store.recordCareerMatch(LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 0))
        store.recordCareerMatch(LegendsMatchEngine.Result(teamGoals: 1, opponentGoals: 0))

        // Striker: two wins (2×3) + two goals (2×3 form, 2×1 morale, 2×1 fame).
        let strikerState = store.profile.playerCareers[striker.id]
        XCTAssertEqual(strikerState?.appearances, 2)
        XCTAssertEqual(strikerState?.goals, 2)
        XCTAssertEqual(strikerState?.seasonGoals, 2)
        XCTAssertEqual(strikerState?.condition.form, 50 + 6 + 6)
        XCTAssertEqual(strikerState?.condition.morale, 50 + 6 + 2)
        XCTAssertEqual(strikerState?.condition.fame, 2)
        // Creator: two wins (2×3) + two assists (2×2 form, 2×1 morale, 2×1 fame).
        let creatorState = store.profile.playerCareers[creator.id]
        XCTAssertEqual(creatorState?.assists, 2)
        XCTAssertEqual(creatorState?.seasonAssists, 2)
        XCTAssertEqual(creatorState?.condition.form, 50 + 6 + 4)
        XCTAssertEqual(creatorState?.condition.fame, 2)
        // Keeper: two wins + two clean sheets (+2 form, +1 fame each) once per match.
        let keeperState = store.profile.playerCareers[keeper.id]
        XCTAssertEqual(keeperState?.cleanSheets, 2)
        XCTAssertEqual(keeperState?.seasonCleanSheets, 2)
        XCTAssertEqual(keeperState?.condition.form, 50 + 6 + 4)
        XCTAssertEqual(keeperState?.condition.fame, 2)
        // Teamwork grows once per appearance, not per contribution.
        XCTAssertEqual(keeperState?.condition.teamwork, 27)
    }
}
