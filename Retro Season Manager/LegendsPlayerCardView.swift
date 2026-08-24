import SwiftUI

enum LegendsPlayerCardVariant {
    case compact
    case grid
    case reveal
    case hero
}

struct LegendsPlayerCardView: View {
    let store: LegendsStore
    let card: LegendsCard
    var variant: LegendsPlayerCardVariant = .grid
    var isSelected: Bool = false
    var showsStatus: Bool = true

    private var owned: Bool { store.profile.ownedCardIDs.contains(card.id) }
    private var retired: Bool { owned && store.isRetired(card) }
    private var signed: Bool { owned && store.isSigned(card) }
    private var assignment: LegendsSquadAssignment { store.assignment(for: card) }
    private var accent: Color { card.rarity.tint }

    private var dimensions: CGSize {
        switch variant {
        case .compact: return CGSize(width: 86, height: 118)
        case .grid: return CGSize(width: 112, height: 152)
        case .reveal: return CGSize(width: 84, height: 120)
        case .hero: return CGSize(width: 190, height: 250)
        }
    }

    var body: some View {
        VStack(spacing: variant == .compact ? 3 : 6) {
            ZStack(alignment: .topTrailing) {
                PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation,
                                   size: variant == .hero ? 78 : (variant == .reveal ? 58 : 44))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(accent, lineWidth: variant == .hero ? 3 : 2))
                Text(card.position.rawValue)
                    .font(.system(size: variant == .compact ? 7 : 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(accent)
                    .clipShape(Capsule())
            }
            Text(owned ? card.name : "???")
                .font(.system(size: variant == .hero ? 14 : (variant == .compact ? 8 : 10), weight: .black, design: .monospaced))
                .foregroundStyle(owned ? Retro.text : Retro.text.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(owned ? "\(store.effectiveOverall(for: card)) OVR" : card.rarity.rawValue.uppercased())
                .font(.system(size: variant == .hero ? 12 : 9, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
            if variant != .compact {
                Text(owned ? "AGE \(store.effectiveAge(for: card))" : "CAREER WAITING")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
            }
            if showsStatus && owned {
                Text(statusLabel)
                    .font(.system(size: variant == .hero ? 9 : 7, weight: .black, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
        }
        .frame(width: dimensions.width, height: dimensions.height)
        .padding(variant == .compact ? 6 : 9)
        .background(
            LinearGradient(colors: [Retro.panel, accent.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: variant == .hero ? 18 : 13))
        .overlay(RoundedRectangle(cornerRadius: variant == .hero ? 18 : 13)
            .stroke(isSelected ? Retro.highlight : accent.opacity(owned ? 0.65 : 0.22), lineWidth: isSelected ? 3 : 1))
        .shadow(color: isSelected ? Retro.highlight.opacity(0.45) : .clear, radius: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var statusLabel: String {
        if retired { return "LEGEND" }
        if !signed { return "UNSIGNED" }
        switch assignment {
        case .startingXI: return "STARTING XI"
        case .bench: return "BENCH"
        case .reserves: return "RESERVES"
        }
    }

    private var statusColor: Color {
        if retired { return Retro.gold }
        if !signed { return Retro.warning }
        switch assignment {
        case .startingXI: return Retro.emerald
        case .bench: return Retro.accent
        case .reserves: return LegendsPalette.blue
        }
    }

    private var accessibilityText: String {
        guard owned else { return "Unowned \(card.position.rawValue) player card" }
        return "\(card.name), \(card.position.rawValue), \(store.effectiveOverall(for: card)) overall, \(statusLabel)"
    }
}
