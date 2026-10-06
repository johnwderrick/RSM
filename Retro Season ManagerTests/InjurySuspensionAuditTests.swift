//
//  InjurySuspensionAuditTests.swift
//  Retro Season ManagerTests
//
//  Focused regression coverage for the Career injury & suspension audit
//  (branch freebuff/injury-suspension-audit). Every test isolates its own
//  save (newGame writes one; deleteSave in tearDown) and drives the real
//  engine paths — no hand-rolled match maths:
//
//  1. Eligibility: manual selection (toggleStarter / assignStarter),
//     auto-pick (autoPickLineup / smartAutoPick) and the pre-match
//     preview XI (matchXIForPreview -> userStartingXI) all keep injured
//     and suspended players off the pitch, with the side staying valid.
//  2. Recovery: one advanceWeek() heals one week / serves one match of
//     ban — the documented model — and the force-simmed league day
//     (resolveTodaysUserMatchAbstractly -> forceResolveLeagueDay) must
//     advance recovery exactly like the live league commit does.
//  3. Captain & set-piece coherence: a banned captain keeps the armband
//     (he's still employed), a departed one gets a squad replacement,
//     and a live match never resolves a penalty to a sent-off taker.
//  4. Persistence: injuries, suspensions and the hand-picked XI survive
//     persist() -> loadSavedGame() unchanged.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class InjurySuspensionAuditTests: XCTestCase {

    // MARK: - Fixtures

    /// A real saved career with deterministic availability: a fully fit
    /// squad everywhere (newGame's seedInjuries() roll is undone) so the
    /// only unavailable players are the ones each test scripts.
    private func makeFitSquadStore(name: String) async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2010, managerName: name)
        guard let id = store.currentSaveID else {
            XCTFail("newGame() did not set currentSaveID")
            return store
        }
        deferredSaves.append(id)
        for clubIndex in store.clubs.indices {
            for index in store.clubs[clubIndex].players.indices {
                store.clubs[clubIndex].players[index].injuryWeeks = 0
                store.clubs[clubIndex].players[index].suspensionMatches = 0
            }
        }
        return store
    }

    /// deleteSave happens after the test body returns, whichever way it
    /// returns — no real save is ever touched (newGame made its own ID).
    private var deferredSaves: [UUID] = []
    override func tearDown() {
        for id in deferredSaves { GameStore.deleteSave(id: id) }
        deferredSaves = []
        super.tearDown()
    }

    /// Applies a change to the squad player with the given id in place.
    private func mutate(_ store: GameStore, id: UUID, _ change: (inout Player) -> Void) {
        guard let index = store.clubs[store.userClubIndex].players.firstIndex(where: { $0.id == id }) else {
            XCTFail("Player \(id) not found in the user's squad")
            return
        }
        change(&store.clubs[store.userClubIndex].players[index])
    }

    /// The user's squad players for one broad position, best first.
    private func squad(_ store: GameStore, position: Position) -> [Player] {
        store.userClub.players
            .filter { $0.position == position }
            .sorted { $0.rating > $1.rating }
    }

    // MARK: - Eligibility: manual selection

    func testManualSelectionBlocksInjuredAndSuspendedPlayers() async {
        let store = await makeFitSquadStore(name: "Eligibility Tester")
        // newGame auto-picks a full XI (assigning `formation` inside newGame
        // fires its didSet, which calls autoPickLineup) — clear it so the
        // toggle path under test is the ADD path with its availability guards.
        store.clearLineup()
        XCTAssertTrue(store.userStarterIDs.isEmpty)
        let injuredID = squad(store, position: .defender)[0].id
        let suspendedID = squad(store, position: .midfielder)[0].id
        mutate(store, id: injuredID) { $0.injuryWeeks = 3 }
        mutate(store, id: suspendedID) { $0.suspensionMatches = 2 }
        // Selection APIs take player VALUES, so fetch fresh copies after
        // mutating — a stale pre-mutation copy would dodge the guards.
        guard let injured = store.clubs[store.userClubIndex].players.first(where: { $0.id == injuredID }),
              let suspended = store.clubs[store.userClubIndex].players.first(where: { $0.id == suspendedID }) else {
            return XCTFail("Tracked players vanished from the squad")
        }

        func assertBlocked(_ change: GameStore.SelectionChange, _ label: String) {
            guard case .blocked = change else {
                XCTFail("\(label) must be blocked, got \(change)")
                return
            }
        }
        assertBlocked(store.toggleStarter(injured), "Selecting an injured player")
        assertBlocked(store.toggleStarter(suspended), "Selecting a suspended player")
        assertBlocked(store.assignStarter(injured, forRole: .centreBack), "Assigning an injured player")
        assertBlocked(store.assignStarter(suspended, forRole: .centralMid), "Assigning a suspended player")
        XCTAssertFalse(store.userStarterIDs.contains(injured.id), "Injured player must stay out of the XI")
        XCTAssertFalse(store.userStarterIDs.contains(suspended.id), "Suspended player must stay out of the XI")
    }

    func testManualSelectionStillAllowsRemovingAnInjuredStarter() async {
        let store = await makeFitSquadStore(name: "Eligibility Tester")
        store.autoPickLineup()
        let starter = squad(store, position: .defender).first { store.userStarterIDs.contains($0.id) }
        guard let starter else { return XCTFail("No defender in the auto-picked XI") }
        mutate(store, id: starter.id) { $0.injuryWeeks = 2 }

        guard case .removed = store.toggleStarter(starter) else {
            XCTFail("Taking an injured player OUT of the XI must still work")
            return
        }
    }

    func testAssignStarterBlockedForUnavailablePlayerLeavesSlotUntouched() async {
        let store = await makeFitSquadStore(name: "Eligibility Tester")
        store.autoPickLineup()
        let keeperID = squad(store, position: .goalkeeper)[0].id
        mutate(store, id: keeperID) { $0.suspensionMatches = 1 }
        guard let keeper = store.clubs[store.userClubIndex].players.first(where: { $0.id == keeperID }) else {
            return XCTFail("Tracked player vanished from the squad")
        }

        guard case .blocked = store.assignStarter(keeper, forRole: .goalkeeper) else {
            XCTFail("A suspended keeper must not be assignable")
            return
        }
        let xi = store.userStartingXI()
        XCTAssertTrue(store.isValidLineup(xi), "A blocked assignment must leave a valid side standing")
        XCTAssertFalse(xi.contains { $0.id == keeper.id }, "The suspended keeper must not be fielded")
    }

    // MARK: - Eligibility: auto-pick and saved lineups

    func testAutoPickKeepsUnavailablePlayersOutAndFillsAValidSide() async {
        let store = await makeFitSquadStore(name: "Auto Pick Tester")
        store.autoPickLineup()
        let bestXIids = Set(store.bestXI(for: store.userClub, formation: store.formation).map { $0.id })
        let fringe = squad(store, position: .defender).first { !bestXIids.contains($0.id) }
        guard let fringe else { return XCTFail("Expected a fringe defender outside the best XI") }
        mutate(store, id: fringe.id) { $0.injuryWeeks = 4 }

        store.autoPickLineup()
        let xi = store.userStartingXI()
        XCTAssertFalse(store.userStarterIDs.contains(fringe.id), "Auto-pick must skip the injured fringe player")
        XCTAssertTrue(store.isValidLineup(xi), "Auto-pick must still produce a valid side")
        XCTAssertEqual(xi.count, 11)
    }

    func testSmartAutoPickKeepsUnavailablePlayersOut() async {
        let store = await makeFitSquadStore(name: "Smart Auto Pick Tester")
        store.autoPickLineup()
        let bestXIids = Set(store.bestXI(for: store.userClub, formation: store.formation).map { $0.id })
        let fringe = squad(store, position: .midfielder).first { !bestXIids.contains($0.id) }
        guard let fringe else { return XCTFail("Expected a fringe midfielder outside the best XI") }
        mutate(store, id: fringe.id) { $0.suspensionMatches = 3 }
        store.autoPickAssist = true

        store.smartAutoPick()
        XCTAssertFalse(store.userStarterIDs.contains(fringe.id), "The assistant must never pick a suspended player")
        XCTAssertTrue(store.isValidLineup(store.userStartingXI()))
    }

    /// A saved lineup whose player is now unavailable (the classic "star
    /// got injured between matches" case) must fall back to a full, valid
    /// best XI rather than fielding the injured starter short-handed —
    /// and the pre-match preview must agree with the engine.
    func testSavedLineupDropsNewlyInjuredStarterAndStaysValid() async {
        let store = await makeFitSquadStore(name: "Saved Lineup Tester")
        store.autoPickLineup()
        let star = squad(store, position: .forward)[0]
        mutate(store, id: star.id) { $0.injuryWeeks = 5 }

        let xi = store.userStartingXI()
        XCTAssertFalse(xi.contains { $0.id == star.id }, "An injured starter must be dropped from the fielded XI")
        XCTAssertTrue(store.isValidLineup(xi), "The fielded XI must stay valid after dropping the injured starter")

        let preview = store.matchXIForPreview(store.userClubIndex)
        XCTAssertFalse(preview.contains { $0.id == star.id }, "The pre-match preview must agree with the engine")
    }

    // MARK: - Recovery timing

    func testAdvanceWeekHealsOneWeekAndServesOneMatchOfBan() async {
        let store = await makeFitSquadStore(name: "Recovery Tester")
        let injuredID = squad(store, position: .defender)[0].id
        let suspendedID = squad(store, position: .midfielder)[0].id
        mutate(store, id: injuredID) { $0.injuryWeeks = 2 }
        mutate(store, id: suspendedID) { $0.suspensionMatches = 1 }

        // advanceWeek heals one week AND may roll a fresh training-ground
        // knock (~30% per club — the pass decrements first, then rolls, so
        // a healed player can be re-injured the same pass). The player's
        // own `injuriesThisSeason` counter discriminates a pure heal from
        // a re-injury: unchanged counter => exactly one week healed.
        func snapshot(_ store: GameStore, _ id: UUID) -> (weeks: Int, knocks: Int) {
            guard let p = store.clubs[store.userClubIndex].players.first(where: { $0.id == id }) else {
                XCTFail("Tracked player vanished from the squad")
                return (-1, -1)
            }
            return (p.injuryWeeks, p.injuriesThisSeason)
        }
        func assertHealedOneWeek(_ before: (weeks: Int, knocks: Int), _ after: (weeks: Int, knocks: Int), _ label: String) {
            if after.knocks == before.knocks {
                XCTAssertEqual(after.weeks, before.weeks - 1, label)
            } else {
                XCTAssertGreaterThanOrEqual(after.weeks, 1,
                    "\(label) — a fresh training knock re-injured him this pass")
            }
        }

        let before1 = snapshot(store, injuredID)
        store.advanceWeek()
        assertHealedOneWeek(before1, snapshot(store, injuredID),
                            "One advanceWeek must heal exactly one injury week (absent a fresh knock)")
        guard let suspendedNow = store.clubs[store.userClubIndex].players.first(where: { $0.id == suspendedID }) else {
            return XCTFail("Tracked player vanished from the squad")
        }
        XCTAssertEqual(suspendedNow.suspensionMatches, 0, "One advanceWeek must serve exactly one match of a ban")

        let before2 = snapshot(store, injuredID)
        store.advanceWeek()
        assertHealedOneWeek(before2, snapshot(store, injuredID),
                            "A second advanceWeek must heal another week (absent a fresh knock)")
    }

    /// The force-simmed league day (Calendar "SIM TO DATE"/"FORCE SIM",
    /// which resolves the user's match through resolveTodaysUserMatchAbstractly
    /// -> forceResolveLeagueDay) must advance recovery exactly like the live
    /// league commit does — its own doc comment promises it mirrors
    /// finishLiveMatch(), which calls advanceWeek() after the round.
    func testForceSimmedLeagueDayAdvancesRecoveryLikeLiveCommit() async {
        let store = await makeFitSquadStore(name: "Force Sim Tester")
        let injured = squad(store, position: .defender)[0]
        let suspended = squad(store, position: .forward)[0]
        mutate(store, id: injured.id) { $0.injuryWeeks = 2 }
        mutate(store, id: suspended.id) { $0.suspensionMatches = 1 }
        store.autoPickLineup()

        // Walk the real calendar to the user's next fixture without ever
        // playing a match — the same loop CONTINUE/SKIP TO MATCH runs.
        // The first matchday a fresh season reaches is league matchday 1.
        var safety = 0
        while !store.isSeasonOver && !store.isUserMatchToday && safety < 60 {
            store.advanceDay()
            safety += 1
        }
        XCTAssertTrue(store.isUserMatchToday, "Walked the calendar without reaching a user match day")

        // Every day BEFORE the match is a quiet one: recovery must not
        // move until the matchday itself is resolved.
        let weeksBefore = store.clubs[store.userClubIndex].players.first { $0.id == injured.id }?.injuryWeeks
        XCTAssertEqual(weeksBefore, 2, "Quiet days must not heal injuries early")

        store.resolveTodaysUserMatchAbstractly()

        guard let injuredAfter = store.clubs[store.userClubIndex].players.first(where: { $0.id == injured.id }),
              let suspendedAfter = store.clubs[store.userClubIndex].players.first(where: { $0.id == suspended.id }) else {
            return XCTFail("Tracked players vanished from the squad")
        }
        XCTAssertEqual(injuredAfter.injuryWeeks, 1,
                       "A force-simmed league day must heal one injury week, exactly like finishLiveMatch's advanceWeek")
        XCTAssertEqual(suspendedAfter.suspensionMatches, 0,
                       "A force-simmed league day must serve one match of a ban, exactly like finishLiveMatch's advanceWeek")

        // And the next fixture must be reachable the same way — proving
        // the day actually advanced (the fixture was played, not skipped).
        var safety2 = 0
        while !store.isSeasonOver && !store.isUserMatchToday && safety2 < 60 {
            store.advanceDay()
            safety2 += 1
        }
        XCTAssertTrue(store.isUserMatchToday || store.isSeasonOver,
                      "After a resolved matchday the calendar must reach the next one")
    }

    // MARK: - Captain & set-piece coherence

    /// A banned captain keeps the armband — he's still employed by the
    /// club and the eligibility rules already keep him off the pitch.
    /// A captain who LEAVES the squad gets a replacement through the
    /// existing validateRoles() path.
    func testCaptainRoleStaysCoherentThroughBansAndDepartures() async {
        let store = await makeFitSquadStore(name: "Captain Tester")
        store.autoPickLineup()
        let captain = squad(store, position: .midfielder)[0]
        store.setCaptain(captain)
        XCTAssertEqual(store.captainID, captain.id)
        mutate(store, id: captain.id) { $0.suspensionMatches = 2 }

        store.validateRoles()
        XCTAssertEqual(store.captainID, captain.id,
                       "A suspended player is still at the club — the armband is kept, not reassigned")
        XCTAssertFalse(store.userStartingXI().contains { $0.id == captain.id },
                       "The banned captain must still be kept off the pitch by the eligibility rules")

        store.clubs[store.userClubIndex].players.removeAll { $0.id == captain.id }
        store.validateRoles()
        XCTAssertNotEqual(store.captainID, captain.id, "A departed captain's armband must be reassigned")
        XCTAssertTrue(store.userClub.players.contains { $0.id == store.captainID },
                      "The new captain must be a squad member")
    }

    /// In a real live match, the designated penalty taker being sent off
    /// must never leave him as the taker: the engine resolves to an
    /// on-pitch player (via the same path a penalty in play uses).
    func testLiveMatchPenaltyTakerResolvesToOnPitchPlayerAfterSendOff() async {
        let store = await makeFitSquadStore(name: "Taker Tester")
        let taker = squad(store, position: .forward)[0]
        store.setPenaltyTaker(taker)
        store.autoPickLineup()

        var safety = 0
        while !store.isSeasonOver && !store.isUserMatchToday && safety < 60 {
            store.advanceDay()
            safety += 1
        }
        XCTAssertTrue(store.isUserMatchToday, "Walked the calendar without reaching a user match day")
        store.beginUserMatch()
        guard let match = store.live else { return XCTFail("beginUserMatch did not start a live match") }

        guard let onPitchTaker = match.userOnPitch.first(where: { $0.player.id == taker.id }) else {
            return XCTFail("The designated taker should be in the auto-picked XI for this audit")
        }
        match.testSendOffUser(playerID: onPitchTaker.player.id)

        let onField = Set(match.userOnPitch.map { $0.player.id })
        XCTAssertFalse(onField.contains(taker.id), "The sent-off taker must be off the pitch")
        let resolved = match.resolvedPenaltyTakerForAudits()
        XCTAssertNotNil(resolved, "A penalty must always find a taker")
        if let resolved {
            XCTAssertTrue(onField.contains(resolved.id),
                          "The penalty taker must be an on-pitch player, not the sent-off designated taker")
        }
    }

    // MARK: - Persistence

    func testPersistReloadPreservesInjuriesSuspensionsBansAndChosenXI() async {
        let store = await makeFitSquadStore(name: "Persistence Tester")
        let injured = squad(store, position: .defender)[0]
        let suspended = squad(store, position: .midfielder)[0]
        let longTerm = squad(store, position: .forward)[0]
        mutate(store, id: injured.id) { $0.injuryWeeks = 2 }
        mutate(store, id: suspended.id) { $0.suspensionMatches = 3 }
        mutate(store, id: longTerm.id) { $0.injuryWeeks = 7 }
        store.autoPickLineup()
        let chosenXI = Set(store.bestXI(for: store.userClub, formation: store.formation).map { $0.id })
        store.userStarterIDs = chosenXI
        store.persist()

        let reloaded = await makeTestStore()
        guard let id = store.currentSaveID else { return XCTFail("No save id") }
        XCTAssertTrue(reloaded.loadSavedGame(id: id), "The save must load back")

        func find(_ store: GameStore, _ id: UUID) -> Player? {
            store.clubs[store.userClubIndex].players.first { $0.id == id }
        }
        XCTAssertEqual(find(reloaded, injured.id)?.injuryWeeks, 2, "Injury weeks must survive the round-trip")
        XCTAssertEqual(find(reloaded, suspended.id)?.suspensionMatches, 3, "Suspension matches must survive the round-trip")
        XCTAssertEqual(find(reloaded, longTerm.id)?.injuryWeeks, 7, "Long-term injuries must survive the round-trip")
        XCTAssertEqual(reloaded.userStarterIDs, chosenXI, "The hand-picked XI must survive the round-trip")
    }
}
