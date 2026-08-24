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
enum CareerPalette {
    static let canvas = Color(red: 0.94, green: 0.97, blue: 0.94)
    static let surface = Color.white
    static let ink = Color(red: 0.035, green: 0.16, blue: 0.08)
    static let mutedInk = Color(red: 0.25, green: 0.38, blue: 0.29)
    static let line = Color(red: 0.12, green: 0.46, blue: 0.23)
}

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

    var navLabel: String {
        switch self {
        case .home:      return "HOME"
        case .squad:     return "SQUAD"
        case .table:     return "TABLE"
        case .fixtures:  return "FIXTURES"
        case .search:    return "SCOUT"
        case .transfers: return "TRANSFERS"
        case .inbox:     return "INBOX"
        case .settings:  return "SETTINGS"
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
            // Keep the stadium visible as a restrained green-tinted backdrop;
            // the dashboard and existing destination views remain the focus.
            GeometryReader { geo in
                Image("StadiumBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Retro.darkGreen.opacity(0.78))
            }
            .ignoresSafeArea()
            LinearGradient(colors: [Retro.darkGreen.opacity(0.94), Retro.forest.opacity(0.82)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(section: $section, accent: Retro.emerald, unreadCount: store.unreadNewsIDs.count)
                VStack(spacing: 0) {
                    TopBar(store: store, section: section)
                    Rectangle()
                        .fill(Retro.emerald.opacity(0.35))
                        .frame(height: 1)
                    content
                }
                .background(CareerPalette.canvas)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(8)
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

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    /// Home through Transfers scroll in the middle so every item stays
    /// reachable on short landscape screens; Inbox and Settings stay
    /// pinned at the bottom like the original layout.
    private var topItems: [GameSection] {
        GameSection.allCases.filter { $0 != .inbox && $0 != .settings }
    }
    private let pinnedItems: [GameSection] = [.inbox, .settings]

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(topItems, id: \.self) { item in
                        sidebarButton(item)
                    }
                }
                .padding(.vertical, 2)
            }
            Spacer(minLength: 8)
            ForEach(pinnedItems, id: \.self) { item in
                sidebarButton(item)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(width: 82)
        .frame(maxHeight: .infinity)
        .background(Retro.darkGreen.opacity(0.98))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Retro.emerald.opacity(0.22))
                .frame(width: 1)
        }
    }

    private func sidebarButton(_ item: GameSection) -> some View {
        Button {
            if section != item {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.18)) { section = item }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    sidebarIcon(for: item)
                        .frame(width: compact ? 46 : 52, height: compact ? 34 : 40)
                    Text(item.navLabel)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(section == item ? .white : Retro.text.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: compact ? 44 : 52)
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
                    .frame(width: compact ? 42 : 46, height: compact ? 34 : 40)
                    .shadow(color: accent.opacity(0.55), radius: 6, y: 2)
            }
            Image(item.imageAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
                .opacity(selected || alerting ? 1 : 0.7)
                .shadow(color: alerting ? Retro.gold.opacity(0.85) : .clear, radius: 5)
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    let store: GameStore
    let section: GameSection

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            CrestView(shortName: store.userClub.shortName, size: compact ? 32 : 40, color: store.userColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("RSM CAREER")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Retro.emerald)
                Text(store.userClub.name)
                    .font(.system(compact ? .subheadline : .headline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("SEASON \(store.seasonLabel) · \(section.title.uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: compact ? 4 : 8)
            careerMetric("BOARD", "\(store.boardConfidence)%", Retro.gold)
            careerMetric("FANS", store.fanMoodLabel.uppercased(), Retro.emerald)
            if compact {
                // One-line date keeps the bar's width budget for the
                // metrics and Continue button on landscape iPhones.
                Text(store.todayDate.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                dateBlock
            }
            ContinueButton(store: store)
        }
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, compact ? 6 : 10)
        .background(
            LinearGradient(colors: [Retro.darkGreen, Retro.forest], startPoint: .leading, endPoint: .trailing)
        )
    }

    private var dateBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(store.todayDate.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
            Text(store.todayDate.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func careerMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
            Text(value)
                .font(.system(size: compact ? 10 : 11, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: compact ? 40 : 48)
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
                    LinearGradient(colors: [store.isUserMatchToday ? Retro.highlight : Retro.emerald,
                                             (store.isUserMatchToday ? Retro.highlight : Retro.forest)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .foregroundStyle(Retro.darkGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: (store.isUserMatchToday ? Retro.highlight : Retro.emerald).opacity(0.45), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var label: String {
        if store.isSeasonOver { return "NEW SEASON" }
        if store.isUserMatchToday { return "GO TO MATCH" }
        return "CONTINUE ▸"
    }
}

