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
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var pickerTarget: PickerTarget? = nil
    @State private var showLibrary = false
    @State private var detailCard: LegendsCard? = nil

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
        LegendsMenuShell(store: store, title: "SQUAD", subtitle: "BUILD YOUR STARTING XI", icon: "person.3.fill", accent: LegendsPalette.blue, onBack: onBack, currentNav: .squad, onNavigate: onNavigate, scrollContent: false) {
            GeometryReader { geo in
                VStack(spacing: 6) {
                    pickerStrip
                    HStack(spacing: 8) {
                        libraryStat("LIBRARY", store.profile.ownedCardIDs.count - store.profile.startingXICardIDs.compactMap { $0 }.count - store.profile.benchCardIDs.compactMap { $0 }.count)
                        libraryStat("ACTIVE", store.profile.activatedCardIDs.count)
                        Spacer()
                        Button {
                            Haptics.tap()
                            showLibrary = true
                        } label: {
                            Label("PLAYER LIBRARY", systemImage: "books.vertical.fill")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(LegendsPalette.blueWash)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.horizontal)
                    HStack(alignment: .top, spacing: 12) {
                        LegendsPitchView(store: store, onOpenDetail: { card in
                            Haptics.tap()
                            detailCard = card
                        }) { index in
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
        .sheet(isPresented: $showLibrary) {
            LegendsPlayerLibrarySheet(store: store)
        }
        .sheet(item: $detailCard) { card in
            LegendsPlayerDetailView(store: store, card: card)
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


    private func libraryStat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(max(0, value))").font(.system(size: 13, weight: .black, design: .rounded))
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced))
        }
        .foregroundStyle(LegendsPalette.navy)
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
            Text("MATCHDAY · BENCH (\(filledBenchCount)/\(LegendsStore.benchSize))")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Text("\(store.activeClubPlayers.count) ACTIVE · \(store.reservePlayers.count) RESERVES")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(0..<LegendsStore.benchSize, id: \.self) { index in benchToken(index) }
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            reservesPanel
            statRow
            careerPanel
        }
    }

    private var reservesPanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("RESERVES (\(store.reservePlayers.count))")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.blue)
            if store.reservePlayers.isEmpty {
                Text("No signed reserves yet.")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            } else {
                ForEach(store.reservePlayers.prefix(4)) { card in
                    HStack(spacing: 5) {
                        Text(card.position.rawValue).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.blue)
                        Text(card.name).font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(LegendsPalette.navy).lineLimit(1)
                        Spacer()
                        Text("\(store.effectiveOverall(for: card))").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy)
                    }
                }
                if store.reservePlayers.count > 4 {
                    Text("+\(store.reservePlayers.count - 4) MORE IN ACTIVE CLUB")
                        .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.5))
                }
            }
        }
        .padding(7)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var careerPanel: some View {
        let activeCards = store.activeClubPlayers.compactMap { card in
            card
        }.sorted { $0.name < $1.name }
        return VStack(alignment: .leading, spacing: 5) {
            Text("PLAYER DEVELOPMENT")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.blue)
            if let card = activeCards.first, let career = store.careerState(for: card) {
                Text("\(card.name) · AGE \(store.effectiveAge(for: card))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.text)
                    .lineLimit(1)
                Text("\(career.appearances) APP · \(store.potentialDescription(for: card))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.58))
                    .lineLimit(1)
            }
            Menu {
                ForEach(activeCards) { card in
                    Button("Train \(card.name)") {
                        Haptics.tap()
                        _ = store.trainPlayer(card.id)
                    }
                }
            } label: {
                Label("TRAIN SIGNED PLAYER", systemImage: "figure.run")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(LegendsPalette.blueWash)
                    .clipShape(Capsule())
            }
            .disabled(activeCards.isEmpty)
        }
        .padding(.top, 2)
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
            if let card {
                detailCard = card
            } else {
                pickerTarget = PickerTarget(kind: .bench(index))
            }
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

private struct LegendsPlayerLibrarySheet: View {
    let store: LegendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = LegendsLibraryQuery()
    @State private var selectedCard: LegendsCard? = nil
    @State private var compareMode = false
    @State private var compareIDs: Set<String> = []
    @State private var showComparison = false
    @State private var signingCard: LegendsCard? = nil
    @State private var signingTarget: SigningTarget? = nil

    private enum SigningTarget {
        case xi(Int)
        case bench(Int)
    }

    private var groups: [(key: String, cards: [LegendsCard])] {
        store.libraryGroups(query: query)
    }

    private var compareCards: [LegendsCard] {
        compareIDs.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            .sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LegendsPalette.contentBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cards stay here until you sign them into the XI or bench. Signing starts their aging clock.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.66))

                        searchField
                        filterBar
                        sortBar

                        if compareMode {
                            comparisonBar
                        }

                        if groups.allSatisfy({ $0.cards.isEmpty }) {
                            Text("No players match these filters.")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                                .frame(maxWidth: .infinity, minHeight: 140)
                        } else {
                            ForEach(groups, id: \.key) { group in
                                if !group.cards.isEmpty {
                                    VStack(alignment: .leading, spacing: 7) {
                                        if query.group != .none {
                                            HStack {
                                                Text(group.key)
                                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                                    .foregroundStyle(LegendsPalette.navy)
                                                if query.group == .player && group.cards.count > 1 {
                                                    Text("\(group.cards.count) VERSIONS")
                                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                                        .foregroundStyle(LegendsPalette.orange)
                                                }
                                                Spacer()
                                            }
                                        }
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 10)], spacing: 10) {
                                            ForEach(group.cards) { card in
                                                libraryCard(card, isSelected: selectedCard?.id == card.id,
                                                            isCompared: compareIDs.contains(card.id))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if let selectedCard, !compareMode {
                            signingPanel(for: selectedCard)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("PLAYER LIBRARY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(compareMode ? "Done" : "Compare") {
                        compareMode.toggle()
                        if !compareMode { compareIDs.removeAll() }
                        selectedCard = nil
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showComparison) {
                LegendsCardComparisonSheet(store: store, cards: compareCards)
            }
            .alert("Start this player's career?", isPresented: Binding(
                get: { signingCard != nil },
                set: { if !$0 { cancelSigning() } }
            )) {
                Button("Cancel", role: .cancel) { cancelSigning() }
                Button("Sign") { confirmSigning() }
            } message: {
                Text("Once signed, \(signingCard?.name ?? "this player") will begin ageing at the end of each season and can develop through matches and training. They cannot return to frozen Collection status.")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            TextField("Search player, club or nation", text: Binding(
                get: { query.searchText },
                set: { query.searchText = $0 }
            ))
            .font(.system(size: 11, design: .monospaced))
            if !query.searchText.isEmpty {
                Button {
                    query.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LegendsPalette.navy.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LegendsPalette.blue.opacity(0.25), lineWidth: 1))
    }

    private var filterBar: some View {
        HStack(spacing: 7) {
            libraryMenu(title: query.position?.rawValue ?? "POSITION") {
                Button("All positions") { query.position = nil }
                ForEach(DetailedPosition.allCases, id: \.self) { position in
                    Button(position.fullName) { query.position = position }
                }
            }
            libraryMenu(title: query.rarity?.rawValue ?? "RARITY") {
                Button("All rarities") { query.rarity = nil }
                ForEach(LegendsRarity.allCases.sorted { $0.tier < $1.tier }, id: \.self) { rarity in
                    Button(rarity.rawValue) { query.rarity = rarity }
                }
            }
            libraryMenu(title: query.era?.rawValue ?? "ERA") {
                Button("All eras") { query.era = nil }
                ForEach(LegendsEra.allCases, id: \.self) { era in
                    Button(era.rawValue) { query.era = era }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var sortBar: some View {
        HStack(spacing: 7) {
            libraryMenu(title: "SORT: \(query.sort.rawValue)") {
                ForEach(LegendsLibrarySort.allCases) { sort in
                    Button(sort.rawValue) { query.sort = sort }
                }
            }
            libraryMenu(title: "GROUP: \(query.group.rawValue)") {
                ForEach(LegendsLibraryGroup.allCases) { group in
                    Button(group.rawValue) { query.group = group }
                }
            }
            Spacer()
            Button("RESET") {
                query = LegendsLibraryQuery()
                selectedCard = nil
            }
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(LegendsPalette.orange)
            .buttonStyle(.plain)
        }
    }

    private func libraryMenu<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title.uppercased())
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .black))
            }
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LegendsPalette.navy.opacity(0.16), lineWidth: 1))
        }
    }

    private var comparisonBar: some View {
        HStack(spacing: 10) {
            Text("SELECT TWO CARDS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
            Spacer()
            Text("\(compareIDs.count) / 2")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.blue)
            Button("COMPARE") {
                showComparison = true
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(compareIDs.count == 2 ? LegendsPalette.blue : LegendsPalette.navy.opacity(0.25))
            .clipShape(Capsule())
            .disabled(compareIDs.count != 2)
        }
        .padding(10)
        .background(LegendsPalette.blueWash)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func libraryCard(_ card: LegendsCard, isSelected: Bool, isCompared: Bool) -> some View {
        Button {
            Haptics.tap()
            if compareMode {
                if isCompared {
                    compareIDs.remove(card.id)
                } else if compareIDs.count < 2 {
                    compareIDs.insert(card.id)
                }
            } else {
                selectedCard = isSelected ? nil : card
            }
        } label: {
            VStack(spacing: 5) {
                PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(card.rarity.tint, lineWidth: 2))
                Text(card.name)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text("\(store.effectiveOverall(for: card)) OVR · \(card.position.rawValue)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(card.rarity.tint)
                if compareMode {
                    Text(isCompared ? "SELECTED" : "TAP TO COMPARE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(isCompared ? LegendsPalette.green : LegendsPalette.navy.opacity(0.48))
                }
            }
            .frame(maxWidth: .infinity, minHeight: compareMode ? 112 : 98)
            .padding(8)
            .background(isCompared ? LegendsPalette.blueWash : (isSelected ? LegendsPalette.greenWash : .white))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCompared ? LegendsPalette.blue : (isSelected ? LegendsPalette.green : card.rarity.tint.opacity(0.3)), lineWidth: isCompared || isSelected ? 2 : 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func cancelSigning() {
        signingCard = nil
        signingTarget = nil
    }

    private func confirmSigning() {
        guard let card = signingCard, let target = signingTarget else {
            cancelSigning()
            return
        }
        switch target {
        case .xi(let index): store.assign(cardID: card.id, toXISlot: index)
        case .bench(let index): store.assign(cardID: card.id, toBenchSlot: index)
        }
        selectedCard = nil
        cancelSigning()
    }

    private func signingPanel(for card: LegendsCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIGN \(card.name.uppercased()) TO...")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
            let compatibleXI = store.startingXISlots.indices.filter {
                store.profile.startingXICardIDs[$0] == nil && store.canPlay(card, in: store.startingXISlots[$0])
            }
            ForEach(compatibleXI, id: \.self) { index in
                Button {
                    signingCard = card
                    signingTarget = .xi(index)
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("STARTING XI · \(store.startingXISlots[index].rawValue)")
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .padding(10)
                    .background(LegendsPalette.greenWash)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(PressableButtonStyle())
            }
            if let benchIndex = store.profile.benchCardIDs.firstIndex(where: { $0 == nil }) {
                Button {
                    signingCard = card
                    signingTarget = .bench(benchIndex)
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("BENCH SLOT \(benchIndex + 1)")
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .padding(10)
                    .background(LegendsPalette.blueWash)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(PressableButtonStyle())
            }
            if compatibleXI.isEmpty && store.profile.benchCardIDs.allSatisfy({ $0 != nil }) {
                Text("No compatible open slot is available yet.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Retro.warning)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LegendsPalette.green.opacity(0.35), lineWidth: 1))
    }
}

private struct LegendsCardComparisonSheet: View {
    let store: LegendsStore
    let cards: [LegendsCard]
    @Environment(\.dismiss) private var dismiss

    private let metrics: [(String, KeyPath<LegendsCard, Int>)] = [
        ("OVR", \.overall), ("PAC", \.pace), ("SHO", \.shooting), ("PAS", \.passing),
        ("DRI", \.dribbling), ("DEF", \.defending), ("PHY", \.physical)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LegendsPalette.contentBackground.ignoresSafeArea()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(cards) { card in
                            comparisonColumn(card)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("COMPARE PLAYERS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func comparisonColumn(_ card: LegendsCard) -> some View {
        VStack(spacing: 8) {
            PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 70)
                .clipShape(Circle())
                .overlay(Circle().stroke(card.rarity.tint, lineWidth: 3))
            Text(card.name)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("\(card.season) · \(card.position.rawValue)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(card.rarity.tint)
            ForEach(metrics, id: \.0) { metric in
                comparisonMetric(metric.0, value: metric.1 == \.overall ? store.effectiveOverall(for: card) : card[keyPath: metric.1])
            }
        }
        .padding(12)
        .frame(width: 150)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(card.rarity.tint.opacity(0.45), lineWidth: 1))
    }

    private func comparisonMetric(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.58))
            Spacer()
            Text("\(value)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(LegendsPalette.contentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Pitch diagram

struct LegendsPitchView: View {
    let store: LegendsStore
    let onOpenDetail: (LegendsCard) -> Void
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
            if let card {
                onOpenDetail(card)
            } else {
                onTapSlot(index)
            }
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
            store.profile.ownedCardIDs.contains($0.id)
                && !namesPlacedElsewhere.contains($0.name)
                && !store.isRetired($0)
        }
        guard let slotPosition else { return owned.sorted { store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1) } }
        return owned
            .filter { store.canPlay($0, in: slotPosition) }
            .sorted { a, b in
                let aExact = a.position == slotPosition
                let bExact = b.position == slotPosition
                if aExact != bExact { return aExact }
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
