//
//  LegendsCollectionView.swift
//  Retro Season Manager
//
//  The Collection Book (Phase 3) — browses the full card database and
//  tracks which cards are owned. Ownership comes from opening packs
//  (Phase 4, LegendsStore+Packs.swift).
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
    @State private var showingFilters = false
    @State private var showingComparison = false
    @State private var comparisonCard: LegendsCard? = nil
    @State private var releaseCandidate: LegendsCard? = nil
    @State private var releaseFavouriteConfirmation = false

    private var cards: [LegendsCard] {
        let retiredIDs = Set(store.profile.legendsHall.map(\.cardID))
        return LegendsCardDatabase.all.filter { card in
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

    var body: some View {
        LegendsMenuShell(store: store, title: browserMode == .activeClub ? "ACTIVE CLUB" : "PLAYER COLLECTION", subtitle: "\(ownedCount) OWNED · \(signedCount) ACTIVE · \(unsignedCount) UNSIGNED · \(retiredCount) LEGENDS", icon: browserMode == .activeClub ? "person.3.fill" : "square.stack.3d.up.fill", accent: browserMode == .activeClub ? LegendsPalette.blue : LegendsPalette.orange, onBack: onBack, currentNav: .collection, onNavigate: onNavigate, scrollContent: false) {
            VStack(spacing: 10) {
                browserModePicker
                statusPicker
                if browserMode == .activeClub { activeClubSummary }
                eraPicker
                rarityPicker
                capacityBanner
                toolbar
                if showingFilters { filterPanel }
                activeFilterSummary
                cardGrid
            }
        }
        .sheet(item: $selectedCard) { card in
            LegendsPlayerDetailView(store: store, card: card)
        }
    }

    private var browserModePicker: some View {
        Picker("Player area", selection: $browserMode) {
            ForEach(LegendsPlayerBrowserMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
        }
        .pickerStyle(.segmented)
        .tint(LegendsPalette.blue)
        .padding(.horizontal)
        .accessibilityLabel("Player area")
    }

    private var statusPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(LegendsCollectionStatus.allCases) { status in
                    Button { selectedStatus = status } label: {
                        Text(status.rawValue).font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(selectedStatus == status ? .white : LegendsPalette.navy)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selectedStatus == status ? LegendsPalette.blue : .white)
                            .clipShape(Capsule())
                    }.buttonStyle(PressableButtonStyle())
                }
            }.padding(.horizontal)
        }
    }

    private var activeClubSummary: some View {
        HStack(spacing: 18) {
            summaryMetric("PLAYERS", signedCount)
            summaryMetric("AVERAGE AGE", averageAge)
            summaryMetric("AVERAGE OVR", averageOverall)
            Spacer()
        }.padding(.horizontal)
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
        VStack(alignment: .leading, spacing: 1) { Text("\(value)").font(.system(size: 15, weight: .black, design: .rounded)); Text(title).font(.system(size: 8, weight: .black, design: .monospaced)) }
            .foregroundStyle(LegendsPalette.navy)
    }

    private var eraPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                eraChip(title: "All", isSelected: selectedEra == nil) { selectedEra = nil }
                ForEach(LegendsEra.allCases, id: \.self) { era in
                    eraChip(title: era.rawValue, isSelected: selectedEra == era) { selectedEra = era }
                }
                Divider().frame(height: 20)
                ownedOnlyChip
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

    private var ownedOnlyChip: some View {
        Button {
            Haptics.tap()
            ownedOnly.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: ownedOnly ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text("OWNED ONLY")
            }
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(ownedOnly ? Retro.background : Retro.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(ownedOnly ? Retro.accent : Retro.panel)
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var rarityPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                rarityChip(title: "All", tint: Retro.text, isSelected: selectedRarity == nil) { selectedRarity = nil }
                ForEach(LegendsRarity.allCases.sorted { $0.tier < $1.tier }, id: \.self) { rarity in
                    rarityChip(title: rarity.rawValue, tint: rarity.tint, isSelected: selectedRarity == rarity) { selectedRarity = rarity }
                }
            }
            .padding(.horizontal)
        }
    }

    private func rarityChip(title: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(isSelected ? Retro.background : tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? tint : Retro.panel)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(tint.opacity(isSelected ? 0 : 0.5), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var collectionFilterBar: some View {
        let nations = Array(Set(LegendsCardDatabase.all.map(\.nation))).sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Menu {
                    Button("All nations") { selectedNation = nil }
                    ForEach(nations, id: \.self) { nation in
                        Button(nation) { selectedNation = nation }
                    }
                } label: {
                    filterPill(selectedNation ?? "NATION", active: selectedNation != nil, tint: LegendsPalette.blue)
                }
                Menu {
                    Button("Any overall") { minimumOverall = 0 }
                    ForEach([70, 80, 85, 90, 95], id: \.self) { rating in
                        Button("\(rating)+ OVR") { minimumOverall = rating }
                    }
                } label: {
                    filterPill(minimumOverall == 0 ? "OVR" : "OVR \(minimumOverall)+", active: minimumOverall > 0, tint: LegendsPalette.orange)
                }
                Button {
                    highPotentialOnly.toggle()
                } label: {
                    filterPill("POTENTIAL", active: highPotentialOnly, tint: LegendsPalette.green)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal)
        }
    }

    private func filterPill(_ title: String, active: Bool, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
            Image(systemName: active ? "checkmark" : "chevron.down")
                .font(.system(size: 8, weight: .black))
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .foregroundStyle(active ? Retro.background : Retro.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(active ? tint : Retro.panel)
        .clipShape(Capsule())
    }

    private var capacityBanner: some View {
        HStack {
            Image(systemName: "archivebox.fill")
            Text("LIBRARY \(unsignedCount) / \(store.unsignedLibraryCapacity)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
            Spacer()
            if store.isUnsignedLibraryFull { Text("FULL").foregroundStyle(.red) }
        }
        .foregroundStyle(LegendsPalette.navy)
        .padding(10)
        .background(store.isUnsignedLibraryFull ? Color.red.opacity(0.1) : LegendsPalette.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .accessibilityLabel("Unsigned player library capacity, \(unsignedCount) of \(store.unsignedLibraryCapacity)")
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { showingFilters.toggle() } label: {
                Label(showingFilters ? "HIDE FILTERS" : "FILTERS", systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("legends.library.filters")
            Spacer()
            Menu("SORT") {
                ForEach(LegendsLibrarySort.allCases) { sort in Button(sort.rawValue) { } }
            }
            .accessibilityIdentifier("legends.library.sort")
        }
        .font(.system(size: 10, weight: .black, design: .monospaced))
        .padding(.horizontal)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("SEARCH PLAYERS", text: .constant(""))
                .textFieldStyle(.roundedBorder)
            Toggle("FAVOURITES ONLY", isOn: .constant(false))
            Toggle("EXACT DUPLICATES", isOn: .constant(false))
            Button("RESET FILTERS") {
                selectedStatus = .all; selectedEra = nil; selectedRarity = nil; selectedNation = nil
                minimumOverall = 0; highPotentialOnly = false; ownedOnly = false
            }
            .accessibilityIdentifier("legends.library.resetFilters")
        }
        .padding(.horizontal)
    }

    private var activeFilterSummary: some View {
        Text("\(cards.count) PLAYERS")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    private var cardGrid: some View {
        ScrollView {
            if cards.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(cards) { card in
                        cardTile(card)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
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
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func cardTile(_ card: LegendsCard) -> some View {
        return Button {
            Haptics.tap()
            selectedCard = card
        } label: {
            LegendsPlayerCardView(store: store, card: card, variant: .grid, showsStatus: true)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct LegendsCardDetailSheet: View {
    let store: LegendsStore
    let card: LegendsCard
    @Environment(\.dismiss) private var dismiss

    private var owned: Bool { store.profile.ownedCardIDs.contains(card.id) }
    private var effectiveOverall: Int { store.effectiveOverall(for: card) }
    private var age: Int { store.effectiveAge(for: card) }
    private var retired: Bool { owned && store.isRetired(card) }
    private var signed: Bool { owned && store.isCareerStarted(card) && !retired }
    private var career: LegendsPlayerCareer? { store.careerState(for: card) }
    private var upgradeLevel: Int { store.profile.cardUpgrades[card.id] ?? 0 }
    private var duplicateProgress: Int { store.profile.duplicateProgress[card.id] ?? 0 }
    private var agingPenalty: Int { store.agingPenalty(for: card) }
    private var foundInPacks: [LegendsPack] { LegendsPackDatabase.all.filter { $0.pool(card) } }

    /// The effective OVR is a single number — this spells out what
    /// actually went into it, since a player couldn't otherwise tell how
    /// much came from upgrades versus how much aging has already cost them.
    private var overallBreakdownText: String {
        var text = "Base \(card.overall)"
        if upgradeLevel > 0 { text += " + \(upgradeLevel) upgrade" }
        if agingPenalty > 0 { text += " − \(agingPenalty) aging" }
        if upgradeLevel > 0 || agingPenalty > 0 { text += " = \(effectiveOverall)" }
        return text
    }

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
                    if owned {
                        PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 76)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(card.rarity.tint, lineWidth: 3))
                    } else {
                        ZStack {
                            Circle().fill(card.rarity.tint.opacity(0.85)).frame(width: 76, height: 76)
                            Text(card.position.rawValue)
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundStyle(Retro.background)
                        }
                    }
                    Text(owned ? card.name : "???")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Text("\(card.rarity.rawValue.uppercased()) · \(card.era.rawValue.uppercased())")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(card.rarity.tint)
                        .tracking(1)
                    if owned {
                        Text(retired ? "CAREER COMPLETE" : (signed ? "ACTIVE CAREER" : "COLLECTION · CAREER NOT STARTED"))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(retired ? Retro.warning : (signed ? Retro.emerald : Retro.highlight))
                        HStack(spacing: 5) {
                            FlagView(nationality: card.nation, width: 16)
                            Text("\(card.club) · \(card.nation) · \(card.season)")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.7))
                        }
                        Text(retired ? "RETIRED AT AGE \(age)" : "AGE \(age)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(retired ? Retro.warning : Retro.text.opacity(0.6))
                    }
                }

                if owned {
                    if retired {
                        Panel(title: "CAREER COMPLETE") {
                            if let career {
                                Text("Career record preserved in Legends Hall · \(career.appearances) appearances · \(career.goals) goals")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Retro.warning)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            Text("This player has retired and can no longer be fielded. Open packs for a new generation.")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.warning)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    } else if signed {
                        Panel(title: "ACTIVE CAREER") {
                            if let career {
                                HStack {
                                    Text("\(career.appearances) APPS · \(career.goals) G · \(career.assists) A")
                                    Spacer()
                                    Text(store.potentialDescription(for: card))
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.emerald)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Panel(title: "COLLECTION") {
                            Text("Unsigned · age frozen at \(card.age). Sign this player from Player Library to start their career.")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.highlight)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Panel(title: "ATTRIBUTES") {
                        VStack(spacing: 8) {
                            statBar("OVR", effectiveOverall)
                            Text(overallBreakdownText)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.55))
                            Text("SCOUTING: \(store.potentialDescription(for: card))")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.highlight)
                            statBar("PAC", card.pace)
                            statBar("SHO", card.shooting)
                            statBar("PAS", card.passing)
                            statBar("DRI", card.dribbling)
                            statBar("DEF", card.defending)
                            statBar("PHY", card.physical)
                        }
                    }

                    // Both duplicateProgress/cardUpgrades already existed
                    // and persisted correctly — they just weren't shown
                    // anywhere, so a player upgrading a card via
                    // duplicates had no way to see it happening.
                    Panel(title: "UPGRADE PROGRESS") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Duplicates toward next upgrade")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                Spacer()
                                Text("\(duplicateProgress)/\(LegendsStore.duplicatesPerUpgrade)")
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(Retro.highlight)
                            }
                            HStack {
                                Text("Upgrade level")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                Spacer()
                                Text(upgradeLevel >= LegendsStore.maxCardUpgrade
                                     ? "MAX (+\(upgradeLevel) OVR)"
                                     : "\(upgradeLevel)/\(LegendsStore.maxCardUpgrade) (+\(upgradeLevel) OVR)")
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(Retro.gold)
                            }
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
                        Text("Open packs to add this card to your collection.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }

                if !foundInPacks.isEmpty {
                    Panel(title: "FOUND IN") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(foundInPacks) { pack in
                                Text("• \(pack.name)")
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.85))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
