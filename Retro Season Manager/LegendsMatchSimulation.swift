//
//  LegendsMatchSimulation.swift
//  Retro Season Manager
//
//  Phase 1 of the Legends 2D match simulator added continuous player
//  motion and a scripted ball, layered on top of Phase 0's static
//  coordinate system and opponent roster synthesis. Phase 2 made the
//  ball event-driven off real `LegendsLiveMatch` commentary. Phase 3 made
//  the *players* part of that event: `triggerAttack` picks two real
//  players from the attacking team by role — a wide outlet for the
//  crossing run, a finisher for the run into the box — and temporarily
//  overrides their `homeAnchor` to the same run targets the ball's own
//  waypoints are built from (`runTargetOverrides`), so the ball and the
//  two runners genuinely converge. Phase 4 brought the *defending*
//  goalkeeper into it too: the shot's target corner and the keeper's dive
//  now both key off which flank the cross came from — a goal goes to the
//  far post (away from the cross side) while the keeper commits to the
//  near post, wrong-footed; a chance still drifts off target on its own,
//  but the keeper dives all the same rather than standing still for
//  either outcome. Phase 5 (this file, updated) adds the first *outfield*
//  defensive reaction: `triggerAttack` also picks the defending team's
//  nearest outfield player to the wide run and marks them the sequence's
//  `markerID` — every tick for the rest of that sequence, `tick()`
//  updates that one player's `runTargetOverrides` entry to the ball's
//  *current* live position (biased slightly toward their own goal, so
//  they read as goal-side rather than literally standing on the ball)
//  before doing anything else, so this defender is the only player whose
//  target moves every tick rather than being fixed once at trigger time
//  — a real closing-down chase, not another scripted waypoint. All
//  overridden players release automatically once the sequence resolves
//  (goal, chance, or handoff back to the idle loop), letting them steer
//  back into the normal ball-relative formation shape `teamShapeShift`
//  still drives for everyone else. Goal/score logic itself is still
//  untouched, and the marker never actually contests/tackles anything —
//  this remains a pure visual layer reacting to `LegendsLiveMatch`'s
//  existing tick loop and Bernoulli goal model, never feeding back into
//  it.
//
//  Two independent update rates, matching Phase 1's design: physics/
//  steering ticks at ~10Hz on a background `Task` loop (mirroring
//  `LegendsLiveMatch.loop()`'s own pause/speed-free lifecycle shape), and
//  rendering decoupled entirely — the view's `TimelineView` just redraws
//  whatever the latest `players`/`ball`/`lastImpact` snapshot is, at its
//  own cadence.
//
//  The pitch is now the match's default view (embedded directly in
//  LegendsLiveMatchView.swift rather than living behind a debug sheet),
//  so its pacing needs to track the real match's own speed control
//  rather than always animating at a fixed real-time pace regardless of
//  what "1×/2×/3×" the commentary is set to. `speedMultiplier` is that
//  hook — the view keeps it equal to `live.speed` (0 while paused/at
//  half-time), and every tick scales `dt` by it before touching the ball
//  or any player, so ball travel speed, steering speed, and therefore
//  how long a whole attack sequence takes to play out all speed up
//  together in the same proportion `LegendsLiveMatch.loop()` itself
//  speeds up match-minutes by.
//
//  Phase 7 extends Phase 5's "track a live position, not a fixed one"
//  idea to the ball itself: its wide-run and box-run legs are now
//  `BallWaypoint.followPlayer` rather than `.fixed` points, resolving
//  every tick to the actual winger's/striker's current `position` —
//  found fresh in `resolvedPosition(for:)` rather than the shared fixed
//  coordinate those two players' own `runTargetOverrides` entries are
//  *also* aiming at. Early in a run, before the faster-steering player
//  (maxSpeed 0.32 vs. the ball's fixed 0.18) has arrived, the ball now
//  visibly curves to seek them rather than beelining for an abstract
//  spot; once they arrive and stop, following them and following their
//  fixed target converge to the same thing, matching the old behavior
//  for the rest of the run. The shot leg stays `.fixed` — a shot leaves
//  the passer and travels toward goal on its own, not toward a player.
//
//  Phase 8 makes the goalkeeper's Phase 4 dive causal instead of
//  decorative: `LegendsLiveMatch`'s non-scoring "big chance" outcome is
//  narrated as a save ("the keeper stands tall!", matching Career Mode's
//  own big-chance line) rather than a wayward shot, so `triggerAttack`'s
//  `!scored` shot waypoint is now literally the same `CGPoint` as the
//  defending keeper's `keeperDivePoint` — the shot travels to exactly
//  where the keeper is diving, and the two visibly meet there, the save
//  itself. A goal still goes to the far post while the keeper commits to
//  the near post, wrong-footed, unchanged from Phase 4.
//
//  Phase 9 queues: two events can land in the same engine tick (a goal
//  and a big chance in the same minute — `LegendsLiveMatch` rolls each
//  side independently), and the single-ball model can only play one
//  sequence at a time. A `triggerAttack` arriving while a sequence is
//  still mid-flight is now queued behind it and plays out automatically
//  the moment the current one resolves, instead of silently replacing
//  the in-flight sequence's waypoints/overrides and dropping the first
//  event's on-pitch moment entirely.
//
//  Phase 10 animates a substitution as a bench handover instead of an
//  in-place cut: `applySubstitution` spawns the incoming card at the
//  near touchline (at the departed player's depth) with a walk-in target
//  of the departed spot — cleared the tick they arrive, after which they
//  steer to the normal formation shape — and leaves the departed card's
//  dot behind as a fading `SubstitutionGhost` that `tick()` drains once
//  its 1s window elapses. The walk-in is separate from
//  `runTargetOverrides` so a concurrent attack sequence's resolution
//  can't cancel it mid-run.
//

import CoreGraphics
import Foundation
import Observation

struct PlayerSimState: Identifiable {
    let id: String
    let team: Side
    let role: DetailedPosition
    let name: String
    /// This player's static Phase 0 formation slot — never changes
    /// mid-match (no dynamic role-swapping yet), used as the basis
    /// `homeAnchor` breathes around each tick.
    let baseAnchor: CGPoint
    var position: CGPoint
    var velocity: CGVector
    /// Recomputed every physics tick from `baseAnchor` plus the shared
    /// ball-relative shift (`LegendsMatchSimulation.teamShapeShift`), or
    /// from `runTargetOverrides` while this player is one of an active
    /// attack sequence's two runners — what `position` is currently
    /// steering toward.
    var homeAnchor: CGPoint
    /// Point 2: detailed effective attributes for this player — the 2D
    /// layer selects its runners/marker with the same action-specific
    /// selectors the live match engine uses, so the visual chase/run
    /// casting reflects real player quality (a fast winger makes the wide
    /// run, an anticipatory defender does the marking) instead of role
    /// order + a uniform random pick. Zero for tests that don't care.
    var detailed: LegendsDetailedAttributes
}

struct BallState {
    var position: CGPoint
}

/// A departed player's dot fading out at their last position after a
/// substitution — the "leaving the pitch" half of the handover, while
/// the incoming card walks on from the touchline (see
/// `LegendsMatchSimulation.applySubstitution`). The view draws it with an
/// alpha that falls to zero over `duration`; the sim removes it once that
/// elapses. Kept alive separately from `players` because the departed
/// card is already off the pitch — there's no slot to put them in.
struct SubstitutionGhost {
    let id: String
    let name: String
    let position: CGPoint
    let time: Date
    /// How long the departed dot lingers, fading, before disappearing.
    static let duration: TimeInterval = 1.0
}

/// One leg of the ball's current path. Most legs are a fixed pitch
/// position, but the wide-run and box-run legs of a triggered attack
/// resolve to whichever real player is currently making that run —
/// their *live* position every tick, not the fixed point they're
/// independently steering toward — so the ball visibly seeks a moving
/// target on the way out to the winger/striker rather than beelining
/// for a spot they merely happen to end up at. `fallback` covers the
/// (should-never-happen-with-a-full-XI) case where no player was found
/// to assign that run to.
private enum BallWaypoint {
    case fixed(CGPoint)
    case followPlayer(id: String, fallback: CGPoint)
}

/// A shot or big chance resolving — `LegendsLiveMatchPitchView` reads
/// this to flash the goal mouth briefly. Compared by `time`, not
/// identity, so the view can tell a *new* impact from the one it already
/// rendered without needing its own extra state.
struct BallImpact: Equatable {
    enum Kind { case goal, chance }
    let position: CGPoint
    let kind: Kind
    let time: Date
    /// Names and action roles selected by the same detailed-attribute
    /// selectors that cast the on-pitch runners. Kept on the impact
    /// snapshot so the renderer can show a meaningful, stable event label
    /// without rereading mutable simulation state after the sequence ends.
    let runnerName: String?
    let finisherName: String?
    let markerName: String?

    init(position: CGPoint, kind: Kind, time: Date,
         runnerName: String? = nil, finisherName: String? = nil, markerName: String? = nil) {
        self.position = position
        self.kind = kind
        self.time = time
        self.runnerName = runnerName
        self.finisherName = finisherName
        self.markerName = markerName
    }
}

/// One queued attack sequence waiting behind the currently-playing one —
/// the same two inputs `triggerAttack(forUser:scored:)` takes, replayed
/// verbatim once the active sequence resolves.
private struct PendingAttack {
    let forUser: Bool
    let scored: Bool
}

// Deliberately not @Observable: the rendering view drives its Canvas
// redraws off TimelineView's own per-frame ticks (see
// LegendsLiveMatchPitchView.swift), not Observation change-tracking, so
// there's nothing for change-tracking to buy here. Plain @MainActor
// reference semantics are all this needs.
@MainActor
final class LegendsMatchSimulation {
    private(set) var players: [PlayerSimState]
    private(set) var ball = BallState(position: CGPoint(x: 0.5, y: 0.5))
    private(set) var lastImpact: BallImpact?

    /// Scales every tick's `dt` before it touches the ball or any player's
    /// steering — the view keeps this in lockstep with the real match's
    /// own `LegendsLiveMatch.speed` (1×/2×/3×) and `0` while paused/at
    /// half-time, so the pitch speeds up and stops exactly in step with
    /// the commentary rather than animating at a constant real-time pace
    /// regardless of what the match itself is doing.
    var speedMultiplier: Double = 1.0

    private var loopTask: Task<Void, Never>?

    /// The ball's current path — starts as the ambient idle loop and gets
    /// swapped out for a scripted attack sequence whenever `triggerAttack`
    /// fires, then swapped back once that sequence's last waypoint is
    /// reached.
    private var waypoints: [BallWaypoint] = LegendsMatchSimulation.idleWaypoints
    private var waypointIndex = 0
    private var pendingImpact: (index: Int, kind: BallImpact.Kind, runnerName: String?, finisherName: String?, markerName: String?)?

    /// The attack sequence currently playing out, if any — set by
    /// `startAttack` and cleared the instant the sequence's last waypoint
    /// is reached. While non-nil, further `triggerAttack` calls enqueue
    /// behind it (see `attackQueue`) rather than clobbering it.
    private var activeAttack: PendingAttack?
    /// Follow-up attacks waiting behind `activeAttack`, drained in FIFO
    /// order as each sequence resolves — see the file header's Phase 9
    /// note for why two can arrive in the same tick.
    private var attackQueue: [PendingAttack] = []

    /// Test-only: how many attack sequences have started since creation
    /// (immediate and dequeued alike) — lets tests confirm a queued
    /// second attack actually plays out after the active one resolves
    /// rather than being dropped.
    private(set) var testAttackStartCount = 0

    // MARK: - Possession

    /// Which team currently has the ball — set by `startAttack` (the
    /// attacking team) and flipped to the defending team the instant
    /// the sequence resolves (goal kick / kick-off), then recovered
    /// back to `.home` after a few idle ticks. Drives the pitch
    /// possession ring so it tracks the real possessor rather than just
    /// the player nearest the ball.
    private(set) var possessionTeam: Side = .home
    /// Idle ticks elapsed since the last sequence resolved — once this
    /// reaches `idleTicksToRecover`, possession resets to the home
    /// team (the user side recovers the ball during ambient play).
    private var idleTicksSinceSequenceEnd = 0
    /// How many idle ticks (at 10 Hz) before possession returns to the
    /// home team — 5 ticks ≈ 0.5s, long enough for a save/goal-kick
    /// visual to register but short enough that the ring snaps back
    /// quickly.
    static let idleTicksToRecover = 5

    /// The two attacking runners, the defending goalkeeper, and the
    /// marking defender from an active attack sequence, each mapped to a
    /// point — fixed (the ball's own waypoints, for the runners; the
    /// near-post dive target, for the keeper) for everyone except the
    /// marker, whose entry `tick()` overwrites every step to the ball's
    /// live position — read instead of the normal `teamShapeShift`
    /// formula in `tick()` for exactly these players, so the ball, its
    /// runners, the keeper's reaction, and the marker's chase all
    /// genuinely converge on the same moment. Cleared the instant the
    /// sequence resolves.
    private var runTargetOverrides: [String: CGPoint] = [:]

    /// The one defending outfield player chasing the current attack
    /// sequence, if any — the only run-target override `tick()` updates
    /// continuously rather than setting once in `triggerAttack`. `nil`
    /// outside an active sequence, or if the defending team had no
    /// non-goalkeeper player to assign (shouldn't happen with a full XI).
    private var markerID: String?
    /// Departed players' dots still fading out after substitutions — see
    /// `SubstitutionGhost`. Appended by `applySubstitution`, drained by
    /// `tick()` once each ghost's `duration` elapses; the view draws them
    /// with a falling alpha.
    private(set) var departingGhosts: [SubstitutionGhost] = []
    /// Incoming cards currently walking on from the touchline to the
    /// departed player's spot — a dictionary so two quick substitutions
    /// can each have their own walk-in. Read instead of the formation
    /// anchor in `tick()` for exactly these players, and cleared the
    /// tick they arrive.
    private var subWalkIns: [String: CGPoint] = [:]
    /// Which goal line the *defending* team's own goal sits on for the
    /// currently active sequence — 0 when the away team is defending
    /// (they defend the opponent's/y=0 goal, i.e. a home attack is live),
    /// 1 when the home team is defending. Used to bias the marker's
    /// chase target goal-side of the ball rather than straight at it.
    private var defendingGoalY: Double = 1

    /// A fixed loop of pitch positions the ball cycles through when no
    /// real event is driving it — kickoff, out to each attacking third
    /// and back — enough to keep the pitch visibly alive between chances.
    private static let idleWaypoints: [BallWaypoint] = [
        .fixed(CGPoint(x: 0.5, y: 0.5)),
        .fixed(CGPoint(x: 0.5, y: 0.22)),
        .fixed(CGPoint(x: 0.22, y: 0.14)),
        .fixed(CGPoint(x: 0.5, y: 0.5)),
        .fixed(CGPoint(x: 0.78, y: 0.14)),
        .fixed(CGPoint(x: 0.5, y: 0.22)),
        .fixed(CGPoint(x: 0.5, y: 0.5)),
        .fixed(CGPoint(x: 0.5, y: 0.78)),
        .fixed(CGPoint(x: 0.78, y: 0.86)),
        .fixed(CGPoint(x: 0.5, y: 0.5)),
        .fixed(CGPoint(x: 0.22, y: 0.86)),
        .fixed(CGPoint(x: 0.5, y: 0.78)),
    ]

    /// Preference order for who makes the wide crossing run and who
    /// finishes it — wingers/wide midfielders before wing-backs for the
    /// former (a winger's the more natural outlet), strikers before
    /// attacking mids/wingers for the latter. `first(where:)` over the
    /// team's actual roster, falling back to any teammate if a squad
    /// genuinely has none of the preferred roles (e.g. an unusual
    /// formation with no out-and-out winger).
    private static let wideRunnerPreference: [DetailedPosition] = [.leftWing, .rightWing, .leftMid, .rightMid, .leftBack, .rightBack]
    private static let finisherPreference: [DetailedPosition] = [.striker, .attackingMid, .leftWing, .rightWing]

    /// Speed the ball travels along its current path, in pitch-units (the
    /// same 0...1 normalized space players move in) per second.
    private let ballSpeed = 0.18

    /// How strongly a team's whole shape drifts sideways toward the
    /// ball's touchline position and forward/back with which third of
    /// the pitch it's in — small enough to read as organic shape rather
    /// than every player chasing the ball directly. Only applies to
    /// players not currently overridden by `runTargetOverrides`.
    private let sidewaysPull = 0.18
    private let depthPull = 0.24

    private let maxSpeed = 0.32
    private let steeringResponsiveness = 3.0

    init(userSlots: [(role: DetailedPosition, id: String, name: String)],
         userFormation: Formation,
         opponentFormation: Formation,
         opponentPlayers: [SyntheticOpponentPlayer],
         userDetailedAttributes: [String: LegendsDetailedAttributes] = [:]) {
        let userAnchors = PitchCoordinateSystem.anchors(for: userFormation, team: .home)
        let opponentAnchors = PitchCoordinateSystem.anchors(for: opponentFormation, team: .away)

        var built: [PlayerSimState] = []
        for (slot, anchor) in zip(userSlots, userAnchors) {
            built.append(PlayerSimState(id: slot.id, team: .home, role: slot.role, name: slot.name,
                                         baseAnchor: anchor, position: anchor, velocity: .zero, homeAnchor: anchor,
                                         detailed: userDetailedAttributes[slot.id] ?? .zero))
        }
        for (player, anchor) in zip(opponentPlayers, opponentAnchors) {
            built.append(PlayerSimState(id: player.id, team: .away, role: player.position, name: player.name,
                                         baseAnchor: anchor, position: anchor, velocity: .zero, homeAnchor: anchor,
                                         detailed: player.detailed))
        }
        players = built
    }

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in await self?.loop() }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    /// Replaces the user-side player occupying `slotIndex` with the card
    /// that just came on — the pitch dot becomes the new card (id + name)
    /// while keeping the slot's role, base anchor and current position,
    /// so a substitution visibly swaps the player mid-match rather than
    /// leaving the departed card's dot on the pitch. `slotIndex` is
    /// 0-based and matches `LegendsLiveMatch.onPitchCardIDs` — the user's
    /// XI occupies `players[0..<11]` in slot order (see `init`).
    ///
    /// If the departing player was mid-run in an active attack sequence
    /// (a runner, the marking defender, or the diving keeper), their
    /// override is released rather than left pointing at a player who is
    /// no longer on the pitch — the ball's `followPlayer` legs degrade to
    /// their fixed fallback points.
    ///
    /// The handover is animated rather than a cut: the departed card's
    /// dot lingers as a fading `SubstitutionGhost` where they stood, and
    /// the incoming card appears at the near touchline (at the departed
    /// player's depth) and walks across to their spot before taking up
    /// the normal formation shape — a sub runs on from the bench instead
    /// of materializing in place.
    func applySubstitution(slotIndex: Int, cardID: String, name: String, replacementDetailed: LegendsDetailedAttributes? = nil) {
        guard players.indices.contains(slotIndex) else { return }
        let departing = players[slotIndex]
        guard departing.id != cardID else { return }
        departingGhosts.append(SubstitutionGhost(id: departing.id, name: departing.name,
                                                 position: departing.position, time: Date()))
        let spawnX = departing.position.x < 0.5 ? 0.02 : 0.98
        players[slotIndex] = PlayerSimState(id: cardID, team: departing.team, role: departing.role,
                                            name: name, baseAnchor: departing.baseAnchor,
                                            position: CGPoint(x: spawnX, y: departing.position.y),
                                            velocity: .zero, homeAnchor: departing.position,
                                            detailed: replacementDetailed ?? departing.detailed)
        subWalkIns[cardID] = departing.position
        runTargetOverrides.removeValue(forKey: departing.id)
        if markerID == departing.id { markerID = nil }
    }

    /// Loads a scripted buildup → wide flank → cross → shot sequence for
    /// whichever team just had a real goal or big chance in the actual
    /// match, interrupting the ambient idle loop, and hands the wide-run
    /// and finishing-run legs to two real players from that team so they
    /// physically make the runs the ball is following. `forUser: true`
    /// means the home/user side is attacking; `scored: true` means the
    /// sequence ends in the net.
    ///
    /// `scored: false` means a *save*, not a wayward shot — Legends'
    /// commentary only ever narrates a non-scoring big chance as "the
    /// keeper stands tall!" (matching Career Mode's own big-chance line),
    /// never a shot ballooned over the bar. So the shot travels to
    /// exactly where the defending goalkeeper's own `runTargetOverrides`
    /// entry sends them — both converge on the same point, the save
    /// itself — rather than the keeper diving decoratively while the
    /// ball goes somewhere unrelated. A goal, by contrast, goes to the
    /// far post (away from the cross side) while the keeper commits to
    /// the near post — wrong-footed, beaten by design.
    func triggerAttack(forUser: Bool, scored: Bool) {
        // A sequence is already mid-flight (or queued) — the single-ball
        // model can only play one at a time, so this one waits its turn
        // rather than replacing the in-flight sequence and dropping the
        // first event's on-pitch moment (Phase 9).
        guard activeAttack == nil else {
            attackQueue.append(PendingAttack(forUser: forUser, scored: scored))
            return
        }
        startAttack(forUser: forUser, scored: scored)
    }

    /// Builds and starts one attack sequence for the given side/outcome —
    /// the shared body behind both an immediate `triggerAttack` and a
    /// dequeued follow-up (see `advanceBall`'s resolution branch).
    private func startAttack(forUser: Bool, scored: Bool) {
        activeAttack = PendingAttack(forUser: forUser, scored: scored)
        testAttackStartCount += 1
        possessionTeam = forUser ? .home : .away
        idleTicksSinceSequenceEnd = 0

        let attackingTeam: Side = forUser ? .home : .away
        let defendingTeam: Side = forUser ? .away : .home
        let attackers = players.filter { $0.team == attackingTeam }
        let defenders = players.filter { $0.team == defendingTeam }

        // Point 2: attribute-driven run casting. The wide outlet is the
        // best crossing/speed candidate among the preferred wide roles
        // (falling back through the preference list, then any teammate);
        // the finisher is the best shooting/positioning candidate among
        // the finishing roles. Deterministic on the roster — no extra
        // randomness beyond the flank coin below.
        let wideRunner = Self.pickRunner(
            from: attackers, preferring: Self.wideRunnerPreference,
            score: { LegendsMatchSelectors.passing($0.detailed) + $0.detailed.sprintSpeed }
        )
        let finisher = Self.pickRunner(
            from: attackers.filter { $0.id != wideRunner?.id }, preferring: Self.finisherPreference,
            score: { LegendsMatchSelectors.shooting($0.detailed) + $0.detailed.positioning }
        )

        let wideLeft = Bool.random()
        let wideX = wideLeft ? 0.14 : 0.86
        let farPostX = wideLeft ? 0.62 : 0.38
        let nearPostX = wideLeft ? 0.38 : 0.62

        var widePoint = CGPoint(x: wideX, y: 0.16)
        var finisherPoint = CGPoint(x: 0.5, y: 0.06)
        var keeperDivePoint = CGPoint(x: nearPostX, y: 0.03)
        // A goal beats the keeper at the far post; a save meets them
        // exactly where they're diving to — same point, so the two
        // waypoints below (shot and keeper) are deliberately identical
        // for `!scored`.
        var shotPoint = scored ? CGPoint(x: farPostX, y: 0.015) : keeperDivePoint
        if !forUser {
            widePoint.y = 1 - widePoint.y
            finisherPoint.y = 1 - finisherPoint.y
            shotPoint.y = 1 - shotPoint.y
            keeperDivePoint.y = 1 - keeperDivePoint.y
        }

        var points: [BallWaypoint] = [
            .fixed(CGPoint(x: 0.5, y: forUser ? 0.42 : 0.58)),
            .fixed(CGPoint(x: 0.5, y: forUser ? 0.28 : 0.72)),
            wideRunner.map { BallWaypoint.followPlayer(id: $0.id, fallback: widePoint) } ?? .fixed(widePoint),
            finisher.map { BallWaypoint.followPlayer(id: $0.id, fallback: finisherPoint) } ?? .fixed(finisherPoint),
            .fixed(shotPoint),
        ]
        let impactIndex = points.count - 1
        if !scored {
            points.append(.fixed(CGPoint(x: 0.5, y: forUser ? 0.35 : 0.65)))
        }

        waypoints = points
        waypointIndex = 0
        pendingImpact = (
            impactIndex,
            scored ? .goal : .chance,
            wideRunner?.name,
            finisher?.name,
            markerID.flatMap { id in players.first(where: { $0.id == id })?.name }
        )

        runTargetOverrides.removeAll()
        if let wideRunner {
            runTargetOverrides[wideRunner.id] = widePoint
        }
        if let finisher {
            runTargetOverrides[finisher.id] = finisherPoint
        }
        if let keeper = defenders.first(where: { $0.role == .goalkeeper }) {
            runTargetOverrides[keeper.id] = keeperDivePoint
        }

        defendingGoalY = forUser ? 0 : 1
        let outfieldDefenders = defenders.filter { $0.role != .goalkeeper }
        // The marker is the defending outfielder with the best defending
        // selector score (positioning/anticipation/tackling) among the
        // three closest to the wide run — closing-down duty goes to the
        // defender best equipped for it, not merely the nearest body.
        if outfieldDefenders.count > 3 {
            let nearestThree = Array(
                outfieldDefenders
                    .sorted { distance($0.position, widePoint) < distance($1.position, widePoint) }
                    .prefix(3)
            )
            let closest = nearestThree.max { lhs, rhs in
                LegendsMatchSelectors.defending(lhs.detailed) < LegendsMatchSelectors.defending(rhs.detailed)
            }
            markerID = closest?.id
        } else {
            markerID = outfieldDefenders.min(by: { distance($0.position, widePoint) < distance($1.position, widePoint) })?.id
        }
        if let markerID {
            runTargetOverrides[markerID] = players.first(where: { $0.id == markerID })?.position
        }
    }

    /// Attribute-aware role-preference pick: candidates are ordered by the
    /// caller's role preference list, and within the best available role
    /// tier the highest-scoring candidate wins (deterministic tie-break on
    /// id so equal-quality players resolve stably). Falls back to any
    /// teammate when no preferred role exists (e.g. an unusual formation
    /// with no out-and-out winger).
    private static func pickRunner(
        from team: [PlayerSimState],
        preferring roles: [DetailedPosition],
        score: (PlayerSimState) -> Int
    ) -> PlayerSimState? {
        guard !team.isEmpty else { return nil }
        for role in roles {
            let tier = team.filter { $0.role == role }
            if let best = tier.max(by: { score($0) < score($1) }) {
                return best
            }
        }
        return team.max(by: { score($0) < score($1) })
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Synchronous single-step advance, no delay and no background `Task`
    /// — the async-free path unit tests drive instead of `start()`'s real
    /// loop, mirroring `LegendsLiveMatch.testAdvanceMinute()`.
    func testAdvance(dt: Double) {
        tick(dt: dt)
    }

    /// Test-only: whether `playerID` currently has a run-target override
    /// from an in-progress attack sequence — lets tests confirm Phase 3's
    /// player/ball coupling without exposing the dictionary itself.
    func testHasRunOverride(for playerID: String) -> Bool {
        runTargetOverrides[playerID] != nil
    }

    /// Test-only: the ID of the defender currently chasing the ball for
    /// an active attack sequence, if any — lets tests confirm Phase 5's
    /// live marking without exposing `markerID` itself as a stored property.
    func testMarkerID() -> String? {
        markerID
    }

    /// Test-only: how many departed-player ghosts are still fading out
    /// after substitutions — lets tests confirm the bench handover's
    /// departing dot appears and expires without exposing the array.
    func testDepartingGhostCount() -> Int {
        departingGhosts.count
    }

    /// Test-only: the spot `playerID`'s substitution walk-in is currently
    /// aiming at, `nil` if they're not walking on — lets tests confirm the
    /// incoming card enters from the touchline and heads for the departed
    /// player's exact position without exposing `subWalkIns` itself.
    func testSubWalkInTarget(for playerID: String) -> CGPoint? {
        subWalkIns[playerID]
    }

    /// Test-only: which player ID (if any) the ball's `index`-th waypoint
    /// leg is following live — `nil` if that leg is a fixed point instead,
    /// or `index` is out of range. Lets tests confirm Phase 7's ball/runner
    /// coupling without exposing `waypoints`/`BallWaypoint` themselves.
    func testFollowedPlayerID(atLegIndex index: Int) -> String? {
        guard waypoints.indices.contains(index) else { return nil }
        if case .followPlayer(let id, _) = waypoints[index] { return id }
        return nil
    }

    private func loop() async {
        var lastTick = Date()
        while !Task.isCancelled {
            let now = Date()
            // Clamped so a stall (background/debugger pause) can't feed a
            // huge dt into the steering integration and fling players
            // across the pitch on resume.
            let dt = min(now.timeIntervalSince(lastTick), 0.2)
            lastTick = now
            tick(dt: dt)
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func tick(dt: Double) {
        let scaledDt = dt * speedMultiplier
        advanceBall(dt: scaledDt)
        if let markerID {
            let goalSideY = ball.position.y + (defendingGoalY - ball.position.y) * 0.15
            runTargetOverrides[markerID] = CGPoint(x: ball.position.x, y: goalSideY)
        }
        let shift = teamShapeShift(ballPosition: ball.position)
        for index in players.indices {
            let anchor: CGPoint
            if let override = runTargetOverrides[players[index].id] {
                anchor = override
            } else if let walkTarget = subWalkIns[players[index].id] {
                anchor = walkTarget
            } else {
                anchor = clampedToPitch(CGPoint(
                    x: players[index].baseAnchor.x + (ball.position.x - players[index].baseAnchor.x) * sidewaysPull,
                    y: players[index].baseAnchor.y + shift
                ))
            }
            players[index].homeAnchor = anchor
            steer(&players[index], dt: scaledDt)
        }
        // A walk-in ends the tick its card reaches the departed spot —
        // next tick they steer to the normal formation shape instead.
        let arrived = subWalkIns.compactMap { id, target -> String? in
            guard let index = players.firstIndex(where: { $0.id == id }),
                  distance(players[index].position, target) < 0.02 else { return nil }
            return id
        }
        for id in arrived { subWalkIns.removeValue(forKey: id) }
        departingGhosts.removeAll { Date().timeIntervalSince($0.time) >= SubstitutionGhost.duration }
        // After a sequence ends, the defending team briefly has the ball
        // (goal kick / kick-off) before the home team recovers during
        // ambient play.
        if activeAttack == nil {
            idleTicksSinceSequenceEnd += 1
            if idleTicksSinceSequenceEnd >= Self.idleTicksToRecover {
                possessionTeam = .home
            }
        }
    }

    /// The pitch position a leg is currently aiming for — the leg's own
    /// fixed point, or (for `.followPlayer`) wherever that player's
    /// `position` actually is *right now*, re-read fresh every tick so a
    /// still-moving runner visibly pulls the ball toward them rather than
    /// the ball beelining for a point the runner merely ends up at.
    private func resolvedPosition(for waypoint: BallWaypoint) -> CGPoint {
        switch waypoint {
        case .fixed(let point):
            return point
        case .followPlayer(let id, let fallback):
            return players.first(where: { $0.id == id })?.position ?? fallback
        }
    }

    private func advanceBall(dt: Double) {
        guard waypointIndex < waypoints.count else { return }
        let target = resolvedPosition(for: waypoints[waypointIndex])
        let dx = target.x - ball.position.x
        let dy = target.y - ball.position.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let step = ballSpeed * dt

        if distance <= step {
            ball.position = target
            if let pending = pendingImpact, pending.index == waypointIndex {
                lastImpact = BallImpact(
                    position: target,
                    kind: pending.kind,
                    time: Date(),
                    runnerName: pending.runnerName,
                    finisherName: pending.finisherName,
                    markerName: pending.markerName
                )
                pendingImpact = nil
            }
            waypointIndex += 1
            if waypointIndex >= waypoints.count {
                // An attack sequence finished — play any follow-up attack
                // that was queued behind it before handing back to the
                // ambient idle loop (Phase 9).
                if let currentAttack = activeAttack {
                    activeAttack = nil
                    if !attackQueue.isEmpty {
                        let next = attackQueue.removeFirst()
                        startAttack(forUser: next.forUser, scored: next.scored)
                        return // startAttack sets possession
                    }
                    // No queued attack — the defending team gains the ball
                    // (goal kick after a save, or kick-off after conceding).
                    possessionTeam = currentAttack.forUser ? .away : .home
                    idleTicksSinceSequenceEnd = 0
                }
                // Sequence finished (or the idle loop lapped) — resume/
                // restart the ambient loop from wherever the ball ended
                // up, and release this sequence's two runners back to
                // the normal ball-relative formation shape.
                waypoints = LegendsMatchSimulation.idleWaypoints
                waypointIndex = 0
                runTargetOverrides.removeAll()
                markerID = nil
            }
        } else {
            ball.position.x += dx / distance * step
            ball.position.y += dy / distance * step
        }
    }

    /// The shared, direction-consistent "how deep is this team sitting"
    /// signal both teams' anchors shift by (see the file's header note —
    /// working out the sign for each team separately turns out to reduce
    /// to the exact same formula, since y=1 is uniformly "toward the
    /// home team's own goal / the away team's attacking third" in this
    /// shared coordinate frame).
    private func teamShapeShift(ballPosition: CGPoint) -> Double {
        (ballPosition.y - 0.5) * depthPull
    }

    private func steer(_ player: inout PlayerSimState, dt: Double) {
        let toAnchor = CGVector(dx: player.homeAnchor.x - player.position.x, dy: player.homeAnchor.y - player.position.y)
        let distance = (toAnchor.dx * toAnchor.dx + toAnchor.dy * toAnchor.dy).squareRoot()

        let desired: CGVector
        if distance < 0.004 {
            desired = .zero
        } else {
            let speed = min(maxSpeed, distance * 4)
            desired = CGVector(dx: toAnchor.dx / distance * speed, dy: toAnchor.dy / distance * speed)
        }

        let ease = min(1, dt * steeringResponsiveness)
        player.velocity = CGVector(
            dx: player.velocity.dx + (desired.dx - player.velocity.dx) * ease,
            dy: player.velocity.dy + (desired.dy - player.velocity.dy) * ease
        )
        let moved = CGPoint(x: player.position.x + player.velocity.dx * dt, y: player.position.y + player.velocity.dy * dt)
        player.position = clampedToPitch(moved)
    }

    private func clampedToPitch(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(0.98, max(0.02, point.x)), y: min(0.98, max(0.02, point.y)))
    }
}
