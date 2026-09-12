//
//  LegendsCollectionView.swift
//  Retro Season Manager
//
//  The Collection Book (Phase 3, redesigned) — browses the full card
//  database and tracks which cards are owned. Ownership comes from
//  opening packs (Phase 4, LegendsStore+Packs.swift).
//
//  Presentation follows the accepted Squad/Division/Training/Packs/
//  Facilities/Assistants/Stadiums language: a white summary band, capsule
//  filter chips, light card tiles, and one stable scroll container owned
//  by this screen (the shell renders the content unsrolled). Filter and
//  selection changes only mutate @State, so the scroll container's
//  identity never changes and the view never jumps back to the top.
//  All lifecycle rules (signing, releasing, retiring, favourites,
//  duplicates) remain owned by LegendsStore — this view only reads them.
//

import SwiftUI

enum LegendsPlayerBrowserMode: String, CaseIterable, Identifiable {
    case collection = "COLLECTION"
    case activeClub = "ACTIVE CLUB"
    var id: String { rawValue }
}

enum LegendsCollectionStatus: String, CaseIterable, Identifiable {
    case all = "ALL"
    case unsigned = "UNSIGNED"
    case signed = "SIGNED"
    case retired = "LEGENDS"
    var id: String { rawValue }
}

struct LegendsCollectionView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var browserMode: LegendsPlayerBrowserMode = .collection
    @State private var selectedStatus: LegendsCollectionStatus = .all
    @State private var selectedEra: LegendsEra? = nil
    @State private var selectedRarity: LegendsRarity? = nil
    @State private var selectedNation: String? = nil
    @State private var minimumOverall = 0
    @State private var highPotentialOnly = false
    @State private var ownedOnly = false
    @State private var selectedCard: LegendsCard? = nil
    @State private var searchText = ""
    @State private var sort: LegendsLibrarySort = .rating
    @State private var favouritesOnly = false
    @State private var duplicatesOnly = false
    @State private var finalSeasonOnly = false
    @State private var showingFilters = false

    // MARK: - Derived data (authoritative store state, view-only)

    private var cards: [LegendsCard] {
        let retiredIDs = Set(store.profile.legendsHall.map(\.cardID))
        let query = LegendsLibraryQuery(position: nil, rarity: selectedRarity, era: selectedEra,
                                        sort: sort, searchText: searchText,
                                        signed: selectedStatus == .signed ? true : (selectedStatus == .unsigned ? false : nil),
                                        favouriteOnly: favouritesOnly, duplicateOnly: duplicatesOnly,
                                        finalSeasonOnly: finalSeasonOnly,
                                        minimumOverall: minimumOverall > 0 ? minimumOverall : nil)
        let library = store.libraryCards(query: query, excludingActive: false)
        return library.filter { card in
            let owned = store.profile.ownedCardIDs.contains(card.id)
            let retired = retiredIDs.contains(card.id) && !owned
            let signed = owned && store.isSigned(card)
            let statusMatches: Bool
            switch selectedStatus {
            case .all: statusMatches = true
            case .unsigned: statusMatches = owned && !signed
            case .signed: statusMatches = signed
            case .retired: statusMatches = retired
            }
            let modeMatches = browserMode == .collection ? (owned || retired) : signed
            return modeMatches && statusMatches
                && (selectedEra == nil || card.era == selectedEra)
                && (selectedRarity == nil || card.rarity == selectedRarity)
                && (selectedNation == nil || card.nation == selectedNation)
                && card.overall >= minimumOverall
                && (!highPotentialOnly || ["GENERATIONAL TALENT", "ELITE POTENTIAL", "HIGH POTENTIAL"].contains(store.potentialDescription(for: card)))
                && (!ownedOnly || owned)
        }
    }

    private var ownedCount: Int { store.profile.ownedCardIDs.count }
    private var signedCount: Int { store.activeClubPlayers.count }
    private var unsignedCount: Int { store.unsignedPlayers.count }
    private var retiredCount: Int { store.profile.legendsHall.count }
    private var totalCount: Int { LegendsCardDatabase.all.count }
    private var completionPercent: Int {
        totalCount == 0 ? 0 : Int((Double(ownedCount) / Double(totalCount) * 100).rounded())
    }

    private var activeFilterCount: Int {
        (selectedEra != nil ? 1 : 0) + (selectedRarity != nil ? 1 : 0) + (selectedNation != nil ? 1 : 0)
            + (minimumOverall > 0 ? 1 : 0) + (highPotentialOnly ? 1 : 0) + (ownedOnly ? 1 : 0)
            + (favouritesOnly ? 1 : 0) + (duplicatesOnly ? 1 : 0) + (finalSeasonOnly ? 1 : 0)
            + (searchText.isEmpty ? 0 : 1)
    }

    var body: some View {
        LegendsMenuShell(store: store, title: browserMode == .activeClub ? "ACTIVE CLUB" : "PLAYER COLLECTION", subtitle: "\(ownedCount) OWNED · \(signedCount) ACTIVE · \(unsignedCount) UNSIGNED · \(retiredCount) LEGENDS", icon: browserMode == .activeClub ? "person.3.fill" : "square.stack.3d.up.fill", accent: browserMode == .activeClub ? LegendsPalette.blue : LegendsPalette.orange, onBack: onBack, currentNav: .collection, onNavigate: onNavigate, scrollContent: false) {
            // One stable scroll container for the whole destination. Plain
            // (non-lazy) rows keep every tile in the accessibility tree even
            // when scrolled off-screen, and the container's identity never
            // changes when filters change, so scroll position is preserved.
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryBand
                        primaryFilterRow
                        if browserMode == .activeClub { activeClubSummary }
                        capacityBanner
                        if showingFilters { advancedFilterPanel }
                        countRow
                        if cards.isEmpty {
                            emptyState
                        } else {
                            cardGrid
                        }
                    }
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .sheet(item: $selectedCard) { card in
            LegendsPlayerDetailView(store: store, card: card)
        }
        .accessibilityIdentifier("legends.library")
    }

    // MARK: - Summary band

    private var summaryBand: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                summaryStat(value: "\(ownedCount)/\(totalCount)",
                            label: "OWNED",
                            color: LegendsPalette.orange,
                            identifier: "legends.players.summary.owned")
                summaryStat(value: "\(signedCount)",
                            label: "SIGNED",
                            color: LegendsPalette.green,
                            identifier: "legends.players.summary.signed")
                summaryStat(value: "\(unsignedCount)",
                            label: "UNSIGNED",
                            color: LegendsPalette.blue,
                            identifier: "legends.players.summary.unsigned")
                summaryStat(value: "\(retiredCount)",
                            label: "LEGENDS",
                            color: LegendsPalette.goldDeep,
                            identifier: "legends.players.summary.legends")
            }
            HStack(spacing: 10) {
                Text("COLLECTION COMPLETION")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                LegendsProgressBar(value: Double(ownedCount) / Double(max(totalCount, 1)), tint: LegendsPalette.orange, height: 8)
                    .accessibilityIdentifier("legends.players.summary.completionBar")
                Text("\(completionPercent)%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LegendsPalette.navy)
                    .accessibilityIdentifier("legends.players.summary.completion")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.orange.opacity(0.24), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.players.summary")
    }

    private func summaryStat(value: String, label: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(LegendsPalette.contentBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.lowercased()) \(value)")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Primary filter row

    /// Mode, status chips, the advanced-filter toggle and the sort menu all
    /// live in one horizontal row: the crowded stack of four separate chip
    /// rows collapses into a single scannable band, with rarer controls
    /// moved into the expandable advanced area.
    private var primaryFilterRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Player area", selection: $browserMode) {
                ForEach(LegendsPlayerBrowserMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)
            .tint(browserMode == .activeClub ? LegendsPalette.blue : LegendsPalette.orange)
            .accessibilityIdentifier("legends.players.mode")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(LegendsCollectionStatus.allCases) { status in
                        Button {
                            Haptics.tap()
                            selectedStatus = status
                        } label: {
                            Text(status.rawValue)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(selectedStatus == status ? .white : LegendsPalette.navy)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedStatus == status ? LegendsPalette.orange : .white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selectedStatus == status ? LegendsPalette.orange : LegendsPalette.navy.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("legends.players.status.\(status.rawValue.lowercased())")
                        .accessibilityAddTraits(selectedStatus == status ? [.isSelected] : [])
                    }
                    Divider().frame(height: 20)
                    Button {
                        Haptics.tap()
                        showingFilters.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(showingFilters ? "HIDE FILTERS" : "FILTERS")
                            if activeFilterCount > 0 && !showingFilters {
                                Text("\(activeFilterCount)")
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(LegendsPalette.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(showingFilters ? .white : LegendsPalette.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(showingFilters ? LegendsPalette.blue : .white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(LegendsPalette.navy.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("legends.library.filters")

                    Menu {
                        ForEach(LegendsLibrarySort.allCases) { option in
                            Button(option.rawValue) { sort = option }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text("SORT")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .black))
                        }
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(LegendsPalette.navy.opacity(0.18), lineWidth: 1))
                    }
                    .accessibilityIdentifier("legends.library.sort")
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Active club summary

    private var activeClubSummary: some View {
        HStack(spacing: 18) {
            summaryMetric("PLAYERS", signedCount)
            summaryMetric("AVERAGE AGE", averageAge)
            summaryMetric("AVERAGE OVR", averageOverall)
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LegendsPalette.blue.opacity(0.22), lineWidth: 1))
    }

    private var averageAge: Int {
        guard !store.activeClubPlayers.isEmpty else { return 0 }
        let total = store.activeClubPlayers.reduce(0) { $0 + store.effectiveAge(for: $1) }
        return total / store.activeClubPlayers.count
    }

    private var averageOverall: Int {
        guard !store.activeClubPlayers.isEmpty else { return 0 }
        let total = store.activeClubPlayers.reduce(0) { $0 + store.effectiveOverall(for: $1) }
        return total / store.activeClubPlayers.count
    }

    private func summaryMetric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        }
        .foregroundStyle(LegendsPalette.navy)
    }

    // MARK: - Capacity banner

    private var capacityBanner: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(store.isUnsignedLibraryFull ? Color.red : LegendsPalette.blue)
            Text("LIBRARY \(unsignedCount) / \(store.unsignedLibraryCapacity)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .monospacedDigit()
            Spacer()
            if store.isUnsignedLibraryFull {
                Text("FULL")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(LegendsPalette.navy)
        .padding(10)
        .background(store.isUnsignedLibraryFull ? Color.red.opacity(0.12) : LegendsPalette.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unsigned player library capacity, \(unsignedCount) of \(store.unsignedLibraryCapacity)")
    }

    // MARK: - Advanced filters

    private var advancedFilterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("SEARCH PLAYERS", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .autocorrectionDisabled()
                .accessibilityIdentifier("legends.library.search")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    eraChip(title: "ALL ERAS", isSelected: selectedEra == nil) { selectedEra = nil }
                    ForEach(LegendsEra.allCases, id: \.self) { era in
                        eraChip(title: era.rawValue, isSelected: selectedEra == era) { selectedEra = era }
                    }
                }
                .padding(.horizontal, 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    rarityChip(title: "ALL RARITIES", tint: LegendsPalette.navy, isSelected: selectedRarity == nil) { selectedRarity = nil }
                    ForEach(LegendsRarity.allCases.sorted { $0.tier < $1.tier }, id: \.self) { rarity in
                        rarityChip(title: rarity.rawValue, tint: rarity.tint, isSelected: selectedRarity == rarity) { selectedRarity = rarity }
                    }
                }
                .padding(.horizontal, 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    Menu {
                        Button("All nations") { selectedNation = nil }
                        ForEach(Array(Set(LegendsCardDatabase.all.map(\.nation))).sorted(), id: \.self) { nation in
                            Button(nation) { selectedNation = nation }
                        }
                    } label: {
                        filterPill(selectedNation?.uppercased() ?? "NATION", active: selectedNation != nil, tint: LegendsPalette.blue)
                    }
                    .accessibilityIdentifier("legends.players.nation")

                    Menu {
                        Button("Any overall") { minimumOverall = 0 }
                        ForEach([70, 80, 85, 90, 95], id: \.self) { rating in
                            Button("\(rating)+ OVR") { minimumOverall = rating }
                        }
                    } label: {
                        filterPill(minimumOverall == 0 ? "OVR" : "OVR \(minimumOverall)+", active: minimumOverall > 0, tint: LegendsPalette.orange)
                    }
                    .accessibilityIdentifier("legends.players.ovr")

                    Button { highPotentialOnly.toggle() } label: {
                        filterPill("POTENTIAL", active: highPotentialOnly, tint: LegendsPalette.green)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("legends.players.potential")

                    Button { ownedOnly.toggle() } label: {
                        filterPill("OWNED ONLY", active: ownedOnly, tint: LegendsPalette.purple)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("legends.players.ownedOnly")
                }
                .padding(.horizontal, 1)
            }

            Toggle("FAVOURITES ONLY", isOn: $favouritesOnly)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tint(LegendsPalette.orange)
                .accessibilityIdentifier("legends.library.favourites")
            Toggle("EXACT DUPLICATES", isOn: $duplicatesOnly)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tint(LegendsPalette.orange)
                .accessibilityIdentifier("legends.library.duplicates")
            Toggle("FINAL SEASON ONLY", isOn: $finalSeasonOnly)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tint(LegendsPalette.orange)
                .accessibilityIdentifier("legends.library.finalSeason")

            Button {
                Haptics.tap()
                selectedStatus = .all; selectedEra = nil; selectedRarity = nil; selectedNation = nil
                minimumOverall = 0; highPotentialOnly = false; ownedOnly = false
                searchText = ""; favouritesOnly = false; duplicatesOnly = false; finalSeasonOnly = false; sort = .rating
            } label: {
                Text("RESET FILTERS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(LegendsPalette.navy)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("legends.library.resetFilters")
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.navy.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.players.advanced")
    }

    private func eraChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(isSelected ? .white : LegendsPalette.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? LegendsPalette.blue : LegendsPalette.contentBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? LegendsPalette.blue : LegendsPalette.navy.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.players.era.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func rarityChip(title: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(isSelected ? .white : LegendsPalette.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? tint : LegendsPalette.contentBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? tint : LegendsPalette.navy.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.players.rarity.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func filterPill(_ title: String, active: Bool, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
            Image(systemName: active ? "checkmark" : "chevron.down")
                .font(.system(size: 8, weight: .black))
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .foregroundStyle(active ? .white : LegendsPalette.navy)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(active ? tint : LegendsPalette.contentBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(active ? tint : LegendsPalette.navy.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Count + grid

    private var countRow: some View {
        Text("\(cards.count) PLAYERS")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy.opacity(0.66))
            .accessibilityIdentifier("legends.players.count")
    }

    /// Plain rows (not lazy) so every tile stays in the accessibility tree
    /// even when scrolled off-screen — XCUITest can always address a card.
    private var cardGrid: some View {
        VStack(spacing: 10) {
            ForEach(stride(from: 0, to: cards.count, by: 3).map { start in
                (id: cards[start].id, cards: Array(cards[start..<min(start + 3, cards.count)]))
            }, id: \.id) { row in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(row.cards) { card in
                        cardTile(card)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: browserMode == .activeClub ? "person.3.fill" : "square.stack.3d.up.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(LegendsPalette.blue)
            Text(browserMode == .activeClub ? "BUILD YOUR ACTIVE CLUB" : (selectedStatus == .unsigned ? "NO UNSIGNED PLAYERS" : "NO PLAYERS HERE"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(LegendsPalette.navy)
            Text(browserMode == .activeClub ? "Sign players from Collection to begin their careers." : "Players you choose not to sign immediately will wait here.")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.navy.opacity(0.10), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.players.empty")
    }

    // MARK: - Card tile

    private func cardTile(_ card: LegendsCard) -> some View {
        let owned = store.profile.ownedCardIDs.contains(card.id)
        let retired = owned && store.isRetired(card)
        let signed = owned && store.isSigned(card)
        let status: String
        let statusColor: Color
        if retired {
            status = "LEGEND"; statusColor = LegendsPalette.goldDeep
        } else if !owned || !signed {
            status = "UNSIGNED"; statusColor = LegendsPalette.blue
        } else {
            switch store.assignment(for: card) {
            case .startingXI: status = "STARTING XI"; statusColor = LegendsPalette.green
            case .bench: status = "BENCH"; statusColor = LegendsPalette.purple
            case .reserves: status = "RESERVES"; statusColor = LegendsPalette.cyan
            }
        }
        let favourite = store.isFavourite(card.id)
        let duplicate = owned && store.isExactDuplicate(card)
        let finalSeason = owned && store.isFinalSeason(card)
        let accent = card.rarity.tint

        return Button {
            Haptics.tap()
            selectedCard = card
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(accent.opacity(owned ? 1 : 0.35), lineWidth: 2))
                        .overlay(alignment: .bottomTrailing) {
                            if !owned {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(LegendsPalette.navy.opacity(0.75))
                                    .clipShape(Circle())
                            }
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.position.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(owned ? 1 : 0.4))
                            .clipShape(Capsule())
                        Text(card.rarity.rawValue.uppercased())
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(owned ? "\(store.effectiveOverall(for: card))" : "??")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(owned ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.4))
                        Text("OVR")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    }
                }

                Text(owned ? card.name : "???")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(owned ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    FlagView(nationality: card.nation, width: 12)
                    Text("\(card.era.rawValue.uppercased()) · \(card.season)")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text(status)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)

                if favourite || duplicate || finalSeason {
                    HStack(spacing: 4) {
                        if favourite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(LegendsPalette.gold)
                                .accessibilityLabel("Favourite")
                        }
                        if duplicate {
                            Text("DUP")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(LegendsPalette.orange)
                                .clipShape(Capsule())
                                .accessibilityLabel("Exact duplicate")
                        }
                        if finalSeason {
                            Text("FINAL SEASON")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(LegendsPalette.orange)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(owned ? 0.45 : 0.18), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.players.card.\(card.id)")
        .accessibilityLabel(cardAccessibilityLabel(card, owned: owned, retired: retired, signed: signed,
                                                    status: status, favourite: favourite,
                                                    duplicate: duplicate, finalSeason: finalSeason))
    }

    private func cardAccessibilityLabel(_ card: LegendsCard, owned: Bool, retired: Bool, signed: Bool,
                                        status: String, favourite: Bool, duplicate: Bool, finalSeason: Bool) -> String {
        var parts: [String]
        if owned {
            parts = [card.name, card.position.rawValue, "\(store.effectiveOverall(for: card)) overall",
                     card.rarity.rawValue, card.era.rawValue, status]
        } else {
            parts = ["Unowned \(card.rarity.rawValue) card, \(card.era.rawValue)"]
        }
        if retired { parts.append("Career complete") }
        if favourite { parts.append("Favourite") }
        if duplicate { parts.append("Exact duplicate") }
        if finalSeason { parts.append("Final season") }
        return parts.joined(separator: ", ")
    }
}
