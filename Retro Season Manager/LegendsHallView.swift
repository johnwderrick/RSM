//
//  LegendsHallView.swift
//  Retro Season Manager
//
//  Permanent museum for completed player careers. A Hall entry survives
//  removing the retired card from the active collection and is independent
//  from any later generation of the same database player.
//
//  Presentation only: every figure shown here is derived from the
//  authoritative `store.profile.legendsHall` entries and the existing
//  favourites store. Sorting and filtering are view-local and never
//  reorder or mutate the stored Hall itself.
//

import SwiftUI

struct LegendsHallView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var selectedEntry: LegendsHallEntry? = nil
    @State private var searchText = ""
    @State private var favouritesOnly = false
    @State private var sort: HallSort = .retirement

    /// The user-facing sort options. The raw values double as the menu
    /// button labels and stay stable for UI tests.
    enum HallSort: String, CaseIterable, Identifiable {
        case peak = "PEAK OVR"
        case appearances = "APPEARANCES"
        case goals = "GOALS"
        case seasons = "SEASONS AT CLUB"
        case retirement = "RETIREMENT SEASON"
        case legacy = "LEGACY"
        case name = "NAME"
        var id: String { rawValue }
    }

    private var allEntries: [LegendsHallEntry] { store.profile.legendsHall }

    private var entries: [LegendsHallEntry] {
        allEntries.filter { entry in
            (!favouritesOnly || store.isFavourite(entry.cardID)) &&
            (searchText.isEmpty || entry.playerName.localizedCaseInsensitiveContains(searchText))
        }.sorted { lhs, rhs in
            switch sort {
            case .peak: return lhs.highestOverall > rhs.highestOverall
            case .appearances: return lhs.appearances > rhs.appearances
            case .goals: return lhs.goals > rhs.goals
            case .seasons: return lhs.seasonsAtClub > rhs.seasonsAtClub
            case .retirement: return lhs.retiredSeason > rhs.retiredSeason
            case .legacy: return lhs.legacyScore > rhs.legacyScore
            case .name: return lhs.playerName < rhs.playerName
            }
        }
    }

    /// All-time ranking used by the Hall of Fame podium. Deliberately
    /// independent from the list filter/sort so the podium is always the
    /// stable "greatest of the club" view.
    private var ranking: [LegendsHallEntry] {
        allEntries.sorted { $0.legacyScore > $1.legacyScore }
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "LEGENDS HALL",
                         subtitle: "\(allEntries.count) COMPLETED CAREERS",
                         icon: "rosette", accent: LegendsPalette.gold,
                         onBack: onBack, currentNav: .hall, onNavigate: onNavigate) {
            VStack(alignment: .leading, spacing: 14) {
                summaryBand
                controls
                if allEntries.isEmpty {
                    emptyState
                } else if entries.isEmpty {
                    filteredEmptyState
                } else {
                    podium
                    careerList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Facilities-style containment: the identifier describes the
            // destination without swallowing the identities of the controls
            // nested inside it.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("legends.hall.screen")
        }
        .sheet(item: $selectedEntry) { entry in
            LegendsHallEntryDetailView(store: store, entry: entry)
        }
    }

    // MARK: - Summary band

    private var summaryBand: some View {
        let hall = allEntries
        let appearances = hall.reduce(0) { $0 + $1.appearances }
        let goals = hall.reduce(0) { $0 + $1.goals }
        let honours = hall.reduce(0) { $0 + $1.honours.count }
        let clubLegends = hall.filter(\.isClubLegend).count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "rosette")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LegendsPalette.goldDeep)
                Text("HALL OF FAME AT A GLANCE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                summaryStat(value: "\(hall.count)", label: "CAREERS",
                            accessible: "\(hall.count) completed careers",
                            identifier: "legends.hall.summary.careers")
                summaryStat(value: "\(clubLegends)", label: "CLUB LEGENDS",
                            accessible: "\(clubLegends) club legends",
                            identifier: "legends.hall.summary.clubLegends")
                summaryStat(value: "\(appearances)", label: "APPEARANCES",
                            accessible: "\(appearances) total appearances",
                            identifier: "legends.hall.summary.appearances")
                summaryStat(value: "\(goals)", label: "GOALS",
                            accessible: "\(goals) total goals",
                            identifier: "legends.hall.summary.goals")
                summaryStat(value: "\(honours)", label: "HONOURS",
                            accessible: "\(honours) career honours",
                            identifier: "legends.hall.summary.honours")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.gold.opacity(0.32), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.hall.summary")
    }

    private func summaryStat(value: String, label: String, accessible: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.goldDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessible)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("SEARCH ALUMNI", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("legends.hall.search")
                if !searchText.isEmpty || favouritesOnly {
                    Button {
                        Haptics.tap()
                        searchText = ""
                        favouritesOnly = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("legends.hall.clearSearch")
                    .accessibilityLabel("Clear search and filters")
                }
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    favouritesOnly.toggle()
                } label: {
                    Label("FAVOURITES", systemImage: favouritesOnly ? "star.fill" : "star")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(favouritesOnly ? LegendsPalette.goldDeep : LegendsPalette.navy.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(favouritesOnly ? LegendsPalette.goldWash : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(
                            favouritesOnly ? LegendsPalette.gold : LegendsPalette.navy.opacity(0.22),
                            lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("legends.hall.favourites")
                .accessibilityLabel(favouritesOnly ? "Favourites filter on" : "Favourites filter off")
                .accessibilityAddTraits(favouritesOnly ? .isSelected : [])

                Spacer(minLength: 8)

                Menu {
                    ForEach(HallSort.allCases) { option in
                        Button(option.rawValue) { sort = option }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 9, weight: .black))
                        Text("SORT: \(sort.rawValue)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LegendsPalette.navy.opacity(0.22), lineWidth: 1))
                }
                .accessibilityIdentifier("legends.hall.sort")
            }
        }
    }

    // MARK: - Podium

    private var podium: some View {
        let top = Array(ranking.prefix(3))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LegendsPalette.goldDeep)
                Text("GREATEST RSM LEGENDS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                Spacer(minLength: 4)
                Text("BY LEGACY SCORE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            }
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                    podiumCard(index: index, entry: entry)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LegendsPalette.goldWash)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.gold.opacity(0.45), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.hall.podium")
    }

    private func podiumCard(index: Int, entry: LegendsHallEntry) -> some View {
        let rankColors: [Color] = [LegendsPalette.gold, LegendsPalette.navy.opacity(0.55), LegendsPalette.orange]
        let rank = index + 1
        return VStack(spacing: 5) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(rankColors[index])
                .clipShape(Circle())
            PlayerPortraitView(name: entry.playerName, position: entry.position.broad,
                               nation: entry.nation, size: 46)
                .clipShape(Circle())
                .overlay(Circle().stroke(LegendsPalette.gold, lineWidth: 2))
            Text(entry.playerName)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            HStack(spacing: 3) {
                if entry.isClubLegend {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(LegendsPalette.goldDeep)
                }
                Text("\(entry.legacyScore)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(LegendsPalette.goldDeep)
            }
            Text("LEGACY")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LegendsPalette.gold.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank): \(entry.playerName), legacy score \(entry.legacyScore)\(entry.isClubLegend ? ", club legend" : "")")
        .accessibilityIdentifier("legends.hall.podium.\(rank)")
    }

    // MARK: - Career list

    /// Row-major pairing keeps wide layouts dense while staying a plain
    /// (non-lazy) hierarchy, so every career card stays materialised in the
    /// accessibility tree and the shared shell scroll never resets.
    @ViewBuilder
    private var careerList: some View {
        let cards = entries
        let columns = cardColumnCount
        if columns == 2 {
            VStack(spacing: 12) {
                ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { start in
                    HStack(alignment: .top, spacing: 12) {
                        careerCard(cards[start])
                        if start + 1 < cards.count {
                            careerCard(cards[start + 1])
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(cards) { entry in
                    careerCard(entry)
                }
            }
        }
    }

    private var cardColumnCount: Int {
        // One column keeps every figure readable on compact landscape
        // phones; wider layouts fit two card columns side by side.
        screenAllowsTwoColumns ? 2 : 1
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var screenAllowsTwoColumns: Bool {
        // Compact iPhone landscape (~667–740pt of content width) stays
        // single-column; iPad compatibility mode and larger phones get two.
        horizontalSizeClass == .regular
    }

    private func careerCard(_ entry: LegendsHallEntry) -> some View {
        Button {
            Haptics.tap()
            selectedEntry = entry
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PlayerPortraitView(name: entry.playerName, position: entry.position.broad,
                                   nation: entry.nation, size: 52)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(entry.isClubLegend ? LegendsPalette.gold : LegendsPalette.gold.opacity(0.5),
                                        lineWidth: entry.isClubLegend ? 3 : 2)
                    )
                    .overlay(alignment: .topTrailing) {
                        if entry.isClubLegend {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(LegendsPalette.gold)
                                .background(Circle().fill(.white))
                                .offset(x: 5, y: -5)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.playerName)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LegendsPalette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        Text("\(entry.position.rawValue) · \(entry.nation) · AGE \(entry.startingAge) → \(entry.finalAge)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if store.isFavourite(entry.cardID) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(LegendsPalette.goldDeep)
                        }
                    }
                    Text("CAREER S\(entry.signedSeason)–S\(entry.retiredSeason) · \(entry.seasonsAtClub) SEASONS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.goldDeep)
                    HStack(spacing: 8) {
                        stat("APP", entry.appearances)
                        stat("G", entry.goals)
                        stat("A", entry.assists)
                        if entry.cleanSheets > 0 { stat("CS", entry.cleanSheets) }
                    }

                    if !entry.honours.isEmpty || !entry.individualAwards.isEmpty {
                        HStack(spacing: 8) {
                            if !entry.honours.isEmpty {
                                Label("\(entry.honours.count)", systemImage: "trophy.fill")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(LegendsPalette.goldDeep)
                            }
                            if !entry.individualAwards.isEmpty {
                                Label("\(entry.individualAwards.count)", systemImage: "medal.fill")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(entry.honours.count) career honours, \(entry.individualAwards.count) individual awards")
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(entry.highestOverall)")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LegendsPalette.goldDeep)
                    Text("PEAK OVR")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    Text("\(entry.legacyScore)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(LegendsPalette.navy)
                    Text("LEGACY")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.5))
                }
            }
            .padding(13)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                entry.isClubLegend ? LegendsPalette.gold.opacity(0.7) : LegendsPalette.gold.opacity(0.3),
                lineWidth: entry.isClubLegend ? 1.6 : 1))
            .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.hall.card.\(entry.cardID)")
        .accessibilityLabel("\(entry.playerName), \(entry.position.rawValue), peak overall \(entry.highestOverall), \(entry.appearances) appearances, \(entry.goals) goals, legacy score \(entry.legacyScore)\(entry.isClubLegend ? ", club legend" : "")\(store.isFavourite(entry.cardID) ? ", favourited" : "")")
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy.opacity(0.85))
        }
        .font(.system(size: 8, weight: .black, design: .monospaced))
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LegendsPalette.blue)
                Text("THE HALL AWAITS ITS FIRST LEGEND")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
            }
            Text("Sign a player, build their career across the seasons, and when they retire their complete story — statistics, honours and legacy score — is preserved here forever.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
            Text("Every new card generation of the same player begins a separate career of its own.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.blue.opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.hall.empty")
    }

    private var filteredEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LegendsPalette.blue)
                Text("NO CAREERS MATCH")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
            }
            Text("No completed career matches the current search or favourites filter. Clear them to see the full Hall.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.7))
            Button {
                Haptics.tap()
                searchText = ""
                favouritesOnly = false
            } label: {
                Text("CLEAR SEARCH & FILTERS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(LegendsPalette.blueWash)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("legends.hall.clearFilters")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.blue.opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.hall.filteredEmpty")
    }
}

/// The permanent career page for one retired player: full statistics,
/// season-by-season history, milestones and club records.
private struct LegendsHallEntryDetailView: View {
    let store: LegendsStore
    let entry: LegendsHallEntry
    @Environment(\.dismiss) private var dismiss
    @State private var isFavourite = false

    private var records: [(LegendsClubRecordKind, LegendsClubRecordEntry)] {
        store.profile.clubRecords
            .filter { $0.value.playerName == entry.playerName }
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close career page")
                        .accessibilityIdentifier("legends.hall.detail.close")
                    }
                    VStack(spacing: 8) {
                        PlayerPortraitView(name: entry.playerName, position: entry.position.broad, nation: entry.nation, size: 84)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(entry.isClubLegend ? Retro.gold : Retro.accent, lineWidth: 3))
                        Text(entry.playerName)
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                        Text(entry.isClubLegend ? "★ CLUB LEGEND ★" : "\(entry.position.rawValue) · \(entry.nation)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(entry.isClubLegend ? Retro.gold : Retro.text.opacity(0.7))
                        Text("CAREER COMPLETE — LEGACY SCORE \(entry.legacyScore)")
                        Button {
                            isFavourite = store.toggleFavourite(cardID: entry.cardID) ? store.isFavourite(entry.cardID) : isFavourite
                        } label: {
                            Label(isFavourite ? "FAVOURITED" : "FAVOURITE", systemImage: isFavourite ? "star.fill" : "star")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("legends.hall.detail.favourite")
                    }

                    Panel(title: "CAREER TOTALS") {
                        VStack(alignment: .leading, spacing: 6) {
                            detailLine("Career", "S\(entry.signedSeason)–S\(entry.retiredSeason) · \(entry.seasonsAtClub) seasons")
                            detailLine("Age", "\(entry.startingAge) → \(entry.finalAge)")
                            detailLine("OVR", "\(entry.startingOverall) → \(entry.highestOverall) (final \(entry.finalOverall))")
                            detailLine("Appearances", "\(entry.appearances)")
                            detailLine("Goals / Assists", "\(entry.goals) / \(entry.assists)")
                            detailLine("Clean sheets", "\(entry.cleanSheets)")
                            detailLine("Trophies", "\(entry.trophies)")
                            detailLine("Legacy Score", "\(entry.legacyScore)")
                        }
                    }
                    .accessibilityIdentifier("legends.hall.detail.totals")

                    if let identity = entry.identityProfile {
                        Panel(title: "IDENTITY & PROFILE") {
                            VStack(alignment: .leading, spacing: 6) {
                                detailLine("Preferred foot", identity.identity.preferredFoot.rawValue)
                                detailLine("Archetype", identity.identity.archetype.rawValue)
                                Text(identity.identity.biography)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.65))
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.identity")
                    }

                    Panel(title: "FINAL CONDITION") {
                        VStack(alignment: .leading, spacing: 6) {
                            detailLine("Form", "\(entry.finalCondition.form)/100")
                            detailLine("Morale", "\(entry.finalCondition.morale)/100")
                            detailLine("Teamwork", "\(entry.finalCondition.teamwork)/100")
                            detailLine("Fame", "\(entry.finalCondition.fame)/100")
                        }
                    }
                    .accessibilityIdentifier("legends.hall.detail.condition")

                    Panel(title: "FINAL DEVELOPMENT PLAN") {
                        VStack(alignment: .leading, spacing: 6) {
                            detailLine("Focus", entry.finalTrainingPlan.focus.rawValue)
                            detailLine("Intensity", entry.finalTrainingPlan.intensity.rawValue)
                            detailLine("Training sessions", "\(entry.finalTrainingSessions)")
                            Text(entry.finalTrainingPlan.lastExplanation)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.65))
                        }
                    }
                    .accessibilityIdentifier("legends.hall.detail.training")

                    if !entry.honours.isEmpty {
                        Panel(title: "HONOURS") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(entry.honours) { honour in
                                    HStack(spacing: 6) {
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Retro.gold)
                                        Text("\(honour.type) · \(honour.competitionName)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.9))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Spacer()
                                        Text("S\(honour.season)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.honours")
                    }

                    if !entry.individualAwards.isEmpty {
                        Panel(title: "INDIVIDUAL AWARDS") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(entry.individualAwards) { award in
                                    HStack(spacing: 6) {
                                        Image(systemName: "medal.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Retro.gold)
                                        Text(award.type)
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.9))
                                        Spacer()
                                        Text("S\(award.season) · \(award.value)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.awards")
                    }

                    if entry.identityProfile != nil {
                        let attributes = entry.finalDetailedAttributes == .zero
                            ? (entry.identityProfile?.attributes ?? .zero)
                            : entry.finalDetailedAttributes
                        Panel(title: "FINAL DETAILED ATTRIBUTES") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(LegendsAttributeGroup.allCases, id: \.self) { group in
                                    Text(group.rawValue)
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(Retro.gold)
                                    ForEach(attributes.values(in: group), id: \.0) { item in
                                        HStack {
                                            Text(item.0).font(.system(.caption2, design: .monospaced))
                                            Spacer()
                                            Text("\(item.1)").font(.system(.caption2, design: .monospaced).bold())
                                        }
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.attributes")
                    }

                    if !entry.careerHistory.isEmpty {
                        Panel(title: "SEASON-BY-SEASON") {
                            VStack(spacing: 6) {
                                ForEach(Array(entry.careerHistory.reversed()), id: \.season) { record in
                                    HStack(spacing: 8) {
                                        Text("S\(record.season)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.8))
                                            .frame(width: 30, alignment: .leading)
                                        Text("AGE \(record.age)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                            .frame(width: 46, alignment: .leading)
                                        Text("\(record.appearances) APP")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                        Text("\(record.goals) G · \(record.assists) A")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                        Spacer()
                                        Text("\(record.overallAtStart) → \(record.overallAtEnd)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(record.overallAtEnd > record.overallAtStart ? Retro.emerald
                                                             : (record.overallAtEnd < record.overallAtStart ? Retro.warning : Retro.gold))
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.history")
                    }

                    if !entry.milestones.isEmpty {
                        Panel(title: "MILESTONES") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(entry.milestones).sorted { $0.rawValue < $1.rawValue }, id: \.self) { milestone in
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(milestone == .clubLegend ? Retro.gold : Retro.emerald)
                                        Text(milestone.rawValue)
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.9))
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.milestones")
                    }

                    if !records.isEmpty {
                        Panel(title: "CLUB RECORDS") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(records, id: \.0) { kind, record in
                                    HStack {
                                        Image(systemName: kind.icon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Retro.gold)
                                        Text(kind.displayName)
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.85))
                                        Spacer()
                                        Text("\(record.value)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.highlight)
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("legends.hall.detail.records")
                    }
                }
                .padding(16)
            }
        }
        .onAppear { isFavourite = store.isFavourite(entry.cardID) }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.65))
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
        }
    }
}
