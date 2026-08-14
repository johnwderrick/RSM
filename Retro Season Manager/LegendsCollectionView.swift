//
//  LegendsCollectionView.swift
//  Retro Season Manager
//
//  The Collection Book (Phase 3) — browses the full card database and
//  tracks which cards are owned. Nothing is ownable yet (Pack Opening is
//  Phase 4), so every card currently shows as not-owned; the screen is
//  still real and useful as a database to browse and plan around.
//

import SwiftUI

struct LegendsCollectionView: View {
    let store: LegendsStore
    var onBack: () -> Void

    @State private var selectedEra: LegendsEra? = nil
    @State private var selectedCard: LegendsCard? = nil

    private var cards: [LegendsCard] {
        let all = LegendsCardDatabase.all
        guard let selectedEra else { return all }
        return all.filter { $0.era == selectedEra }
    }

    private var ownedCount: Int { store.profile.ownedCardIDs.count }
    private var totalCount: Int { LegendsCardDatabase.all.count }
    private var completionPercent: Int {
        totalCount == 0 ? 0 : Int((Double(ownedCount) / Double(totalCount) * 100).rounded())
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                eraPicker
                cardGrid
            }
        }
        .sheet(item: $selectedCard) { card in
            LegendsCardDetailSheet(card: card, owned: store.profile.ownedCardIDs.contains(card.id))
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("‹ Back")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            VStack(spacing: 4) {
                Text("COLLECTION BOOK")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text("\(ownedCount) / \(totalCount) PLAYERS · \(completionPercent)% COMPLETE")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .tracking(1)
            }
        }
    }

    private var eraPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                eraChip(title: "All", isSelected: selectedEra == nil) { selectedEra = nil }
                ForEach(LegendsEra.allCases, id: \.self) { era in
                    eraChip(title: era.rawValue, isSelected: selectedEra == era) { selectedEra = era }
                }
            }
            .padding(.horizontal)
        }
    }

    private func eraChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(isSelected ? Retro.background : Retro.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Retro.accent : Retro.panel)
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(cards) { card in
                    cardTile(card)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func cardTile(_ card: LegendsCard) -> some View {
        let owned = store.profile.ownedCardIDs.contains(card.id)
        return Button {
            Haptics.tap()
            selectedCard = card
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(card.rarity.tint.opacity(owned ? 0.9 : 0.25))
                        .frame(width: 40, height: 40)
                    Text(card.position.rawValue)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(owned ? Retro.background : Retro.text.opacity(0.5))
                }
                Text(owned ? card.name : "???")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(owned ? Retro.text : Retro.text.opacity(0.4))
                    .lineLimit(1)
                Text(owned ? "\(card.overall) OVR" : card.rarity.rawValue.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(card.rarity.tint.opacity(owned ? 1 : 0.6))
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(8)
            .background(Retro.panel.opacity(owned ? 0.7 : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(card.rarity.tint.opacity(owned ? 0.6 : 0.15), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct LegendsCardDetailSheet: View {
    let card: LegendsCard
    let owned: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(card.rarity.tint.opacity(0.85)).frame(width: 76, height: 76)
                        Text(card.position.rawValue)
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                    }
                    Text(owned ? card.name : "???")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Text("\(card.rarity.rawValue.uppercased()) · \(card.era.rawValue.uppercased())")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(card.rarity.tint)
                        .tracking(1)
                    if owned {
                        Text("\(card.club) · \(card.nation) · \(card.season)")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                    }
                }

                if owned {
                    Panel(title: "ATTRIBUTES") {
                        VStack(spacing: 8) {
                            statBar("OVR", card.overall)
                            statBar("PAC", card.pace)
                            statBar("SHO", card.shooting)
                            statBar("PAS", card.passing)
                            statBar("DRI", card.dribbling)
                            statBar("DEF", card.defending)
                            statBar("PHY", card.physical)
                        }
                    }

                    Panel(title: "SPECIAL ABILITY") {
                        Text(card.specialAbility)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(Retro.accent)
                    }

                    Panel(title: "BIOGRAPHY") {
                        Text(card.biography)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    }
                } else {
                    Panel(title: "NOT YET OWNED") {
                        Text("Open packs to add this card to your collection. Packs unlock in a future update.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 420)
        }
    }

    private func statBar(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.7))
                .frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Retro.background.opacity(0.5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(card.rarity.tint)
                        .frame(width: geo.size.width * CGFloat(min(value, 99)) / 99)
                }
            }
            .frame(height: 8)
            Text("\(value)")
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .frame(width: 26, alignment: .trailing)
        }
    }
}
