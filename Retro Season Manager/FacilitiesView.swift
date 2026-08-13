//
//  FacilitiesView.swift
//  Retro Season Manager
//
//  Club Facilities: the 8 investable pieces of infrastructure (training
//  ground, youth academy, medical centre, scouting network, stadium,
//  hospitality, museum, club shop) with visual level progression and a
//  one-tap upgrade — the mechanism behind a small club slowly becoming
//  a giant.
//

import SwiftUI

/// A row of 5 small blocks showing a facility's level, colour-tiered like
/// the trophy cabinet (bronze → silver → gold → premium glow) — a level
/// number alone doesn't read as progression the way a filling bar does.
private struct FacilityLevelBar: View {
    let level: Int
    private let maxLevel = 5

    private var tierColor: Color {
        switch level {
        case 0:     return Retro.text.opacity(0.3)
        case 1:     return Retro.bronze
        case 2, 3:  return Retro.silver
        case 4:     return Retro.highlight
        default:    return Retro.accent
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxLevel, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < level ? tierColor : Retro.text.opacity(0.12))
                    .frame(width: 18, height: 8)
            }
        }
    }
}

private struct FacilityRow: View {
    let store: GameStore
    let kind: FacilityKind
    @State private var message: String?

    private var level: Int { kind.level(in: store.userClub) }
    private var cost: Int? { store.facilityUpgradeCost(kind, forClubIndex: store.userClubIndex) }
    private var canAfford: Bool { (cost).map { store.userClub.transferBudget >= $0 } ?? false }

    var body: some View {
        Panel(title: kind.displayName.uppercased()) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(Retro.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        FacilityLevelBar(level: level)
                        Text(kind.tierLabel(level))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight)
                    }
                    Spacer()
                }
                Text(kind.effectBlurb(level))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))

                HStack {
                    if let cost {
                        Text("Upgrade: \(formatMoney(cost))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                        Spacer()
                        Button {
                            Haptics.tap()
                            message = store.investInFacility(kind)
                        } label: {
                            Text("UPGRADE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background((canAfford ? Retro.accent : Retro.text).opacity(canAfford ? 0.25 : 0.1))
                                .foregroundStyle(canAfford ? Retro.accent : Retro.text.opacity(0.4))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAfford)
                    } else {
                        Text("MAX LEVEL")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.gold)
                    }
                }
                if let message {
                    Text(message)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }
            }
        }
    }
}

struct FacilitiesView: View {
    let store: GameStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(FacilityKind.allCases) { kind in
                    FacilityRow(store: store, kind: kind)
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                CrestView(shortName: store.userClub.shortName, size: 40, color: store.userColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("🏟 CLUB FACILITIES")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text(store.userClub.name)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }
                Spacer()
            }
            Text("Transfer budget: \(formatMoney(store.userClub.transferBudget))")
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
        }
    }
}
