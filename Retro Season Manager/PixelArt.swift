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

/// A simple 3-pointed crown.
struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.45))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.2, y: rect.minY + h * 0.7))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.8, y: rect.minY + h * 0.7))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.45))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
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

/// A single laurel leaf, curving away from the stem — two mirrored copies
/// either side of a badge form the classic laurel-wreath charge.
struct LaurelLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                           control: CGPoint(x: rect.maxX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                           control: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private enum BadgeShapeKind: CaseIterable { case circle, shield }
private enum BadgePattern: CaseIterable { case solid, halvedVertical, halvedDiagonal, stripes, quartered }
private enum BadgeCharge: CaseIterable { case initials, star, crown, laurel, chevron }

/// A procedurally generated club crest: shape, colour pattern and central
/// charge are all picked deterministically from the club's name, so the
/// same club always renders the same badge and the whole roster of clubs
/// reads as hundreds of distinct-but-related crests from one system
/// instead of hand-drawn one-offs. `primaryColor` is caller-supplied (club
/// branding elsewhere in the app) — everything else grows from the seed.
struct ClubBadgeView: View {
    let name: String
    let shortName: String
    let size: CGFloat
    var primaryColor: Color = Retro.emerald

    private var seed: SeededGenerator { SeededGenerator(seed: name) }

    private var shapeKind: BadgeShapeKind {
        var gen = seed
        return BadgeShapeKind.allCases.randomElement(using: &gen) ?? .circle
    }

    private var pattern: BadgePattern {
        var gen = seed
        _ = gen.next()
        return BadgePattern.allCases.randomElement(using: &gen) ?? .solid
    }

    private var charge: BadgeCharge {
        var gen = seed
        _ = gen.next(); _ = gen.next()
        return BadgeCharge.allCases.randomElement(using: &gen) ?? .initials
    }

    private var secondaryColor: Color {
        var gen = seed
        _ = gen.next(); _ = gen.next(); _ = gen.next()
        let options: [Color] = [Retro.gold, Retro.darkGreen, Retro.pureWhite, Retro.royalBlue]
        return options.randomElement(using: &gen) ?? Retro.gold
    }

    var body: some View {
        ZStack {
            base
            chargeView
        }
        .frame(width: size, height: size)
        .overlay(outline)
        .shadow(color: primaryColor.opacity(0.5), radius: size * 0.1, y: size * 0.04)
    }

    @ViewBuilder
    private var base: some View {
        switch pattern {
        case .solid:
            clip(LinearGradient(colors: [primaryColor, primaryColor.opacity(0.7)], startPoint: .top, endPoint: .bottom))
        case .halvedVertical:
            clip(HStack(spacing: 0) {
                Rectangle().fill(primaryColor)
                Rectangle().fill(secondaryColor)
            })
        case .halvedDiagonal:
            clip(ZStack {
                Rectangle().fill(primaryColor)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size))
                    path.addLine(to: CGPoint(x: size, y: 0))
                    path.addLine(to: CGPoint(x: size, y: size))
                    path.closeSubpath()
                }
                .fill(secondaryColor)
            })
        case .stripes:
            clip(HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle().fill(i.isMultiple(of: 2) ? primaryColor : secondaryColor)
                }
            })
        case .quartered:
            clip(VStack(spacing: 0) {
                HStack(spacing: 0) { Rectangle().fill(primaryColor); Rectangle().fill(secondaryColor) }
                HStack(spacing: 0) { Rectangle().fill(secondaryColor); Rectangle().fill(primaryColor) }
            })
        }
    }

    private func clip(_ content: some View) -> some View {
        content.clipShape(badgeShape)
    }

    private var badgeShape: AnyShape {
        switch shapeKind {
        case .circle: return AnyShape(Circle())
        case .shield: return AnyShape(ShieldShape())
        }
    }

    @ViewBuilder
    private var outline: some View {
        switch shapeKind {
        case .circle: Circle().stroke(chargeTint.opacity(0.55), lineWidth: max(1, size * 0.025))
        case .shield: ShieldShape().stroke(chargeTint.opacity(0.55), lineWidth: max(1, size * 0.025))
        }
    }

    /// The charge (initials/star/crown/laurel) is always drawn in
    /// whichever of primary/secondary reads better against the base, so
    /// it's never invisible on a same-tone background.
    private var chargeTint: Color {
        pattern == .solid ? Retro.pureWhite : secondaryColor
    }

    @ViewBuilder
    private var chargeView: some View {
        switch charge {
        case .initials:
            Text(shortName)
                .font(.system(size: size * 0.34, weight: .bold, design: .monospaced))
                .foregroundStyle(chargeTint)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        case .star:
            StarShape()
                .fill(chargeTint)
                .frame(width: size * 0.44, height: size * 0.44)
        case .crown:
            CrownShape()
                .fill(chargeTint)
                .frame(width: size * 0.5, height: size * 0.36)
                .offset(y: -size * 0.02)
        case .laurel:
            HStack(spacing: size * 0.28) {
                LaurelLeafShape().fill(chargeTint).frame(width: size * 0.16, height: size * 0.5)
                    .rotationEffect(.degrees(-18))
                LaurelLeafShape().fill(chargeTint).frame(width: size * 0.16, height: size * 0.5)
                    .rotationEffect(.degrees(18))
                    .scaleEffect(x: -1, y: 1)
            }
        case .chevron:
            Path { path in
                let w = size * 0.5, h = size * 0.32
                path.move(to: CGPoint(x: -w / 2, y: -h / 2))
                path.addLine(to: CGPoint(x: 0, y: h / 2))
                path.addLine(to: CGPoint(x: w / 2, y: -h / 2))
            }
            .stroke(chargeTint, style: StrokeStyle(lineWidth: max(2, size * 0.06), lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.5, height: size * 0.32)
        }
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

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .promotion:     return "Win promotion to a higher division."
        case .leagueTitle:   return "Win the league title."
        case .cupWinner:     return "Win a domestic cup."
        case .europeanGlory: return "Win a European trophy."
        case .treble:        return "Win the league, a cup and Europe in the same season."
        case .invincible:    return "Go through an entire league season unbeaten."
        case .wins50:        return "Win 50 matches as a manager."
        case .wins100:       return "Win 100 matches as a manager."
        case .wins200:       return "Win 200 matches as a manager."
        case .dynasty:       return "Manage the same club for 10 seasons."
        }
    }

    var trophy: (kind: TrophyKind, tier: TrophyTier) {
        switch self {
        case .promotion:     return (.league, .bronze)
        case .leagueTitle:   return (.league, .premium)
        case .cupWinner:     return (.cup, .gold)
        case .europeanGlory: return (.europa, .premium)
        case .treble:        return (.champions, .premium)
        case .invincible:    return (.playerOfYear, .premium)
        case .wins50:        return (.managerAward, .bronze)
        case .wins100:       return (.managerAward, .silver)
        case .wins200:       return (.managerAward, .gold)
        case .dynasty:       return (.managerOfMonth, .gold)
        }
    }
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
struct PlayerPortraitView: View {
    let name: String
    var position: Position? = nil
    var age: Int? = nil
    var size: CGFloat = 40

    private var seed: SeededGenerator { SeededGenerator(seed: name) }
    private var isVeteran: Bool { (age ?? 25) >= 31 }
    private var isYouth: Bool { (age ?? 25) <= 20 }

    private static let skinTones: [Color] = [
        Color(red: 0.94, green: 0.80, blue: 0.69),
        Color(red: 0.87, green: 0.68, blue: 0.53),
        Color(red: 0.76, green: 0.57, blue: 0.42),
        Color(red: 0.55, green: 0.38, blue: 0.27),
        Color(red: 0.35, green: 0.23, blue: 0.16),
    ]
    private static let hairTones: [Color] = [
        Color(red: 0.08, green: 0.07, blue: 0.07),
        Color(red: 0.25, green: 0.16, blue: 0.10),
        Color(red: 0.40, green: 0.27, blue: 0.15),
        Color(red: 0.80, green: 0.68, blue: 0.40),
        Color(red: 0.72, green: 0.35, blue: 0.18),
    ]
    private static let greyTones: [Color] = [
        Color(red: 0.65, green: 0.65, blue: 0.65),
        Color(red: 0.78, green: 0.78, blue: 0.78),
        Color(red: 0.25, green: 0.16, blue: 0.10),
    ]

    private var skinTone: Color {
        var gen = seed
        return Self.skinTones.randomElement(using: &gen) ?? Self.skinTones[0]
    }

    private var hairTone: Color {
        var gen = seed
        _ = gen.next()
        let pool = isVeteran ? Self.greyTones : Self.hairTones
        return pool.randomElement(using: &gen) ?? pool[0]
    }

    private var hairStyle: Int {
        var gen = seed
        _ = gen.next(); _ = gen.next()
        return Int.random(in: 0...3, using: &gen)
    }

    private var hasBeard: Bool {
        guard !isYouth else { return false }
        var gen = seed
        _ = gen.next(); _ = gen.next(); _ = gen.next()
        return Double.random(in: 0..<1, using: &gen) < (isVeteran ? 0.55 : 0.3)
    }

    private var browAngle: Double {
        var gen = seed
        _ = gen.next(); _ = gen.next(); _ = gen.next(); _ = gen.next()
        return [-8.0, 0.0, 10.0].randomElement(using: &gen) ?? 0
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
            hairBackdrop
            ZStack {
                Circle().fill(skinTone)
                HStack(spacing: size * 0.14) {
                    Capsule().fill(hairTone).frame(width: size * 0.14, height: size * 0.035)
                        .rotationEffect(.degrees(browAngle))
                    Capsule().fill(hairTone).frame(width: size * 0.14, height: size * 0.035)
                        .rotationEffect(.degrees(-browAngle))
                }
                .offset(y: -size * 0.05)
                HStack(spacing: size * 0.18) {
                    Circle().fill(Color.black.opacity(0.75)).frame(width: size * 0.07, height: size * 0.07)
                    Circle().fill(Color.black.opacity(0.75)).frame(width: size * 0.07, height: size * 0.07)
                }
                .offset(y: size * 0.02)
                if hasBeard {
                    Ellipse()
                        .fill(hairTone.opacity(0.92))
                        .frame(width: size * 0.5, height: size * 0.22)
                        .offset(y: size * 0.3)
                }
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: size * 0.2, height: size * 0.03)
                    .offset(y: size * 0.18)
            }
            .frame(width: size * 0.82, height: size * 0.82)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1).frame(width: size * 0.82, height: size * 0.82))
        }
        .frame(width: size, height: size)
    }

    /// Drawn behind the (clipped, circular) head, so only the portion that
    /// pokes out beyond the head's edge reads as visible hair — a bald or
    /// short style barely peeks above the hairline, a fuller style shows
    /// as a band or ring around the head.
    @ViewBuilder
    private var hairBackdrop: some View {
        switch hairStyle {
        case 0:
            EmptyView()
        case 1:
            Circle().fill(hairTone).frame(width: size * 0.7, height: size * 0.5).offset(y: -size * 0.22)
        case 2:
            Circle().fill(hairTone).frame(width: size * 0.95, height: size * 0.95).offset(y: -size * 0.02)
        default:
            Circle().fill(hairTone).frame(width: size * 0.88, height: size * 0.62).offset(y: -size * 0.18)
        }
    }
}
