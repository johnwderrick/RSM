//
//  InboxView.swift
//  Retro Season Manager
//
//  The news inbox and its detail sheet.
//

import SwiftUI

// MARK: - Inbox

struct InboxView: View {
    let store: GameStore
    @State private var message: String?
    @State private var folder: InboxFolder = .all
    @State private var openItem: NewsItem?
    @State private var counterTarget: TransferOffer?

    private var filteredNews: [NewsItem] {
        folder == .all ? store.news : store.news.filter { $0.category.folder == folder }
    }

    private func unreadCount(in folder: InboxFolder) -> Int {
        let items = folder == .all ? store.news : store.news.filter { $0.category.folder == folder }
        return items.filter { store.unreadNewsIDs.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("INBOX")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    if !store.unreadNewsIDs.isEmpty {
                        Text("\(store.unreadNewsIDs.count) UNREAD")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Retro.highlight)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if !store.unreadNewsIDs.isEmpty {
                        Button {
                            store.markAllNewsRead()
                        } label: {
                            Text("Mark all read")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }

                folderTabs

                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if folder == .all && !store.pendingOffers.isEmpty {
                    Panel(title: "TRANSFER OFFERS") {
                        VStack(spacing: 8) {
                            ForEach(store.pendingOffers) { offer in
                                offerRow(offer)
                            }
                        }
                    }
                }

                if filteredNews.isEmpty {
                    Text("Nothing here. Press CONTINUE to advance the calendar.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                } else {
                    ForEach(filteredNews) { item in
                        newsRow(item)
                    }
                }
            }
            .padding()
        }
        .sheet(item: $openItem) { item in
            NewsDetailSheet(store: store, item: item)
        }
        .sheet(item: $counterTarget) { offer in
            CounterSellOfferSheet(store: store, offer: offer) { result in
                message = result
                counterTarget = nil
            }
        }
    }

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(InboxFolder.allCases) { tab in
                    let selected = folder == tab
                    let unread = unreadCount(in: tab)
                    Button {
                        Haptics.tap()
                        folder = tab
                    } label: {
                        HStack(spacing: 4) {
                            Text(tab.rawValue.uppercased())
                            if unread > 0 {
                                Text("\(unread)")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(selected ? Retro.accent : Retro.background)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(selected ? Retro.background : Retro.highlight)
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.system(.caption, design: .monospaced).bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected ? Retro.accent : Retro.panel)
                        .foregroundStyle(selected ? Retro.background : Retro.text)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private func offerRow(_ offer: TransferOffer) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(offer.playerName)
                    .font(.system(.callout, design: .monospaced).bold())
                Text("\(store.clubs[offer.fromClubIndex].name) · \(formatMoney(offer.amount))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
            }
            Spacer()
            Button { message = store.acceptOffer(offer) } label: {
                Text("ACCEPT")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Retro.accent).foregroundStyle(Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            Button { Haptics.tap(); counterTarget = offer } label: {
                Text("COUNTER")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Retro.highlight.opacity(0.25)).foregroundStyle(Retro.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            Button { store.rejectOffer(offer); message = "Bid for \(offer.playerName) rejected." } label: {
                Text("REJECT")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Retro.panel).foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
    }

    private func newsRow(_ item: NewsItem) -> some View {
        let unread = store.unreadNewsIDs.contains(item.id)
        return Button {
            Haptics.tap()
            store.markNewsRead(item)
            openItem = item
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if unread {
                    Circle().fill(Retro.highlight).frame(width: 7, height: 7).padding(.top, 5)
                } else {
                    Circle().fill(Color.clear).frame(width: 7, height: 7).padding(.top, 5)
                }
                if let playerName = item.playerName {
                    PlayerAvatarView(name: playerName, position: item.playerPosition, size: 28)
                } else {
                    Text(item.category.glyph)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Retro.accent)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.category.sender)
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight)
                        Spacer()
                        Text(item.date.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    }
                    HStack(spacing: 4) {
                        if item.newspaperID != nil {
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Retro.highlight.opacity(0.8))
                        }
                        Text(item.title)
                            .font(.system(.callout, design: .monospaced).weight(unread ? .bold : .regular))
                            .foregroundStyle(Retro.text)
                            .lineLimit(1)
                    }
                    Text(item.body)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Retro.text.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(unread ? Retro.token.opacity(0.3) : Retro.panel.opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(unread ? Retro.highlight.opacity(0.35) : .clear, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// A news item opened to full size, like an email — the bigger reading
/// pane the compact inbox rows link out to.
struct NewsDetailSheet: View {
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
            Retro.background.ignoresSafeArea()
            if let newspaper {
                newspaperContent(newspaper)
            } else {
                plainContent
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

    /// The dressed-up presentation for a newsworthy story — a full
    /// newspaper front page, plus the tappable player/club tags carried
    /// over from the plain layout below.
    private func newspaperContent(_ newspaper: Newspaper) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Retro.text.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 20)

            NewspaperArticleView(newspaper: newspaper)

            if item.playerName != nil {
                tagRow.padding(.horizontal, 20).padding(.bottom, 16)
            }
        }
    }

    /// The original plain layout — kept as a fallback for the (minor,
    /// routine) stories that don't earn a generated front page.
    private var plainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(item.category.glyph)
                    .font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.category.sender)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text(item.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Retro.text.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Retro.accent.opacity(0.25))

            Text(item.title)
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            if item.playerName != nil {
                tagRow
            }

            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    Text(item.body)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Retro.text)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if item.playerName != nil {
                    playerCard
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
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
                .font(.system(.caption2, design: .monospaced).bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Retro.panel)
                .foregroundStyle(enabled ? Retro.accent : Retro.text.opacity(0.7))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(enabled ? Retro.accent.opacity(0.4) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var playerCard: some View {
        VStack(spacing: 8) {
            PlayerAvatarView(name: item.playerName ?? "?", position: item.playerPosition, size: 56)
            if let name = item.playerName {
                Text(name)
                    .font(.system(.caption, design: .monospaced).bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            if let position = item.playerPosition {
                Text(position.rawValue)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Retro.highlight)
                    .clipShape(Capsule())
            }
            if let rating = item.playerRating {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text("\(rating)").font(.system(.caption2, design: .monospaced).bold())
                }
                .foregroundStyle(Retro.accent)
            }
            if let age = item.playerAge {
                Text("Age \(age)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
            }
        }
        .padding(10)
        .frame(width: 96)
        .background(Retro.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

