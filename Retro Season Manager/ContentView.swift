//
//  ContentView.swift
//  Retro Season Manager
//
//  Old-school, text-driven football manager. Pick a club, set your
//  formation, play through the season and chase the title.
//

import SwiftUI

extension Color {
    /// Builds a colour from a stored [red, green, blue] array.
    init(rgb: [Double]) {
        self.init(red: rgb.count > 0 ? rgb[0] : 0.5,
                  green: rgb.count > 1 ? rgb[1] : 0.5,
                  blue: rgb.count > 2 ? rgb[2] : 0.5)
    }
}

extension GameStore {
    /// The user club's primary colour.
    var userColor: Color { Color(rgb: userClub.colorRGB) }
    /// The primary colour of any club.
    func color(forClubIndex index: Int) -> Color {
        clubs.indices.contains(index) ? Color(rgb: clubs[index].colorRGB) : Retro.accent
    }
}

/// A retro colour palette for that classic "green screen" manager feel.
/// The game's brand palette — everything in the "modern retro" art package
/// (icons, badges, trophies, portraits) is built from these named colours
/// only, so the whole app reads as one consistent, football-green identity
/// instead of a grab-bag of similar-but-different greens.
enum Retro {
    // Primary greens, exact brand hex values.
    static let emerald    = Color(red: 0x19 / 255, green: 0xC2 / 255, blue: 0x5A / 255)  // #19C25A
    static let darkGreen  = Color(red: 0x0B / 255, green: 0x33 / 255, blue: 0x16 / 255)  // #0B3316
    static let forest     = Color(red: 0x14 / 255, green: 0x5A / 255, blue: 0x2B / 255)  // #145A2B
    static let pitchGreen = Color(red: 0x2C / 255, green: 0x7A / 255, blue: 0x3F / 255)  // #2C7A3F

    // Accents.
    static let royalBlue = Color(red: 0x2A / 255, green: 0x5C / 255, blue: 0xE8 / 255)   // #2A5CE8
    static let gold       = Color(red: 0xF4 / 255, green: 0xC1 / 255, blue: 0x3A / 255)  // #F4C13A
    static let pureWhite  = Color.white
    static let pureBlack  = Color.black
    static let warning    = Color(red: 0xE5 / 255, green: 0x4D / 255, blue: 0x42 / 255)  // red, warnings only

    // Existing semantic roles, now sourced from the brand palette above.
    static let background = darkGreen
    static let panel      = forest
    static let accent     = emerald
    static let text       = Color(red: 0.82, green: 0.97, blue: 0.85)
    static let highlight  = gold

    // Tactics-screen colours (green pitch, purple player tokens).
    static let pitch      = pitchGreen
    static let pitchLight = Color(red: 0.20, green: 0.50, blue: 0.30)
    static let token      = Color(red: 0.42, green: 0.26, blue: 0.62)
    static let tokenEdge  = Color(red: 0.60, green: 0.42, blue: 0.85)

    // Traffic-light position fit.
    static let fitGood = emerald
    static let fitOkay = gold
    static let fitPoor = warning

    // Metallic trophy-tier tones.
    static let bronze = Color(red: 0xCD / 255, green: 0x7F / 255, blue: 0x32 / 255)
    static let silver = Color(red: 0xC4 / 255, green: 0xC9 / 255, blue: 0xCE / 255)
}

extension PositionFitLevel {
    var color: Color {
        switch self {
        case .confident: return Retro.fitGood
        case .okay:       return Retro.fitOkay
        case .poor:       return Retro.fitPoor
        }
    }
}

#if os(iOS)
import UIKit
#endif

/// Tactile feedback for key moments — a no-op on platforms without a Taptic Engine.
enum Haptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

extension GameStore {
    /// Runs a heavy action behind a loading overlay. The overlay is set,
    /// then a frame is yielded so SwiftUI actually gets to paint the
    /// spinner before the work starts. `action` can be a plain synchronous
    /// closure (it's trivially valid wherever an async one is expected) or
    /// an async one that yields periodically mid-loop — the latter is what
    /// keeps the spinner animating instead of the whole UI freezing solid
    /// for a long sim, since a purely synchronous closure blocks the main
    /// actor for its entire duration in one go once it starts.
    func runHeavy(_ message: String, action: @escaping () async -> Void) {
        busyMessage = message
        isBusy = true
        Task { @MainActor in
            await Task.yield()
            await action()
            isBusy = false
        }
    }
}

/// A full-screen loading overlay shown while a heavy operation runs.
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Retro.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(Retro.accent)
                    .scaleEffect(1.4)
                Text(message.uppercased())
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
            }
            .padding(28)
            .background(Retro.panel.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .transition(.opacity)
    }
}

/// A subtle press-down effect for buttons — the light "give" of a native app control.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @State private var store = GameStore()

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            if let live = store.live {
                MatchView(store: store, live: live)
            } else if store.atPreMatch {
                PreMatchHubView(store: store)
            } else if store.careerEnded {
                CareerEndView(store: store)
            } else if store.hasStarted && store.isSeasonOver {
                SeasonReviewView(store: store)
            } else if store.hasStarted {
                MainGameView(store: store)
            } else {
                MainMenuView(store: store)
            }
            if store.isBusy {
                LoadingOverlay(message: store.busyMessage)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(store.hasStarted ? store.userColor : Retro.accent)
        .animation(.easeInOut(duration: 0.2), value: store.isBusy)
    }
}

// MARK: - Save slots

/// Lists every career save so the manager can run more than one at once —
/// load one, rename it, or delete it — rather than being limited to a
/// single ever-overwritten save file.
struct SaveSlotListSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var saves: [SaveSlotInfo] = GameStore.savedGames()
    @State private var renaming: SaveSlotInfo?
    @State private var renameText = ""
    @State private var pendingDelete: SaveSlotInfo?

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CAREER SAVES")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                if saves.isEmpty {
                    Spacer()
                    Text("No career saves yet.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(saves) { slot in
                                row(slot)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .alert("Rename Save", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Save name", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let slot = renaming {
                    SaveSlots.rename(slot.id, to: renameText)
                    saves = GameStore.savedGames()
                }
                renaming = nil
            }
        }
        .alert("Delete this save?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let slot = pendingDelete {
                    GameStore.deleteSave(id: slot.id)
                    saves = GameStore.savedGames()
                }
                pendingDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func row(_ slot: SaveSlotInfo) -> some View {
        Button {
            Haptics.tap()
            store.runHeavy("Loading \(slot.clubName)…") {
                store.loadSavedGame(id: slot.id)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.clubName)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Text("Season \(slot.season) · \(slot.divisionName.isEmpty ? "In progress" : slot.divisionName) · \(slot.lastPlayed.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.65))
                }
                Spacer()
                Button {
                    renameText = slot.clubName
                    renaming = slot
                } label: {
                    Image(systemName: "pencil").foregroundStyle(Retro.text.opacity(0.7))
                }
                .buttonStyle(.plain)
                Button {
                    pendingDelete = slot
                } label: {
                    Image(systemName: "trash").foregroundStyle(Color(red: 0.9, green: 0.4, blue: 0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Main menu

struct MainMenuView: View {
    let store: GameStore
    @State private var showClubSelect = false
    @State private var showSaveList = false

    var body: some View {
        if showClubSelect {
            ClubSelectView(store: store) { withAnimation(.easeInOut(duration: 0.25)) { showClubSelect = false } }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        } else {
            menu
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)).combined(with: .opacity))
        }
    }

    private var menu: some View {
        ZStack {
            GeometryReader { geo in
                Image("MainMenuBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            // A gentle top-to-bottom darkening rather than a flat scrim —
            // keeps the stadium frontage visible in the middle while still
            // guaranteeing contrast for the title up top and the tagline
            // down at the bottom.
            LinearGradient(colors: [Retro.background.opacity(0.55), Retro.background.opacity(0.15),
                                     Retro.background.opacity(0.15), Retro.background.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 4) {
                    Text("⚽︎ RETRO SEASON MANAGER")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(startYearRangeLabel)
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .tracking(6)
                }

                HStack(spacing: 10) {
                    menuTile(icon: "play.fill", title: "Resume",
                             subtitle: mostRecentSave.map { "Continue \($0.clubName)" } ?? "No save to resume",
                             enabled: mostRecentSave != nil) {
                        guard let slot = mostRecentSave else { return }
                        store.runHeavy("Loading \(slot.clubName)…") {
                            store.loadSavedGame(id: slot.id)
                        }
                    }
                    menuTile(icon: "gearshape.fill", title: "New Game",
                             subtitle: "Pick a club and start", enabled: true) {
                        withAnimation(.easeInOut(duration: 0.25)) { showClubSelect = true }
                    }
                    menuTile(icon: "folder.fill", title: "Load Game",
                             subtitle: GameStore.hasSavedGame ? "\(GameStore.savedGames().count) career save\(GameStore.savedGames().count == 1 ? "" : "s")" : "No saves yet",
                             enabled: GameStore.hasSavedGame) {
                        showSaveList = true
                    }
                }
                .padding(20)
                .background(Retro.background.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                Spacer()
                Text("An old-school football management sim")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .padding(.bottom, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showSaveList) {
            SaveSlotListSheet(store: store)
        }
    }

    /// A subtitle describing which start years a new career can begin in —
    /// The most recently played save, if any — `savedGames()` is already
    /// sorted newest first, so this is the one "Resume" jumps straight into.
    private var mostRecentSave: SaveSlotInfo? { GameStore.savedGames().first }

    /// a range once there's more than one on offer, so this never goes
    /// stale as further start years are added.
    private var startYearRangeLabel: String {
        let years = GameStore.availableStartYears
        guard let first = years.first, let last = years.last else { return "" }
        return first == last ? "SEASON \(ClubSelectView.seasonLabel(for: first))" : "\(first) – \(last)"
    }

    private func menuTile(icon: String, title: String, subtitle: String,
                          enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(enabled ? Retro.accent : Retro.text.opacity(0.4))
                Text(title)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(enabled ? Retro.text : Retro.text.opacity(0.4))
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 172, height: 140)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.accent.opacity(enabled ? 0.4 : 0.1), lineWidth: 1))
            .shadow(color: .black.opacity(enabled ? 0.3 : 0), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }
}

// MARK: - Club selection

struct ClubSelectView: View {
    let store: GameStore
    var onBack: (() -> Void)? = nil
    @State private var pendingClubIndex: Int? = nil
    @State private var selectedStartYear = GameStore.availableStartYears.first ?? 2000

    var body: some View {
        if let pendingClubIndex, let preview = store.clubPreview(forClubIndex: pendingClubIndex, startYear: selectedStartYear) {
            ClubConfirmView(store: store, clubIndex: pendingClubIndex, preview: preview, startYear: selectedStartYear) {
                withAnimation(.easeInOut(duration: 0.25)) { self.pendingClubIndex = nil }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        } else {
            selectionList
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)).combined(with: .opacity))
        }
    }

    private var selectionList: some View {
        VStack(spacing: 16) {
            HStack {
                if let onBack {
                    Button { onBack() } label: {
                        Text("‹ Back")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            VStack(spacing: 4) {
                Text("⚽️ NEW GAME")
                    .font(.system(.title, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text("Choose the club you wish to manage")
                    .font(.system(.footnote, design: .monospaced))
            }

            if GameStore.availableStartYears.count > 1 {
                startYearPicker
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.clubsByDivision, id: \.tier) { division in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(division.name.uppercased())
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(Retro.accent)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(division.clubs, id: \.index) { club in
                                    Button {
                                        Haptics.tap()
                                        withAnimation(.easeInOut(duration: 0.25)) { pendingClubIndex = club.index }
                                    } label: {
                                        HStack {
                                            Text(club.short)
                                                .font(.system(.footnote, design: .monospaced).bold())
                                                .foregroundStyle(Retro.highlight)
                                                .frame(width: 44, alignment: .leading)
                                            Text(club.name)
                                                .font(.system(.footnote, design: .monospaced))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Retro.panel)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Retro.accent.opacity(0.15), lineWidth: 1))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var startYearPicker: some View {
        VStack(spacing: 6) {
            Text("CAREER START")
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.7))
            // A horizontally scrolling row rather than a fixed HStack, so
            // this keeps working cleanly as more start years are added in
            // future — a plain HStack would eventually overflow a narrow
            // phone screen once there are enough options to not fit in one row.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GameStore.availableStartYears, id: \.self) { year in
                        Button {
                            Haptics.tap()
                            selectedStartYear = year
                        } label: {
                            Text(Self.seasonLabel(for: year))
                                .font(.system(.footnote, design: .monospaced).bold())
                                .foregroundStyle(selectedStartYear == year ? Retro.background : Retro.text)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedStartYear == year ? Retro.accent : Retro.panel)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// A "2000/01" style label for a start year, matching `GameStore`'s own
    /// `seasonLabel` formatting.
    static func seasonLabel(for year: Int) -> String {
        "\(year)/\(String(format: "%02d", (year + 1) % 100))"
    }
}

// MARK: - Club confirmation

struct ClubConfirmView: View {
    let store: GameStore
    let clubIndex: Int
    let preview: GameStore.ClubPreview
    var startYear: Int = 2000
    var onBack: () -> Void

    private var clubColor: Color { Color(rgb: preview.colorRGB) }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("‹ Choose a different club")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer()

            VStack(spacing: 14) {
                CrestView(shortName: preview.short, size: 72, color: clubColor)
                Text(preview.name)
                    .font(.system(.title, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text(preview.divisionName)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
                StarRatingView(stars: preview.stars)
            }

            Panel(title: "WHAT TO EXPECT") {
                VStack(alignment: .leading, spacing: 8) {
                    confirmStat("Starting season", ClubSelectView.seasonLabel(for: startYear))
                    confirmStat("League standing", "\(ordinal(preview.divisionRank)) of \(preview.divisionSize) seeds")
                    confirmStat("Transfer budget", formatMoney(preview.estimatedBudget))
                    confirmStat("Board objective", preview.boardObjective)
                }
            }
            .frame(maxWidth: 420)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Haptics.success()
                    store.runHeavy("Building the \(preview.name) squad…") {
                        store.newGame(clubIndex: clubIndex, startYear: startYear)
                    }
                } label: {
                    Text("MANAGE \(preview.name.uppercased())")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .frame(maxWidth: 420)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [clubColor, clubColor.opacity(0.75)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: clubColor.opacity(0.45), radius: 10, y: 5)
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("Go back to club selection")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.bottom, 24)
        }
    }

    private func confirmStat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.85))
            Spacer()
            Text(value).foregroundStyle(Retro.accent).bold()
        }
        .font(.system(.callout, design: .monospaced))
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (1, let t) where t != 11: suffix = "st"
        case (2, let t) where t != 12: suffix = "nd"
        case (3, let t) where t != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

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

// MARK: - Home / manager's office

struct HomeView: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                dayStrip
                boardStrip
                HStack(alignment: .top, spacing: 14) {
                    // Left column: next match + medical centre.
                    VStack(spacing: 14) {
                        NextMatchPanel(store: store)
                        MedicalCentrePanel(store: store, section: $section)
                        ContractsPanel(store: store)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    // Right column: standings + fixtures.
                    VStack(spacing: 14) {
                        StandingsMiniPanel(store: store, section: $section)
                        FixturesMiniPanel(store: store, section: $section)
                        SquadNeedsPanel(store: store, section: $section)

                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(14)
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(store.currentDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text(countdownText)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(store.isUserMatchToday ? Retro.highlight : Retro.text.opacity(0.85))
                FormView(outcomes: store.recentForm(forClubIndex: store.userClubIndex, count: 6))
            }
            if !store.pendingOffers.isEmpty {
                Text("⚠️ \(store.pendingOffers.count) bid\(store.pendingOffers.count == 1 ? "" : "s")")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
            }
            if store.isDeadlineDayRush, let days = store.daysUntilTransferDeadline {
                Text(days == 0 ? "🔥 DEADLINE DAY" : "🔥 Deadline in \(days)d")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
            }
            Spacer()
            if !store.isSeasonOver && !store.isUserMatchToday {
                Button {
                    Haptics.tap()
                    store.runHeavy("Skipping to the next match…") {
                        await store.advanceToNextMatch()
                        if store.isUserMatchToday {
                            store.enterPreMatch()
                        }
                    }
                } label: {
                    Text("SKIP TO MATCH ▸▸")
                        .font(.system(.caption, design: .monospaced).bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Retro.accent)
                        .foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Retro.panel.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var countdownText: String {
        if store.isSeasonOver { return "SEASON COMPLETE" }
        if store.isUserMatchToday { return store.isCupMatchDay ? "🏆 CUP DAY" : "⚽︎ MATCH DAY" }
        if let days = store.daysUntilNextMatch {
            return "Next match in \(days) day\(days == 1 ? "" : "s")"
        }
        return ""
    }

    private var boardStrip: some View {
        Button { section = .transfers } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("BOARD OBJECTIVE")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.75))
                    Text(store.boardObjective)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("Reputation: \(store.reputationLabel) (\(store.managerReputation))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                    if store.isObjectiveAtRisk {
                        Text("⚠️ Off the pace for this")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.35))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("BUDGET \(formatMoney(store.userClub.transferBudget))")
                        .foregroundStyle(Retro.highlight)
                        .font(.system(.caption, design: .monospaced).bold())
                    Text("Confidence \(store.boardConfidence)% \(confidenceTrendArrow(store.boardConfidenceTrend)) · \(store.jobSecurity)")
                        .foregroundStyle(confidenceColor(store.boardConfidence))
                        .font(.system(.caption, design: .monospaced).bold())
                    ZStack(alignment: .leading) {
                        Capsule().fill(Retro.text.opacity(0.2))
                        GeometryReader { geo in
                            Capsule()
                                .fill(confidenceColor(store.boardConfidence))
                                .frame(width: geo.size.width * CGFloat(store.boardConfidence) / 100)
                        }
                    }
                    .frame(width: 100, height: 5)
                    if store.boardConfidence <= 20 {
                        Text("⚠️ Sacking risk")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.35))
                    }
                    Text("Squad morale: \(store.teamMoraleLabel(forClubIndex: store.userClubIndex))")
                        .foregroundStyle(Retro.text.opacity(0.85))
                        .font(.system(.caption, design: .monospaced).bold())
                    Text("Fans: \(store.fanMoodLabel)")
                        .foregroundStyle(confidenceColor(store.fanConfidence))
                        .font(.system(.caption, design: .monospaced).bold())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Retro.panel.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Next match panel

struct NextMatchPanel: View {
    let store: GameStore

    var body: some View {
        Panel(title: "NEXT MATCH") {
            if let match = store.nextUserMatchInfo {
                let isHome = match.homeIndex == store.userClubIndex
                let opponentIndex = isHome ? match.awayIndex : match.homeIndex
                let opponent = store.clubs[opponentIndex]
                let probs = store.outcomeProbabilities(homeIndex: match.homeIndex, awayIndex: match.awayIndex)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(isHome ? "HOME" : "AWAY")
                            .foregroundStyle(Retro.highlight)
                        Spacer()
                        Text(match.label)
                            .foregroundStyle(match.isCup ? Retro.highlight : Retro.text.opacity(0.85))
                    }
                    .font(.system(.caption, design: .monospaced).bold())

                    HStack(spacing: 12) {
                        CrestView(shortName: opponent.shortName, size: 48, color: store.color(forClubIndex: opponentIndex))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opponent.name)
                                .font(.system(.body, design: .monospaced).bold())
                            StarRatingView(stars: store.starRating(forClubIndex: opponentIndex))
                            Text(match.isCup ? store.clubDivisionLabel(forClubIndex: opponentIndex)
                                 : "\(ordinal(store.position(ofClubIndex: opponentIndex))) in the league")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.85))
                        }
                    }

                    labelled("FORM") {
                        FormView(outcomes: store.recentForm(forClubIndex: opponentIndex))
                    }

                    labelled("ODDS") {
                        let userWin = isHome ? probs.home : probs.away
                        let oppWin = isHome ? probs.away : probs.home
                        HStack(spacing: 10) {
                            oddsChip("You", userWin, favourite: userWin >= oppWin && userWin >= probs.draw)
                            oddsChip("Draw", probs.draw, favourite: probs.draw > userWin && probs.draw > oppWin)
                            oddsChip(opponent.shortName, oppWin, favourite: oppWin > userWin && oppWin >= probs.draw)
                        }
                    }

                    labelled("MANAGER") {
                        Text(store.manager(forClubIndex: opponentIndex))
                            .font(.system(.callout, design: .monospaced))
                    }
                }
            } else {
                seasonOver
            }
        }
    }

    @ViewBuilder
    private var seasonOver: some View {
        if let champion = store.champion {
            VStack(alignment: .leading, spacing: 8) {
                Text("SEASON \(store.season) COMPLETE")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                Text("🏆 Champions: \(champion.name)")
                    .font(.system(.callout, design: .monospaced))
                Text(champion.id == store.userClub.id
                     ? "Congratulations, boss — you won the league!"
                     : "You finished \(ordinal(store.userPosition)). Press NEW SEASON to go again.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
        }
    }

    private func labelled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.8))
            content()
        }
    }

    private func oddsChip(_ title: String, _ probability: Double, favourite: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .monospaced))
            Text("\(Int((probability * 100).rounded()))%")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(favourite ? Retro.highlight : Retro.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Retro.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Medical centre

struct MedicalCentrePanel: View {
    let store: GameStore
    @Binding var section: GameSection
    @State private var showingMedicalCentre = false

    var body: some View {
        Button { showingMedicalCentre = true } label: {
            Panel(title: "MEDICAL CENTRE") {
                let injured = store.injuredPlayers(forClubIndex: store.userClubIndex)
                let suspended = store.suspendedPlayers(forClubIndex: store.userClubIndex)
                if injured.isEmpty && suspended.isEmpty {
                    Text("No injuries or bans — squad fully available. ✓")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(injured.prefix(5)) { player in
                            HStack(spacing: 8) {
                                Text("⚠️")
                                Text(player.name)
                                Spacer()
                                Text(returnDateText(for: player))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(player.injuryWeeks >= 3 ? .red : Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                        ForEach(suspended.prefix(3)) { player in
                            HStack(spacing: 8) {
                                Text("🟥")
                                Text(player.name)
                                Spacer()
                                Text("banned \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es")")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                        let hiddenCount = max(0, injured.count - 5) + max(0, suspended.count - 3)
                        if hiddenCount > 0 {
                            Text("+ \(hiddenCount) more — view squad")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingMedicalCentre) {
            MedicalCentreSheet(store: store)
        }
    }

    private func returnDateText(for player: Player) -> String {
        guard let date = store.expectedReturnDate(for: player) else {
            return "out ~\(player.injuryWeeks) wk\(player.injuryWeeks == 1 ? "" : "s")"
        }
        return "back ~\(date.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

/// The full Medical Centre — every injured or suspended squad player with
/// how long they're out and (for injuries) a fitness-return countdown, in
/// place of the Home dashboard panel's five-a-side preview.
struct MedicalCentreSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var injured: [Player] { store.injuredPlayers(forClubIndex: store.userClubIndex) }
    private var suspended: [Player] { store.suspendedPlayers(forClubIndex: store.userClubIndex) }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("MEDICAL CENTRE")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Retro.text.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                if injured.isEmpty && suspended.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("✓")
                            .font(.system(size: 40))
                            .foregroundStyle(Retro.accent)
                        Text("Full squad availability — no injuries or bans.")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if !injured.isEmpty {
                                Panel(title: "INJURED (\(injured.count))") {
                                    VStack(spacing: 10) {
                                        ForEach(injured) { player in
                                            injuryRow(player)
                                        }
                                    }
                                }
                            }
                            if !suspended.isEmpty {
                                Panel(title: "SUSPENDED (\(suspended.count))") {
                                    VStack(spacing: 10) {
                                        ForEach(suspended) { player in
                                            suspensionRow(player)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func injuryRow(_ player: Player) -> some View {
        let severe = player.injuryWeeks >= 3
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(severe ? Color(red: 0.95, green: 0.4, blue: 0.35) : Retro.highlight)
                    .frame(width: 8, height: 8)
                Text(player.position.rawValue)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Retro.highlight)
                    .clipShape(Capsule())
                Text(player.name)
                    .font(.system(.callout, design: .monospaced).bold())
                Spacer()
                Text(returnDateText(for: player))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(severe ? Color(red: 0.95, green: 0.4, blue: 0.35) : Retro.highlight)
            }
            Text("\(player.durability.label) durability · \(player.injuriesThisSeason) injur\(player.injuriesThisSeason == 1 ? "y" : "ies") this season")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
        }
        .padding(10)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func suspensionRow(_ player: Player) -> some View {
        HStack {
            Text("🟥")
            Text(player.name)
                .font(.system(.callout, design: .monospaced).bold())
            Spacer()
            Text("\(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es") left")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
        .padding(10)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func returnDateText(for player: Player) -> String {
        guard let date = store.expectedReturnDate(for: player) else {
            return "out ~\(player.injuryWeeks) wk\(player.injuryWeeks == 1 ? "" : "s")"
        }
        return "back ~\(date.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

// MARK: - Contracts panel

/// Contracts never just expire and cost you a player any more — an
/// unrenewed deal quietly auto-renews at season's end — but renewing on
/// your own terms is still better than leaving it to chance, so this
/// surfaces who's worth locking down now.
/// Flags detailed positions where the squad is dangerously thin — a quick
/// at-a-glance nudge toward what the transfer market should be fixing.
struct SquadNeedsPanel: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        Button { section = .squad } label: {
            Panel(title: "SQUAD NEEDS") {
                let needs = store.squadNeeds()
                if needs.isEmpty {
                    Text("Squad has cover everywhere. ✓")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(needs, id: \.role) { need in
                            HStack(spacing: 8) {
                                Text(need.count == 0 ? "🔴" : "🟡")
                                Text(need.role.fullName)
                                Spacer()
                                Text(need.count == 0 ? "none fit" : "\(need.count) fit")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(need.count == 0 ? Color(red: 0.9, green: 0.35, blue: 0.35) : Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ContractsPanel: View {
    let store: GameStore
    @State private var renewing: Player?
    @State private var message: String?

    var body: some View {
        Panel(title: "CONTRACTS") {
            let expiring = store.expiringContracts
            if expiring.isEmpty {
                Text("No deals expiring soon. ✓")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let message {
                        Text(message)
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight)
                    }
                    ForEach(expiring.prefix(5)) { player in
                        Button { renewing = player } label: {
                            HStack(spacing: 8) {
                                Text(player.contractYears <= 0 ? "⏳" : "📄")
                                Text(player.name)
                                Spacer()
                                Text(player.contractYears <= 0 ? "expires this year" : "\(player.contractYears) yr left")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(player.contractYears <= 0 ? .red : Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text)
                        }
                        .buttonStyle(.plain)
                    }
                    if expiring.count > 5 {
                        Text("+ \(expiring.count - 5) more — view squad")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    }
                }
            }
        }
        .sheet(item: $renewing) { player in
            ContractOfferSheet(store: store, player: player) { result in
                message = result
                renewing = nil
            }
        }
    }
}

// MARK: - Standings mini panel

struct StandingsMiniPanel: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        Button { section = .table } label: {
            Panel(title: store.divisionName(store.userDivisionTier).uppercased()) {
                let table = store.userTable()
                let userRow = table.firstIndex { $0.id == store.userClub.id } ?? 0
                let lower = max(0, min(userRow - 1, table.count - 4))
                let window = Array(table.enumerated())[lower..<min(lower + 4, table.count)]

                VStack(spacing: 4) {
                    HStack {
                        Text("Pos").frame(width: 36, alignment: .leading)
                        Text("Team")
                        Spacer()
                        Text("P").frame(width: 24, alignment: .trailing)
                        Text("GD").frame(width: 30, alignment: .trailing)
                        Text("Pts").frame(width: 30, alignment: .trailing)
                    }
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.8))

                    ForEach(Array(window), id: \.element.id) { index, club in
                        let isUser = club.id == store.userClub.id
                        HStack {
                            Text(ordinal(index + 1)).frame(width: 36, alignment: .leading)
                            Text(club.shortName)
                            Spacer()
                            Text("\(club.played)").frame(width: 24, alignment: .trailing)
                            Text("\(club.goalDifference)").frame(width: 30, alignment: .trailing)
                            Text("\(club.points)").frame(width: 30, alignment: .trailing)
                        }
                        .font(.system(.callout, design: .monospaced)
                            .weight(isUser ? .bold : .regular))
                        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fixtures mini panel

struct FixturesMiniPanel: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        Button { section = .fixtures } label: {
            Panel(title: "FIXTURES & RESULTS · SEE CALENDAR") {
                VStack(spacing: 6) {
                    ForEach(store.userFixtureWindow()) { fixture in
                        fixtureRow(fixture)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func fixtureRow(_ fixture: Fixture) -> some View {
        let isHome = fixture.homeIndex == store.userClubIndex
        let opponentIndex = isHome ? fixture.awayIndex : fixture.homeIndex
        let opponent = store.clubs[opponentIndex]
        return HStack(spacing: 8) {
            Text(store.date(forMatchday: fixture.matchday).formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
                .frame(width: 58, alignment: .leading)
            Text(opponent.shortName)
            Text(isHome ? "H" : "A")
                .foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            if fixture.played {
                let us = isHome ? fixture.homeGoals : fixture.awayGoals
                let them = isHome ? fixture.awayGoals : fixture.homeGoals
                Text("\(us)-\(them)")
                    .foregroundStyle(us > them ? Retro.accent : (us == them ? Retro.text : Retro.highlight))
            } else {
                let difficulty = store.fixtureDifficulty(opponentIndex: opponentIndex)
                Text(String(repeating: "★", count: difficulty))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(difficultyColor(difficulty))
            }
        }
        .font(.system(.callout, design: .monospaced))
    }

    private func difficultyColor(_ stars: Int) -> Color {
        switch stars {
        case 5, 4: return Color(red: 0.85, green: 0.35, blue: 0.3)
        case 3: return Retro.highlight
        default: return Retro.accent
        }
    }
}

// MARK: - Season review

struct SeasonReviewView: View {
    let store: GameStore

    var body: some View {
        ZStack {
            LinearGradient(colors: [Retro.background, Retro.panel, Retro.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text("SEASON \(store.season) REVIEW")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)

                    if store.wasSacked { sackedBanner }

                    verdictPanel

                    HStack(alignment: .top, spacing: 14) {
                        standingsPanel
                        awardsPanel
                    }

                    teamOfTheSeasonPanel

                    if !store.pendingJobOffers.isEmpty { jobOffersPanel }

                    continueButton
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private var verdictPanel: some View {
        let met = store.objectiveMet()
        return VStack(spacing: 8) {
            Text("🏆 CHAMPIONS: \(store.champion?.name ?? "—")")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text("\(store.userClub.name) finished \(ordinal(store.userPosition)) on \(store.userClub.points) pts")
                .font(.system(.callout, design: .monospaced).bold())
            Text(store.seasonVerdict())
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(met ? Retro.accent : Color(red: 0.95, green: 0.45, blue: 0.45))
            Text("Objective: \(store.boardObjective) — \(met ? "ACHIEVED ✓" : "MISSED ✗")")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(met ? Retro.accent : Color(red: 0.95, green: 0.45, blue: 0.45))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Retro.panel.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var standingsPanel: some View {
        Panel(title: "\(store.divisionName(store.userDivisionTier).uppercased()) — FINAL") {
            VStack(spacing: 3) {
                ForEach(Array(store.userTable().enumerated()), id: \.element.id) { index, club in
                    let isUser = club.id == store.userClub.id
                    HStack {
                        Text("\(index + 1)").frame(width: 22, alignment: .leading)
                        Text(club.shortName)
                        Spacer()
                        Text("\(club.points)")
                    }
                    .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
                    .foregroundStyle(isUser ? Retro.highlight : Retro.text)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var awardsPanel: some View {
        Panel(title: "AWARDS") {
            VStack(alignment: .leading, spacing: 10) {
                if let boot = store.goldenBoot() {
                    award("🥇 Golden Boot", "\(boot.player.name) (\(boot.club.shortName))", "\(boot.player.goals) goals")
                }
                if let pos = store.playerOfSeason() {
                    award("⭐ Your Player of the Season", pos.name,
                          pos.averageRating.map { String(format: "avg %.2f over %d apps", $0, pos.apps) } ?? "")
                }
                if let scorer = store.userTopScorer() {
                    award("🎯 Your Top Scorer", scorer.name, "\(scorer.goals) goals")
                }
                if let win = store.biggestUserWin() {
                    award("💥 Biggest Win", win, "")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func award(_ title: String, _ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Text(name)
                .font(.system(.callout, design: .monospaced).bold())
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            }
        }
    }

    private var sackedBanner: some View {
        Text("⚠️ SACKED — you must accept a new job to continue")
            .font(.system(.callout, design: .monospaced).bold())
            .foregroundStyle(Retro.background)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.9, green: 0.4, blue: 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var jobOffersPanel: some View {
        Panel(title: store.wasSacked ? "JOB OFFERS (choose one)" : "JOB OFFERS") {
            VStack(spacing: 6) {
                ForEach(store.pendingJobOffers) { offer in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(offer.clubName)
                                .font(.system(.callout, design: .monospaced).bold())
                            Text("\(offer.divisionName) · prestige \(offer.prestige)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.8))
                            Text("Budget \(formatMoney(offer.transferBudget)) · \(offer.expectedObjective)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.highlight)
                        }
                        Spacer()
                        let accepted = store.pendingClubSwitch == offer.clubIndex
                        Button { store.acceptJobOffer(offer) } label: {
                            Text(accepted ? "ACCEPTED ✓" : "ACCEPT")
                                .font(.system(.caption, design: .monospaced).bold())
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(accepted ? Retro.highlight : Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !store.wasSacked {
                    Text("Ignore these to stay at \(store.userClub.name).")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var mustChooseJob: Bool { store.wasSacked && store.pendingClubSwitch == nil }

    @ViewBuilder
    private var continueButton: some View {
        Button {
            if store.isFinalSeason {
                store.endCareer()
            } else {
                store.runHeavy("Rolling into the new season…") {
                    store.startNextSeason()
                }
            }
        } label: {
            Text(store.isFinalSeason ? "VIEW CAREER SUMMARY ▸" : "CONTINUE TO SEASON \(store.season + 1) ▸")
                .font(.system(.body, design: .monospaced).bold())
                .padding(.horizontal, 26).padding(.vertical, 14)
                .background(mustChooseJob ? Retro.panel : Retro.accent)
                .foregroundStyle(mustChooseJob ? Retro.text.opacity(0.5) : Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(mustChooseJob)
    }

    private var teamOfTheSeasonPanel: some View {
        Panel(title: "TEAM OF THE SEASON") {
            let xi = store.teamOfTheSeason()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(xi) { player in
                    HStack(spacing: 6) {
                        Text(player.position.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Retro.highlight)
                            .frame(width: 30, alignment: .leading)
                        Text(surname(player.name))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(player.rating)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Retro.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Career end

struct CareerEndView: View {
    let store: GameStore

    var body: some View {
        ZStack {
            LinearGradient(colors: [Retro.background, Retro.panel, Retro.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("CAREER COMPLETE")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("30 seasons managed · 2000 – 2030")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                    Text("Finished with \(store.userClub.name) in the \(store.divisionName(store.userDivisionTier))")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.highlight)

                    Panel(title: "CAREER HONOURS (\(store.careerHonours.count))") {
                        if store.careerHonours.isEmpty {
                            Text("No major honours — but a career to remember.")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.8))
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { _, honour in
                                    HonourRow(text: honour)
                                        .font(.system(.callout, design: .monospaced))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 560)

                    Button {
                        store.returnToMenuAfterCareer()
                    } label: {
                        Text("BACK TO MAIN MENU")
                            .font(.system(.body, design: .monospaced).bold())
                            .padding(.horizontal, 26).padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }
}

// MARK: - Pre-match hub

struct PreMatchHubView: View {
    let store: GameStore

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(Retro.accent.opacity(0.25)).frame(height: 1)
                if let match = store.nextUserMatchInfo {
                    content(for: match)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CrestView(shortName: store.userClub.shortName, size: 34, color: store.userColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.userClub.name)
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(store.userColor)
                Text("Pre-Match Hub")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            Spacer()
            Button { store.atPreMatch = false } label: {
                Text("BACK")
                    .font(.system(.callout, design: .monospaced).bold())
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Retro.panel).foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            Button { store.beginUserMatch() } label: {
                Text("KICK OFF ▸")
                    .font(.system(.callout, design: .monospaced).bold())
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Retro.highlight).foregroundStyle(Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func content(for match: UserMatchInfo) -> some View {
        let isHome = match.homeIndex == store.userClubIndex
        let opponentIndex = isHome ? match.awayIndex : match.homeIndex
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(match.label.uppercased())
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(match.isCup ? Retro.highlight : Retro.accent)
                    .padding(.horizontal, 14)
                if let talk = store.pendingTeamTalk {
                    teamTalkPanel(talk).padding(.horizontal, 14)
                }
                if let question = store.pendingPressQuestion {
                    pressPanel(question).padding(.horizontal, 14)
                }
                HStack(alignment: .top, spacing: 14) {
                    // Left: the match-up & your form.
                    VStack(spacing: 14) {
                        matchupPanel(opponentIndex: opponentIndex, isHome: isHome)
                        predictionPanel(opponentIndex: opponentIndex, isHome: isHome)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    // Right: opponent scouting report.
                    opponentPanel(opponentIndex: opponentIndex)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 12)
        }
    }

    private func matchupPanel(opponentIndex: Int, isHome: Bool) -> some View {
        let opponent = store.clubs[opponentIndex]
        let ratings = store.starRatings(forClubIndices: [store.userClubIndex, opponentIndex])
        return Panel(title: store.nextMatchIsDerby ? "⚔️ DERBY DAY" : "THE FIXTURE") {
            VStack(spacing: 10) {
                HStack {
                    teamBadge(store.userClub.shortName, store.userClub.name, ratings[store.userClubIndex] ?? 1, store.userColor)
                    Text(isHome ? "vs" : "@")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    teamBadge(opponent.shortName, opponent.name, ratings[opponentIndex] ?? 1, store.color(forClubIndex: opponentIndex))
                }
                HStack {
                    Text("Your form")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                    FormView(outcomes: store.recentForm(forClubIndex: store.userClubIndex))
                }
                HStack {
                    Text("\(opponent.shortName) form")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                    FormView(outcomes: store.recentForm(forClubIndex: opponentIndex))
                }
            }
        }
    }

    private func teamBadge(_ short: String, _ name: String, _ stars: Int, _ color: Color = Retro.accent) -> some View {
        VStack(spacing: 4) {
            CrestView(shortName: short, size: 44, color: color)
            Text(name)
                .font(.system(.caption, design: .monospaced).bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
            StarRatingView(stars: stars)
        }
        .frame(maxWidth: .infinity)
    }

    private func predictionPanel(opponentIndex: Int, isHome: Bool) -> some View {
        let homeIndex = isHome ? store.userClubIndex : opponentIndex
        let awayIndex = isHome ? opponentIndex : store.userClubIndex
        let probs = store.outcomeProbabilities(homeIndex: homeIndex, awayIndex: awayIndex)
        let userWin = Int(((isHome ? probs.home : probs.away) * 100).rounded())
        let draw = Int((probs.draw * 100).rounded())
        let oppWin = max(0, 100 - userWin - draw)
        return Panel(title: "MATCH ODDS") {
            HStack {
                oddsChip("You", userWin, userWin >= oppWin && userWin >= draw)
                oddsChip("Draw", draw, draw > userWin && draw > oppWin)
                oddsChip(store.clubs[opponentIndex].shortName, oppWin, oppWin > userWin && oppWin >= draw)
            }
        }
    }

    private func oddsChip(_ title: String, _ pct: Int, _ favourite: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(.caption2, design: .monospaced)).lineLimit(1)
            Text("\(pct)%")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(favourite ? Retro.highlight : Retro.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Retro.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func opponentPanel(opponentIndex: Int) -> some View {
        let opponent = store.clubs[opponentIndex]
        return Panel(title: opponent.name.uppercased()) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Style", store.playStyle(forClubIndex: opponentIndex))
                infoRow("Formation", store.formationName(forClubIndex: opponentIndex))
                infoRow("Manager", store.manager(forClubIndex: opponentIndex))
                if let key = store.keyPlayer(forClubIndex: opponentIndex) {
                    infoRow("Key player", "\(key.name) (\(key.rating))")
                }
                Divider().overlay(Retro.accent.opacity(0.2))
                HStack(alignment: .top, spacing: 16) {
                    strengthsColumn("STRENGTHS", store.teamStrengths(forClubIndex: opponentIndex), Retro.accent)
                    strengthsColumn("WEAKNESSES", store.teamWeaknesses(forClubIndex: opponentIndex), Retro.highlight)
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            Text(value).bold()
        }
        .font(.system(.callout, design: .monospaced))
    }

    private func teamTalkPanel(_ question: PressQuestion) -> some View {
        Panel(title: "🗣 TEAM TALK") {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.prompt)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(question.options) { option in
                    Button { store.answerTeamTalk(option) } label: {
                        Text(option.label)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Retro.panel)
                            .foregroundStyle(Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pressPanel(_ question: PressQuestion) -> some View {
        Panel(title: "🎙 PRESS CONFERENCE") {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.prompt)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(question.options) { option in
                    Button { store.answerPress(option) } label: {
                        Text(option.label)
                            .font(.system(.footnote, design: .monospaced).bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Retro.panel)
                            .foregroundStyle(Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func strengthsColumn(_ title: String, _ items: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.system(.footnote, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Live match

struct MatchView: View {
    let store: GameStore
    let live: LiveMatch
    @State private var showSubs = false
    @State private var goalFlash = false
    @State private var goalFlashColor = Retro.highlight
    @State private var goalFlashText = "GOAL!"
    @State private var penaltyFlash = false
    @State private var redCardFlash = false
    @State private var interviewAnswered = false

    private var userGoals: Int { live.userSide == .home ? live.homeGoals : live.awayGoals }
    private var opponentGoals: Int { live.userSide == .home ? live.awayGoals : live.homeGoals }
    private var userWon: Bool { userGoals > opponentGoals }
    private var userDrew: Bool { userGoals == opponentGoals }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("StadiumBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            Retro.background.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 0) {
                scoreBar
                commentaryFeed
                Divider().overlay(Retro.accent.opacity(0.2))
                statsBlock
                infoRow
                controlBar
            }
            if penaltyFlash { penaltyFlashOverlay }
            if redCardFlash { redCardFlashOverlay }
            if goalFlash { goalFlashOverlay }
            if live.isFinished {
                fullTimeOverlay
            }
        }
        .onAppear { live.start() }
        .onChange(of: live.homeGoals) { _, _ in triggerGoalFlash(side: .home) }
        .onChange(of: live.awayGoals) { _, _ in triggerGoalFlash(side: .away) }
        .onChange(of: live.penaltyAwardedCount) { _, _ in triggerPenaltyFlash() }
        .onChange(of: live.redCardCount) { _, _ in triggerRedCardFlash() }
        .onChange(of: live.isFinished) { _, finished in
            guard finished else { return }
            if userWon { Haptics.success() } else if userDrew { Haptics.warning() } else { Haptics.error() }
        }
        .sheet(isPresented: $showSubs) { SubsSheet(live: live) }
    }

    private func triggerPenaltyFlash() {
        guard !live.isFinished else { return }
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.15)) { penaltyFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            withAnimation(.easeOut(duration: 0.3)) { penaltyFlash = false }
        }
    }

    private var penaltyFlashOverlay: some View {
        GeometryReader { geo in
            Image("PenaltyAwarded")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .scaleEffect(penaltyFlash ? 1.0 : 0.6)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func triggerRedCardFlash() {
        guard !live.isFinished else { return }
        Haptics.error()
        withAnimation(.easeIn(duration: 0.15)) { redCardFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.easeOut(duration: 0.3)) { redCardFlash = false }
        }
    }

    private var redCardFlashOverlay: some View {
        GeometryReader { geo in
            Image("RedCardFlash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .scaleEffect(redCardFlash ? 1.0 : 0.6)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// A penalty conversion waits for the "PENALTY!" flash to finish
    /// before showing the goal flash, so the two don't collide — an
    /// open-play goal still flashes immediately.
    private func triggerGoalFlash(side: Side) {
        guard !live.isFinished else { return }
        let scoringIndex = side == .home ? live.homeIndex : live.awayIndex
        goalFlashColor = store.color(forClubIndex: scoringIndex)
        goalFlashText = side == live.userSide ? "GOAL!!!" : "GOAL AGAINST"
        let wasPenalty = live.events.last?.type == .penalty
        Task {
            if wasPenalty { try? await Task.sleep(for: .milliseconds(1100)) }
            side == live.userSide ? Haptics.success() : Haptics.error()
            withAnimation(.easeIn(duration: 0.15)) { goalFlash = true }
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.4)) { goalFlash = false }
        }
    }

    /// Each side of a goal gets its own full-bleed photo behind the flash
    /// text — the celebration shot when the user scores, the dejected
    /// keeper shot when they concede — instead of one flat colour flash
    /// doing double duty for both.
    private var isUserGoalFlash: Bool { goalFlashText == "GOAL!!!" }

    private var goalFlashOverlay: some View {
        ZStack {
            GeometryReader { geo in
                Image(isUserGoalFlash ? "GoalCelebration" : "GoalAgainst")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            (isUserGoalFlash ? Retro.background : Color.black).opacity(0.30).ignoresSafeArea()
            VStack(spacing: 6) {
                Text("⚽︎")
                    .font(.system(size: 90))
                Text(goalFlashText)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                Text(live.commentary.last?.text ?? "")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .scaleEffect(goalFlash ? 1.0 : 0.6)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: Commentary

    private var commentaryFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(live.commentary.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced)
                                .weight(line.text.contains("GOAL") ? .bold : .regular))
                            .foregroundStyle(commentaryColor(line.text))
                            .multilineTextAlignment(commentaryAlignment(line.side))
                            .frame(maxWidth: .infinity, alignment: commentaryFrameAlignment(line.side))
                            .id(index)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: live.commentary.count) { _, _ in
                withAnimation { proxy.scrollTo(live.commentary.count - 1, anchor: .bottom) }
            }
        }
    }

    /// Home-side commentary reads on the left, away-side on the right —
    /// matching the score bar's own home-first, away-second order — with
    /// neutral lines (kick-off, half-time, full-time) centred.
    private func commentaryFrameAlignment(_ side: Side?) -> Alignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil:   return .center
        }
    }

    private func commentaryAlignment(_ side: Side?) -> TextAlignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil:   return .center
        }
    }

    private func commentaryColor(_ line: String) -> Color {
        if line.contains("GOAL") { return Retro.highlight }
        if line.contains("RED CARD") { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if line.contains("booked") { return Color(red: 0.95, green: 0.85, blue: 0.35) }
        if line.contains("Full-time") || line.contains("Half-time") || line.contains("Kick-off") { return Retro.accent }
        return Retro.text.opacity(0.9)
    }

    // MARK: Score bar

    private var scoreBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text(clockText)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(statusColor)
                    .frame(width: 64, alignment: .leading)
                Spacer()
                HStack(spacing: 10) {
                    Text(live.homeShort).fontWeight(.bold)
                    Text("\(live.homeGoals) - \(live.awayGoals)")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text(live.awayShort).fontWeight(.bold)
                }
                Spacer()
                playPauseButton
            }
            progressDots
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
    }

    private var clockText: String {
        if live.isFinished { return "FT" }
        if live.isHalfTime { return "HT" }
        if live.minute <= 90 { return "\(live.minute)'" }
        return "90+\(live.minute - 90)'"
    }

    private var statusColor: Color {
        if live.isFinished { return Retro.highlight }
        if live.isHalfTime { return Retro.highlight }
        return Retro.accent
    }

    private var progressDots: some View {
        let total = 24
        let filled = Int(Double(min(live.minute, live.totalMinutes)) / Double(max(live.totalMinutes, 1)) * Double(total))
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Retro.accent : Retro.text.opacity(0.2))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var playPauseButton: some View {
        let playing = !live.isPaused && !live.isHalfTime && !live.isFinished
        return Button {
            if live.isFinished { return }
            playing ? live.pause() : live.resume()
        } label: {
            Text(live.isFinished ? "FULL TIME" : (playing ? "⏸ PAUSE" : "▶ PLAY"))
                .font(.system(.callout, design: .monospaced).bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(playing ? Retro.highlight : Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(live.isFinished)
    }

    // MARK: Stats

    private var statsBlock: some View {
        VStack(spacing: 8) {
            Text("\(live.stadium) · Att. \(live.attendance.formatted())")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))

            let stats: [(String, String, String)] = [
                ("\(live.homePossession)%", "POSSESSION", "\(100 - live.homePossession)%"),
                ("\(live.shots.home) (\(live.shotsOnTarget.home))", "SHOTS (ON TGT)", "\(live.shots.away) (\(live.shotsOnTarget.away))"),
                ("\(live.clearCut.home)", "CLEAR CUT", "\(live.clearCut.away)"),
                ("\(live.offsides.home)", "OFFSIDES", "\(live.offsides.away)"),
                (ratingText(live.teamRating.home), "TEAM RATING", ratingText(live.teamRating.away)),
                ("\(live.corners.home)", "CORNERS", "\(live.corners.away)"),
            ]
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    statRow(home: stat.0, label: stat.1, away: stat.2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func statRow(home: String, label: String, away: String) -> some View {
        HStack {
            Text(home)
                .foregroundStyle(Retro.accent)
                .frame(width: 64, alignment: .leading)
            Spacer()
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
            Spacer()
            Text(away)
                .foregroundStyle(Retro.text)
                .frame(width: 64, alignment: .trailing)
        }
        .font(.system(.callout, design: .monospaced).bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func ratingText(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private var infoRow: some View {
        HStack {
            Text(live.competition)
            Spacer()
            Text("\(live.weather.glyph) \(live.weather.rawValue)")
            Spacer()
            Text(live.dateText)
        }
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(Retro.text.opacity(0.7))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: Controls

    private var controlBar: some View {
        VStack(spacing: 6) {
            momentumBar
            possessionBar
            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 3.0], id: \.self) { value in
                    Button {
                        live.setSpeed(value)
                    } label: {
                        Text("\(Int(value))×")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(live.speed == value ? Retro.accent : Retro.panel)
                            .foregroundStyle(live.speed == value ? Retro.background : Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }

                barButton("SKIP") { live.skipToEnd() }

                Spacer()

                Picker("Mentality", selection: Binding(
                    get: { live.userMentality },
                    set: { live.userMentality = $0 }
                )) {
                    ForEach(Mentality.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Retro.accent)

                Picker("Instruction", selection: Binding(
                    get: { live.userInstruction },
                    set: { live.userInstruction = $0 }
                )) {
                    ForEach(MatchInstruction.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Retro.highlight)

                barButton("SUBS \(live.userSubsLeft)/5") { showSubs = true }
                    .disabled(live.userSubsLeft == 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
    }

    private var possessionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(store.color(forClubIndex: live.homeIndex))
                    .frame(width: geo.size.width * CGFloat(live.homePossession) / 100)
                Rectangle().fill(store.color(forClubIndex: live.awayIndex))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var momentumBar: some View {
        VStack(spacing: 2) {
            HStack {
                Text("MOMENTUM")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
            }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    store.color(forClubIndex: live.homeIndex)
                        .frame(width: geo.size.width * CGFloat(live.momentum))
                    store.color(forClubIndex: live.awayIndex)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }

    private func barButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Full time

    private var fullTimeOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("FULL TIME")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text("\(live.homeName) \(live.homeGoals) - \(live.awayGoals) \(live.awayName)")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .multilineTextAlignment(.center)

                if !live.motmName.isEmpty {
                    Text("★ Man of the Match: \(live.motmName)")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                }

                Text("YOUR PLAYER RATINGS")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.8))
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(live.userPlayerRatings.enumerated()), id: \.offset) { _, entry in
                            HStack {
                                Text(surname(entry.player.name))
                                Spacer()
                                Text(String(format: "%.1f", entry.rating))
                                    .foregroundStyle(ratingColor(entry.rating))
                                    .bold()
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 130)

                if !interviewAnswered {
                    let question = store.makePostMatchInterview(won: userWon, draw: userDrew)
                    VStack(spacing: 6) {
                        Text("🎙 \(question.prompt)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            ForEach(question.options) { option in
                                Button {
                                    store.answerPress(option, headline: "Post-match interview")
                                    interviewAnswered = true
                                } label: {
                                    Text(option.label)
                                        .font(.system(.caption2, design: .monospaced).bold())
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(Retro.panel)
                                        .foregroundStyle(Retro.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    store.finishLiveMatch()
                } label: {
                    Text("CONTINUE ▸")
                        .font(.system(.body, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Retro.accent)
                        .foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(Retro.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(24)
        }
    }

    private func ratingColor(_ value: Double) -> Color {
        switch value {
        case 7.5...: return Retro.highlight
        case 6.5..<7.5: return Retro.accent
        default: return Retro.text
        }
    }
}

// MARK: - Substitutions sheet

struct SubsSheet: View {
    let live: LiveMatch
    @Environment(\.dismiss) private var dismiss
    @State private var offID: UUID?
    @State private var onID: UUID?

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SUBSTITUTIONS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Text("\(live.userSubsLeft) remaining")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.highlight)
                }

                HStack(alignment: .top, spacing: 12) {
                    column(title: "OFF (on pitch)", players: live.userOnPitch.map { ($0.player, Int($0.energy)) },
                           selected: offID) { offID = $0 }
                    column(title: "ON (bench)", players: live.userBench.map { ($0, nil) },
                           selected: onID) { onID = $0 }
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Button {
                        if let offID, let onID,
                           let off = live.userOnPitch.first(where: { $0.id == offID }),
                           let on = live.userBench.first(where: { $0.id == onID }) {
                            live.makeUserSub(off: off, on: on)
                            dismiss()
                        }
                    } label: {
                        Text("MAKE SUB")
                            .font(.system(.body, design: .monospaced).bold())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(canSub ? Retro.accent : Retro.panel)
                            .foregroundStyle(canSub ? Retro.background : Retro.text.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSub)
                }
            }
            .padding()
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private var canSub: Bool {
        offID != nil && onID != nil && live.userSubsLeft > 0
    }

    private func column(title: String, players: [(Player, Int?)], selected: UUID?,
                        onSelect: @escaping (UUID) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.85))
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(players, id: \.0.id) { player, energy in
                        Button {
                            onSelect(player.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(player.position.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .frame(width: 30)
                                    .foregroundStyle(Retro.highlight)
                                Text(surname(player.name))
                                    .lineLimit(1)
                                Spacer()
                                if let energy {
                                    Text("\(energy)%")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(energy < 70 ? Retro.highlight : Retro.text.opacity(0.7))
                                } else {
                                    Text("\(player.rating)")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundStyle(Retro.accent)
                                }
                            }
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selected == player.id ? Retro.token.opacity(0.6) : Retro.panel.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Transfers & finances

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

/// This season's income/expenditure, in order — transfers, wages sold,
/// gate receipts, investments, prize money, and the season-opening reset.
struct LedgerView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var income: Int { store.seasonLedger.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    private var expenditure: Int { store.seasonLedger.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SEASON LEDGER")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                HStack(spacing: 14) {
                    statLine("Income", formatMoney(income), Retro.accent)
                    statLine("Expenditure", formatMoney(expenditure), Color(red: 0.9, green: 0.4, blue: 0.35))
                    statLine("Net", formatMoney(income + expenditure), Retro.highlight)
                }
                .padding(10)
                .background(Retro.panel.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                if store.seasonLedger.isEmpty {
                    Text("No transactions yet this season.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(store.seasonLedger) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.category)
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text)
                                        Text(entry.detail)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.7))
                                    }
                                    Spacer()
                                    Text(formatMoney(entry.amount))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(entry.amount >= 0 ? Retro.accent : Color(red: 0.9, green: 0.4, blue: 0.35))
                                }
                                .padding(10)
                                .background(Retro.panel.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func statLine(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TransfersView: View {
    let store: GameStore
    @State private var tab = 0
    @State private var profile: ProfileContext?
    @State private var message: String?
    @State private var showingLedger = false
    @State private var personalTermsDeal: PendingTransferDeal?
    @State private var withdrawDeal: PendingTransferDeal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    financesPanel
                    boardPanel
                }

                infrastructurePanel
                backroomStaffPanel
                if !store.pendingTransferDeals.isEmpty {
                    pendingDealsPanel
                }
                if !store.playersOnLoanFromUser().isEmpty {
                    loanedOutPanel
                }

                HStack {
                    Text("TRANSFER WINDOW")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                    Text(store.transferWindowStatus)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(store.isDeadlineDayRush ? Color(red: 0.95, green: 0.35, blue: 0.35)
                                          : (store.transferWindowOpen ? Retro.accent : Retro.highlight))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Retro.panel.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Picker("", selection: $tab) {
                    Text("My Squad").tag(0)
                    Text("Market").tag(1)
                    Text("Youth (\(store.youthProspects.count))").tag(2)
                }
                .pickerStyle(.segmented)

                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if tab == 1 {
                    let suggestions = store.suggestedTransferTargets(limit: 3)
                    if !suggestions.isEmpty {
                        suggestedTargetsPanel(suggestions)
                    }
                }
                if tab == 0 { squadList } else if tab == 1 { marketList } else { youthList }
            }
            .padding(14)
        }
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { message = $0 }
        }
        .sheet(item: $personalTermsDeal) { deal in
            PersonalTermsSheet(store: store, deal: deal) { message = $0 }
        }
        .sheet(item: $withdrawDeal) { deal in
            ConfirmActionSheet(
                title: "Break off talks with \(deal.player.name)?",
                message: "He'll return to \(deal.sellingClubName) and this deal is off. This can't be undone.",
                confirmLabel: "WITHDRAW"
            ) {
                message = store.withdrawPendingDeal(deal)
            }
        }
    }

    private var pendingDealsPanel: some View {
        Panel(title: "PENDING TRANSFERS") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.pendingTransferDeals) { deal in
                    HStack(spacing: 8) {
                        PlayerAvatarView(name: deal.player.name, position: deal.player.detailedPosition.broad, size: 30, age: deal.player.age)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(deal.player.name)
                                .font(.system(.callout, design: .monospaced).bold())
                            Text(deal.isReady
                                 ? "Ready to talk terms — \(formatMoney(deal.agreedFee)) fee agreed"
                                 : "Medical & paperwork in progress — \(formatMoney(deal.agreedFee)) fee agreed")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(deal.isReady ? Retro.accent : Retro.text.opacity(0.65))
                        }
                        Spacer()
                        if deal.isReady {
                            Button {
                                Haptics.tap()
                                personalTermsDeal = deal
                            } label: {
                                Text("TALK TERMS")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Retro.accent)
                                    .foregroundStyle(Retro.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(PressableButtonStyle())
                        } else {
                            Text("⏳").font(.system(.caption, design: .monospaced))
                        }
                        Button {
                            Haptics.tap()
                            withdrawDeal = deal
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(Retro.text.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var financesPanel: some View {
        Panel(title: "FINANCES") {
            VStack(alignment: .leading, spacing: 4) {
                statLine("Transfer budget", formatMoney(store.userClub.transferBudget), Retro.accent)
                let wageHeadroom = store.userClub.wageBudget - store.userClub.wageBill
                statLine("Wage bill / wk", "\(formatMoney(store.userClub.wageBill)) of \(formatMoney(store.userClub.wageBudget))",
                         wageHeadroom < 0 ? .red : Retro.text)
                statLine("Squad size", "\(store.userClub.players.count) / 30", Retro.text)
                Button { showingLedger = true } label: {
                    Text("VIEW SEASON LEDGER")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Retro.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingLedger) {
            LedgerView(store: store)
        }
    }

    private var boardPanel: some View {
        Panel(title: "THE BOARD") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Objective: \(store.boardObjective)")
                    .font(.system(.callout, design: .monospaced))
                ConfidenceBar(value: store.boardConfidence, trend: store.boardConfidenceTrend)
                statLine("Job security", store.jobSecurity,
                         store.boardConfidence >= 45 ? Retro.accent : Retro.highlight)
                statLine("Your contract", "\(store.managerContractYears) year\(store.managerContractYears == 1 ? "" : "s") left",
                         store.managerContractYears <= 1 ? Retro.highlight : Retro.text.opacity(0.85))
                Button {
                    Haptics.tap()
                    message = store.requestBudgetIncrease()
                } label: {
                    Text(store.daysUntilNextBudgetRequest.map { "ASK AGAIN IN \($0)D" } ?? "REQUEST MORE BUDGET")
                        .font(.system(.caption, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(store.daysUntilNextBudgetRequest == nil ? Retro.accent : Retro.panel)
                        .foregroundStyle(store.daysUntilNextBudgetRequest == nil ? Retro.background : Retro.text.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(store.daysUntilNextBudgetRequest != nil)
                if store.boardConfidence <= 40 {
                    Button {
                        Haptics.tap()
                        message = store.requestClearTheAirMeeting()
                    } label: {
                        Text(store.daysUntilNextClearAirMeeting.map { "ASK AGAIN IN \($0)D" } ?? "CALL CLEAR-THE-AIR MEETING")
                            .font(.system(.caption, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(store.daysUntilNextClearAirMeeting == nil ? Color(red: 0.9, green: 0.4, blue: 0.35) : Retro.panel)
                            .foregroundStyle(store.daysUntilNextClearAirMeeting == nil ? Retro.background : Retro.text.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(store.daysUntilNextClearAirMeeting != nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var loanedOutPanel: some View {
        Panel(title: "PLAYERS ON LOAN") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.playersOnLoanFromUser(), id: \.player.id) { entry in
                    HStack(spacing: 8) {
                        Text(entry.player.name)
                            .font(.system(.callout, design: .monospaced))
                        Spacer()
                        Text("at \(store.clubs[entry.clubIndex].name)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                        Button {
                            Haptics.tap()
                            message = store.recallFromLoan(entry.player)
                        } label: {
                            Text("RECALL")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Retro.panel)
                                .foregroundStyle(Retro.highlight)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var infrastructurePanel: some View {
        Panel(title: "CLUB INFRASTRUCTURE") {
            HStack(alignment: .top, spacing: 14) {
                investmentCard(
                    title: "YOUTH ACADEMY",
                    level: store.userClub.youthFacilityLevel,
                    cost: store.youthUpgradeCost(forClubIndex: store.userClubIndex),
                    detail: "Bigger, more frequent intakes with better prospects.",
                    action: {
                        message = store.investInYouthAcademy()
                    }
                )
                investmentCard(
                    title: "STADIUM",
                    level: store.userClub.stadiumExpansionLevel,
                    cost: store.stadiumUpgradeCost(forClubIndex: store.userClubIndex),
                    detail: "Capacity: \(store.stadiumInfo(forClubIndex: store.userClubIndex).capacity.formatted()) — a fuller ground boosts home advantage.",
                    action: {
                        message = store.investInStadium()
                    }
                )
                ticketPriceCard
            }
        }
    }

    private var ticketPriceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TICKET PRICES")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            HStack(spacing: 10) {
                stepButton("minus.circle.fill") {
                    message = store.setTicketPriceLevel(store.userClub.ticketPriceLevel - 1)
                }
                Text(["Cheap", "Low", "Standard", "High", "Premium"][store.userClub.ticketPriceLevel - 1])
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .frame(minWidth: 70)
                stepButton("plus.circle.fill") {
                    message = store.setTicketPriceLevel(store.userClub.ticketPriceLevel + 1)
                }
            }
            Text("Higher prices earn more per head but cost attendance and fan goodwill.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(.plain)
    }

    private var backroomStaffPanel: some View {
        Panel(title: "BACKROOM STAFF") {
            HStack(alignment: .top, spacing: 14) {
                ForEach(StaffRole.allCases) { role in
                    staffCard(role)
                }
            }
        }
    }

    private func staffCard(_ role: StaffRole) -> some View {
        let level = store.staffLevel(role)
        let name = store.backroomStaff.first { $0.role == role }?.name
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(role.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < level ? Retro.accent : Retro.text.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            Text(name ?? "Vacant")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(name == nil ? Retro.text.opacity(0.5) : Retro.text)
            Text(role.effectDescription)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(1...3, id: \.self) { hireLevel in
                    Button("Level \(hireLevel) — \(formatMoney(store.staffHireCost(level: hireLevel)))") {
                        message = store.hireStaff(role: role, level: hireLevel)
                    }
                }
            } label: {
                Text(level == 0 ? "HIRE" : "REPLACE")
                    .font(.system(.caption, design: .monospaced).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Retro.accent)
                    .foregroundStyle(Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func investmentCard(title: String, level: Int, cost: Int?, detail: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < level ? Retro.accent : Retro.text.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            Text(detail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.tap()
                action()
            } label: {
                Text(cost.map { "INVEST (\(formatMoney($0)))" } ?? "MAX LEVEL")
                    .font(.system(.caption, design: .monospaced).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(cost == nil ? Retro.panel : Retro.accent)
                    .foregroundStyle(cost == nil ? Retro.text.opacity(0.5) : Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(cost == nil || store.userClub.transferBudget < (cost ?? 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statLine(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.85))
            Spacer()
            Text(value).foregroundStyle(color).bold()
        }
        .font(.system(.callout, design: .monospaced))
    }

    private var squadList: some View {
        VStack(spacing: 4) {
            ForEach(sortedSquad) { player in
                Button { profile = .squad(player) } label: {
                    TransferRow(position: player.position.rawValue,
                                name: player.name,
                                subtitle: "Age \(player.age) · \(player.rating) OVR\(player.isTransferListed ? " · LISTED" : "")",
                                trailing: formatMoney(player.value),
                                dimmed: !player.isAvailable)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func suggestedTargetsPanel(_ suggestions: [TransferTarget]) -> some View {
        Panel(title: "SUGGESTED TARGETS") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Would plug a thin spot in the squad, and fits the budget.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
                ForEach(suggestions) { target in
                    Button { profile = .market(target) } label: {
                        TransferRow(position: target.player.detailedPosition.rawValue,
                                    name: target.player.name,
                                    subtitle: sellerName(target) + " · \(target.player.rating) OVR",
                                    trailing: priceLabel(for: target),
                                    dimmed: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var marketList: some View {
        VStack(spacing: 4) {
            if store.transferMarket.isEmpty {
                Text("No players available right now.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            ForEach(store.transferMarket.sorted { $0.player.rating > $1.player.rating }) { target in
                let affordable = target.sellingClubIndex == nil
                    ? store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
                    : store.userClub.transferBudget >= target.askingPrice
                        && store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
                Button { profile = .market(target) } label: {
                    TransferRow(position: target.player.position.rawValue,
                                name: target.player.name,
                                subtitle: sellerName(target) + " · \(target.player.rating) OVR" + scoutTag(target),
                                trailing: priceLabel(for: target),
                                dimmed: !affordable)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var youthList: some View {
        VStack(spacing: 4) {
            Text("Prospects from your academy — promote the best, release the rest.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
            if store.youthProspects.isEmpty {
                Text("No prospects — the next intake arrives next season.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            ForEach(store.youthProspects) { prospect in
                HStack(spacing: 8) {
                    Text(prospect.position.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.background)
                        .frame(width: 36).padding(.vertical, 4)
                        .background(Retro.accent).clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(prospect.name).font(.system(.callout, design: .monospaced).bold())
                        Text("Age \(prospect.age) · \(prospect.rating) OVR")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.75))
                    }
                    Spacer()
                    Button { message = store.promoteYouth(prospect) } label: {
                        Text("PROMOTE")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Retro.accent).foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    Button { message = store.releaseYouth(prospect) } label: {
                        Text("RELEASE")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Retro.panel).foregroundStyle(Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Retro.panel.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var sortedSquad: [Player] {
        store.userClub.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    private func sellerName(_ target: TransferTarget) -> String {
        if let index = target.sellingClubIndex { return store.clubs[index].shortName }
        return "Free agent"
    }

    private func priceLabel(for target: TransferTarget) -> String {
        target.sellingClubIndex == nil ? "FREE" : formatMoney(target.askingPrice)
    }

    private func scoutTag(_ target: TransferTarget) -> String {
        switch store.scoutState(for: target) {
        case .unscouted:              return ""
        case .inProgress:             return " · 🔍scouting"
        case .scouted(let report):    return " · POT ~\(report.potential)"
        }
    }
}

struct TransferRow: View {
    let position: String
    let name: String
    let subtitle: String
    let trailing: String
    let dimmed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(position)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.background)
                .frame(width: 36)
                .padding(.vertical, 4)
                .background(Retro.accent)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(.callout, design: .monospaced).bold())
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.75))
            }
            Spacer()
            Text(trailing)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Retro.panel.opacity(dimmed ? 0.3 : 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(dimmed ? 0.7 : 1)
    }
}

/// A thin bar showing board confidence.
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

// MARK: - Player profile

struct PlayerProfileSheet: View {
    let store: GameStore
    let context: ProfileContext
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingContractOffer = false
    @State private var showingBidOffer = false
    @State private var showingFreeAgentOffer = false
    @State private var showingTerminateConfirm = false
    @State private var showingLoanOut = false

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                header
                shortlistButton
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        attributesGrid
                        profileInfoPanel
                        attributesPanel
                        seasonPanel
                        if case .market(let target) = context { scoutSection(target) }
                        statusLine
                    }
                }
                actionButton
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(isPresented: $showingContractOffer) {
            ContractOfferSheet(store: store, player: player) { result in
                onAction(result)
                showingContractOffer = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingBidOffer) {
            if case .market(let target) = context {
                TransferBidSheet(store: store, target: target) { result in
                    onAction(result)
                    showingBidOffer = false
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingFreeAgentOffer) {
            let fromClubIndex: Int? = { if case .scouted(_, let clubIndex) = context { return clubIndex }; return nil }()
            FreeAgentContractSheet(store: store, player: player, fromClubIndex: fromClubIndex) { result in
                onAction(result)
                showingFreeAgentOffer = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingTerminateConfirm) {
            ConfirmActionSheet(
                title: "Release \(player.name)?",
                message: "The club pays a severance of \(formatMoney(max(50, player.wage * 4))) and his squad slot is freed immediately. This can't be undone.",
                confirmLabel: "TERMINATE CONTRACT"
            ) {
                onAction(store.terminateContract(player))
                dismiss()
            }
        }
        .sheet(isPresented: $showingLoanOut) {
            LoanOutSheet(store: store, player: player) { result in
                onAction(result)
                showingLoanOut = false
                dismiss()
            }
        }
    }

    /// The freshest copy of the player (squad players may have changed).
    private var player: Player {
        switch context {
        case .squad(let p):  return store.currentPlayer(p.id) ?? p
        case .market(let t): return t.player
        case .scouted(let p, _): return p
        }
    }

    private var shortlistButton: some View {
        let isShortlisted = store.isShortlisted(player.id)
        return Button {
            Haptics.tap()
            store.toggleShortlist(player.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isShortlisted ? "star.fill" : "star")
                Text(isShortlisted ? "SHORTLISTED" : "ADD TO SHORTLIST")
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(isShortlisted ? Retro.background : Retro.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isShortlisted ? Retro.highlight : Retro.panel.opacity(0.7))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                PlayerPortraitView(name: player.name, position: player.position, age: player.age, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("Age \(player.age) · \(player.detailedPosition.fullName) · \(player.foot)")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                    OverallRatingView(rating: player.rating)
                }
                Spacer()
                VStack {
                    Text("\(player.rating)")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text("OVR").font(.system(.caption2, design: .monospaced))
                }
            }
            if !player.secondaryPositions.isEmpty {
                HStack(spacing: 6) {
                    Text("ALSO PLAYS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                    ForEach(player.secondaryPositions, id: \.self) { role in
                        Text(role.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Retro.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Retro.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    private var attributesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            attribute("Value", formatMoney(player.value))
            attribute("Wage / wk", formatMoney(player.wage))
            attribute("Morale", player.moraleLabel)
            attribute("Contract", "Until \(store.contractExpiryYear(player))")
            attribute("Fitness", "\(player.fitnessLabel) (\(player.fitness)%)")
            attribute("Durability", player.durability.label)
            attribute("Personality", player.personality.label)
            if let clause = player.releaseClause {
                attribute("Release clause", formatMoney(clause))
            }
            if let clause = player.sellOnClause {
                attribute("Sell-on owed", "\(clause.percentage)% to \(clause.club)")
            }
            if let clause = player.buyBackClause {
                attribute("Buy-back", "\(formatMoney(clause.fee)) — \(clause.club)")
            }
        }
    }

    @ViewBuilder
    private func scoutSection(_ target: TransferTarget) -> some View {
        Panel(title: "SCOUTING") {
            switch store.scoutState(for: target) {
            case .unscouted:
                Text("Not yet scouted. Assign a scout to reveal potential and a recommendation.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            case .inProgress:
                Text("🔍 Scout watching — report due in a few days.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
            case .scouted(let report):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potential ~\(report.potential)")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(report.verdict)
                        .font(.system(.footnote, design: .monospaced))
                    Text(report.note)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                }
            }
        }
    }

    private func attribute(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.panel.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var seasonPanel: some View {
        Panel(title: "THIS SEASON") {
            HStack {
                Text("Apps \(player.apps)")
                Spacer()
                Text(player.averageRating.map { String(format: "Avg %.2f", $0) } ?? "Avg —")
                Spacer()
                Text("Goals \(player.goals)")
            }
            .font(.system(.callout, design: .monospaced))
        }
    }

    private var profileInfoPanel: some View {
        Panel(title: "PROFILE") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                infoCell("Foot", player.foot)
                infoCell("Status", statusText)
                infoCell("Form", player.formGuide.isEmpty ? "—" : player.formGuide.map(String.init).joined(separator: "-"))
                infoCell("Ability", String(repeating: "★", count: player.stars) + String(repeating: "☆", count: 5 - player.stars))
            }
        }
    }

    private var statusText: String {
        switch context {
        case .squad:                     return store.squadStatus(for: player)
        case .market:                    return "Transfer target"
        case .scouted(_, let clubIndex):
            return store.clubs.indices.contains(clubIndex) ? store.clubs[clubIndex].name : "Unattached"
        }
    }

    private func infoCell(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            Text(value).bold().foregroundStyle(Retro.accent)
        }
        .font(.system(.footnote, design: .monospaced))
    }

    private var attributesPanel: some View {
        Panel(title: "ATTRIBUTES") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(player.attributeOrder, id: \.self) { name in
                    AttributeBar(name: name, value: player.attributes[name] ?? 0)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            if player.isInjured {
                if let date = store.expectedReturnDate(for: player) {
                    badge("⚠️ Injured — expected back \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                } else {
                    badge("⚠️ Injured — out ~\(player.injuryWeeks) wk\(player.injuryWeeks == 1 ? "" : "s")")
                }
            }
            if player.isSuspended {
                badge("⛔ Suspended for \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es")")
            }
            if player.isOnLoan {
                badge("↩︎ On loan — returns to parent club at season end")
            }
            if player.wantsToLeave {
                badge("💢 Unsettled — has asked to leave")
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Retro.highlight)
            .font(.system(.footnote, design: .monospaced))
    }

    @ViewBuilder
    private var actionButton: some View {
        switch context {
        case .squad(let p):
            VStack(spacing: 8) {
                if !p.isOnLoan {
                    HStack(spacing: 8) {
                        pill(store.captainID == p.id ? "CAPTAIN ✓" : "CAPTAIN", filled: store.captainID == p.id) {
                            store.setCaptain(p); onAction("\(p.name) is now club captain."); dismiss()
                        }
                        pill(store.penaltyTakerID == p.id ? "PENS ✓" : "PENS", filled: store.penaltyTakerID == p.id) {
                            store.setPenaltyTaker(p); onAction("\(p.name) is on penalties."); dismiss()
                        }
                        pill(store.freeKickTakerID == p.id ? "FREE-KICKS ✓" : "FREE-KICKS", filled: store.freeKickTakerID == p.id) {
                            store.setFreeKickTaker(p); onAction("\(p.name) takes free-kicks."); dismiss()
                        }
                        pill(store.cornerTakerID == p.id ? "CORNERS ✓" : "CORNERS", filled: store.cornerTakerID == p.id) {
                            store.setCornerTaker(p); onAction("\(p.name) takes corners."); dismiss()
                        }
                    }
                    if p.wantsToLeave && !p.isTransferListed {
                        HStack(spacing: 8) {
                            pill("TALK ROUND", filled: false) {
                                onAction(store.respondToTransferRequest(p, agreeToList: false)); dismiss()
                            }
                            pill("AGREE TO LIST", filled: false) {
                                onAction(store.respondToTransferRequest(p, agreeToList: true)); dismiss()
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        pill("NEGOTIATE (\(formatMoney(store.renewalDemand(p)))/wk)", filled: false) {
                            Haptics.tap()
                            showingContractOffer = true
                        }
                        pill(p.isTransferListed ? "UNLIST" : "LIST", filled: false) {
                            store.toggleTransferList(p)
                            onAction(p.isTransferListed ? "\(p.name) taken off the list." : "\(p.name) listed.")
                            dismiss()
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain).foregroundStyle(Retro.text)
                    Spacer()
                    if !p.isOnLoan {
                        pill("LOAN OUT", filled: false, enabled: store.transferWindowOpen) {
                            Haptics.tap()
                            showingLoanOut = true
                        }
                        if store.canTerminateContract(p) {
                            pill("TERMINATE", filled: false, enabled: true) {
                                Haptics.tap()
                                showingTerminateConfirm = true
                            }
                        }
                        pill("SELL \(formatMoney(Int(Double(p.value) * 0.9)))",
                             filled: true, enabled: store.transferWindowOpen) {
                            onAction(store.sellPlayer(p)); dismiss()
                        }
                    }
                }
            }
        case .market(let target):
            let isFreeAgent = target.sellingClubIndex == nil
            let canBuy = store.transferWindowOpen && store.userClub.transferBudget >= target.askingPrice
                && store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
            let canSignFree = store.transferWindowOpen
                && store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
            let scouting: Bool = { if case .scouted = store.scoutState(for: target) { return false }; if case .inProgress = store.scoutState(for: target) { return false }; return true }()
            HStack(spacing: 8) {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(Retro.text)
                Spacer()
                if scouting {
                    pill("SCOUT", filled: false) { store.scout(target); onAction("Scout sent to watch \(target.player.name)."); dismiss() }
                }
                if target.sellingClubIndex != nil {
                    pill("LOAN", filled: false, enabled: store.transferWindowOpen) {
                        onAction(store.loanIn(target)); dismiss()
                    }
                }
                if isFreeAgent {
                    pill(store.transferWindowOpen ? "SIGN (FREE)" : "CLOSED",
                         filled: true, enabled: canSignFree) {
                        Haptics.tap()
                        showingFreeAgentOffer = true
                    }
                } else {
                    // Negotiating is the featured path — a real back-and-forth
                    // over the fee, not a one-tap purchase. Paying full asking
                    // price outright is still there for anyone in a hurry, just
                    // no longer the primary button.
                    pill(store.transferWindowOpen ? "PAY ASKING \(formatMoney(target.askingPrice))" : "CLOSED",
                         filled: false, enabled: canBuy) {
                        onAction(store.buyPlayer(target)); dismiss()
                    }
                    pill("NEGOTIATE", filled: true, enabled: store.transferWindowOpen) {
                        Haptics.tap()
                        showingBidOffer = true
                    }
                }
            }
        case .scouted(let p, let clubIndex):
            let isFreeAgent = p.contractYears <= 0
            let fee = store.negotiatedFee(for: p)
            let canBid = store.transferWindowOpen && store.userClub.transferBudget >= fee
                && store.userClub.wageBill + p.wage <= store.userClub.wageBudget
            let canSignFree = store.transferWindowOpen
                && store.userClub.wageBill + p.wage <= store.userClub.wageBudget
            HStack(spacing: 8) {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(Retro.text)
                Spacer()
                if isFreeAgent {
                    pill(store.transferWindowOpen ? "SIGN (FREE)" : "WINDOW CLOSED",
                         filled: true, enabled: canSignFree) {
                        Haptics.tap()
                        showingFreeAgentOffer = true
                    }
                } else {
                    pill(store.transferWindowOpen ? "OFFER \(formatMoney(fee))" : "WINDOW CLOSED",
                         filled: true, enabled: canBid) {
                        onAction(store.signFromSearch(clubIndex: clubIndex, playerID: p.id)); dismiss()
                    }
                }
            }
        }
    }

    private func pill(_ title: String, filled: Bool, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            filled ? Haptics.impact() : Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(.callout, design: .monospaced).bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(filled ? (enabled ? Retro.accent : Retro.panel) : Retro.panel)
                .foregroundStyle(filled ? (enabled ? Retro.background : Retro.text.opacity(0.5)) : Retro.text)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: (filled && enabled) ? Retro.accent.opacity(0.35) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }
}

/// A two-way contract negotiation: pick a wage and length, the player
/// accepts or turns it down depending on how it stacks up against their
/// demand, morale, and — for very short or very long deals — their age.
struct ContractOfferSheet: View {
    let store: GameStore
    let player: Player
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wage: Int
    @State private var years = 3
    @State private var lastOutcome: GameStore.ContractOutcome?
    @State private var includeReleaseClause = false
    @State private var releaseClause: Int
    @State private var signingOnFee = 0
    @State private var selectedTab: Tab = .offer

    enum Tab: String, CaseIterable, Identifiable {
        case offer = "Current Offer"
        case existing = "Existing Contract"
        var id: String { rawValue }
    }

    private var demand: Int
    private var step: Int
    private var clauseStep: Int
    private var feeStep: Int

    init(store: GameStore, player: Player, onResult: @escaping (String) -> Void) {
        self.store = store
        self.player = player
        self.onResult = onResult
        let demand = store.renewalDemand(player)
        self.demand = demand
        self.step = max(1, demand / 20)
        _wage = State(initialValue: demand)
        let suggestedClause = max(500, player.value * 2)
        self.clauseStep = max(100, suggestedClause / 20)
        _releaseClause = State(initialValue: suggestedClause)
        self.feeStep = max(25, player.value / 40)
    }

    private var newExpiryYear: Int { (store.startYear - 1) + store.season + years }

    private var squadRole: SquadRole { store.squadRole(for: player) }

    private var roleColor: Color {
        switch squadRole {
        case .starPlayer:       return Retro.highlight
        case .firstTeamRegular: return Retro.accent
        case .rotation:         return Color(red: 0.55, green: 0.70, blue: 0.95)
        case .backup:           return Retro.text.opacity(0.6)
        case .youthProspect:    return Color(red: 0.55, green: 0.85, blue: 0.55)
        }
    }

    private var roleFlavour: String {
        switch squadRole {
        case .starPlayer:       return "He knows he's one of your best — expect him to push hard for top wages."
        case .firstTeamRegular: return "A trusted regular in the side — a fair, market-rate deal keeps him happy."
        case .rotation:         return "In and out of the side — reasonable terms, nothing outlandish."
        case .backup:           return "Fringe squad player — happy to sign for less if it means staying part of things."
        case .youthProspect:    return "Academy prospect — game time matters more to him than the wage packet."
        }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("CONTRACT NEGOTIATION")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text(squadRole.rawValue.uppercased())
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(roleColor)
                        .clipShape(Capsule())
                    Text("Currently wants \(formatMoney(demand))/wk")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                    Text(roleFlavour)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    VStack(spacing: 16) {
                        infoStrip

                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        if selectedTab == .existing {
                            existingContractPanel
                        } else {

                        VStack(spacing: 10) {
                            Text("WEEKLY WAGE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { wage = max(1, wage - step) }
                                Text(formatMoney(wage))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(wage >= demand ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { wage += step }
                            }
                        }

                        VStack(spacing: 10) {
                            Text("CONTRACT LENGTH")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            Picker("Years", selection: $years) {
                                ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(spacing: 8) {
                            Text("SIGNING-ON FEE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 16) {
                                stepButton("minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                                Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(signingOnFee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                    .frame(minWidth: 90)
                                stepButton("plus.circle.fill") { signingOnFee += feeStep }
                            }
                            Text("A one-off bonus, paid from the transfer budget, that sweetens the deal.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }

                        VStack(spacing: 8) {
                            Toggle(isOn: $includeReleaseClause) {
                                Text("RELEASE CLAUSE")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                            }
                            .tint(Retro.accent)
                            if includeReleaseClause {
                                HStack(spacing: 16) {
                                    stepButton("minus.circle.fill") { releaseClause = max(clauseStep, releaseClause - clauseStep) }
                                    Text(formatMoney(releaseClause))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(Retro.highlight)
                                        .frame(minWidth: 90)
                                    stepButton("plus.circle.fill") { releaseClause += clauseStep }
                                }
                                Text("Guarantees any rival bid for him is at least this much.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
                            }
                        }

                        offerSummaryBox

                        }
                    }
                    .padding(.vertical, 4)
                }

                if case .accepted(let message) = lastOutcome {
                    Button {
                        onResult(message)
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(.headline, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                } else if selectedTab == .offer {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeOffer(wage: wage)
                        } label: {
                            Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                                .font(.system(.headline, design: .monospaced).bold())
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                } else {
                    Button("Close") { finish() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    /// Leaves the sheet, passing the last outcome's message up (if there
    /// was one) so the caller's toast still reflects what happened.
    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeOffer(wage offerWage: Int) {
        Haptics.impact()
        let outcome = store.proposeRenewal(player, wage: offerWage, years: years,
                                           releaseClause: includeReleaseClause ? releaseClause : nil,
                                           signingOnFee: signingOnFee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.ContractOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ ACCEPTED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason, let counterWage):
            VStack(spacing: 6) {
                Text("❌ DECLINED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterWage {
                    Button {
                        wage = counterWage
                        makeOffer(wage: counterWage)
                    } label: {
                        Text("Offer \(formatMoney(counterWage))/wk instead")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Retro.highlight)
                            .foregroundStyle(Retro.background)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var infoStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRANSFER BUDGET").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                Text(formatMoney(store.userClub.transferBudget)).font(.system(.callout, design: .monospaced).bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MOOD").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Retro.text.opacity(0.15))
                        Capsule().fill(moraleColor).frame(width: geo.size.width * CGFloat(player.morale) / 100)
                    }
                }
                .frame(width: 70, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var moraleColor: Color {
        switch player.morale {
        case 70...:   return Retro.accent
        case 45..<70: return Retro.highlight
        default:      return Color(red: 0.95, green: 0.45, blue: 0.35)
        }
    }

    private var existingContractPanel: some View {
        VStack(spacing: 14) {
            contractRow("Current wage", formatMoney(player.wage) + "/wk")
            contractRow("Years remaining", "\(player.contractYears)")
            contractRow("Contract expiry", "\(store.contractExpiryYear(player))")
            contractRow("Release clause", player.releaseClause.map(formatMoney) ?? "None")
            contractRow("Squad status", squadRole.rawValue)
        }
        .padding(.vertical, 8)
    }

    private func contractRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
        }
        .padding(.horizontal, 4)
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Retro.text.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Retro.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var offerSummarySentence: String {
        var sentence = "I'm proposing \(formatMoney(wage)) per week until 30/6/\(newExpiryYear)"
        if signingOnFee > 0 {
            sentence += ", plus a \(formatMoney(signingOnFee)) signing-on fee"
        }
        if includeReleaseClause {
            sentence += ", with a \(formatMoney(releaseClause)) release clause"
        }
        return sentence + "."
    }
}

/// Signing a free agent (or a search-found player with an already-expired
/// contract) — no transfer fee exists to negotiate, so this is personal
/// terms only: wage and contract length, same negotiation feel as a
/// renewal but landing the player at your club instead of keeping them put.
struct FreeAgentContractSheet: View {
    let store: GameStore
    let player: Player
    let fromClubIndex: Int?
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wage: Int
    @State private var years = 3
    @State private var lastOutcome: GameStore.ContractOutcome?
    @State private var signingOnFee = 0

    private var demand: Int
    private var step: Int
    private var feeStep: Int

    init(store: GameStore, player: Player, fromClubIndex: Int?, onResult: @escaping (String) -> Void) {
        self.store = store
        self.player = player
        self.fromClubIndex = fromClubIndex
        self.onResult = onResult
        let demand = store.freeAgentWageDemand(player)
        self.demand = demand
        self.step = max(1, demand / 20)
        _wage = State(initialValue: demand)
        self.feeStep = max(25, player.value / 40)
    }

    private var squadRole: SquadRole { store.squadRole(for: player) }

    private var roleColor: Color {
        switch squadRole {
        case .starPlayer:       return Retro.highlight
        case .firstTeamRegular: return Retro.accent
        case .rotation:         return Color(red: 0.55, green: 0.70, blue: 0.95)
        case .backup:           return Retro.text.opacity(0.6)
        case .youthProspect:    return Color(red: 0.55, green: 0.85, blue: 0.55)
        }
    }

    private var newExpiryYear: Int { (store.startYear - 1) + store.season + years }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("FREE TRANSFER")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text(squadRole.rawValue.uppercased())
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(roleColor)
                        .clipShape(Capsule())
                    Text("No fee — just agree personal terms. Wants \(formatMoney(demand))/wk")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        infoStrip

                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        VStack(spacing: 10) {
                            Text("WEEKLY WAGE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { wage = max(1, wage - step) }
                                Text(formatMoney(wage))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(wage >= demand ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { wage += step }
                            }
                        }

                        VStack(spacing: 10) {
                            Text("CONTRACT LENGTH")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            Picker("Years", selection: $years) {
                                ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(spacing: 8) {
                            Text("SIGNING-ON FEE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 16) {
                                stepButton("minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                                Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(signingOnFee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                    .frame(minWidth: 90)
                                stepButton("plus.circle.fill") { signingOnFee += feeStep }
                            }
                            Text("A one-off bonus, paid from the transfer budget, that sweetens the deal.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }

                        offerSummaryBox
                    }
                    .padding(.vertical, 4)
                }

                if case .accepted(let message) = lastOutcome {
                    Button {
                        onResult(message)
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(.headline, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                } else {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeOffer(wage: wage)
                        } label: {
                            Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                                .font(.system(.headline, design: .monospaced).bold())
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeOffer(wage offerWage: Int) {
        Haptics.impact()
        let outcome = store.signFreeAgent(player, fromClubIndex: fromClubIndex, wage: offerWage, years: years, signingOnFee: signingOnFee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.ContractOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ SIGNED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason, let counterWage):
            VStack(spacing: 6) {
                Text("❌ DECLINED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterWage {
                    Button {
                        wage = counterWage
                        makeOffer(wage: counterWage)
                    } label: {
                        Text("Offer \(formatMoney(counterWage))/wk instead")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Retro.highlight)
                            .foregroundStyle(Retro.background)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var infoStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRANSFER BUDGET").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                Text(formatMoney(store.userClub.transferBudget)).font(.system(.callout, design: .monospaced).bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MOOD").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Retro.text.opacity(0.15))
                        Capsule().fill(moraleColor).frame(width: geo.size.width * CGFloat(player.morale) / 100)
                    }
                }
                .frame(width: 70, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var moraleColor: Color {
        switch player.morale {
        case 70...:   return Retro.accent
        case 45..<70: return Retro.highlight
        default:      return Color(red: 0.95, green: 0.45, blue: 0.35)
        }
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Retro.text.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Retro.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var offerSummarySentence: String {
        var sentence = "I'm proposing \(formatMoney(wage)) per week until 30/6/\(newExpiryYear)"
        if signingOnFee > 0 {
            sentence += ", plus a \(formatMoney(signingOnFee)) signing-on fee"
        }
        return sentence + "."
    }
}

/// Every scouting assessment filed so far, in one list — findings from a
/// specific "scout this player" assignment and from a broader world/youth
/// scouting mission alike. A report whose target has since left the
/// transfer market (sold elsewhere, window closed) still shows, just
/// without a way to act on it.
struct ScoutReportsSheet: View {
    let store: GameStore
    let onSelect: (ProfileContext) -> Void
    @Environment(\.dismiss) private var dismiss

    private var reports: [ScoutReport] {
        store.scoutedReports.values.sorted { $0.potential > $1.potential }
    }

    private func target(for report: ScoutReport) -> TransferTarget? {
        store.transferMarket.first { $0.player.id == report.playerID }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("SCOUT REPORTS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Retro.text.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                if reports.isEmpty {
                    Spacer()
                    Text("No reports filed yet — scout a target, or send scouts out into the world.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(reports.enumerated()), id: \.offset) { _, report in
                                reportRow(report)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func reportRow(_ report: ScoutReport) -> some View {
        let live = target(for: report)
        return Button {
            guard let live else { return }
            Haptics.tap()
            onSelect(.market(live))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(report.playerName)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Text("POT ~\(report.potential)")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                }
                Text(report.verdict)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
                HStack {
                    Text(report.note)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                    Spacer()
                    if live == nil {
                        Text("NO LONGER AVAILABLE")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.text.opacity(0.5))
                    } else {
                        Text(live.map { formatMoney($0.askingPrice) } ?? "")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.accent)
                    }
                }
            }
            .padding(10)
            .background(Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(live == nil)
    }
}

/// A haggling flow for a transfer-market target: bid below asking price
/// and the selling club may reject outright or counter with a figure
/// they'd actually accept, instead of asking price being the only number
/// that ever works.
struct TransferBidSheet: View {
    let store: GameStore
    let target: TransferTarget
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Int
    @State private var lastOutcome: GameStore.BidOutcome?
    @State private var sellOnPercentage = 0
    @State private var includeBuyBack = false
    @State private var buyBackFee: Int
    @State private var includedPlayerID: UUID?
    @State private var selectedTab: Tab = .offer

    enum Tab: String, CaseIterable, Identifiable {
        case offer = "Current Offer"
        case interested = "Interested Clubs"
        var id: String { rawValue }
    }

    private let step: Int
    private let buyBackStep: Int

    init(store: GameStore, target: TransferTarget, onResult: @escaping (String) -> Void) {
        self.store = store
        self.target = target
        self.onResult = onResult
        let starting = Int(Double(target.askingPrice) * 0.85)
        _amount = State(initialValue: starting)
        self.step = max(1, target.askingPrice / 20)
        let suggestedBuyBack = max(50, Int(Double(target.player.value) * 1.3))
        self.buyBackFee = suggestedBuyBack
        self.buyBackStep = max(25, suggestedBuyBack / 20)
    }

    private var sellerIndex: Int? { target.sellingClubIndex }
    private var sellerName: String { sellerIndex.map { store.clubs[$0].name } ?? "Free agent" }

    private var sellerUnderPressure: Bool {
        guard let sellerIndex else { return false }
        let seller = store.clubs[sellerIndex]
        return seller.transferBudget < seller.wageBill * 8
    }

    private var interestedClubsCount: Int {
        let ratingFactor = max(0, (target.player.rating - 65) / 8)
        let seed = abs(target.id.hashValue) % 3
        return min(4, ratingFactor + seed)
    }

    private var assistantAdvice: String {
        if sellerUnderPressure {
            return "\(sellerName) are short on transfer funds and may accept a below-value offer."
        }
        if target.player.contractYears <= 1 {
            return "\(target.player.name)'s contract is close to expiry — \(sellerName) may be more willing to do business."
        }
        return "\(target.player.name) isn't near the end of his contract and is unlikely to be sold cheaply."
    }

    private var eligibleMakeweights: [Player] {
        Array(
            store.userClub.players
                .filter { !store.userStarterIDs.contains($0.id) }
                .sorted { $0.value > $1.value }
                .prefix(8)
        )
    }

    private var includedPlayer: Player? {
        includedPlayerID.flatMap { id in store.userClub.players.first { $0.id == id } }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("NEGOTIATE FEE")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(target.player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("Asking price \(formatMoney(target.askingPrice)) · \(sellerName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                }

                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    VStack(spacing: 16) {
                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        if selectedTab == .interested {
                            interestedClubsPanel
                        } else {

                        assistantAdviceBox

                        VStack(spacing: 10) {
                            Text("YOUR OFFER")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { amount = max(step, amount - step) }
                                Text(formatMoney(amount))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(amount >= target.askingPrice ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { amount += step }
                            }
                        }

                        if let sellerIndex {
                            VStack(spacing: 8) {
                                Text("SELL-ON PERCENTAGE")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                HStack(spacing: 16) {
                                    stepButton("minus.circle.fill") { sellOnPercentage = max(0, sellOnPercentage - 5) }
                                    Text(sellOnPercentage > 0 ? "\(sellOnPercentage)%" : "None")
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(sellOnPercentage > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                        .frame(minWidth: 90)
                                    stepButton("plus.circle.fill") { sellOnPercentage = min(25, sellOnPercentage + 5) }
                                }
                                Text("A cut of any future resale for \(store.clubs[sellerIndex].name) — sweetens the deal.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
                            }

                            VStack(spacing: 8) {
                                Toggle(isOn: $includeBuyBack) {
                                    Text("BUY-BACK CLAUSE")
                                        .font(.system(.caption2, design: .monospaced).bold())
                                        .foregroundStyle(Retro.text.opacity(0.7))
                                }
                                .tint(Retro.accent)
                                if includeBuyBack {
                                    HStack(spacing: 16) {
                                        stepButton("minus.circle.fill") { buyBackFee = max(buyBackStep, buyBackFee - buyBackStep) }
                                        Text(formatMoney(buyBackFee))
                                            .font(.system(.callout, design: .monospaced).bold())
                                            .foregroundStyle(Retro.highlight)
                                            .frame(minWidth: 90)
                                        stepButton("plus.circle.fill") { buyBackFee += buyBackStep }
                                    }
                                    Text("\(store.clubs[sellerIndex].name) can re-sign him at this fee later. A lower fee helps close the deal now.")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Retro.text.opacity(0.6))
                                }
                            }

                            if !eligibleMakeweights.isEmpty {
                                VStack(spacing: 8) {
                                    Text("EXCHANGE PLAYER")
                                        .font(.system(.caption2, design: .monospaced).bold())
                                        .foregroundStyle(Retro.text.opacity(0.7))
                                    Picker("Exchange", selection: $includedPlayerID) {
                                        Text("None").tag(UUID?.none)
                                        ForEach(eligibleMakeweights) { p in
                                            Text("\(p.name) (\(formatMoney(p.value)))").tag(Optional(p.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Retro.accent)
                                    if let includedPlayer {
                                        Text("\(includedPlayer.name) goes the other way, cutting the cash you need to find.")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                    }
                                }
                            }
                        }

                        offerSummaryBox

                        }
                    }
                    .padding(.vertical, 4)
                }

                if case .accepted(let message) = lastOutcome {
                    Button {
                        onResult(message)
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(.headline, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                } else if selectedTab == .offer {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeBid(amount)
                        } label: {
                            Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                                .font(.system(.headline, design: .monospaced).bold())
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                } else {
                    Button("Close") { finish() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeBid(_ offer: Int) {
        Haptics.impact()
        let outcome = store.proposeBid(target, amount: offer, sellOnPercentage: sellOnPercentage,
                                       buyBackFee: includeBuyBack ? buyBackFee : 0, includedPlayer: includedPlayer)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.BidOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ ACCEPTED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason, let counterPrice):
            VStack(spacing: 6) {
                Text("❌ REJECTED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterPrice {
                    Button {
                        amount = counterPrice
                        makeBid(counterPrice)
                    } label: {
                        Text("Offer \(formatMoney(counterPrice)) instead")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Retro.highlight)
                            .foregroundStyle(Retro.background)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var assistantAdviceBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.fill.questionmark")
                .foregroundStyle(Retro.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("ASSISTANT ADVICE")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.6))
                Text(assistantAdvice)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Retro.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var interestedClubsPanel: some View {
        VStack(spacing: 10) {
            if interestedClubsCount == 0 {
                Text("No other clubs are known to be tracking \(target.player.name) right now.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Text("\(interestedClubsCount) other club\(interestedClubsCount == 1 ? "" : "s") \(interestedClubsCount == 1 ? "is" : "are") also monitoring this move.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text("Dragging the negotiation out risks losing him to a rival bid — move quickly if you want him.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Retro.text.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Retro.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var offerSummarySentence: String {
        var sentence = "Offering \(formatMoney(amount))"
        if let includedPlayer {
            sentence += " plus \(includedPlayer.name)"
        }
        sentence += " for \(target.player.name)"
        if sellOnPercentage > 0 {
            sentence += ", with a \(sellOnPercentage)% sell-on"
        }
        if includeBuyBack {
            sentence += ", and a \(formatMoney(buyBackFee)) buy-back option"
        }
        return sentence + "."
    }
}

/// Personal-terms negotiation for a transfer whose fee is already agreed
/// with the selling club — the final step that actually completes a
/// signing initiated through `TransferBidSheet` or a direct "pay asking"
/// buy, once the player's medical is done and he's ready to talk.
struct PersonalTermsSheet: View {
    let store: GameStore
    let deal: PendingTransferDeal
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wage: Int
    @State private var years = 3
    @State private var lastOutcome: GameStore.ContractOutcome?
    @State private var signingOnFee = 0

    private var demand: Int
    private var step: Int
    private var feeStep: Int

    init(store: GameStore, deal: PendingTransferDeal, onResult: @escaping (String) -> Void) {
        self.store = store
        self.deal = deal
        self.onResult = onResult
        let demand = store.transferWageDemand(deal.player)
        self.demand = demand
        self.step = max(1, demand / 20)
        _wage = State(initialValue: demand)
        self.feeStep = max(25, deal.player.value / 40)
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("PERSONAL TERMS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(deal.player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("Fee of \(formatMoney(deal.agreedFee)) already agreed with \(deal.sellingClubName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .multilineTextAlignment(.center)
                    Text("Wants \(formatMoney(demand))/wk to make the move")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }

                ScrollView {
                    VStack(spacing: 16) {
                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        VStack(spacing: 10) {
                            Text("WEEKLY WAGE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { wage = max(1, wage - step) }
                                Text(formatMoney(wage))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(wage >= demand ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { wage += step }
                            }
                        }

                        VStack(spacing: 10) {
                            Text("CONTRACT LENGTH")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            Picker("Years", selection: $years) {
                                ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(spacing: 8) {
                            Text("SIGNING-ON FEE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 16) {
                                stepButton("minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                                Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(signingOnFee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                    .frame(minWidth: 90)
                                stepButton("plus.circle.fill") { signingOnFee += feeStep }
                            }
                            Text("A one-off bonus, paid on top of the transfer fee, that sweetens the deal.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 4)
                }

                if case .accepted(let message) = lastOutcome {
                    Button {
                        onResult(message)
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(.headline, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                } else {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeOffer(wage: wage)
                        } label: {
                            Text(lastOutcome == nil ? "PROPOSE TERMS" : "OFFER AGAIN")
                                .font(.system(.headline, design: .monospaced).bold())
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeOffer(wage offerWage: Int) {
        Haptics.impact()
        let outcome = store.finalizePersonalTerms(deal, wage: offerWage, years: years, signingOnFee: signingOnFee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.ContractOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ AGREED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason, let counterWage):
            VStack(spacing: 6) {
                Text("❌ DECLINED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterWage {
                    Button {
                        wage = counterWage
                        makeOffer(wage: counterWage)
                    } label: {
                        Text("Offer \(formatMoney(counterWage))/wk instead")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Retro.highlight)
                            .foregroundStyle(Retro.background)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Loaning a squad player out: pick a genuinely interested club, decide
/// whether to ask for a fee, and see whether they actually say yes — real
/// loan logic (squad need, wage affordability) instead of a single-tap
/// instant move to a random club.
struct LoanOutSheet: View {
    let store: GameStore
    let player: Player
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    let candidates: [Int]
    @State private var selectedClubIndex: Int?
    @State private var fee = 0
    @State private var lastOutcome: GameStore.LoanOutcome?

    private let feeStep: Int

    init(store: GameStore, player: Player, onResult: @escaping (String) -> Void) {
        self.store = store
        self.player = player
        self.onResult = onResult
        let candidates = store.loanCandidates(for: player)
        self.candidates = candidates
        _selectedClubIndex = State(initialValue: candidates.first)
        self.feeStep = max(10, player.value / 40)
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("LOAN OUT")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("\(formatMoney(player.wage))/wk comes off your wage bill for the loan.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                if candidates.isEmpty {
                    Spacer()
                    Text("No club has room or a genuine need for him right now.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let lastOutcome {
                                resultBanner(lastOutcome)
                            }

                            VStack(spacing: 8) {
                                Text("DESTINATION")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                Picker("Club", selection: $selectedClubIndex) {
                                    ForEach(candidates, id: \.self) { index in
                                        Text(store.clubs[index].name).tag(Optional(index))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Retro.accent)
                            }

                            VStack(spacing: 8) {
                                Text("LOAN FEE")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                HStack(spacing: 16) {
                                    stepButton("minus.circle.fill") { fee = max(0, fee - feeStep) }
                                    Text(fee > 0 ? formatMoney(fee) : "None")
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(fee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                        .frame(minWidth: 90)
                                    stepButton("plus.circle.fill") { fee += feeStep }
                                }
                                Text("Asking for a fee makes them less likely to say yes.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if case .accepted(let message) = lastOutcome {
                        Button {
                            onResult(message)
                            dismiss()
                        } label: {
                            Text("DONE")
                                .font(.system(.headline, design: .monospaced).bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        HStack(spacing: 10) {
                            Button("Cancel") { finish() }
                                .buttonStyle(.plain)
                                .foregroundStyle(Retro.text)
                            Spacer()
                            Button {
                                propose()
                            } label: {
                                Text(lastOutcome == nil ? "PROPOSE LOAN" : "TRY AGAIN")
                                    .font(.system(.headline, design: .monospaced).bold())
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .background(Retro.accent)
                                    .foregroundStyle(Retro.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(selectedClubIndex == nil)
                        }
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason): onResult(reason)
            }
        }
        dismiss()
    }

    private func propose() {
        guard let selectedClubIndex else { return }
        Haptics.impact()
        let outcome = store.proposeLoanOut(player, toClubIndex: selectedClubIndex, fee: fee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.LoanOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ AGREED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason):
            VStack(spacing: 4) {
                Text("❌ PASSED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Reusable pieces

/// A themed "are you sure" screen for any hard-to-reverse action — release,
/// loan out, anything that shouldn't be one accidental tap away. Styled to
/// match the rest of the app rather than a plain system alert.
struct ConfirmActionSheet: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                Text(title)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Button {
                        Haptics.warning()
                        onConfirm()
                    } label: {
                        Text(confirmLabel)
                            .font(.system(.headline, design: .monospaced).bold())
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.9, green: 0.35, blue: 0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }
}

/// One attribute row: name, value and a coloured 1...20 bar.
struct AttributeBar: View {
    let name: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Retro.text.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 20)
                }
            }
            .frame(height: 6)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 20, alignment: .trailing)
        }
    }

    private var color: Color {
        switch value {
        case 15...: return Retro.accent
        case 10..<15: return Retro.highlight
        default: return Retro.text.opacity(0.6)
        }
    }
}

/// A simple crest: the club's short name inside a rounded badge.
/// A circular initials "headshot" for a player — no real portraits exist
/// in this game, so a coloured monogram (tinted by position, like a strip
/// colour) stands in for one anywhere a player card is shown.
struct PlayerAvatarView: View {
    let name: String
    let position: Position?
    let size: CGFloat
    var age: Int? = nil

    var body: some View {
        PlayerPortraitView(name: name, position: position, age: age, size: size)
    }
}

struct CrestView: View {
    let shortName: String
    let size: CGFloat
    var color: Color = Retro.accent

    var body: some View {
        ClubBadgeView(name: shortName, shortName: shortName, size: size, primaryColor: color)
    }
}

/// A row of filled/empty stars for a club's rating.
struct StarRatingView: View {
    let stars: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= stars ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(Retro.highlight)
            }
        }
    }
}

/// A player's overall ability as a plain numeric reading, coloured by
/// tier — used everywhere a player's rating is shown.
struct OverallRatingView: View {
    let rating: Int

    var body: some View {
        Text("\(rating)")
            .font(.system(.callout, design: .monospaced).bold())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch rating {
        case 85...:   return Retro.highlight
        case 75..<85: return Retro.accent
        case 65..<75: return Color(red: 0.55, green: 0.70, blue: 0.95)
        default:      return Retro.text
        }
    }
}

/// A row of coloured W/D/L boxes showing recent form.
struct FormView: View {
    let outcomes: [MatchOutcome]

    var body: some View {
        HStack(spacing: 3) {
            if outcomes.isEmpty {
                Text("No games played yet")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            } else {
                ForEach(Array(outcomes.enumerated()), id: \.offset) { _, outcome in
                    Text(outcome.letter)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(color(for: outcome))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func color(for outcome: MatchOutcome) -> Color {
        switch outcome {
        case .win:  return Color(red: 0.20, green: 0.65, blue: 0.25)
        case .draw: return Color(red: 0.45, green: 0.45, blue: 0.45)
        case .loss: return Color(red: 0.75, green: 0.20, blue: 0.20)
        }
    }
}

// MARK: - Inbox

struct InboxView: View {
    let store: GameStore
    @State private var message: String?
    @State private var folder: InboxFolder = .all
    @State private var openItem: NewsItem?

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
                    Text(item.title)
                        .font(.system(.callout, design: .monospaced).weight(unread ? .bold : .regular))
                        .foregroundStyle(Retro.text)
                        .lineLimit(1)
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

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
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

// MARK: - Settings

/// A destination reachable from the Settings menu — mirrors the grouped
/// MANAGER / OPTIONS list pattern, so each is a focused single-topic page
/// instead of one endless scroll.
enum SettingsDestination: String, CaseIterable, Identifiable {
    case managerProfile = "Manager Profile"
    case boardConfidence = "Board Confidence"
    case trophyCabinet = "Trophy Cabinet"
    case achievements = "Achievements"
    case managerCV = "Manager CV"
    case records = "All-Time Records"
    case hallOfFame = "Hall of Fame"
    case transferHistory = "Transfer History"
    case seasonHistory = "Season History"
    case currentSave = "Current Save"
    case difficulty = "Difficulty"
    case teamSelection = "Team Selection"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .managerProfile:   return "person.text.rectangle.fill"
        case .boardConfidence:  return "gauge.with.dots.needle.67percent"
        case .trophyCabinet:    return "trophy.fill"
        case .achievements:     return "medal.fill"
        case .managerCV:        return "briefcase.fill"
        case .records:          return "chart.bar.fill"
        case .hallOfFame:       return "star.circle.fill"
        case .transferHistory:  return "arrow.left.arrow.right.circle.fill"
        case .seasonHistory:    return "calendar.badge.clock"
        case .currentSave:      return "gamecontroller.fill"
        case .difficulty:       return "slider.horizontal.3"
        case .teamSelection:    return "checklist"
        }
    }

    static let manager: [SettingsDestination] = [.managerProfile, .boardConfidence, .trophyCabinet, .achievements, .managerCV, .records, .hallOfFame, .transferHistory, .seasonHistory]
    static let options: [SettingsDestination] = [.currentSave, .difficulty, .teamSelection]
}

struct SettingsView: View {
    let store: GameStore
    @State private var destination: SettingsDestination?

    var body: some View {
        if let destination {
            SettingsDetailView(store: store, destination: destination) {
                Haptics.tap()
                self.destination = nil
            }
        } else {
            SettingsMenuView(store: store) { selected in
                Haptics.tap()
                destination = selected
            }
        }
    }
}

/// The top-level Settings screen: a grouped list of destinations, tap to
/// drill in — the FM-style "MANAGER" / "OPTIONS" menu.
struct SettingsMenuView: View {
    let store: GameStore
    let onSelect: (SettingsDestination) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("SETTINGS")
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)

                Panel(title: "MANAGER") {
                    VStack(spacing: 6) {
                        ForEach(SettingsDestination.manager) { destination in
                            menuRow(destination)
                        }
                    }
                }

                Panel(title: "OPTIONS") {
                    VStack(spacing: 6) {
                        ForEach(SettingsDestination.options) { destination in
                            menuRow(destination)
                        }
                    }
                }

                Button {
                    store.quitToMenu()
                } label: {
                    Text("⟲  SAVE & EXIT TO MENU")
                        .font(.system(.body, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Retro.accent)
                        .foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private func menuRow(_ destination: SettingsDestination) -> some View {
        Button {
            onSelect(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Retro.accent)
                    .frame(width: 20)
                Text(destination.rawValue)
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Retro.text.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A single Settings sub-page — the drill-down content for one
/// `SettingsDestination`, with a back chevron to return to the menu.
struct SettingsDetailView: View {
    let store: GameStore
    let destination: SettingsDestination
    let onBack: () -> Void

    private func recordLine(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.85))
            Spacer()
            Text(value ?? "—").bold().foregroundStyle(Retro.accent)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.system(.footnote, design: .monospaced))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("SETTINGS")
                            .font(.system(.caption, design: .monospaced).bold())
                    }
                    .foregroundStyle(Retro.accent)
                }
                .buttonStyle(.plain)

                content
            }
            .padding()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .managerProfile:   managerProfilePanel
        case .boardConfidence:  boardConfidencePanel
        case .trophyCabinet:    trophyCabinetPanel
        case .achievements:     achievementsPanel
        case .currentSave:      currentSavePanel
        case .difficulty:       difficultyPanel
        case .teamSelection:    teamSelectionPanel
        case .records:          recordsPanel
        case .hallOfFame:       hallOfFamePanel
        case .managerCV:        managerCVPanel
        case .transferHistory:  transferHistoryPanel
        case .seasonHistory:    seasonHistoryPanel
        }
    }

    private var managerProfilePanel: some View {
        Panel(title: "MANAGER PROFILE") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    CrestView(shortName: store.userClub.shortName, size: 54, color: store.userColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.userClub.name)
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(store.userColor)
                        Text(store.divisionName(store.userDivisionTier))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.75))
                    }
                }
                Divider().overlay(Retro.accent.opacity(0.2))
                recordLine("Reputation", "\(store.reputationLabel) (\(store.managerReputation))")
                recordLine("Job security", store.jobSecurity)
                recordLine("Board objective", store.boardObjective)
                recordLine("Season", store.seasonLabel)
                recordLine("Honours won", "\(store.careerHonours.count)")
            }
            .font(.system(.callout, design: .monospaced))
        }
    }

    private var boardConfidencePanel: some View {
        Panel(title: "BOARD CONFIDENCE") {
            VStack(alignment: .leading, spacing: 12) {
                ConfidenceBar(value: store.boardConfidence, trend: store.boardConfidenceTrend)
                Divider().overlay(Retro.accent.opacity(0.2))
                Text(confidenceReadout)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.9))
                recordLine("This season's objective", store.boardObjective)
                recordLine("Job security", store.jobSecurity)
            }
        }
    }

    private var confidenceReadout: String {
        switch store.boardConfidence {
        case 75...:   return "The board are delighted with how things are going — you have their full backing."
        case 50..<75: return "The board are satisfied. Keep results ticking over and there's no cause for concern."
        case 30..<50: return "Patience is wearing thin upstairs. A poor run from here would put real pressure on you."
        default:      return "The board's confidence has collapsed — your position is under serious threat."
        }
    }

    private var trophyCabinetPanel: some View {
        Panel(title: "TROPHY CABINET") {
            if store.careerHonours.isEmpty {
                Text("Nothing in the cabinet yet — win something to start filling it.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { _, honour in
                        VStack(spacing: 6) {
                            if let guess = TrophyKind.guess(from: honour) {
                                TrophyView(kind: guess.kind, tier: guess.tier, size: 44)
                            } else {
                                TrophyView(kind: .league, tier: .bronze, size: 44)
                            }
                            Text(honour)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    private var achievementsPanel: some View {
        Panel(title: "ACHIEVEMENTS (\(store.unlockedAchievements.count)/\(AchievementKind.allCases.count))") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(AchievementKind.allCases) { kind in
                    let unlocked = store.unlockedAchievements.contains(kind)
                    VStack(spacing: 6) {
                        TrophyView(kind: kind.trophy.kind, tier: unlocked ? kind.trophy.tier : .bronze, size: 40)
                            .opacity(unlocked ? 1 : 0.25)
                            .grayscale(unlocked ? 0 : 1)
                        Text(kind.rawValue)
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(unlocked ? Retro.text : Retro.text.opacity(0.5))
                            .multilineTextAlignment(.center)
                        Text(kind.subtitle)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private var currentSavePanel: some View {
        Panel(title: "CURRENT SAVE") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Club:    \(store.userClub.name) (\(store.divisionName(store.userDivisionTier)))")
                Text("Season:  \(store.seasonLabel)")
                Text("Reputation: \(store.reputationLabel) (\(store.managerReputation))")
                Text("Honours: \(store.careerHonours.count)")
            }
            .font(.system(.callout, design: .monospaced))
        }
    }

    private var difficultyPanel: some View {
        Panel(title: "DIFFICULTY") {
            VStack(alignment: .leading, spacing: 6) {
                Picker("Difficulty", selection: Binding(
                    get: { store.difficulty },
                    set: { store.difficulty = $0 }
                )) {
                    ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Affects your team's edge in matches and how patient the board is.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.75))
            }
        }
    }

    private var teamSelectionPanel: some View {
        Panel(title: "TEAM SELECTION") {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: Binding(
                    get: { store.autoPickAssist },
                    set: { store.autoPickAssist = $0 }
                )) {
                    Text("Assist: auto-pick starting XI")
                        .font(.system(.callout, design: .monospaced).bold())
                }
                .tint(Retro.accent)
                Text("Picks your strongest available side before every match, factoring fitness and morale. When a bigger game is close behind a smaller one (say a midweek cup tie before a big league weekend), it rests key players who aren't fully fresh rather than risking them.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.75))
                Divider().overlay(Retro.accent.opacity(0.2))
                Toggle(isOn: Binding(
                    get: { store.delegateToAssistant },
                    set: { store.delegateToAssistant = $0 }
                )) {
                    Text("Delegate press conferences & team talks")
                        .font(.system(.callout, design: .monospaced).bold())
                }
                .tint(Retro.accent)
                .disabled(store.staffLevel(.assistantManager) < 3)
                Text(store.staffLevel(.assistantManager) >= 3
                     ? "Your assistant handles routine press questions and team talks automatically, picking whichever option reads best."
                     : "Needs an assistant manager of at least level 3 on staff.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.75))
            }
        }
    }

    private var recordsPanel: some View {
        Panel(title: "ALL-TIME RECORDS") {
            let honours = store.honourTally()
            VStack(alignment: .leading, spacing: 4) {
                recordLine("Most league titles", store.mostTitles().map { "\($0.name) (\($0.count))" })
                recordLine("Most National Cups", store.mostCups().map { "\($0.name) (\($0.count))" })
                recordLine("Most Continental Cups", store.mostEuropeanCups().map { "\($0.name) (\($0.count))" })
                recordLine("All-time top scorer", store.topCareerScorer().map { "\($0.name) — \($0.goals)" })
                recordLine("All-time most appearances", store.topCareerAppearances().map { "\($0.name) — \($0.apps)" })
                recordLine("Most Man of the Match awards", store.topCareerMOTM().map { "\($0.name) — \($0.count)" })
                recordLine("\(store.userClub.name)'s biggest win",
                           store.userClub.recordWinMargin > 0 ? store.userClub.recordWinDescription : nil)
                if let record = store.careerRecordByClub[store.userClub.name], record.matches > 0 {
                    recordLine("Home record", "\(record.homeWins)W \(record.homeDraws)D \(record.homeLosses)L")
                    recordLine("Away record", "\(record.awayWins)W \(record.awayDraws)D \(record.awayLosses)L")
                }
                Divider().overlay(Retro.accent.opacity(0.2))
                Text("Your honours: \(honours.titles) titles · \(honours.cups) cups · \(honours.euros) European · \(honours.promotions) promotions")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
            }
            .font(.system(.callout, design: .monospaced))
        }
    }

    private var hallOfFamePanel: some View {
        Panel(title: "HALL OF FAME — BEST XI YOU'VE MANAGED") {
            let xi = store.bestEverXI()
            if xi.isEmpty {
                Text("Complete a season to start building your Hall of Fame.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(xi) { entry in
                        HStack(spacing: 6) {
                            Text(entry.position.rawValue)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.highlight)
                                .frame(width: 32, alignment: .leading)
                            Text(entry.name).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 2)
                            Text("\(entry.peakRating)")
                                .foregroundStyle(Retro.accent).bold()
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
    }

    private var managerCVPanel: some View {
        Panel(title: "MANAGER CV") {
            let cv = store.managerCV()
            if cv.isEmpty {
                Text("Complete a season to start your CV.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(cv) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.club)
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(Retro.accent)
                                Spacer()
                                Text("\(entry.seasons) season\(entry.seasons == 1 ? "" : "s")")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.75))
                            }
                            Text("\(entry.record.wins)W \(entry.record.draws)D \(entry.record.losses)L · \(entry.record.winPercentage)% win rate")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.85))
                            if !entry.trophies.isEmpty {
                                ForEach(entry.trophies, id: \.self) { trophy in
                                    HonourRow(text: trophy, size: 16)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Retro.highlight)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var transferHistoryPanel: some View {
        Panel(title: "TRANSFER HISTORY") {
            if store.transferHistory.isEmpty {
                Text("No transfer activity yet.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.transferHistory.prefix(25)) { entry in
                        HStack {
                            Text(entry.date.formatted(.dateTime.day().month(.abbreviated).year()))
                                .frame(width: 80, alignment: .leading)
                                .foregroundStyle(Retro.text.opacity(0.6))
                            Text("\(entry.action) \(entry.playerName)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let otherClub = entry.otherClub {
                                Text(otherClub)
                                    .foregroundStyle(Retro.text.opacity(0.7))
                            }
                            if let fee = entry.fee {
                                Text(formatMoney(fee))
                                    .foregroundStyle(Retro.highlight)
                            }
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    if store.transferHistory.count > 25 {
                        Text("+ \(store.transferHistory.count - 25) more")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    }
                }
            }
        }
    }

    private var seasonHistoryPanel: some View {
        Panel(title: "SEASON HISTORY") {
            if store.history.isEmpty {
                Text("No completed seasons yet.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text("Season").frame(width: 70, alignment: .leading)
                        Text("You").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Champions").frame(maxWidth: .infinity, alignment: .leading)
                        Text("National Cup").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Europe").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    ForEach(store.history.reversed()) { record in
                        HStack {
                            Text(record.label).frame(width: 70, alignment: .leading)
                            Text("\(ordinal(record.userPosition)) \(record.userDivision)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(Retro.accent)
                            Text(record.champion).frame(maxWidth: .infinity, alignment: .leading)
                            Text(record.cupWinner).frame(maxWidth: .infinity, alignment: .leading)
                            Text(record.euroWinner).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }
}

// MARK: - Squad / Tactics

enum SquadViewMode: String, CaseIterable {
    case tactics = "TACTICS"
    case list = "SQUAD LIST"
}

struct SquadView: View {
    let store: GameStore
    @State private var message: String?
    @State private var mode: SquadViewMode = .tactics
    @State private var showingDepth = false
    @State private var showingTeamSetup = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(SquadViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if mode == .tactics {
                tacticsToolbar
                GeometryReader { geo in
                    // Side-by-side needs real width for both the pitch and
                    // a legible bench list; below that, stack instead of
                    // squeezing the pitch into a sliver.
                    if geo.size.width >= 560 {
                        HStack(spacing: 0) {
                            PitchView(store: store, message: $message)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            SquadListPanel(store: store, message: $message)
                                .frame(width: 248)
                        }
                    } else {
                        VStack(spacing: 0) {
                            PitchView(store: store, message: $message)
                                .frame(maxWidth: .infinity)
                                .frame(height: max(280, geo.size.height * 0.62))
                            SquadListPanel(store: store, message: $message)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            } else {
                SquadTableView(store: store)
            }
        }
        .background(Retro.background)
        .sheet(isPresented: $showingDepth) {
            SquadDepthSheet(store: store)
        }
        .sheet(isPresented: $showingTeamSetup) {
            TeamSetupSheet(store: store, message: $message)
        }
    }

    /// A slim, single-row toolbar replacing what used to be a permanently
    /// visible formation strip, squad-depth banner, and bottom action bar —
    /// all three now live behind one "Team Setup" button and one depth
    /// icon, so the pitch itself gets the vast majority of the screen.
    private var tacticsToolbar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    showingTeamSetup = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3.fill")
                        Text("\(store.formation.name) · \(store.preferredMentality.rawValue)")
                    }
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Retro.panel)
                    .foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())

                let needs = store.squadNeeds()
                Button {
                    Haptics.tap()
                    showingDepth = true
                } label: {
                    Image(systemName: needs.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(needs.isEmpty ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                        .padding(8)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())

                Spacer()

                if let message {
                    Text(message)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.highlight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text("XI \(store.userStarterIDs.count)/11")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(store.userStarterIDs.count == 11 ? Retro.accent : Retro.highlight)
            }
            if store.isFormationBeddingIn {
                Text("Formation still bedding in — performance dips slightly for a few matches after a switch.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Retro.panel.opacity(0.5))
    }
}

/// The full squad-depth picture: which roles are thin or empty, and any
/// market targets that would plug the gap within budget — reached from
/// the Squad tab's summary strip instead of only being a Home-dashboard
/// panel, so "how do I improve this squad?" has one obvious home.
struct SquadDepthSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var opened: TransferTarget?

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("SQUAD DEPTH")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        let needs = store.squadNeeds()
                        Panel(title: "COVER BY POSITION") {
                            if needs.isEmpty {
                                Text("Every role has cover. ✓")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.85))
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(needs, id: \.role) { need in
                                        HStack(spacing: 8) {
                                            Text(need.count == 0 ? "🔴" : "🟡")
                                            Text(need.role.fullName)
                                            Spacer()
                                            Text(need.count == 0 ? "none fit" : "\(need.count) fit")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(need.count == 0 ? Color(red: 0.9, green: 0.35, blue: 0.35) : Retro.highlight)
                                        }
                                        .font(.system(.callout, design: .monospaced))
                                    }
                                }
                            }
                        }

                        let suggestions = store.suggestedTransferTargets(limit: 6)
                        if !suggestions.isEmpty {
                            Panel(title: "COULD PLUG THE GAP") {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fits a thin role and your budget.")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Retro.text.opacity(0.6))
                                    ForEach(suggestions) { target in
                                        Button { opened = target } label: {
                                            HStack {
                                                Text(target.player.detailedPosition.rawValue)
                                                    .font(.system(.footnote, design: .monospaced).bold())
                                                    .foregroundStyle(Retro.highlight)
                                                    .frame(width: 40, alignment: .leading)
                                                Text(target.player.name)
                                                    .font(.system(.footnote, design: .monospaced))
                                                Spacer()
                                                Text(target.sellingClubIndex == nil ? "FREE" : formatMoney(target.askingPrice))
                                                    .font(.system(.caption, design: .monospaced).bold())
                                                    .foregroundStyle(Retro.accent)
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(item: $opened) { target in
            PlayerProfileSheet(store: store, context: .market(target)) { _ in }
        }
    }
}

// MARK: - Full squad table (browse & sort the whole roster)

private enum SquadSortColumn: String, CaseIterable {
    case position = "POS", name = "NAME", age = "AGE", ability = "ABL", fitness = "FIT",
         value = "VALUE", wage = "WAGE", contract = "CONTRACT"
}

struct SquadTableView: View {
    let store: GameStore
    @State private var sortColumn: SquadSortColumn = .position
    @State private var ascending = true
    @State private var profile: ProfileContext?
    @State private var positionGroupFilter: Position?

    private var sortedPlayers: [Player] {
        let players = store.userClub.players.filter { positionGroupFilter == nil || $0.detailedPosition.broad == positionGroupFilter }
        let sorted: [Player]
        switch sortColumn {
        case .position:
            sorted = players.sorted {
                $0.detailedPosition.broad.order != $1.detailedPosition.broad.order
                    ? $0.detailedPosition.broad.order < $1.detailedPosition.broad.order
                    : $0.rating > $1.rating
            }
        case .name:     sorted = players.sorted { $0.name < $1.name }
        case .age:      sorted = players.sorted { $0.age < $1.age }
        case .ability:  sorted = players.sorted { $0.rating > $1.rating }
        case .fitness:  sorted = players.sorted { $0.fitness > $1.fitness }
        case .value:    sorted = players.sorted { $0.value > $1.value }
        case .wage:     sorted = players.sorted { $0.wage > $1.wage }
        case .contract: sorted = players.sorted { $0.contractYears < $1.contractYears }
        }
        return ascending ? sorted : sorted.reversed()
    }

    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            positionGroupRow
            header
            if let message {
                Text(message)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Retro.panel.opacity(0.5))
            }
            Divider().overlay(Retro.accent.opacity(0.25))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedPlayers) { player in
                        SquadTableRow(store: store, player: player,
                                     isStarter: store.userStarterIDs.contains(player.id),
                                     markers: store.roleMarkers(for: player.id),
                                     contractExpiry: store.contractExpiryYear(player),
                                     onOpenProfile: { profile = .squad(player) },
                                     onMessage: { message = $0 })
                        Divider().overlay(Retro.accent.opacity(0.08))
                    }
                }
            }
        }
        .background(Retro.background)
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { _ in }
        }
    }

    private var positionGroupRow: some View {
        HStack(spacing: 6) {
            groupChip(label: "ALL", isSelected: positionGroupFilter == nil) { positionGroupFilter = nil }
            ForEach(Position.allCases, id: \.self) { group in
                groupChip(label: group.rawValue, isSelected: positionGroupFilter == group) {
                    positionGroupFilter = (positionGroupFilter == group) ? nil : group
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func groupChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Retro.background : Retro.text.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Retro.accent : Retro.panel.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var header: some View {
        HStack(spacing: 8) {
            headerCell("POS", .position, width: 46, alignment: .leading)
            headerCell("NAME", .name, alignment: .leading)
            headerCell("AGE", .age, width: 36)
            headerCell("ABL", .ability, width: 54)
            headerCell("FIT", .fitness, width: 54)
            headerCell("VALUE", .value, width: 72)
            headerCell("WAGE/WK", .wage, width: 72)
            headerCell("CONTRACT", .contract, width: 78)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.panel.opacity(0.7))
    }

    private func headerCell(_ title: String, _ column: SquadSortColumn, width: CGFloat? = nil,
                            alignment: Alignment = .center) -> some View {
        Button {
            if sortColumn == column { ascending.toggle() } else { sortColumn = column; ascending = true }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortColumn == column {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(sortColumn == column ? Retro.accent : Retro.text.opacity(0.7))
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
        }
        .buttonStyle(.plain)
    }
}

struct SquadTableRow: View {
    let store: GameStore
    let player: Player
    let isStarter: Bool
    var markers: [String] = []
    let contractExpiry: Int
    let onOpenProfile: () -> Void
    let onMessage: (String) -> Void

    /// Natural role first, then secondary roles, then whatever's left in
    /// the broad bucket — every role this player could plausibly move to.
    private var roleOptions: [DetailedPosition] {
        var roles = [player.detailedPosition] + player.secondaryPositions
        for candidate in DetailedPosition.plausibleRoles(for: player.position) where !roles.contains(candidate) {
            roles.append(candidate)
        }
        return roles
    }

    /// Roles genuinely worth training toward — no existing natural,
    /// secondary or related competence there yet.
    private var retrainableRoles: [DetailedPosition] {
        DetailedPosition.plausibleRoles(for: player.position)
            .filter { $0 != player.detailedPosition && player.fit(for: $0) <= 0 }
    }

    /// This player's fit for the exact pitch slot they're pinned to, if
    /// any — a glanceable warning ring for "I manually dragged someone
    /// into a spot they're not suited for", without needing to open the
    /// pitch view to notice. Auto-filled starters (no explicit pin) are
    /// already placed by best fit, so there's nothing to flag there.
    private var slotFitLevel: PositionFitLevel? {
        guard isStarter else { return nil }
        let position = player.position
        let count: Int
        switch position {
        case .goalkeeper: count = 1
        case .defender:   count = store.formation.defenders
        case .midfielder: count = store.formation.midfielders
        case .forward:    count = store.formation.forwards
        }
        for index in 0..<count {
            let key = "\(position.rawValue)-\(index)"
            if store.slotPins[key] == player.id {
                let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: store.formation.wideMidfieldersAreWingers)
                return player.fitLevel(for: role)
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(roleOptions, id: \.self) { role in
                    let dot = player.fitLevel(for: role) == .confident ? "🟢" : (player.fitLevel(for: role) == .okay ? "🟡" : "🔴")
                    Button("\(dot) \(role.fullName) — \(player.effectiveRating(for: role))") {
                        let change = store.assignStarter(player, forRole: role)
                        if case .blocked(let reason) = change {
                            onMessage(reason)
                        } else {
                            onMessage("\(surname(player.name)) moved to \(role.fullName).")
                        }
                    }
                }
                if isStarter {
                    Divider()
                    Button("Move to Bench", role: .destructive) {
                        store.toggleStarter(player)
                        onMessage("\(surname(player.name)) dropped to the bench.")
                    }
                }
                if player.retrainingRole == nil, !retrainableRoles.isEmpty {
                    Divider()
                    Menu("🎓 Retrain for…") {
                        ForEach(retrainableRoles, id: \.self) { role in
                            Button(role.fullName) {
                                switch store.beginRetraining(player, toward: role) {
                                case .started(let msg), .blocked(let msg):
                                    onMessage(msg)
                                }
                            }
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.detailedPosition.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    if !player.secondaryPositions.isEmpty {
                        Text(player.secondaryPositions.map(\.rawValue).joined(separator: "/"))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.55))
                    }
                }
                .foregroundStyle(Retro.background)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .frame(width: 46)
                .background(positionColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    (slotFitLevel != .confident ? slotFitLevel : nil).map { level in
                        RoundedRectangle(cornerRadius: 4).stroke(level.color, lineWidth: 2)
                    }
                )
            }

            Button(action: onOpenProfile) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(player.isInjured ? Color.red
                                  : (player.isSuspended ? Color.orange
                                     : (isStarter ? Retro.accent : Color.green.opacity(0.5))))
                            .frame(width: 6, height: 6)
                        if player.morale < 45 {
                            Text("☹")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.3))
                        }
                        Text(player.name)
                            .font(.system(size: 11, weight: isStarter ? .bold : .regular, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        ForEach(markers, id: \.self) { marker in
                            Text(marker)
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.background)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(Retro.highlight)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                        if let role = player.retrainingRole {
                            Text("🎓\(role.rawValue) \(player.retrainingDaysRemaining)d")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.background)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(Retro.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(player.age)")
                        .frame(width: 36)
                    OverallRatingView(rating: player.rating)
                        .frame(width: 54)
                    VStack(spacing: 2) {
                        Text("\(player.fitness)%")
                            .font(.system(size: 9, design: .monospaced))
                        FitnessBar(value: player.fitness).frame(height: 4)
                    }
                    .frame(width: 54)
                    Text(formatMoney(player.value))
                        .frame(width: 72)
                    Text(formatMoney(player.wage))
                        .frame(width: 72)
                    Text(player.contractYears <= 1 ? "Exp \(contractExpiry)" : "\(contractExpiry)")
                        .foregroundStyle(player.contractYears <= 1 ? Color(red: 0.95, green: 0.45, blue: 0.35) : Retro.text)
                        .frame(width: 78)
                }
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Retro.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(isStarter ? Retro.token.opacity(0.25) : Color.clear)
    }

    private var positionColor: Color {
        switch player.detailedPosition.broad {
        case .goalkeeper: return Retro.highlight
        case .defender:   return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .midfielder: return Retro.accent
        case .forward:    return Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }
}

// MARK: - Team setup sheet

/// Everything about setting the team up — formation, mentality, auto-pick,
/// clear XI, training focus — consolidated into one sheet reached from a
/// single button, instead of permanently occupying a strip above the pitch
/// and a bar below it.
struct TeamSetupSheet: View {
    let store: GameStore
    @Binding var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("TEAM SETUP")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Panel(title: "FORMATION") {
                            VStack(alignment: .leading, spacing: 10) {
                                if store.autoPickAssist {
                                    Text("ASSIST ON")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Retro.background)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Retro.highlight)
                                        .clipShape(Capsule())
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(Formation.all) { formation in
                                        let selected = store.formation == formation
                                        Button {
                                            Haptics.tap()
                                            store.formation = formation
                                            message = nil
                                        } label: {
                                            Text(formation.name)
                                                .font(.system(.footnote, design: .monospaced).bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(selected ? Retro.accent : Retro.panel)
                                                .foregroundStyle(selected ? Retro.background : Retro.text)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                                if store.isFormationBeddingIn {
                                    Text("Formation still bedding in — performance dips slightly for a few matches after a switch.")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Retro.highlight)
                                }
                                HStack(spacing: 8) {
                                    Button {
                                        Haptics.tap()
                                        store.resetSlotPins()
                                        message = "Pitch positions reset to best fit."
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("RESET SLOTS")
                                        }
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Retro.panel)
                                        .foregroundStyle(Retro.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(PressableButtonStyle())

                                    let suggested = store.recommendedFormation
                                    if suggested != store.formation {
                                        Button {
                                            Haptics.tap()
                                            store.formation = suggested
                                            message = "Switched to \(suggested.name) — your assistant's suggested shape for this squad."
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "lightbulb.fill")
                                                Text("TRY \(suggested.name)")
                                            }
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Retro.highlight.opacity(0.25))
                                            .foregroundStyle(Retro.highlight)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                            }
                        }

                        Panel(title: "MENTALITY") {
                            HStack(spacing: 8) {
                                ForEach(Mentality.allCases) { mentality in
                                    let selected = store.preferredMentality == mentality
                                    Button {
                                        Haptics.tap()
                                        store.preferredMentality = mentality
                                    } label: {
                                        Text(mentality.rawValue)
                                            .font(.system(.footnote, design: .monospaced).bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selected ? Retro.highlight : Retro.panel)
                                            .foregroundStyle(selected ? Retro.background : Retro.text)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                        }

                        Panel(title: "SQUAD TOOLS") {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    setupButton("AUTO-PICK") { store.autoPickLineup(); message = "Best XI selected." }
                                    setupButton("CLEAR XI") { store.clearLineup(); message = "Lineup cleared." }
                                }
                                Menu {
                                    Picker("Training", selection: Binding(
                                        get: { store.trainingFocus },
                                        set: { store.trainingFocus = $0; message = "Training focus: \($0.rawValue)." }
                                    )) {
                                        ForEach(TrainingFocus.allCases) { Text($0.rawValue).tag($0) }
                                    }
                                } label: {
                                    Text("TRAIN: \(store.trainingFocus.rawValue.uppercased())")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Retro.panel)
                                        .foregroundStyle(Retro.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .menuStyle(.button)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func setupButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pitch

struct PitchView: View {
    let store: GameStore
    @Binding var message: String?
    @State private var pickerTarget: SlotPickerTarget?
    @State private var draggingKey: String?

    var body: some View {
        ZStack {
            PitchBackground()
            PitchGridDots()
            VStack(spacing: 6) {
                frontLine
                row(.defender, store.formation.defenders, indices: Array(0..<store.formation.defenders))
                row(.goalkeeper, 1, indices: [0])
            }
            .padding(16)
        }
        .padding(10)
        .sheet(item: $pickerTarget) { target in
            PositionPickerSheet(store: store, role: target.role, currentPlayerID: target.currentPlayerID) { player in
                let change = store.assignStarter(player, forRole: target.role)
                if case .blocked(let reason) = change {
                    message = reason
                } else {
                    message = "\(surname(player.name)) selected at \(target.role.rawValue)."
                }
            } onBench: {
                guard let id = target.currentPlayerID,
                      let player = store.userClub.players.first(where: { $0.id == id }) else { return }
                store.toggleStarter(player)
                message = "\(surname(player.name)) dropped to the bench."
            }
        }
    }

    /// The attacking line(s) above the back four. A genuine front-three
    /// shape (4-3-3 and similar, where two "midfielders" are really
    /// wingers) merges the wide pair with the striker(s) into one settled
    /// front line — LW / ST / RW side by side, like a real team sheet —
    /// with the remaining central midfielders in their own row below. Any
    /// other formation (a classic 4-4-2, say) keeps forwards and midfield
    /// as two separate single-line rows.
    @ViewBuilder
    private var frontLine: some View {
        let midCount = store.formation.midfielders
        if store.formation.wideMidfieldersAreWingers {
            combinedFrontRow(midCount: midCount)
            let central = centralMidIndices(midCount)
            if !central.isEmpty {
                row(.midfielder, midCount, indices: central)
            }
        } else {
            row(.forward, store.formation.forwards, indices: Array(0..<store.formation.forwards))
            row(.midfielder, midCount, indices: Array(0..<midCount))
        }
    }

    private func centralMidIndices(_ count: Int) -> [Int] {
        (0..<count).filter {
            let role = DetailedPosition.expected(for: .midfielder, indexInRow: $0, rowCount: count, wideIsWinger: true)
            return role != .leftWing && role != .rightWing
        }
    }

    /// One HStack mixing the wide midfielder slots and the forward slots
    /// together, left wing → striker(s) → right wing, so a 4-3-3's front
    /// three genuinely reads as one line rather than the winger sitting a
    /// row apart from the man he's meant to be playing alongside.
    private func combinedFrontRow(midCount: Int) -> some View {
        let wideIndices = (0..<midCount).filter {
            let role = DetailedPosition.expected(for: .midfielder, indexInRow: $0, rowCount: midCount, wideIsWinger: true)
            return role == .leftWing || role == .rightWing
        }
        let leftWide = wideIndices.first
        let rightWide = wideIndices.count > 1 ? wideIndices.last : nil
        let forwardCount = store.formation.forwards
        let midPlayers = slotPlayers(.midfielder, midCount)
        let fwdPlayers = slotPlayers(.forward, forwardCount)

        return HStack(spacing: 4) {
            if let leftWide {
                tokenView(position: .midfielder, index: leftWide, count: midCount, player: midPlayers[leftWide])
            }
            ForEach(0..<forwardCount, id: \.self) { index in
                tokenView(position: .forward, index: index, count: forwardCount, player: fwdPlayers[index])
            }
            if let rightWide {
                tokenView(position: .midfielder, index: rightWide, count: midCount, player: midPlayers[rightWide])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ position: Position, _ count: Int, indices subsetIndices: [Int]) -> some View {
        let players = slotPlayers(position, count)
        return HStack(spacing: 4) {
            ForEach(subsetIndices, id: \.self) { index in
                tokenView(position: position, index: index, count: count, player: players[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tokenView(position: Position, index: Int, count: Int, player: Player?) -> some View {
        let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: store.formation.wideMidfieldersAreWingers)
        let key = slotKey(position, index)
        return PlayerToken(
            player: player,
            role: role.rawValue,
            fitLevel: player?.fitLevel(for: role) ?? .confident,
            onTap: { pickerTarget = SlotPickerTarget(role: role, currentPlayerID: player?.id) }
        )
        .frame(maxWidth: .infinity)
        .opacity(draggingKey == key ? 0.5 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { _ in draggingKey = key }
                .onEnded { drag in
                    swapWithNeighbour(position, index: index, count: count,
                                      playerID: player?.id, movedRight: drag.translation.width > 0)
                    draggingKey = nil
                }
        )
    }

    /// Swaps a slot with its next-door neighbour in the same broad-position
    /// group (index-1 for a leftward drag, index+1 for a rightward one) —
    /// simple, deliberately decoupled from real pixel geometry, so it can't
    /// ever destabilise the surrounding layout the way frame-tracking did.
    private func swapWithNeighbour(_ position: Position, index: Int, count: Int, playerID: UUID?, movedRight: Bool) {
        guard let playerID, count > 1 else { return }
        let neighbourIndex = movedRight ? index + 1 : index - 1
        guard neighbourIndex >= 0, neighbourIndex < count else { return }
        let slots = slotPlayers(position, count)
        Haptics.tap()
        let neighbourPlayerID = slots[neighbourIndex]?.id
        store.setSlotPin(slotKey(position, neighbourIndex), playerID: playerID)
        store.setSlotPin(slotKey(position, index), playerID: neighbourPlayerID)
    }

    private func slotKey(_ position: Position, _ index: Int) -> String { "\(position.rawValue)-\(index)" }

    /// The selected players filling a row's slots. Explicit drag-placed
    /// pins are honoured first; anyone left over fills the remaining
    /// slots by best natural/secondary fit, same as before pins existed.
    private func slotPlayers(_ position: Position, _ count: Int) -> [Player?] {
        guard count > 0 else { return [] }
        var pool = store.userClub.players.filter { store.userStarterIDs.contains($0.id) && $0.position == position }
        var slots: [Player?] = Array(repeating: nil, count: count)

        for index in 0..<count {
            guard let pinnedID = store.slotPins[slotKey(position, index)],
                  let player = pool.first(where: { $0.id == pinnedID }) else { continue }
            slots[index] = player
            pool.removeAll { $0.id == pinnedID }
        }

        let order = (0..<count).filter { slots[$0] == nil }.sorted { a, b in
            let aEdge = a == 0 || a == count - 1
            let bEdge = b == 0 || b == count - 1
            if aEdge != bEdge { return aEdge }
            return a < b
        }
        for index in order {
            let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: store.formation.wideMidfieldersAreWingers)
            func score(_ p: Player) -> Double { Double(p.effectiveRating(for: role)) * (0.9 + 0.1 * Double(p.fitness) / 100) }
            guard let best = pool.max(by: { score($0) < score($1) }) else { continue }
            slots[index] = best
            pool.removeAll { $0.id == best.id }
        }
        return slots
    }

}

/// Identifies which pitch slot the quick-select sheet is filling.
struct SlotPickerTarget: Identifiable {
    let role: DetailedPosition
    let currentPlayerID: UUID?
    var id: String { role.rawValue + "-" + (currentPlayerID?.uuidString ?? "empty") }
}

/// Wraps a plain Int as Identifiable, for `.sheet(item:)` bindings keyed by
/// a club index (e.g. tapping a team name to view their squad).
struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

/// A read-only look at any club's full squad — reached by tapping a team
/// name anywhere in the league table or a fixture list.
struct ClubSquadSheet: View {
    let store: GameStore
    let clubIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var profile: ProfileContext?

    private var club: Club { store.clubs[clubIndex] }
    private var sortedPlayers: [Player] {
        club.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                header
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(sortedPlayers) { player in
                            Button {
                                Haptics.tap()
                                profile = .scouted(player, clubIndex: clubIndex)
                            } label: {
                                row(player)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { _ in }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CrestView(shortName: club.shortName, size: 44, color: store.color(forClubIndex: clubIndex))
            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text("\(store.clubDivisionLabel(forClubIndex: clubIndex)) · \(store.starRating(forClubIndex: clubIndex))★ · \(club.players.count) players")
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
    }

    private func row(_ player: Player) -> some View {
        HStack(spacing: 10) {
            Text(player.detailedPosition.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.background)
                .frame(width: 42)
                .padding(.vertical, 4)
                .background(positionColor(player))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(player.name)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .lineLimit(1)
            Spacer()
            Text("\(player.age)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
                .frame(width: 24)
            OverallRatingView(rating: player.rating)
        }
        .padding(10)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func positionColor(_ player: Player) -> Color {
        switch player.detailedPosition.broad {
        case .goalkeeper: return Retro.highlight
        case .defender:   return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .midfielder: return Retro.accent
        case .forward:    return Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }
}

/// Quick-select: ranks every eligible squad player for one specific pitch
/// slot by their rating at that role, so picking a natural fit takes one tap.
struct PositionPickerSheet: View {
    let store: GameStore
    let role: DetailedPosition
    let currentPlayerID: UUID?
    let onPick: (Player) -> Void
    let onBench: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Eligible players for this slot — anyone already nailed into a
    /// different starting slot is left off the list, aside from whoever
    /// currently occupies this one.
    private var candidates: [Player] {
        store.userClub.players
            .filter { $0.position == role.broad }
            .filter { $0.id == currentPlayerID || !store.userStarterIDs.contains($0.id) }
            .sorted { $0.effectiveRating(for: role) > $1.effectiveRating(for: role) }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SELECT \(role.fullName.uppercased())")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(candidates) { player in
                            candidateRow(player)
                        }
                    }
                }
            }
            .padding()
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func candidateRow(_ player: Player) -> some View {
        let isCurrent = player.id == currentPlayerID
        let unavailable = player.isInjured || player.isSuspended
        return Button {
            if isCurrent { onBench() } else { onPick(player) }
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(player.detailedPosition.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(width: 40)
                    .background(fitColor(player))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(.callout, design: .monospaced).bold())
                    Text("\(fitLabel(player)) · \(player.fitnessLabel) · Age \(player.age)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                    FitnessBar(value: player.fitness).frame(width: 90, height: 4)
                }

                Spacer()

                Text("\(player.effectiveRating(for: role))")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Retro.accent)
                }
            }
            .padding(10)
            .background(isCurrent ? Retro.token.opacity(0.35) : Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(unavailable && !isCurrent ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(unavailable && !isCurrent)
    }

    private func fitLabel(_ player: Player) -> String {
        switch player.fit(for: role) {
        case 2:  return "Natural"
        case 1:  return "Can play"
        case 0:  return "Makeshift"
        default: return "Out of position"
        }
    }

    private func fitColor(_ player: Player) -> Color {
        player.fitLevel(for: role).color
    }
}

/// A thin bar showing match fitness, green-to-red by condition.
struct FitnessBar: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Retro.text.opacity(0.15))
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(value) / 100)
            }
        }
    }

    private var color: Color {
        switch value {
        case 75...:   return Retro.accent
        case 50..<75: return Retro.highlight
        default:      return Color(red: 0.9, green: 0.35, blue: 0.35)
        }
    }
}

/// A single player token (or empty slot) on the pitch.
struct PlayerToken: View {
    let player: Player?
    let role: String
    var fitLevel: PositionFitLevel = .confident
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(role)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Retro.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if let player {
                    VStack(spacing: 1) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(fitLevel.color)
                                .frame(width: 6, height: 6)
                            Text(surname(player.name))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(.white)
                        }
                        Text("\(player.rating)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(minWidth: 52)
                    .background(Retro.token)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(fitLevel == .poor ? fitLevel.color : Retro.tokenEdge, lineWidth: fitLevel == .poor ? 1.5 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 52, height: 30)
                        .background(Color.black.opacity(0.25))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// The green pitch with mown stripes and markings.
struct PitchBackground: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(0..<7), id: \.self) { index in
                    (index.isMultiple(of: 2) ? Retro.pitch : Retro.pitchLight)
                }
            }
            PitchMarkings()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// A faint placement grid over the pitch, the way a real tactics board
/// marks out even slot positions — purely decorative, sits under the
/// player tokens.
struct PitchGridDots: View {
    private let columns = 7
    private let rows = 10

    var body: some View {
        // Built from plain stacks rather than a GeometryReader — a
        // GeometryReader used directly inside a ZStack has no intrinsic
        // size of its own, which can make the ZStack (and everything
        // sized relative to it) report the wrong size to its parent.
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 3, height: 3)
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .allowsHitTesting(false)
    }
}

/// Simple top-down pitch markings.
struct PitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        // Halfway line.
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        // Centre circle.
        let radius = min(rect.width, rect.height) * 0.11
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius,
                                   width: radius * 2, height: radius * 2))
        // Penalty boxes at each end.
        let boxWidth = rect.width * 0.5
        let boxHeight = rect.height * 0.15
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.minY,
                            width: boxWidth, height: boxHeight))
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.maxY - boxHeight,
                            width: boxWidth, height: boxHeight))
        return path
    }
}

// MARK: - Squad list (right column)

struct SquadListPanel: View {
    let store: GameStore
    @Binding var message: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SQUAD")
                    .foregroundStyle(Retro.accent)
                Spacer()
                Text("ROLE")
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
            .font(.system(.caption, design: .monospaced).bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Retro.panel)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(sortedPlayers) { player in
                        Button {
                            handleTap(player)
                        } label: {
                            SquadListRow(player: player,
                                         isStarter: store.userStarterIDs.contains(player.id),
                                         markers: store.roleMarkers(for: player.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Retro.background)
    }

    private var sortedPlayers: [Player] {
        store.userClub.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    private func handleTap(_ player: Player) {
        switch store.toggleStarter(player) {
        case .blocked(let reason): message = reason
        case .added:               message = "\(surname(player.name)) added to the XI."
        case .removed:             message = "\(surname(player.name)) dropped to the bench."
        }
    }
}

struct SquadListRow: View {
    let player: Player
    let isStarter: Bool
    var markers: [String] = []

    var body: some View {
        HStack(spacing: 8) {
            Text(player.position.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.background)
                .frame(width: 32)
                .padding(.vertical, 3)
                .background(positionColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Circle()
                .fill(player.isInjured ? Color.red
                      : (player.isSuspended ? Color.orange
                         : (isStarter ? Retro.accent : Color.green.opacity(0.5))))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(.system(size: 11, weight: isStarter ? .bold : .regular, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    ForEach(markers, id: \.self) { marker in
                        Text(marker)
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(Retro.background)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Retro.highlight)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                subtitle
                    .font(.system(size: 8, design: .monospaced))
            }

            Spacer(minLength: 2)

            Text(player.detailedPosition.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(isStarter ? Retro.background : Retro.text)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isStarter ? Retro.highlight : Retro.panel)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(isStarter ? Retro.token.opacity(0.35) : Color.clear)
        .foregroundStyle(Retro.text)
    }

    private var subtitle: Text {
        if player.isInjured {
            return Text("Injured \(player.injuryWeeks)w").foregroundStyle(Retro.text.opacity(0.7))
        }
        if player.isSuspended {
            return Text("Suspended \(player.suspensionMatches)").foregroundStyle(Retro.text.opacity(0.7))
        }
        let base = Text("R\(player.rating) · Age \(player.age) · ").foregroundStyle(Retro.text.opacity(0.7))
        let contract = Text(player.contractYears <= 1 ? "Exp" : "\(player.contractYears)y")
            .foregroundStyle(player.contractYears <= 1 ? Color(red: 0.95, green: 0.45, blue: 0.35) : Retro.text.opacity(0.7))
        let goals = player.goals > 0
            ? Text(" · \(player.goals)⚽︎").foregroundStyle(Retro.text.opacity(0.7))
            : Text("")
        let fitness = player.fitness < 75
            ? Text(" · \(player.fitness)%").foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
            : Text("")
        return base + contract + goals + fitness
    }

    private var positionColor: Color {
        switch player.position {
        case .goalkeeper: return Retro.highlight
        case .defender:   return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .midfielder: return Retro.accent
        case .forward:    return Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }
}


// MARK: - League table

private enum CompetitionTab: String, CaseIterable, Identifiable {
    case league = "League", faCup = "National Cup", leagueCup = "League Trophy",
         europe = "Continental Cup", uefaCup = "Midweek Cup"
    var id: String { rawValue }
}

struct TableView: View {
    let store: GameStore
    @State private var tier: Int?
    @State private var competition: CompetitionTab = .league
    @State private var squadClubIndex: IdentifiableInt?

    private var shownTier: Int { tier ?? store.userDivisionTier }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("COMPETITIONS — SEASON \(store.season)")
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)

                Picker("Competition", selection: $competition) {
                    ForEach(CompetitionTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch competition {
                case .league:
                    leagueSection
                case .faCup:
                    cupSection(name: GameStore.cupName, ties: store.cupTies,
                              roundLabel: store.cupRoundLabel, winnerName: store.cupWinnerName)
                case .leagueCup:
                    cupSection(name: GameStore.leagueCupName, ties: store.leagueCupTies,
                              roundLabel: store.leagueCupRoundLabel, winnerName: store.leagueCupWinnerName)
                case .europe:
                    cupSection(name: GameStore.euroName, ties: store.euroTies,
                              roundLabel: store.euroWinnerName != nil ? "Completed" : store.euroRoundLabel,
                              winnerName: store.euroWinnerName)
                case .uefaCup:
                    cupSection(name: GameStore.uefaCupName, ties: store.uefaCupTies,
                              roundLabel: store.uefaCupRoundLabel, winnerName: store.uefaCupWinnerName)
                }
            }
            .padding()
        }
        .sheet(item: $squadClubIndex) { wrapped in
            ClubSquadSheet(store: store, clubIndex: wrapped.value)
        }
    }

    @ViewBuilder
    private var leagueSection: some View {
        Picker("Division", selection: Binding(
            get: { shownTier },
            set: { tier = $0 }
        )) {
            ForEach(0..<GameStore.divisionNames.count, id: \.self) { t in
                Text(GameStore.divisionNames[t]).tag(t)
            }
        }
        .pickerStyle(.segmented)

        // Column headers.
        HStack {
            Text("#").frame(width: 24, alignment: .leading)
            Text("Club")
            Spacer()
            Group {
                Text("P")
                Text("W")
                Text("D")
                Text("L")
                Text("GD")
                Text("Pts")
            }
            .frame(width: 30, alignment: .trailing)
        }
        .font(.system(.caption, design: .monospaced).bold())
        .foregroundStyle(Retro.highlight)

        ForEach(Array(store.leagueTable(tier: shownTier).enumerated()), id: \.element.id) { index, club in
            let isUser = club.id == store.userClub.id
            let zone = promotionZone(index: index)
            Button {
                Haptics.tap()
                if let clubIndex = store.clubs.firstIndex(where: { $0.id == club.id }) {
                    squadClubIndex = IdentifiableInt(value: clubIndex)
                }
            } label: {
                HStack {
                    Text("\(index + 1)").frame(width: 24, alignment: .leading)
                        .foregroundStyle(zone)
                    Text(club.shortName)
                        .fontWeight(isUser ? .bold : .regular)
                    Spacer()
                    Group {
                        Text("\(club.played)")
                        Text("\(club.won)")
                        Text("\(club.drawn)")
                        Text("\(club.lost)")
                        Text("\(club.goalDifference)")
                        Text("\(club.points)")
                    }
                    .frame(width: 30, alignment: .trailing)
                }
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(isUser ? Retro.highlight : Retro.text)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(isUser ? Retro.panel : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
        }

        topScorers
    }

    @ViewBuilder
    private func cupSection(name: String, ties: [CupTie], roundLabel: String, winnerName: String?) -> some View {
        if let winnerName {
            Panel(title: "WINNERS") {
                Text("🏆 \(winnerName) lifted the \(name)!")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
            }
        }
        if ties.isEmpty && winnerName == nil {
            Text("\(name) hasn't started yet.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        } else if !ties.isEmpty {
            Panel(title: winnerName == nil ? roundLabel.uppercased() : "FINAL") {
                VStack(spacing: 4) {
                    ForEach(ties) { tie in cupTieRow(tie) }
                }
            }
        }
    }

    private func cupTieRow(_ tie: CupTie) -> some View {
        let isUser = tie.homeIndex == store.userClubIndex || tie.awayIndex == store.userClubIndex
        return Group {
            if tie.isBye {
                HStack {
                    Text(store.clubs[tie.homeIndex].shortName)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
                    Spacer()
                    Text("bye").foregroundStyle(Retro.text.opacity(0.7))
                }
            } else {
                HStack {
                    Text(store.clubs[tie.homeIndex].shortName).frame(width: 48, alignment: .leading)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
                    if tie.played {
                        Text("\(tie.homeGoals)-\(tie.awayGoals)").foregroundStyle(Retro.highlight)
                        if tie.onPenalties {
                            Text("(p)").font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.7))
                        }
                    } else {
                        Text(" v ").foregroundStyle(Retro.text.opacity(0.6))
                    }
                    Text(store.clubs[tie.awayIndex].shortName).frame(width: 48, alignment: .trailing)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.awayIndex) }
                    Spacer()
                }
            }
        }
        .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(isUser ? Retro.panel : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Colours the position number: green auto-promotion, blue play-offs,
    /// red relegation.
    private func promotionZone(index: Int) -> Color {
        if shownTier > 0 {
            if index < 2 { return Retro.accent }                                    // auto promotion
            if index < 6 { return Color(red: 0.4, green: 0.7, blue: 1.0) }           // play-offs
        }
        if shownTier < GameStore.divisionNames.count - 1 && index >= GameStore.divisionSize - 3 {
            return Color(red: 0.9, green: 0.4, blue: 0.4)                            // relegation
        }
        return Retro.text.opacity(0.6)
    }

    private var topScorers: some View {
        Panel(title: "TOP SCORERS — \(GameStore.divisionNames[shownTier].uppercased())") {
            let scorers = store.topScorers(limit: 8, tier: shownTier)
            if scorers.isEmpty {
                Text("No goals scored yet.")
                    .font(.system(.footnote, design: .monospaced))
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(scorers.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(entry.player.name)
                            Text("(\(entry.club.shortName))")
                                .foregroundStyle(Retro.text.opacity(0.8))
                            Spacer()
                            Text("\(entry.player.goals)")
                                .foregroundStyle(Retro.highlight)
                        }
                        .font(.system(.callout, design: .monospaced))
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Fixtures

struct CalendarView: View {
    let store: GameStore
    @State private var displayedMonth: Date
    @State private var selectedDate: Date
    @State private var message: String?
    @State private var squadClubIndex: IdentifiableInt?

    private static let gridCalendar = Calendar(identifier: .gregorian)

    init(store: GameStore) {
        self.store = store
        _displayedMonth = State(initialValue: store.currentDate)
        _selectedDate = State(initialValue: store.currentDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                monthGrid
                simToDateBar
                dayDetail
            }
            .padding()
        }
        .sheet(item: $squadClubIndex) { wrapped in
            ClubSquadSheet(store: store, clubIndex: wrapped.value)
        }
    }

    @ViewBuilder
    private var simToDateBar: some View {
        if !store.isSeasonOver && selectedDate > store.currentDate {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact()
                    let target = selectedDate
                    store.runHeavy("Simming to \(target.formatted(.dateTime.day().month(.abbreviated)))…") {
                        let before = store.currentDate
                        await store.simTo(date: target)
                        if Self.gridCalendar.isDate(store.currentDate, inSameDayAs: target) {
                            message = "Simmed to \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year()))."
                        } else if store.currentDate > before {
                            message = "Stopped early on \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year())) — needs your attention."
                        }
                        displayedMonth = store.currentDate
                    }
                } label: {
                    Text("SIM TO \(selectedDate.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                        .font(.system(.callout, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Retro.accent)
                        .foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.warning()
                    let target = selectedDate
                    store.runHeavy("Force-simming to \(target.formatted(.dateTime.day().month(.abbreviated)))…") {
                        await store.forceSimTo(date: target)
                        message = "Force-simmed to \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year())) — every match along the way was auto-resolved."
                        displayedMonth = store.currentDate
                    }
                } label: {
                    Text("FORCE SIM")
                        .font(.system(.callout, design: .monospaced).bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Retro.panel)
                        .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.5), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var header: some View {
        HStack {
            Text("CALENDAR")
                .font(.system(.headline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 26, height: 26)
            }
            .buttonStyle(PressableButtonStyle())
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.callout, design: .monospaced).bold())
                .frame(minWidth: 150)
                .multilineTextAlignment(.center)
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 26, height: 26)
            }
            .buttonStyle(PressableButtonStyle())
            Button {
                Haptics.tap()
                displayedMonth = store.currentDate
                selectedDate = store.currentDate
            } label: {
                Text("TODAY")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Retro.panel)
                    .foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func shiftMonth(_ delta: Int) {
        Haptics.tap()
        displayedMonth = Self.gridCalendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }

    private var monthGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(Array(gridDays().enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = Self.gridCalendar.veryShortWeekdaySymbols
        let start = Self.gridCalendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// The displayed month's days, front-padded with nils so day 1 lands
    /// under the correct weekday column.
    private func gridDays() -> [Date?] {
        guard let monthInterval = Self.gridCalendar.dateInterval(of: .month, for: displayedMonth),
              let daysInMonth = Self.gridCalendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let firstWeekday = Self.gridCalendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - Self.gridCalendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            days.append(Self.gridCalendar.date(byAdding: .day, value: offset, to: monthInterval.start))
        }
        return days
    }

    private func involvesUser(_ index: Int, _ index2: Int) -> Bool {
        index == store.userClubIndex || index2 == store.userClubIndex
    }

    private func isUserDay(_ day: Date) -> Bool {
        store.fixtures(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.cupTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.leagueCupTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.euroTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.uefaCupTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.communityShieldTie(onDate: day).map { involvesUser($0.homeIndex, $0.awayIndex) } ?? false
            || store.uefaSuperCupTie(onDate: day).map { involvesUser($0.homeIndex, $0.awayIndex) } ?? false
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = Self.gridCalendar.isDate(day, inSameDayAs: store.currentDate)
        let isSelected = Self.gridCalendar.isDate(day, inSameDayAs: selectedDate)
        let hasEvent = store.hasCalendarEvent(onDate: day)
        let userDay = isUserDay(day)
        return Button {
            Haptics.tap()
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text("\(Self.gridCalendar.component(.day, from: day))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular, design: .monospaced))
                Circle()
                    .fill(hasEvent ? (userDay ? Retro.highlight : Retro.accent.opacity(0.7)) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(isSelected ? Retro.accent.opacity(0.25) : (isToday ? Retro.panel.opacity(0.7) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isToday ? Retro.accent.opacity(0.5) : .clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Retro.text)
    }

    @ViewBuilder
    private var dayDetail: some View {
        let dayFixtures = store.fixtures(onDate: selectedDate)
        let friendlies = store.friendlyFixtures(onDate: selectedDate)
        let cup = store.cupTies(onDate: selectedDate)
        let leagueCup = store.leagueCupTies(onDate: selectedDate)
        let euro = store.euroTies(onDate: selectedDate)
        let uefaCup = store.uefaCupTies(onDate: selectedDate)
        let communityShield = store.communityShieldTie(onDate: selectedDate)
        let uefaSuperCup = store.uefaSuperCupTie(onDate: selectedDate)
        let dayNews = store.news(onDate: selectedDate)

        Panel(title: selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).uppercased()) {
            if dayFixtures.isEmpty && friendlies.isEmpty && cup.isEmpty && leagueCup.isEmpty && euro.isEmpty
                && uefaCup.isEmpty && communityShield == nil && uefaSuperCup == nil && dayNews.isEmpty {
                Text("Nothing scheduled or reported on this day.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !friendlies.isEmpty {
                        sectionLabel("PRE-SEASON FRIENDLY")
                        VStack(spacing: 4) { ForEach(friendlies) { fixtureRow($0) } }
                    }
                    if !dayFixtures.isEmpty {
                        sectionLabel("LEAGUE — \(store.divisionName(store.userDivisionTier).uppercased())")
                        VStack(spacing: 4) { ForEach(dayFixtures) { fixtureRow($0) } }
                    }
                    if let communityShield {
                        sectionLabel(GameStore.communityShieldName.uppercased())
                        tieRow(communityShield)
                    }
                    if let uefaSuperCup {
                        sectionLabel(GameStore.uefaSuperCupName.uppercased())
                        tieRow(uefaSuperCup)
                    }
                    if !cup.isEmpty {
                        sectionLabel(GameStore.cupName.uppercased())
                        VStack(spacing: 4) { ForEach(cup) { tieRow($0) } }
                    }
                    if !leagueCup.isEmpty {
                        sectionLabel(GameStore.leagueCupName.uppercased())
                        VStack(spacing: 4) { ForEach(leagueCup) { tieRow($0) } }
                    }
                    if !euro.isEmpty {
                        sectionLabel(GameStore.euroName.uppercased())
                        VStack(spacing: 4) { ForEach(euro) { tieRow($0) } }
                    }
                    if !uefaCup.isEmpty {
                        sectionLabel(GameStore.uefaCupName.uppercased())
                        VStack(spacing: 4) { ForEach(uefaCup) { tieRow($0) } }
                    }
                    if !dayNews.isEmpty {
                        sectionLabel("NEWS")
                        VStack(alignment: .leading, spacing: 6) { ForEach(dayNews) { newsRow($0) } }
                    }
                }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(Retro.text.opacity(0.6))
    }

    private func fixtureRow(_ fixture: Fixture) -> some View {
        let home = store.clubs[fixture.homeIndex]
        let away = store.clubs[fixture.awayIndex]
        let isUser = involvesUser(fixture.homeIndex, fixture.awayIndex)
        return HStack {
            Text(home.shortName).frame(width: 44, alignment: .leading)
                .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: fixture.homeIndex) }
            if fixture.played {
                Text("\(fixture.homeGoals) - \(fixture.awayGoals)").foregroundStyle(Retro.highlight)
            } else {
                Text(" v ").foregroundStyle(Retro.text.opacity(0.8))
            }
            Text(away.shortName).frame(width: 44, alignment: .trailing)
                .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: fixture.awayIndex) }
            Spacer()
        }
        .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
    }

    private func tieRow(_ tie: CupTie) -> some View {
        let isUser = involvesUser(tie.homeIndex, tie.awayIndex)
        return Group {
            if tie.isBye {
                HStack {
                    Text(store.clubs[tie.homeIndex].shortName)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
                    Spacer()
                    Text("bye").foregroundStyle(Retro.text.opacity(0.7))
                }
            } else {
                HStack {
                    Text(store.clubs[tie.homeIndex].shortName).frame(width: 48, alignment: .leading)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
                    if tie.played {
                        Text("\(tie.homeGoals)-\(tie.awayGoals)").foregroundStyle(Retro.highlight)
                        if tie.onPenalties {
                            Text("(p)").font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.7))
                        }
                    } else {
                        Text(" v ").foregroundStyle(Retro.text.opacity(0.6))
                    }
                    Text(store.clubs[tie.awayIndex].shortName).frame(width: 48, alignment: .trailing)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.awayIndex) }
                    Spacer()
                }
            }
        }
        .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(isUser ? Retro.panel : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func newsRow(_ item: NewsItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.category.glyph)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(.footnote, design: .monospaced).bold())
                Text(item.body)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            }
        }
    }
}

// MARK: - Player search

private struct SearchResult: Identifiable {
    let player: Player
    let clubIndex: Int
    var id: UUID { player.id }
}

struct PlayerSearchView: View {
    let store: GameStore
    @State private var query = ""
    @State private var positionFilter: DetailedPosition?
    @State private var shortlistOnly = false
    @State private var profile: ProfileContext?
    @State private var message: String?
    @State private var showingReports = false

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isActive: Bool { shortlistOnly || trimmedQuery.count >= 2 || positionFilter != nil }

    private static let resultCap = 60

    private var allMatches: [SearchResult] {
        guard isActive else { return [] }
        if shortlistOnly {
            return store.shortlistedResults.map { SearchResult(player: $0.player, clubIndex: $0.clubIndex) }
        }
        var matches: [SearchResult] = []
        for (index, club) in store.clubs.enumerated() {
            for player in club.players {
                if trimmedQuery.count >= 2 && !player.name.localizedCaseInsensitiveContains(trimmedQuery) { continue }
                if let positionFilter, player.detailedPosition != positionFilter { continue }
                matches.append(SearchResult(player: player, clubIndex: index))
            }
        }
        return matches.sorted { $0.player.rating > $1.player.rating }
    }

    private var results: [SearchResult] { Array(allMatches.prefix(Self.resultCap)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PLAYER SEARCH")
                .font(.system(.headline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            scoutingToolbar
            searchField
            positionFilterRow

            if let message {
                Text(message)
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Retro.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !isActive {
                Text("Type at least 2 characters, or pick a position, to search every club in the pyramid.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
            } else if results.isEmpty {
                Text(shortlistOnly ? "Your shortlist is empty. Star a player's profile to add them."
                                    : "No players found for \"\(query)\".")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
            } else {
                if allMatches.count > Self.resultCap {
                    Text("Showing top \(Self.resultCap) of \(allMatches.count) matches by rating — refine your search to narrow it down.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(results) { result in
                            resultRow(result)
                        }
                    }
                }
            }
        }
        .padding()
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

    /// Active scouting missions — send a scout out into the wider world
    /// (or specifically after youth talent) instead of only ever being
    /// able to search for players you already know exist, plus a running
    /// list of every report filed so far.
    private var scoutingToolbar: some View {
        HStack(spacing: 8) {
            scoutButton("🌍 SCOUT WORLD") { store.scoutTheWorld(youthOnly: false) }
            scoutButton("🎓 SCOUT YOUTH") { store.scoutTheWorld(youthOnly: true) }
            Spacer()
            Button {
                Haptics.tap()
                showingReports = true
            } label: {
                Text("REPORTS (\(store.scoutedReports.count))")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Retro.panel)
                    .foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func scoutButton(_ title: String, action: @escaping () -> String) -> some View {
        Button {
            Haptics.impact()
            message = action()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!store.transferWindowOpen)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Retro.text.opacity(0.6))
            TextField("Search players by name…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Retro.text)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Retro.text.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Retro.panel.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var positionFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(label: "★ SHORTLIST", isSelected: shortlistOnly) { shortlistOnly.toggle() }
                filterChip(label: "ALL", isSelected: !shortlistOnly && positionFilter == nil) {
                    shortlistOnly = false; positionFilter = nil
                }
                ForEach(DetailedPosition.allCases, id: \.self) { role in
                    filterChip(label: role.rawValue, isSelected: !shortlistOnly && positionFilter == role) {
                        shortlistOnly = false
                        positionFilter = (positionFilter == role) ? nil : role
                    }
                }
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(isSelected ? Retro.background : Retro.text.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Retro.accent : Retro.panel.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func resultRow(_ result: SearchResult) -> some View {
        let club = store.clubs[result.clubIndex]
        let player = result.player
        let isShortlisted = store.isShortlisted(player.id)
        return HStack(spacing: 6) {
            Button {
                Haptics.tap()
                profile = .scouted(player, clubIndex: result.clubIndex)
            } label: {
                HStack(spacing: 10) {
                    CrestView(shortName: club.shortName, size: 32, color: store.color(forClubIndex: result.clubIndex))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.name)
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                        Text("\(club.name) · \(player.detailedPosition.fullName) · Age \(player.age)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        OverallRatingView(rating: player.rating)
                        if result.clubIndex != store.userClubIndex {
                            Text(player.contractYears <= 0 ? "FREE" : formatMoney(store.negotiatedFee(for: player)))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.highlight)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Button {
                Haptics.tap()
                store.toggleShortlist(player.id)
            } label: {
                Image(systemName: isShortlisted ? "star.fill" : "star")
                    .foregroundStyle(isShortlisted ? Retro.highlight : Retro.text.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Shared panel container

/// A titled, rounded panel used throughout the retro UI.
struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Retro.accent.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
    }
}

// MARK: - Helpers

/// The last word of a player's name, for compact pitch tokens.
func surname(_ name: String) -> String {
    name.split(separator: " ").last.map(String.init) ?? name
}

/// Formats an integer as an ordinal, e.g. 1 -> "1st".
func ordinal(_ n: Int) -> String {
    let suffix: String
    switch (n % 100, n % 10) {
    case (11, _), (12, _), (13, _): suffix = "th"
    case (_, 1): suffix = "st"
    case (_, 2): suffix = "nd"
    case (_, 3): suffix = "rd"
    default: suffix = "th"
    }
    return "\(n)\(suffix)"
}

#Preview {
    ContentView()
}

#Preview("Home Menu", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 4)
    store.advanceDay()
    store.advanceDay()
    store.advanceDay()
    return MainGameView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

#Preview("Team / Tactics", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 4)
    return SquadView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

@MainActor
private func matchPreviewStore() -> GameStore {
    let store = GameStore()
    store.newGame(clubIndex: 3)   // Stamford Blues — blue theme
    var days = 0
    while !store.isUserMatchToday && days < 90 { store.advanceDay(); days += 1 }
    store.beginUserMatch()
    if let live = store.live {
        // Advance the clock a little for a populated preview.
        for _ in 0..<70 { live.testAdvanceMinute() }
    }
    return store
}

#Preview("Live Match", traits: .landscapeLeft) {
    let store = matchPreviewStore()
    return Group {
        if let live = store.live {
            MatchView(store: store, live: live)
        }
    }
    .font(.system(.body, design: .monospaced))
    .foregroundStyle(Retro.text)
    .tint(Retro.accent)
    .background(Retro.background)
}

#Preview("Transfers", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 2)
    return TransfersView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

#Preview("Player Profile", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 2)
    let target = store.transferMarket.first { $0.sellingClubIndex != nil }!
    store.scout(target)
    for _ in 0..<4 { store.advanceDay() }
    return PlayerProfileSheet(store: store, context: .market(target)) { _ in }
}

#Preview("Pre-Match Hub", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 4)
    var d = 0; while !store.isUserMatchToday && d < 90 { store.advanceDay(); d += 1 }
    store.enterPreMatch()
    return PreMatchHubView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
}

#Preview("Main Menu", traits: .landscapeLeft) {
    MainMenuView(store: GameStore())
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
}

#Preview("Club Select", traits: .landscapeLeft) {
    ClubSelectView(store: GameStore())
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

#Preview("Division Tables", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 24)
    for _ in 0..<60 { store.advanceDay(); if store.isUserMatchToday { store.beginUserMatch(); store.live?.skipToEnd(); store.finishLiveMatch() } }
    return TableView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}


#Preview("Season Review", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 0)
    while !store.isSeasonOver {
        if store.isUserMatchToday { store.beginUserMatch(); store.live?.skipToEnd(); store.finishLiveMatch() }
        else { store.advanceDay() }
    }
    return SeasonReviewView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
}
