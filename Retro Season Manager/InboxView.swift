//
//  InboxView.swift
//  Retro Season Manager
//
//  The Career newsroom: a summary band, folder filters and the message
//  list in the accepted Career light-card design language, plus the
//  full-screen article reader opened from a row.
//
//  Every value shown comes from the authoritative GameStore news APIs
//  (`store.news`, `store.unreadNewsIDs`, `markNewsRead`, `markAllNewsRead`,
//  `pendingOffers`…). Nothing here generates, reorders or re-categorises
//  news: filtering is presentation-only and read state moves exclusively
//  through the store's existing mechanism.
//
//  One stable vertical scroll container hosts the whole destination. The
//  folder filter is a compact chip row inside it (never a nested vertical
//  ScrollView), so switching folders, opening an article or returning from
//  another destination cannot jump the page to the top.
//

import SwiftUI

// MARK: - Category presentation

extension NewsCategory {
    /// SF Symbol for the light-card inbox presentation (the procedural
    /// `glyph` on the model remains the retro theme's character art).
    var symbolName: String {
        switch self {
        case .result:   return "soccerball"
        case .transfer: return "arrow.left.arrow.right"
        case .offer:    return "sterlingsign.circle"
        case .injury:   return "cross.case.fill"
        case .board:    return "doc.text.fill"
        case .info:     return "info.circle.fill"
        case .world:    return "globe.europe.africa.fill"
        }
    }

    /// Restrained state accent for the light-card inbox: the established
    /// Career green for football business, gold for board matters, orange
    /// for medical, and muted ink for routine admin.
    var accentColor: Color {
        switch self {
        case .result, .transfer, .offer, .world: return CareerPalette.line
        case .injury:                            return Color(red: 0.72, green: 0.42, blue: 0.10)
        case .board:                             return Retro.gold
        case .info:                              return CareerPalette.mutedInk
        }
    }
}

// MARK: - Inbox

struct InboxView: View {
    let store: GameStore
    @State private var message: String?
    @State private var filter: InboxFilter = .all
    @State private var openItem: NewsItem?
    @State private var counterTarget: TransferOffer?

    /// The destination's filters. `unread` is a presentation-only quick
    /// filter over the store's authoritative unread set; the folder cases
    /// file stories exactly as `NewsCategory.folder` always has.
    enum InboxFilter: Equatable {
        case all, unread
        case folder(InboxFolder)

        var label: String {
            switch self {
            case .all: return "ALL"
            case .unread: return "UNREAD"
            case .folder(let folder): return folder.rawValue.uppercased()
            }
        }

        var identifier: String {
            switch self {
            case .all: return "career.inbox.filter.all"
            case .unread: return "career.inbox.filter.unread"
            case .folder(let folder): return "career.inbox.filter.\(CareerIdentifiers.slug(folder.rawValue))"
            }
        }

        /// The empty-state category this filter falls into.
        var isEmptyBecauseUnreadFilter: Bool { self == .unread }
        var isACategoryFolder: Bool {
            if case .folder = self { return true }
            return false
        }
    }

    private var filteredNews: [NewsItem] {
        switch filter {
        case .all:
            return store.news
        case .unread:
            return store.news.filter { store.unreadNewsIDs.contains($0.id) }
        case .folder(let folder):
            return store.news.filter { $0.category.folder == folder }
        }
    }

    private func unreadCount(in filter: InboxFilter) -> Int {
        switch filter {
        case .all:
            return store.unreadNewsIDs.count
        case .unread:
            return store.unreadNewsIDs.count
        case .folder(let folder):
            return store.news.filter { $0.category.folder == folder && store.unreadNewsIDs.contains($0.id) }.count
        }
    }

    /// The most recent message's headline, for the summary band's
    /// "latest" context — purely presentational, straight off `store.news`
    /// (which `addNews` keeps newest-first).
    private var latestTitle: String? {
        store.news.first?.title
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    if let message { feedbackBand(message) }
                    filterRow
                    if filter == .all && !store.pendingOffers.isEmpty {
                        offersCard
                    }
                    if filteredNews.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredNews) { item in
                            newsRow(item)
                        }
                        endOfListAnchor
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier("career.inbox.scroll")
            .background(CareerPalette.canvas)
        }
        .background(CareerPalette.canvas)
        .sheet(item: $openItem) { item in
            InboxArticleView(store: store, item: item)
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
            Image(systemName: "envelope.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("INBOX")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.news.count) MESSAGES · SEASON \(store.season)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            if !store.unreadNewsIDs.isEmpty {
                Button {
                    Haptics.tap()
                    store.markAllNewsRead()
                } label: {
                    Text("MARK ALL READ")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.line)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(CareerPalette.line.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.inbox.markall")
                .accessibilityLabel("Mark all messages read")
            }
            summaryStat("UNREAD", "\(store.unreadNewsIDs.count)",
                        accent: store.unreadNewsIDs.isEmpty ? nil : CareerPalette.line)
            summaryStat("DATE", store.currentDate.formatted(.dateTime.day().month(.abbreviated)).uppercased())
            summaryStat("PLAYED", "\(store.userClub.played)")
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.inbox.summary")
        .accessibilityLabel("""
        Inbox. \(store.news.count) messages, \(store.unreadNewsIDs.count) unread. \
        Season \(store.season), \(store.currentDate.formatted(.dateTime.day().month().year())). \
        \(latestTitle != nil ? "Latest: \(latestTitle!)." : "No messages yet.")
        """)
    }

    private func summaryStat(_ title: String, _ value: String, accent: Color? = nil) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(accent ?? CareerPalette.ink)
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
        .accessibilityIdentifier("career.inbox.feedback")
    }

    // MARK: Filters

    private var filterRow: some View {
        HStack(spacing: 6) {
            chip(.all)
            chip(.unread)
            ForEach(InboxFolder.allCases.filter { $0 != .all }) { folder in
                chip(.folder(folder))
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ candidate: InboxFilter) -> some View {
        let selected = filter == candidate
        let unread = unreadCount(in: candidate)
        return Button {
            Haptics.tap()
            filter = candidate
        } label: {
            HStack(spacing: 4) {
                Text(candidate.label)
                if unread > 0, candidate == .unread || candidate == .all {
                    Text("\(unread)")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(selected ? Color.white.opacity(0.25) : CareerPalette.line.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(selected ? .white : CareerPalette.mutedInk)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(selected ? CareerPalette.line : CareerPalette.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CareerPalette.line.opacity(selected ? 0 : 0.20)))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(candidate.identifier)
        .accessibilityLabel("\(candidate.label) filter\(unread > 0 ? ", \(unread) unread" : "")\(selected ? ", selected" : "")")
    }

    // MARK: Transfer offers (existing ALL-folder panel, restyled)

    private var offersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sterlingsign.circle.fill").foregroundStyle(CareerPalette.line)
                Text("TRANSFER OFFERS").font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("career.inbox.offers.header")
            ForEach(store.pendingOffers) { offer in
                offerRow(offer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.gold.opacity(0.4)))
        .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 2)
    }

    private func offerRow(_ offer: TransferOffer) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(offer.playerName)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.clubs[offer.fromClubIndex].name) · \(formatMoney(offer.amount))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer()
            Button { message = store.acceptOffer(offer) } label: {
                Text("ACCEPT")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(CareerPalette.line).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(PressableButtonStyle())
            Button { Haptics.tap(); counterTarget = offer } label: {
                Text("COUNTER")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(CareerPalette.line.opacity(0.12)).foregroundStyle(CareerPalette.line)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(PressableButtonStyle())
            Button { store.rejectOffer(offer); message = "Bid for \(offer.playerName) rejected." } label: {
                Text("REJECT")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(CareerPalette.surface).foregroundStyle(CareerPalette.mutedInk)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(CareerPalette.line.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: Message list

    private func newsRow(_ item: NewsItem) -> some View {
        let unread = store.unreadNewsIDs.contains(item.id)
        return Button {
            Haptics.tap()
            store.markNewsRead(item)
            openItem = item
        } label: {
            HStack(alignment: .top, spacing: 10) {
                // Unread marker: a gold dot for unread, an invisible
                // spacer for read so rows stay aligned.
                Circle()
                    .fill(unread ? Retro.gold : .clear)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: item.category.symbolName)
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(item.category.accentColor)
                        Text(item.category.sender.uppercased())
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(item.category.accentColor)
                        Spacer()
                        Text(item.date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    Text(item.title)
                        .font(.system(size: 11, weight: unread ? .black : .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .lineLimit(1)
                    Text(item.body)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 11)
            .stroke(unread ? Retro.gold.opacity(0.65) : CareerPalette.line.opacity(0.14),
                    lineWidth: unread ? 1.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .opacity(unread ? 1 : 0.88)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(item.stableRowIdentifier)
        .accessibilityLabel("\(unread ? "Unread. " : "")\(item.category.sender): \(item.title). \(item.date.formatted(.dateTime.day().month().year()))")
    }

    /// Bottom-of-list marker: proves the full message list is reachable
    /// in the destination's single scroll container.
    private var endOfListAnchor: some View {
        Text("END OF INBOX")
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(CareerPalette.mutedInk.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
            .accessibilityIdentifier("career.inbox.list.end")
    }

    private var emptyState: some View {
        let symbol = store.news.isEmpty
            ? "tray"
            : (filter.isEmptyBecauseUnreadFilter
               ? "checkmark.circle"
               : (filter.isACategoryFolder ? "line.3.horizontal.decrease.circle" : "newspaper"))
        let title: String
        let detail: String
        if store.news.isEmpty {
            title = "NO MESSAGES YET"
            detail = "Team news, results, transfers and board updates will land here as the season unfolds. Press CONTINUE to advance the calendar."
        } else if filter.isEmptyBecauseUnreadFilter {
            title = "NOTHING UNREAD"
            detail = "You're fully caught up. New stories will appear here the moment they arrive."
        } else if filter.isACategoryFolder {
            title = "NOTHING IN \(filter.label)"
            detail = "No filed messages in this folder. Try ALL to see every message."
        } else {
            title = "NOTHING HERE"
            detail = "Press CONTINUE to advance the calendar."
        }
        return VStack(spacing: 8) {
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
        .accessibilityIdentifier("career.inbox.empty")
        .accessibilityLabel("\(title). \(detail)")
    }
}

// MARK: - Article reader

/// The full-screen reading pane for one story, in the light-card language.
/// Newspaper-worthy stories still render their generated front page
/// (authoritative `NewspaperArticleView`); routine stories get the plain
/// light-card layout. Either way there is exactly one vertical scroll
/// container and the close control stays pinned above it.
struct InboxArticleView: View {
    let store: GameStore
    let item: NewsItem
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlayerProfile = false

    /// Best-effort live lookup of the player this story is about, by name
    /// across every club — the story itself is a frozen snapshot, but
    /// tapping through should show where he stands today, if he's still
    /// findable (he may have retired, or belong to a club outside this world).
    private var resolvedPlayer: (player: Player, clubIndex: Int)? {
        guard let name = item.playerName else { return nil }
        for (index, club) in store.clubs.enumerated() {
            if let match = club.players.first(where: { $0.name == name }) {
                return (match, index)
            }
        }
        return nil
    }

    /// The generated front page for this story, if it was judged
    /// newspaper-worthy — see `GameStore+Newspaper.swift`.
    private var newspaper: Newspaper? {
        guard let id = item.newspaperID else { return nil }
        return store.newspapers.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                articleHeader
                Divider().overlay(CareerPalette.line.opacity(0.18))
                if let newspaper {
                    NewspaperArticleView(newspaper: newspaper)
                } else {
                    plainArticleBody
                }
                if item.playerName != nil && newspaper != nil {
                    tagRow.padding(.horizontal, 20).padding(.vertical, 12)
                        .background(CareerPalette.canvas)
                }
            }
        }
        .sheet(isPresented: $showingPlayerProfile) {
            if let resolved = resolvedPlayer {
                PlayerProfileSheet(
                    store: store,
                    context: resolved.clubIndex == store.userClubIndex
                        ? .squad(resolved.player)
                        : .scouted(resolved.player, clubIndex: resolved.clubIndex),
                    onAction: { _ in }
                )
            }
        }
    }

    /// The pinned header: category, date and the always-reachable close
    /// action. Deliberately outside the scroll container so the close
    /// control never scrolls away on compact screens.
    private var articleHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(item.category.accentColor)
                .frame(width: 30, height: 30)
                .background(item.category.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.category.sender.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(item.category.accentColor)
                Text(item.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("career.inbox.article.header")
            .accessibilityLabel("\(item.category.sender). \(item.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))")
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(CareerPalette.ink.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("career.inbox.article.close")
            .accessibilityLabel("Close article")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(CareerPalette.surface)
    }

    /// The plain light-card article body for routine stories — one scroll
    /// container, comfortable typography, the player snapshot card inline
    /// (below the text so it never pinches the column), and the end
    /// anchor that proves lower content is reachable.
    private var plainArticleBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.system(size: 19, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if item.playerName != nil || item.clubName != nil {
                    tagRow
                }

                Text(item.body)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink.opacity(0.92))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if item.playerName != nil {
                    snapshotCard.padding(.top, 2)
                }

                // Scroll-depth marker: proves the article's lower content
                // is reachable in the single scroll container.
                Text("END OF ARTICLE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .accessibilityIdentifier("career.inbox.article.end")
            }
            .padding(20)
        }
        .accessibilityIdentifier("career.inbox.article.scroll")
    }

    private var tagRow: some View {
        HStack(spacing: 8) {
            if let playerName = item.playerName {
                tagPill(playerName, enabled: resolvedPlayer != nil) {
                    Haptics.tap()
                    showingPlayerProfile = true
                }
            }
            if let clubName = item.clubName {
                tagPill(clubName, enabled: false, action: {})
            }
            Spacer()
        }
    }

    private func tagPill(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(CareerPalette.line.opacity(0.08))
                .foregroundStyle(enabled ? CareerPalette.line : CareerPalette.mutedInk)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(enabled ? CareerPalette.line.opacity(0.4) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// The frozen player snapshot the story carries — deliberately read-only
    /// presentation of `NewsItem`'s existing fields.
    private var snapshotCard: some View {
        HStack(spacing: 12) {
            PlayerAvatarView(name: item.playerName ?? "?", position: item.playerPosition, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.playerName ?? "")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let position = item.playerPosition {
                        Text(position.rawValue)
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.line)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(CareerPalette.line.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if let rating = item.playerRating {
                        Text("\(rating) OVR")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    if let age = item.playerAge {
                        Text("AGE \(age)")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                }
            }
            Spacer()
        }
        .padding(11)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(CareerPalette.line.opacity(0.14)))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
