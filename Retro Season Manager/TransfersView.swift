//
//  TransfersView.swift
//  Retro Season Manager
//
//  The Transfer Centre: market, shortlist, live negotiations, squad,
//  youth and club business in the accepted Career light-card language.
//  All data and actions remain authoritative in GameStore; this view only
//  organises and presents them.
//

import SwiftUI

// MARK: - Transfer context

/// What a player profile sheet is showing, and the action it offers.
enum ProfileContext: Identifiable {
    case squad(Player)
    case market(TransferTarget)
    /// A player from any other club, found via search — can be bid on.
    case scouted(Player, clubIndex: Int)

    var id: UUID {
        switch self {
        case .squad(let player):  return player.id
        case .market(let target): return target.id
        case .scouted(let player, _): return player.id
        }
    }
}

// MARK: - Season ledger (restyled sheet)

/// This season's income/expenditure, in order — transfers, wages sold,
/// gate receipts, investments, prize money, and the season-opening reset.
struct LedgerView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var income: Int { store.seasonLedger.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    private var expenditure: Int { store.seasonLedger.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SEASON LEDGER")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                        Text("EVERY POUND IN AND OUT THIS SEASON")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Label("CLOSE", systemImage: "xmark")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(CareerPalette.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(CareerPalette.line.opacity(0.22)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.transfers.ledger.close")
                }
                HStack(spacing: 10) {
                    ledgerStat("INCOME", formatMoney(income), CareerPalette.line)
                    ledgerStat("EXPENDITURE", formatMoney(expenditure), Retro.warning)
                    ledgerStat("NET", formatMoney(income + expenditure), Retro.gold)
                }
                if store.seasonLedger.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(CareerPalette.line)
                        Text("No transactions yet this season.")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 26)
                    .background(CareerPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(store.seasonLedger) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.category)
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(CareerPalette.ink)
                                        Text(entry.detail)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(CareerPalette.mutedInk)
                                    }
                                    Spacer()
                                    Text(formatMoney(entry.amount))
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundStyle(entry.amount >= 0 ? CareerPalette.line : Retro.warning)
                                }
                                .padding(10)
                                .background(CareerPalette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
    }

    private func ledgerStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(CareerPalette.line.opacity(0.14)))
    }
}

// MARK: - Transfer Centre

private enum TransferTab: String, CaseIterable {
    case market, shortlist, negotiations, squad, youth, club

    var label: String {
        switch self {
        case .market:       return "MARKET"
        case .shortlist:    return "SHORTLIST"
        case .negotiations: return "NEGOTIATIONS"
        case .squad:        return "SQUAD"
        case .youth:        return "YOUTH"
        case .club:         return "CLUB"
        }
    }

    var slug: String { rawValue }
}

private enum MarketAgeFilter: String, CaseIterable {
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

private enum MarketAbilityFilter: String, CaseIterable {
    case all = "ANY OVR", firstTeam = "70+ OVR", elite = "80+ OVR"
    func includes(_ rating: Int) -> Bool {
        switch self {
        case .all: return true
        case .firstTeam: return rating >= 70
        case .elite: return rating >= 80
        }
    }
}

private enum MarketPriceFilter: String, CaseIterable {
    case all = "ANY PRICE", affordable = "AFFORDABLE"
}

private enum MarketSort: String, CaseIterable {
    case rating = "OVR: HIGH TO LOW"
    case priceAsc = "PRICE: LOW TO HIGH"
    case priceDesc = "PRICE: HIGH TO LOW"
    case youngest = "AGE: YOUNGEST"
    case name = "NAME"
}

struct TransfersView: View {
    let store: GameStore

    @State private var tab: TransferTab = .market
    @State private var query = ""
    @State private var positionFilter: DetailedPosition?
    @State private var ageFilter: MarketAgeFilter = .all
    @State private var abilityFilter: MarketAbilityFilter = .all
    @State private var priceFilter: MarketPriceFilter = .all
    @State private var sort: MarketSort = .rating

    @State private var profile: ProfileContext?
    @State private var message: String?
    @State private var showingLedger = false
    @State private var personalTermsDeal: PendingTransferDeal?
    @State private var withdrawDeal: PendingTransferDeal?
    @State private var counterTarget: TransferOffer?

    private static let priceChipWidth: CGFloat = 74
    /// Presentation cap on rendered market cards. The generated market can
    /// hold 200+ targets (three surplus players at every club in the
    /// pyramid); sorting, search and the filters reach the rest. Mirrors
    /// the accepted Scouting Centre's result cap.
    private static let marketCap = 40
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Derived data

    private var marketByPlayerID: [UUID: TransferTarget] {
        Dictionary(store.transferMarket.map { ($0.player.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var wageHeadroomOK: Bool { store.userClub.wageBill < store.userClub.wageBudget }

    /// Real affordability, mirroring the authoritative guards on
    /// `buyPlayer`/`proposeBid`: fee fits the budget AND the wage fits.
    private func budgetBlocked(_ target: TransferTarget) -> Bool {
        guard let _ = target.sellingClubIndex else { return false }
        return store.userClub.transferBudget < target.askingPrice
    }

    private func wageBlocked(_ target: TransferTarget) -> Bool {
        store.userClub.wageBill + target.player.wage > store.userClub.wageBudget
    }

    private func isAffordable(_ target: TransferTarget) -> Bool {
        !budgetBlocked(target) && !wageBlocked(target)
    }

    private var filteredMarket: [TransferTarget] {
        let filtered = store.transferMarket.filter { target in
            let player = target.player
            if !trimmedQuery.isEmpty && !player.name.localizedCaseInsensitiveContains(trimmedQuery) { return false }
            if let positionFilter, player.detailedPosition != positionFilter { return false }
            if !ageFilter.includes(player.age) || !abilityFilter.includes(player.rating) { return false }
            if priceFilter == .affordable && !isAffordable(target) { return false }
            return true
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .rating:
                return lhs.player.rating == rhs.player.rating
                    ? lhs.player.name < rhs.player.name
                    : lhs.player.rating > rhs.player.rating
            case .priceAsc:
                return lhs.askingPrice == rhs.askingPrice
                    ? lhs.player.rating > rhs.player.rating
                    : lhs.askingPrice < rhs.askingPrice
            case .priceDesc:
                return lhs.askingPrice == rhs.askingPrice
                    ? lhs.player.rating > rhs.player.rating
                    : lhs.askingPrice > rhs.askingPrice
            case .youngest:
                return lhs.player.age == rhs.player.age
                    ? lhs.player.rating > rhs.player.rating
                    : lhs.player.age < rhs.player.age
            case .name:
                return lhs.player.name.localizedCaseInsensitiveCompare(rhs.player.name) == .orderedAscending
            }
        }
    }

    private var shortlistResults: [(player: Player, clubIndex: Int?, target: TransferTarget?)] {
        let targets = marketByPlayerID
        return store.shortlistedResults.map { ($0.player, $0.clubIndex, targets[$0.player.id]) }
    }

    /// `shortlistedResults` marks a free agent / unattached player with a
    /// nil club index (see the store's doc comment) — never a valid slot
    /// into `clubs`.
    private func isFreeAgentResult(_ clubIndex: Int?) -> Bool { clubIndex == nil }

    private var activeFilterCount: Int {
        var count = 0
        if !trimmedQuery.isEmpty { count += 1 }
        if positionFilter != nil { count += 1 }
        if ageFilter != .all { count += 1 }
        if abilityFilter != .all { count += 1 }
        if priceFilter != .all { count += 1 }
        return count
    }

    private var negotiationCount: Int { store.pendingTransferDeals.count + store.pendingOffers.count }

    // MARK: Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    if let message { feedbackBand(message) }
                    tabBar
                    switch tab {
                    case .market:
                        // A curated panel loses its point once the user
                        // starts filtering — hide it while any filter is
                        // active so the market reflects the filters alone
                        // (presentation-only; no store impact).
                        if activeFilterCount == 0, !store.suggestedTransferTargets(limit: 3).isEmpty {
                            suggestedPanel(store.suggestedTransferTargets(limit: 3))
                        }
                        filterCard
                        marketSection(columns: geometry.size.width >= 760 ? 2 : 1)
                    case .shortlist:
                        shortlistSection(columns: geometry.size.width >= 760 ? 2 : 1)
                    case .negotiations:
                        negotiationsSection
                    case .squad:
                        squadSection
                    case .youth:
                        youthSection
                    case .club:
                        clubSection
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier("career.transfers.scroll")
            .background(CareerPalette.canvas)
        }
        .background(CareerPalette.canvas)
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { message = $0 }
        }
        .sheet(item: $personalTermsDeal) { deal in
            PersonalTermsSheet(store: store, deal: deal) { message = $0 }
        }
        .sheet(item: $withdrawDeal) { deal in
            ConfirmActionSheet(
                title: "Break off talks with \(deal.player.name)?",
                message: "\(deal.player.name) returns to \(deal.sellingClubName) and this deal is off. No fee has been paid. This can't be undone.",
                confirmLabel: "WITHDRAW",
                financialNote: "Agreed fee \(formatMoney(deal.agreedFee)) will not be spent"
            ) {
                message = store.withdrawPendingDeal(deal)
            }
        }
        .sheet(item: $counterTarget) { offer in
            CounterSellOfferSheet(store: store, offer: offer) { result in
                message = result
                counterTarget = nil
            }
        }
    }

    // MARK: Summary band

    private var summaryBand: some View {
        HStack(spacing: 14) {
            Image(systemName: "sterlingsign.circle.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("TRANSFER CENTRE")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text(windowSubtitle)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(store.isDeadlineDayRush ? Retro.warning : CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            summaryStat("BUDGET", formatMoney(store.userClub.transferBudget))
            summaryStat("SQUAD", "\(store.userClub.players.count)/30")
            summaryStat("TARGETS", "\(store.transferMarket.count)")
            summaryStat("DEALS", "\(store.pendingTransferDeals.count)")
            summaryStat("OFFERS", "\(store.pendingOffers.count)")
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.transfers.summary")
        .accessibilityLabel("""
        Transfer Centre. Transfer budget \(formatMoney(store.userClub.transferBudget)). \
        Squad \(store.userClub.players.count) of 30. \(store.transferMarket.count) market targets. \
        \(store.pendingTransferDeals.count) deals in progress. \(store.pendingOffers.count) offers received. \
        \(store.shortlistedPlayerIDs.count) shortlisted. \(store.transferWindowStatus).
        """)
    }

    private var windowSubtitle: String {
        let base = store.transferWindowStatus.uppercased()
        return "TRANSFER WINDOW \(base)"
    }

    private func summaryStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 42)
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
        .background(Retro.highlight.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("career.transfers.feedback")
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 7) {
            ForEach(TransferTab.allCases, id: \.self) { candidate in
                tabChip(candidate)
            }
            Spacer(minLength: 0)
        }
    }

    private func tabChip(_ candidate: TransferTab) -> some View {
        let isSelected = tab == candidate
        let count: Int? = {
            switch candidate {
            case .shortlist: return store.shortlistedPlayerIDs.count
            case .negotiations: return negotiationCount
            case .youth: return store.youthProspects.count
            default: return nil
            }
        }()
        return Button {
            Haptics.tap()
            tab = candidate
        } label: {
            HStack(spacing: 4) {
                Text(candidate.label)
                if let count, count > 0 {
                    Text("\(count)")
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : CareerPalette.line.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(isSelected ? .white : CareerPalette.mutedInk)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(isSelected ? CareerPalette.line : CareerPalette.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CareerPalette.line.opacity(isSelected ? 0 : 0.20)))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("career.transfers.tab.\(candidate.slug)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Shared card chrome

    private func sectionCard<Content: View>(title: String, subtitle: String, symbol: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: symbol).foregroundStyle(CareerPalette.line)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                    Text(subtitle)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
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

    // MARK: Market

    private func suggestedPanel(_ suggestions: [TransferTarget]) -> some View {
        sectionCard(title: "SUGGESTED TARGETS", subtitle: "WOULD PLUG A THIN SPOT IN THE SQUAD, AND FITS THE BUDGET",
                    symbol: "lightbulb.fill") {
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.player.id) { target in
                    targetCard(target, context: "suggested")
                }
            }
        }
    }

    private var filterCard: some View {
        sectionCard(title: "MARKET FILTERS", subtitle: "PRESENTATION ONLY — THE STORED SCHEDULE OF TARGETS NEVER CHANGES",
                    symbol: "line.3.horizontal.decrease.circle.fill") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(CareerPalette.line)
                        TextField("Search player name", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                            .accessibilityIdentifier("career.transfers.filter.search")
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
                        ForEach(DetailedPosition.allCases, id: \.self) { role in
                            Button(role.fullName) { positionFilter = role }
                        }
                    }
                    filterMenu(title: ageFilter.rawValue, identifier: "age") {
                        ForEach(MarketAgeFilter.allCases, id: \.self) { item in
                            Button(item.rawValue) { ageFilter = item }
                        }
                    }
                    filterMenu(title: abilityFilter.rawValue, identifier: "ability") {
                        ForEach(MarketAbilityFilter.allCases, id: \.self) { item in
                            Button(item.rawValue) { abilityFilter = item }
                        }
                    }
                }
                HStack(spacing: 8) {
                    filterMenu(title: priceFilter.rawValue, identifier: "price") {
                        ForEach(MarketPriceFilter.allCases, id: \.self) { item in
                            Button(item.rawValue) { priceFilter = item }
                        }
                    }
                    filterMenu(title: sort.rawValue, identifier: "sort") {
                        ForEach(MarketSort.allCases, id: \.self) { item in
                            Button(item.rawValue) { sort = item }
                        }
                    }
                    Spacer()
                    Text("\(filteredMarket.count) FOUND")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                    if activeFilterCount > 0 {
                        Button("RESET \(activeFilterCount)") { resetFilters() }
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("career.transfers.filter.reset")
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
        .accessibilityIdentifier("career.transfers.filter.\(identifier)")
    }

    private func resetFilters() {
        query = ""
        positionFilter = nil
        ageFilter = .all
        abilityFilter = .all
        priceFilter = .all
    }

    private func marketSection(columns: Int) -> some View {
        sectionCard(title: "TRANSFER MARKET",
                    subtitle: store.transferWindowOpen
                        ? "LIVE TARGETS · BID, NEGOTIATE OR LOAN"
                        : "WINDOW CLOSED · SIGNINGS RESUME NEXT SEASON",
                    symbol: "arrow.left.arrow.right.circle.fill") {
            if filteredMarket.isEmpty {
                emptyState(
                    symbol: store.transferMarket.isEmpty ? "tray" : "magnifyingglass",
                    title: store.transferMarket.isEmpty ? "NO PLAYERS AVAILABLE RIGHT NOW" : "NO PLAYERS MATCH THESE FILTERS",
                    detail: store.transferMarket.isEmpty
                        ? "The market refreshes as clubs reshape their squads — check back soon."
                        : "Clear one or more filters to widen the search."
                )
            } else {
                VStack(spacing: 10) {
                    let shown = Array(filteredMarket.prefix(Self.marketCap))
                    ForEach(0..<Int(ceil(Double(shown.count) / Double(columns))), id: \.self) { row in
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < shown.count { targetCard(shown[index], context: "market") }
                                else { Color.clear.frame(maxWidth: .infinity) }
                            }
                        }
                    }
                }
                if filteredMarket.count > Self.marketCap {
                    Text("SHOWING THE TOP \(Self.marketCap) OF \(filteredMarket.count) · REFINE FILTERS TO NARROW THE LIST")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
            }
        }
    }

    // MARK: Target card

    private func targetCard(_ target: TransferTarget, context: String) -> some View {
        let player = target.player
        let clubName = sellerName(target)
        let state = store.scoutState(for: target)
        var report: ScoutReport?
        if case .scouted(let value) = state { report = value }
        var inProgress = false
        if case .inProgress = state { inProgress = true }
        let shortlisted = store.isShortlisted(player.id)
        let overBudget = budgetBlocked(target)
        let blockedByWage = wageBlocked(target)
        let isFree = target.sellingClubIndex == nil

        return VStack(alignment: .leading, spacing: 9) {
            // The whole identity block is one tappable, screen-readable
            // element — keeps the accessibility tree small and fast.
            Button {
                Haptics.tap()
                profile = .market(target)
            } label: {
                HStack(spacing: 10) {
                    PlayerPortraitView(name: player.name, position: player.position, age: player.age,
                                       nation: player.nationality, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                            .lineLimit(1)
                        Text("\(player.detailedPosition.rawValue) · AGE \(player.age) · \(clubName)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            FlagView(nationality: player.nationality, width: 14)
                            Text(player.nationality)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(CareerPalette.mutedInk)
                        }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(player.rating)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.line)
                        Text("OVR")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("career.transfers.card.\(player.id.uuidString)")
            .accessibilityLabel("""
            \(player.name), \(player.detailedPosition.fullName), age \(player.age), \(player.nationality), \
            \(clubName), overall \(player.rating). \
            \(report != nil ? "Full scout report available, potential around \(report!.potential)." :
                              inProgress ? "Scout watching, report pending." : "Not scouted yet."). \
            \(isFree ? "Free agent." : "Asking price \(formatMoney(target.askingPrice)).") \
            \(overBudget ? "Over transfer budget." : blockedByWage ? "Wage budget would be exceeded." : "Affordable.")
            """)

            HStack(spacing: 6) {
                if report != nil {
                    scoutBadge("FULL REPORT", color: CareerPalette.line)
                } else if inProgress {
                    scoutBadge("SCOUT WATCHING", color: .orange)
                } else {
                    scoutBadge("UNSCOUTED", color: CareerPalette.mutedInk)
                }
                if shortlisted { scoutBadge("SHORTLISTED", color: Retro.gold) }
                Spacer()
                if overBudget {
                    scoutBadge("OVER BUDGET", color: Retro.warning)
                } else if blockedByWage {
                    scoutBadge("WAGE BLOCKED", color: .orange)
                }
                Text(isFree ? "FREE" : formatMoney(target.askingPrice))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .frame(minWidth: Self.priceChipWidth, alignment: .trailing)
            }

            if let report = report {
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
            }

            HStack(spacing: 7) {
                if case .unscouted = store.scoutState(for: target) {
                    Button {
                        Haptics.tap()
                        store.scout(target)
                        message = "Scout sent to watch \(player.name)."
                    } label: {
                        Label("ASSIGN SCOUT", systemImage: "binoculars.fill")
                    }
                    .accessibilityIdentifier("career.transfers.scout.\(player.id.uuidString)")
                }
                Button {
                    Haptics.tap()
                    store.toggleShortlist(player.id)
                    message = shortlisted ? "\(player.name) removed from your shortlist."
                                          : "\(player.name) added to your shortlist."
                } label: {
                    Label(shortlisted ? "SHORTLISTED" : "SHORTLIST", systemImage: shortlisted ? "star.fill" : "star")
                }
                .accessibilityIdentifier("career.transfers.shortlist.\(player.id.uuidString)")
                Spacer()
                Button("VIEW PROFILE") { Haptics.tap(); profile = .market(target) }
                    .accessibilityIdentifier("career.transfers.profile.\(player.id.uuidString)")
            }
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .buttonStyle(TransferCompactButtonStyle())
        }
        .padding(11).frame(maxWidth: .infinity, alignment: .topLeading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 11)
            .stroke(shortlisted ? Retro.gold.opacity(0.75) : CareerPalette.line.opacity(0.14),
                    lineWidth: shortlisted ? 1.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .opacity((overBudget || blockedByWage) ? 0.82 : 1)
        .accessibilityHint(context == "suggested" ? "Suggested because he fills a thin position" : "")
    }

    private func scoutBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    // MARK: Shortlist

    private func shortlistSection(columns: Int) -> some View {
        sectionCard(title: "SHORTLIST", subtitle: "PLAYERS MARKED FOR CONTINUED TRACKING", symbol: "star.fill") {
            let entries = shortlistResults
            if entries.isEmpty {
                emptyState(symbol: "star.slash",
                           title: "YOUR SHORTLIST IS EMPTY",
                           detail: "Star a market target, a scouted player or anyone in the search database to track them here.")
            } else {
                VStack(spacing: 10) {
                    ForEach(0..<Int(ceil(Double(entries.count) / Double(columns))), id: \.self) { row in
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < entries.count {
                                    shortlistCard(entries[index].player,
                                                  clubIndex: entries[index].clubIndex,
                                                  target: entries[index].target)
                                } else {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func shortlistCard(_ player: Player, clubIndex: Int?, target: TransferTarget?) -> some View {
        let clubName: String
        if isFreeAgentResult(clubIndex) {
            clubName = "Free Agent"
        } else if clubIndex == store.userClubIndex {
            clubName = store.userClub.name
        } else if let clubIndex, store.clubs.indices.contains(clubIndex) {
            clubName = store.clubs[clubIndex].name
        } else {
            clubName = "Free Agent"
        }
        var report: ScoutReport?
        if let target, case .scouted(let value) = store.scoutState(for: target) { report = value }

        return VStack(alignment: .leading, spacing: 9) {
            Button {
                Haptics.tap()
                if let target {
                    profile = .market(target)
                } else if clubIndex == store.userClubIndex {
                    profile = .squad(player)
                } else if isFreeAgentResult(clubIndex) {
                    profile = .scouted(player, clubIndex: store.userClubIndex)
                } else {
                    profile = .scouted(player, clubIndex: clubIndex ?? store.userClubIndex)
                }
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
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(CareerPalette.mutedInk)
                        }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(player.rating)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.line)
                        Text("OVR")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("career.transfers.card.\(player.id.uuidString)")
            .accessibilityLabel("\(player.name), \(player.detailedPosition.fullName), age \(player.age), \(clubName), overall \(player.rating), shortlisted\(report != nil ? ", potential around \(report!.potential)" : "")")

            HStack(spacing: 6) {
                if let report { scoutBadge("POT ~\(report.potential)", color: CareerPalette.line) }
                Spacer()
                Text(target.map { $0.sellingClubIndex == nil ? "FREE" : formatMoney($0.askingPrice) }
                     ?? (player.contractYears <= 0 ? "FREE" : formatMoney(store.negotiatedFee(for: player))))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
            }

            HStack(spacing: 7) {
                Button {
                    Haptics.tap()
                    store.toggleShortlist(player.id)
                    message = "\(player.name) removed from your shortlist."
                } label: {
                    Label("REMOVE", systemImage: "star.slash")
                }
                .accessibilityIdentifier("career.transfers.shortlist.\(player.id.uuidString)")
                Spacer()
                Button("VIEW PROFILE") {
                    Haptics.tap()
                    if let target {
                        profile = .market(target)
                    } else if clubIndex == store.userClubIndex {
                        profile = .squad(player)
                    } else if isFreeAgentResult(clubIndex) {
                        profile = .scouted(player, clubIndex: store.userClubIndex)
                    } else {
                        profile = .scouted(player, clubIndex: clubIndex ?? store.userClubIndex)
                    }
                }
                .accessibilityIdentifier("career.transfers.profile.\(player.id.uuidString)")
            }
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .buttonStyle(TransferCompactButtonStyle())
        }
        .padding(11).frame(maxWidth: .infinity, alignment: .topLeading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Retro.gold.opacity(0.75), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    // MARK: Negotiations

    private var negotiationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.pendingTransferDeals.isEmpty && store.pendingOffers.isEmpty && store.playersOnLoanFromUser().isEmpty {
                sectionCard(title: "NEGOTIATIONS", subtitle: "EVERY LIVE DEAL IN ONE PLACE", symbol: "handshake") {
                    emptyState(symbol: "handshake",
                               title: "NOTHING IN PROGRESS",
                               detail: "Deals you agree and bids you receive will show up here.")
                }
            }
            if !store.pendingTransferDeals.isEmpty {
                sectionCard(title: "PENDING SIGNINGS (\(store.pendingTransferDeals.count))",
                            subtitle: "FEE AGREED — MEDICAL AND PERSONAL TERMS TO FOLLOW",
                            symbol: "doc.text.magnifyingglass") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.pendingTransferDeals) { deal in
                            dealRow(deal)
                        }
                    }
                }
            }
            if !store.pendingOffers.isEmpty {
                sectionCard(title: "OFFERS RECEIVED (\(store.pendingOffers.count))",
                            subtitle: "BIDS FROM OTHER CLUBS FOR YOUR PLAYERS",
                            symbol: "square.and.arrow.down.on.square") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.pendingOffers) { offer in
                            offerRow(offer)
                        }
                    }
                }
            }
            let loanedOut = store.playersOnLoanFromUser()
            if !loanedOut.isEmpty {
                sectionCard(title: "OUT ON LOAN (\(loanedOut.count))",
                            subtitle: "WAGES OFF THE BILL UNTIL THE LOAN ENDS",
                            symbol: "arrow.uturn.right.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(loanedOut, id: \.player.id) { entry in
                            loanRow(entry.player, clubIndex: entry.clubIndex)
                        }
                    }
                }
            }
        }
    }

    private func dealRow(_ deal: PendingTransferDeal) -> some View {
        HStack(spacing: 9) {
            PlayerAvatarView(name: deal.player.name, position: deal.player.position, size: 34,
                             age: deal.player.age, nation: deal.player.nationality)
            VStack(alignment: .leading, spacing: 1) {
                Text(deal.player.name)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(deal.sellingClubName) · \(formatMoney(deal.agreedFee)) fee agreed")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text(deal.isReady ? "READY TO TALK TERMS" : "MEDICAL & PAPERWORK IN PROGRESS")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(deal.isReady ? CareerPalette.line : .orange)
            }
            Spacer()
            if deal.isReady {
                Button {
                    Haptics.tap()
                    personalTermsDeal = deal
                } label: {
                    Text("TALK TERMS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 9).padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(CareerPalette.line)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.transfers.deal.\(deal.id.uuidString).terms")
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
            }
            Button {
                Haptics.tap()
                withdrawDeal = deal
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("career.transfers.deal.\(deal.id.uuidString).withdraw")
            .accessibilityLabel("Withdraw from the deal for \(deal.player.name)")
        }
        .padding(9)
        .background(CareerPalette.canvas.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func offerRow(_ offer: TransferOffer) -> some View {
        let buyerName = store.clubs.indices.contains(offer.fromClubIndex) ? store.clubs[offer.fromClubIndex].name : "Unknown club"
        return HStack(spacing: 9) {
            if let player = store.currentPlayer(offer.playerID) {
                PlayerAvatarView(name: player.name, position: player.position, size: 34,
                                 age: player.age, nation: player.nationality)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(offer.playerName)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(buyerName) bid \(formatMoney(offer.amount))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                Text("AWAITING YOUR RESPONSE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Button {
                    message = store.acceptOffer(offer)
                } label: {
                    Text("ACCEPT")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(CareerPalette.line)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.transfers.offer.\(offer.id.uuidString).accept")
                Button {
                    Haptics.tap()
                    counterTarget = offer
                } label: {
                    Text("COUNTER")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .foregroundStyle(CareerPalette.ink)
                        .background(CareerPalette.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.transfers.offer.\(offer.id.uuidString).counter")
                Button {
                    Haptics.tap()
                    store.rejectOffer(offer)
                    message = "Bid for \(offer.playerName) rejected."
                } label: {
                    Text("REJECT")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .foregroundStyle(Retro.warning)
                        .background(Retro.warning.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.transfers.offer.\(offer.id.uuidString).reject")
            }
        }
        .padding(9)
        .background(CareerPalette.canvas.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func loanRow(_ player: Player, clubIndex: Int) -> some View {
        let hostName = store.clubs.indices.contains(clubIndex) ? store.clubs[clubIndex].name : "another club"
        return HStack(spacing: 9) {
            PlayerAvatarView(name: player.name, position: player.position, size: 34,
                             age: player.age, nation: player.nationality)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("at \(hostName)")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer()
            Button {
                Haptics.tap()
                message = store.recallFromLoan(player)
            } label: {
                Text("RECALL")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .foregroundStyle(CareerPalette.ink)
                    .background(CareerPalette.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("career.transfers.loan.\(player.id.uuidString).recall")
        }
        .padding(9)
        .background(CareerPalette.canvas.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: Squad

    private var sortedSquad: [Player] {
        store.userClub.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    private var squadSection: some View {
        sectionCard(title: "MY SQUAD (\(store.userClub.players.count))",
                    subtitle: "TAP A PLAYER FOR PROFILE, CONTRACT AND SELLING OPTIONS",
                    symbol: "person.3.fill") {
            VStack(spacing: 6) {
                ForEach(sortedSquad) { player in
                    squadRow(player)
                }
            }
        }
    }

    private func squadRow(_ player: Player) -> some View {
        Button {
            Haptics.tap()
            profile = .squad(player)
        } label: {
            HStack(spacing: 10) {
                PlayerPortraitView(name: player.name, position: player.position, age: player.age,
                                   nation: player.nationality, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.name)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .lineLimit(1)
                    Text("\(player.careerPositionLabel) · AGE \(player.age) · \(player.rating) OVR")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
                if player.isTransferListed {
                    scoutBadge("LISTED", color: Retro.gold)
                }
                Spacer()
                Text(formatMoney(player.value))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(CareerPalette.canvas.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .opacity(player.isAvailable ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.transfers.squad.\(player.id.uuidString)")
        .accessibilityLabel("\(player.name), \(player.careerPositionLabel), age \(player.age), overall \(player.rating), value \(formatMoney(player.value))\(player.isTransferListed ? ", transfer listed" : "")\(player.isAvailable ? "" : ", currently unavailable")")
    }

    // MARK: Youth

    private var youthSection: some View {
        sectionCard(title: "YOUTH ACADEMY", subtitle: "PROSPECTS FROM YOUR ACADEMY — PROMOTE THE BEST, RELEASE THE REST",
                    symbol: "graduationcap.fill") {
            if store.youthProspects.isEmpty {
                emptyState(symbol: "graduationcap",
                           title: "NO PROSPECTS RIGHT NOW",
                           detail: "The next intake arrives next season — a bigger youth academy brings more, and better, prospects.")
            } else {
                VStack(spacing: 6) {
                    ForEach(store.youthProspects) { prospect in
                        youthRow(prospect)
                    }
                }
            }
        }
    }

    private func youthRow(_ prospect: Player) -> some View {
        HStack(spacing: 9) {
            Text(prospect.position.rawValue)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 34).padding(.vertical, 4)
                .background(CareerPalette.line)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 1) {
                Text(prospect.name)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("Age \(prospect.age) · \(prospect.rating) OVR")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer()
            Button {
                Haptics.tap()
                message = store.promoteYouth(prospect)
            } label: {
                Text("PROMOTE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(CareerPalette.line)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("career.transfers.youth.promote.\(prospect.id.uuidString)")
            Button {
                Haptics.tap()
                message = store.releaseYouth(prospect)
            } label: {
                Text("RELEASE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .foregroundStyle(CareerPalette.ink)
                    .background(CareerPalette.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("career.transfers.youth.release.\(prospect.id.uuidString)")
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(CareerPalette.canvas.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: Club (finances · board · infrastructure · staff)

    private var clubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            financesCard
            boardCard
            infrastructureCard
            staffCard
        }
    }

    private var financesCard: some View {
        sectionCard(title: "FINANCES", subtitle: "THE MONEY THE BOARD HAVE PLACED AT YOUR DISPOSAL",
                    symbol: "banknote.fill") {
            VStack(alignment: .leading, spacing: 6) {
                clubStat("Transfer budget", formatMoney(store.userClub.transferBudget), CareerPalette.line)
                clubStat("Wage bill / wk",
                         "\(formatMoney(store.userClub.wageBill)) of \(formatMoney(store.userClub.wageBudget))",
                         store.userClub.wageBill > store.userClub.wageBudget ? Retro.warning : CareerPalette.ink)
                clubStat("Squad size", "\(store.userClub.players.count) / 30", CareerPalette.ink)
                Button {
                    Haptics.tap()
                    showingLedger = true
                } label: {
                    Text("VIEW SEASON LEDGER")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(CareerPalette.line)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.transfers.ledger")
            }
        }
        .sheet(isPresented: $showingLedger) {
            LedgerView(store: store)
        }
    }

    private var boardCard: some View {
        sectionCard(title: "THE BOARD", subtitle: "CONFIDENCE, OBJECTIVES AND YOUR CONTRACT",
                    symbol: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Objective: \(store.boardObjective)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                careerConfidenceBar
                clubStat("Job security", store.jobSecurity,
                         store.boardConfidence >= 45 ? CareerPalette.line : Retro.gold)
                clubStat("Your contract",
                         "\(store.managerContractYears) year\(store.managerContractYears == 1 ? "" : "s") left",
                         store.managerContractYears <= 1 ? Retro.gold : CareerPalette.ink)
                Button {
                    Haptics.tap()
                    message = store.requestBudgetIncrease()
                } label: {
                    Text(store.daysUntilNextBudgetRequest.map { "ASK AGAIN IN \($0)D" } ?? "REQUEST MORE BUDGET")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(store.daysUntilNextBudgetRequest == nil ? CareerPalette.line : CareerPalette.canvas)
                        .foregroundStyle(store.daysUntilNextBudgetRequest == nil ? Color.white : CareerPalette.mutedInk)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(store.daysUntilNextBudgetRequest != nil)
                .accessibilityIdentifier("career.transfers.board.budget")
                if store.boardConfidence <= 40 {
                    Button {
                        Haptics.tap()
                        message = store.requestClearTheAirMeeting()
                    } label: {
                        Text(store.daysUntilNextClearAirMeeting.map { "ASK AGAIN IN \($0)D" } ?? "CALL CLEAR-THE-AIR MEETING")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(store.daysUntilNextClearAirMeeting == nil ? Retro.warning : CareerPalette.canvas)
                            .foregroundStyle(store.daysUntilNextClearAirMeeting == nil ? Color.white : CareerPalette.mutedInk)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(store.daysUntilNextClearAirMeeting != nil)
                    .accessibilityIdentifier("career.transfers.board.clearAir")
                }
            }
        }
    }

    private var careerConfidenceBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(CareerPalette.canvas)
                    Capsule().fill(confidenceColor(store.boardConfidence))
                        .frame(width: geo.size.width * CGFloat(store.boardConfidence) / 100)
                }
            }
            .frame(height: 8)
            Text("Confidence \(store.boardConfidence)% \(confidenceTrendArrow(store.boardConfidenceTrend))")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
        }
    }

    private var infrastructureCard: some View {
        sectionCard(title: "CLUB INFRASTRUCTURE", subtitle: "SPEND TRANSFER BUDGET ON LONG-TERM ADVANTAGE",
                    symbol: "building.2.fill") {
            HStack(alignment: .top, spacing: 12) {
                investmentCard(
                    title: "YOUTH ACADEMY",
                    level: store.userClub.youthFacilityLevel,
                    cost: store.youthUpgradeCost(forClubIndex: store.userClubIndex),
                    detail: "Bigger, more frequent intakes with better prospects.",
                    investIdentifier: "career.transfers.invest.youth"
                ) {
                    message = store.investInYouthAcademy()
                }
                investmentCard(
                    title: "STADIUM",
                    level: store.userClub.stadiumExpansionLevel,
                    cost: store.stadiumUpgradeCost(forClubIndex: store.userClubIndex),
                    detail: "Capacity: \(store.stadiumInfo(forClubIndex: store.userClubIndex).capacity.formatted()) — a fuller ground boosts home advantage.",
                    investIdentifier: "career.transfers.invest.stadium"
                ) {
                    message = store.investInStadium()
                }
                ticketPriceCard
            }
        }
    }

    private func investmentCard(title: String, level: Int, cost: Int?, detail: String,
                                investIdentifier: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < level ? CareerPalette.line : CareerPalette.canvas)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(CareerPalette.line.opacity(0.25)))
                    }
                }
            }
            Text(detail)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.tap()
                action()
            } label: {
                Text(cost.map { "INVEST (\(formatMoney($0)))" } ?? "MAX LEVEL")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(cost == nil ? CareerPalette.canvas : (store.userClub.transferBudget >= (cost ?? 0) ? CareerPalette.line : CareerPalette.canvas))
                    .foregroundStyle(cost == nil ? CareerPalette.mutedInk : (store.userClub.transferBudget >= (cost ?? 0) ? Color.white : CareerPalette.mutedInk))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(cost == nil || store.userClub.transferBudget < (cost ?? 0))
            .accessibilityIdentifier(investIdentifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(CareerPalette.canvas.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var ticketPriceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TICKET PRICES")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.line)
            HStack(spacing: 10) {
                stepButton("minus.circle.fill", identifier: "career.transfers.ticket.down") {
                    message = store.setTicketPriceLevel(store.userClub.ticketPriceLevel - 1)
                }
                Text(["Cheap", "Low", "Standard", "High", "Premium"][store.userClub.ticketPriceLevel - 1])
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .frame(minWidth: 64)
                stepButton("plus.circle.fill", identifier: "career.transfers.ticket.up") {
                    message = store.setTicketPriceLevel(store.userClub.ticketPriceLevel + 1)
                }
            }
            Text("Higher prices earn more per head but cost attendance and fan goodwill.")
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(CareerPalette.canvas.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func stepButton(_ icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(CareerPalette.line)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var staffCard: some View {
        sectionCard(title: "BACKROOM STAFF", subtitle: "HIRES THAT PAY OFF ACROSS THE WHOLE CLUB",
                    symbol: "person.text.rectangle.fill") {
            HStack(alignment: .top, spacing: 12) {
                ForEach(StaffRole.allCases) { role in
                    staffCardRow(role)
                }
            }
        }
    }

    private func staffCardRow(_ role: StaffRole) -> some View {
        let level = store.staffLevel(role)
        let name = store.backroomStaff.first { $0.role == role }?.name
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(role.rawValue.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < level ? CareerPalette.line : CareerPalette.canvas)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(CareerPalette.line.opacity(0.25)))
                    }
                }
            }
            Text(name ?? "Vacant")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(name == nil ? CareerPalette.mutedInk : CareerPalette.ink)
            Text(role.effectDescription)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(1...3, id: \.self) { hireLevel in
                    Button("Level \(hireLevel) — \(formatMoney(store.staffHireCost(level: hireLevel)))") {
                        message = store.hireStaff(role: role, level: hireLevel)
                    }
                }
            } label: {
                Text(level == 0 ? "HIRE" : "REPLACE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(CareerPalette.line)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityIdentifier("career.transfers.staff.\(CareerIdentifiers.slug(role.rawValue))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(CareerPalette.canvas.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Shared bits

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(CareerPalette.line)
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.transfers.empty")
        .accessibilityLabel("\(title). \(detail)")
    }

    private func clubStat(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func sellerName(_ target: TransferTarget) -> String {
        if let index = target.sellingClubIndex, store.clubs.indices.contains(index) {
            return store.clubs[index].shortName
        }
        return "Free agent"
    }
}

/// Compact chip-style button used inside transfer/target cards.
private struct TransferCompactButtonStyle: ButtonStyle {
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

// MARK: - Board confidence (dark-theme destinations keep using these)

/// The colour scheme shared by every board-confidence display — green when
/// safe, amber when it's worth worrying, red once it's genuine sacking risk.
func confidenceColor(_ value: Int) -> Color {
    switch value {
    case 60...:   return Retro.accent
    case 30..<60: return Retro.highlight
    default:      return Color(red: 0.9, green: 0.35, blue: 0.35)
    }
}

/// A small arrow reflecting the change in board confidence from the last
/// result — empty string while flat or with no result yet.
func confidenceTrendArrow(_ trend: Int) -> String {
    if trend > 0 { return "▲" }
    if trend < 0 { return "▼" }
    return ""
}

/// A thin bar showing board confidence (dark destinations).
struct ConfidenceBar: View {
    let value: Int
    var trend: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Retro.text.opacity(0.2))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 8)
            Text("Confidence \(value)% \(confidenceTrendArrow(trend))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
        }
    }

    private var color: Color { confidenceColor(value) }
}
