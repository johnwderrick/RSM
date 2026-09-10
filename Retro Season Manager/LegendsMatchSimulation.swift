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
//  (goal, chance, or handoff back to continuous open play), letting them steer
//  back into the possession-aware formation shape `openPlayAnchor`
//  drives for everyone else. Goal/score logic itself remains untouched:
//  open play, pressing and turnovers make the visual layer believable
//  without feeding a second result model back into `LegendsLiveMatch`.
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
    /// Recomputed every physics tick from `baseAnchor` plus the current
    /// possession-aware team shape, or
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
    let eventID: String?
    let runnerID: String?
    let finisherID: String?
    let markerID: String?
    let goalkeeperID: String?

    init(position: CGPoint, kind: Kind, time: Date,
         runnerName: String? = nil, finisherName: String? = nil, markerName: String? = nil,
         eventID: String? = nil, runnerID: String? = nil, finisherID: String? = nil,
         markerID: String? = nil, goalkeeperID: String? = nil) {
        self.position = position
        self.kind = kind
        self.time = time
        self.runnerName = runnerName
        self.finisherName = finisherName
        self.markerName = markerName
        self.eventID = eventID
        self.runnerID = runnerID
        self.finisherID = finisherID
        self.markerID = markerID
        self.goalkeeperID = goalkeeperID
    }
}

/// One queued attack sequence waiting behind the currently-playing one —
/// the same two inputs `triggerAttack(forUser:scored:)` takes, replayed
/// verbatim once the active sequence resolves.
private struct PendingAttack {
    let forUser: Bool
    let scored: Bool
    let event: LegendsMatchEvent?

    init(forUser: Bool, scored: Bool, event: LegendsMatchEvent? = nil) {
        self.forUser = forUser
        self.scored = scored
        self.event = event
    }

    init(event: LegendsMatchEvent) {
        self.init(forUser: event.isUserEvent, scored: event.scored, event: event)
    }
}

/// The visible choice made by the player in possession during continuous
/// open play. These decisions affect only how the authoritative match is
/// represented; they never create goals or rewrite engine outcomes.
enum LegendsAmbientAction: String, Equatable {
    case carry
    case receive
    case progressivePass
    case recycle
    case switchPlay
    case interceptedPass
}

/// One real continuous-possession action shared by the pitch and the radio
/// commentary feed. Participants are captured when the decision happens;
/// neither consumer has to infer them from prose or from nearby positions.
struct LegendsAmbientActionEvent: Identifiable, Equatable {
    let id: String
    let sequence: Int
    let action: LegendsAmbientAction
    let team: Side
    let actorID: String
    let actorName: String
    let receiverID: String?
    let receiverName: String?
    let defenderID: String?
    let defenderName: String?
    let text: String

    init(sequence: Int, action: LegendsAmbientAction, team: Side,
         actorID: String, actorName: String,
         receiverID: String? = nil, receiverName: String? = nil,
         defenderID: String? = nil, defenderName: String? = nil) {
        self.id = "A\(sequence)"
        self.sequence = sequence
        self.action = action
        self.team = team
        self.actorID = actorID
        self.actorName = actorName
        self.receiverID = receiverID
        self.receiverName = receiverName
        self.defenderID = defenderID
        self.defenderName = defenderName
        self.text = Self.commentaryText(sequence: sequence, action: action,
                                        actorName: actorName, receiverName: receiverName,
                                        defenderName: defenderName)
    }

    private static func commentaryText(sequence: Int, action: LegendsAmbientAction,
                                       actorName: String, receiverName: String?,
                                       defenderName: String?) -> String {
        switch action {
        case .carry:
            switch sequence % 6 {
            case 0: return "\(actorName) carries it forward..."
            case 1: return "\(actorName) drives into midfield..."
            case 2: return "There's space ahead of \(actorName)..."
            case 3: return "\(actorName) moves forward with the ball..."
            case 4: return "\(actorName) holds possession under pressure..."
            default: return "Still \(actorName), looking for support..."
            }
        case .receive:
            switch sequence % 6 {
            case 0: return "\(actorName) takes it under control..."
            case 1: return "\(actorName) cushions the pass..."
            case 2: return "\(actorName) brings it down neatly..."
            case 3: return "\(actorName) takes a touch and looks up..."
            case 4: return "Good first touch from \(actorName)..."
            default: return "\(actorName) receives with the move still on..."
            }
        case .progressivePass:
            guard let receiverName else { return "\(actorName) looks forward..." }
            switch sequence % 6 {
            case 0: return "\(actorName) finds \(receiverName) ahead..."
            case 1: return "\(actorName) feeds \(receiverName) forward..."
            case 2: return "\(actorName) moves it quickly into \(receiverName)..."
            case 3: return "\(actorName) threads it forward to \(receiverName)..."
            case 4: return "\(actorName) turns it around the corner to \(receiverName)..."
            default: return "A clever ball into \(receiverName) from \(actorName)..."
            }
        case .recycle:
            guard let receiverName else { return "They recycle possession..." }
            switch sequence % 6 {
            case 0: return "Back to \(receiverName)..."
            case 1: return "\(actorName) sends it back to \(receiverName)..."
            case 2: return "They recycle possession through \(receiverName)..."
            case 3: return "RSM start again from \(receiverName)..."
            case 4: return "\(actorName) keeps it moving back to \(receiverName)..."
            default: return "Simple ball to \(receiverName) from \(actorName)..."
            }
        case .switchPlay:
            guard let receiverName else { return "They switch the play..." }
            switch sequence % 6 {
            case 0: return "\(actorName) switches the play to \(receiverName)..."
            case 1: return "The ball is worked across to \(receiverName)..."
            case 2: return "Out wide to \(receiverName)..."
            case 3: return "\(actorName) moves it wide to \(receiverName)..."
            case 4: return "They move it from side to side, finding \(receiverName)..."
            default: return "\(actorName) opens the pitch up for \(receiverName)..."
            }
        case .interceptedPass:
            let target = receiverName.map { " towards \($0)" } ?? ""
            let defender = defenderName ?? "the defender"
            switch sequence % 4 {
            case 0: return "\(defender) steps across and intercepts \(actorName)'s ball\(target)..."
            case 1: return "\(actorName) tries it\(target), but \(defender) reads the pass..."
            case 2: return "The pass is cut out by \(defender), who wins it back..."
            default: return "\(defender) gets there first and intercepts for the other side..."
            }
        }
    }
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
    /// The exact authoritative commentary beat the ball is currently
    /// performing. The pitch reads this value on every render tick so the
    /// sentence shown to the player and the visible action cannot drift.
    private(set) var currentPresentationText: String?
    private(set) var currentPresentationSide: Side?
    private(set) var currentPresentationEventID: String?
    /// The latest radio line for continuous possession. It is the same
    /// immutable action event delivered to `LegendsLiveMatch`, so the pitch
    /// subtitle and the commentary feed cannot describe different actions.
    private(set) var currentAmbientCommentaryText: String?
    private(set) var currentAmbientCommentarySide: Side?
    private(set) var currentAmbientActionEvent: LegendsAmbientActionEvent?
    private(set) var isPresentingRestart = false
    /// The football action currently being performed, plus the ordered
    /// history completed for this event. These are presentation facts only:
    /// they cannot alter the authoritative result.
    private(set) var currentPresentationAction: LegendsPresentationAction?
    private(set) var completedPresentationActions: [LegendsPresentationAction] = []
    /// During control, preparation and carries the possession halo belongs
    /// to the actual scripted actor. It becomes nil the instant a pass,
    /// cross or shot is released and transfers to the receiver on arrival.
    private var scriptedPossessorID: String?
    private var currentLegElapsed = 0.0
    /// Fired when a scripted goal actually reaches its goal-mouth waypoint,
    /// not when the match engine changes the score several seconds earlier.
    var onGoalPresented: ((LegendsMatchEvent) -> Void)?
    /// Fired when an authored beat begins. The live match uses this to put
    /// the same passer, receiver or defender into the text feed at the
    /// moment the corresponding pitch action starts.
    var onPresentationBeat: ((LegendsMatchEvent, LegendsPresentationBeat, Int) -> Void)?
    /// Fired once for each real continuous-possession decision. The live
    /// engine consumes the authored text; the pitch retains the same event
    /// as its current radio line.
    var onAmbientAction: ((LegendsAmbientActionEvent) -> Void)?
    /// Fired when a direct restart state is installed. The restart is already
    /// at its authoritative location; this callback only narrates that same
    /// state in the live commentary feed. The optional name is the structured
    /// taker selected for a corner or direct free kick.
    var onRestartPresentation: ((LegendsMatchRestart, String?) -> Void)?
    /// Called only after the final visual waypoint for an authoritative
    /// event resolves. The live engine uses this acknowledgement to release
    /// its presentation hold and advance to the next minute/commentary line.
    var onEventPresentationCompleted: ((String) -> Void)?

    /// Kept live with the match controls. Tactics change only the visual
    /// decisions and team shape here; the authoritative live engine remains
    /// solely responsible for chances, goals and the final score.
    var userMentality: Mentality
    var userInstruction: MatchInstruction

    /// Scales every tick's `dt` before it touches the ball or any player's
    /// steering — the view keeps this in lockstep with the real match's
    /// own `LegendsLiveMatch.speed` (1×/2×/3×) and `0` while paused/at
    /// half-time, so the pitch speeds up and stops exactly in step with
    /// the commentary rather than animating at a constant real-time pace
    /// regardless of what the match itself is doing.
    var speedMultiplier: Double = 1.0

    private var loopTask: Task<Void, Never>?

    /// The ball's scripted path while a real engine chance is being shown.
    /// Ordinary play is handled by the continuous possession state below,
    /// rather than a repeating list of fixed pitch coordinates.
    private var waypoints: [BallWaypoint] = []
    private var waypointIndex = 0
    private var pendingImpact: (index: Int, kind: BallImpact.Kind, runnerName: String?, finisherName: String?, markerName: String?, eventID: String?, runnerID: String?, finisherID: String?, markerID: String?, goalkeeperID: String?)?

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

    /// Scripted chances alternate flanks from a stable starting side. The
    /// 2D layer is explanatory rather than authoritative, so an unseeded
    /// coin toss here only made identical match inputs render differently
    /// and made snapshot tests order-dependent.
    private var nextAttackUsesLeftFlank = true
    private(set) var testLastAttackUsedLeftFlank: Bool?
    private(set) var testLastAttackPattern: LegendsMatchEvent.AttackPattern?

    // MARK: - Possession

    /// Which team currently has the ball — set by open play and by real
    /// attack events, then handed to the side entitled to the restart.
    private(set) var possessionTeam: Side = .home
    /// The player visibly controlling the ball in settled open play. `nil`
    /// while a pass or scripted attack is in flight, so proximity alone
    /// cannot award the possession halo to an unrelated player.
    var possessionPlayerID: String? {
        if activeAttack != nil { return scriptedPossessorID }
        guard ambientPassTargetID == nil else { return nil }
        return ambientPossessorID
    }
    /// Continuous open-play state. The ball belongs to a real player,
    /// travels toward a real receiving teammate, and occasionally changes
    /// sides through a visible interception instead of teleporting or
    /// automatically returning to the user team.
    private var ambientPossessorID: String?
    private var ambientPreviousPossessorID: String?
    private var ambientPassTargetID: String?
    private var ambientPresserID: String?
    private var pendingAmbientTurnoverTeam: Side?
    private var ambientHoldElapsed = 0.0
    private var ambientCompletedPasses = 0
    private var ambientSequencePasses = 0
    private var ambientDecisionIndex = 0
    private(set) var testLastAmbientAction: LegendsAmbientAction?
    private(set) var testAmbientActionHistory: [LegendsAmbientAction] = []
    private(set) var ambientActionEvents: [LegendsAmbientActionEvent] = []
    private var ambientCommentarySequence = 0

    private let ambientHoldDuration = 0.55

    /// Open-play responsibilities are recalculated from the live possessor
    /// and ball position. Two teammates offer a passing triangle; the
    /// defending side assigns one presser, one covering defender and up to
    /// two goal-side markers. IDs are stable for identical simulation state.
    private var supportPlayerIDs: [String] = []
    private var coverDefenderID: String?
    private var markingAssignments: [String: String] = [:]

    /// The two attacking runners, the defending goalkeeper, and the
    /// marking defender from an active attack sequence, each mapped to a
    /// point — fixed (the ball's own waypoints, for the runners; the
    /// near-post dive target, for the keeper) for everyone except the
    /// marker, whose entry `tick()` overwrites every step to the ball's
    /// live position — read instead of the normal open-play shape
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

    /// The last restart placed by an authoritative event. Restart locations
    /// are state transitions, not ball-travel waypoints: the ball is placed
    /// directly at this position once the preceding action finishes.
    private(set) var lastRestart: LegendsMatchRestart?
    private(set) var directRestartCount = 0

    /// A short restart presentation keeps the goal/dead-ball reaction visible
    /// while the ball is already in its legally correct location. It never
    /// advances the ball between unrelated states.
    private var restartPresentationElapsed = 0.0
    private let restartPresentationDuration = 0.35
    /// A goal restart remains at the centre spot until the goal card/flash
    /// has dismissed. This prevents normal open play from pulling the ball
    /// away from centre while the celebration is still on screen.
    private var waitingForGoalCardDismissalEventID: String?
    private var kickoffTakerID: String?
    private var kickoffTakerPosition: CGPoint?
    private var restartSetupTargets: [String: CGPoint] = [:]
    private var holdsGoalCardRestart = false
    /// Gives the final shot/save/block a complete render tick before the
    /// direct restart resets the players. The ball and the outcome remain
    /// authoritative immediately; only the restart transition is deferred
    /// so a keeper/defender can be seen at the same point as the impact.
    private var restartPendingAfterImpact = false

    /// Which goal line the *defending* team's own goal sits on for the
    /// currently active sequence — 0 when the away team is defending
    /// (they defend the opponent's/y=0 goal, i.e. a home attack is live),
    /// 1 when the home team is defending. Used to bias the marker's
    /// chase target goal-side of the ball rather than straight at it.
    private var defendingGoalY: Double = 1

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
         userDetailedAttributes: [String: LegendsDetailedAttributes] = [:],
         userMentality: Mentality = .balanced,
         userInstruction: MatchInstruction = .balanced) {
        self.userMentality = userMentality
        self.userInstruction = userInstruction
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
        ambientPossessorID = Self.closestOutfieldPlayer(
            in: built, team: .home, to: CGPoint(x: 0.5, y: 0.5)
        )?.id
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
    /// match, interrupting continuous open play, and hands the wide-run
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
        enqueueOrStart(PendingAttack(forUser: forUser, scored: scored))
    }

    /// Production entry point. The engine has already chosen every actor,
    /// outcome and channel; the renderer only animates that immutable event.
    func trigger(_ event: LegendsMatchEvent) {
        enqueueOrStart(PendingAttack(event: event))
    }

    private func enqueueOrStart(_ attack: PendingAttack) {
        // A sequence is already mid-flight (or queued) — the single-ball
        // model can only play one at a time, so this one waits its turn
        // rather than replacing the in-flight sequence and dropping the
        // first event's on-pitch moment (Phase 9).
        guard activeAttack == nil else {
            attackQueue.append(attack)
            return
        }
        startAttack(attack)
    }

    /// Builds and starts one attack sequence for the given side/outcome —
    /// the shared body behind both an immediate `triggerAttack` and a
    /// dequeued follow-up (see `advanceBall`'s resolution branch).
    private func startAttack(_ attack: PendingAttack) {
        let forUser = attack.forUser
        let scored = attack.scored
        let authoritative = attack.event
        let presentation = authoritative?.presentationScript
        activeAttack = attack
        currentPresentationText = presentation?.beats.first?.text
        currentPresentationSide = authoritative?.side
        currentPresentationEventID = authoritative?.id
        currentAmbientCommentaryText = nil
        currentAmbientCommentarySide = nil
        currentAmbientActionEvent = nil
        waitingForGoalCardDismissalEventID = nil
        kickoffTakerID = nil
        kickoffTakerPosition = nil
        restartSetupTargets.removeAll()
        isPresentingRestart = false
        restartPresentationElapsed = 0
        restartPendingAfterImpact = false
        currentPresentationAction = presentation?.beats.first?.action
        completedPresentationActions = []
        scriptedPossessorID = presentation?.beats.first.flatMap { possessorID(for: $0) }
        currentLegElapsed = 0
        testAttackStartCount += 1
        possessionTeam = forUser ? .home : .away
        ambientPassTargetID = nil
        ambientPresserID = nil
        pendingAmbientTurnoverTeam = nil
        ambientHoldElapsed = 0
        clearOpenPlayAssignments()

        let attackingTeam: Side = forUser ? .home : .away
        let defendingTeam: Side = forUser ? .away : .home
        let attackers = players.filter { $0.team == attackingTeam }
        let defenders = players.filter { $0.team == defendingTeam }

        // Point 2: attribute-driven run casting. The wide outlet is the
        // best crossing/speed candidate among the preferred wide roles
        // (falling back through the preference list, then any teammate);
        // the finisher is the best shooting/positioning candidate among
        // the finishing roles. Deterministic on the roster — no extra
        // randomness beyond the deterministic flank rotation below.
        let authoritativeRunner = presentation.flatMap { script -> PlayerSimState? in
            guard let creatorID = script.creatorID else { return nil }
            return attackers.first { $0.id == creatorID }
        }
        let wideRunner = authoritativeRunner
            ?? Self.pickRunner(from: attackers, preferring: Self.wideRunnerPreference,
                               score: { LegendsMatchSelectors.passing($0.detailed) + $0.detailed.sprintSpeed })
        let authoritativeFinisher = presentation.flatMap { script in
            attackers.first { $0.id == script.shooterID }
        }
        let finisher = authoritativeFinisher
            ?? Self.pickRunner(from: attackers.filter { $0.id != wideRunner?.id }, preferring: Self.finisherPreference,
                               score: { LegendsMatchSelectors.shooting($0.detailed) + $0.detailed.positioning })

        let wideLeft: Bool
        if let presentation {
            wideLeft = presentation.channel == .left
        } else {
            wideLeft = nextAttackUsesLeftFlank
            nextAttackUsesLeftFlank.toggle()
        }
        testLastAttackUsedLeftFlank = wideLeft
        let pattern = presentation?.attackPattern ?? .wideCross
        let outcome = presentation?.outcome ?? (scored ? .goal : .saved)
        testLastAttackPattern = pattern
        let channelX = wideLeft ? 0.14 : 0.86
        let farPostX = wideLeft ? 0.62 : 0.38
        let nearPostX = wideLeft ? 0.38 : 0.62

        /// Coordinates are described for a home attack toward y=0, then
        /// mirrored for the away team. Every route still ends with the exact
        /// authoritative shooter/outcome selected by the match engine.
        func attackPoint(_ x: Double, _ homeY: Double) -> CGPoint {
            CGPoint(x: x, y: forUser ? homeY : 1 - homeY)
        }

        func presentationPoint(_ zone: LegendsPresentationZone) -> CGPoint {
            switch zone {
            case .centre: return attackPoint(0.50, 0.24)
            case .leftBuildUp: return attackPoint(0.38, 0.62)
            case .rightBuildUp: return attackPoint(0.62, 0.62)
            case .leftChannel: return attackPoint(0.14, 0.16)
            case .rightChannel: return attackPoint(0.86, 0.16)
            case .leftByline: return attackPoint(0.14, 0.055)
            case .rightByline: return attackPoint(0.86, 0.055)
            case .edgeOfBox: return attackPoint(wideLeft ? 0.42 : 0.58, 0.105)
            case .penaltyArea: return attackPoint(0.50, 0.06)
            case .leftGoal: return attackPoint(0.38, 0.015)
            case .rightGoal: return attackPoint(0.62, 0.015)
            case .leftOfGoal: return attackPoint(0.28, 0.015)
            case .rightOfGoal: return attackPoint(0.72, 0.015)
            case .leftPost: return attackPoint(0.42, 0.015)
            case .rightPost: return attackPoint(0.58, 0.015)
            case .leftCorner: return attackPoint(0.02, 0.02)
            case .rightCorner: return attackPoint(0.98, 0.02)
            }
        }

        let buildupOne: CGPoint
        let buildupTwo: CGPoint
        var creatorPoint: CGPoint
        var finisherPoint: CGPoint
        switch pattern {
        case .wideCross:
            buildupOne = attackPoint(0.50, 0.42)
            buildupTwo = attackPoint(0.50, 0.28)
            creatorPoint = attackPoint(channelX, 0.16)
            finisherPoint = attackPoint(0.50, 0.06)
        case .cutback:
            buildupOne = attackPoint(wideLeft ? 0.42 : 0.58, 0.38)
            buildupTwo = attackPoint(wideLeft ? 0.28 : 0.72, 0.24)
            creatorPoint = attackPoint(channelX, 0.055)
            finisherPoint = attackPoint(wideLeft ? 0.42 : 0.58, 0.105)
        case .centralCombination:
            buildupOne = attackPoint(wideLeft ? 0.44 : 0.56, 0.40)
            buildupTwo = attackPoint(wideLeft ? 0.40 : 0.60, 0.26)
            creatorPoint = attackPoint(wideLeft ? 0.44 : 0.56, 0.17)
            finisherPoint = attackPoint(0.50, 0.065)
        case .counterAttack:
            buildupOne = attackPoint(wideLeft ? 0.38 : 0.62, 0.62)
            buildupTwo = attackPoint(wideLeft ? 0.32 : 0.68, 0.42)
            creatorPoint = attackPoint(wideLeft ? 0.34 : 0.66, 0.25)
            finisherPoint = attackPoint(0.50, 0.075)
        case .longShot:
            buildupOne = attackPoint(wideLeft ? 0.40 : 0.60, 0.42)
            buildupTwo = attackPoint(wideLeft ? 0.45 : 0.55, 0.32)
            creatorPoint = attackPoint(wideLeft ? 0.43 : 0.57, 0.25)
            finisherPoint = attackPoint(0.50, 0.205)
        }

        // The ordered commentary beats are the authoritative destinations.
        // Pattern defaults above exist only for older synthetic test events;
        // production events make the runner and receiver move to the exact
        // zones named by their text script.
        if let carryBeat = presentation?.beats.first(where: { $0.action == .carry }) {
            creatorPoint = presentationPoint(carryBeat.zone)
        }
        if let throwBeat = presentation?.beats.first(where: { $0.action == .throwIn }) {
            creatorPoint = presentationPoint(throwBeat.zone)
        }
        if let presentation,
           let receivingBeat = presentation.beats.first(where: { $0.receiverID == presentation.shooterID }) {
            finisherPoint = presentationPoint(receivingBeat.zone)
        }
        if let offsideBeat = presentation?.beats.first(where: { $0.action == .offside }) {
            finisherPoint = presentationPoint(offsideBeat.zone)
        }

        let keeperDivePoint = attackPoint(nearPostX, 0.03)
        let shotPoint = presentation?.beats.last.map { presentationPoint($0.zone) }
            ?? (scored ? attackPoint(farPostX, 0.015) : keeperDivePoint)

        let pointsFromCommentary: [BallWaypoint]? = presentation.map { script in
            script.beats.map { beat in
                let destination = presentationPoint(beat.zone)
                let followedID: String?
                switch beat.action {
                case .carry, .receive, .offside:
                    followedID = beat.actorID
                case .pass, .cross, .cutback, .throughBall, .throwIn:
                    followedID = beat.receiverID
                case .shoot, .goal, .save, .block, .miss, .woodwork,
                     .foul, .tackle, .clearance:
                    followedID = nil
                }
                if let followedID, players.contains(where: { $0.id == followedID }) {
                    return .followPlayer(id: followedID, fallback: destination)
                }
                return .fixed(destination)
            }
        }

        var points: [BallWaypoint]
        if let pointsFromCommentary, !pointsFromCommentary.isEmpty {
            // Production events are a literal rendering of the ordered text
            // beats: one ball destination per sentence/action, in the same
            // order, with no extra visual-only buildup inserted between them.
            points = pointsFromCommentary
        } else {
            // Compatibility path for older synthetic animation tests, which
            // intentionally trigger a goal/save without an engine event.
            points = [
                .fixed(buildupOne),
                .fixed(buildupTwo),
                wideRunner.map { BallWaypoint.followPlayer(id: $0.id, fallback: creatorPoint) } ?? .fixed(creatorPoint),
                finisher.map { BallWaypoint.followPlayer(id: $0.id, fallback: finisherPoint) } ?? .fixed(finisherPoint),
                .fixed(shotPoint),
            ]
        }
        let impactIndex = points.count - 1
        // Restarts are direct state placements, never ball-travel waypoints.
        // The final meaningful beat still resolves at its authoritative
        // destination; `beginDirectRestartPresentation()` then places the
        // ball and holds the short restart caption without drawing an
        // artificial path from the goal or foul location.

        waypoints = points
        waypointIndex = 0
        runTargetOverrides.removeAll()
        if let wideRunner {
            runTargetOverrides[wideRunner.id] = creatorPoint
        }
        if let finisher {
            runTargetOverrides[finisher.id] = finisherPoint
        }
        if let presentation {
            for beat in presentation.beats {
                let destination = presentationPoint(beat.zone)
                switch beat.action {
                case .carry, .receive, .offside, .clearance:
                    if let actorID = beat.actorID {
                        runTargetOverrides[actorID] = destination
                    }
                case .pass, .cross, .cutback, .throughBall, .throwIn:
                    if let receiverID = beat.receiverID {
                        runTargetOverrides[receiverID] = destination
                    }
                    if beat.action == .throwIn, let actorID = beat.actorID {
                        runTargetOverrides[actorID] = destination
                    }
                case .shoot:
                    if let actorID = beat.actorID {
                        runTargetOverrides[actorID] = destination
                    }
                case .foul, .tackle:
                    if let actorID = beat.actorID {
                        runTargetOverrides[actorID] = destination
                    }
                    if let receiverID = beat.receiverID {
                        runTargetOverrides[receiverID] = destination
                    }
                case .goal, .save, .block, .miss, .woodwork:
                    break
                }
            }
        }
        let authoritativeKeeper = presentation.flatMap { script -> PlayerSimState? in
            guard let goalkeeperID = script.goalkeeperID else { return nil }
            return defenders.first { $0.id == goalkeeperID }
        }
        let keeper = authoritativeKeeper
            ?? defenders.first(where: { $0.role == .goalkeeper })
        if let keeper, outcome == .goal || outcome == .saved {
            runTargetOverrides[keeper.id] = keeperDivePoint
        }

        defendingGoalY = forUser ? 0 : 1
        let outfieldDefenders = defenders.filter { $0.role != .goalkeeper }
        // The marker is the defending outfielder with the best defending
        // selector score (positioning/anticipation/tackling) among the
        // three closest to the wide run — closing-down duty goes to the
        // defender best equipped for it, not merely the nearest body.
        if let authoritativeMarkerID = presentation?.markerID,
           outfieldDefenders.contains(where: { $0.id == authoritativeMarkerID }) {
            markerID = authoritativeMarkerID
        } else if outfieldDefenders.count > 3 {
            let nearestThree = Array(
                outfieldDefenders
                    .sorted { distance($0.position, creatorPoint) < distance($1.position, creatorPoint) }
                    .prefix(3)
            )
            let closest = nearestThree.max { lhs, rhs in
                LegendsMatchSelectors.defending(lhs.detailed) < LegendsMatchSelectors.defending(rhs.detailed)
            }
            markerID = closest?.id
        } else {
            markerID = outfieldDefenders.min(by: { distance($0.position, creatorPoint) < distance($1.position, creatorPoint) })?.id
        }
        if let markerID {
            runTargetOverrides[markerID] = players.first(where: { $0.id == markerID })?.position
        }
        if authoritative != nil {
            updatePresentationForCurrentLeg()
        } else {
            notifyCurrentPresentationBeat()
        }
        if authoritative?.isShotEvent != false {
            pendingImpact = (
                impactIndex, outcome == .goal ? .goal : .chance,
                wideRunner?.name, finisher?.name,
                markerID.flatMap { id in players.first(where: { $0.id == id })?.name },
                authoritative?.id, wideRunner?.id, finisher?.id, markerID, keeper?.id
            )
        } else {
            pendingImpact = nil
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

    private func placeBallForDirectRestart(_ restart: LegendsMatchRestart) {
        ball.position = restartPosition(for: restart)
        lastRestart = restart
        directRestartCount += 1
    }

    private func restartTeam(_ restart: LegendsMatchRestart) -> Side {
        switch restart {
        case .kickoff(let team), .goalkeeperPossession(let team), .goalKick(let team),
             .corner(let team, _), .freeKick(let team, _), .throwIn(let team, _),
             .openPlay(let team, _):
            return team
        }
    }

    private func restartPosition(for restart: LegendsMatchRestart) -> CGPoint {
        switch restart {
        case .kickoff:
            return CGPoint(x: 0.5, y: 0.5)
        case .goalkeeperPossession(let team), .goalKick(let team):
            return CGPoint(x: 0.5, y: team == .home ? 0.94 : 0.06)
        case .corner(let team, let channel):
            return CGPoint(
                x: channel == .left ? 0.02 : 0.98,
                y: team == .home ? 0.02 : 0.98
            )
        case .freeKick(let team, let channel):
            return CGPoint(
                x: channel == .left ? 0.30 : 0.70,
                y: team == .home ? 0.30 : 0.70
            )
        case .throwIn(_, let channel):
            return CGPoint(x: channel == .left ? 0.02 : 0.98, y: 0.5)
        case .openPlay(let team, let channel):
            return CGPoint(
                x: channel == .left ? 0.30 : 0.70,
                y: team == .home ? 0.58 : 0.42
            )
        }
    }

    private func restartCommentary(for restart: LegendsMatchRestart, takerName: String? = nil) -> String {
        switch restart {
        case .kickoff:
            return "The conceding team restart from the centre spot."
        case .goalkeeperPossession:
            return "The goalkeeper gathers the ball and restarts play."
        case .goalKick:
            return "Play restarts with a goal kick."
        case .corner(_, let channel):
            let corner = channel == .left ? "left corner" : "right corner"
            return takerName.map { "\($0) will take the \(corner)." }
                ?? "The attacking side prepare to take the corner."
        case .freeKick:
            return takerName.map { "\($0) stands over the free kick." }
                ?? "Play restarts with the free kick."
        case .throwIn:
            return "Play restarts with the throw-in."
        case .openPlay:
            return "The defender wins possession and play continues."
        }
    }

    private struct PresentationTiming {
        let preparation: Double
        let ballSpeed: Double
        let controlledCarry: Bool
    }

    private func timing(for action: LegendsPresentationAction) -> PresentationTiming {
        switch action {
        case .carry:
            return PresentationTiming(preparation: 0.10, ballSpeed: 0, controlledCarry: true)
        case .receive:
            return PresentationTiming(preparation: 0.18, ballSpeed: 0, controlledCarry: true)
        case .pass:
            return PresentationTiming(preparation: 0.22, ballSpeed: 0.40, controlledCarry: false)
        case .cross:
            return PresentationTiming(preparation: 0.34, ballSpeed: 0.48, controlledCarry: false)
        case .cutback:
            return PresentationTiming(preparation: 0.24, ballSpeed: 0.36, controlledCarry: false)
        case .throughBall:
            return PresentationTiming(preparation: 0.20, ballSpeed: 0.52, controlledCarry: false)
        case .shoot:
            return PresentationTiming(preparation: 0.30, ballSpeed: 0.24, controlledCarry: false)
        case .goal, .miss, .woodwork:
            return PresentationTiming(preparation: 0, ballSpeed: 0.66, controlledCarry: false)
        case .save, .block:
            return PresentationTiming(preparation: 0, ballSpeed: 0.58, controlledCarry: false)
        case .foul, .offside, .tackle:
            return PresentationTiming(preparation: 0.28, ballSpeed: 0.24, controlledCarry: false)
        case .throwIn:
            return PresentationTiming(preparation: 0.42, ballSpeed: 0.34, controlledCarry: false)
        case .clearance:
            return PresentationTiming(preparation: 0.20, ballSpeed: 0.56, controlledCarry: false)
        }
    }

    private func possessorID(for beat: LegendsPresentationBeat) -> String? {
        switch beat.action {
        case .carry, .receive, .pass, .cross, .cutback, .throughBall, .shoot, .throwIn, .clearance:
            return beat.actorID
        case .tackle:
            return beat.actorID
        case .goal, .save, .block, .miss, .woodwork, .foul, .offside:
            return nil
        }
    }

    private func fixedDestination(for waypoint: BallWaypoint) -> CGPoint {
        switch waypoint {
        case .fixed(let point): return point
        case .followPlayer(_, let fallback): return fallback
        }
    }

    /// Emits a beat once its visual leg becomes current. The callback is
    /// idempotent at the live-engine layer, so queueing cannot duplicate
    /// commentary when a render or test tick revisits the same state.
    private func notifyCurrentPresentationBeat() {
        guard let event = activeAttack?.event,
              let script = activeAttack?.event?.presentationScript,
              script.beats.indices.contains(waypointIndex) else { return }
        let beat = script.beats[waypointIndex]
        onPresentationBeat?(event, beat, waypointIndex)
    }

    private func applyPresentationRunTarget(for beat: LegendsPresentationBeat, destination: CGPoint) {
        switch beat.action {
        case .carry, .receive, .offside, .clearance:
            if let actorID = beat.actorID {
                runTargetOverrides[actorID] = destination
            }
        case .pass, .cross, .cutback, .throughBall, .throwIn:
            if let receiverID = beat.receiverID {
                runTargetOverrides[receiverID] = destination
            }
            if beat.action == .throwIn, let actorID = beat.actorID {
                runTargetOverrides[actorID] = destination
            }
        case .shoot:
            if let actorID = beat.actorID {
                runTargetOverrides[actorID] = destination
            }
        case .foul, .tackle:
            if let actorID = beat.actorID {
                runTargetOverrides[actorID] = destination
            }
            if let receiverID = beat.receiverID {
                runTargetOverrides[receiverID] = destination
            }
        case .goal, .save, .block, .miss, .woodwork:
            break
        }
    }

    /// Moves every visible and testable timeline property together when a
    /// new action begins. The caption, possessor halo and movement therefore
    /// all read from the same beat index.
    private func updatePresentationForCurrentLeg() {
        guard let event = activeAttack?.event else { return }
        let script = event.presentationScript
        currentPresentationEventID = event.id
        currentPresentationSide = event.side
        currentLegElapsed = 0

        if waypointIndex < script.beats.count {
            let beat = script.beats[waypointIndex]
            // Keep the active participant moving toward this beat's own
            // destination. Later beats may use the same player (for example
            // a receiver taking a touch and then shooting), so assigning all
            // targets once at attack start would make an earlier controlled
            // beat wait forever for a player already steering to a later one.
            if waypoints.indices.contains(waypointIndex) {
                applyPresentationRunTarget(for: beat, destination: fixedDestination(for: waypoints[waypointIndex]))
            }
            // The goal beat is confirmed by the impact callback below. Do
            // not expose its sentence while the ball is still travelling.
            currentPresentationText = beat.action == .goal ? nil : beat.text
            currentPresentationAction = beat.action
            scriptedPossessorID = possessorID(for: beat)
            isPresentingRestart = false
            notifyCurrentPresentationBeat()
            return
        }

        guard waypointIndex < waypoints.count else { return }
        currentPresentationText = restartCommentary(for: script.restart)
        currentPresentationAction = nil
        scriptedPossessorID = nil
        isPresentingRestart = true
        runTargetOverrides.removeAll()
        markerID = nil

        if case .kickoff(let team) = script.restart {
            let centre = restartPosition(for: script.restart)
            possessionTeam = team
            if let taker = Self.closestOutfieldPlayer(in: players, team: team, to: centre) {
                scriptedPossessorID = taker.id
                runTargetOverrides[taker.id] = centre
            }
        }
    }

    /// Keeps the direct centre restart behind the existing goal card. The
    /// simulation still owns the restart transition; this flag is enabled
    /// by the live view before playback and released only when that same
    /// card finishes, so the centre spot cannot be overwritten by ambient
    /// possession while the celebration is visible.
    func holdGoalRestartUntilCardDismissal() {
        holdsGoalCardRestart = true
        // The simulation owns the waiting event; the live view keeps the
        // score/card lifecycle separate from this presentation-only hold.
    }

    /// Releases the centre-spot hold for the matching goal card. A stale or
    /// repeated dismissal is ignored, so an old overlay cannot release a
    /// newer restart or advance the ball twice.
    func completeGoalCardPresentation(for eventID: String) {
        guard waitingForGoalCardDismissalEventID == eventID else { return }
        waitingForGoalCardDismissalEventID = nil
        beginDirectRestartPresentation()
    }
    /// Synchronous single-step advance, no delay and no background `Task`
    /// — the async-free path unit tests drive instead of `start()`'s real
    /// loop, mirroring `LegendsLiveMatch.testAdvanceMinute()`.
    func testAdvance(dt: Double) {
        tick(dt: dt)
    }

    /// Test-only: whether the exact centre-spot restart is waiting for the
    /// matching goal card to dismiss. While true, the ball and kickoff taker
    /// are already at (0.5, 0.5), but the kickoff has not been released.
    func testIsWaitingForGoalCardDismissal() -> Bool {
        waitingForGoalCardDismissalEventID != nil
    }


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

    /// Test-only contract for the commentary-first renderer: production
    /// events create exactly one leg per ordered text beat. Restarts are
    /// direct state placements after the final beat, never extra travel.
    func testWaypointCount() -> Int { waypoints.count }
    func testLastRestart() -> LegendsMatchRestart? { lastRestart }
    func testDirectRestartCount() -> Int { directRestartCount }
    func testKickoffTakerID() -> String? { kickoffTakerID }

    /// Open-play test hooks. These expose identities, not mutable state,
    /// so deterministic possession behaviour can be verified without
    /// coupling tests to private implementation collections.
    func testAmbientPossessorID() -> String? { ambientPossessorID }
    func testAmbientPassTargetID() -> String? { ambientPassTargetID }
    func testAmbientPresserID() -> String? { ambientPresserID }
    func testAmbientCompletedPasses() -> Int { ambientCompletedPasses }
    func testAmbientActionEvents() -> [LegendsAmbientActionEvent] { ambientActionEvents }
    func testHasActiveAttack() -> Bool { activeAttack != nil }
    func testRunTarget(for playerID: String) -> CGPoint? { runTargetOverrides[playerID] }
    func testSupportPlayerIDs() -> [String] { supportPlayerIDs }
    func testCoverDefenderID() -> String? { coverDefenderID }
    func testMarkingAssignments() -> [String: String] { markingAssignments }
    func testBeginAmbientPossession(for team: Side) {
        beginAmbientPossession(for: team, near: CGPoint(x: 0.5, y: 0.5))
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
        if activeAttack == nil {
            advanceAmbientPlay(dt: scaledDt)
        } else {
            advanceBall(dt: scaledDt)
        }
        if let markerID, activeAttack != nil {
            let goalSideY = ball.position.y + (defendingGoalY - ball.position.y) * 0.15
            runTargetOverrides[markerID] = CGPoint(x: ball.position.x, y: goalSideY)
        }
        for index in players.indices {
            let anchor: CGPoint
            if let restartTarget = restartSetupTargets[players[index].id], isPresentingRestart {
                anchor = restartTarget
            } else if let override = runTargetOverrides[players[index].id] {
                anchor = override
            } else if let walkTarget = subWalkIns[players[index].id] {
                anchor = walkTarget
            } else if activeAttack == nil,
                      players[index].id == ambientPossessorID,
                      ambientPassTargetID == nil {
                anchor = dribbleTarget(for: players[index])
            } else if activeAttack == nil, players[index].id == ambientPresserID {
                anchor = pressingTarget(for: players[index])
            } else {
                anchor = openPlayAnchor(for: players[index])
            }
            players[index].homeAnchor = anchor
            steer(&players[index], dt: scaledDt)
        }
        // Steering happens after the action timeline is advanced. Reattach
        // the ball to the actor's freshly integrated position so controlled
        // carries and preparation frames never leave it trailing behind.
        if activeAttack != nil, !isPresentingRestart,
           let possessorID = scriptedPossessorID,
           let possessor = players.first(where: { $0.id == possessorID }) {
            ball.position = possessor.position
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
    }

    // MARK: - Continuous open play

    /// Advances ordinary possession independently of the sparse scoring
    /// events produced by `LegendsLiveMatch`. The authoritative engine still
    /// owns the result; this layer makes the time between those events read
    /// as football rather than as a decorative ball loop.
    private func advanceAmbientPlay(dt: Double) {
        guard dt > 0 else { return }
        guard let possessorIndex = players.firstIndex(where: {
            $0.id == ambientPossessorID && $0.team == possessionTeam
        }) else {
            beginAmbientPossession(for: possessionTeam, near: ball.position)
            return
        }

        let possessor = players[possessorIndex]
        ambientPresserID = bestPresser(for: possessionTeam.opposite, near: ball.position)?.id
        refreshOpenPlayAssignments(around: possessor)

        if let targetID = ambientPassTargetID,
           let target = players.first(where: { $0.id == targetID }) {
            let passing = LegendsMatchSelectors.passing(possessor.detailed)
            let passSpeed = 0.26 + Double(passing) / 500.0
            let arrived = moveBall(toward: target.position, speed: passSpeed, dt: dt)
            if arrived {
                let previousID = ambientPossessorID
                ambientPreviousPossessorID = previousID
                ambientPossessorID = target.id
                ambientPassTargetID = nil
                ambientHoldElapsed = 0

                recordAmbientAction(.receive, actor: target)
                if let turnoverTeam = pendingAmbientTurnoverTeam {
                    possessionTeam = turnoverTeam
                    pendingAmbientTurnoverTeam = nil
                    ambientSequencePasses = 0
                } else {
                    ambientCompletedPasses += 1
                    ambientSequencePasses += 1
                }
            }
            return
        }

        // During a carry the ball stays attached to the real possessor while
        // that player advances into space. This deliberately follows their
        // live position rather than their static formation coordinate.
        _ = moveBall(toward: possessor.position, speed: 0.42, dt: dt)
        ambientHoldElapsed += dt
        let tactics = tacticalProfile(for: possessor.team)
        guard ambientHoldElapsed >= tactics.holdDuration else { return }

        ambientDecisionIndex += 1
        let presser = players.first { $0.id == ambientPresserID }
        let pressureDistance = presser.map { distance($0.position, possessor.position) } ?? 1
        // A defender within roughly a player's immediate-control radius is
        // pressure; the wider threshold made compact blocks read as constant
        // pressure and pushed every decision into recycle/switch branches.
        let pressured = pressureDistance < 0.10
        let dribbling = LegendsMatchSelectors.dribbling(possessor.detailed)
        let defending = presser.map { LegendsMatchSelectors.defending($0.detailed) } ?? 50

        let action: LegendsAmbientAction
        if pressured {
            action = ambientDecisionIndex.isMultiple(of: 2) ? .recycle : .switchPlay
        } else if tactics.bias > 0.15 && !ambientDecisionIndex.isMultiple(of: 4) {
            action = dribbling > defending + 4 && ambientDecisionIndex.isMultiple(of: 3)
                ? .carry : .progressivePass
        } else if tactics.bias < -0.15 && !ambientDecisionIndex.isMultiple(of: 4) {
            action = ambientDecisionIndex.isMultiple(of: 2) ? .recycle : .switchPlay
        } else if dribbling > defending + 8 && ambientDecisionIndex.isMultiple(of: 4) {
            action = .carry
        } else if ambientDecisionIndex.isMultiple(of: 5) {
            action = .switchPlay
        } else if ambientSequencePasses > 1 && ambientDecisionIndex.isMultiple(of: 3) {
            action = .recycle
        } else {
            action = .progressivePass
        }

        if action == .carry {
            recordAmbientAction(.carry, actor: possessor)
            ambientHoldElapsed = 0
            return
        }

        if let receiver = choosePassRecipient(from: possessor, action: action) {
            if passWillBeIntercepted(from: possessor, to: receiver, presser: presser, action: action),
               let interceptor = Self.closestOutfieldPlayer(
                   in: players, team: possessionTeam.opposite, to: midpoint(possessor.position, receiver.position)
               ) {
                recordAmbientAction(.interceptedPass, actor: possessor, receiver: receiver, defender: interceptor)
                ambientPassTargetID = interceptor.id
                pendingAmbientTurnoverTeam = possessionTeam.opposite
            } else {
                recordAmbientAction(action, actor: possessor, receiver: receiver)
                ambientPassTargetID = receiver.id
            }
            ambientHoldElapsed = 0
        }
    }

    private func recordAmbientAction(_ action: LegendsAmbientAction,
                                     actor: PlayerSimState,
                                     receiver: PlayerSimState? = nil,
                                     defender: PlayerSimState? = nil) {
        testLastAmbientAction = action
        testAmbientActionHistory.append(action)
        ambientCommentarySequence += 1
        let event = LegendsAmbientActionEvent(
            sequence: ambientCommentarySequence,
            action: action,
            team: actor.team,
            actorID: actor.id,
            actorName: actor.name,
            receiverID: receiver?.id,
            receiverName: receiver?.name,
            defenderID: defender?.id,
            defenderName: defender?.name
        )
        ambientActionEvents.append(event)
        currentAmbientActionEvent = event
        currentAmbientCommentaryText = event.text
        currentAmbientCommentarySide = event.team
        onAmbientAction?(event)
        if testAmbientActionHistory.count > 100 {
            testAmbientActionHistory.removeFirst(testAmbientActionHistory.count - 100)
        }
        if ambientActionEvents.count > 100 {
            ambientActionEvents.removeFirst(ambientActionEvents.count - 100)
        }
    }

    /// Begins a restart/open-play phase with the nearest sensible outfield
    /// player. The ball travels to them on subsequent ticks; it never jumps.
    private func beginAmbientPossession(for team: Side, near point: CGPoint,
                                        preferredPlayerID: String? = nil) {
        possessionTeam = team
        ambientPreviousPossessorID = nil
        ambientPassTargetID = nil
        pendingAmbientTurnoverTeam = nil
        ambientHoldElapsed = 0
        ambientSequencePasses = 0
        if let preferredPlayerID,
           players.contains(where: { $0.id == preferredPlayerID && $0.team == team }) {
            ambientPossessorID = preferredPlayerID
        } else {
            ambientPossessorID = Self.closestOutfieldPlayer(in: players, team: team, to: point)?.id
        }
        ambientPresserID = bestPresser(for: team.opposite, near: point)?.id
        supportPlayerIDs = []
        coverDefenderID = nil
        markingAssignments = [:]
    }

    private func clearOpenPlayAssignments() {
        supportPlayerIDs = []
        coverDefenderID = nil
        markingAssignments = [:]
    }

    /// A compact visual interpretation of the existing match controls.
    /// Positive bias means front-foot football; negative bias means risk
    /// reduction and a deeper, more compact block. The away side stays
    /// balanced until opponent tactical choices become an authoritative
    /// engine concept.
    private struct TacticalProfile {
        let bias: Double
        let holdDuration: Double
    }

    private func tacticalProfile(for team: Side) -> TacticalProfile {
        guard team == .home else {
            return TacticalProfile(bias: 0, holdDuration: ambientHoldDuration)
        }
        let rawBias = (userMentality.attack * userInstruction.attack)
            - (userMentality.solidity * userInstruction.solidity)
        let bias = min(0.42, max(-0.42, rawBias * 0.48))
        let timeWasteDelay = userInstruction == .timeWaste ? 1.35 : 1.0
        return TacticalProfile(
            bias: bias,
            holdDuration: ambientHoldDuration * timeWasteDelay * (1 - bias * 0.18)
        )
    }

    /// Builds coordinated responsibilities around the player in possession.
    /// The nearest useful teammates become a short outlet and a forward
    /// option instead of every attacker remaining glued to a formation dot.
    /// Defenders retain a compact block: one presses, one covers the space
    /// behind them, and two others track the most advanced available threats.
    private func refreshOpenPlayAssignments(around possessor: PlayerSimState) {
        let attackDirection = possessor.team == .home ? -1.0 : 1.0
        let tactics = tacticalProfile(for: possessor.team)
        let teammates = players.filter {
            $0.team == possessor.team && $0.id != possessor.id && $0.role != .goalkeeper
        }

        func supportScore(_ player: PlayerSimState, forward: Bool) -> Double {
            let separation = distance(player.position, possessor.position)
            let ideal = 1 - min(1, abs(separation - 0.20) / 0.20)
            let progress = (player.position.y - possessor.position.y) * attackDirection
            let vertical = forward
                ? progress * (1.4 + tactics.bias * 0.8)
                : -abs(progress + 0.04)
            let control = Double(LegendsMatchSelectors.firstTouch(player.detailed)) / 99
            return ideal * 1.8 + vertical * 1.4 + control * 0.2
        }

        let shortOutlet = teammates.sorted {
            let lhs = supportScore($0, forward: false)
            let rhs = supportScore($1, forward: false)
            if abs(lhs - rhs) > 0.0001 { return lhs > rhs }
            return $0.id < $1.id
        }.first
        let forwardOutlet = teammates.filter { $0.id != shortOutlet?.id }.sorted {
            let lhs = supportScore($0, forward: true)
            let rhs = supportScore($1, forward: true)
            if abs(lhs - rhs) > 0.0001 { return lhs > rhs }
            return $0.id < $1.id
        }.first
        supportPlayerIDs = [shortOutlet?.id, forwardOutlet?.id].compactMap { $0 }

        let defendingTeam = possessor.team.opposite
        let availableDefenders = players.filter {
            $0.team == defendingTeam
                && $0.role != .goalkeeper
                && $0.id != ambientPresserID
        }
        coverDefenderID = availableDefenders.sorted {
            let lhs = distance($0.position, ball.position)
            let rhs = distance($1.position, ball.position)
            if abs(lhs - rhs) > 0.0001 { return lhs < rhs }
            let lhsDefending = LegendsMatchSelectors.defending($0.detailed)
            let rhsDefending = LegendsMatchSelectors.defending($1.detailed)
            if lhsDefending != rhsDefending { return lhsDefending > rhsDefending }
            return $0.id < $1.id
        }.first?.id

        let threats = teammates
            .filter { !supportPlayerIDs.contains($0.id) }
            .sorted {
                let ownGoalY = defendingTeam == .home ? 1.0 : 0.0
                let lhs = abs($0.position.y - ownGoalY)
                let rhs = abs($1.position.y - ownGoalY)
                if abs(lhs - rhs) > 0.0001 { return lhs < rhs }
                return $0.id < $1.id
            }
            .prefix(2)

        var unassigned = availableDefenders.filter { $0.id != coverDefenderID }
        var assignments: [String: String] = [:]
        for threat in threats {
            guard let marker = unassigned.min(by: {
                let lhs = distance($0.position, threat.position)
                let rhs = distance($1.position, threat.position)
                if abs(lhs - rhs) > 0.0001 { return lhs < rhs }
                return $0.id < $1.id
            }) else { break }
            assignments[marker.id] = threat.id
            unassigned.removeAll { $0.id == marker.id }
        }
        markingAssignments = assignments
    }

    private static func closestOutfieldPlayer(
        in players: [PlayerSimState], team: Side, to point: CGPoint
    ) -> PlayerSimState? {
        players
            .filter { $0.team == team && $0.role != .goalkeeper }
            .min { lhs, rhs in
                let lhsDistance = hypot(lhs.position.x - point.x, lhs.position.y - point.y)
                let rhsDistance = hypot(rhs.position.x - point.x, rhs.position.y - point.y)
                if abs(lhsDistance - rhsDistance) > 0.0001 { return lhsDistance < rhsDistance }
                return lhs.id < rhs.id
            }
    }

    /// Pick among the three closest defenders using the Point 2 defending
    /// selector, so anticipation/positioning influence who steps out rather
    /// than every player swarming the ball.
    private func bestPresser(for team: Side, near point: CGPoint) -> PlayerSimState? {
        let nearest = players
            .filter { $0.team == team && $0.role != .goalkeeper }
            .sorted {
                let lhs = distance($0.position, point)
                let rhs = distance($1.position, point)
                if abs(lhs - rhs) > 0.0001 { return lhs < rhs }
                return $0.id < $1.id
            }
            .prefix(3)

        return nearest.sorted {
            let lhs = LegendsMatchSelectors.defending($0.detailed)
            let rhs = LegendsMatchSelectors.defending($1.detailed)
            if lhs != rhs { return lhs > rhs }
            return $0.id < $1.id
        }.first
    }

    /// Selects a teammate for the chosen football action. Progressive passes
    /// seek useful vertical gain, recycling offers a safe backward angle and
    /// switches favour the opposite side of the pitch.
    private func choosePassRecipient(
        from possessor: PlayerSimState,
        action: LegendsAmbientAction
    ) -> PlayerSimState? {
        var candidates = players.filter {
            $0.team == possessor.team && $0.id != possessor.id && $0.role != .goalkeeper
        }
        if candidates.count > 1, let previousID = ambientPreviousPossessorID {
            candidates.removeAll { $0.id == previousID }
        }
        let attackDirection = possessor.team == .home ? -1.0 : 1.0

        func score(_ candidate: PlayerSimState) -> Double {
            let separation = distance(possessor.position, candidate.position)
            let forwardProgress = (candidate.position.y - possessor.position.y) * attackDirection
            let idealDistance = 1.0 - min(1.0, abs(separation - 0.24) / 0.24)
            let control = Double(LegendsMatchSelectors.firstTouch(candidate.detailed)) / 99.0
            let directionScore: Double
            switch action {
            case .progressivePass:
                directionScore = forwardProgress * 1.7
            case .recycle:
                directionScore = -forwardProgress * 1.45
            case .switchPlay:
                directionScore = abs(candidate.position.x - possessor.position.x) * 1.8
            case .carry, .interceptedPass, .receive:
                directionScore = forwardProgress
            }
            let supportBonus = supportPlayerIDs.contains(candidate.id) ? 0.32 : 0
            return idealDistance * 1.6 + directionScore + control * 0.25 + supportBonus
        }

        return candidates.sorted {
            let lhs = score($0)
            let rhs = score($1)
            if abs(lhs - rhs) > 0.0001 { return lhs > rhs }
            return $0.id < $1.id
        }.first
    }

    /// Deterministic pass-risk model. Distance, pressure and the nearest
    /// defender raise risk; passing and first touch lower it. A stable action
    /// index replaces random rolls so identical simulations remain identical.
    private func stableValue(_ value: String) -> Int {
        value.utf8.reduce(17) { partial, byte in
            (partial &* 31 &+ Int(byte)) % 10_000
        }
    }

    private func passWillBeIntercepted(
        from passer: PlayerSimState,
        to receiver: PlayerSimState,
        presser: PlayerSimState?,
        action: LegendsAmbientAction
    ) -> Bool {
        let passDistance = distance(passer.position, receiver.position)
        let lanePoint = midpoint(passer.position, receiver.position)
        let laneDefender = players
            .filter { $0.team != passer.team && $0.role != .goalkeeper }
            .min {
                let lhs = distance($0.position, lanePoint)
                let rhs = distance($1.position, lanePoint)
                if abs(lhs - rhs) > 0.0001 { return lhs < rhs }
                return $0.id < $1.id
            }
        let passing = LegendsMatchSelectors.passing(passer.detailed)
        let touch = LegendsMatchSelectors.firstTouch(receiver.detailed)
        let defending = laneDefender.map { LegendsMatchSelectors.defending($0.detailed) }
            ?? presser.map { LegendsMatchSelectors.defending($0.detailed) }
            ?? 50
        let pressure = presser.map {
            max(0, 0.20 - distance($0.position, passer.position)) * 180
        } ?? 0
        let lanePressure = laneDefender.map {
            max(0, 0.18 - distance($0.position, lanePoint)) * 170
        } ?? 0
        // Pass type is part of the football decision: recycling is the
        // safest outlet, progressive play accepts moderate risk for territory,
        // and a switch exposes a longer diagonal lane. Each adjustment is
        // bounded so attributes and spacing still matter more than a fixed
        // turnover rule.
        let actionAdjustment: Double
        switch action {
        case .recycle: actionAdjustment = -8
        case .progressivePass: actionAdjustment = 0
        case .switchPlay: actionAdjustment = 5
        case .carry, .interceptedPass, .receive: actionAdjustment = 0
        }
        let risk = max(4.0, min(44.0,
            6 + passDistance * 38 + pressure * 0.55 + lanePressure * 0.60
                + Double(defending - passing) * 0.16 - Double(touch - 50) * 0.08
                + actionAdjustment
        ))
        // Stable player identity prevents different pairs with equal-length
        // IDs from collapsing into the same repetitive turnover pattern.
        let identityRoll = stableValue("\(passer.id)|\(receiver.id)")
        let stableRoll = (ambientDecisionIndex * 37 + ambientSequencePasses * 17 + identityRoll) % 100
        return Double(stableRoll) < risk
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func moveBall(toward target: CGPoint, speed: Double, dt: Double) -> Bool {
        let dx = target.x - ball.position.x
        let dy = target.y - ball.position.y
        let remaining = hypot(dx, dy)
        let step = speed * dt
        guard remaining > step, remaining > 0.0001 else {
            ball.position = target
            return true
        }
        ball.position.x += dx / remaining * step
        ball.position.y += dy / remaining * step
        return false
    }

    private func dribbleTarget(for player: PlayerSimState) -> CGPoint {
        let direction = player.team == .home ? -1.0 : 1.0
        let isWide = [.leftBack, .rightBack, .leftMid, .rightMid, .leftWing, .rightWing].contains(player.role)
        // Wide players carry into the channel instead of being pulled toward
        // the centre every time they receive the ball. Central players still
        // make a modest inside movement to create a passing angle.
        let lateralMovement: Double
        if isWide {
            lateralMovement = player.baseAnchor.x < 0.5 ? -0.012 : 0.012
        } else {
            lateralMovement = (0.5 - player.position.x) * 0.08
        }
        return clampedToPitch(CGPoint(
            x: player.position.x + lateralMovement,
            y: player.position.y + direction * 0.055
        ))
    }

    private func pressingTarget(for player: PlayerSimState) -> CGPoint {
        let ownGoalY = player.team == .home ? 1.0 : 0.0
        let tactics = tacticalProfile(for: player.team)
        let goalSideDepth = 0.10 - tactics.bias * 0.10
        return clampedToPitch(CGPoint(
            x: ball.position.x,
            y: ball.position.y + (ownGoalY - ball.position.y) * goalSideDepth
        ))
    }

    private func supportTarget(for player: PlayerSimState, index: Int) -> CGPoint {
        guard let possessor = players.first(where: { $0.id == ambientPossessorID }) else {
            return player.baseAnchor
        }
        let direction = player.team == .home ? -1.0 : 1.0
        let tactics = tacticalProfile(for: player.team)
        let side: Double
        if index == 0 {
            let distance = 0.13 + tactics.bias * 0.035
            side = possessor.position.x <= 0.5 ? distance : -distance
        } else {
            let distance = 0.11 + tactics.bias * 0.025
            side = possessor.position.x <= 0.5 ? -distance : distance
        }
        let vertical = index == 0
            ? -direction * (0.075 - tactics.bias * 0.025)
            : direction * (0.12 + tactics.bias * 0.09)
        return clampedToPitch(CGPoint(
            x: possessor.position.x + side,
            y: possessor.position.y + vertical
        ))
    }

    private func coverTarget(for player: PlayerSimState) -> CGPoint {
        let ownGoalY = player.team == .home ? 1.0 : 0.0
        let tactics = tacticalProfile(for: player.team)
        let coverDepth = 0.18 - tactics.bias * 0.09
        return clampedToPitch(CGPoint(
            x: ball.position.x * 0.72 + player.baseAnchor.x * 0.28,
            y: ball.position.y + (ownGoalY - ball.position.y) * coverDepth
        ))
    }

    private func markingTarget(for player: PlayerSimState, threatID: String) -> CGPoint {
        guard let threat = players.first(where: { $0.id == threatID }) else {
            return player.baseAnchor
        }
        let ownGoalY = player.team == .home ? 1.0 : 0.0
        return clampedToPitch(CGPoint(
            x: threat.position.x * 0.78 + player.baseAnchor.x * 0.22,
            y: threat.position.y + (ownGoalY - threat.position.y) * 0.07
        ))
    }

    private func defensiveBlockAnchor(for player: PlayerSimState) -> CGPoint {
        let tactics = tacticalProfile(for: player.team)
        if player.role == .goalkeeper {
            let ownGoalY = player.team == .home ? 1.0 : 0.0
            let sweep = 0.08 + tactics.bias * 0.09
            return clampedToPitch(CGPoint(
                x: 0.5 + (ball.position.x - 0.5) * 0.18,
                y: ownGoalY + (ball.position.y - ownGoalY) * sweep
            ))
        }

        let ownGoalY = player.team == .home ? 1.0 : 0.0
        let shiftedY = player.baseAnchor.y + (ball.position.y - 0.5) * depthPull * 0.72
        let goalSideOffset: Double
        switch player.role.broad {
        case .goalkeeper: goalSideOffset = 0
        case .defender: goalSideOffset = 0.11
        case .midfielder: goalSideOffset = 0.055
        case .forward: goalSideOffset = 0
        }
        let goalSideY = ball.position.y + (ownGoalY - ball.position.y) * goalSideOffset
        let ballInDefensiveHalf = player.team == .home ? ball.position.y > 0.5 : ball.position.y < 0.5
        var y: Double
        if ballInDefensiveHalf && player.role.broad != .forward {
            y = player.team == .home ? max(shiftedY, goalSideY) : min(shiftedY, goalSideY)
        } else {
            y = shiftedY
        }
        let attackDirection = player.team == .home ? -1.0 : 1.0
        y += attackDirection * tactics.bias * 0.12
        let compactness = 1.35 - tactics.bias * 0.42
        return clampedToPitch(CGPoint(
            x: player.baseAnchor.x + (ball.position.x - player.baseAnchor.x) * sidewaysPull * compactness,
            y: y
        ))
    }

    /// Attacking players form passing triangles around the possessor while
    /// retaining formation width. The defending team moves as a compact
    /// block with explicit pressing, cover and goal-side marking duties.
    /// Goalkeepers sweep only a few yards and remain tied to their own goal.
    private func openPlayAnchor(for player: PlayerSimState) -> CGPoint {
        let attacking = player.team == possessionTeam
        if !attacking {
            if player.id == coverDefenderID {
                return coverTarget(for: player)
            }
            if let threatID = markingAssignments[player.id] {
                return markingTarget(for: player, threatID: threatID)
            }
            return defensiveBlockAnchor(for: player)
        }

        if let supportIndex = supportPlayerIDs.firstIndex(of: player.id) {
            return supportTarget(for: player, index: supportIndex)
        }
        if player.role == .goalkeeper {
            let ownGoalY = player.team == .home ? 1.0 : 0.0
            let tactics = tacticalProfile(for: player.team)
            let sweep = 0.12 + tactics.bias * 0.10
            return clampedToPitch(CGPoint(
                x: 0.5 + (ball.position.x - 0.5) * 0.14,
                y: ownGoalY + (ball.position.y - ownGoalY) * sweep
            ))
        }

        let xPull = sidewaysPull * 0.62
        let yPull = depthPull * 1.05
        let tactics = tacticalProfile(for: player.team)
        let direction = player.team == .home ? -1.0 : 1.0
        let roleAdvance: Double
        switch player.role.broad {
        case .goalkeeper: roleAdvance = 0
        case .defender: roleAdvance = attacking ? 0.012 : 0
        case .midfielder: roleAdvance = attacking ? 0.032 : 0
        case .forward: roleAdvance = attacking ? 0.05 : 0
        }
        let wideRole = [.leftBack, .rightBack, .leftMid, .rightMid, .leftWing, .rightWing].contains(player.role)
        let widthAmount = 0.025 + tactics.bias * 0.045
        let width = wideRole ? (player.baseAnchor.x < 0.5 ? -widthAmount : widthAmount) : 0

        return clampedToPitch(CGPoint(
            x: player.baseAnchor.x + (ball.position.x - player.baseAnchor.x) * xPull + width,
            y: player.baseAnchor.y + (ball.position.y - 0.5) * yPull + direction * roleAdvance
        ))
    }

    /// The pitch position a released ball is currently aiming for. Receiver
    /// legs follow that player's live position; outcome and restart legs use
    /// fixed authoritative zones.
    private func resolvedPosition(for waypoint: BallWaypoint) -> CGPoint {
        switch waypoint {
        case .fixed(let point):
            return point
        case .followPlayer(let id, let fallback):
            return players.first(where: { $0.id == id })?.position ?? fallback
        }
    }

    private func advanceBall(dt: Double) {
        guard dt > 0 else { return }
        // A goal has reached the net, but its card is still on screen. Keep
        // the ball and the preceding shot state untouched until the view
        // acknowledges dismissal of that exact card.
        guard waitingForGoalCardDismissalEventID == nil else { return }
        if restartPendingAfterImpact {
            restartPendingAfterImpact = false
            beginDirectRestartPresentation()
            return
        }
        if isPresentingRestart {
            restartPresentationElapsed += dt
            guard restartPresentationElapsed >= restartPresentationDuration else { return }
            finishActiveAttackAfterRestart()
            return
        }
        guard waypointIndex < waypoints.count else { return }
        let waypoint = waypoints[waypointIndex]
        let script = activeAttack?.event?.presentationScript
        let beat = script.flatMap { $0.beats.indices.contains(waypointIndex) ? $0.beats[waypointIndex] : nil }
        currentLegElapsed += dt

        var target = resolvedPosition(for: waypoint)
        var speed = ballSpeed

        if let beat {
            let actionTiming = timing(for: beat.action)
            if currentLegElapsed < actionTiming.preparation {
                if let actorID = possessorID(for: beat),
                   let actor = players.first(where: { $0.id == actorID }) {
                    scriptedPossessorID = actorID
                    ball.position = actor.position
                }
                return
            }

            if actionTiming.controlledCarry,
               let actorID = beat.actorID,
               let actor = players.first(where: { $0.id == actorID }) {
                scriptedPossessorID = actorID
                ball.position = actor.position
                target = fixedDestination(for: waypoint)
                if distance(actor.position, target) > 0.025 { return }
            } else {
                // The preparation/first-touch phase has ended: the ball is
                // now visibly in flight until this action reaches its target.
                scriptedPossessorID = nil
                speed = actionTiming.ballSpeed
            }
        } else if isPresentingRestart {
            speed = 0.34
        }

        let dx = target.x - ball.position.x
        let dy = target.y - ball.position.y
        let remaining = (dx * dx + dy * dy).squareRoot()
        let step = speed * dt
        guard remaining <= step else {
            ball.position.x += dx / remaining * step
            ball.position.y += dy / remaining * step
            return
        }

        ball.position = target
        if let pending = pendingImpact, pending.index == waypointIndex {
            lastImpact = BallImpact(
                position: target,
                kind: pending.kind,
                time: Date(),
                runnerName: pending.runnerName,
                finisherName: pending.finisherName,
                markerName: pending.markerName,
                eventID: pending.eventID,
                runnerID: pending.runnerID,
                finisherID: pending.finisherID,
                markerID: pending.markerID,
                goalkeeperID: pending.goalkeeperID
            )
            if pending.kind == .chance,
               let goalkeeperID = pending.goalkeeperID,
               let goalkeeperIndex = players.firstIndex(where: { $0.id == goalkeeperID }) {
                // A saved chance is one shared visual outcome: at the
                // impact tick the keeper has reached the same point as the
                // shot. This is a finish of the keeper's dive, not a second
                // outcome roll or a decorative reaction after the ball has
                // already gone elsewhere.
                players[goalkeeperIndex].position = target
                players[goalkeeperIndex].homeAnchor = target
                players[goalkeeperIndex].velocity = .zero
            }
            if pending.kind == .goal, let event = activeAttack?.event {
                // The ball is now on the goal line. Only at this point may
                // the live engine publish the goal line, score and card.
                onGoalPresented?(event)
            }
            pendingImpact = nil
        }
        if let action = beat?.action {
            completedPresentationActions.append(action)
        }
        waypointIndex += 1

        let reachedFinalWaypoint = waypointIndex >= waypoints.count
        if !reachedFinalWaypoint {
            updatePresentationForCurrentLeg()
            return
        }

        // A goal card is a real presentation phase. Do not install the
        // centre-spot restart until that card has dismissed; this prevents
        // the card/celebration from hiding a reset that happened too early.
        if let event = activeAttack?.event, event.scored, holdsGoalCardRestart {
            waitingForGoalCardDismissalEventID = event.id
            currentPresentationText = nil
            currentPresentationAction = nil
            currentLegElapsed = 0
            return
        }

        // Non-goal outcomes and headless/test attacks enter their direct
        // restart on the next simulation tick. That one-tick handoff keeps
        // the final impact visible with the keeper/defender at the same
        // point before the restart setup repositions the teams.
        if activeAttack != nil {
            restartPendingAfterImpact = true
            return
        }

        waypoints.removeAll()
        waypointIndex = 0
        runTargetOverrides.removeAll()
        markerID = nil
        currentPresentationAction = nil
        scriptedPossessorID = nil
        currentLegElapsed = 0
        beginAmbientPossession(for: possessionTeam, near: ball.position)
    }

    private func beginDirectRestartPresentation() {
        guard let currentAttack = activeAttack else { return }
        let restart: LegendsMatchRestart
        let restartTakerID: String?
        let restartTakerName: String?
        if let authoritativeEvent = currentAttack.event {
            restart = authoritativeEvent.presentationScript.restart
            restartTakerID = authoritativeEvent.presentationScript.restartTakerID
            restartTakerName = authoritativeEvent.presentationScript.restartTakerName
        } else {
            let team: Side = currentAttack.forUser ? .away : .home
            restart = currentAttack.scored ? .kickoff(team: team) : .openPlay(team: team, channel: .left)
            restartTakerID = nil
            restartTakerName = nil
        }

        placeBallForDirectRestart(restart)
        let restartTeam = restartTeam(restart)
        possessionTeam = restartTeam
        restartSetupTargets = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.baseAnchor) })
        runTargetOverrides.removeAll()
        markerID = nil
        kickoffTakerID = nil
        kickoffTakerPosition = nil

        if case .kickoff = restart {
            let centre = restartPosition(for: restart)
            let taker = players
                .filter { $0.team == restartTeam && $0.role != .goalkeeper }
                .min {
                    let lhsCentrality = abs($0.position.x - centre.x) + abs($0.position.y - centre.y)
                    let rhsCentrality = abs($1.position.x - centre.x) + abs($1.position.y - centre.y)
                    if abs(lhsCentrality - rhsCentrality) > 0.0001 { return lhsCentrality < rhsCentrality }
                    return $0.id < $1.id
                }
            if let taker {
                kickoffTakerID = taker.id
                kickoffTakerPosition = centre
                restartSetupTargets[taker.id] = centre
                if let index = players.firstIndex(where: { $0.id == taker.id }) {
                    players[index].position = centre
                    players[index].homeAnchor = centre
                    players[index].velocity = .zero
                }
                scriptedPossessorID = taker.id
            }
        } else if let restartTakerID,
                  let takerIndex = players.firstIndex(where: { $0.id == restartTakerID && $0.team == restartTeam }) {
            let restartPoint = restartPosition(for: restart)
            restartSetupTargets[restartTakerID] = restartPoint
            players[takerIndex].position = restartPoint
            players[takerIndex].homeAnchor = restartPoint
            players[takerIndex].velocity = .zero
            scriptedPossessorID = restartTakerID
        }

        for index in players.indices {
            guard players[index].id != kickoffTakerID,
                  players[index].id != restartTakerID,
                  let target = restartSetupTargets[players[index].id] else { continue }
            players[index].position = target
            players[index].homeAnchor = target
            players[index].velocity = .zero
        }

        // The exact centre placement is installed only after a goal card has
        // dismissed. `waitingForGoalCardDismissalEventID` owns that hold, so
        // this method never moves a goal ball while the scorer card is live.
        restartPendingAfterImpact = false
        restartPresentationElapsed = 0
        isPresentingRestart = true
        currentPresentationSide = restartTeam
        currentPresentationText = restartCommentary(for: restart, takerName: restartTakerName)
        currentPresentationAction = nil
        onRestartPresentation?(restart, restartTakerName)
    }

    private func finishActiveAttackAfterRestart() {
        guard let currentAttack = activeAttack else {
            isPresentingRestart = false
            return
        }
        activeAttack = nil
        var preferredRestartPlayerID: String? = kickoffTakerID
        restartSetupTargets.removeAll()
        if let event = currentAttack.event {
            let presentation = event.presentationScript
            switch presentation.restart {
            case .kickoff(let team):
                possessionTeam = team
            case .goalkeeperPossession(let team), .goalKick(let team):
                possessionTeam = team
                preferredRestartPlayerID = presentation.goalkeeperID
            case .corner(let team, _):
                possessionTeam = team
                preferredRestartPlayerID = presentation.restartTakerID ?? presentation.creatorID
            case .freeKick(let team, _):
                possessionTeam = team
                preferredRestartPlayerID = presentation.restartTakerID
                    ?? (team == event.side ? presentation.shooterID : presentation.markerID)
            case .throwIn(let team, _):
                possessionTeam = team
                preferredRestartPlayerID = presentation.creatorID
            case .openPlay(let team, _):
                possessionTeam = team
                preferredRestartPlayerID = presentation.markerID
            }
        }
        if let eventID = currentAttack.event?.id {
            onEventPresentationCompleted?(eventID)
        }
        isPresentingRestart = false
        restartPresentationElapsed = 0
        kickoffTakerID = nil
        kickoffTakerPosition = nil
        if !attackQueue.isEmpty {
            let next = attackQueue.removeFirst()
            startAttack(next)
            return
        }
        waypoints.removeAll()
        waypointIndex = 0
        runTargetOverrides.removeAll()
        markerID = nil
        beginAmbientPossession(for: possessionTeam, near: ball.position,
                               preferredPlayerID: preferredRestartPlayerID)
        currentPresentationText = nil
        currentPresentationSide = nil
        currentPresentationEventID = nil
        currentPresentationAction = nil
        scriptedPossessorID = nil
        currentLegElapsed = 0
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
