//
//  MainGameShell.swift
//  Retro Season Manager
//
//  The main in-career shell once a save is loaded: the sidebar, top
//  bar and the section switcher that hosts every other screen.
//

import SwiftUI

// MARK: - Main game shell

/// The sections reachable from the left sidebar.
enum GameSection: CaseIterable {
    case home, squad, table, fixtures, search, transfers, inbox, settings

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .squad:     return "person.3.fill"
        case .table:     return "list.number"
        case .fixtures:  return "calendar"
        case .search:    return "magnifyingglass"
        case .transfers: return "sterlingsign.circle.fill"
        case .inbox:     return "envelope.fill"
        case .settings:  return "gearshape.fill"
        }
    }

    /// The matching hand-authored pixel-grid icon from the game's art
    /// system, used everywhere `icon` used to fall back to an SF Symbol.
    var pixelIcon: PixelIconKind {
        switch self {
        case .home:      return .home
        case .squad:     return .squad
        case .table:     return .table
        case .fixtures:  return .fixtures
        case .search:    return .search
        case .transfers: return .transfers
        case .inbox:     return .inbox
        case .settings:  return .settings
        }
    }

    /// The hand-painted pixel-art icon for this destination, sliced from
    /// the game's commissioned icon sheet — used in the sidebar in place
    /// of the procedural `pixelIcon` fallback.
    var imageAssetName: String {
        switch self {
        case .home:      return "IconHome"
        case .squad:     return "IconSquad"
        case .table:     return "IconTable"
        case .fixtures:  return "IconFixtures"
        case .search:    return "IconSearch"
        case .transfers: return "IconTransfers"
        case .inbox:     return "IconInbox"
        case .settings:  return "IconSettings"
        }
    }

    var title: String {
        switch self {
        case .home:      return "Home Menu"
        case .squad:     return "Squad"
        case .table:     return "Competitions"
        case .fixtures:  return "Calendar"
        case .search:    return "Player Search"
        case .transfers: return "Transfers & Finances"
        case .inbox:     return "Inbox"
        case .settings:  return "Settings"
        }
    }
}

struct MainGameView: View {
    let store: GameStore
    @State private var section: GameSection = .home

    var body: some View {
        ZStack {
            // A dimmed night-match backdrop behind the whole game shell —
            // dark enough that it never fights with the panels and
            // monospace text sitting on top, everywhere those panels leave
            // a gap. Match day itself and the main menu keep their own look.
            GeometryReader { geo in
                Image("StadiumBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            Retro.background.opacity(0.82).ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(section: $section, accent: store.userColor, unreadCount: store.unreadNewsIDs.count)
                VStack(spacing: 0) {
                    TopBar(store: store, section: section)
                    Rectangle()
                        .fill(Retro.accent.opacity(0.25))
                        .frame(height: 1)
                    content
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch section {
            case .home:      HomeView(store: store, section: $section)
            case .squad:     SquadView(store: store)
            case .table:     TableView(store: store)
            case .fixtures:  CalendarView(store: store)
            case .search:    PlayerSearchView(store: store)
            case .transfers: TransfersView(store: store)
            case .inbox:     InboxView(store: store)
            case .settings:  SettingsView(store: store)
            }
        }
        .id(section)
        .transition(.opacity)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var section: GameSection
    var accent: Color = Retro.accent
    var unreadCount: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            ForEach(GameSection.allCases, id: \.self) { item in
                Button {
                    if section != item {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.18)) { section = item }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        sidebarIcon(for: item)
                            .frame(width: 52, height: 46)
                        if item == .inbox && unreadCount > 0 {
                            Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color(red: 0.9, green: 0.3, blue: 0.3))
                                .clipShape(Capsule())
                                .offset(x: 4, y: -2)
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())
                if item == .transfers { Spacer() }
            }
        }
        .padding(.vertical, 12)
        .frame(width: 64)
        .frame(maxHeight: .infinity)
        .background(Retro.panel)
    }

    /// One sidebar icon: the hand-painted pixel-art asset, dimmed when not
    /// the active tab, full brightness with a club-coloured chip behind it
    /// when selected, and a gold glow on an unread inbox even when it
    /// isn't the current tab.
    @ViewBuilder
    private func sidebarIcon(for item: GameSection) -> some View {
        let selected = section == item
        let alerting = item == .inbox && unreadCount > 0
        ZStack {
            if selected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 40)
                    .shadow(color: accent.opacity(0.55), radius: 6, y: 2)
            }
            Image(item.imageAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .opacity(selected || alerting ? 1 : 0.7)
                .shadow(color: alerting ? Retro.gold.opacity(0.85) : .clear, radius: 5)
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    let store: GameStore
    let section: GameSection

    var body: some View {
        HStack(spacing: 12) {
            CrestView(shortName: store.userClub.shortName, size: 34, color: store.userColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.userClub.name)
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(store.userColor)
                Text(section.title)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(store.todayDate.formatted(.dateTime.weekday(.wide)).uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
                Text(store.todayDate.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
            }
            ContinueButton(store: store)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Retro.background)
    }
}

/// The CONTINUE button — plays the next round, or rolls into the next season.
struct ContinueButton: View {
    let store: GameStore

    var body: some View {
        Button {
            Haptics.impact()
            if store.isSeasonOver {
                store.runHeavy("Rolling into the new season…") {
                    store.startNextSeason()
                }
            } else if store.isUserMatchToday {
                store.enterPreMatch()
            } else {
                store.runHeavy("Advancing…") {
                    await store.advanceUntilNews()
                    if store.isUserMatchToday {
                        store.enterPreMatch()
                    }
                }
            }
        } label: {
            Text(label)
                .font(.system(.callout, design: .monospaced).bold())
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [store.isUserMatchToday ? Retro.highlight : store.userColor,
                                             (store.isUserMatchToday ? Retro.highlight : store.userColor).opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: (store.isUserMatchToday ? Retro.highlight : store.userColor).opacity(0.45), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var label: String {
        if store.isSeasonOver { return "NEW SEASON" }
        if store.isUserMatchToday { return "GO TO MATCH" }
        return "CONTINUE ▸"
    }
}

