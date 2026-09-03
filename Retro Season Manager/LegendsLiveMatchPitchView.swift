//
//  LegendsLiveMatchPitchView.swift
//  Retro Season Manager
//
//  Phase 0 of the Legends 2D match simulator built the pitch coordinate
//  system and a static formation render. Phase 1 added continuous
//  motion. Phase 2 connected the ball to real match commentary. Phases
//  3-5 added real players running the attack, a goalkeeper reaction, and
//  a marking defender. Phase 6 made the pitch the match's *default* view
//  instead of a debug sheet behind a "2D" button — this file's job
//  narrowed accordingly: it no longer owns a `LegendsMatchSimulation`,
//  a header, or dismiss chrome of its own. `LegendsPitchCanvas` is now
//  just the reusable rendering piece — background, markings, the
//  Canvas draw loop, the legend — that `LegendsLiveMatchView.swift`
//  embeds directly alongside its existing score bar and control bar,
//  which is also where the simulation now lives and where its pacing is
//  kept in step with the real match's own speed/pause state.
//

import SwiftUI

/// The animated state of a `BallImpact`'s expanding goal-mouth flash at a
/// given moment — the pure, testable core of `drawImpactFlash`'s visibility
/// window (the canvas calls `state(for:at:)` with `Date()` on every draw).
/// `nil` when the flash has not started yet (a clock skew before the
/// impact's own timestamp) or has already expired — exactly the cases where
/// the canvas draws nothing. Extracted so the "is this impact actually
/// rendered, and how big/faded" question is assertable without a UI
/// snapshot.
struct ImpactFlashState {
    /// 0...1 through the 0.6s window — drives both the ring's growth and
    /// its fade-out.
    let progress: Double
    /// The ring's current radius in points — grows from 0 to `maxRadius`.
    let radius: CGFloat
    /// 1...0 — how opaque the ring still is.
    let opacity: Double

    /// How long an impact flash stays visible once it fires.
    static let duration: TimeInterval = 0.6
    /// The ring's final radius, in points.
    static let maxRadius: CGFloat = 46

    /// The flash's state `now` seconds after (or before) the impact fired —
    /// `nil` outside the `[0, duration)` window, so the canvas simply draws
    /// nothing then.
    static func state(for impact: BallImpact, at now: Date) -> ImpactFlashState? {
        let elapsed = now.timeIntervalSince(impact.time)
        guard elapsed >= 0, elapsed < duration else { return nil }
        let progress = elapsed / duration
        return ImpactFlashState(progress: progress,
                                radius: maxRadius * CGFloat(progress),
                                opacity: 1 - progress)
    }
}

struct LegendsPitchCanvas: View {
    let simulation: LegendsMatchSimulation
    let userColor: Color
    let opponentColor: Color
    let userName: String
    let opponentName: String

    /// Bumped ~30×/sec by the `.task` sleep-loop below to force fresh
    /// `Canvas` draws. `TimelineView(.animation)` was tried first here and
    /// reliably redrew *only* when some other TimelineView happened to
    /// exist elsewhere in the hierarchy (confirmed by A/B testing on
    /// device) — nested alone, on this SwiftUI version, it draws the
    /// first frame and then never fires again, silently freezing the
    /// whole pitch. A plain `@State` counter driving redraws through
    /// SwiftUI's ordinary invalidation path is the well-established,
    /// reliable alternative, so that's what this uses instead.
    @State private var renderTick = 0

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack {
                    LandscapePitchBackground()
                    Canvas { context, size in
                        _ = renderTick
                        draw(into: context, size: size)
                    }
                }
            }
            .aspectRatio(1.55, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Legends match pitch")
            .accessibilityValue(impactAccessibilitySummary)
            .accessibilityIdentifier("legends.match.pitch")
            legend
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                renderTick &+= 1
            }
        }
    }

    /// `PitchCoordinateSystem`'s (x, y) is a portrait-pitch frame — x is
    /// touchline-to-touchline spread, y is goal-to-goal depth (0 = the
    /// opponent's goal line, 1 = the user's own). This view reads goal-to-
    /// goal across the screen's *width*, the classic match-tracker layout
    /// the reference image uses (own goal on the left, attacking right),
    /// so depth maps to x and spread maps to y — a transpose, not a
    /// change to the coordinate system itself, which stays reusable
    /// as-is for the Squad screen's vertical tactics board.
    private func landscapePosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (1 - point.y), y: size.height * point.x)
    }

    private func draw(into context: GraphicsContext, size: CGSize) {
        let ballPosition = simulation.ball.position
        // Show the ring only when a real player controls the ball. Passes,
        // crosses and shots are unowned while in flight; being nearest to a
        // loose ball is not the same thing as having possession.
        let possessionPlayerID = simulation.possessionPlayerID

        // Departed players' dots fading out at their last position — the
        // "leaving the pitch" half of a substitution, drawn while the
        // incoming card walks on from the touchline as a normal player
        // dot. The ~30Hz redraw re-evaluates the alpha with a fresh
        // `Date()` each frame, exactly like the impact flash, so the dot
        // fades on its own with no extra dismissal state.
        for ghost in simulation.departingGhosts {
            let elapsed = Date().timeIntervalSince(ghost.time)
            guard elapsed >= 0, elapsed < SubstitutionGhost.duration else { continue }
            let pos = landscapePosition(for: ghost.position, in: size)
            let alpha = 1 - elapsed / SubstitutionGhost.duration
            let rect = CGRect(x: pos.x - 10, y: pos.y - 10, width: 20, height: 20)
            context.fill(Path(ellipseIn: rect), with: .color(userColor.opacity(alpha)))
            context.stroke(Path(ellipseIn: rect), with: .color(Retro.background.opacity(alpha)), lineWidth: 1)
            let label = context.resolve(
                Text(surname(ghost.name))
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(alpha))
            )
            context.draw(label, at: pos)
        }

        for player in simulation.players {
            let pos = landscapePosition(for: player.position, in: size)
            let color = player.team == .home ? userColor : opponentColor
            let radius: CGFloat = 10

            if player.id == possessionPlayerID {
                let ringRadius = radius + 4
                let ringRect = CGRect(x: pos.x - ringRadius, y: pos.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
                context.stroke(Path(ellipseIn: ringRect), with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            }

            let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            context.stroke(Path(ellipseIn: rect), with: .color(Retro.background), lineWidth: 1)

            // The player's surname, not a static role abbreviation — a
            // substitution swaps the dot's identity via
            // `LegendsMatchSimulation.applySubstitution`, and the label
            // is the only per-dot visual that can show it. Surname-only
            // keeps 22 dots readable at this size (the same compact-token
            // helper the Career lineups panel already uses).
            let label = context.resolve(
                Text(surname(player.name))
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            )
            context.draw(label, at: pos)
        }

        let ballPos = landscapePosition(for: ballPosition, in: size)
        let ballRadius: CGFloat = 4.5
        let ballRect = CGRect(x: ballPos.x - ballRadius, y: ballPos.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)
        context.fill(Path(ellipseIn: ballRect), with: .color(.white))
        context.stroke(Path(ellipseIn: ballRect), with: .color(.black.opacity(0.3)), lineWidth: 0.5)

        drawImpactFlash(into: context, size: size)
    }

    /// An expanding, fading ring at the goal mouth when a shot resolves —
    /// gold and slightly filled for a goal, plain white outline for a
    /// chance that goes just wide. Self-expiring: delegates the entire
    /// visibility window and animation to `ImpactFlashState.state(for:at:)`
    /// (see that type for why it's pure), and draws the ring the state
    /// describes — the canvas's ~30Hz redraw tick re-evaluates it every
    /// frame with a fresh `Date()`, so the ring grows and fades on its own
    /// with no extra dismissal state.
    private func drawImpactFlash(into context: GraphicsContext, size: CGSize) {
        guard let impact = simulation.lastImpact,
              let flash = ImpactFlashState.state(for: impact, at: Date()) else { return }

        let pos = landscapePosition(for: impact.position, in: size)
        let rect = CGRect(x: pos.x - flash.radius, y: pos.y - flash.radius,
                          width: flash.radius * 2, height: flash.radius * 2)
        let color: Color = impact.kind == .goal ? Retro.gold : .white

        if impact.kind == .goal {
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(flash.opacity * 0.25)))
        }
        context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(flash.opacity)), lineWidth: 3)

        // Keep the action readable in the visual layer: the flash names
        // the attribute-selected participants rather than showing an
        // anonymous ring. The compact label remains legible in landscape
        // and is also mirrored by the accessibility summary below.
        let participants = [
            impact.runnerName.map { "RUN \(surname($0))" },
            impact.finisherName.map { "FINISH \(surname($0))" },
            impact.markerName.map { "MARK \(surname($0))" }
        ].compactMap { $0 }
        guard !participants.isEmpty else { return }
        let text = participants.joined(separator: "  ·  ")
        let label = context.resolve(
            Text(text)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(color.opacity(flash.opacity))
        )
        context.draw(label, at: CGPoint(x: pos.x, y: max(10, pos.y - flash.radius - 10)))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(userColor).frame(width: 10, height: 10)
                Text(userName)
            }
            HStack(spacing: 6) {
                Circle().fill(opponentColor).frame(width: 10, height: 10)
                Text(opponentName)
            }
        }
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(Retro.text.opacity(0.75))
    }

    /// VoiceOver gets the same event context that the Canvas paints next
    /// to the impact ring. This is derived read-only from the latest
    /// immutable impact snapshot and never mutates simulation state.
    private var impactAccessibilitySummary: String {
        guard let impact = simulation.lastImpact else { return "No active match event" }
        let names = [
            impact.runnerName.map { "wide run by \($0)" },
            impact.finisherName.map { "finish by \($0)" },
            impact.markerName.map { "marked by \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")
        return names.isEmpty ? "Latest match event" : names
    }
}

/// Landscape pitch markings — halfway line vertical, penalty boxes at the
/// left and right ends — the transpose of Career's `PitchMarkings`
/// (`PitchView.swift`), which assumes a portrait rect with boxes top and
/// bottom for the Squad screen's vertical tactics board. Kept local to
/// this file rather than added to `PitchView.swift` since nothing else
/// needs a landscape pitch today.
private struct LandscapePitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        // Halfway line.
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        // Centre circle.
        let radius = min(rect.width, rect.height) * 0.11
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius,
                                   width: radius * 2, height: radius * 2))
        // Penalty boxes at each end.
        let boxWidth = rect.width * 0.15
        let boxHeight = rect.height * 0.5
        path.addRect(CGRect(x: rect.minX, y: rect.midY - boxHeight / 2,
                            width: boxWidth, height: boxHeight))
        path.addRect(CGRect(x: rect.maxX - boxWidth, y: rect.midY - boxHeight / 2,
                            width: boxWidth, height: boxHeight))
        return path
    }
}

/// The green pitch with mown stripes running vertically (stacked
/// left-to-right) and landscape markings — the transpose of `PitchView.swift`'s
/// `PitchBackground`, whose horizontal stripe bands assume a portrait rect.
private struct LandscapePitchBackground: View {
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(Array(0..<7), id: \.self) { index in
                    (index.isMultiple(of: 2) ? Retro.pitch : Retro.pitchLight)
                }
            }
            LandscapePitchMarkings()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
