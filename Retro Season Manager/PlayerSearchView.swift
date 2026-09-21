//
//  PlayerSearchView.swift
//  Retro Season Manager
//
//  Career scouting centre. All data and actions remain authoritative in
//  GameStore; this view only organises and presents them.
//

import SwiftUI

private struct SearchResult: Identifiable {
    let player: Player
    let clubIndex: Int?
    let target: TransferTarget?
    var id: UUID { player.id }
}

private enum ScoutScope: String, CaseIterable {
    case discovered = "DISCOVERED"
    case allPlayers = "ALL PLAYERS"
    case shortlist = "SHORTLIST"

    var slug: String {
        switch self {
        case .discovered: return "discovered"
        case .allPlayers: return "all"
        case .shortlist: return "shortlist"
        }
    }
}

private enum ScoutAgeFilter: String, CaseIterable {
    case all = "ANY AGE", youth = "U21", prime = "22–27", experienced = "28+"
    func includes(_ age: Int) -> Bool {
        switch self {
        case .all: return true
        case .youth: return age <= 21
        case .prime: return (22...27).contains(age)
        case .experienced: return age >= 28
        }
    }
}

private enum ScoutAbilityFilter: String, CaseIterable {
    case all = "ANY OVR", firstTeam = "70+ OVR", elite = "80+ OVR"
    func includes(_ rating: Int) -> Bool {
        switch self {
        case .all: return true
        case .firstTeam: return rating >= 70
        case .elite: return rating >= 80
        }
    }
}

private enum ScoutPotentialFilter: String, CaseIterable {
    case all = "ANY POTENTIAL", high = "80+ POT", elite = "88+ POT", unknown = "NOT FULLY SCOUTED"
}

private enum ScoutSort: String, CaseIterable {
    case rating = "OVR: HIGH TO LOW"
    case potential = "POTENTIAL"
    case youngest = "AGE: YOUNGEST"
    case value = "VALUE: HIGH TO LOW"
    case name = "NAME"
}

struct PlayerSearchView: View {
    let store: GameStore

    @State private var scope: ScoutScope = .discovered
    @State private var query = ""
    @State private var positionFilter: DetailedPosition?
    @State private var ageFilter: ScoutAgeFilter = .all
    @State private var abilityFilter: ScoutAbilityFilter = .all
    @State private var potentialFilter: ScoutPotentialFilter = .all
    @State private var nationalityFilter = "ALL NATIONS"
    @State private var sort: ScoutSort = .rating
    @State private var profile: ProfileContext?
    @State private var message: String?
    @State private var showingReports = false

    private static let resultCap = 80
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var marketTargetsByPlayerID: [UUID: TransferTarget] {
        Dictionary(store.transferMarket.map { ($0.player.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var baseResults: [SearchResult] {
        let targets = marketTargetsByPlayerID
        switch scope {
        case .discovered:
            return store.transferMarket.map {
                SearchResult(player: $0.player, clubIndex: $0.sellingClubIndex, target: $0)
            }
        case .allPlayers:
            return store.clubs.enumerated().flatMap { clubIndex, club in
                club.players.map { SearchResult(player: $0, clubIndex: clubIndex, target: targets[$0.id]) }
            }
        case .shortlist:
            return store.shortlistedResults.map {
                SearchResult(player: $0.player, clubIndex: $0.clubIndex, target: targets[$0.player.id])
            }
        }
    }

    private var nationalities: [String] {
        Array(Set(baseResults.map(\.player.nationality))).sorted()
    }

    private func report(for result: SearchResult) -> ScoutReport? {
        guard let target = result.target else { return nil }
        return store.scoutedReports[target.id]
    }

    private func matchesPotential(_ result: SearchResult) -> Bool {
        let potential = report(for: result)?.potential
        switch potentialFilter {
        case .all: return true
        case .high: return (potential ?? 0) >= 80
        case .elite: return (potential ?? 0) >= 88
        case .unknown: return potential == nil
        }
    }

    private var filteredResults: [SearchResult] {
        let filtered = baseResults.filter { result in
            let player = result.player
            if !trimmedQuery.isEmpty && !player.name.localizedCaseInsensitiveContains(trimmedQuery) { return false }
            if let positionFilter, player.detailedPosition != positionFilter { return false }
            if !ageFilter.includes(player.age) || !abilityFilter.includes(player.rating) { return false }
            if nationalityFilter != "ALL NATIONS" && player.nationality != nationalityFilter { return false }
            return matchesPotential(result)
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .rating:
                return lhs.player.rating == rhs.player.rating ? lhs.player.name < rhs.player.name : lhs.player.rating > rhs.player.rating
            case .potential:
                let left = report(for: lhs)?.potential ?? -1
                let right = report(for: rhs)?.potential ?? -1
                return left == right ? lhs.player.rating > rhs.player.rating : left > right
            case .youngest:
                return lhs.player.age == rhs.player.age ? lhs.player.rating > rhs.player.rating : lhs.player.age < rhs.player.age
            case .value:
                return lhs.player.value == rhs.player.value ? lhs.player.rating > rhs.player.rating : lhs.player.value > rhs.player.value
            case .name:
                return lhs.player.name.localizedCaseInsensitiveCompare(rhs.player.name) == .orderedAscending
            }
        }
    }

    private var shownResults: [SearchResult] { Array(filteredResults.prefix(Self.resultCap)) }
    private var activeAssignments: Int { store.scoutingDue.count }

    private var activeFilterCount: Int {
        var count = 0
        if !trimmedQuery.isEmpty { count += 1 }
        if positionFilter != nil { count += 1 }
        if ageFilter != .all { count += 1 }
        if abilityFilter != .all { count += 1 }
        if potentialFilter != .all { count += 1 }
        if nationalityFilter != "ALL NATIONS" { count += 1 }
        return count
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    if let message { feedbackBand(message) }
                    missionCard
                    controlsCard
                    resultsSection(columns: geometry.size.width >= 760 ? 2 : 1)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier("career.scout.scroll")
            .background(CareerPalette.canvas)
        }
        .background(CareerPalette.canvas)
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { message = $0 }
        }
        .sheet(isPresented: $showingReports) {
            ScoutReportsSheet(store: store) { context in
                showingReports = false
                profile = context
            }
        }
    }

    private var summaryBand: some View {
        HStack(spacing: 16) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("SCOUTING CENTRE")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                Text("LEVEL \(store.userClub.scoutingNetworkLevel) NETWORK · \(store.transferWindowStatus.uppercased())")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            summaryStat("TARGETS", "\(store.transferMarket.count)")
            summaryStat("REPORTS", "\(store.scoutedReports.count)")
            summaryStat("WATCHING", "\(activeAssignments)")
            summaryStat("SHORTLIST", "\(store.shortlistedPlayerIDs.count)")
        }
        .foregroundStyle(CareerPalette.ink)
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("career.scout.summary")
        .accessibilityLabel("Scouting Centre, Targets \(store.transferMarket.count), Reports \(store.scoutedReports.count), Watching \(activeAssignments), Shortlist \(store.shortlistedPlayerIDs.count)")
    }

    private func summaryStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            Text(value).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
        }
        .frame(minWidth: 48)
    }

    private func feedbackBand(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(text).lineLimit(2)
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Retro.highlight.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("career.scout.feedback")
    }

    private var missionCard: some View {
        scoutCard(title: "NETWORK MISSIONS", subtitle: "EXPAND THE DISCOVERED PLAYER POOL", symbol: "globe.europe.africa.fill") {
            HStack(spacing: 8) {
                missionButton("SCOUT WORLD", symbol: "globe") { store.scoutTheWorld(youthOnly: false) }
                missionButton("SCOUT YOUTH", symbol: "graduationcap.fill") { store.scoutTheWorld(youthOnly: true) }
                Spacer(minLength: 6)
                Button {
                    Haptics.tap()
                    showingReports = true
                } label: {
                    Label("REPORTS \(store.scoutedReports.count)", systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 11).padding(.vertical, 9)
                        .foregroundStyle(CareerPalette.ink)
                        .background(CareerPalette.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.20)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.scout.reports")
            }
        }
    }

    private func missionButton(_ title: String, symbol: String, action: @escaping () -> String) -> some View {
        Button {
            Haptics.impact()
            message = action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .padding(.horizontal, 11).padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(store.transferWindowOpen ? CareerPalette.line : CareerPalette.mutedInk.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!store.transferWindowOpen)
        .accessibilityIdentifier("career.scout.mission.\(title == "SCOUT WORLD" ? "world" : "youth")")
    }

    private var controlsCard: some View {
        scoutCard(title: "PLAYER SEARCH", subtitle: "FILTER THE LIVE CAREER DATABASE", symbol: "line.3.horizontal.decrease.circle.fill") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    ForEach(ScoutScope.allCases, id: \.self) { candidate in
                        Button {
                            Haptics.tap()
                            scope = candidate
                        } label: {
                            Text(candidate.rawValue)
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(scope == candidate ? .white : CareerPalette.mutedInk)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(scope == candidate ? CareerPalette.line : CareerPalette.canvas)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(CareerPalette.line.opacity(scope == candidate ? 0 : 0.18)))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("career.scout.scope.\(candidate.slug)")
                        .accessibilityAddTraits(scope == candidate ? [.isSelected] : [])
                    }
                    Spacer()
                    Text("\(filteredResults.count) FOUND")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(CareerPalette.line)
                        TextField("Search player name", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                            .accessibilityIdentifier("career.scout.search")
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(CareerPalette.mutedInk)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10).frame(height: 36)
                    .background(CareerPalette.canvas).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.16)))

                    filterMenu(title: positionFilter?.rawValue ?? "POSITION", identifier: "position") {
                        Button("ANY POSITION") { positionFilter = nil }
                        ForEach(DetailedPosition.allCases, id: \.self) { role in Button(role.fullName) { positionFilter = role } }
                    }
                    filterMenu(title: ageFilter.rawValue, identifier: "age") {
                        ForEach(ScoutAgeFilter.allCases, id: \.self) { item in Button(item.rawValue) { ageFilter = item } }
                    }
                    filterMenu(title: abilityFilter.rawValue, identifier: "ability") {
                        ForEach(ScoutAbilityFilter.allCases, id: \.self) { item in Button(item.rawValue) { abilityFilter = item } }
                    }
                }

                HStack(spacing: 8) {
                    filterMenu(title: potentialFilter.rawValue, identifier: "potential") {
                        ForEach(ScoutPotentialFilter.allCases, id: \.self) { item in Button(item.rawValue) { potentialFilter = item } }
                    }
                    filterMenu(title: nationalityFilter, identifier: "nation") {
                        Button("ALL NATIONS") { nationalityFilter = "ALL NATIONS" }
                        ForEach(nationalities, id: \.self) { nation in Button(nation) { nationalityFilter = nation } }
                    }
                    filterMenu(title: sort.rawValue, identifier: "sort") {
                        ForEach(ScoutSort.allCases, id: \.self) { item in Button(item.rawValue) { sort = item } }
                    }
                    Spacer()
                    if activeFilterCount > 0 {
                        Button("RESET \(activeFilterCount)") { resetFilters() }
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange).buttonStyle(.plain)
                            .accessibilityIdentifier("career.scout.filters.reset")
                    }
                }
            }
        }
    }

    private func filterMenu<Content: View>(title: String, identifier: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down")
            }
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(CareerPalette.ink)
            .padding(.horizontal, 9).frame(height: 36)
            .background(CareerPalette.canvas).clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.16)))
        }
        .accessibilityIdentifier("career.scout.filter.\(identifier)")
    }

    private func resetFilters() {
        query = ""
        positionFilter = nil
        ageFilter = .all
        abilityFilter = .all
        potentialFilter = .all
        nationalityFilter = "ALL NATIONS"
    }

    @ViewBuilder
    private func resultsSection(columns: Int) -> some View {
        let results = shownResults
        scoutCard(title: scope == .shortlist ? "SHORTLIST" : "SCOUTING DATABASE",
                  subtitle: resultSubtitle, symbol: "person.2.crop.square.stack.fill") {
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: scope == .shortlist ? "star.slash" : "magnifyingglass")
                        .font(.system(size: 24, weight: .bold)).foregroundStyle(CareerPalette.line)
                    Text(scope == .shortlist ? "YOUR SHORTLIST IS EMPTY" : "NO PLAYERS MATCH THESE FILTERS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                    Text(scope == .shortlist
                         ? "Star a player from the database or their profile to track them here."
                         : "Clear one or more filters to widen the search.")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
                .accessibilityIdentifier("career.scout.empty")
            } else {
                VStack(spacing: 10) {
                    ForEach(0..<Int(ceil(Double(results.count) / Double(columns))), id: \.self) { row in
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < results.count { resultCard(results[index]) }
                                else { Color.clear.frame(maxWidth: .infinity) }
                            }
                        }
                    }
                }
                if filteredResults.count > Self.resultCap {
                    Text("SHOWING THE TOP \(Self.resultCap) OF \(filteredResults.count) · REFINE FILTERS TO NARROW THE LIST")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
            }
        }
    }

    private var resultSubtitle: String {
        switch scope {
        case .discovered: return "LIVE TRANSFER TARGETS AND SCOUTING STATUS"
        case .allPlayers: return "SEARCH EVERY CLUB IN THE CAREER WORLD"
        case .shortlist: return "PLAYERS MARKED FOR CONTINUED TRACKING"
        }
    }

    private func resultCard(_ result: SearchResult) -> some View {
        let player = result.player
        let clubName = result.clubIndex.flatMap {
            $0 >= 0 && store.clubs.indices.contains($0) ? store.clubs[$0].name : nil
        } ?? "Free Agent"
        let report = report(for: result)
        let state = scoutState(for: result)
        let shortlisted = store.isShortlisted(player.id)

        return VStack(alignment: .leading, spacing: 9) {
            Button {
                Haptics.tap()
                profile = profileContext(for: result)
            } label: {
                HStack(spacing: 10) {
                    PlayerPortraitView(name: player.name, position: player.position, age: player.age,
                                       nation: player.nationality, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink).lineLimit(1)
                        Text("\(player.detailedPosition.rawValue) · AGE \(player.age) · \(clubName)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk).lineLimit(1)
                        HStack(spacing: 4) {
                            FlagView(nationality: player.nationality, width: 14)
                            Text(player.nationality)
                                .font(.system(size: 7, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                        }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(player.rating)")
                            .font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.line)
                        Text("OVR")
                            .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("career.scout.card.\(player.id.uuidString)")
            .accessibilityLabel("\(player.name), \(player.detailedPosition.fullName), age \(player.age), \(player.nationality), \(clubName), overall \(player.rating), \(state.label)")

            HStack(spacing: 6) {
                stateBadge(state)
                Spacer()
                Text(result.target.map { formatMoney($0.askingPrice) }
                     ?? (player.contractYears <= 0 ? "FREE" : formatMoney(store.negotiatedFee(for: player))))
                    .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
            }

            if let report {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("POTENTIAL ~\(report.potential)").fontWeight(.black)
                        Spacer()
                        Text("\(report.confidence)% CONFIDENCE").foregroundStyle(CareerPalette.line)
                    }
                    Text(report.verdict).lineLimit(2)
                    Text("EST. \(formatMoney(report.valueRangeLow))–\(formatMoney(report.valueRangeHigh))")
                        .foregroundStyle(CareerPalette.mutedInk)
                }
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(CareerPalette.line.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 7))
            } else if state == .unscouted {
                Text("Potential and value confidence are hidden until a report is filed.")
                    .font(.system(size: 7, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            }

            HStack(spacing: 7) {
                if let target = result.target, case .unscouted = store.scoutState(for: target) {
                    Button {
                        Haptics.tap()
                        store.scout(target)
                        message = "Scout sent to watch \(player.name)."
                    } label: {
                        Label("ASSIGN SCOUT", systemImage: "binoculars.fill")
                    }
                    .accessibilityIdentifier("career.scout.assign.\(player.id.uuidString)")
                }
                Button {
                    Haptics.tap()
                    store.toggleShortlist(player.id)
                    message = shortlisted ? "\(player.name) removed from your shortlist." : "\(player.name) added to your shortlist."
                } label: {
                    Label(shortlisted ? "SHORTLISTED" : "SHORTLIST", systemImage: shortlisted ? "star.fill" : "star")
                }
                .accessibilityIdentifier("career.scout.shortlist.\(player.id.uuidString)")
                Spacer()
                Button("VIEW PROFILE") { profile = profileContext(for: result) }
                    .accessibilityIdentifier("career.scout.profile.\(player.id.uuidString)")
            }
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .buttonStyle(ScoutCompactButtonStyle())
        }
        .padding(11).frame(maxWidth: .infinity, alignment: .topLeading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 11)
            .stroke(shortlisted ? Retro.highlight.opacity(0.75) : CareerPalette.line.opacity(0.14),
                    lineWidth: shortlisted ? 1.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private enum CardScoutState: Equatable {
        case unscouted, inProgress, scouted
        var label: String {
            switch self {
            case .unscouted: return "Not scouted"
            case .inProgress: return "Scouting in progress"
            case .scouted: return "Full report available"
            }
        }
    }

    private func scoutState(for result: SearchResult) -> CardScoutState {
        guard let target = result.target else { return .unscouted }
        switch store.scoutState(for: target) {
        case .unscouted: return .unscouted
        case .inProgress: return .inProgress
        case .scouted: return .scouted
        }
    }

    private func stateBadge(_ state: CardScoutState) -> some View {
        let color: Color = state == .scouted ? CareerPalette.line : (state == .inProgress ? .orange : CareerPalette.mutedInk)
        return Text(state == .scouted ? "FULL REPORT" : (state == .inProgress ? "SCOUT WATCHING" : "UNSCOUTED"))
            .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(color.opacity(0.10)).clipShape(Capsule())
    }

    private func profileContext(for result: SearchResult) -> ProfileContext {
        if let target = result.target { return .market(target) }
        if result.clubIndex == store.userClubIndex { return .squad(result.player) }
        // A shortlisted free agent carries a nil club index (see the
        // store's shortlistedResults doc comment); profile actions on
        // him sign from free agency, so anchor the context at the user club.
        return .scouted(result.player, clubIndex: result.clubIndex ?? store.userClubIndex)
    }

    private func scoutCard<Content: View>(title: String, subtitle: String, symbol: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: symbol).foregroundStyle(CareerPalette.line)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
                    Text(subtitle).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 2)
    }
}

private struct ScoutCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(CareerPalette.ink)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(CareerPalette.canvas.opacity(configuration.isPressed ? 0.55 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(CareerPalette.line.opacity(0.18)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
