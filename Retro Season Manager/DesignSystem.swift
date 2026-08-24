//
//  DesignSystem.swift
//  Retro Season Manager
//
//  Shared visual language: the Retro colour palette, haptics, button
//  styles and small cross-cutting SwiftUI helpers used by every screen.
//

import SwiftUI

extension Color {
    /// Builds a colour from a stored [red, green, blue] array.
    init(rgb: [Double]) {
        self.init(red: rgb.count > 0 ? rgb[0] : 0.5,
                  green: rgb.count > 1 ? rgb[1] : 0.5,
                  blue: rgb.count > 2 ? rgb[2] : 0.5)
    }

    /// A colour seeded from `seed` (deterministic per name, e.g. an
    /// opponent's name) whose hue is pushed at least ~80° around the
    /// wheel from `hue`. Used for opponent crest/badge/pitch-token
    /// colours, which used to pick a fully random hue and could
    /// coincidentally land on — or dangerously close to — the user's own
    /// crest colour, making the two teams hard to tell apart on the
    /// score bar or 2D pitch.
    static func distinctOpponentColor(seed: String, awayFromHue hue: Double) -> Color {
        var gen = SeededGenerator(seed: seed)
        let offset = Double.random(in: 0.22...0.78, using: &gen)
        let opponentHue = (hue + offset).truncatingRemainder(dividingBy: 1)
        return Color(hue: opponentHue, saturation: 0.5, brightness: 0.75)
    }

    /// Approximate hue (0...1) of an [r, g, b] triplet, each 0...1 — the
    /// counterpart `distinctOpponentColor` steers away from.
    static func hue01(ofRGB rgb: [Double]) -> Double {
        guard rgb.count >= 3 else { return 0 }
        let r = rgb[0], g = rgb[1], b = rgb[2]
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        guard delta > 0.0001 else { return 0 }
        var hue: Double
        if maxC == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return hue / 360
    }
}

extension GameStore {
    /// The user club's primary colour.
    var userColor: Color { Color(rgb: userClub.colorRGB) }
    /// The primary colour of any club.
    func color(forClubIndex index: Int) -> Color {
        clubs.indices.contains(index) ? Color(rgb: clubs[index].colorRGB) : Retro.accent
    }
}

/// A retro colour palette for that classic "green screen" manager feel.
/// The game's brand palette — everything in the "modern retro" art package
/// (icons, badges, trophies, portraits) is built from these named colours
/// only, so the whole app reads as one consistent, football-green identity
/// instead of a grab-bag of similar-but-different greens.
enum Retro {
    // Primary greens, exact brand hex values.
    static let emerald    = Color(red: 0x19 / 255, green: 0xC2 / 255, blue: 0x5A / 255)  // #19C25A
    static let darkGreen  = Color(red: 0x0B / 255, green: 0x33 / 255, blue: 0x16 / 255)  // #0B3316
    static let forest     = Color(red: 0x14 / 255, green: 0x5A / 255, blue: 0x2B / 255)  // #145A2B
    static let pitchGreen = Color(red: 0x2C / 255, green: 0x7A / 255, blue: 0x3F / 255)  // #2C7A3F

    // Accents.
    static let royalBlue = Color(red: 0x2A / 255, green: 0x5C / 255, blue: 0xE8 / 255)   // #2A5CE8
    static let gold       = Color(red: 0xF4 / 255, green: 0xC1 / 255, blue: 0x3A / 255)  // #F4C13A
    static let pureWhite  = Color.white
    static let pureBlack  = Color.black
    static let warning    = Color(red: 0xE5 / 255, green: 0x4D / 255, blue: 0x42 / 255)  // red, warnings only

    // Existing semantic roles, now sourced from the brand palette above.
    static let background = darkGreen
    static let panel      = forest
    static let accent     = emerald
    static let text       = Color(red: 0.82, green: 0.97, blue: 0.85)
    static let highlight  = gold

    // Tactics-screen colours (green pitch, purple player tokens).
    static let pitch      = pitchGreen
    static let pitchLight = Color(red: 0.20, green: 0.50, blue: 0.30)
    static let token      = Color(red: 0.42, green: 0.26, blue: 0.62)
    static let tokenEdge  = Color(red: 0.60, green: 0.42, blue: 0.85)

    // Traffic-light position fit.
    static let fitGood = emerald
    static let fitOkay = gold
    static let fitPoor = warning

    // Metallic trophy-tier tones.
    static let bronze = Color(red: 0xCD / 255, green: 0x7F / 255, blue: 0x32 / 255)
    static let silver = Color(red: 0xC4 / 255, green: 0xC9 / 255, blue: 0xCE / 255)
}

extension PositionFitLevel {
    var color: Color {
        switch self {
        case .confident: return Retro.fitGood
        case .okay:       return Retro.fitOkay
        case .poor:       return Retro.fitPoor
        }
    }
}

#if os(iOS)
import UIKit
#endif

/// Tactile feedback for key moments — a no-op on platforms without a Taptic Engine.
@MainActor
enum Haptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        SoundManager.shared.play(.buttonTap)
    }
    static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        SoundManager.shared.play(.buttonTap)
    }
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

extension GameStore {
    /// Runs a heavy action behind a loading overlay. The overlay is set,
    /// then a frame is yielded so SwiftUI actually gets to paint the
    /// spinner before the work starts. `action` can be a plain synchronous
    /// closure (it's trivially valid wherever an async one is expected) or
    /// an async one that yields periodically mid-loop — the latter is what
    /// keeps the spinner animating instead of the whole UI freezing solid
    /// for a long sim, since a purely synchronous closure blocks the main
    /// actor for its entire duration in one go once it starts.
    func runHeavy(_ message: String, action: @escaping () async -> Void) {
        busyMessage = message
        isBusy = true
        Task { @MainActor in
            await Task.yield()
            await action()
            isBusy = false
        }
    }
}

/// A full-screen loading overlay shown while a heavy operation runs.
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Retro.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(Retro.accent)
                    .scaleEffect(1.4)
                Text(message.uppercased())
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
            }
            .padding(28)
            .background(Retro.panel.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .transition(.opacity)
    }
}

/// A subtle press-down effect for buttons — the light "give" of a native app control.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

