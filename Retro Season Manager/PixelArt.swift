//
//  PixelArt.swift
//  Retro Season Manager
//
//  The game's "modern retro" art system: literal pixel-grid icons (crisp,
//  grid-aligned blocks rather than smooth vector curves) plus procedural
//  badge, trophy and portrait generators, all built from the Retro brand
//  palette so the whole app reads as one consistent visual language.
//

import SwiftUI

// MARK: - Pixel grid rendering

/// Renders a hand-authored bitmap (each `true` cell = one filled pixel
/// block) as a crisp, grid-aligned shape — literal pixel art rather than
/// smooth curves, matching the game's 16-bit visual language. With
/// `outlineOnly` set, only cells touching an "off" neighbour are drawn,
/// giving a genuine hollow outline computed from the same bitmap rather
/// than needing a second hand-authored version of every icon.
struct PixelBitmap: Shape {
    let grid: [[Bool]]
    var outlineOnly: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rows = grid.count
        guard rows > 0 else { return path }
        let cols = grid.map(\.count).max() ?? 0
        guard cols > 0 else { return path }
        let cellW = rect.width / CGFloat(cols)
        let cellH = rect.height / CGFloat(rows)

        func isOn(_ r: Int, _ c: Int) -> Bool {
            guard r >= 0, r < rows, c >= 0, c < grid[r].count else { return false }
            return grid[r][c]
        }

        for r in 0..<rows {
            for c in 0..<grid[r].count where grid[r][c] {
                if outlineOnly {
                    let isEdge = !isOn(r - 1, c) || !isOn(r + 1, c) || !isOn(r, c - 1) || !isOn(r, c + 1)
                    guard isEdge else { continue }
                }
                let x = rect.minX + CGFloat(c) * cellW
                let y = rect.minY + CGFloat(r) * cellH
                path.addRect(CGRect(x: x, y: y, width: cellW, height: cellH))
            }
        }
        return path
    }

    /// Turns `"X"` / `.` row strings into a bitmap grid — easier to author
    /// and review than nested boolean arrays.
    static func parse(_ rows: [String]) -> [[Bool]] {
        rows.map { row in row.map { $0 == "X" } }
    }
}

// MARK: - Navigation icon pack

/// The game's navigation icon set — one hand-authored 12x12 bitmap per
/// destination, matching `GameSection`.
enum PixelIconKind: String, CaseIterable {
    case home, squad, table, fixtures, search, transfers, inbox, settings

    var grid: [[Bool]] {
        switch self {
        case .home:
            return PixelBitmap.parse([
                "....XX......",
                "...XXXX.....",
                "..XXXXXX....",
                ".XXXXXXXX...",
                ".XXXXXXXXXX.",
                "..XXXXXXXX..",
                "..XXXXXXXX..",
                "..XXXXXXXX..",
                "..XXXXXXXX..",
                "..XXX..XXX..",
                "..XXX..XXX..",
                "..XXX..XXX..",
            ])
        case .squad:
            return PixelBitmap.parse([
                "...XX..XX...",
                "..XXXXXXXX..",
                ".XXXXXXXXXX.",
                "XX.XXXXXX.XX",
                "X..XXXXXX..X",
                "...XXXXXX...",
                "...XXXXXX...",
                "...XXXXXX...",
                "...XXXXXX...",
                "...XXXXXX...",
                "...XXXXXX...",
                "...XXXXXX...",
            ])
        case .table:
            return PixelBitmap.parse([
                "XXXXXXXXXXX.",
                "XXXXXXXXXXX.",
                "............",
                "XXXXXXXXX...",
                "XXXXXXXXX...",
                "............",
                "XXXXXXX.....",
                "XXXXXXX.....",
                "............",
                "XXXXX.......",
                "XXXXX.......",
                "............",
            ])
        case .fixtures:
            return PixelBitmap.parse([
                ".XX......XX.",
                ".XX......XX.",
                "XXXXXXXXXXXX",
                "X..........X",
                "X..........X",
                "X.XX.XX.XX.X",
                "X.XX.XX.XX.X",
                "X..........X",
                "X.XX.XX.XX.X",
                "X.XX.XX.XX.X",
                "X..........X",
                "XXXXXXXXXXXX",
            ])
        case .search:
            return PixelBitmap.parse([
                "...XXXXX....",
                "..XX...XX...",
                ".XX.....XX..",
                ".XX.....XX..",
                ".XX.....XX..",
                ".XX.....XX..",
                "..XX...XX...",
                "...XXXXX.XX.",
                ".........XX.",
                "..........XX",
                "...........X",
                "............",
            ])
        case .transfers:
            return PixelBitmap.parse([
                "...XXXXXX...",
                "..XXXXXXXX..",
                ".XXXXXXXXXX.",
                "XXXXXXXXXXXX",
                "XXXXXXXXXXXX",
                "XXXX.XX.XXXX",
                "XXXX.XX.XXXX",
                "XXXXXXXXXXXX",
                "XXXXXXXXXXXX",
                ".XXXXXXXXXX.",
                "..XXXXXXXX..",
                "...XXXXXX...",
            ])
        case .inbox:
            return PixelBitmap.parse([
                "XXXXXXXXXXXX",
                "X..........X",
                "X.XX....XX.X",
                "X..XX..XX..X",
                "X...XXXX...X",
                "X..........X",
                "X..........X",
                "X..........X",
                "XXXXXXXXXXXX",
                "............",
                "............",
                "............",
            ])
        case .settings:
            return PixelBitmap.parse([
                "...X....X...",
                "..XXX..XXX..",
                "...XXXXXX...",
                ".XXXXXXXXXX.",
                "XXXXXXXXXXXX",
                "XXXXXXXXXXXX",
                "XXXXXXXXXXXX",
                "XXXXXXXXXXXX",
                ".XXXXXXXXXX.",
                "...XXXXXX...",
                "..XXX..XXX..",
                "...X....X...",
            ])
        }
    }
}

/// The visual treatment applied to a `PixelIcon` — one shared bitmap per
/// icon, restyled per state rather than five independently hand-drawn
/// versions, so every icon stays pixel-perfect consistent across states.
enum PixelIconState {
    case filled, outline, active, disabled, selected
}

/// One navigation icon, rendered from its pixel-grid bitmap with the
/// colour/glow treatment for its current state.
struct PixelIcon: View {
    let kind: PixelIconKind
    var state: PixelIconState = .filled
    var size: CGFloat = 24
    /// Overrides the brand emerald for the `.filled`/`.active`/`.selected`
    /// treatments — lets a selected nav icon pick up the manager's chosen
    /// club colour instead of always being plain emerald.
    var tint: Color = Retro.emerald

    var body: some View {
        ZStack {
            if state == .selected {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(
                        LinearGradient(colors: [tint, tint.opacity(0.75)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 1.65, height: size * 1.45)
                    .shadow(color: tint.opacity(0.55), radius: size * 0.22, y: size * 0.05)
            }
            PixelBitmap(grid: kind.grid, outlineOnly: state == .outline)
                .fill(glyphColor)
                .frame(width: size, height: size)
                .shadow(color: glowColor, radius: state == .active ? size * 0.2 : 0)
        }
        .frame(width: size * 1.65, height: size * 1.45)
        .opacity(state == .disabled ? 0.55 : 1)
    }

    private var glyphColor: Color {
        switch state {
        case .filled:   return tint
        case .outline:  return Retro.text.opacity(0.85)
        case .active:   return Retro.gold
        case .disabled: return Retro.text.opacity(0.4)
        case .selected: return Retro.darkGreen
        }
    }

    private var glowColor: Color {
        state == .active ? Retro.gold.opacity(0.75) : .clear
    }
}

// MARK: - Deterministic "randomness" from a name

/// A tiny seeded PRNG so a badge/portrait generated from a club or player
/// name comes out looking the same every time — no extra storage needed,
/// the name itself is the seed.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hasher = Hasher()
        hasher.combine(seed)
        let value = UInt64(bitPattern: Int64(hasher.finalize()))
        state = value == 0 ? 0x9E3779B97F4A7C15 : value
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Club badges

/// A shield outline — rounded shoulders tapering to a point, the classic
/// club-crest silhouette.
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let topCurve = h * 0.16
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topCurve))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY),
                           control: CGPoint(x: rect.minX, y: rect.minY - h * 0.02))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topCurve),
                           control: CGPoint(x: rect.maxX, y: rect.minY - h * 0.02))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.55))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.maxY),
                           control: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.88))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.55),
                           control: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.88))
        path.closeSubpath()
        return path
    }
}

/// A 5-point star.
struct StarShape: Shape {
    var points: Int = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        let step = Double.pi / Double(points)
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Double(i) * step - .pi / 2
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                 y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// Renders one of a curated pool of real crest artwork images
/// (`Assets.xcassets/Badges/ClubBadge01`...`ClubBadge24`), picked
/// deterministically from the club's name so the same club always shows
/// the same badge — the same "same seed, same result" principle the
/// procedural generator this replaced used, just against real artwork
/// instead of drawn shapes. With only 24 source badges against a much
/// larger roster of clubs (80 across Career Mode's four divisions alone),
/// clubs necessarily repeat a badge sometimes — acceptable for a first
/// pass; a larger badge pool or a player-facing picker would remove the
/// repetition later. `shortName`/`primaryColor` stay on the signature for
/// source compatibility with existing call sites but no longer drive the
/// rendering, since the artwork's colors and lettering are fixed.
struct ClubBadgeView: View {
    let name: String
    let shortName: String
    let size: CGFloat
    var primaryColor: Color = Retro.emerald

    private static let badgeCount = 24

    private var badgeIndex: Int {
        var gen = SeededGenerator(seed: name)
        return Int.random(in: 1...Self.badgeCount, using: &gen)
    }

    var body: some View {
        Image("ClubBadge\(String(format: "%02d", badgeIndex))")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: size * 0.08, y: size * 0.03)
    }
}

/// Type-erases a `Shape` so `ClubBadgeView` can pick between `Circle` and
/// `ShieldShape` in one `@ViewBuilder` switch.
struct AnyShape: Shape {
    private nonisolated(unsafe) let pathBuilder: (CGRect) -> Path
    init(_ shape: some Shape) { pathBuilder = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { pathBuilder(rect) }
}

// MARK: - Trophies

/// A classic chalice-shaped trophy: wide bowl, stem, footed base.
struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let bowlBottom = rect.minY + h * 0.5
        path.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.08, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.62, y: bowlBottom))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.38, y: bowlBottom))
        path.closeSubpath()
        let stemW = w * 0.14
        path.addRect(CGRect(x: rect.midX - stemW / 2, y: bowlBottom, width: stemW, height: h * 0.28))
        let baseY = bowlBottom + h * 0.28
        path.addRoundedRect(in: CGRect(x: rect.midX - w * 0.28, y: baseY, width: w * 0.56, height: h * 0.14),
                             cornerSize: CGSize(width: 3, height: 3))
        return path
    }
}

/// A simplified football-boot silhouette for the Golden Boot.
struct BootShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.45, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.16))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.6, y: rect.minY + h * 0.5))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.64))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A simplified goalkeeper-glove silhouette for the Golden Glove.
struct GloveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + h * 0.15, width: w * 0.7, height: h * 0.75),
                             cornerSize: CGSize(width: w * 0.2, height: w * 0.2))
        path.move(to: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.35))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.25))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.55))
        path.closeSubpath()
        return path
    }
}

/// Which physical shape a trophy is drawn as — several named honours
/// share the same real-world silhouette (most cups look like cups).
enum TrophySilhouette { case cup, shield, boot, glove, star }

/// Every named honour in the game, mapped to the silhouette it's drawn
/// with.
enum TrophyKind {
    case league, cup, champions, europa, world
    case managerAward, managerOfMonth, youthAward
    case goldenBoot, goldenGlove, playerOfYear

    var silhouette: TrophySilhouette {
        switch self {
        case .league, .cup, .champions, .europa, .world: return .cup
        case .managerAward, .managerOfMonth, .youthAward: return .shield
        case .goldenBoot: return .boot
        case .goldenGlove: return .glove
        case .playerOfYear: return .star
        }
    }

    /// Best-effort mapping from a free-text honours-log line (this game
    /// logs honours as plain strings, e.g. "🏆 Premier League title
    /// (2001/02)") to the trophy it represents, so existing text lists can
    /// gain a matching icon without changing how honours are stored.
    static func guess(from text: String) -> (kind: TrophyKind, tier: TrophyTier)? {
        let lower = text.lowercased()
        if lower.contains("golden boot") { return (.goldenBoot, .silver) }
        if lower.contains("golden glove") { return (.goldenGlove, .silver) }
        if lower.contains("player of the") { return (.playerOfYear, .silver) }
        if lower.contains("manager of the month") { return (.managerOfMonth, .bronze) }
        if lower.contains("young player") || lower.contains("youth") { return (.youthAward, .bronze) }
        if lower.contains("world") { return (.world, .premium) }
        if lower.contains("champions") { return (.champions, .premium) }
        if lower.contains("europa") || lower.contains("uefa") { return (.europa, .gold) }
        if lower.contains("cup") || lower.contains("shield") { return (.cup, .gold) }
        if lower.contains("title") || lower.contains("champion") { return (.league, .premium) }
        return nil
    }
}

/// The metallic finish a trophy is rendered in — `.premium` is reserved
/// for a career's biggest honours (league/continental/world titles) and
/// adds an emerald-gold two-tone glow on top of gold.
enum TrophyTier {
    case bronze, silver, gold, premium

    var colors: [Color] {
        switch self {
        case .bronze:  return [Retro.bronze, Retro.bronze.opacity(0.65)]
        case .silver:  return [Retro.silver, Retro.silver.opacity(0.65)]
        case .gold:    return [Retro.gold, Retro.gold.opacity(0.65)]
        case .premium: return [Retro.gold, Retro.emerald]
        }
    }
}

/// A career milestone the manager can unlock — distinct from the honours
/// log (`careerHonours`), which just lists what was won; these are
/// specific, sometimes harder-to-spot feats (an unbeaten season, a round
/// number of wins) worth calling out and collecting.
enum AchievementKind: String, CaseIterable, Codable, Identifiable {
    case promotion = "Promotion"
    case leagueTitle = "League Winner"
    case cupWinner = "Cup Winner"
    case europeanGlory = "European Glory"
    case treble = "Treble Winner"
    case invincible = "Invincible"
    case wins50 = "50 Wins"
    case wins100 = "100 Wins"
    case wins200 = "200 Wins"
    case dynasty = "Dynasty"
    case giantKiller = "Giant Killer"
    case youthRevolution = "Youth Revolution"
    case transferGenius = "Transfer Genius"
    case underdog = "Underdog"
    case greatEscape = "Great Escape"
    case matches1000 = "1000 Matches"
    case legendaryManager = "Legendary Manager"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .promotion:        return "Win promotion to a higher division."
        case .leagueTitle:      return "Win the league title."
        case .cupWinner:        return "Win a domestic cup."
        case .europeanGlory:    return "Win a European trophy."
        case .treble:           return "Win the league, a cup and Europe in the same season."
        case .invincible:       return "Go through an entire league season unbeaten."
        case .wins50:           return "Win 50 matches as a manager."
        case .wins100:          return "Win 100 matches as a manager."
        case .wins200:          return "Win 200 matches as a manager."
        case .dynasty:          return "Manage the same club for 10 seasons."
        case .giantKiller:      return "Beat a club far above your station three times in a career."
        case .youthRevolution:  return "Give five academy graduates real first-team minutes in one season."
        case .transferGenius:   return "Turn a profit on five separate transfer sales."
        case .underdog:         return "Win a major trophy as one of the least fancied clubs in your division."
        case .greatEscape:      return "Survive relegation by the barest of margins."
        case .matches1000:      return "Take charge of 1,000 matches as a manager."
        case .legendaryManager: return "Build a managerial career worthy of legend."
        }
    }

    /// The bigger, punchier headline used on the unlock celebration and
    /// the history page — distinct from the shorter grid label above.
    var flavorTitle: String {
        switch self {
        case .promotion:        return "PROMOTION!"
        case .leagueTitle:      return "CHAMPIONS!"
        case .cupWinner:        return "CUP WINNERS!"
        case .europeanGlory:    return "EUROPEAN GLORY!"
        case .treble:           return "TREBLE WINNERS!"
        case .invincible:       return "THE INVINCIBLES"
        case .wins50:           return "50 WINS"
        case .wins100:          return "CENTURY OF WINS"
        case .wins200:          return "200 WINS"
        case .dynasty:          return "A DYNASTY"
        case .giantKiller:      return "THE GIANT KILLER"
        case .youthRevolution:  return "YOUTH REVOLUTION"
        case .transferGenius:   return "TRANSFER GENIUS"
        case .underdog:         return "THE UNDERDOG"
        case .greatEscape:      return "THE GREAT ESCAPE"
        case .matches1000:      return "1,000 MATCHES"
        case .legendaryManager: return "LEGENDARY MANAGER"
        }
    }

    /// Career points banked the moment this is first unlocked — scaled
    /// roughly by how hard it is to earn.
    var points: Int {
        switch self {
        case .promotion:        return 100
        case .leagueTitle:      return 300
        case .cupWinner:        return 200
        case .europeanGlory:    return 350
        case .treble:           return 500
        case .invincible:       return 400
        case .wins50:           return 50
        case .wins100:          return 100
        case .wins200:          return 200
        case .dynasty:          return 300
        case .giantKiller:      return 150
        case .youthRevolution:  return 200
        case .transferGenius:   return 250
        case .underdog:         return 250
        case .greatEscape:      return 200
        case .matches1000:      return 300
        case .legendaryManager: return 500
        }
    }

    var category: AchievementCategory {
        switch self {
        case .promotion, .leagueTitle, .cupWinner, .europeanGlory, .treble:
            return .trophies
        case .invincible, .underdog, .greatEscape, .giantKiller:
            return .character
        case .wins50, .wins100, .wins200, .matches1000:
            return .milestones
        case .dynasty, .youthRevolution, .transferGenius, .legendaryManager:
            return .legacy
        }
    }

    var trophy: (kind: TrophyKind, tier: TrophyTier) {
        switch self {
        case .promotion:        return (.league, .bronze)
        case .leagueTitle:      return (.league, .premium)
        case .cupWinner:        return (.cup, .gold)
        case .europeanGlory:    return (.europa, .premium)
        case .treble:           return (.champions, .premium)
        case .invincible:       return (.playerOfYear, .premium)
        case .wins50:           return (.managerAward, .bronze)
        case .wins100:          return (.managerAward, .silver)
        case .wins200:          return (.managerAward, .gold)
        case .dynasty:          return (.managerOfMonth, .gold)
        case .giantKiller:      return (.cup, .silver)
        case .youthRevolution:  return (.youthAward, .gold)
        case .transferGenius:   return (.managerAward, .silver)
        case .underdog:         return (.cup, .premium)
        case .greatEscape:      return (.league, .bronze)
        case .matches1000:      return (.managerAward, .premium)
        case .legendaryManager: return (.managerOfMonth, .premium)
        }
    }
}

/// Groups achievements into sections on the gallery screen.
enum AchievementCategory: String, CaseIterable, Codable {
    case trophies = "Trophies"
    case character = "Character"
    case milestones = "Milestones"
    case legacy = "Legacy"
}

/// The rich record of one achievement's unlock — when, and the story
/// behind it — kept alongside the bare `unlockedAchievements` set so the
/// gallery's history page has something to actually show.
struct AchievementUnlock: Codable, Identifiable {
    var id: AchievementKind { kind }
    let kind: AchievementKind
    let season: Int
    let date: Date
    let context: String
}

/// One pixel-art trophy, in its tier's metallic finish.
struct TrophyView: View {
    let kind: TrophyKind
    var tier: TrophyTier = .gold
    var size: CGFloat = 40

    var body: some View {
        glyph
            .fill(LinearGradient(colors: tier.colors, startPoint: .top, endPoint: .bottom))
            .overlay(glyph.stroke(Color.white.opacity(0.35), lineWidth: max(0.5, size * 0.02)))
            .frame(width: size, height: size)
            .shadow(color: tier.colors[0].opacity(0.6), radius: tier == .premium ? size * 0.22 : size * 0.1, y: size * 0.03)
    }

    private var glyph: AnyShape {
        switch kind.silhouette {
        case .cup:    return AnyShape(CupShape())
        case .shield: return AnyShape(ShieldShape())
        case .boot:   return AnyShape(BootShape())
        case .glove:  return AnyShape(GloveShape())
        case .star:   return AnyShape(StarShape())
        }
    }
}

/// Renders a trophy icon next to a free-text honours line when one can be
/// guessed from the text, falling back to plain text otherwise — a small
/// drop-in upgrade for the honours/CV lists that already store trophies
/// as strings.
struct HonourRow: View {
    let text: String
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            if let guess = TrophyKind.guess(from: text) {
                TrophyView(kind: guess.kind, tier: guess.tier, size: size)
            }
            Text(text)
        }
    }
}

// MARK: - Player portraits

/// A procedurally generated player headshot — skin tone, hair, beard and
/// expression are all picked deterministically from the player's name (and
/// nudged by age, where known), so every player looks distinct and stable
/// across launches without storing a single image. Deliberately geometric
/// rather than photoreal — flat colour, hard edges, no shading gradients on
/// the face itself — to sit comfortably next to the game's pixel-icon
/// system instead of reading as a different, softer art style.
/// A circular player headshot: one of a curated pool of real portrait
/// photos (`Assets.xcassets/Portraits/Portrait01`...`Portrait66`), picked
/// deterministically from the player's name — the same "same seed, same
/// result" principle `ClubBadgeView` uses for real crest artwork. With
/// only 66 source photos against a Career Mode roster that can run into
/// the thousands, the same photo repeats often (roughly every ~25
/// players) — accepted for now as a starter set; a larger portrait pool
/// would reduce the repetition later without any other change here.
/// `age` stays on the signature for source compatibility with existing
/// call sites but no longer drives anything, since a real photo can't be
/// aged up or down the way the procedural generator it replaced could.
///
/// The pick isn't uniformly random across all 66, though — see
/// `tonePool` below for why, and `PlayerPortraitView.ToneOverrides.swift`-
/// adjacent tables further down this file for the actual data.
struct PlayerPortraitView: View {
    let name: String
    var position: Position? = nil
    var age: Int? = nil
    /// A real-world nationality string, when the caller has one on hand
    /// (`Player.nationality`, `LegendsCard.nation`, `ClubLegend.nationality`)
    /// — biases which skin-tone bucket of the 66 portraits this player's
    /// face is drawn from. Optional and additive: omitting it just falls
    /// back to the unbucketed full pool, exactly like before this existed.
    var nation: String? = nil
    var size: CGFloat = 40

    private static let portraitCount = 66

    /// Which skin-tone bucket a player's portrait should be drawn from,
    /// and why: Legends' card names are deliberate parodies of specific,
    /// identifiable real footballers ("L. Miessi" → Messi, "K. Mbappa" →
    /// Mbappé) — `PortraitTone.nameOverrides` matches on the *exact*
    /// display name for the ones where the real person's own appearance
    /// is well known, since a nation-level guess isn't good enough there
    /// (a France-default bucket would put a Mbappé/Kanté/Vieira/Varane/
    /// Desailly parody on the wrong-toned face). Career Mode's players
    /// are generated, not parodies of anyone real, so for them (and any
    /// Legends name not in the override list) this only ever reaches
    /// `PortraitTone.nationDefaults` — a plausibility default bucketed by
    /// nation, not a claim about any specific individual.
    private var tonePool: [Int] {
        if let override = PortraitTone.nameOverrides[name] { return override }
        if let nation, let byNation = PortraitTone.nationDefaults[nation] { return byNation }
        return Array(1...Self.portraitCount)
    }

    private var portraitIndex: Int {
        var gen = SeededGenerator(seed: name)
        let pool = tonePool
        return pool.randomElement(using: &gen) ?? Int.random(in: 1...Self.portraitCount, using: &gen)
    }

    private var accentColor: Color {
        switch position {
        case .goalkeeper: return Color(red: 0.85, green: 0.65, blue: 0.25)
        case .defender:   return Color(red: 0.35, green: 0.55, blue: 0.85)
        case .midfielder: return Retro.emerald
        case .forward:    return Color(red: 0.85, green: 0.35, blue: 0.4)
        case nil:         return Retro.text.opacity(0.5)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [accentColor.opacity(0.35), accentColor.opacity(0.1)],
                                      center: .center, startRadius: 0, endRadius: size * 0.6))
            Image("Portrait\(String(format: "%02d", portraitIndex))")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size * 0.82, height: size * 0.82)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .frame(width: size, height: size)
    }
}

/// The skin-tone buckets `PlayerPortraitView.tonePool` draws from — the
/// 66 source photos sorted once, by eye, into three broad tone groups,
/// plus the two tables (per-nation default, per-name override) that
/// decide which bucket a given player pulls from. Kept as one small,
/// clearly-labelled place so the judgment calls involved (which bucket a
/// person or nation gets) are easy to find and revise, rather than
/// scattered through `PlayerPortraitView` itself.
private enum PortraitTone {
    static let light = [6, 9, 12, 14, 15, 18, 22, 25, 27, 30, 35, 36, 42, 46, 53, 57, 64]
    static let medium = [2, 5, 7, 8, 13, 17, 19, 20, 26, 28, 31, 32, 33, 34, 39, 43, 47, 48, 50, 51, 52, 54, 56, 58, 59, 60, 61, 62, 63, 65, 66]
    static let dark = [1, 3, 4, 10, 11, 16, 21, 23, 24, 29, 37, 38, 40, 41, 44, 45, 49, 55]

    /// A plausibility default per nation — not a claim about any one
    /// person, just the bucket a generated (not-a-real-person) Career
    /// Mode player from that nation most often lands in. Every nation
    /// appearing in `LegendsCardDatabase` or Career Mode's
    /// `nationalityPool`/`randomNationality` is covered.
    static let nationDefaults: [String: [Int]] = [
        "Argentina": light, "Austria": light, "Belgium": light, "Brazil": medium,
        "Canada": light, "Croatia": light, "Czech Republic": light, "Denmark": light,
        "England": light, "France": light, "Germany": light,
        "Republic of Ireland": light, "Italy": light, "Ivory Coast": dark, "Netherlands": light,
        "Nigeria": dark, "Northern Ireland": light, "Norway": light, "Poland": light,
        "Portugal": light, "Romania": light, "Scotland": light, "Slovenia": light,
        "Spain": light, "Sweden": light, "Wales": light,
    ]

    /// Legends' card names are deliberate parodies of specific, real,
    /// identifiable footballers — this is the subset where the nation
    /// default above would put a well-known real person's face on the
    /// wrong tone entirely (mostly Black players from squads whose
    /// nation-default above skews light, going by the rest of that
    /// nation's roster in this card set). Not exhaustive — only the
    /// cases confidently identifiable from the name/nation/era on the
    /// card, and only where getting it wrong would actually show.
    static let nameOverrides: [String: [Int]] = [
        "A. Davison": dark,     // Alphonso Davies
        "C. Seedorfino": dark,  // Clarence Seedorf
        "D. Alvarinho": dark,   // Dani Alves
        "E. Nascimento": dark,  // Pelé
        "K. Mbappa": dark,      // Kylian Mbappé
        "M. Desaille": dark,    // Marcel Desailly
        "N. Kantay": dark,      // N'Golo Kanté
        "P. Vieirama": dark,    // Patrick Vieira
        "R. Carlosao": dark,    // Roberto Carlos
        "R. Riveraldo": dark,   // Rivaldo
        "R. Varanova": dark,    // Raphaël Varane
        "T. Alabana": dark,     // David Alaba
        "T. Walkerino": dark,   // Kyle Walker
        "V. Dijkerman": dark,   // Virgil van Dijk
        "V. Junior": dark,      // Vinícius Júnior
    ]
}
