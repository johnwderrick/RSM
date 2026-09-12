//
//  LegendsLiveMatch.swift
//  Retro Season Manager
//
//  A minute-by-minute live match engine for RSM Legends, mirroring
//  Career Mode's LiveMatch.swift structurally (tick loop, pause/speed,
//  mentality/instruction, substitutions, commentary, momentum) but
//  scaled to what Legends actually has: one aggregate card per Starting
//  XI slot instead of full Player objects, and no cards/injuries/weather
//  (Legends has no underlying data for those yet).
//
//  Goal resolution is two-stage, not a single coin flip. Each minute
//  rolls two independent Bernoulli trials — one per side — using
//  `p = chanceRatePerGame * ratio / 90` to decide whether that side
//  creates a genuine attacking chance this minute (unchanged in shape
//  from the engine's original single-roll design, so mid-match
//  mentality/instruction changes still genuinely shift the odds for
//  every remaining minute rather than only cosmetically animating a
//  pre-computed result). A fired chance is then *resolved* for real
//  against the opposing side's actual players — a weighted-random
//  attacker (by shooting/dribbling/pace/overall) against a weighted-
//  random defender plus the defending side's goalkeeper (by
//  defending/physical/overall) — via `resolveChance`/
//  `conversionProbability`, using a deterministic synthetic opponent
//  roster (`LegendsOpponentRoster`, full attributes). The two stages
//  together still land near the same "~2.7 goals per game" baseline
//  `LegendsMatchEngine.simulate(...)` targets, but the outcome is now
//  attribute-grounded instead of an abstract single-roll coin flip, and
//  the scorer is simply whoever took the shot — no second, unrelated
//  dice roll after the goal is already decided.
//

import Foundation
import Observation

/// A saved set-piece role that can be resolved against the players who are
/// actually available during a live match. The role assignment is a request;
/// the taker ID/name captured on the event is the authoritative result.
enum LegendsSetPiece: Equatable {
    case penalty
    case directFreeKick
    case leftCorner
    case rightCorner

    var squadRole: LegendsSquadRole {
        switch self {
        case .penalty: return .penalties
        case .directFreeKick: return .freeKicks
        case .leftCorner: return .leftCorner
        case .rightCorner: return .rightCorner
        }
    }

    var usesRestartTaker: Bool {
        switch self {
        case .penalty: return false
        case .directFreeKick, .leftCorner, .rightCorner: return true
        }
    }
}

struct LegendsSetPieceTaker: Equatable {
    let id: String
    let name: String
}

/// One authoritative attacking event produced by the match engine. Score,
/// commentary, career statistics and the 2D renderer all consume this exact
/// record; none of those layers is allowed to select participants again.
struct LegendsMatchEvent: Identifiable, Equatable {
    enum Outcome: Equatable {
        case goal
        case saved
        case blocked
        case missed
        case woodwork
        case foul
        case offside
        case throwIn
        case tackled
        case cleared
    }
    enum Channel: Equatable { case left, right }
    enum AttackPattern: String, CaseIterable, Equatable {
        case wideCross
        case cutback
        case centralCombination
        case counterAttack
        case longShot
    }

    let id: String
    let minute: Int
    let side: Side
    let outcome: Outcome
    let channel: Channel
    let attackPattern: AttackPattern
    let creatorID: String?
    let creatorName: String?
    let shooterID: String
    let shooterName: String
    let markerID: String?
    let markerName: String?
    let goalkeeperID: String?
    let goalkeeperName: String?
    let expectedGoals: Double
    /// The set piece, when this event awards or takes one. This is captured
    /// by the live engine so commentary and the pitch never select a second
    /// taker after the event has been created.
    let setPiece: LegendsSetPiece?
    let setPieceTakerID: String?
    let setPieceTakerName: String?

    /// Stable per-event phrase selector. It is derived from the event ID,
    /// never from process-randomized hashing or a UI animation, so replaying
    /// the same seeded match keeps commentary and the visible action aligned.
    var commentaryVariant: Int {
        id.utf8.reduce(0) { partial, byte in
            (partial &* 31 &+ Int(byte)) % 3
        }
    }

    init(
        id: String, minute: Int, side: Side, outcome: Outcome, channel: Channel,
        attackPattern: AttackPattern = .wideCross,
        creatorID: String?, creatorName: String?, shooterID: String, shooterName: String,
        markerID: String?, markerName: String?, goalkeeperID: String?, goalkeeperName: String?,
        expectedGoals: Double,
        setPiece: LegendsSetPiece? = nil,
        setPieceTakerID: String? = nil,
        setPieceTakerName: String? = nil
    ) {
        self.id = id
        self.minute = minute
        self.side = side
        self.outcome = outcome
        self.channel = channel
        self.attackPattern = attackPattern
        self.creatorID = creatorID
        self.creatorName = creatorName
        let resolvedShooterID = setPiece == .penalty ? (setPieceTakerID ?? shooterID) : shooterID
        let resolvedShooterName = setPiece == .penalty ? (setPieceTakerName ?? shooterName) : shooterName
        self.shooterID = resolvedShooterID
        self.shooterName = resolvedShooterName
        self.markerID = markerID
        self.markerName = markerName
        self.goalkeeperID = goalkeeperID
        self.goalkeeperName = goalkeeperName
        self.expectedGoals = expectedGoals
        self.setPiece = setPiece
        self.setPieceTakerID = setPieceTakerID ?? (setPiece == .penalty ? resolvedShooterID : nil)
        self.setPieceTakerName = setPieceTakerName ?? (setPiece == .penalty ? resolvedShooterName : nil)
    }

    var scored: Bool { outcome == .goal }
    var isUserEvent: Bool { side == .home }
    var isShotEvent: Bool {
        switch outcome {
        case .goal, .saved, .blocked, .missed, .woodwork: return true
        case .foul, .offside, .throwIn, .tackled, .cleared: return false
        }
    }
    var presentationScript: LegendsMatchPresentationScript {
        LegendsMatchPresentationScript(event: self)
    }
}

enum LegendsPresentationAction: Equatable {
    case carry
    case receive
    case pass
    case cross
    case cutback
    case throughBall
    case shoot
    case goal
    case save
    case block
    case miss
    case woodwork
    case foul
    case offside
    case throwIn
    case tackle
    case clearance
}

enum LegendsPresentationZone: Equatable {
    case centre
    case leftBuildUp
    case rightBuildUp
    case leftChannel
    case rightChannel
    case leftByline
    case rightByline
    case edgeOfBox
    case penaltyArea
    case leftGoal
    case rightGoal
    case leftOfGoal
    case rightOfGoal
    case leftPost
    case rightPost
    case leftCorner
    case rightCorner
}

struct LegendsPresentationBeat: Equatable {
    let action: LegendsPresentationAction
    let actorID: String?
    let actorName: String
    let receiverID: String?
    let receiverName: String?
    let zone: LegendsPresentationZone
    let text: String
}

enum LegendsMatchRestart: Equatable {
    case kickoff(team: Side)
    case goalkeeperPossession(team: Side)
    case goalKick(team: Side)
    case corner(team: Side, channel: LegendsMatchEvent.Channel)
    case freeKick(team: Side, channel: LegendsMatchEvent.Channel)
    case throwIn(team: Side, channel: LegendsMatchEvent.Channel)
    case openPlay(team: Side, channel: LegendsMatchEvent.Channel)
}

/// One immutable description of what happened in an authoritative chance.
/// Both the text commentary and the 2D pitch consume this object, so names,
/// actions, flank, outcome and participants cannot drift apart.
struct LegendsMatchPresentationScript: Equatable {
    let eventID: String
    let side: Side
    let outcome: LegendsMatchEvent.Outcome
    let channel: LegendsMatchEvent.Channel
    let attackPattern: LegendsMatchEvent.AttackPattern
    let creatorID: String?
    let shooterID: String
    let markerID: String?
    let goalkeeperID: String?
    let setPiece: LegendsSetPiece?
    let setPieceTakerID: String?
    let setPieceTakerName: String?
    /// The taker is used when the final beat transitions into a direct
    /// free-kick or corner restart. Penalties are resolved as shot events,
    /// so their taker remains on the shooter beat instead.
    let restartTakerID: String?
    let restartTakerName: String?
    let beats: [LegendsPresentationBeat]
    let restart: LegendsMatchRestart

    init(event: LegendsMatchEvent) {
        eventID = event.id
        side = event.side
        outcome = event.outcome
        channel = event.channel
        attackPattern = event.attackPattern
        creatorID = event.creatorID
        shooterID = event.shooterID
        markerID = event.markerID
        goalkeeperID = event.goalkeeperID
        setPiece = event.setPiece
        setPieceTakerID = event.setPieceTakerID
        setPieceTakerName = event.setPieceTakerName
        restartTakerID = event.setPiece?.usesRestartTaker == true ? event.setPieceTakerID : nil
        restartTakerName = event.setPiece?.usesRestartTaker == true ? event.setPieceTakerName : nil

        let beatCreatorID = event.creatorID ?? event.shooterID
        let creator = event.creatorName ?? event.shooterName
        let flank = event.channel == .left ? "left" : "right"
        let buildUpZone: LegendsPresentationZone = event.channel == .left ? .leftBuildUp : .rightBuildUp
        let channelZone: LegendsPresentationZone = event.channel == .left ? .leftChannel : .rightChannel
        let bylineZone: LegendsPresentationZone = event.channel == .left ? .leftByline : .rightByline
        let defendingTeam = event.side.opposite
        var scriptedBeats: [LegendsPresentationBeat] = []
        let receiverTouchText: String
        switch event.commentaryVariant {
        case 0: receiverTouchText = "\(event.shooterName) takes it under control."
        case 1: receiverTouchText = "\(event.shooterName) cushions the pass and brings it down."
        default: receiverTouchText = "\(event.shooterName) takes a touch and looks up."
        }

        if event.setPiece != .penalty {
        switch event.attackPattern {
        case .wideCross:
            let carryText: String
            let crossText: String
            switch event.commentaryVariant {
            case 0:
                carryText = "\(creator) carries down the \(flank) flank, with room to run."
                crossText = "\(creator) sends a cross towards \(event.shooterName)."
            case 1:
                carryText = "\(creator) advances into the \(flank) channel and looks for support."
                crossText = "\(creator) swings the ball into the box for \(event.shooterName)."
            default:
                carryText = "\(creator) makes ground on the \(flank), stretching the defence."
                crossText = "\(creator) clips a dangerous ball towards \(event.shooterName)."
            }
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: channelZone,
                                       text: carryText))
            scriptedBeats.append(.init(action: .cross, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .penaltyArea,
                                       text: crossText))
            scriptedBeats.append(.init(action: .receive, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil, zone: .penaltyArea,
                                       text: receiverTouchText))
        case .cutback:
            let bylineText: String
            let cutbackText: String
            switch event.commentaryVariant {
            case 0:
                bylineText = "\(creator) reaches the byline on the \(flank) and looks up."
                cutbackText = "\(creator) cuts it back for \(event.shooterName)."
            case 1:
                bylineText = "\(creator) gets to the \(flank) byline."
                cutbackText = "\(creator) pulls it back into the path of \(event.shooterName)."
            default:
                bylineText = "\(creator) stretches the defence on the \(flank)."
                cutbackText = "\(creator) squares the ball for \(event.shooterName)."
            }
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: bylineZone,
                                       text: bylineText))
            scriptedBeats.append(.init(action: .cutback, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .edgeOfBox,
                                       text: cutbackText))
            scriptedBeats.append(.init(action: .receive, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil, zone: .edgeOfBox,
                                       text: receiverTouchText))
        case .centralCombination:
            let driveText: String
            switch event.commentaryVariant {
            case 0: driveText = "\(creator) drives through the centre, carrying the move forward."
            case 1: driveText = "\(creator) drives through midfield."
            default: driveText = "\(creator) turns inside and carries it through the middle."
            }
            let combineText: String
            switch event.commentaryVariant {
            case 0: combineText = "\(creator) keeps it moving into \(event.shooterName) at the edge of the box."
            case 1: combineText = "\(creator) combines with \(event.shooterName) at the edge of the area."
            default: combineText = "\(creator) plays a neat one-two with \(event.shooterName) at the box."
            }
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: .centre,
                                       text: driveText))
            scriptedBeats.append(.init(action: .pass, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .edgeOfBox,
                                       text: combineText))
            scriptedBeats.append(.init(action: .receive, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil, zone: .edgeOfBox,
                                       text: receiverTouchText))
        case .counterAttack:
            let counterText: String
            switch event.commentaryVariant {
            case 0: counterText = "\(creator) leads a quick counter through the \(flank) channel."
            case 1: counterText = "\(creator) breaks forward down the \(flank) side."
            default: counterText = "\(creator) carries the counter into the \(flank) channel."
            }
            let releaseText: String
            switch event.commentaryVariant {
            case 0: releaseText = "\(creator) releases \(event.shooterName) into space."
            case 1: releaseText = "\(creator) threads \(event.shooterName) through on goal."
            default: releaseText = "\(creator) spots the run and sends \(event.shooterName) through."
            }
            scriptedBeats.append(.init(action: .carry, actorID: beatCreatorID, actorName: creator,
                                       receiverID: nil, receiverName: nil, zone: buildUpZone,
                                       text: counterText))
            scriptedBeats.append(.init(action: .throughBall, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .penaltyArea,
                                       text: releaseText))
            scriptedBeats.append(.init(action: .receive, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil, zone: .penaltyArea,
                                       text: receiverTouchText))
        case .longShot:
            let longBallText: String
            switch event.commentaryVariant {
            case 0: longBallText = "\(creator) works it into central space for \(event.shooterName)."
            case 1: longBallText = "\(creator) finds \(event.shooterName) in shooting range."
            default: longBallText = "\(creator) moves it quickly into \(event.shooterName) at the top of the area."
            }
            scriptedBeats.append(.init(action: .pass, actorID: beatCreatorID, actorName: creator,
                                       receiverID: event.shooterID, receiverName: event.shooterName,
                                       zone: .edgeOfBox,
                                       text: longBallText))
            scriptedBeats.append(.init(action: .receive, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil, zone: .edgeOfBox,
                                       text: receiverTouchText))
        }
        }

        let pressure = event.markerName.map { " under pressure from \($0)" } ?? ""
        if event.isShotEvent {
            let shotText: String
            if event.setPiece == .penalty {
                shotText = "\(event.shooterName) steps up to take the penalty."
            } else {
                switch event.commentaryVariant {
                case 0: shotText = "\(event.shooterName) opens up for the shot\(pressure)."
                case 1: shotText = "\(event.shooterName) has a sight of goal and gets it away\(pressure)."
                default: shotText = "\(event.shooterName) pulls the trigger\(pressure)."
                }
            }
            scriptedBeats.append(.init(action: .shoot, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil,
                                       zone: event.attackPattern == .longShot ? .edgeOfBox : .penaltyArea,
                                       text: shotText))
        }
        switch event.outcome {
        case .goal:
            let keeper = event.goalkeeperName.map { " beyond \($0)" } ?? ""
            let goalZone: LegendsPresentationZone = event.channel == .left ? .rightGoal : .leftGoal
            let goalText: String
            switch event.commentaryVariant {
            case 0: goalText = "\(event.shooterName) finds the net\(keeper)!"
            case 1: goalText = "\(event.shooterName) beats the goalkeeper\(keeper) and it nestles in the net!"
            default: goalText = "The finish from \(event.shooterName) is too good for the keeper\(keeper)!"
            }
            scriptedBeats.append(.init(action: .goal, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: event.goalkeeperID, receiverName: event.goalkeeperName,
                                       zone: goalZone,
                                       text: goalText))
            restart = .kickoff(team: defendingTeam)
        case .saved:
            let keeper = event.goalkeeperName ?? "The goalkeeper"
            let saveZone: LegendsPresentationZone = event.channel == .left ? .leftGoal : .rightGoal
            let saveText: String
            switch event.commentaryVariant {
            case 0: saveText = "\(keeper) gathers the effort comfortably."
            case 1: saveText = "\(keeper) gets across and saves."
            default: saveText = "\(keeper) dives full stretch and keeps it out."
            }
            scriptedBeats.append(.init(action: .save, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: event.goalkeeperID, receiverName: event.goalkeeperName,
                                       zone: saveZone,
                                       text: saveText))
            restart = .goalkeeperPossession(team: defendingTeam)
        case .blocked:
            let marker = event.markerName ?? "The defender"
            let blockText: String
            switch event.commentaryVariant {
            case 0: blockText = "Blocked! \(marker) gets in the way."
            case 1: blockText = "\(marker) gets a body in the way and blocks the effort."
            default: blockText = "\(marker) throws himself in the way and makes the block."
            }
            scriptedBeats.append(.init(action: .block, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: event.markerID, receiverName: event.markerName,
                                       zone: .penaltyArea,
                                       text: blockText))
            restart = .corner(team: event.side, channel: event.channel)
        case .missed:
            let missText = event.commentaryVariant == 0
                ? "The effort flashes wide of the far post."
                : "The effort drifts just wide of the far post."
            scriptedBeats.append(.init(action: .miss, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil,
                                       zone: event.channel == .left ? .rightOfGoal : .leftOfGoal,
                                       text: missText))
            restart = .goalKick(team: defendingTeam)
        case .woodwork:
            let woodworkText = event.commentaryVariant == 2
                ? "The strike rattles the post!"
                : "The ball crashes against the post!"
            scriptedBeats.append(.init(action: .woodwork, actorID: event.shooterID, actorName: event.shooterName,
                                       receiverID: nil, receiverName: nil,
                                       zone: event.channel == .left ? .rightPost : .leftPost,
                                       text: woodworkText))
            restart = .goalKick(team: defendingTeam)
        case .foul:
            let marker = event.markerName ?? "The defender"
            let foulText = event.commentaryVariant == 1
                ? "\(marker) catches \(event.shooterName) in the \(flank) channel."
                : "\(marker) brings down \(event.shooterName) in the \(flank) channel."
            scriptedBeats = [.init(action: .foul, actorID: event.markerID, actorName: marker,
                                   receiverID: event.shooterID, receiverName: event.shooterName,
                                   zone: channelZone,
                                   text: foulText)]
            restart = .freeKick(team: event.side, channel: event.channel)
        case .offside:
            scriptedBeats = [.init(action: .offside, actorID: event.shooterID, actorName: event.shooterName,
                                   receiverID: event.creatorID, receiverName: event.creatorName,
                                   zone: .penaltyArea,
                                   text: "\(event.shooterName) goes too early and is caught offside.")]
            restart = .freeKick(team: defendingTeam, channel: event.channel)
        case .throwIn:
            scriptedBeats = [.init(action: .throwIn, actorID: beatCreatorID, actorName: creator,
                                   receiverID: event.shooterID, receiverName: event.shooterName,
                                   zone: channelZone,
                                   text: "\(creator) takes the throw-in towards \(event.shooterName).")]
            restart = .throwIn(team: event.side, channel: event.channel)
        case .tackled:
            let marker = event.markerName ?? "The defender"
            let tackleText = event.commentaryVariant == 2
                ? "\(marker) nicks the ball away from \(event.shooterName)."
                : "\(marker) times the tackle on \(event.shooterName) and wins possession."
            scriptedBeats = [.init(action: .tackle, actorID: event.markerID, actorName: marker,
                                   receiverID: event.shooterID, receiverName: event.shooterName,
                                   zone: channelZone,
                                   text: tackleText)]
            restart = .openPlay(team: defendingTeam, channel: event.channel)
        case .cleared:
            let marker = event.markerName ?? "The defender"
            let clearanceText = event.commentaryVariant == 0
                ? "\(marker) reads the danger and clears towards the \(flank) touchline."
                : "\(marker) sees the danger and hooks it towards the \(flank) touchline."
            scriptedBeats = [.init(action: .clearance, actorID: event.markerID, actorName: marker,
                                   receiverID: nil, receiverName: nil,
                                   zone: channelZone,
                                   text: clearanceText)]
            restart = .throwIn(team: event.side, channel: event.channel)
        }
        beats = scriptedBeats
    }

    var detailedText: String {
        beats.map(\.text).joined(separator: " ")
    }
}

@MainActor
@Observable
final class LegendsLiveMatch {
    let opponent: LegendsOpponent
    private let store: LegendsStore
    /// Snapshot of `store.startingXISlots` at kickoff — formation can't
    /// change mid-match, so this never needs to be resized.
    private let slots: [DetailedPosition]

    private(set) var minute = 0
    private(set) var addedTime = 0
    private(set) var teamGoals = 0
    private(set) var opponentGoals = 0
    private(set) var commentary: [CommentaryLine] = []
    private(set) var events: [LegendsMatchEvent] = []
    private(set) var isPaused = true
    private(set) var isHalfTime = false
    private(set) var isFinished = false
    private var halfTimeTaken = false
    var speed: Double = 1

    /// Seeded from `store.profile.preferredMentality` at kickoff, then
    /// freely editable mid-match — Career Mode allows the same.
    var userMentality: Mentality
    var userInstruction: MatchInstruction = .balanced

    private(set) var subsLeft = 5
    /// Indexed identically to `slots` — the card currently occupying
    /// that Starting XI slot, or nil if it was never filled (shouldn't
    /// happen for a match that was allowed to kick off, but defensive).
    private(set) var onPitchCardIDs: [String?]
    /// Kickoff XI and real minutes played are snapshotted by the engine so
    /// post-match statistics include substitutes without treating them as
    /// starters or giving every participant an automatic 90 minutes.
    private(set) var startingCardIDs: [String]
    private(set) var minutesPlayedByCardID: [String: Int]
    /// Parallel to `onPitchCardIDs` — 0...100, decays each minute for a
    /// filled slot, reset to 100 by a substitution into that slot.
    private(set) var energyBySlot: [Double]
    private(set) var benchCardIDs: [String]

    /// Home-relative, 0.5 = even. Cosmetic (not fed back into goal
    /// probability), same shape as Career's own momentum.
    private(set) var momentum: Double = 0.5
    private(set) var scorerCardIDs: [String] = []
    private(set) var substitutionFlashCount = 0
    private(set) var lastSubOffName = ""
    private(set) var lastSubOnName = ""

    private var loopTask: Task<Void, Never>?
    /// Engine events currently being presented by the 2D pitch. The match
    /// clock waits while these sets are non-empty, keeping commentary,
    /// actors and the visible ball sequence on the same authoritative event.
    private var presentationEventIDs: Set<String> = []
    private var unstartedPresentationEventIDs: Set<String> = []
    private var uses2DPresentation = false
    private var pendingGoalEvents: [String: LegendsMatchEvent] = [:]
    private var finishRequested = false
    private var presentedBeatKeys: Set<String> = []
    private var presentedAmbientActionIDs: Set<String> = []
    /// Cards removed from the live XI are unavailable for the remainder of
    /// this match, even if an older save or a UI callback still retains the
    /// persisted role assignment.
    private var unavailableUserCardIDs: Set<String> = []
    var isAwaiting2DPresentation: Bool {
        !presentationEventIDs.isEmpty || !unstartedPresentationEventIDs.isEmpty
    }
    /// Goals/subs after minute 45 — drives stoppage time, a cheap echo
    /// of Career's event-counted approach without needing cards/injuries.
    private var secondHalfEventCount = 0
    private var eventSequence = 0

    /// Manager/stadium tactical+gameplay bonus plus a chemistry nudge,
    /// snapshotted once at kickoff — mirrors the shape of the old instant-
    /// sim engine's `chemistryBonus = totalChemistry * 0.3 +
    /// matchStrengthBonus` (`LegendsMatchEngine.swift`/
    /// `LegendsStore+ManagersAndStadiums.swift`), which this live engine
    /// had never actually picked up despite being the only match path a
    /// real player ever sees — managers, stadiums and chemistry were
    /// dead weight here until now. Snapshotted rather than read live so a
    /// manager/stadium change can't retroactively skew an in-progress
    /// match (not that the live screen currently offers a way to change
    /// either mid-match anyway).
    private let strengthBonus: Double

    /// The exact bonus snapshot used by this live match, exposed read-only
    /// for regression coverage of instant/live parity.
    var appliedMatchStrengthBonus: Double { strengthBonus }

    /// Synthesized opponent XI (id/name/position + full attribute set),
    /// generated once at kickoff from the same deterministic roster the
    /// cosmetic 2D pitch already draws its 11 dots from
    /// (`LegendsOpponentRoster.swift`) — reused here so the score engine
    /// finally has real attributes to resolve a shot against instead of
    /// a single flat `opponent.rating` number. Pure/deterministic on
    /// `opponent.name`, no RNG draw, so constructing it doesn't perturb
    /// `rng`'s sequence (matters for `pairedAverageGoalsDelta`'s seeded
    /// A/B pairing in the tests).
    private let opponentRoster: (formation: Formation, slots: [DetailedPosition], players: [SyntheticOpponentPlayer])
    private let incidentScheduleOffset: Int

    /// Defaults to the system generator in production; tests can inject a
    /// seeded one (e.g. `SeededGenerator`) to run two matches through the
    /// *same* sequence of rolls and isolate the effect of a single input
    /// (mentality, a manager bonus, ...) from ordinary match-to-match
    /// variance — see `LegendsLiveMatchTests.pairedAverageGoalsDelta`.
    private var rng: any RandomNumberGenerator

    init(store: LegendsStore, opponent: LegendsOpponent, rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.store = store
        self.opponent = opponent

        // Treat persisted squad arrays as untrusted legacy input. Older or
        // interrupted saves can contain the wrong number of slots, stale IDs
        // or the same card more than once. Normalize to the current formation
        // so every parallel live-match array has exactly the same safe length.
        let slotSnapshot = store.startingXISlots
        self.slots = slotSnapshot
        let savedXI = store.profile.startingXICardIDs
        var usedCardIDs = Set<String>()
        let normalizedXI: [String?] = (0..<slotSnapshot.count).map { index in
            guard savedXI.indices.contains(index),
                  let cardID = savedXI[index],
                  !usedCardIDs.contains(cardID),
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
                  store.isSigned(card) else {
                return nil
            }
            usedCardIDs.insert(cardID)
            return cardID
        }
        self.onPitchCardIDs = normalizedXI
        self.startingCardIDs = normalizedXI.compactMap { $0 }
        self.minutesPlayedByCardID = Dictionary(uniqueKeysWithValues: normalizedXI.compactMap { $0 }.map { ($0, 0) })
        self.energyBySlot = Array(repeating: 100.0, count: slotSnapshot.count)

        var usedBenchIDs = Set<String>()
        self.benchCardIDs = store.profile.benchCardIDs.compactMap { cardID in
            guard let cardID,
                  !usedCardIDs.contains(cardID),
                  usedBenchIDs.insert(cardID).inserted,
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
                  store.isSigned(card) else {
                return nil
            }
            return cardID
        }

        self.userMentality = store.profile.preferredMentality
        self.strengthBonus = store.matchChemistryBonus(for: opponent)
        self.opponentRoster = LegendsOpponentRoster.generateRoster(for: opponent)
        self.incidentScheduleOffset = opponent.name.utf8.reduce(0) { partial, byte in
            (partial &* 31 &+ Int(byte)) % 97
        } % 7
        self.rng = rng
    }

    var totalMinutes: Int { 90 + addedTime }
    var result: LegendsMatchEngine.Result { LegendsMatchEngine.Result(teamGoals: teamGoals, opponentGoals: opponentGoals) }

    var userOnPitchCards: [LegendsCard] {
        onPitchCardIDs.compactMap { $0 }.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
    }
    var userBenchCards: [LegendsCard] {
        benchCardIDs.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
    }

    /// The persisted captain remains authoritative when available. If the
    /// captain is absent, substituted off or otherwise unavailable, the
    /// saved vice-captain takes the armband before automatic leadership
    /// selection is considered. The persisted assignments are never mutated.
    var effectiveCaptainCardID: String? {
        if let captain = activeUserCardID(for: .captain) { return captain }
        if let viceCaptain = activeUserCardID(for: .viceCaptain) { return viceCaptain }
        return automaticLeadershipCard()?.id
    }

    var activeViceCaptainCardID: String? {
        activeUserCardID(for: .viceCaptain)
    }

    /// Resolves a saved set-piece assignment against the live availability
    /// snapshot. A card on the bench, substituted off, missing from a legacy
    /// XI or otherwise absent is never returned; the deterministic
    /// attribute-based fallback is used instead.
    func setPieceTaker(for setPiece: LegendsSetPiece, team: Side = .home) -> LegendsSetPieceTaker? {
        guard team == .home else {
            return automaticOpponentSetPieceTaker(for: setPiece)
        }
        if let assignedID = activeUserCardID(for: setPiece.squadRole),
           let card = userCard(withID: assignedID) {
            return LegendsSetPieceTaker(id: card.id, name: card.name)
        }
        return automaticUserSetPieceTaker(for: setPiece)
    }

    private func activeUserCardID(for role: LegendsSquadRole) -> String? {
        let assignedID: String?
        if role == .captain {
            assignedID = store.profile.captainCardID
        } else {
            assignedID = store.profile.squadRoleAssignments[role.rawValue]
        }
        guard let assignedID,
              !unavailableUserCardIDs.contains(assignedID),
              onPitchCardIDs.contains(assignedID),
              let card = LegendsCardDatabase.all.first(where: { $0.id == assignedID }),
              store.isSigned(card),
              !store.isRetired(card) else {
            return nil
        }
        return assignedID
    }

    private func userCard(withID id: String) -> LegendsCard? {
        guard !unavailableUserCardIDs.contains(id), onPitchCardIDs.contains(id),
              let card = LegendsCardDatabase.all.first(where: { $0.id == id }),
              store.isSigned(card), !store.isRetired(card) else { return nil }
        return card
    }

    private func automaticLeadershipCard() -> LegendsCard? {
        onPitchCardIDs.compactMap { $0 }
            .filter { !unavailableUserCardIDs.contains($0) }
            .compactMap { id in LegendsCardDatabase.all.first(where: { $0.id == id }) }
            .filter { $0.position != .goalkeeper && store.isSigned($0) && !store.isRetired($0) }
            .max {
                let lhsAttributes = store.effectiveDetailedAttributes(for: $0)
                let rhsAttributes = store.effectiveDetailedAttributes(for: $1)
                let lhs = LegendsMatchSelectors.bounded(Double(lhsAttributes.leadership) * 0.7
                    + Double(lhsAttributes.composure) * 0.2 + Double(store.effectiveOverall(for: $0)) * 0.1)
                let rhs = LegendsMatchSelectors.bounded(Double(rhsAttributes.leadership) * 0.7
                    + Double(rhsAttributes.composure) * 0.2 + Double(store.effectiveOverall(for: $1)) * 0.1)
                return lhs == rhs ? $0.id > $1.id : lhs < rhs
            }
    }

    private func automaticUserSetPieceTaker(for setPiece: LegendsSetPiece) -> LegendsSetPieceTaker? {
        let candidates = onPitchCardIDs.compactMap { id -> LegendsCard? in
            guard let id, !unavailableUserCardIDs.contains(id),
                  let card = LegendsCardDatabase.all.first(where: { $0.id == id }),
                  card.position != .goalkeeper, store.isSigned(card), !store.isRetired(card) else { return nil }
            return card
        }
        guard let selected = candidates.max(by: { lhs, rhs in
            let left = userSetPieceScore(lhs, for: setPiece)
            let right = userSetPieceScore(rhs, for: setPiece)
            return left == right ? lhs.id > rhs.id : left < right
        }) else { return nil }
        return LegendsSetPieceTaker(id: selected.id, name: selected.name)
    }

    private func userSetPieceScore(_ card: LegendsCard, for setPiece: LegendsSetPiece) -> Int {
        let attributes = store.effectiveDetailedAttributes(for: card)
        switch setPiece {
        case .penalty:
            return LegendsMatchSelectors.shooting(attributes) * 2
                + attributes.setPieces * 2 + attributes.composure + store.effectiveOverall(for: card)
        case .directFreeKick:
            return attributes.setPieces * 3 + attributes.longShots * 2
                + attributes.passing + attributes.composure
        case .leftCorner, .rightCorner:
            return attributes.crossing * 3 + attributes.setPieces * 2
                + attributes.vision + attributes.passing
        }
    }

    private func automaticOpponentSetPieceTaker(for setPiece: LegendsSetPiece) -> LegendsSetPieceTaker? {
        let candidates = opponentRoster.players.filter { $0.position != .goalkeeper }
        guard let selected = candidates.max(by: { lhs, rhs in
            let left = opponentSetPieceScore(lhs, for: setPiece)
            let right = opponentSetPieceScore(rhs, for: setPiece)
            return left == right ? lhs.id > rhs.id : left < right
        }) else { return nil }
        return LegendsSetPieceTaker(id: selected.id, name: selected.name)
    }

    private func opponentSetPieceScore(_ player: SyntheticOpponentPlayer, for setPiece: LegendsSetPiece) -> Int {
        switch setPiece {
        case .penalty:
            return player.shooting * 2 + LegendsMatchSelectors.shooting(player.detailed) * 2
                + player.overall
        case .directFreeKick:
            return LegendsMatchSelectors.shooting(player.detailed) * 2
                + LegendsMatchSelectors.passing(player.detailed) + player.shooting
        case .leftCorner, .rightCorner:
            return player.passing * 2 + LegendsMatchSelectors.passing(player.detailed) * 2
                + player.overall
        }
    }

    // MARK: - Playback controls

    func start() {
        guard loopTask == nil else { return }
        say("Kick-off!")
        SoundManager.shared.play(.whistleKickOff)
        isPaused = false
        loopTask = Task { [weak self] in await self?.loop() }
    }

    func togglePause() { isPaused ? resume() : pause() }
    func pause() { isPaused = true }
    func resume() { isPaused = false; isHalfTime = false }
    func setSpeed(_ value: Double) { speed = value }

    /// Stops the live loop immediately — the "abandon match" path. The
    /// normal full-time flow ends the loop naturally via `isFinished`; an
    /// abandoned match never gets there, so the background task is
    /// cancelled outright and the engine is left paused so nothing can
    /// tick on. The result is not computed here — the caller records the
    /// forfeit loss itself.
    func stop() {
        loopTask?.cancel()
        loopTask = nil
        presentationEventIDs.removeAll()
        unstartedPresentationEventIDs.removeAll()
        isPaused = true
    }

    /// Enables the presentation-aware path used by the 2D match view. The
    /// seeded outcome is still selected immediately; goal score/commentary
    /// consequences wait for the renderer's net-confirmation callback.
    func enable2DPresentation() {
        uses2DPresentation = true
    }

    /// Keeps the direct centre restart behind the existing goal card. The
    /// simulation still owns the restart transition; this flag only lets the
    /// renderer acknowledge when the current card has finished.
    func holdGoalRestartUntilCardDismissal() {
        uses2DPresentation = true
    }

    func completeGoalCardPresentation(for eventID: String) {
        // The simulation owns the waiting event. This method is intentionally
        // a no-op at the score-engine level; the view forwards the dismissal
        // to the pitch state so a stale card cannot alter the result.
        _ = eventID
    }

    func presentAmbientAction(_ event: LegendsAmbientActionEvent) {
        guard presentedAmbientActionIDs.insert(event.id).inserted else { return }
        say(event.text, side: event.team)
    }

    func presentRestart(_ restart: LegendsMatchRestart, takerName: String? = nil) {
        let text: String
        let side: Side
        switch restart {
        case .kickoff(let team):
            text = "The conceding team restart from the centre spot."
            side = team
        case .goalkeeperPossession(let team):
            text = "The goalkeeper gathers the ball and restarts play."
            side = team
        case .goalKick(let team):
            text = "Play restarts with a goal kick."
            side = team
        case .corner(let team, let channel):
            let corner = channel == .left ? "left corner" : "right corner"
            text = takerName.map { "\($0) will take the \(corner)." }
                ?? "The attacking side prepare to take the corner."
            side = team
        case .freeKick(let team, _):
            text = takerName.map { "\($0) stands over the free kick." }
                ?? "Play restarts with the free kick."
            side = team
        case .throwIn(let team, _):
            text = "Play restarts with the throw-in."
            side = team
        case .openPlay(let team, _):
            text = "The defender wins possession and play continues."
            side = team
        }
        say(text, side: side)
    }

    func skipToEnd() {
        // Skip is intentionally headless: release any visual holds and
        // commit already-selected goals before using the same tick path to
        // finish the match synchronously.
        uses2DPresentation = false
        presentationEventIDs.removeAll()
        unstartedPresentationEventIDs.removeAll()
        let pending = events.compactMap { pendingGoalEvents.removeValue(forKey: $0.id) }
        for event in pending { scoreGoal(event) }
        finishRequested = false
        isHalfTime = false
        isPaused = false
        while !isFinished { tick() }
    }

    /// Synchronous single-minute advance, no delay — the async-free path
    /// unit tests drive instead of the real `Task`-based loop in `start()`.
    func testAdvanceMinute() {
        guard !isAwaiting2DPresentation else { return }
        isHalfTime = false
        tick()
    }

    func begin2DPresentation(for eventID: String) {
        unstartedPresentationEventIDs.remove(eventID)
        presentationEventIDs.insert(eventID)
    }

    func complete2DPresentation(for eventID: String) {
        presentationEventIDs.remove(eventID)
        unstartedPresentationEventIDs.remove(eventID)
        finishMatchIfReady()
    }

    /// Confirms a goal only after the pitch has reached the goal beat. The
    /// event and its shooter were selected earlier; this method only releases
    /// the visible score/commentary consequences once the ball is on the line.
    @discardableResult
    func confirmGoalPresentation(for eventID: String) -> Bool {
        guard let event = pendingGoalEvents.removeValue(forKey: eventID) else { return false }
        scoreGoal(event)
        finishMatchIfReady()
        return true
    }

    /// Adds one authored beat to the live feed when its matching visual
    /// action begins. Goal beats are intentionally held back: the goal line
    /// is emitted by `confirmGoalPresentation` at the instant the ball lands.
    func present2DBeat(for event: LegendsMatchEvent, beat: LegendsPresentationBeat, index: Int) {
        let key = "\(event.id)-\(index)"
        guard presentedBeatKeys.insert(key).inserted else { return }
        guard beat.action != .goal else { return }
        say(beat.text, side: event.side)
    }

    private func loop() async {
        // `Task.isCancelled` matters as much as `isFinished`: `stop()`
        // (the abandon path) cancels the task, and without checking it
        // here the loop would keep sleeping forever in the paused branch
        // — `try?` swallows the cancellation error — leaking the engine.
        while !isFinished && !Task.isCancelled {
            if isPaused || isHalfTime || isAwaiting2DPresentation {
                try? await Task.sleep(for: .milliseconds(80))
                continue
            }
            tick()
            let perMinute = UInt64(max(60, 700 / max(speed, 0.5)))
            try? await Task.sleep(for: .milliseconds(perMinute))
        }
    }

    // MARK: - Tick

    private func tick() {
        guard !isFinished else { return }
        minute += 1
        recordPlayedMinute()

        if minute == 45 && !halfTimeTaken {
            halfTimeTaken = true
            isHalfTime = true
            isPaused = true
            say("Half-time.")
            SoundManager.shared.play(.whistleHalfTime)
            return
        }

        if minute == 90 && addedTime == 0 {
            addedTime = min(6, 1 + secondHalfEventCount / 2 + Int.random(in: 0...1, using: &rng))
        }

        decayEnergy()
        let eventCountBeforeMinute = events.count
        rollGoalChances()
        if events.count == eventCountBeforeMinute {
            createScheduledIncidentIfNeeded()
        }
        recomputeMomentum()

        if minute >= totalMinutes {
            finishMatchIfReady()
        }
    }

    private func recordPlayedMinute() {
        // Career statistics use regulation minutes. Stoppage time is real
        // match time but does not turn a full appearance into 91–96 minutes.
        guard minute <= 90 else { return }
        for cardID in onPitchCardIDs.compactMap({ $0 }) {
            minutesPlayedByCardID[cardID, default: 0] += 1
        }
    }

    private func decayEnergy() {
        for index in energyBySlot.indices where onPitchCardIDs[index] != nil {
            energyBySlot[index] = max(20, energyBySlot[index] - Double.random(in: 0.2...0.5, using: &rng))
        }
    }

    /// Independent attack/defence ratios (see file header) rather than
    /// one shared ratio — lets mentality/instruction bite on "how often
    /// do I create a chance" and "how often I concede one" separately. A
    /// hit here used to *be* the goal directly; now it's a genuine
    /// attacking opportunity, resolved for real against the opposing
    /// side's actual players in `resolveChance`.
    private func rollGoalChances() {
        // The bonus applies symmetrically to attack and defence, matching
        // how the old instant-sim engine's single `chemistryBonus` term
        // boosted the team's overall competitiveness (it fed one shared
        // teamRating that decided both scoring and conceding odds via the
        // same ratio) rather than favoring one side of the ball.
        let liveAttack = energyWeightedAverage { $0.broad == .midfielder || $0.broad == .forward } + strengthBonus
        let liveDefence = energyWeightedAverage { $0 == .goalkeeper || $0.broad == .defender } + strengthBonus
        let oppRating = Double(opponent.rating)

        let effectiveAttack = max(liveAttack * userMentality.attack * userInstruction.attack, 1)
        let effectiveDefence = max(liveDefence * userMentality.solidity * userInstruction.solidity, 1)

        let userChanceRatio = effectiveAttack / (effectiveAttack + oppRating)
        let opponentChanceRatio = oppRating / (oppRating + effectiveDefence)

        let pUserChance = Self.chanceRatePerGame * userChanceRatio / 90
        let pOpponentChance = Self.chanceRatePerGame * opponentChanceRatio / 90

        if Double.random(in: 0..<1, using: &rng) < pUserChance {
            resolveChance(forUser: true)
        }
        if Double.random(in: 0..<1, using: &rng) < pOpponentChance {
            resolveChance(forUser: false)
        }
    }

    private func energyWeightedAverage(where matchesSlot: (DetailedPosition) -> Bool) -> Double {
        var total = 0.0
        var count = 0
        for (index, slot) in slots.enumerated() where matchesSlot(slot) {
            guard let cardID = onPitchCardIDs[index],
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { continue }
            let energyFactor = 0.72 + 0.28 * energyBySlot[index] / 100
            total += Double(store.effectiveOverall(for: card)) * energyFactor
            count += 1
        }
        guard count > 0 else { return 1 }
        return total / Double(count)
    }

    // MARK: - Shot resolution

    /// A single real player's shot-relevant numbers, resolved once per
    /// fired chance — works uniformly for a user `LegendsCard` or an
    /// opponent `SyntheticOpponentPlayer`. Not `private`: exposed
    /// (module-internal, via `@testable import`) so tests can exercise
    /// `conversionProbability` directly, without the statistical noise
    /// and dilution of proving an attribute's effect indirectly through
    /// a full paired-trial match simulation.
    struct ShotContestant {
        let id: String
        let name: String
        let shooting: Int
        let dribbling: Int
        let pace: Int
        let overall: Int
    }

    struct DefenseContestant {
        let defending: Int
        let physical: Int
        let keeperOverall: Int
    }

    private struct DefenseSelection {
        let contestant: DefenseContestant
        let markerID: String?
        let markerName: String?
        let goalkeeperID: String?
        let goalkeeperName: String?
    }

    /// Chances/game at exact parity between the two ratios above — the
    /// replacement for the old flat `2.7` (see file header): `2.7` used
    /// to be the *goal* rate directly; this is the *chance* rate, scaled
    /// up so that once `baseConversion` (below) is applied at parity the
    /// combined-team average lands back near the same ~2.7 goals/game.
    private static let chanceRatePerGame = 7.5

    private static let baseConversion = 0.35
    private static let conversionFloor = 0.05
    private static let conversionCeiling = 0.75

    /// One fired attacking chance, resolved for real: a weighted-random
    /// attacker against a weighted-random defender plus the defending
    /// side's goalkeeper, using actual `LegendsCard`/`SyntheticOpponentPlayer`
    /// attributes instead of a single blended `overall` and a pre-decided
    /// coin flip. The attacker who takes the shot is credited as scorer
    /// directly — no second, unrelated dice roll the way the old
    /// `weightedScorer()` ran *after* the goal was already decided.
    static func setPieceKind(for outcome: LegendsMatchEvent.Outcome,
                             channel: LegendsMatchEvent.Channel,
                             penaltyAwarded: Bool = false) -> LegendsSetPiece? {
        if penaltyAwarded { return .penalty }
        switch outcome {
        case .blocked:
            return channel == .left ? .leftCorner : .rightCorner
        case .foul:
            return .directFreeKick
        default:
            return nil
        }
    }

    private func resolveChance(forUser: Bool) {
        let attacker: ShotContestant
        let energyFactor: Double
        let creator: (id: String, name: String)?
        let defense: DefenseSelection
        if forUser {
            guard let picked = pickUserAttacker() else { return }
            (attacker, energyFactor) = picked
            creator = pickUserCreator(excluding: attacker.id)
            defense = opponentDefenseSelection()
        } else {
            attacker = pickOpponentAttacker()
            energyFactor = 1.0 // no fatigue system for the synthetic opponent roster
            creator = pickOpponentCreator(excluding: attacker.id)
            defense = userDefenseSelection()
        }

        let pConvert = conversionProbability(attacker: attacker, defense: defense.contestant, energyFactor: energyFactor)
        let scored = Double.random(in: 0..<1, using: &rng) < pConvert
        eventSequence += 1
        let resolvedOutcome: LegendsMatchEvent.Outcome = scored
            ? .goal
            : nonScoringOutcome(attacker: attacker, defense: defense.contestant)
        let channel: LegendsMatchEvent.Channel = eventSequence.isMultiple(of: 2) ? .right : .left
        let side: Side = forUser ? .home : .away
        // Reclassify a small deterministic share of already-resolved chances
        // as penalties. This consumes no RNG and never changes whether the
        // chance scored, preserving the established score/outcome model.
        let penaltyAwarded = (minute + eventSequence * 13 + incidentScheduleOffset).isMultiple(of: 29)
        let outcome: LegendsMatchEvent.Outcome = penaltyAwarded && resolvedOutcome == .blocked
            ? .saved
            : resolvedOutcome
        let setPiece = Self.setPieceKind(for: outcome, channel: channel, penaltyAwarded: penaltyAwarded)
        let selectedSetPieceTaker = setPiece.flatMap { self.setPieceTaker(for: $0, team: side) }
        let event = LegendsMatchEvent(
            id: "M\(minute)-E\(eventSequence)", minute: minute,
            side: side,
            outcome: outcome,
            channel: channel,
            attackPattern: attackPattern(forUser: forUser, shooterID: attacker.id, creatorID: creator?.id),
            creatorID: penaltyAwarded ? nil : creator?.id,
            creatorName: penaltyAwarded ? nil : creator?.name,
            shooterID: attacker.id, shooterName: attacker.name,
            markerID: defense.markerID, markerName: defense.markerName,
            goalkeeperID: defense.goalkeeperID, goalkeeperName: defense.goalkeeperName,
            expectedGoals: pConvert,
            setPiece: setPiece,
            setPieceTakerID: selectedSetPieceTaker?.id,
            setPieceTakerName: selectedSetPieceTaker?.name
        )
        appendAuthoritativeEvent(event)
        if scored {
            if uses2DPresentation {
                pendingGoalEvents[event.id] = event
            } else {
                scoreGoal(event)
            }
        } else {
            if !uses2DPresentation {
                say("Big chance for \(forUser ? store.profile.clubName : opponent.name). \(event.presentationScript.detailedText)", side: event.side)
            }
            bumpMomentum(towardUser: forUser, by: 0.05)
        }
    }

    /// Varies the visible resolution of a chance without changing whether it
    /// became a goal. This consumes no additional RNG, so the established
    /// score-rate balance and seeded match results remain unchanged.
    private func nonScoringOutcome(attacker: ShotContestant,
                                   defense: DefenseContestant) -> LegendsMatchEvent.Outcome {
        let selector = (minute * 7 + eventSequence * 11 + attacker.shooting
                        + defense.defending + defense.keeperOverall) % 10
        switch selector {
        case 0, 1: return .blocked
        case 2, 3, 4: return .missed
        case 5: return .woodwork
        default: return .saved
        }
    }

    /// Adds a small, deterministic number of non-shot incidents to a match.
    /// These moments do not alter the score calculation and use no random
    /// draws; they exist so commentary and the pitch can show the same foul,
    /// offside or throw-in instead of filling every gap with generic motion.
    private func createScheduledIncidentIfNeeded() {
        let outcome: LegendsMatchEvent.Outcome
        let scheduledMinute = minute + incidentScheduleOffset
        if scheduledMinute.isMultiple(of: 29) {
            outcome = .throwIn
        } else if scheduledMinute.isMultiple(of: 37) {
            outcome = .foul
        } else if scheduledMinute.isMultiple(of: 43) {
            outcome = .offside
        } else if scheduledMinute.isMultiple(of: 47) {
            outcome = .tackled
        } else if scheduledMinute.isMultiple(of: 53) {
            outcome = .cleared
        } else {
            return
        }

        let forUser = (minute / 10).isMultiple(of: 2)
        let attackers = incidentParticipants(forUser: forUser)
        let defenders = incidentParticipants(forUser: !forUser)
        guard !attackers.isEmpty, !defenders.isEmpty else { return }
        let actor = attackers[minute % attackers.count]
        let supporting = attackers[(minute + 3) % attackers.count]
        let defender = defenders[(minute + 5) % defenders.count]
        let channel: LegendsMatchEvent.Channel = minute.isMultiple(of: 2) ? .right : .left

        eventSequence += 1
        let side: Side = forUser ? .home : .away
        let setPiece = Self.setPieceKind(for: outcome, channel: channel)
        let selectedSetPieceTaker = setPiece.flatMap { self.setPieceTaker(for: $0, team: side) }
        let event = LegendsMatchEvent(
            id: "M\(minute)-E\(eventSequence)", minute: minute,
            side: side,
            outcome: outcome, channel: channel,
            attackPattern: outcome == .offside ? .counterAttack : .wideCross,
            creatorID: supporting.id, creatorName: supporting.name,
            shooterID: actor.id, shooterName: actor.name,
            markerID: defender.id, markerName: defender.name,
            goalkeeperID: nil, goalkeeperName: nil,
            expectedGoals: 0,
            setPiece: setPiece,
            setPieceTakerID: selectedSetPieceTaker?.id,
            setPieceTakerName: selectedSetPieceTaker?.name
        )
        appendAuthoritativeEvent(event)
        if !uses2DPresentation {
            say(event.presentationScript.detailedText, side: event.side)
        }
    }

    private func incidentParticipants(forUser: Bool) -> [(id: String, name: String)] {
        if forUser {
            return onPitchCardIDs.enumerated().compactMap { index, cardID in
                guard slots.indices.contains(index), slots[index].broad != .goalkeeper,
                      let cardID,
                      let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else {
                    return nil
                }
                return (card.id, card.name)
            }
        }
        return opponentRoster.players
            .filter { $0.position.broad != .goalkeeper }
            .map { (id: $0.id, name: $0.name) }
    }

    /// Chooses a plausible route from the selected players and match context.
    /// This is intentionally deterministic and consumes no extra RNG draw, so
    /// adding visual variety cannot change later score rolls in the same match.
    private func attackPattern(forUser: Bool, shooterID: String, creatorID: String?) -> LegendsMatchEvent.AttackPattern {
        let shooterPosition: DetailedPosition? = forUser
            ? LegendsCardDatabase.all.first(where: { $0.id == shooterID })?.position
            : opponentRoster.players.first(where: { $0.id == shooterID })?.position
        let creatorPosition: DetailedPosition? = creatorID.flatMap { id in
            forUser
                ? LegendsCardDatabase.all.first(where: { $0.id == id })?.position
                : opponentRoster.players.first(where: { $0.id == id })?.position
        }
        let selector = (minute + eventSequence * 7) % 10
        if shooterPosition?.broad == .midfielder && selector <= 2 { return .longShot }
        if let creatorPosition, [.leftWing, .rightWing, .leftMid, .rightMid, .leftBack, .rightBack].contains(creatorPosition) {
            return selector.isMultiple(of: 2) ? .wideCross : .cutback
        }
        if selector == 3 || selector == 8 { return .counterAttack }
        if selector <= 5 { return .centralCombination }
        return selector.isMultiple(of: 2) ? .wideCross : .cutback
    }

    private func attackerPower(_ a: ShotContestant, energyFactor: Double) -> Double {
        (Double(a.shooting) * 1.6 + Double(a.dribbling) * 0.9 + Double(a.pace) * 0.5 + Double(a.overall) * 0.4) * energyFactor
    }

    private func defensePower(_ d: DefenseContestant) -> Double {
        Double(d.defending) * 1.3 + Double(d.physical) * 0.9 + Double(d.keeperOverall) * 1.1
    }

    func conversionProbability(attacker: ShotContestant, defense: DefenseContestant, energyFactor: Double) -> Double {
        let ap = attackerPower(attacker, energyFactor: energyFactor)
        let dp = defensePower(defense)
        let shotQuality = ap / (ap + dp) // 0...1, 0.5 at parity
        let raw = Self.baseConversion * (shotQuality / 0.5)
        return min(Self.conversionCeiling, max(Self.conversionFloor, raw))
    }

    private func positionWeight(_ broad: Position) -> Double {
        switch broad {
        case .forward: return 5
        case .midfielder: return 2
        case .defender: return 0.3
        case .goalkeeper: return 0.02
        }
    }

    /// Forward-heaviest, same shape the old `weightedScorer()` used —
    /// extended to read `dribbling`/`pace` alongside `shooting`/`overall`
    /// now that a real shot-quality contest exists to feed them into.
    private func pickUserAttacker() -> (ShotContestant, energyFactor: Double)? {
        let candidates: [(index: Int, card: LegendsCard)] = slots.indices.compactMap { index in
            guard let cardID = onPitchCardIDs[index],
                  let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { return nil }
            return (index, card)
        }
        guard !candidates.isEmpty else { return nil }
        func weight(_ card: LegendsCard) -> Double {
            positionWeight(card.position.broad) * (Double(card.shooting) * 2.5 + Double(store.effectiveOverall(for: card)) * 0.3)
        }
        let totalWeight = candidates.reduce(0.0) { $0 + weight($1.card) }
        let picked: (index: Int, card: LegendsCard)
        if totalWeight > 0 {
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            picked = candidates.first { roll -= weight($0.card); return roll < 0 } ?? candidates[candidates.count - 1]
        } else {
            picked = candidates[Int.random(in: 0..<candidates.count, using: &rng)]
        }
        let energyFactor = 0.72 + 0.28 * energyBySlot[picked.index] / 100
        let detailed = store.effectiveDetailedAttributes(for: picked.card)
        let contestant = ShotContestant(id: picked.card.id, name: picked.card.name, shooting: LegendsMatchSelectors.shooting(detailed),
                                         dribbling: LegendsMatchSelectors.dribbling(detailed), pace: detailed.sprintSpeed,
                                         overall: store.effectiveOverall(for: picked.card))
        return (contestant, energyFactor)
    }

    private func pickOpponentAttacker() -> ShotContestant {
        let players = opponentRoster.players
        func weight(_ player: SyntheticOpponentPlayer) -> Double {
            positionWeight(player.position.broad) * (Double(player.shooting) * 2.5 + Double(player.overall) * 0.3)
        }
        let totalWeight = players.reduce(0.0) { $0 + weight($1) }
        let picked: SyntheticOpponentPlayer
        if totalWeight > 0 {
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            picked = players.first { roll -= weight($0); return roll < 0 } ?? players[players.count - 1]
        } else {
            picked = players[Int.random(in: 0..<players.count, using: &rng)]
        }
        return ShotContestant(id: picked.id, name: picked.name, shooting: picked.shooting,
                               dribbling: picked.dribbling, pace: picked.pace, overall: picked.overall)
    }

    private func pickUserCreator(excluding shooterID: String) -> (id: String, name: String)? {
        let candidates = onPitchCardIDs.compactMap { $0 }.filter { $0 != shooterID }.compactMap { id in
            LegendsCardDatabase.all.first { $0.id == id }
        }
        let preferred = candidates.filter { $0.position.broad == .midfielder || $0.position.broad == .forward }
        let pool = preferred.isEmpty ? candidates : preferred
        return pool.max { lhs, rhs in
            let left = store.effectiveDetailedAttributes(for: lhs)
            let right = store.effectiveDetailedAttributes(for: rhs)
            let leftScore = LegendsMatchSelectors.chanceCreation(left) + LegendsMatchSelectors.passing(left)
            let rightScore = LegendsMatchSelectors.chanceCreation(right) + LegendsMatchSelectors.passing(right)
            return leftScore == rightScore ? lhs.id > rhs.id : leftScore < rightScore
        }.map { ($0.id, $0.name) }
    }

    private func pickOpponentCreator(excluding shooterID: String) -> (id: String, name: String)? {
        let candidates = opponentRoster.players.filter { $0.id != shooterID }
        let preferred = candidates.filter { $0.position.broad == .midfielder || $0.position.broad == .forward }
        let pool = preferred.isEmpty ? candidates : preferred
        return pool.max { lhs, rhs in
            let leftScore = LegendsMatchSelectors.chanceCreation(lhs.detailed) + LegendsMatchSelectors.passing(lhs.detailed)
            let rightScore = LegendsMatchSelectors.chanceCreation(rhs.detailed) + LegendsMatchSelectors.passing(rhs.detailed)
            return leftScore == rightScore ? lhs.id > rhs.id : leftScore < rightScore
        }.map { ($0.id, $0.name) }
    }

    /// Weighted toward the on-pitch defenders' average, plus the user's
    /// actual on-pitch goalkeeper standing in for shot-stopping.
    private func userDefenseSelection() -> DefenseSelection {
        let outfield: [LegendsCard] = slots.indices.compactMap { index in
            guard slots[index].broad != .goalkeeper, let cardID = onPitchCardIDs[index] else { return nil }
            return LegendsCardDatabase.all.first { $0.id == cardID }
        }
        let defenders = outfield.filter { $0.position.broad == .defender }
        let pool = defenders.isEmpty ? outfield : defenders
        let marker = pool.max { lhs, rhs in
            let left = LegendsMatchSelectors.defending(store.effectiveDetailedAttributes(for: lhs))
            let right = LegendsMatchSelectors.defending(store.effectiveDetailedAttributes(for: rhs))
            return left == right ? lhs.id > rhs.id : left < right
        }
        let keeper: LegendsCard? = slots.indices.compactMap { index -> LegendsCard? in
            guard slots[index] == .goalkeeper, let cardID = onPitchCardIDs[index] else { return nil }
            return LegendsCardDatabase.all.first { $0.id == cardID }
        }.first
        let markerAttributes = marker.map { store.effectiveDetailedAttributes(for: $0) }
        let keeperOverall = keeper.map { card in
            let keeper = LegendsMatchSelectors.goalkeeper(store.effectiveDetailedAttributes(for: card))
            return Int((Double(store.effectiveOverall(for: card)) * 0.7 + Double(keeper) * 0.3).rounded())
        } ?? opponent.rating
        return DefenseSelection(
            contestant: DefenseContestant(
                defending: markerAttributes.map { LegendsMatchSelectors.defending($0) } ?? opponent.rating,
                physical: markerAttributes?.strength ?? opponent.rating,
                keeperOverall: keeperOverall
            ),
            markerID: marker?.id, markerName: marker?.name,
            goalkeeperID: keeper?.id, goalkeeperName: keeper?.name
        )
    }

    private func opponentDefenseSelection() -> DefenseSelection {
        let defenders = opponentRoster.players.filter { $0.position.broad == .defender }
        let outfield = opponentRoster.players.filter { $0.position.broad != .goalkeeper }
        let pool = defenders.isEmpty ? outfield : defenders
        let marker = pool.max { lhs, rhs in
            let left = LegendsMatchSelectors.defending(lhs.detailed)
            let right = LegendsMatchSelectors.defending(rhs.detailed)
            return left == right ? lhs.id > rhs.id : left < right
        }
        let keeper = opponentRoster.players.first { $0.position == .goalkeeper }
        return DefenseSelection(
            contestant: DefenseContestant(
                defending: marker.map { LegendsMatchSelectors.defending($0.detailed) } ?? opponent.rating,
                physical: marker?.physical ?? opponent.rating,
                keeperOverall: keeper.map { LegendsMatchSelectors.goalkeeper($0.detailed) } ?? opponent.rating
            ),
            markerID: marker?.id, markerName: marker?.name,
            goalkeeperID: keeper?.id, goalkeeperName: keeper?.name
        )
    }

    private func appendAuthoritativeEvent(_ event: LegendsMatchEvent) {
        events.append(event)
        if uses2DPresentation {
            unstartedPresentationEventIDs.insert(event.id)
        }
    }

    /// `scorerCardID` is only ever supplied for the user side —
    /// `scorerCardIDs` is user-scoped bookkeeping (nothing in the UI
    /// reads an opponent-side equivalent), while `scorerName` names
    /// whoever actually took the shot on both sides, finally giving
    /// opponent goals a named scorer in commentary — they previously had
    /// none at all.
    private func scoreGoal(_ event: LegendsMatchEvent) {
        let confirmation = event.presentationScript.beats.last(where: { $0.action == .goal })?.text ?? "The finish is in."
        if event.isUserEvent {
            teamGoals += 1
            scorerCardIDs.append(event.shooterID)
            let assist = event.creatorName.map { " (assist: \($0))" } ?? ""
            say("⚽︎ GOAL! \(event.shooterName) scores! \(confirmation)\(assist) \(store.profile.clubName) \(teamGoals)-\(opponentGoals) \(opponent.name)", side: .home)
            bumpMomentum(towardUser: true, by: 0.22)
            SoundManager.shared.play(.goalCrowd)
        } else {
            opponentGoals += 1
            let assist = event.creatorName.map { " (assist: \($0))" } ?? ""
            say("⚽︎ GOAL! \(event.shooterName) scores! \(confirmation)\(assist) \(opponent.name) \(opponentGoals)-\(teamGoals) \(store.profile.clubName)", side: .away)
            bumpMomentum(towardUser: false, by: 0.22)
        }
        if minute > 45 { secondHalfEventCount += 1 }
    }

    private func bumpMomentum(towardUser: Bool, by amount: Double) {
        let delta = towardUser ? amount : -amount
        momentum = min(0.85, max(0.15, momentum + delta))
    }

    private func recomputeMomentum() {
        momentum += (0.5 - momentum) * 0.12
    }

    private func finishMatchIfReady() {
        guard !isFinished else { return }
        guard finishRequested || minute >= totalMinutes else { return }
        if uses2DPresentation && (isAwaiting2DPresentation || !pendingGoalEvents.isEmpty) {
            finishRequested = true
            return
        }
        finishRequested = false
        finishMatch()
    }

    private func finishMatch() {
        guard !isFinished else { return }
        isFinished = true
        isPaused = true
        say("Full-time! \(store.profile.clubName) \(teamGoals)-\(opponentGoals) \(opponent.name)")
        SoundManager.shared.play(.whistleFullTime)
    }

    // MARK: - Substitutions

    /// No position-legality rule (matches Career): `off` just needs to be
    /// currently on the pitch, `on` currently on the bench. A subbed-off
    /// card doesn't return to the bench — same as real football, once
    /// they're off, they're out for the rest of the match.
    @discardableResult
    func makeUserSub(offCardID: String, onCardID: String) -> Bool {
        guard subsLeft > 0 else { return false }
        guard let slotIndex = onPitchCardIDs.firstIndex(of: offCardID) else { return false }
        guard let benchIndex = benchCardIDs.firstIndex(of: onCardID) else { return false }

        let offName = LegendsCardDatabase.all.first { $0.id == offCardID }?.name ?? ""
        let onName = LegendsCardDatabase.all.first { $0.id == onCardID }?.name ?? ""

        onPitchCardIDs[slotIndex] = onCardID
        unavailableUserCardIDs.insert(offCardID)
        minutesPlayedByCardID[onCardID, default: 0] = 0
        energyBySlot[slotIndex] = 100
        benchCardIDs.remove(at: benchIndex)

        subsLeft -= 1
        substitutionFlashCount += 1
        lastSubOffName = offName
        lastSubOnName = onName
        say("🔄 \(onName) replaces \(offName).", side: .home)
        SoundManager.shared.play(.substitution)
        if minute > 45 { secondHalfEventCount += 1 }
        return true
    }

    // MARK: - Commentary

    private func say(_ text: String, side: Side? = nil) {
        let label = minute > 90 ? "90+\(minute - 90)" : "\(minute)"
        commentary.append(CommentaryLine(text: "\(label)'  \(text)", side: side))
        if commentary.count > 60 { commentary.removeFirst(commentary.count - 60) }
    }
}
