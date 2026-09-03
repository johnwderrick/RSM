//
//  LegendsMatchSimulationTests.swift
//  Retro Season ManagerTests
//
//  Phase 1 of the Legends 2D match simulator added the continuous-motion
//  layer (LegendsMatchSimulation.swift); Phase 2 made the ball
//  event-driven via `triggerAttack(forUser:scored:)`; Phase 3 made two
//  real attacking players (a wide runner, a finisher) physically make
//  the runs the ball's sequence follows, via `runTargetOverrides`; Phase
//  4 sent the defending goalkeeper diving to the near post, wrong-footed
//  against a shot that goes to the far post for a goal; Phase 5 added a
//  marking defender who chases the ball's *live* position every tick
//  rather than a fixed waypoint; Phase 6 made the pitch the match's
//  default view with `speedMultiplier` kept in lockstep with the real
//  match's speed/pause; Phase 7 made the ball's own wide-run/box-run legs
//  follow the real runner's *live* position too, not a shared fixed
//  point; Phase 8 made a non-scoring "chance" a genuine save — the shot
//  waypoint is now literally the same point as the defending keeper's
//  dive target, so the two visibly meet there rather than the keeper
//  reacting decoratively to a shot going somewhere unrelated. This file
//  covers all nine: the idle ambient loop still moves the ball with
//  nothing triggered, a triggered attack sequence reaches the correct
//  goal mouth and fires the matching `BallImpact` (goal vs. chance,
//  correct side), a chance's shot lands exactly where the keeper is
//  diving to, two attacking-team players plus the defending keeper and a
//  defending marker get run overrides, the keeper dives to the opposite
//  side from where a *goal's* shot goes, the marker's target actually
//  moves as the ball moves (unlike every other override), the ball's
//  wide-run/box-run legs follow a real player rather than a fixed point
//  while the shot leg doesn't, `speedMultiplier` scales/freezes the whole
//  simulation, those overrides clear once the sequence resolves, a second
//  `triggerAttack` landing mid-sequence is queued and plays out after the
//  active one rather than being dropped (Phase 9), and players still
//  steer toward their (ball-shifted or run-overridden) home anchors and
//  stay in bounds. Capstoning all of it, one end-to-end test drives a
//  real `LegendsLiveMatch` to full time, forwards every goal/big-chance
//  commentary line into the simulation exactly the way the live view's
//  `reactToLatestCommentary` does (id-diffing against the last handled
//  line), then drains the pitch and asserts that *every* event — even
//  bursts that must queue behind each other — produced a visible impact
//  flash at the right goal mouth — and a soak twin drives the same match
//  through the *real* async `start()` loops (3× speed, ~20s of wall time)
//  to confirm the queue keeps draining under sustained live-speed load.
//  The canvas's visibility window itself is asserted through the pure
//  `ImpactFlashState` function `drawImpactFlash` now delegates to: a fired
//  impact renders the instant it fires, expands and fades over 0.6s, and
//  draws nothing outside that window — and `ImageRenderer` snapshots of
//  the actual canvas prove the ring really reaches the pixels at the goal
//  mouth, that the attack's wide runner and finisher dots really reach
//  their run targets on the pitch mid-attack, and that substituting the
//  substituting the departing runner off mid-attack is a *bench handover*
//  rather than an in-place cut: the incoming card's dot (new surname)
//  appears at the touchline and walks across to the departed spot while
//  the departed dot fades out where it stood — all three snapshot tests
//  assert that on the pixels (the handover lands at the departed spot,
//  the ghost fades, and the subbed-on card then steers back toward its
//  formation slot, visible as the dot's red centroid moving toward the
//  formation anchor), and a double-substitution test drives two walk-ins
//  in quick succession, asserting they complete independently — the
//  shorter walk arrives first, each card at its own departed spot — and
//  a pixel snapshot captures two dots walking on from opposite touchlines
//  in the same frame, proving both are visible simultaneously.
//  Everything else is driven
//  entirely through `testAdvance(dt:)`,
//  mirroring how LegendsLiveMatchTests.swift stays synchronous via
//  `testAdvanceMinute()` rather than the real async `start()` loop.
//
//  `freshSimulation()` is `async` and constructs via `Task { @MainActor in
//  ... }.value` rather than calling the @MainActor init directly from a
//  sync test method — per the Project Bible's §6 toolchain finding,
//  constructing a @MainActor store synchronously inline inside a sync
//  @MainActor XCTest method reliably crashes with a malloc double-free on
//  this Xcode toolchain (a bug inside Swift Concurrency itself, not app
//  code). Same rule GameStoreTestSupport.swift's makeTestStore() and
//  LegendsLiveMatchTests.swift's freshStore() already follow.
//

import SwiftUI
import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsMatchSimulationTests: XCTestCase {

    private func fourFourTwoUserSlots() -> [(role: DetailedPosition, id: String, name: String)] {
        let formation = Formation.all.first { $0.name == "4-4-2" }!
        return formation.slotRoles().enumerated().map { index, role in
            (role, "user-\(index)", "Player \(index)")
        }
    }

    private func freshSimulation() async -> LegendsMatchSimulation {
        let userSlots = fourFourTwoUserSlots()
        let opponent = LegendsOpponentRoster.generateRoster(for: LegendsOpponent(name: "Test Rivals", rating: 65))
        return await Task { @MainActor in
            LegendsMatchSimulation(
                userSlots: userSlots,
                userFormation: Formation.all.first { $0.name == "4-4-2" }!,
                opponentFormation: opponent.formation,
                opponentPlayers: opponent.players
            )
        }.value
    }

    // MARK: - Full-match store (shared with the end-to-end test below)

    /// A disk-free `LegendsStore` for the end-to-end test — mirrors
    /// LegendsLiveMatchTests.freshStore(), plus explicitly clears the
    /// manager/stadium fields, since `LegendsLiveMatch` snapshots them
    /// into `strengthBonus` and a real playthrough on disk would otherwise
    /// leak into the match's event rate.
    private func freshStore() async -> LegendsStore {
        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile.ownedCardIDs = Set(LegendsCardDatabase.all.map(\.id))
        store.profile.startingXICardIDs = Array(repeating: nil, count: 11)
        store.profile.benchCardIDs = Array(repeating: nil, count: LegendsStore.benchSize)
        store.profile.captainCardID = nil
        store.profile.formationName = "4-4-2"
        store.profile.currentSeason = 1
        store.profile.matchesPlayedThisSeason = 0
        store.profile.cardUpgrades = [:]
        store.profile.duplicateProgress = [:]
        store.profile.preferredMentality = .balanced
        store.profile.cardAgeOffsets = [:]
        store.profile.ownedManagerIDs = []
        store.profile.activeManagerID = nil
        store.profile.ownedStadiumIDs = []
        store.profile.activeStadiumID = nil
        return store
    }

    /// Fills the XI with the N unique-named cards a `sorted`-and-deduped
    /// list starts with, then fills the bench with the next few — same
    /// "one card per real-ish player" dedup LegendsLiveMatchTests uses.
    private func fillSquad(_ store: LegendsStore, preferring sorted: [LegendsCard]) {
        var seenNames = Set<String>()
        let unique = sorted.filter { seenNames.insert($0.name).inserted }
        let slots = store.startingXISlots
        for i in 0..<slots.count {
            store.assign(cardID: unique[i].id, toXISlot: i)
        }
        for i in 0..<min(LegendsStore.benchSize, unique.count - slots.count) {
            store.assign(cardID: unique[slots.count + i].id, toBenchSlot: i)
        }
    }

    private func strongestXI(_ store: LegendsStore) {
        fillSquad(store, preferring: LegendsCardDatabase.all.sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) })
    }

    // MARK: - Shared mirrors of the live view's wiring

    /// Forwards any goal/big-chance commentary lines appended since the
    /// last-handled line into the simulation — the exact id-diff
    /// `LegendsLiveMatchView.reactToLatestCommentary` performs — shared by
    /// the synchronous end-to-end test and the live-loop soak below so
    /// both exercise the same mirror of the view's real wiring.
    /// `lastHandled` stays untouched when nothing is new, and advances to
    /// the newest line once a batch has been scanned.
    private func forwardNewCommentary(from live: LegendsLiveMatch,
                                      into simulation: LegendsMatchSimulation,
                                      lastHandled: inout UUID?,
                                      expected: inout [(side: Side, kind: BallImpact.Kind)]) {
        let lines = live.commentary
        let startIndex: Int
        if let anchor = lastHandled, let index = lines.firstIndex(where: { $0.id == anchor }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        guard startIndex < lines.count else { return }
        for line in lines[startIndex...] {
            guard let side = line.side else { continue }
            if line.text.contains("⚽︎ GOAL") {
                expected.append((side, .goal))
                simulation.triggerAttack(forUser: side == .home, scored: true)
            } else if line.text.contains("Big chance for") {
                expected.append((side, .chance))
                simulation.triggerAttack(forUser: side == .home, scored: false)
            }
        }
        lastHandled = lines.last?.id
    }

    /// Records `simulation.lastImpact` if it's newer than the last one
    /// seen — `lastImpact` is a single slot overwritten by each resolution,
    /// so anything that runs long enough for several sequences (the soak)
    /// dedups by the impact's own timestamp to catch every one.
    private func captureNewImpact(from simulation: LegendsMatchSimulation,
                                  into captured: inout [BallImpact],
                                  lastCapturedTime: inout Date?) {
        if let impact = simulation.lastImpact, impact.time != lastCapturedTime {
            captured.append(impact)
            lastCapturedTime = impact.time
        }
    }

    // MARK: - Speed sync (Phase 6)

    func testZeroSpeedMultiplierFreezesTheBall() async {
        let simulation = await freshSimulation()
        simulation.speedMultiplier = 0
        let start = simulation.ball.position
        for _ in 0..<20 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertEqual(simulation.ball.position.x, start.x, accuracy: 0.0001,
                        "A 0 multiplier (paused/half-time) should stop the ball from moving at all.")
        XCTAssertEqual(simulation.ball.position.y, start.y, accuracy: 0.0001)
    }

    func testHigherSpeedMultiplierMovesTheBallFurtherForTheSameRealTime() async {
        let normal = await freshSimulation()
        let fast = await freshSimulation()
        fast.speedMultiplier = 3

        for _ in 0..<10 {
            normal.testAdvance(dt: 0.1)
            fast.testAdvance(dt: 0.1)
        }

        let normalMoved = hypot(normal.ball.position.x - 0.5, normal.ball.position.y - 0.5)
        let fastMoved = hypot(fast.ball.position.x - 0.5, fast.ball.position.y - 0.5)
        XCTAssertGreaterThan(fastMoved, normalMoved,
                              "3× speed should carry the ball further than 1× over the same number of real-time ticks.")
    }

    func testBallStartsAtKickoffCenter() async {
        let simulation = await freshSimulation()
        XCTAssertEqual(simulation.ball.position.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(simulation.ball.position.y, 0.5, accuracy: 0.0001)
    }

    func testIdleBallMovesOverTicksWithNoTriggeredAttack() async {
        let simulation = await freshSimulation()
        let start = simulation.ball.position
        for _ in 0..<20 {
            simulation.testAdvance(dt: 0.1)
        }
        let moved = hypot(simulation.ball.position.x - start.x, simulation.ball.position.y - start.y)
        XCTAssertGreaterThan(moved, 0, "Continuous open play should move the ball with nothing triggered.")
        XCTAssertNil(simulation.lastImpact, "No attack was triggered, so no impact should fire.")
    }

    // MARK: - Continuous open play

    func testOpenPlayStartsWithARealHomeOutfieldPossessor() async {
        let simulation = await freshSimulation()
        guard let possessorID = simulation.testAmbientPossessorID(),
              let possessor = simulation.players.first(where: { $0.id == possessorID }) else {
            return XCTFail("Open play should begin with a real player in possession.")
        }
        XCTAssertEqual(possessor.team, .home)
        XCTAssertNotEqual(possessor.role, .goalkeeper)
        XCTAssertEqual(simulation.possessionTeam, .home)
    }

    func testOpenPlayPassTargetsARealTeammate() async {
        let simulation = await freshSimulation()
        let startingPossessorID = simulation.testAmbientPossessorID()

        for _ in 0..<30 where simulation.testAmbientPassTargetID() == nil {
            simulation.testAdvance(dt: 0.1)
        }

        guard let targetID = simulation.testAmbientPassTargetID(),
              let target = simulation.players.first(where: { $0.id == targetID }) else {
            return XCTFail("The possessor should select a live teammate as a passing option.")
        }
        XCTAssertNotEqual(targetID, startingPossessorID)
        XCTAssertEqual(target.team, .home)
        XCTAssertNotEqual(target.role, .goalkeeper)
        XCTAssertNil(simulation.possessionPlayerID,
                     "A pass in flight should not display a possession ring on the nearest player.")
    }

    func testNearestCapableDefenderPressesGoalSideOfTheBall() async {
        let simulation = await freshSimulation()
        simulation.testAdvance(dt: 0.1)

        guard let presserID = simulation.testAmbientPresserID(),
              let presser = simulation.players.first(where: { $0.id == presserID }) else {
            return XCTFail("The out-of-possession team should assign one real presser.")
        }
        XCTAssertEqual(presser.team, .away)
        XCTAssertNotEqual(presser.role, .goalkeeper)
        XCTAssertEqual(presser.homeAnchor.x, simulation.ball.position.x, accuracy: 0.0001)
        let expectedGoalSideY = simulation.ball.position.y + (0 - simulation.ball.position.y) * 0.10
        XCTAssertEqual(presser.homeAnchor.y, expectedGoalSideY, accuracy: 0.0001)
    }

    func testOpenPlayIncludesVisibleDeterministicTurnovers() async {
        let first = await freshSimulation()
        let second = await freshSimulation()
        var sawAwayPossession = false

        for _ in 0..<350 {
            first.testAdvance(dt: 0.1)
            second.testAdvance(dt: 0.1)
            sawAwayPossession = sawAwayPossession || first.possessionTeam == .away

            XCTAssertEqual(first.possessionTeam, second.possessionTeam)
            XCTAssertEqual(first.testAmbientPossessorID(), second.testAmbientPossessorID())
            XCTAssertEqual(first.testAmbientPassTargetID(), second.testAmbientPassTargetID())
            XCTAssertEqual(first.ball.position.x, second.ball.position.x, accuracy: 0.0001)
            XCTAssertEqual(first.ball.position.y, second.ball.position.y, accuracy: 0.0001)
        }

        XCTAssertGreaterThan(first.testAmbientCompletedPasses(), 0)
        XCTAssertTrue(sawAwayPossession,
                      "Open play should change hands through a visible interception instead of resetting to home possession.")
        XCTAssertTrue(first.ball.position.x >= 0 && first.ball.position.x <= 1)
        XCTAssertTrue(first.ball.position.y >= 0 && first.ball.position.y <= 1)
    }

    // MARK: - Triggered attacks

    /// Long enough to run a full buildup → wide flank → cross → shot
    /// sequence (~1 pitch-unit of path at 0.18 units/sec ≈ 6s) plus a
    /// margin, regardless of which flank the random wide waypoint picks.
    private let ticksToCompleteAnAttack = 150

    func testUserGoalAttackEndsAtTheOpponentGoalMouthAndFiresAGoalImpact() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a goal impact to have fired.")
        }
        XCTAssertEqual(impact.kind, .goal)
        // y = 0 is the opponent's goal line in this coordinate system —
        // a user goal should land right on it.
        XCTAssertEqual(impact.position.y, 0.015, accuracy: 0.02)
    }

    func testOpponentGoalAttackEndsAtTheUsersGoalMouthAndFiresAGoalImpact() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: false, scored: true)
        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a goal impact to have fired.")
        }
        XCTAssertEqual(impact.kind, .goal)
        // y = 1 is the user's own goal line — an opponent goal should
        // land right on it (the mirrored side of a user goal).
        XCTAssertEqual(impact.position.y, 0.985, accuracy: 0.02)
    }

    func testUserChanceEndsNearButNotOnTheGoalLineAndFiresAChanceImpact() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: false)
        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a chance impact to have fired.")
        }
        XCTAssertEqual(impact.kind, .chance)
        XCTAssertEqual(impact.position.y, 0.03, accuracy: 0.02)
    }

    /// A Legends "chance" is narrated as a save ("the keeper stands
    /// tall!"), never a wayward shot — so the shot should travel to
    /// *exactly* where the defending keeper is diving to, not some
    /// unrelated off-target point, making the save visually causal
    /// rather than decorative.
    func testChanceShotLandsExactlyWhereTheDefendingKeeperDivesTo() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: false)

        guard let keeper = simulation.players.first(where: { $0.team == .away && $0.role == .goalkeeper }) else {
            return XCTFail("Expected an away goalkeeper in the roster.")
        }
        XCTAssertTrue(simulation.testHasRunOverride(for: keeper.id), "The keeper should be diving to meet this chance.")

        // Stop at the instant the impact fires, not after the full budget
        // — a chance sequence has a rebound leg *after* the shot, and the
        // keeper's override (along with everyone else's) releases only
        // once that finishes, after which they'd steer back into normal
        // formation shape and no longer be standing at the save point.
        var ticks = 0
        while simulation.lastImpact == nil && ticks < ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
            ticks += 1
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a chance impact to have fired.")
        }
        guard let keeperAtImpact = simulation.players.first(where: { $0.id == keeper.id }) else {
            return XCTFail("Keeper should still be present.")
        }
        // The instant the impact fires, the keeper — still steering
        // toward (or already at) the same dive point the shot waypoint
        // was built from — should be right where the impact landed.
        let distanceFromKeeper = hypot(impact.position.x - keeperAtImpact.position.x, impact.position.y - keeperAtImpact.position.y)
        XCTAssertLessThan(distanceFromKeeper, 0.05, "The save should land right where the keeper is standing.")
    }

    // MARK: - Queued attacks (Phase 9)

    /// Two events can land in the same engine tick (each side is rolled
    /// independently) — the second `triggerAttack` must queue behind the
    /// in-flight sequence and play out once it resolves, not silently
    /// replace it and drop the first event's on-pitch moment.
    func testSecondAttackWhileOneIsActiveIsQueuedAndPlaysAfterItResolves() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        simulation.triggerAttack(forUser: false, scored: false)
        XCTAssertEqual(simulation.testAttackStartCount, 1,
                       "A second attack arriving mid-sequence should be queued, not started immediately")

        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertEqual(simulation.testAttackStartCount, 2,
                       "The queued attack should start once the first sequence resolves")

        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected the queued opponent chance's impact to have fired")
        }
        XCTAssertEqual(impact.kind, .chance, "The queued opponent chance should be the latest impact once both sequences have played")
        XCTAssertEqual(impact.position.y, 0.97, accuracy: 0.02,
                       "The queued opponent chance should resolve at the user's own goal line")
    }

    func testAttackFlanksAlternateFromADeterministicStartingSide() async {
        let firstSimulation = await freshSimulation()
        let identicalSimulation = await freshSimulation()

        firstSimulation.triggerAttack(forUser: true, scored: true)
        identicalSimulation.triggerAttack(forUser: true, scored: true)
        XCTAssertEqual(firstSimulation.testLastAttackUsedLeftFlank, true)
        XCTAssertEqual(identicalSimulation.testLastAttackUsedLeftFlank,
                       firstSimulation.testLastAttackUsedLeftFlank,
                       "Identical simulations should choose the same starting flank")

        firstSimulation.triggerAttack(forUser: false, scored: false)
        for _ in 0..<ticksToCompleteAnAttack {
            firstSimulation.testAdvance(dt: 0.1)
        }
        XCTAssertEqual(firstSimulation.testAttackStartCount, 2)
        XCTAssertEqual(firstSimulation.testLastAttackUsedLeftFlank, false,
                       "The next scripted chance should rotate to the opposite flank")
    }

    // MARK: - Substitutions (live pitch sync)

    func testSubstitutionSwapsTheSlotDotAndReleasesTheDepartingPlayersRunOverride() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        guard let runner = simulation.players.first(where: { $0.team == .home && simulation.testHasRunOverride(for: $0.id) }),
              let slotIndex = simulation.players.firstIndex(where: { $0.id == runner.id }) else {
            return XCTFail("Expected an active home runner to substitute off")
        }

        simulation.applySubstitution(slotIndex: slotIndex, cardID: "new-signing", name: "New Signing")

        let incoming = simulation.players[slotIndex]
        XCTAssertEqual(incoming.id, "new-signing", "The slot should now be the incoming card")
        XCTAssertEqual(incoming.name, "New Signing")
        XCTAssertEqual(incoming.role, runner.role, "The slot's role should be unchanged by the swap")
        // The handover is animated rather than a cut: the incoming card
        // appears at the near touchline (at the departed player's depth),
        // not in place, and walks to the departed spot.
        let expectedSpawnX = runner.position.x < 0.5 ? 0.02 : 0.98
        XCTAssertEqual(incoming.position.x, expectedSpawnX, accuracy: 0.0001,
                       "The incoming card should appear at the near touchline, not in place")
        XCTAssertEqual(incoming.position.y, runner.position.y, accuracy: 0.0001,
                       "The incoming card should appear at the departed player's depth")
        XCTAssertEqual(simulation.testSubWalkInTarget(for: "new-signing")?.x ?? -1, runner.position.x, accuracy: 0.0001,
                       "The walk-in should head for the departed player's exact spot")
        XCTAssertEqual(simulation.testDepartingGhostCount(), 1,
                       "The departed card's dot should linger as a fading ghost")
        XCTAssertFalse(simulation.players.contains { $0.id == runner.id }, "The departed card should no longer be on the pitch")
        XCTAssertFalse(simulation.testHasRunOverride(for: "new-signing"),
                       "The incoming card shouldn't inherit the departed player's run target")
    }

    func testPossessionTeamFollowsAttacksAndRestartsWithTheDefendingSide() async {
        let simulation = await freshSimulation()
        XCTAssertEqual(simulation.possessionTeam, .home, "Possession should start with the home team")

        // Home attack — possession is set to the home (attacking) team.
        simulation.triggerAttack(forUser: true, scored: true)
        XCTAssertEqual(simulation.possessionTeam, .home)

        // A goal hands the restart to the side that conceded; possession
        // must not automatically snap back to the user team.
        for _ in 0..<ticksToCompleteAnAttack where simulation.testHasActiveAttack() {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertFalse(simulation.testHasActiveAttack())
        XCTAssertEqual(simulation.possessionTeam, .away,
                       "After a home goal, the away side should take the restart")

        // Away attack — possession flips to the away team.
        simulation.triggerAttack(forUser: false, scored: true)
        XCTAssertEqual(simulation.possessionTeam, .away)

        for _ in 0..<ticksToCompleteAnAttack where simulation.testHasActiveAttack() {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertFalse(simulation.testHasActiveAttack())
        XCTAssertEqual(simulation.possessionTeam, .home,
                       "After an away goal, the home side should take the restart")
    }

    func testSubstitutingTheActiveMarkerReleasesTheChase() async {
        let simulation = await freshSimulation()
        // An away attack makes the home team defend, so the marker is a
        // home player — the only kind of player a substitution replaces.
        simulation.triggerAttack(forUser: false, scored: true)
        guard let markerID = simulation.testMarkerID(),
              let slotIndex = simulation.players.firstIndex(where: { $0.id == markerID }) else {
            return XCTFail("Expected an active home marker to substitute off")
        }

        simulation.applySubstitution(slotIndex: slotIndex, cardID: "new-signing", name: "New Signing")

        XCTAssertNil(simulation.testMarkerID(), "Subbing off the active marker should release the chase")
    }

    /// Subs both attacking runners off in quick succession — the wide
    /// outlet and the finisher — and asserts the two walk-ins complete
    /// independently without interfering: each incoming card spawns at its
    /// own departed player's near touchline with its own walk-in target
    /// (never the other runner's spot), neither inherits the departed
    /// runners' overrides, and the two walks — the wide runner's is short
    /// (0.02 → ~0.14), the finisher's long (0.02 → ~0.48) — clear at
    /// different ticks, each card arriving at its own departed spot. The
    /// single-sub tests assert the handover mechanics; this one proves the
    /// per-card walk-in dictionary keeps two concurrent handovers apart.
    func testTwoSimultaneousSubstitutionsWalkInIndependently() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.lastImpact, "The walk-ins must start mid-attack, before the shot resolves")

        // The two attacking runners are the wide outlet and the finisher.
        guard let wideID = simulation.testFollowedPlayerID(atLegIndex: 2),
              let finisherID = simulation.testFollowedPlayerID(atLegIndex: 3),
              let wideSlot = simulation.players.firstIndex(where: { $0.id == wideID }),
              let finisherSlot = simulation.players.firstIndex(where: { $0.id == finisherID }),
              wideSlot != finisherSlot else {
            return XCTFail("Expected the two attacking runners to be distinct user-side players")
        }
        let wideDeparting = simulation.players[wideSlot]
        let finisherDeparting = simulation.players[finisherSlot]

        simulation.applySubstitution(slotIndex: wideSlot, cardID: "sub-wide", name: "New Winger")
        simulation.applySubstitution(slotIndex: finisherSlot, cardID: "sub-finisher", name: "New Striker")

        let wideIncoming = simulation.players[wideSlot]
        let finisherIncoming = simulation.players[finisherSlot]
        // Each card appears at its own departed player's near touchline,
        // at that player's depth.
        let wideSpawnX = wideDeparting.position.x < 0.5 ? 0.02 : 0.98
        let finisherSpawnX = finisherDeparting.position.x < 0.5 ? 0.02 : 0.98
        XCTAssertEqual(wideIncoming.position.x, wideSpawnX, accuracy: 0.0001,
                       "The wide sub should appear at its departed player's near touchline")
        XCTAssertEqual(finisherIncoming.position.x, finisherSpawnX, accuracy: 0.0001,
                       "The finisher sub should appear at its departed player's near touchline")
        XCTAssertEqual(wideIncoming.position.y, wideDeparting.position.y, accuracy: 0.0001,
                       "The wide sub should appear at the departed player's depth")
        XCTAssertEqual(finisherIncoming.position.y, finisherDeparting.position.y, accuracy: 0.0001,
                       "The finisher sub should appear at the departed player's depth")

        // Each walk-in aims at its own departed spot — never the other
        // runner's.
        guard let wideTarget = simulation.testSubWalkInTarget(for: "sub-wide"),
              let finisherTarget = simulation.testSubWalkInTarget(for: "sub-finisher") else {
            return XCTFail("Both incoming cards should have active walk-ins")
        }
        XCTAssertEqual(wideTarget.x, wideDeparting.position.x, accuracy: 0.0001,
                       "The wide sub's walk-in should head for the wide runner's exact spot")
        XCTAssertEqual(wideTarget.y, wideDeparting.position.y, accuracy: 0.0001,
                       "The wide sub's walk-in should head for the wide runner's exact spot")
        XCTAssertEqual(finisherTarget.x, finisherDeparting.position.x, accuracy: 0.0001,
                       "The finisher sub's walk-in should head for the finisher's exact spot")
        XCTAssertEqual(finisherTarget.y, finisherDeparting.position.y, accuracy: 0.0001,
                       "The finisher sub's walk-in should head for the finisher's exact spot")
        XCTAssertGreaterThan(abs(wideTarget.x - finisherTarget.x), 0.1,
                             "The two walk-ins should aim at different spots")
        XCTAssertEqual(simulation.testDepartingGhostCount(), 2,
                       "Both departed dots should linger as fading ghosts")
        XCTAssertFalse(simulation.testHasRunOverride(for: "sub-wide"),
                       "The wide sub shouldn't inherit the departed runner's override")
        XCTAssertFalse(simulation.testHasRunOverride(for: "sub-finisher"),
                       "The finisher sub shouldn't inherit the departed runner's override")

        // Advance tick by tick, recording when each walk-in clears. The
        // wide runner's walk is short, the finisher's long, so the wide
        // sub should arrive first — while the finisher sub is still
        // walking — and each should arrive at its own departed spot.
        var ticksUntilWideArrives: Int?
        var ticksUntilFinisherArrives: Int?
        var wideArrivedPos: CGPoint?
        var finisherArrivedPos: CGPoint?
        for tick in 1...30 {
            simulation.testAdvance(dt: 0.1)
            if ticksUntilWideArrives == nil, simulation.testSubWalkInTarget(for: "sub-wide") == nil {
                ticksUntilWideArrives = tick
                wideArrivedPos = simulation.players[wideSlot].position
            }
            if ticksUntilFinisherArrives == nil, simulation.testSubWalkInTarget(for: "sub-finisher") == nil {
                ticksUntilFinisherArrives = tick
                finisherArrivedPos = simulation.players[finisherSlot].position
            }
            if ticksUntilWideArrives != nil, ticksUntilFinisherArrives != nil { break }
        }
        guard let ticksWide = ticksUntilWideArrives,
              let ticksFinisher = ticksUntilFinisherArrives,
              let wideArrived = wideArrivedPos,
              let finisherArrived = finisherArrivedPos else {
            return XCTFail("Both walk-ins should complete within 30 ticks")
        }
        XCTAssertLessThan(ticksWide, ticksFinisher,
                          "The shorter walk should arrive first — the walk-ins complete independently")
        XCTAssertLessThan(ticksWide, 12, "The wide runner's short walk should be quick")
        XCTAssertLessThan(ticksFinisher, 30, "The finisher's long walk should still complete")
        XCTAssertEqual(wideArrived.x, wideDeparting.position.x, accuracy: 0.03,
                       "The wide sub should arrive at the wide runner's departed spot")
        XCTAssertEqual(wideArrived.y, wideDeparting.position.y, accuracy: 0.03,
                       "The wide sub should arrive at the wide runner's departed spot")
        XCTAssertEqual(finisherArrived.x, finisherDeparting.position.x, accuracy: 0.03,
                       "The finisher sub should arrive at the finisher's departed spot")
        XCTAssertEqual(finisherArrived.y, finisherDeparting.position.y, accuracy: 0.03,
                       "The finisher sub should arrive at the finisher's departed spot")
        XCTAssertNil(simulation.lastImpact, "Both walk-ins should complete mid-attack, before the shot resolves")
    }

    func testAttackSequenceHandsBackToContinuousOpenPlayAfterResolving() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        let atSequenceEnd = simulation.ball.position
        // A real possessor and passing phase take over after the event — the
        // ball should not stay frozen at the goal mouth.
        for _ in 0..<50 {
            simulation.testAdvance(dt: 0.1)
        }
        let moved = hypot(simulation.ball.position.x - atSequenceEnd.x, simulation.ball.position.y - atSequenceEnd.y)
        XCTAssertGreaterThan(moved, 0.05, "The ball should have moved into continuous open play after the attack resolved.")
    }

    // MARK: - Possession coupling (Phase 3), keeper reaction (Phase 4), marking (Phase 5)

    func testTriggerAttackAssignsRunOverridesToTwoAttackersAndTwoDefenders() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)

        let overriddenHome = simulation.players.filter { $0.team == .home && simulation.testHasRunOverride(for: $0.id) }
        let overriddenAway = simulation.players.filter { $0.team == .away && simulation.testHasRunOverride(for: $0.id) }
        XCTAssertEqual(overriddenHome.count, 2, "A wide runner and a finisher should be assigned run targets for a home attack.")
        XCTAssertEqual(overriddenAway.count, 2, "The defending goalkeeper and one marking outfield player should get run overrides.")
        XCTAssertTrue(overriddenAway.contains { $0.role == .goalkeeper })
        XCTAssertTrue(overriddenAway.contains { $0.role != .goalkeeper })
    }

    func testTriggerAttackOverridesTheDefendingTeamForAnAwayAttack() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: false, scored: false)

        let overriddenAway = simulation.players.filter { $0.team == .away && simulation.testHasRunOverride(for: $0.id) }
        let overriddenHome = simulation.players.filter { $0.team == .home && simulation.testHasRunOverride(for: $0.id) }
        XCTAssertEqual(overriddenAway.count, 2, "An away attack should assign run targets to two away players.")
        XCTAssertEqual(overriddenHome.count, 2, "The home goalkeeper and a home marker should react to an away attack.")
        XCTAssertTrue(overriddenHome.contains { $0.role == .goalkeeper })
    }

    func testTriggerAttackAssignsAnOutfieldMarkerFromTheDefendingTeam() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)

        guard let markerID = simulation.testMarkerID() else {
            return XCTFail("Expected a marker to be assigned.")
        }
        guard let marker = simulation.players.first(where: { $0.id == markerID }) else {
            return XCTFail("Marker should be a real player in the roster.")
        }
        XCTAssertEqual(marker.team, .away, "The marker should come from the defending team for a home attack.")
        XCTAssertNotEqual(marker.role, .goalkeeper, "The keeper already has its own dedicated override.")
    }

    func testMarkerChasesTheBallsLivePositionRatherThanAFixedPoint() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: false)
        guard let markerID = simulation.testMarkerID() else {
            return XCTFail("Expected a marker to be assigned.")
        }

        simulation.testAdvance(dt: 0.01)
        guard let earlyAnchor = simulation.players.first(where: { $0.id == markerID })?.homeAnchor else {
            return XCTFail("Marker should still be present.")
        }

        // Advance well into the sequence — the ball will have moved a long
        // way from where it was on that first tick, and since the marker
        // tracks it live (not a fixed waypoint set once), its target
        // should have moved a comparable distance too.
        for _ in 0..<30 {
            simulation.testAdvance(dt: 0.1)
        }
        guard let laterAnchor = simulation.players.first(where: { $0.id == markerID })?.homeAnchor else {
            return XCTFail("Marker should still be present.")
        }

        let anchorMovement = hypot(laterAnchor.x - earlyAnchor.x, laterAnchor.y - earlyAnchor.y)
        XCTAssertGreaterThan(anchorMovement, 0.1,
                              "The marker's target should have moved substantially as the ball moved, unlike the runners'/keeper's fixed targets.")
    }

    func testMarkerClearsOnceTheSequenceResolves() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        XCTAssertNotNil(simulation.testMarkerID())

        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.testMarkerID(), "The marker assignment should release once the sequence hands back to open play.")
    }

    func testDefendingKeeperDivesToTheNearPostAwayFromWhereTheShotGoes() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)

        guard let keeperID = simulation.players.first(where: { $0.team == .away && $0.role == .goalkeeper })?.id else {
            return XCTFail("Expected an away goalkeeper in the roster.")
        }
        XCTAssertTrue(simulation.testHasRunOverride(for: keeperID))

        // Capture the dive side right away — the override (and with it
        // `homeAnchor`) is released the instant the sequence resolves, in
        // the very same tick a *scored* sequence's impact fires, so this
        // has to be read before running the sequence to completion below.
        simulation.testAdvance(dt: 0.01)
        guard let diveSide = simulation.players.first(where: { $0.id == keeperID }).map({ $0.homeAnchor.x < 0.5 }) else {
            return XCTFail("Keeper should still be present.")
        }

        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a goal impact to have fired.")
        }
        // The keeper's dive target and the shot's target corner are on
        // opposite sides of goal centre (x = 0.5) — "wrong-footed."
        let shotSide = impact.position.x < 0.5
        XCTAssertNotEqual(diveSide, shotSide, "The keeper should dive to the opposite side from where the shot goes.")
    }

    func testRunOverridesClearOnceTheSequenceResolves() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        XCTAssertTrue(simulation.players.contains { simulation.testHasRunOverride(for: $0.id) })

        for _ in 0..<ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertFalse(simulation.players.contains { simulation.testHasRunOverride(for: $0.id) },
                        "Run overrides should release once the sequence hands back to open play.")
    }

    func testAnOverriddenRunnersHomeAnchorIsTheirRunTargetNotTheNormalFormula() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        // One tiny tick so `tick()` has run once and set `homeAnchor` from
        // the override rather than checking the pre-tick initial value.
        simulation.testAdvance(dt: 0.01)

        guard let runner = simulation.players.first(where: { simulation.testHasRunOverride(for: $0.id) }) else {
            return XCTFail("Expected at least one overridden runner.")
        }
        // Run targets (near the touchline in the attacking third, or deep
        // in the box) sit well outside the small ball-relative breathing
        // range `teamShapeShift`/`sidewaysPull` would ever move a normal
        // player's anchor to — a big gap from baseAnchor here confirms
        // the override, not the shared formula, is driving this player.
        let distanceFromBaseAnchor = hypot(runner.homeAnchor.x - runner.baseAnchor.x, runner.homeAnchor.y - runner.baseAnchor.y)
        XCTAssertGreaterThan(distanceFromBaseAnchor, 0.1,
                              "An overridden runner's homeAnchor should be their run target, well away from their base anchor.")
    }

    // MARK: - Ball tracks the live runner (Phase 7)

    func testWideRunLegFollowsTheWideRunnerLiveNotAFixedPoint() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)

        guard let followedID = simulation.testFollowedPlayerID(atLegIndex: 2) else {
            return XCTFail("Expected the wide-run leg (index 2) to follow a real player.")
        }
        XCTAssertTrue(simulation.testHasRunOverride(for: followedID),
                       "The followed player should be one of this sequence's runners.")
    }

    func testBoxRunLegFollowsTheFinisherLiveNotAFixedPoint() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: false, scored: false)

        guard let followedID = simulation.testFollowedPlayerID(atLegIndex: 3) else {
            return XCTFail("Expected the box-run leg (index 3) to follow a real player.")
        }
        XCTAssertTrue(simulation.testHasRunOverride(for: followedID),
                       "The followed player should be one of this sequence's runners.")
    }

    func testShotLegIsAFixedPointNotFollowingAPlayer() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        XCTAssertNil(simulation.testFollowedPlayerID(atLegIndex: 4),
                     "The shot should travel toward a fixed goal-mouth point, not follow a player.")
    }

    func testIdleLoopLegsNeverFollowAPlayer() async {
        let simulation = await freshSimulation()
        // No triggerAttack — every idle-loop leg should be a fixed point.
        for index in 0..<6 {
            XCTAssertNil(simulation.testFollowedPlayerID(atLegIndex: index),
                         "Idle-loop leg \(index) shouldn't follow a player.")
        }
    }

    // MARK: - Players

    func testPlayersInitializeAtFormationAnchors() async {
        let simulation = await freshSimulation()
        XCTAssertEqual(simulation.players.count, 22, "11 user + 11 synthesized opponent players.")

        let userAnchors = PitchCoordinateSystem.anchors(for: Formation.all.first { $0.name == "4-4-2" }!, team: .home)
        let homePlayers = simulation.players.filter { $0.team == .home }
        XCTAssertEqual(homePlayers.count, 11)
        for (player, anchor) in zip(homePlayers, userAnchors) {
            XCTAssertEqual(player.position.x, anchor.x, accuracy: 0.0001)
            XCTAssertEqual(player.position.y, anchor.y, accuracy: 0.0001)
        }
    }

    func testPlayersSteerTowardTheirShiftedAnchorsOverTime() async {
        let simulation = await freshSimulation()
        let startingPositions = simulation.players.map(\.position)

        // Kickoff's ball sits at (0.5, 0.5) — any player whose base anchor
        // isn't already dead-center gets a non-zero shifted home anchor
        // from tick one, so repeated ticks should visibly move them.
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }

        var movedCount = 0
        for (player, start) in zip(simulation.players, startingPositions) {
            let distance = hypot(player.position.x - start.x, player.position.y - start.y)
            if distance > 0.01 { movedCount += 1 }
        }
        XCTAssertGreaterThan(movedCount, 15, "Most of the 22 players should have visibly steered after 4 seconds of ticks.")
    }

    func testPlayersStayWithinPitchBoundsOverManyTicksIncludingDuringAnAttack() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: Bool.random(), scored: Bool.random())
        for _ in 0..<300 {
            simulation.testAdvance(dt: 0.1)
        }
        for player in simulation.players {
            XCTAssertGreaterThanOrEqual(player.position.x, 0, "\(player.id) drifted out of bounds")
            XCTAssertLessThanOrEqual(player.position.x, 1, "\(player.id) drifted out of bounds")
            XCTAssertGreaterThanOrEqual(player.position.y, 0, "\(player.id) drifted out of bounds")
            XCTAssertLessThanOrEqual(player.position.y, 1, "\(player.id) drifted out of bounds")
        }
        XCTAssertGreaterThanOrEqual(simulation.ball.position.x, 0)
        XCTAssertLessThanOrEqual(simulation.ball.position.x, 1)
        XCTAssertGreaterThanOrEqual(simulation.ball.position.y, 0)
        XCTAssertLessThanOrEqual(simulation.ball.position.y, 1)
    }

    // MARK: - Full-match end-to-end (every event flashes)

    /// A real match against a weak opponent, played to full time minute by
    /// minute, with every goal/big-chance commentary line forwarded into a
    /// `LegendsMatchSimulation` exactly as
    /// `LegendsLiveMatchView.reactToLatestCommentary` does — diffing
    /// against the last-handled line's id — and the pitch then drained
    /// until every sequence, including the back-to-back bursts that must
    /// queue behind each other (Phase 9), has resolved. Asserts that every
    /// single event produced a visible impact flash: the right kind (goal
    /// vs. chance), at the right team's goal mouth, each carrying its own
    /// fresh timestamp (the view's expanding ring keys off that timestamp
    /// to stay visible), and that none was dropped along the way.
    func testFullMatchEveryGoalAndBigChanceFiresAVisibleImpactFlash() async {
        let store = await freshStore()
        strongestXI(store)
        let opponent = LegendsOpponent(name: "Rival XI", rating: 40)
        let live = LegendsLiveMatch(store: store, opponent: opponent,
                                    rng: DeterministicRNG(seed: 0x5EED_F00D))

        // Build the pitch exactly the way LegendsLiveMatchView.init does:
        // the same kickoff XI snapshot as user slots, the same synthesized
        // opponent roster, the store's formation.
        let userSlots: [(role: DetailedPosition, id: String, name: String)] = Array(
            zip(store.startingXISlots, live.onPitchCardIDs).enumerated()
        ).map { index, pair in
            let (role, cardID) = pair
            let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            return (role, cardID ?? "user-slot-\(index)", card?.name ?? "—")
        }
        let opponentRoster = LegendsOpponentRoster.generateRoster(for: opponent)
        let simulation = await Task { @MainActor in
            LegendsMatchSimulation(
                userSlots: userSlots,
                userFormation: store.formation,
                opponentFormation: opponentRoster.formation,
                opponentPlayers: opponentRoster.players
            )
        }.value

        // Play the match to full time, forwarding new commentary lines
        // after every minute — a faithful mirror of the view's
        // `reactToLatestCommentary` id-diff — and recording each
        // goal/big-chance event we expect to flash.
        var expectedEvents: [(side: Side, kind: BallImpact.Kind)] = []
        var lastHandledCommentaryID: UUID?
        while !live.isFinished {
            live.testAdvanceMinute()
            forwardNewCommentary(from: live, into: simulation,
                                 lastHandled: &lastHandledCommentaryID,
                                 expected: &expectedEvents)
        }

        XCTAssertTrue(live.isFinished, "The match should reach full time")
        XCTAssertGreaterThanOrEqual(expectedEvents.count, 2,
                                    "A full match against a weak side should produce several goals/big chances — the queue only has something to prove with a real burst")

        // Drain the pitch. Sequences play one at a time in FIFO order; each
        // resolves to exactly one impact. `lastImpact` is a single slot, but
        // sequences resolve many ticks apart, so capturing it every tick and
        // deduping by its timestamp catches every one.
        var captured: [BallImpact] = []
        var lastCapturedTime: Date?
        for _ in 0..<(expectedEvents.count + 1) * ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
            captureNewImpact(from: simulation, into: &captured, lastCapturedTime: &lastCapturedTime)
            if captured.count == expectedEvents.count { break }
        }

        XCTAssertEqual(simulation.testAttackStartCount, expectedEvents.count,
                       "Every goal/big-chance line must start an attack sequence — none may be dropped")
        XCTAssertEqual(captured.count, expectedEvents.count,
                       "Every triggered attack — immediate or queued — must resolve to an impact")
        for (impact, event) in zip(captured, expectedEvents) {
            XCTAssertEqual(impact.kind, event.kind,
                           "Impacts must match their commentary events in FIFO order")
            let expectedY: Double
            switch (event.side, event.kind) {
            case (.home, .goal):   expectedY = 0.015
            case (.home, .chance): expectedY = 0.03
            case (.away, .goal):   expectedY = 0.985
            case (.away, .chance): expectedY = 0.97
            }
            XCTAssertEqual(impact.position.y, expectedY, accuracy: 0.02,
                           "A \(event.side) \(event.kind) must flash at that side's own goal mouth")
        }
        XCTAssertEqual(Set(captured.map(\.time)).count, captured.count,
                       "Each impact must carry its own fresh timestamp — the view's flash ring keys off it to stay visible")
    }

    // MARK: - Soak: full match under the real async loops

    /// The one test in this file that drives the *real* async loops — both
    /// `LegendsLiveMatch.start()` and `LegendsMatchSimulation.start()` —
    /// rather than the synchronous `testAdvance*` paths, so it exercises
    /// the production wiring as shipped: the loops sleeping on their own
    /// cadences and interleaving on the MainActor, with a watcher task
    /// forwarding commentary the way the live view's
    /// `.onChange(of: live.commentary.count)` does. Runs the full match at
    /// 3× (the game's top speed; ~20s of wall time — this is deliberately
    /// the soak). Asserts the queue kept draining during live play (most
    /// sequences had already started and some impacts had already flashed
    /// by full-time, and the post-match drain is short), and that every
    /// goal/big chance — immediate or queued — resolved to a visible
    /// impact flash at the right goal mouth, each with its own fresh
    /// timestamp.
    func testFullMatchUnderRealAsyncLoopsDrainsTheQueueAndFlashesEveryEvent() async {
        let store = await freshStore()
        strongestXI(store)
        let opponent = LegendsOpponent(name: "Rival XI", rating: 40)
        let live = LegendsLiveMatch(store: store, opponent: opponent,
                                    rng: DeterministicRNG(seed: 0x5EED_F00D))
        live.setSpeed(3)

        // Build the pitch exactly the way LegendsLiveMatchView.init does
        // (same kickoff XI snapshot, same synthesized opponent roster).
        let userSlots: [(role: DetailedPosition, id: String, name: String)] = Array(
            zip(store.startingXISlots, live.onPitchCardIDs).enumerated()
        ).map { index, pair in
            let (role, cardID) = pair
            let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            return (role, cardID ?? "user-slot-\(index)", card?.name ?? "—")
        }
        let opponentRoster = LegendsOpponentRoster.generateRoster(for: opponent)
        let simulation = await Task { @MainActor in
            LegendsMatchSimulation(
                userSlots: userSlots,
                userFormation: store.formation,
                opponentFormation: opponentRoster.formation,
                opponentPlayers: opponentRoster.players
            )
        }.value

        // State shared between this test and the watcher task — all
        // MainActor, interleaved via sleeps, so the mutations serialize.
        var expectedEvents: [(side: Side, kind: BallImpact.Kind)] = []
        var lastHandledCommentaryID: UUID?
        var captured: [BallImpact] = []
        var lastCapturedTime: Date?

        // The watcher plays the view's role: every ~50ms it forwards any
        // newly appended goal/big-chance line into the simulation (the same
        // id-diff as `reactToLatestCommentary`) and records any impact that
        // just fired.
        let watcher = Task { @MainActor in
            while !Task.isCancelled {
                forwardNewCommentary(from: live, into: simulation,
                                     lastHandled: &lastHandledCommentaryID,
                                     expected: &expectedEvents)
                captureNewImpact(from: simulation, into: &captured, lastCapturedTime: &lastCapturedTime)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        simulation.speedMultiplier = live.speed
        live.start()
        simulation.start()

        // Wait for full time, yielding the MainActor between polls so both
        // loops can actually tick. The real engine pauses at half-time, as
        // the app does, and nothing clears that on its own — mirror the
        // player tapping play to start the second half.
        let waitStart = Date()
        while !live.isFinished {
            if live.isHalfTime {
                live.resume()
                simulation.speedMultiplier = live.speed
            }
            if Date().timeIntervalSince(waitStart) > 60 { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        // Snapshot the live-drain signal at full-time, *before* the catch-up
        // below: how many sequences had already started while play was live.
        let expectedAtFullTime = expectedEvents.count
        let startedAtFullTime = simulation.testAttackStartCount

        // The final minute's lines can land a moment after `isFinished`
        // flips — catch up synchronously (idempotent: the anchor diff means
        // nothing already handled is re-forwarded), then tear down.
        forwardNewCommentary(from: live, into: simulation,
                             lastHandled: &lastHandledCommentaryID,
                             expected: &expectedEvents)
        watcher.cancel()
        simulation.stop()
        live.stop()
        // The post-match drain runs at 1× so its tick budget reads like the
        // rest of this file.
        simulation.speedMultiplier = 1

        XCTAssertTrue(live.isFinished, "The real async loop should reach full time")
        XCTAssertGreaterThanOrEqual(expectedEvents.count, 2,
                                    "The match should produce several goals/big chances for the queue to work through")
        XCTAssertGreaterThanOrEqual(startedAtFullTime, expectedAtFullTime - 2,
                                    "The queue must keep draining during live play — at most the very latest events may still be queued at full-time")
        XCTAssertGreaterThan(captured.count, 0,
                             "Some impacts should have flashed live during the match, not only during the post-match drain")

        // Drain anything still queued or mid-flight, continuing the capture
        // from where the watcher left off.
        var drainTicks = 0
        for _ in 0..<(expectedEvents.count + 1) * ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
            drainTicks += 1
            captureNewImpact(from: simulation, into: &captured, lastCapturedTime: &lastCapturedTime)
            if captured.count == expectedEvents.count { break }
        }

        XCTAssertEqual(simulation.testAttackStartCount, expectedEvents.count,
                       "Every goal/big-chance line must start an attack sequence — none may be dropped")
        XCTAssertEqual(captured.count, expectedEvents.count,
                       "Every triggered attack — immediate or queued — must resolve to an impact")
        XCTAssertLessThanOrEqual(drainTicks, 3 * ticksToCompleteAnAttack,
                                 "The post-match drain must be short — the queue kept draining during live play, not piling up for the end")
        for (impact, event) in zip(captured, expectedEvents) {
            XCTAssertEqual(impact.kind, event.kind,
                           "Impacts must match their commentary events in FIFO order")
            let expectedY: Double
            switch (event.side, event.kind) {
            case (.home, .goal):   expectedY = 0.015
            case (.home, .chance): expectedY = 0.03
            case (.away, .goal):   expectedY = 0.985
            case (.away, .chance): expectedY = 0.97
            }
            XCTAssertEqual(impact.position.y, expectedY, accuracy: 0.02,
                           "A \(event.side) \(event.kind) must flash at that side's own goal mouth")
        }
        XCTAssertEqual(Set(captured.map(\.time)).count, captured.count,
                       "Each impact must carry its own fresh timestamp — the view's flash ring keys off it to stay visible")
    }

    // MARK: - Impact flash visibility (the canvas's draw path)

    /// The canvas's goal-mouth ring must actually be visible the instant an
    /// impact fires and through the following 0.6s window, growing from
    /// nothing to `maxRadius` while fading out — driven by the same pure
    /// `ImpactFlashState.state(for:at:)` that `drawImpactFlash` now calls
    /// with `Date()` on every ~30Hz redraw.
    func testImpactFlashVisibilityWindowDrivesTheCanvasRing() async {
        let now = Date()
        let impact = BallImpact(position: CGPoint(x: 0.5, y: 0.015), kind: .goal, time: now)

        // The instant it fires: visible, zero-sized, fully opaque.
        guard let flash = ImpactFlashState.state(for: impact, at: now) else {
            return XCTFail("A flash should be visible the moment it fires")
        }
        XCTAssertEqual(flash.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(flash.radius, 0, accuracy: 0.0001)
        XCTAssertEqual(flash.opacity, 1, accuracy: 0.0001)

        // Halfway through the window: the ring has grown halfway and faded
        // halfway — the expanding, fading animation in one check.
        let midway = now.addingTimeInterval(ImpactFlashState.duration / 2)
        guard let mid = ImpactFlashState.state(for: impact, at: midway) else {
            return XCTFail("A flash should still be visible halfway through its window")
        }
        XCTAssertEqual(mid.progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(mid.radius, ImpactFlashState.maxRadius / 2, accuracy: 0.0001)
        XCTAssertEqual(mid.opacity, 0.5, accuracy: 0.0001)
    }

    /// Outside its `[0, 0.6)` window the flash draws nothing — before the
    /// impact's own timestamp (clock skew) and from the moment it expires.
    func testImpactFlashDrawsNothingBeforeItsTimestampOrAfterExpiry() async {
        let now = Date()
        let impact = BallImpact(position: CGPoint(x: 0.5, y: 0.015), kind: .goal, time: now)

        XCTAssertNil(ImpactFlashState.state(for: impact, at: now.addingTimeInterval(-0.1)),
                     "A flash must not render before its own timestamp")
        XCTAssertNil(ImpactFlashState.state(for: impact, at: now.addingTimeInterval(ImpactFlashState.duration)),
                     "A flash must not render once its window has expired")

        // Just before expiry it's still visible, nearly fully grown and faded.
        let edge = now.addingTimeInterval(ImpactFlashState.duration - 0.001)
        guard let edgeState = ImpactFlashState.state(for: impact, at: edge) else {
            return XCTFail("A flash should stay visible up until the end of its window")
        }
        XCTAssertLessThan(edgeState.progress, 1)
        XCTAssertGreaterThan(edgeState.progress, 0.99)
        XCTAssertLessThan(edgeState.opacity, 0.01)
    }

    /// The end-to-end link: an impact a real simulation actually fires —
    /// the same ones the full-match tests assert for every goal and big
    /// chance — must be visible when the canvas draws at that moment, via
    /// the exact state function `drawImpactFlash` now delegates to. The
    /// canvas redraws at ~30Hz, so at most ~33ms pass between the impact
    /// firing and the next draw: comfortably inside the 0.6s window.
    func testARealImpactFromTheSimulationIsVisibleTheMomentItFires() async {
        let simulation = await freshSimulation()
        simulation.triggerAttack(forUser: true, scored: true)
        var ticks = 0
        while simulation.lastImpact == nil && ticks < ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
            ticks += 1
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a goal impact to have fired")
        }
        guard let flash = ImpactFlashState.state(for: impact, at: Date()) else {
            return XCTFail("The fired impact must be visible when the canvas next draws")
        }
        XCTAssertEqual(flash.progress, 0, accuracy: 0.01,
                       "The ring should be at the very start of its window when first drawn")
        XCTAssertGreaterThanOrEqual(flash.radius, 0)
        XCTAssertLessThanOrEqual(flash.radius, ImpactFlashState.maxRadius)
        XCTAssertGreaterThan(flash.opacity, 0.99)
    }

    // MARK: - ImageRenderer snapshot: the flash really reaches the pixels

    /// Renders `LegendsPitchCanvas` off-screen with `ImageRenderer` twice
    /// while a fired impact's flash is alive — at two moments inside its
    /// 0.6s window — and diffs the two pixel buffers. Nothing else changes
    /// between the renders: no ticks run, so every player and the ball stay
    /// frozen, and the only input that moves is `Date()`, which is exactly
    /// what `drawImpactFlash` keys off. The differing pixels are therefore
    /// the growing flash ring and nothing else. Asserts it is a real,
    /// non-transparent ring sitting at the goal mouth: hundreds of changed
    /// pixels, all on the half of the pitch the goal was scored into (the
    /// right edge for a user goal — the opponent's goal mouth renders at
    /// x ≈ 0.985 of the landscape pitch width), around mid-height. The ring
    /// is invisible at the exact instant it fires (zero radius, per
    /// `ImpactFlashState`), so the snapshots wait for it to grow.
    func testImageRendererDrawsTheImpactRingAtTheGoalMouth() async {
        let simulation = await freshSimulation()
        // A user goal resolves at the opponent's goal mouth, y ≈ 0.015 —
        // the right edge of the landscape render.
        simulation.triggerAttack(forUser: true, scored: true)
        var ticks = 0
        while simulation.lastImpact == nil && ticks < ticksToCompleteAnAttack {
            simulation.testAdvance(dt: 0.1)
            ticks += 1
        }
        guard let impact = simulation.lastImpact else {
            return XCTFail("Expected a goal impact to have fired")
        }
        XCTAssertEqual(impact.kind, .goal)

        let view = LegendsPitchCanvas(simulation: simulation, userColor: .red, opponentColor: .blue,
                                      userName: "HOME", opponentName: "AWAY")
            .frame(width: 620, height: 430)

        // Two snapshots while the flash is alive: at ~0.15s (small ring)
        // and ~0.35s (larger ring) — both comfortably inside the 0.6s
        // window even with sleep jitter. A fresh `ImageRenderer` is created
        // right at each capture moment: it rasterizes the view when the
        // renderer is built, so reusing one renderer across both sleeps
        // would return the same stale frame twice (the flash at zero
        // radius) and diff to nothing.
        Thread.sleep(forTimeInterval: 0.15)
        let earlyRenderer = ImageRenderer(content: view)
        earlyRenderer.scale = 1
        guard let early = earlyRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }
        Thread.sleep(forTimeInterval: 0.2)
        let laterRenderer = ImageRenderer(content: view)
        laterRenderer.scale = 1
        guard let later = laterRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }

        let earlyPixels = rgbaBuffer(from: early)
        let laterPixels = rgbaBuffer(from: later)
        XCTAssertEqual(earlyPixels.count, laterPixels.count, "Both snapshots should be the same size")

        let width = early.width
        let height = early.height
        var rightSideDiffs = 0
        var leftSideDiffs = 0
        var minX = width, maxX = 0, minY = height, maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                var differs = false
                for channel in 0..<4 where abs(Int(earlyPixels[i + channel]) - Int(laterPixels[i + channel])) > 8 {
                    differs = true
                    break
                }
                guard differs else { continue }
                if x > width / 2 { rightSideDiffs += 1 } else { leftSideDiffs += 1 }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        XCTAssertGreaterThan(rightSideDiffs, 200,
                             "The flash ring should visibly grow between the two snapshots — hundreds of changed pixels on the goal side")
        XCTAssertLessThanOrEqual(leftSideDiffs, 10,
                                 "Every changed pixel should be on the goal side of the pitch — nothing on the opposite half")
        // The ring sits at the goal mouth: right-center of the rendered
        // pitch (mid-height is robust to the image's row orientation).
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        XCTAssertGreaterThan(Double(centerX), Double(width) * 0.7,
                             "The ring should be near the right edge, where the opponent's goal mouth renders")
        XCTAssertLessThan(abs(centerY - height / 2), height / 4,
                          "The flash should be around mid-height (the goal mouth), not in a corner")
    }

    /// Renders the pitch mid-attack and closes the loop on the two attacking
    /// runners: the sim says exactly who the wide outlet and the finisher
    /// are (`testFollowedPlayerID` on the wide-run/box-run legs) and where
    /// they stand, and the canvas draws each player's dot at exactly that
    /// position — so the test verifies both the physical run (the wide
    /// runner hugging the touchline, deep in the attacking third; the
    /// finisher in the box) *and* that a cluster of the user's red pixels is
    /// actually rendered at each dot's expected spot. The finisher's box
    /// spot is empty in the kickoff formation, so a control render proves
    /// its dot appeared because of the attack; the wide runner's spot is
    /// skipped for that comparison because the far striker starts 8px from
    /// it (the 4-4-2's strikers sit wide, at pitch x 0.12/0.88).
    func testImageRendererShowsTheRunnersReachingThePitchMidAttack() async {
        let simulation = await freshSimulation()
        let view = LegendsPitchCanvas(simulation: simulation, userColor: .red, opponentColor: .blue,
                                      userName: "HOME", opponentName: "AWAY")
            .frame(width: 620, height: 430)

        // Control: the kickoff formation with no attack (used only for the
        // finisher's box spot below).
        let controlRenderer = ImageRenderer(content: view)
        controlRenderer.scale = 1
        guard let control = controlRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }

        // Mid-attack: 40 ticks in (well before the shot resolves at ~65+
        // ticks), both runners have already steered out to their run
        // targets and are standing on them.
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.lastImpact, "The snapshot must be mid-attack, before the shot resolves")

        // The sim's Phase 7 live-follow legs tell us which real players are
        // making the wide run and the box run.
        guard let wideID = simulation.testFollowedPlayerID(atLegIndex: 2),
              let finisherID = simulation.testFollowedPlayerID(atLegIndex: 3) else {
            return XCTFail("Expected the wide-run and box-run legs to follow real players")
        }
        guard let wide = simulation.players.first(where: { $0.id == wideID }),
              let finisher = simulation.players.first(where: { $0.id == finisherID }) else {
            return XCTFail("Expected both runners to still be on the pitch")
        }

        // The physical runs: the wide outlet hugs the touchline (pitch x
        // 0.14 or 0.86) deep in the attacking third (y 0.16); the finisher
        // sits in the box at (0.5, 0.06).
        XCTAssertLessThanOrEqual(min(abs(wide.position.x - 0.14), abs(wide.position.x - 0.86)), 0.03,
                                 "The wide runner should hug whichever touchline the flank was")
        XCTAssertEqual(wide.position.y, 0.16, accuracy: 0.03,
                       "The wide runner should have reached the touchline-deep outlet")
        XCTAssertEqual(finisher.position.x, 0.5, accuracy: 0.03,
                       "The finisher should have reached the box's centre")
        XCTAssertEqual(finisher.position.y, 0.06, accuracy: 0.03,
                       "The finisher should have reached the box")

        let midRenderer = ImageRenderer(content: view)
        midRenderer.scale = 1
        guard let mid = midRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }
        let midPixels = rgbaBuffer(from: mid)
        let controlPixels = rgbaBuffer(from: control)
        XCTAssertEqual(midPixels.count, controlPixels.count, "Both snapshots should be the same size")

        let width = mid.width
        let height = mid.height
        // The canvas renders the 0...1 pitch transposed into a 620x400
        // pitch area at the top of the 620x430 frame (the geometry the ring
        // snapshot test confirmed empirically): landscape x = width*(1 - y),
        // landscape y = 400*x.
        func landscape(_ point: CGPoint) -> (x: Int, y: Int) {
            (Int(Double(width) * (1 - point.y)), Int(400.0 * point.x))
        }
        func isRedPixel(_ i: Int) -> Bool {
            midPixels[i] > 140 && midPixels[i + 1] < 90 && midPixels[i + 2] < 90
        }
        func redPixelCount(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> Int {
            var count = 0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 { count += 1 }
                }
            }
            return count
        }

        let widePos = landscape(wide.position)
        let finisherPos = landscape(finisher.position)

        // Each runner's dot (10pt red disc minus the white surname label) is
        // actually rendered at the position the sim says it stands at.
        XCTAssertGreaterThan(redPixelCount(in: midPixels, near: widePos.x, widePos.y, radius: 12), 30,
                             "The wide runner's red dot should be rendered at its pitch position")
        XCTAssertGreaterThan(redPixelCount(in: midPixels, near: finisherPos.x, finisherPos.y, radius: 12), 30,
                             "The finisher's red dot should be rendered at its pitch position")

        // And those positions are the run targets, not the formation slots
        // they left: deep in the attacking third, the wide one hugging the
        // top or bottom touchline, the finisher mid-height in the box.
        XCTAssertGreaterThan(Double(widePos.x), Double(width) * 0.7,
                             "The wide runner should be deep in the attacking third")
        XCTAssertTrue(Double(widePos.y) < 120 || Double(widePos.y) > 280,
                      "The wide runner should be hugging the touchline (top or bottom edge)")
        XCTAssertGreaterThan(Double(finisherPos.x), Double(width) * 0.7,
                             "The finisher should be deep in the attacking third")
        XCTAssertTrue(Double(finisherPos.y) > 150 && Double(finisherPos.y) < 250,
                      "The finisher should be at mid-height, in the box")

        // The finisher's box spot is empty in the kickoff formation — its
        // dot mid-attack is genuinely new (the wide runner's spot is not
        // compared this way because the far striker starts ~8px from it).
        XCTAssertLessThanOrEqual(redPixelCount(in: controlPixels, near: finisherPos.x, finisherPos.y, radius: 12), 5,
                                 "Nothing should be rendered at the finisher's box spot before the attack")
    }

    /// Renders the pitch mid-attack, substitutes the departing runner off
    /// for a new card, and asserts on the pixels that the substitution's
    /// handover happens *at the departed spot*: frame 1 holds the departing
    /// ghost fading there (old surname), frame 2 — after the incoming card
    /// has walked on from the touchline — holds the incoming card's dot
    /// within a small window of that spot with the new surname. The red
    /// disc is rendered near the same position in both frames, and the
    /// surname label inside the dot — the one per-dot visual a
    /// substitution can actually change — differs on the pixels. The
    /// Phase 3 substitution tests assert the id/name swap inside the sim;
    /// this closes the loop on the canvas drawing the handover.
    func testImageRendererShowsTheSubstitutedCardReplacingTheDepartedDotAtTheSameSpot() async {
        let simulation = await freshSimulation()
        let view = LegendsPitchCanvas(simulation: simulation, userColor: .red, opponentColor: .blue,
                                      userName: "HOME", opponentName: "AWAY")
            .frame(width: 620, height: 430)

        // Mid-attack so the departing player is standing on their run
        // target — the same setup as the runners snapshot test.
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.lastImpact, "The snapshot must be mid-attack, before the shot resolves")

        // The box-run leg names the finisher; the user's XI occupies
        // players[0..<11] in slot order, so the runner is a subbable slot.
        guard let finisherID = simulation.testFollowedPlayerID(atLegIndex: 3),
              let slotIndex = simulation.players.indices.first(where: { $0 < 11 && simulation.players[$0].id == finisherID }) else {
            return XCTFail("Expected the box-run leg to follow a user-side player in the XI")
        }
        let departed = simulation.players[slotIndex]

        // Sub the departing runner off for a card whose surname is clearly
        // different from the departed slot's ("9" of "Player 9").
        simulation.applySubstitution(slotIndex: slotIndex, cardID: "sub-rooney", name: "B. Rooney")
        let incoming = simulation.players[slotIndex]
        XCTAssertEqual(incoming.id, "sub-rooney", "The slot should now hold the incoming card")

        // Frame 1, right after the sub: the departing ghost lingers at the
        // spot while the incoming card appears at the touchline.
        let beforeRenderer = ImageRenderer(content: view)
        beforeRenderer.scale = 1
        guard let before = beforeRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }

        // Let the walk-in complete: the incoming card runs on from the
        // touchline to the departed spot (~16-17 ticks).
        for _ in 0..<18 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.testSubWalkInTarget(for: "sub-rooney"), "The walk-in should have completed")
        XCTAssertEqual(simulation.players[slotIndex].position.x, departed.position.x, accuracy: 0.03,
                       "The incoming card should arrive at the departed spot")
        XCTAssertEqual(simulation.players[slotIndex].position.y, departed.position.y, accuracy: 0.03,
                       "The incoming card should arrive at the departed spot")

        // The ghost's fade is wall-clock (the view re-reads `Date()` each
        // frame, like the impact flash) — sleep past its 1s window so the
        // departed dot is gone from the canvas before frame 2, without
        // ticking the sim (the incoming card stays put at its arrival
        // position during the sleep).
        Thread.sleep(forTimeInterval: 1.05)
        let afterRenderer = ImageRenderer(content: view)
        afterRenderer.scale = 1
        guard let after = afterRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }

        let beforePixels = rgbaBuffer(from: before)
        let afterPixels = rgbaBuffer(from: after)
        XCTAssertEqual(beforePixels.count, afterPixels.count, "Both snapshots should be the same size")

        let width = before.width
        let height = before.height
        // The canvas renders the 0...1 pitch transposed into a 620x400
        // pitch area at the top of the 620x430 frame (the geometry the
        // earlier snapshot tests confirmed empirically).
        func landscape(_ point: CGPoint) -> (x: Int, y: Int) {
            (Int(Double(width) * (1 - point.y)), Int(400.0 * point.x))
        }
        func redPixelCount(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> Int {
            var count = 0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 { count += 1 }
                }
            }
            return count
        }
        func redCentroid(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> (x: Double, y: Double) {
            var sumX = 0.0, sumY = 0.0, count = 0.0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 {
                        sumX += Double(x)
                        sumY += Double(y)
                        count += 1
                    }
                }
            }
            return (sumX / count, sumY / count)
        }

        let pos = landscape(departed.position)

        // Both frames show a red disc at the departed spot — the ghost
        // fading there in frame 1, the arrived incoming card in frame 2.
        XCTAssertGreaterThan(redPixelCount(in: beforePixels, near: pos.x, pos.y, radius: 12), 30,
                             "The departed ghost's red dot should be rendered at the spot")
        XCTAssertGreaterThan(redPixelCount(in: afterPixels, near: pos.x, pos.y, radius: 12), 30,
                             "The incoming card's red dot should be rendered at the same spot")

        // And the handover lands close to where the ghost stood: the walk-
        // in clears the tick the card gets within 0.02 of the departed
        // spot, so frame 2's disc is within a small window of frame 1's
        // (the white label is drawn centered on the dot, so the wider
        // surname doesn't skew the centroid).
        let beforeCentroid = redCentroid(in: beforePixels, near: pos.x, pos.y, radius: 12)
        let afterCentroid = redCentroid(in: afterPixels, near: pos.x, pos.y, radius: 12)
        XCTAssertLessThan(abs(afterCentroid.x - beforeCentroid.x), 15,
                          "The handover should land within a few pixels of the departed spot")
        XCTAssertLessThan(abs(afterCentroid.y - beforeCentroid.y), 15,
                          "The handover should land within a few pixels of the departed spot")

        // The surname label inside the dot changed — the departed slot's
        // "9" is now the incoming card's longer surname. This is the one
        // per-dot visual that can show a substitution.
        var labelDiffs = 0
        for y in max(0, pos.y - 12)..<min(height, pos.y + 12) {
            for x in max(0, pos.x - 12)..<min(width, pos.x + 12) {
                let i = (y * width + x) * 4
                var differs = false
                for channel in 0..<4 where abs(Int(beforePixels[i + channel]) - Int(afterPixels[i + channel])) > 8 {
                    differs = true
                    break
                }
                if differs { labelDiffs += 1 }
            }
        }
        XCTAssertGreaterThan(labelDiffs, 15,
                             "The surname label inside the dot should change when the card is substituted")
    }

    /// Renders the pitch mid-attack, substitutes the departing runner off,
    /// and asserts the incoming card's dot *rejoins the current team
    /// shape* over the following ticks — but only after the
    /// walk-in completes: the incoming card first runs on from the
    /// touchline to the departed spot, and only once `applySubstitution`'s
    /// walk-in clears does it start steering back to the normal
    /// ball-relative formation anchor. Mirrored on the pixels: the red
    /// dot's centroid moves by the displacement predicted by the pitch-to-
    /// canvas mapping. The same-spot snapshot test proves the handover lands
    /// at the departed spot; this one proves the dot then *leaves* it,
    /// heading home.
    func testImageRendererShowsTheSubstitutedCardRejoiningTheCurrentTeamShape() async {
        let simulation = await freshSimulation()
        let view = LegendsPitchCanvas(simulation: simulation, userColor: .red, opponentColor: .blue,
                                      userName: "HOME", opponentName: "AWAY")
            .frame(width: 620, height: 430)

        // Mid-attack: the departing finisher stands on their box run target.
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.lastImpact, "The snapshot must be mid-attack, before the shot resolves")

        guard let finisherID = simulation.testFollowedPlayerID(atLegIndex: 3),
              let slotIndex = simulation.players.indices.first(where: { $0 < 11 && simulation.players[$0].id == finisherID }) else {
            return XCTFail("Expected the box-run leg to follow a user-side player in the XI")
        }

        simulation.applySubstitution(slotIndex: slotIndex, cardID: "sub-rooney", name: "B. Rooney")
        let subbed = simulation.players[slotIndex]
        XCTAssertFalse(simulation.testHasRunOverride(for: subbed.id),
                       "The substitution should release the departed runner's override")
        // Let the walk-in complete first: the incoming card runs on from
        // the touchline to the departed spot (~16-17 ticks), then — with
        // the walk-in cleared — starts steering back to its formation
        // anchor.
        for _ in 0..<18 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.testSubWalkInTarget(for: "sub-rooney"), "The walk-in should have completed")

        // The walk-in is removed at the end of its arrival tick. Advance
        // once more so `homeAnchor` is the real possession-aware team-shape
        // target rather than the just-cleared walk-in target.
        simulation.testAdvance(dt: 0.01)
        let start = simulation.players[slotIndex].position

        let beforeRenderer = ImageRenderer(content: view)
        beforeRenderer.scale = 1
        guard let before = beforeRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }

        // Let the re-steer happen — enough ticks to visibly move.
        for _ in 0..<12 {
            simulation.testAdvance(dt: 0.1)
        }
        let endState = simulation.players[slotIndex]
        let end = endState.position

        // Sim-level: it left the departed spot and its current velocity is
        // aimed into the possession-aware team shape. The anchor moves with
        // the ball during these ticks, so comparing the end position with a
        // stale copy of the earlier anchor would test the wrong destination.
        let moved = hypot(end.x - start.x, end.y - start.y)
        XCTAssertGreaterThan(moved, 0.02, "The incoming card should physically leave the departed spot")
        let targetVector = CGVector(
            dx: endState.homeAnchor.x - end.x,
            dy: endState.homeAnchor.y - end.y
        )
        let steeringDotProduct = (endState.velocity.dx * targetVector.dx) + (endState.velocity.dy * targetVector.dy)
        XCTAssertGreaterThan(steeringDotProduct, 0,
                             "The incoming card should be steering toward its current team-shape target")

        let afterRenderer = ImageRenderer(content: view)
        afterRenderer.scale = 1
        guard let after = afterRenderer.cgImage else { return XCTFail("ImageRenderer produced no image") }

        let beforePixels = rgbaBuffer(from: before)
        let afterPixels = rgbaBuffer(from: after)
        XCTAssertEqual(beforePixels.count, afterPixels.count, "Both snapshots should be the same size")

        let width = before.width
        let height = before.height
        // The canvas renders the 0...1 pitch transposed into a 620x400
        // pitch area at the top of the 620x430 frame (the geometry the
        // earlier snapshot tests confirmed empirically).
        func landscape(_ point: CGPoint) -> (x: Int, y: Int) {
            (Int(Double(width) * (1 - point.y)), Int(400.0 * point.x))
        }
        func redPixelCount(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> Int {
            var count = 0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 { count += 1 }
                }
            }
            return count
        }
        func redCentroid(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> (x: Double, y: Double) {
            var sumX = 0.0, sumY = 0.0, count = 0.0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 {
                        sumX += Double(x)
                        sumY += Double(y)
                        count += 1
                    }
                }
            }
            return (sumX / count, sumY / count)
        }

        // The incoming card's dot is rendered at both spots — the departed
        // spot after the walk-in, and the re-steered position after the
        // ticks.
        let startPos = landscape(start)
        let endPos = landscape(end)
        XCTAssertGreaterThan(redPixelCount(in: beforePixels, near: startPos.x, startPos.y, radius: 12), 30,
                             "The incoming card's dot should be rendered at the departed spot after the walk-in")
        XCTAssertGreaterThan(redPixelCount(in: afterPixels, near: endPos.x, endPos.y, radius: 12), 30,
                             "The incoming card's dot should be rendered at its re-steered position")

        // The pixel displacement should agree with the same coordinate
        // transform used by the renderer. This proves visible motion without
        // imposing a legacy 40px minimum that contradicts eased steering.
        let startCentroid = redCentroid(in: beforePixels, near: startPos.x, startPos.y, radius: 12)
        let endCentroid = redCentroid(in: afterPixels, near: endPos.x, endPos.y, radius: 12)
        let renderedMovement = hypot(endCentroid.x - startCentroid.x, endCentroid.y - startCentroid.y)
        let expectedMovement = hypot(
            Double(width) * (end.y - start.y),
            400.0 * (end.x - start.x)
        )
        XCTAssertGreaterThan(renderedMovement, 10,
                             "The rejoin should visibly move the dot across the pitch")
        XCTAssertEqual(renderedMovement, expectedMovement, accuracy: 10,
                       "Rendered displacement should match the simulation-to-canvas mapping")
    }

    /// Renders the substitution from the bench: the incoming card's dot
    /// appears at the near touchline (not in place) and walks across the
    /// pitch to the departed spot, while the departed card's dot fades
    /// out where it stood — the two halves of the handover
    /// `applySubstitution` animates. The two clocks are driven
    /// separately, exactly as they run in the live view: the ghost's fade
    /// is wall-clock (the canvas re-reads `Date()` each frame), so a
    /// `Thread.sleep` ages it between frames 1 and 2 with no sim ticks;
    /// the walk is sim-clock, so eight `testAdvance` ticks move the
    /// incoming card between frames 2 and 3. Frame 1 shows the incoming
    /// dot at the touchline and the ghost at full strength at the spot;
    /// frame 2 shows the ghost faded; frame 3 shows the incoming dot
    /// partway across, closer to the departed spot.
    func testImageRendererShowsTheBenchSubstitutionWalkingOnAndTheDepartingDotFading() async {
        let simulation = await freshSimulation()
        let view = LegendsPitchCanvas(simulation: simulation, userColor: .red, opponentColor: .blue,
                                      userName: "HOME", opponentName: "AWAY")
            .frame(width: 620, height: 430)

        // Mid-attack: the departing finisher stands on their box run target.
        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.lastImpact, "The snapshot must be mid-attack, before the shot resolves")

        guard let finisherID = simulation.testFollowedPlayerID(atLegIndex: 3),
              let slotIndex = simulation.players.indices.first(where: { $0 < 11 && simulation.players[$0].id == finisherID }) else {
            return XCTFail("Expected the box-run leg to follow a user-side player in the XI")
        }
        let departed = simulation.players[slotIndex]

        simulation.applySubstitution(slotIndex: slotIndex, cardID: "sub-rooney", name: "B. Rooney")
        let incoming = simulation.players[slotIndex]
        let expectedSpawnX = departed.position.x < 0.5 ? 0.02 : 0.98
        XCTAssertEqual(incoming.position.x, expectedSpawnX, accuracy: 0.0001,
                       "The incoming card should appear at the near touchline, not in place")
        XCTAssertEqual(incoming.position.y, departed.position.y, accuracy: 0.0001,
                       "The incoming card should appear at the departed player's depth")
        XCTAssertEqual(simulation.testSubWalkInTarget(for: "sub-rooney")?.x ?? -1, departed.position.x, accuracy: 0.0001,
                       "The walk-on should aim at the departed player's exact spot")
        XCTAssertEqual(simulation.testDepartingGhostCount(), 1,
                       "The departed card's dot should linger as a fading ghost")

        // Frame 1, right after the sub: the incoming card's dot at the
        // touchline, the departed ghost at full strength at the departed
        // spot.
        let frame1Renderer = ImageRenderer(content: view)
        frame1Renderer.scale = 1
        guard let frame1 = frame1Renderer.cgImage else { return XCTFail("ImageRenderer produced no image") }
        let frame1Pixels = rgbaBuffer(from: frame1)

        // The ghost's fade is wall-clock (the view re-reads `Date()` each
        // frame, like the impact flash) — sleep so it's ~0.8s old (alpha
        // ~0.2, nearly gone) without ticking the sim, so the incoming
        // card stays at the touchline.
        Thread.sleep(forTimeInterval: 0.8)
        let frame2Renderer = ImageRenderer(content: view)
        frame2Renderer.scale = 1
        guard let frame2 = frame2Renderer.cgImage else { return XCTFail("ImageRenderer produced no image") }
        let frame2Pixels = rgbaBuffer(from: frame2)
        XCTAssertEqual(frame1Pixels.count, frame2Pixels.count, "Both snapshots should be the same size")

        // The walk is sim-clock — 8 ticks moves the incoming card most of
        // the way across to the departed spot.
        for _ in 0..<8 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertEqual(simulation.testDepartingGhostCount(), 1, "The ghost should still be fading, not yet drained")
        let walked = simulation.players[slotIndex].position
        let frame3Renderer = ImageRenderer(content: view)
        frame3Renderer.scale = 1
        guard let frame3 = frame3Renderer.cgImage else { return XCTFail("ImageRenderer produced no image") }
        let frame3Pixels = rgbaBuffer(from: frame3)

        // Once the ghost's wall-age passes its 1s window, the next tick
        // drains it from the simulation.
        Thread.sleep(forTimeInterval: 0.4)
        simulation.testAdvance(dt: 0.1)
        XCTAssertEqual(simulation.testDepartingGhostCount(), 0,
                       "The sim should drain the departed ghost once its fade window elapses")

        let width = frame1.width
        let height = frame1.height
        // The canvas renders the 0...1 pitch transposed into a 620x400
        // pitch area at the top of the 620x430 frame (the geometry the
        // earlier snapshot tests confirmed empirically).
        func landscape(_ point: CGPoint) -> (x: Int, y: Int) {
            (Int(Double(width) * (1 - point.y)), Int(400.0 * point.x))
        }
        func redPixelCount(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> Int {
            var count = 0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 { count += 1 }
                }
            }
            return count
        }
        func redCentroid(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> (x: Double, y: Double) {
            var sumX = 0.0, sumY = 0.0, count = 0.0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 {
                        sumX += Double(x)
                        sumY += Double(y)
                        count += 1
                    }
                }
            }
            return (sumX / count, sumY / count)
        }

        let spawnPos = landscape(incoming.position)
        let spotPos = landscape(departed.position)

        // Frame 1: the incoming card's dot is at the touchline, and the
        // departed ghost is at full strength at the departed spot.
        XCTAssertGreaterThan(redPixelCount(in: frame1Pixels, near: spawnPos.x, spawnPos.y, radius: 12), 30,
                             "The incoming card's dot should appear at the touchline")
        let ghostCountFrame1 = redPixelCount(in: frame1Pixels, near: spotPos.x, spotPos.y, radius: 12)
        XCTAssertGreaterThan(ghostCountFrame1, 30,
                             "The departed card's dot should still be visible at the spot")

        // Frame 2 (0.8s later, no sim ticks): the departed ghost has
        // faded — its red pixels are mostly gone — while the incoming
        // card hasn't moved (the walk needs sim ticks).
        XCTAssertGreaterThan(redPixelCount(in: frame2Pixels, near: spawnPos.x, spawnPos.y, radius: 12), 30,
                             "The incoming card should still be at the touchline — only the fade should change")
        let ghostCountFrame2 = redPixelCount(in: frame2Pixels, near: spotPos.x, spotPos.y, radius: 12)
        XCTAssertLessThan(ghostCountFrame2, ghostCountFrame1 / 2,
                          "The departed dot should visibly fade out over its 1s window")

        // Frame 3 (after the 8 walk ticks): the incoming card's dot is
        // rendered at its walked position — closer to the departed spot
        // than the touchline was — the walk across the pitch.
        let walkedPos = landscape(walked)
        XCTAssertGreaterThan(redPixelCount(in: frame3Pixels, near: walkedPos.x, walkedPos.y, radius: 12), 30,
                             "The incoming card's dot should be rendered at its walked position")
        let spawnCentroid = redCentroid(in: frame1Pixels, near: spawnPos.x, spawnPos.y, radius: 12)
        let walkedCentroid = redCentroid(in: frame3Pixels, near: walkedPos.x, walkedPos.y, radius: 12)
        let gapFromSpawn = hypot(spawnCentroid.x - Double(spotPos.x), spawnCentroid.y - Double(spotPos.y))
        let gapFromWalked = hypot(walkedCentroid.x - Double(spotPos.x), walkedCentroid.y - Double(spotPos.y))
        XCTAssertLessThan(gapFromWalked, gapFromSpawn,
                          "The incoming dot should walk toward the departed spot, not stay at the touchline")

        // Sim-level counterpart: it's left the touchline heading for the
        // departed spot.
        let walkStart = incoming.position
        XCTAssertLessThan(hypot(walked.x - departed.position.x, walked.y - departed.position.y),
                          hypot(walkStart.x - departed.position.x, walkStart.y - departed.position.y),
                          "The incoming card should be closer to the departed spot than the touchline is")
    }

    /// Renders a double substitution mid-attack and captures both incoming
    /// dots mid-walk from opposite touchlines in the same frame. Two
    /// outfield home players positioned on opposite sides of x = 0.5 are
    /// subbed off in quick succession — one near the left touchline, one
    /// near the right — so one incoming card enters from the top edge of
    /// the pitch and the other from the bottom. Three ticks later both are
    /// mid-walk: the pixel snapshot shows both red dots visible at the same
    /// time, on opposite sides of the pitch, each between its touchline
    /// and its target. The two players are chosen dynamically from the
    /// home XI's current positions so the test works regardless of which
    /// flank the attack's wide runner was assigned by the deterministic
    /// alternating sequence inside `startAttack`.
    func testImageRendererShowsTwoDotsWalkingOnFromOppositeTouchlines() async {
        let simulation = await freshSimulation()
        let view = LegendsPitchCanvas(simulation: simulation, userColor: .red, opponentColor: .blue,
                                      userName: "HOME", opponentName: "AWAY")
            .frame(width: 620, height: 430)

        simulation.triggerAttack(forUser: true, scored: true)
        for _ in 0..<40 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNil(simulation.lastImpact, "The snapshot must be mid-attack, before the shot resolves")

        // Find one outfield home player near each touchline — guaranteed to
        // exist in any formation (there's always a left-ish and right-ish
        // outfield player).
        let homeXI = simulation.players.prefix(11)
        guard let leftPlayer = homeXI.first(where: { $0.position.x < 0.4 && $0.role != .goalkeeper }),
              let rightPlayer = homeXI.first(where: { $0.position.x > 0.6 && $0.role != .goalkeeper }),
              let leftSlot = simulation.players.firstIndex(where: { $0.id == leftPlayer.id }),
              let rightSlot = simulation.players.firstIndex(where: { $0.id == rightPlayer.id }) else {
            return XCTFail("Expected home outfield players on both sides of the pitch")
        }

        simulation.applySubstitution(slotIndex: leftSlot, cardID: "sub-left", name: "New Left")
        simulation.applySubstitution(slotIndex: rightSlot, cardID: "sub-right", name: "New Right")

        // Each card walks to its own departed spot.
        guard let leftTarget = simulation.testSubWalkInTarget(for: "sub-left"),
              let rightTarget = simulation.testSubWalkInTarget(for: "sub-right") else {
            return XCTFail("Both incoming cards should have active walk-ins")
        }
        XCTAssertEqual(leftTarget.x, leftPlayer.position.x, accuracy: 0.0001,
                       "The left sub's walk-in should aim at the left player's spot")
        XCTAssertEqual(rightTarget.x, rightPlayer.position.x, accuracy: 0.0001,
                       "The right sub's walk-in should aim at the right player's spot")
        XCTAssertGreaterThan(abs(leftTarget.x - rightTarget.x), 0.3,
                             "The two walk-in targets should be on opposite sides of the pitch")

        // Three ticks: both are mid-walk — neither has arrived yet.
        for _ in 0..<3 {
            simulation.testAdvance(dt: 0.1)
        }
        XCTAssertNotNil(simulation.testSubWalkInTarget(for: "sub-left"),
                        "The left sub should still be walking")
        XCTAssertNotNil(simulation.testSubWalkInTarget(for: "sub-right"),
                        "The right sub should still be walking")

        let leftPos = simulation.players[leftSlot].position
        let rightPos = simulation.players[rightSlot].position

        // Each dot is between its touchline and its target — moving inward.
        XCTAssertGreaterThan(leftPos.x, 0.02,
                             "The left sub has moved inward from the touchline")
        XCTAssertLessThan(leftPos.x, leftPlayer.position.x,
                          "The left sub has not yet reached its target")
        XCTAssertLessThan(rightPos.x, 0.98,
                          "The right sub has moved inward from the touchline")
        XCTAssertGreaterThan(rightPos.x, rightPlayer.position.x,
                             "The right sub has not yet reached its target")

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.cgImage else { return XCTFail("ImageRenderer produced no image") }
        let pixels = rgbaBuffer(from: image)

        let width = image.width
        let height = image.height
        func landscape(_ point: CGPoint) -> (x: Int, y: Int) {
            (Int(Double(width) * (1 - point.y)), Int(400.0 * point.x))
        }
        func redPixelCount(in buffer: [UInt8], near cx: Int, _ cy: Int, radius r: Int) -> Int {
            var count = 0
            for y in max(0, cy - r)..<min(height, cy + r) {
                for x in max(0, cx - r)..<min(width, cx + r) {
                    let i = (y * width + x) * 4
                    if buffer[i] > 140 && buffer[i + 1] < 90 && buffer[i + 2] < 90 { count += 1 }
                }
            }
            return count
        }

        let leftPixel = landscape(leftPos)
        let rightPixel = landscape(rightPos)

        // Both dots are rendered on the pixels at the same time.
        XCTAssertGreaterThan(redPixelCount(in: pixels, near: leftPixel.x, leftPixel.y, radius: 12), 30,
                             "The left sub's red dot should be rendered mid-walk")
        XCTAssertGreaterThan(redPixelCount(in: pixels, near: rightPixel.x, rightPixel.y, radius: 12), 30,
                             "The right sub's red dot should be rendered mid-walk")


        // The two dots are on opposite sides of the pitch: one near the
        // top touchline region, the other near the bottom — each entering
        // from its own dugout edge, walking toward the defensive line.
        XCTAssertLessThan(Double(min(leftPixel.y, rightPixel.y)), Double(height) / 3,
                          "One dot should be near the top edge of the pitch")
        XCTAssertGreaterThan(Double(max(leftPixel.y, rightPixel.y)), Double(height) * 2 / 3,
                             "The other dot should be near the bottom edge of the pitch")
    }
}

/// Copies a `CGImage` into a plain RGBA byte buffer (one byte per channel,
/// top row first) so a test can assert on actual rendered pixels.
private func rgbaBuffer(from image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &pixels, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

/// A deterministic test-only LCG. `SeededGenerator` is seeded through
/// `Hasher`, which Swift intentionally randomizes per process — fine for
/// the statistical paired tests that tolerate run-to-run noise, but the
/// end-to-end tests here assert against the *count* of events a match
/// produces, so they need rolls that are identical on every single launch.
/// A plain LCG gives that: the same seed always drives the same match.
private struct DeterministicRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
