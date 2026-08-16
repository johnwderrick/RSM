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
import UniformTypeIdentifiers

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
        GeometryReader { geo in
            ZStack {
                Retro.background.ignoresSafeArea()
                VStack(spacing: 6) {
                    header
                    pickerStrip
                    HStack(alignment: .top, spacing: 12) {
                        LegendsPitchView(store: store) { index in
                            Haptics.tap()
                            pickerTarget = PickerTarget(kind: .xi(index))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        sidePanel
                            .frame(width: 190)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .frame(width: geo.size.width, height: geo.size.height)
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
                LegendsBackButton(action: onBack)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("BENCH (\(filledBenchCount)/\(LegendsStore.benchSize))")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(0..<LegendsStore.benchSize, id: \.self) { index in
                        benchToken(index)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            statRow
        }
    }

    private func benchToken(_ index: Int) -> some View {
        let cardID = store.profile.benchCardIDs[index]
        let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        let slot = LegendsSquadSlot.bench(index)
        return LegendsPlayerToken(card: card, role: card?.position ?? .centralMid,
                                   overall: card.map { store.effectiveOverall(for: $0) },
                                   chemistryStars: 0, isCaptain: false, diameter: 40,
                                   slot: slot, onSwap: { store.swapSquadSlots($0, $1) }) {
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

    /// The default 60pt token doesn't fit 4 rows in a landscape phone's
    /// height budget (see the Squad screen's own header/picker-strip
    /// chrome above it) — so instead of a fixed size, the pitch measures
    /// its own allotted height and sizes tokens to actually fit it,
    /// rather than assuming a portrait-sized budget it never gets.
    private func diameter(for availableHeight: CGFloat) -> CGFloat {
        let rowCount = CGFloat(rowRanges.count)
        let rowSpacing: CGFloat = 6
        let verticalPadding: CGFloat = 8
        let rowHeight = (availableHeight - verticalPadding * 2 - rowSpacing * (rowCount - 1)) / rowCount
        // Budget beyond the circle itself for the name label + chemistry dots.
        return max(32, min(60, rowHeight - 22))
    }

    var body: some View {
        GeometryReader { geo in
            let tokenDiameter = diameter(for: geo.size.height)
            ZStack {
                PitchBackground()
                PitchGridDots()
                VStack(spacing: 6) {
                    ForEach(Array(rowRanges.enumerated()), id: \.offset) { _, range in
                        HStack(spacing: 6) {
                            ForEach(Array(range), id: \.self) { index in
                                slotToken(index, diameter: tokenDiameter)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func slotToken(_ index: Int, diameter: CGFloat) -> some View {
        let role = store.startingXISlots[index]
        let cardID = store.profile.startingXICardIDs[index]
        let card = cardID.flatMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        let isCaptain = cardID != nil && cardID == store.profile.captainCardID
        let slot = LegendsSquadSlot.xi(index)
        return LegendsPlayerToken(card: card, role: role,
                                   overall: card.map { store.effectiveOverall(for: $0) },
                                   chemistryStars: cardID != nil ? store.chemistryStars(forXISlot: index) : 0,
                                   isCaptain: isCaptain, diameter: diameter,
                                   slot: slot, onSwap: { store.swapSquadSlots($0, $1) }) {
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
    var showChemistry: Bool = true
    /// This token's own squad position and a swap callback — when both
    /// are supplied, the token becomes a drag source *and* drop target,
    /// so dragging one token onto another swaps the two players. Left
    /// nil for non-squad contexts (e.g. the card picker sheet), where a
    /// token is just a tap-to-pick tile.
    var slot: LegendsSquadSlot? = nil
    var onSwap: ((LegendsSquadSlot, LegendsSquadSlot) -> Void)? = nil
    let onTap: () -> Void

    private var ringColor: Color {
        switch role.broad {
        case .goalkeeper, .defender: return Retro.royalBlue
        case .midfielder: return Retro.emerald
        case .forward: return Retro.warning
        }
    }

    var body: some View {
        Group {
            if let slot, let onSwap {
                tokenButton
                    .onDrag { NSItemProvider(object: slot.dragString as NSString) }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                            guard let string = reading as? String, let sourceSlot = LegendsSquadSlot(dragString: string) else { return }
                            DispatchQueue.main.async { onSwap(sourceSlot, slot) }
                        }
                        return true
                    }
            } else {
                tokenButton
            }
        }
    }

    private var tokenButton: some View {
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
                    if showChemistry { chemistryDots }
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

    /// Names, not IDs — `LegendsStore+Squad.swift`'s `removeFromSquad`
    /// evicts a slot by matching *name* (only one version of a real
    /// player allowed in the squad at once), so the picker has to filter
    /// the same way. Filtering by ID alone let the list offer a card that
    /// would silently evict a *different* slot holding another season of
    /// the same person the moment it was picked.
    private var namesPlacedElsewhere: Set<String> {
        let idsElsewhere = Set((store.profile.startingXICardIDs + store.profile.benchCardIDs).compactMap { $0 })
            .subtracting(currentCardID.map { [$0] } ?? [])
        return Set(idsElsewhere.compactMap { id in LegendsCardDatabase.all.first { $0.id == id }?.name })
    }

    private var availableCards: [LegendsCard] {
        let owned = LegendsCardDatabase.all.filter {
            store.profile.ownedCardIDs.contains($0.id) && !namesPlacedElsewhere.contains($0.name) && !store.isRetired($0)
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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 92), spacing: 14)], spacing: 16) {
                            ForEach(availableCards) { card in
                                LegendsPlayerToken(card: card, role: card.position,
                                                    overall: store.effectiveOverall(for: card),
                                                    chemistryStars: 0, isCaptain: false, diameter: 56,
                                                    showChemistry: false) {
                                    Haptics.tap()
                                    onSelect(card.id)
                                    dismiss()
                                }
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
