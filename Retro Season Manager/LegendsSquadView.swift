//
//  LegendsSquadView.swift
//  Retro Season Manager
//
//  Squad Builder — a true pitch-diagram layout: circular tokens
//  positioned in formation-shaped rows (adapting PitchView.swift's own
//  row-stacking technique, which already proves this look doesn't need
//  coordinate-based placement), a bench grid, and a stat row. Landscape
//  layout (the app is landscape-locked; the reference screenshot the
//  user shared was portrait, so pitch/bench sit side by side here
//  rather than stacked). All store-layer logic (assign/clear/captain/
//  formation, the one-card-per-player and retired-card rules) and
//  LegendsCardPickerSheet are reused unchanged from the original list
//  version — only the visual layer changed.
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
            VStack(spacing: 10) {
                header
                pickerStrip
                HStack(alignment: .top, spacing: 12) {
                    LegendsPitchView(store: store) { index in
                        Haptics.tap()
                        pickerTarget = PickerTarget(kind: .xi(index))
                    }
                    .frame(maxWidth: .infinity)

                    sidePanel
                        .frame(width: 190)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
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

    private var header: some View {
        VStack(spacing: 6) {
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
        }
    }

    private var pickerStrip: some View {
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

                Divider().frame(height: 20)

                Picker("Mentality", selection: Binding(
                    get: { store.profile.preferredMentality },
                    set: { store.setPreferredMentality($0) }
                )) {
                    ForEach(Mentality.allCases) { mentality in
                        Text(mentality.rawValue).tag(mentality)
                    }
                }
                .pickerStyle(.menu)
                .tint(Retro.highlight)
            }
            .padding(.horizontal)
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BENCH (\(filledBenchCount)/\(LegendsStore.benchSize))")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(0..<LegendsStore.benchSize, id: \.self) { index in
                        benchToken(index)
                    }
                }
            }
            .frame(maxHeight: 260)

            Divider()

            statRow
        }
    }

    private func benchToken(_ index: Int) -> some View {
        let cardID = store.profile.benchCardIDs[index]
        let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        return LegendsPlayerToken(card: card, role: card?.position ?? .centralMid,
                                   overall: card.map { store.effectiveOverall(for: $0) },
                                   chemistryStars: 0, isCaptain: false, diameter: 42) {
            Haptics.tap()
            pickerTarget = PickerTarget(kind: .bench(index))
        }
    }

    private var filledBenchCount: Int { store.profile.benchCardIDs.compactMap { $0 }.count }

    private var statRow: some View {
        VStack(spacing: 6) {
            statLine("OTR", store.currentTeamRating)
            statLine("ATK", store.attackRating)
            statLine("DEF", store.defenceRating)
            statLine("CHM", store.totalChemistry, suffix: "/33")
        }
    }

    private func statLine(_ label: String, _ value: Int, suffix: String = "") -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            Spacer()
            Text(value > 0 ? "\(value)\(suffix)" : "—")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
    }
}

// MARK: - Pitch diagram

struct LegendsPitchView: View {
    let store: LegendsStore
    let onTapSlot: (Int) -> Void

    /// Attack-first, GK-last row order (matches Career's own pitch
    /// convention) — `startingXISlots` itself is stored GK-first, so
    /// this only reorders which range renders on top, not the indices.
    private var rowRanges: [Range<Int>] {
        let f = store.formation
        let gk = 0..<1
        let def = 1..<(1 + f.defenders)
        let mid = (1 + f.defenders)..<(1 + f.defenders + f.midfielders)
        let fwd = (1 + f.defenders + f.midfielders)..<(1 + f.defenders + f.midfielders + f.forwards)
        return [fwd, mid, def, gk]
    }

    var body: some View {
        ZStack {
            PitchBackground()
            PitchGridDots()
            VStack(spacing: 10) {
                ForEach(Array(rowRanges.enumerated()), id: \.offset) { _, range in
                    HStack(spacing: 6) {
                        ForEach(Array(range), id: \.self) { index in
                            slotToken(index)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(16)
        }
    }

    private func slotToken(_ index: Int) -> some View {
        let role = store.startingXISlots[index]
        let cardID = store.profile.startingXICardIDs[index]
        let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        let isCaptain = cardID != nil && cardID == store.profile.captainCardID
        return LegendsPlayerToken(card: card, role: role,
                                   overall: card.map { store.effectiveOverall(for: $0) },
                                   chemistryStars: cardID != nil ? store.chemistryStars(forXISlot: index) : 0,
                                   isCaptain: isCaptain) {
            onTapSlot(index)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A circular token — role abbreviation, big rating, name, a role-colour
/// ring, and the existing chemistry dots in place of the reference
/// screenshot's condition bar (Legends has no persisted fitness stat to
/// back a real one — chemistry is the real, already-computed substitute).
struct LegendsPlayerToken: View {
    let card: LegendsCard?
    let role: DetailedPosition
    let overall: Int?
    let chemistryStars: Int
    let isCaptain: Bool
    var diameter: CGFloat = 60
    let onTap: () -> Void

    private var ringColor: Color {
        switch role.broad {
        case .goalkeeper, .defender: return Retro.royalBlue
        case .midfielder: return Retro.emerald
        case .forward: return Retro.warning
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Retro.panel.opacity(card == nil ? 0.4 : 0.95))
                        .frame(width: diameter, height: diameter)
                        .overlay(Circle().stroke(ringColor.opacity(card == nil ? 0.3 : 0.9), lineWidth: 2))
                    VStack(spacing: 0) {
                        Text(role.rawValue)
                            .font(.system(size: diameter * 0.14, weight: .bold, design: .monospaced))
                            .foregroundStyle(ringColor)
                        if let overall {
                            Text("\(overall)")
                                .font(.system(size: diameter * 0.28, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.text)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: diameter * 0.22))
                                .foregroundStyle(Retro.text.opacity(0.4))
                        }
                    }
                    if isCaptain {
                        Text("C")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Retro.background)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Retro.gold))
                            .offset(x: diameter / 2 - 6, y: -diameter / 2 + 6)
                    }
                }
                if let card {
                    Text(card.name)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    chemistryDots
                } else {
                    Text("Empty")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.4))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var chemistryDots: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < chemistryStars ? chemistryColor : Retro.text.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var chemistryColor: Color {
        switch chemistryStars {
        case 3: return Retro.emerald
        case 2: return Retro.gold
        case 1: return Retro.warning
        default: return Retro.text.opacity(0.2)
        }
    }
}

// MARK: - Card picker (unchanged from the list version)

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
        let owned = LegendsCardDatabase.all.filter {
            store.profile.ownedCardIDs.contains($0.id) && !placedElsewhere.contains($0.id) && !store.isRetired($0)
        }
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
                                            Text("\(card.position.rawValue) · \(card.rarity.rawValue) · age \(store.effectiveAge(for: card))")
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
