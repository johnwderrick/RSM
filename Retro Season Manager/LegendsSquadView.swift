//
//  LegendsSquadView.swift
//  Retro Season Manager
//
//  Squad Builder (Phase 5) — Starting XI, Bench, Captain and Formation.
//  Chemistry (Phase 6) isn't computed here; the doc keeps them as
//  separate roadmap phases.
//

import SwiftUI

struct LegendsSquadView: View {
    let store: LegendsStore
    var onBack: () -> Void

    @State private var pickerTarget: PickerTarget? = nil

    private struct PickerTarget: Identifiable {
        enum Kind { case xi(Int), bench(Int) }
        let kind: Kind
        var id: String {
            switch kind {
            case .xi(let i): return "xi-\(i)"
            case .bench(let i): return "bench-\(i)"
            }
        }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                formationPicker
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        squadSection(title: "STARTING XI (\(filledXICount)/\(store.startingXISlots.count))") {
                            ForEach(Array(store.startingXISlots.enumerated()), id: \.offset) { index, slot in
                                xiRow(index: index, slot: slot)
                            }
                        }
                        squadSection(title: "BENCH (\(filledBenchCount)/\(LegendsStore.benchSize))") {
                            ForEach(0..<LegendsStore.benchSize, id: \.self) { index in
                                benchRow(index: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(item: $pickerTarget) { target in
            switch target.kind {
            case .xi(let index):
                LegendsCardPickerSheet(store: store, slotPosition: store.startingXISlots[index],
                                        currentCardID: store.profile.startingXICardIDs[index]) { picked in
                    if let picked { store.assign(cardID: picked, toXISlot: index) }
                    else { store.clearXISlot(index) }
                }
            case .bench(let index):
                LegendsCardPickerSheet(store: store, slotPosition: nil,
                                        currentCardID: store.profile.benchCardIDs[index]) { picked in
                    if let picked { store.assign(cardID: picked, toBenchSlot: index) }
                    else { store.clearBenchSlot(index) }
                }
            }
        }
    }

    private var filledXICount: Int { store.profile.startingXICardIDs.compactMap { $0 }.count }
    private var filledBenchCount: Int { store.profile.benchCardIDs.compactMap { $0 }.count }

    private var header: some View {
        VStack(spacing: 8) {
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

            Text("SQUAD")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            Text(store.currentTeamRating > 0 ? "TEAM RATING \(store.currentTeamRating)  ·  CHEMISTRY \(store.totalChemistry)/33" : "SET YOUR STARTING XI")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
                .tracking(1)
        }
    }

    private var formationPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Formation.all) { formation in
                    Button {
                        Haptics.tap()
                        store.setFormation(formation.name)
                    } label: {
                        Text(formation.name)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(store.profile.formationName == formation.name ? Retro.background : Retro.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(store.profile.formationName == formation.name ? Retro.accent : Retro.panel)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }

    private func squadSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            VStack(spacing: 6) { content() }
        }
    }

    private func xiRow(index: Int, slot: DetailedPosition) -> some View {
        let cardID = store.profile.startingXICardIDs[index]
        let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        let isCaptain = cardID != nil && cardID == store.profile.captainCardID

        return HStack(spacing: 10) {
            Text(slot.rawValue)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.background)
                .frame(width: 40, height: 24)
                .background(Retro.accent.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                Haptics.tap()
                pickerTarget = PickerTarget(kind: .xi(index))
            } label: {
                slotContent(card: card, fallback: "Empty — tap to assign")
            }
            .buttonStyle(PressableButtonStyle())

            if card != nil {
                chemistryDots(store.chemistryStars(forXISlot: index))
            }

            if let card {
                Button {
                    Haptics.tap()
                    store.setCaptain(cardID: isCaptain ? nil : card.id)
                } label: {
                    Image(systemName: isCaptain ? "star.fill" : "star")
                        .foregroundStyle(isCaptain ? Retro.gold : Retro.text.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Three pips — a compact stand-in for the doc's chemistry stars —
    /// coloured red/amber/green by how much of the 0...3 scale is filled.
    private func chemistryDots(_ stars: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < stars ? chemistryColor(stars) : Retro.text.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func chemistryColor(_ stars: Int) -> Color {
        switch stars {
        case 3: return Retro.emerald
        case 2: return Retro.gold
        case 1: return Retro.warning
        default: return Retro.text.opacity(0.2)
        }
    }

    private func benchRow(index: Int) -> some View {
        let cardID = store.profile.benchCardIDs[index]
        let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }

        return HStack(spacing: 10) {
            Text("SUB")
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.background)
                .frame(width: 40, height: 24)
                .background(Retro.text.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                Haptics.tap()
                pickerTarget = PickerTarget(kind: .bench(index))
            } label: {
                slotContent(card: card, fallback: "Empty — tap to assign")
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func slotContent(card: LegendsCard?, fallback: String) -> some View {
        HStack {
            if let card {
                Circle().fill(card.rarity.tint).frame(width: 10, height: 10)
                Text(card.name)
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Spacer()
                Text("\(store.effectiveOverall(for: card))")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(card.rarity.tint)
            } else {
                Text(fallback)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.5))
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LegendsCardPickerSheet: View {
    let store: LegendsStore
    let slotPosition: DetailedPosition?
    let currentCardID: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    private var placedElsewhere: Set<String> {
        Set((store.profile.startingXICardIDs + store.profile.benchCardIDs).compactMap { $0 })
            .subtracting(currentCardID.map { [$0] } ?? [])
    }

    private var availableCards: [LegendsCard] {
        let owned = LegendsCardDatabase.all.filter { store.profile.ownedCardIDs.contains($0.id) && !placedElsewhere.contains($0.id) }
        guard let slotPosition else { return owned.sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) } }
        return owned.sorted { a, b in
            let aFits = a.position == slotPosition
            let bFits = b.position == slotPosition
            if aFits != bFits { return aFits }
            return store.effectiveOverall(for: a) > store.effectiveOverall(for: b)
        }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(slotPosition.map { "PICK A \($0.rawValue)" } ?? "PICK A SUB")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                if currentCardID != nil {
                    Button {
                        Haptics.tap()
                        onSelect(nil)
                        dismiss()
                    } label: {
                        Text("Clear this slot")
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(Retro.warning)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal)
                }

                if availableCards.isEmpty {
                    Spacer()
                    Text("No available cards. Open more packs or free one up from another slot.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(availableCards) { card in
                                Button {
                                    Haptics.tap()
                                    onSelect(card.id)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Circle().fill(card.rarity.tint).frame(width: 10, height: 10)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name)
                                                .font(.system(.footnote, design: .monospaced).bold())
                                                .foregroundStyle(Retro.text)
                                            Text("\(card.position.rawValue) · \(card.rarity.rawValue)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(Retro.text.opacity(0.6))
                                        }
                                        Spacer()
                                        Text("\(store.effectiveOverall(for: card))")
                                            .font(.system(.callout, design: .monospaced).bold())
                                            .foregroundStyle(card.rarity.tint)
                                    }
                                    .padding(12)
                                    .background(Retro.panel.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}
