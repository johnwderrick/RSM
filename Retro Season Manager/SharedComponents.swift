//
//  SharedComponents.swift
//  Retro Season Manager
//
//  Small, reusable presentational views shared across many screens.
//

import SwiftUI

// MARK: - Reusable pieces

/// A themed "are you sure" screen for any hard-to-reverse action — release,
/// loan out, anything that shouldn't be one accidental tap away. Styled to
/// match the rest of the app rather than a plain system alert.
struct ConfirmActionSheet: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                Text(title)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Button {
                        Haptics.warning()
                        onConfirm()
                    } label: {
                        Text(confirmLabel)
                            .font(.system(.headline, design: .monospaced).bold())
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.9, green: 0.35, blue: 0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }
}

/// One attribute row: name, value and a coloured 1...20 bar.
struct AttributeBar: View {
    let name: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Retro.text.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 20)
                }
            }
            .frame(height: 6)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 20, alignment: .trailing)
        }
    }

    private var color: Color {
        switch value {
        case 15...: return Retro.accent
        case 10..<15: return Retro.highlight
        default: return Retro.text.opacity(0.6)
        }
    }
}

/// A simple crest: the club's short name inside a rounded badge.
/// A circular initials "headshot" for a player — no real portraits exist
/// in this game, so a coloured monogram (tinted by position, like a strip
/// colour) stands in for one anywhere a player card is shown.
struct PlayerAvatarView: View {
    let name: String
    let position: Position?
    let size: CGFloat
    var age: Int? = nil

    var body: some View {
        PlayerPortraitView(name: name, position: position, age: age, size: size)
    }
}

struct CrestView: View {
    let shortName: String
    let size: CGFloat
    var color: Color = Retro.accent

    var body: some View {
        ClubBadgeView(name: shortName, shortName: shortName, size: size, primaryColor: color)
    }
}

/// A row of filled/empty stars for a club's rating.
struct StarRatingView: View {
    let stars: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= stars ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(Retro.highlight)
            }
        }
    }
}

/// A player's overall ability as a plain numeric reading, coloured by
/// tier — used everywhere a player's rating is shown.
struct OverallRatingView: View {
    let rating: Int

    var body: some View {
        Text("\(rating)")
            .font(.system(.callout, design: .monospaced).bold())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch rating {
        case 85...:   return Retro.highlight
        case 75..<85: return Retro.accent
        case 65..<75: return Color(red: 0.55, green: 0.70, blue: 0.95)
        default:      return Retro.text
        }
    }
}

/// A row of coloured W/D/L boxes showing recent form.
struct FormView: View {
    let outcomes: [MatchOutcome]

    var body: some View {
        HStack(spacing: 3) {
            if outcomes.isEmpty {
                Text("No games played yet")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            } else {
                ForEach(Array(outcomes.enumerated()), id: \.offset) { _, outcome in
                    Text(outcome.letter)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(color(for: outcome))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func color(for outcome: MatchOutcome) -> Color {
        switch outcome {
        case .win:  return Color(red: 0.20, green: 0.65, blue: 0.25)
        case .draw: return Color(red: 0.45, green: 0.45, blue: 0.45)
        case .loss: return Color(red: 0.75, green: 0.20, blue: 0.20)
        }
    }
}

// MARK: - Shared panel container

/// A titled, rounded panel used throughout the retro UI.
struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Retro.accent.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
    }
}

// MARK: - Generic match flash

/// A match moment worth a quick full-screen flash that doesn't have (or
/// doesn't need) dedicated bundled art — unlike the goal/penalty/red-card
/// flashes, which use real sliced photos, these use a solid colour field,
/// bold text and existing procedural glyphs. Add a case here and it's
/// immediately usable via `MatchFlashOverlay` and `triggerEventFlash` —
/// no new art required, though a case can always graduate to real art
/// later without changing any call site.
enum MatchFlashKind {
    case halfTime(homeShort: String, homeGoals: Int, awayGoals: Int, awayShort: String)
    case injury(playerName: String)
    case playerOfTheMatch(name: String)
    case yellowCard(playerName: String)
    case substitution(offName: String, onName: String)
    case promotion(clubName: String)
    case champions(clubName: String)

    var headline: String {
        switch self {
        case .halfTime:         return "HALF TIME"
        case .injury:           return "INJURY"
        case .playerOfTheMatch: return "MAN OF THE MATCH"
        case .yellowCard:       return "YELLOW CARD"
        case .substitution:     return "SUBSTITUTION"
        case .promotion:        return "PROMOTED!"
        case .champions:        return "CHAMPIONS!"
        }
    }

    var subtext: String {
        switch self {
        case .halfTime(let home, let homeGoals, let awayGoals, let away): return "\(home) \(homeGoals)-\(awayGoals) \(away)"
        case .injury(let name): return name
        case .playerOfTheMatch(let name): return name
        case .yellowCard(let name): return name
        case .substitution(let off, let on): return "\(on) replaces \(off)"
        case .promotion(let clubName): return "\(clubName) go up!"
        case .champions(let clubName): return "\(clubName) are champions!"
        }
    }

    var glyph: String {
        switch self {
        case .halfTime:         return "⏸"
        case .injury:           return "💥"
        case .playerOfTheMatch: return "⭐"
        case .yellowCard:       return "🟨"
        case .substitution:     return "🔄"
        case .promotion:        return "⬆︎"
        case .champions:        return "🏆"
        }
    }

    var color: Color {
        switch self {
        case .halfTime:         return Retro.accent
        case .injury:           return Color(red: 0.95, green: 0.55, blue: 0.35)
        case .playerOfTheMatch: return Retro.gold
        case .yellowCard:       return Color(red: 0.9, green: 0.78, blue: 0.15)
        case .substitution:     return Retro.royalBlue
        case .promotion:        return Retro.accent
        case .champions:        return Retro.gold
        }
    }

    /// Whether this moment deserves the full broadcast treatment — screen
    /// shake, crowd confetti, and a longer hold — versus a quick, quiet
    /// lower-third-style flash.
    var isCelebratory: Bool {
        switch self {
        case .promotion, .champions: return true
        default: return false
        }
    }
}

/// The stylized counterpart to the photo-backed goal/penalty/red-card
/// flashes — same quick, punchy CRT-broadcast timing, driven purely by
/// colour and type since no source art exists for these moments.
struct MatchFlashOverlay: View {
    let kind: MatchFlashKind
    @State private var popped = false
    @State private var flickerOn = true

    var body: some View {
        ZStack {
            kind.color.opacity(flickerOn ? 0.88 : 0.94).ignoresSafeArea()
            VStack(spacing: 8) {
                Text(kind.glyph)
                    .font(.system(size: kind.isCelebratory ? 84 : 64))
                Text(kind.headline)
                    .font(.system(size: kind.isCelebratory ? 56 : 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                Text(kind.subtext)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .scaleEffect(popped ? 1.0 : 0.6)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .onAppear {
            // A quick channel-flicker before settling, like an old TV
            // broadcast cutting to a graphic — then a pixel-sprite pop-in.
            withAnimation(.easeInOut(duration: 0.05).repeatCount(3, autoreverses: true)) {
                flickerOn.toggle()
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                popped = true
            }
        }
    }
}

