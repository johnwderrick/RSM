//
//  MainMenuFlow.swift
//  Retro Season Manager
//
//  The pre-career flow: save-slot management, the main menu, and
//  choosing/confirming a club to start a new career with.
//

import SwiftUI

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
    @State private var loadFailed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.trailing, 48)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if saves.isEmpty {
                            emptyState
                        } else {
                            ForEach(saves) { slot in row(slot) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .accessibilityIdentifier("career.saves.scroll")
            }
            .padding(20)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.65))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("career.saves.close")
            .accessibilityLabel("Close career saves")
            .padding(12)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
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
        .alert("Unable to load career", isPresented: $loadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This save could not be opened. Your other saves have not been changed.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 25))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 50, height: 50)
                .background(CareerPalette.line.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("CAREER SAVES")
                    .font(.system(.headline, design: .monospaced).bold())
                    .accessibilityIdentifier("career.saves.header")
                Text("\(saves.count) SAVED \(saves.count == 1 ? "CAREER" : "CAREERS") · SELECT ONE TO CONTINUE")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(CareerPalette.mutedInk)
                    .accessibilityIdentifier("career.saves.count")
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(CareerPalette.line)
            Text("NO CAREER SAVES YET")
                .font(.system(.headline, design: .monospaced).bold())
            Text("Start a new career to create your first save.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("career.saves.empty")
    }

    private func row(_ slot: SaveSlotInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "soccerball")
                    .font(.system(size: 23))
                    .foregroundStyle(CareerPalette.line)
                    .frame(width: 42, height: 42)
                    .background(CareerPalette.line.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.displayName)
                        .font(.system(.callout, design: .monospaced).bold())
                        .accessibilityIdentifier("career.saves.name.\(slot.id.uuidString)")
                    Text("SEASON \(slot.season) · \(slot.divisionName.isEmpty ? "IN PROGRESS" : slot.divisionName.uppercased())")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(CareerPalette.mutedInk)
                    Text("LAST PLAYED \(slot.lastPlayed.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    store.runHeavy("Loading \(slot.displayName)…") {
                        if !store.loadSavedGame(id: slot.id) { loadFailed = true }
                    }
                } label: {
                    Label("LOAD CAREER", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .foregroundStyle(.white)
                        .background(CareerPalette.line)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .accessibilityIdentifier("career.saves.load.\(slot.id.uuidString)")

                Button {
                    renameText = slot.displayName
                    renaming = slot
                } label: {
                    Label("RENAME", systemImage: "pencil")
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(CareerPalette.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .accessibilityIdentifier("career.saves.rename.\(slot.id.uuidString)")

                Button {
                    pendingDelete = slot
                } label: {
                    Label("DELETE", systemImage: "trash")
                        .foregroundStyle(.red)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .accessibilityIdentifier("career.saves.delete.\(slot.id.uuidString)")
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .buttonStyle(PressableButtonStyle())
        }
        .padding(14)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.06), radius: 7, y: 3)
    }
}

// MARK: - Main menu

struct MainMenuView: View {
    let store: GameStore
    var onSwitchExperience: (() -> Void)? = nil
    @State private var showClubSelect = false
    @State private var showSaveList = false
    @State private var showLegacyCareers = false
    @State private var loadFailed = false
    @State private var availableSaves: [SaveSlotInfo] = GameStore.savedGames()

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

                // A horizontally scrolling row rather than a fixed HStack —
                // matches `startYearPicker`'s own reasoning: keeps this
                // working cleanly on narrow phones now that a fourth tile
                // ("Legacy") has been added, and for however many more
                // might be added later.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        menuTile(icon: "play.fill", title: "Resume",
                                 subtitle: mostRecentSave.map { "Continue \($0.displayName)" } ?? "No save to resume",
                                 enabled: mostRecentSave != nil) {
                            guard let slot = mostRecentSave else { return }
                            store.runHeavy("Loading \(slot.displayName)…") {
                                if !store.loadSavedGame(id: slot.id) { loadFailed = true }
                            }
                        }
                        .accessibilityIdentifier("career.menu.resume")
                        menuTile(icon: "gearshape.fill", title: "New Game",
                                 subtitle: "Pick a club and start", enabled: true) {
                            withAnimation(.easeInOut(duration: 0.25)) { showClubSelect = true }
                        }
                        menuTile(icon: "folder.fill", title: "Load Game",
                                 subtitle: availableSaves.isEmpty ? "No saves yet" : "\(availableSaves.count) career save\(availableSaves.count == 1 ? "" : "s")",
                                 enabled: !availableSaves.isEmpty) {
                            showSaveList = true
                        }
                        .accessibilityIdentifier("career.menu.loadGame")
                        menuTile(icon: "trophy.fill", title: "Museum",
                                 subtitle: legacyCareers.isEmpty ? "No careers finished yet" : "\(legacyCareers.count) past career\(legacyCareers.count == 1 ? "" : "s")",
                                 enabled: !legacyCareers.isEmpty) {
                            showLegacyCareers = true
                        }
                    }
                    .padding(20)
                }
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
        .overlay(alignment: .topTrailing) {
            if let onSwitchExperience {
                Button {
                    Haptics.tap()
                    onSwitchExperience()
                } label: {
                    Text("Switch Mode ›")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Retro.background.opacity(0.6))
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .padding()
            }
        }
        .onAppear { availableSaves = GameStore.savedGames() }
        .sheet(isPresented: $showSaveList, onDismiss: {
            availableSaves = GameStore.savedGames()
        }) {
            SaveSlotListSheet(store: store)
        }
        .sheet(isPresented: $showLegacyCareers) {
            LegacyCareersListView()
        }
        .alert("Unable to load career", isPresented: $loadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This save could not be opened. Your other saves have not been changed.")
        }
    }

    /// A subtitle describing which start years a new career can begin in —
    /// The most recently played save, if any — `savedGames()` is already
    /// sorted newest first, so this is the one "Resume" jumps straight into.
    private var mostRecentSave: SaveSlotInfo? { availableSaves.first }

    /// Every permanently archived career — see `LegacyCareer.swift`.
    private var legacyCareers: [LegacyCareerInfo] { LegacyArchive.all() }

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
    @State private var managerName = ""

    var body: some View {
        if let pendingClubIndex, let preview = store.clubPreview(forClubIndex: pendingClubIndex, startYear: selectedStartYear) {
            ClubConfirmView(store: store, clubIndex: pendingClubIndex, preview: preview,
                            startYear: selectedStartYear, managerName: $managerName) {
                withAnimation(.easeInOut(duration: 0.25)) { self.pendingClubIndex = nil }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        } else {
            selectionList
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)).combined(with: .opacity))
        }
    }

    private var selectionList: some View {
        VStack(spacing: 0) {
            selectionHeader

            if GameStore.availableStartYears.count > 1 {
                startYearPicker
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(store.clubsByDivision, id: \.tier) { division in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(CareerPalette.line)
                                    .frame(width: 4, height: 16)
                                    .clipShape(Capsule())
                                Text(division.name.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(CareerPalette.ink)
                                Spacer()
                                Text("\(division.clubs.count) CLUBS")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(CareerPalette.mutedInk)
                            }
                            .padding(.horizontal, 2)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(division.clubs, id: \.index) { club in
                                    clubChoice(club)
                                }
                            }
                        }
                    }
                    Color.clear
                        .frame(height: 2)
                        .accessibilityIdentifier("career.newGame.clubs.end")
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 18)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CareerIdentifiers.newGameClubScroll)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CareerPalette.canvas.ignoresSafeArea())
        .font(.system(.body, design: .monospaced))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(CareerIdentifiers.newGameSelect)
        }
    }

    private var selectionHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if let onBack {
                    Button {
                        Haptics.tap()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(CareerPalette.line)
                            .frame(width: 36, height: 36)
                            .background(CareerPalette.surface)
                            .overlay(Circle().stroke(CareerPalette.line.opacity(0.18)))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.newGameBack)
                    .accessibilityLabel("Back to main menu")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW CAREER")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                    Text("Choose your era and club")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
                Spacer(minLength: 2)
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                    .frame(width: 38, height: 38)
                    .background(CareerPalette.line.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
            }

            Text("Pick a starting season, then choose any club from the four-division pyramid.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func clubChoice(_ club: (index: Int, name: String, short: String)) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.25)) { pendingClubIndex = club.index }
        } label: {
            HStack(spacing: 8) {
                Text(club.short)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .frame(width: 34, height: 34)
                    .background(CareerPalette.line.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                Text(club.name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(CareerPalette.line.opacity(0.16)))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: CareerPalette.ink.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.newGameClub(club.index))
        .accessibilityLabel("\(club.name), \(club.short), \(ClubSelectView.seasonLabel(for: selectedStartYear))")
    }

    private var startYearPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("STARTING ERA")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
                Text("SEASON \(Self.seasonLabel(for: selectedStartYear))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .accessibilityIdentifier(CareerIdentifiers.newGameSelectedEra)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(GameStore.availableStartYears, id: \.self) { year in
                        let selected = selectedStartYear == year
                        Button {
                            Haptics.tap()
                            selectedStartYear = year
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Self.seasonLabel(for: year))
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                Text(eraSubtitle(for: year))
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(selected ? Color.white : CareerPalette.ink)
                            .frame(minWidth: 86, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selected ? CareerPalette.line : CareerPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? CareerPalette.line : CareerPalette.line.opacity(0.18)))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier(CareerIdentifiers.newGameEra(year))
                        .accessibilityLabel("\(Self.seasonLabel(for: year)) era")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CareerIdentifiers.newGameEraScroll)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CareerPalette.surface)
        .accessibilityElement(children: .contain)
        .overlay(alignment: .top) { Rectangle().fill(CareerPalette.line.opacity(0.12)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(CareerPalette.line.opacity(0.12)).frame(height: 1) }
    }

    private func eraSubtitle(for year: Int) -> String {
        switch year {
        case 2000: return "THE MILLENNIUM"
        case 2010: return "A NEW DECADE"
        case 2020: return "THE MODERN ERA"
        default: return "START IN \(year)"
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
    @Binding var managerName: String
    var onBack: () -> Void
    @FocusState private var nameFieldFocused: Bool

    private var clubColor: Color { Color(rgb: preview.colorRGB) }

    var body: some View {
        VStack(spacing: 0) {
            confirmationHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    clubIdentityCard
                    managerNameCard
                    previewCard
                    Color.clear
                        .frame(height: 1)
                        .accessibilityIdentifier("career.newGame.confirm.end")
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .accessibilityIdentifier(CareerIdentifiers.newGameConfirm)
            .scrollDismissesKeyboard(.interactively)

            confirmationFooter
        }
        .background(CareerPalette.canvas.ignoresSafeArea())
        .font(.system(.body, design: .monospaced))
    }

    private var confirmationHeader: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                nameFieldFocused = false
                onBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .black))
                    Text("CLUBS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundStyle(CareerPalette.line)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(CareerPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.newGameBackToClubs)
            .accessibilityLabel("Back to club selection")

            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR NEW CLUB")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("SEASON \(ClubSelectView.seasonLabel(for: startYear)) · READY TO BUILD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var clubIdentityCard: some View {
        HStack(spacing: 12) {
            CrestView(shortName: preview.short, size: 54, color: clubColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.name)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(preview.divisionName.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                StarRatingView(stars: preview.stars)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(CareerPalette.line.opacity(0.82))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.newGameClubSummary)
        .accessibilityLabel("\(preview.name), \(preview.divisionName), \(preview.stars) stars, season \(ClubSelectView.seasonLabel(for: startYear))")
    }

    private var managerNameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeading("YOUR NAME", icon: "person.crop.circle")
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CareerPalette.line)
                TextField("e.g. John Derrick", text: $managerName)
                    .focused($nameFieldFocused)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { nameFieldFocused = false }
                    .accessibilityIdentifier(CareerIdentifiers.newGameManagerName)
                if !managerName.isEmpty {
                    Button {
                        managerName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(CareerPalette.mutedInk.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear manager name")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(CareerPalette.canvas.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            Text("Leave blank and we'll choose a name for you.")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeading("WHAT TO EXPECT", icon: "chart.bar.doc.horizontal")
            VStack(spacing: 0) {
                confirmStat("Starting season", ClubSelectView.seasonLabel(for: startYear))
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("career.newGame.preview.startingSeason")
                    .accessibilityLabel("Starting season \(ClubSelectView.seasonLabel(for: startYear))")
                statDivider
                confirmStat("League standing", "\(ordinal(preview.divisionRank)) of \(preview.divisionSize) seeds")
                statDivider
                confirmStat("Transfer budget", formatMoney(preview.estimatedBudget))
                statDivider
                confirmStat("Board objective", preview.boardObjective)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.newGamePreview)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(CareerPalette.line.opacity(0.10))
            .frame(height: 1)
    }

    private func cardHeading(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(CareerPalette.line)
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
            Spacer()
        }
    }

    private var confirmationFooter: some View {
        VStack(spacing: 5) {
            Button {
                Haptics.success()
                nameFieldFocused = false
                store.runHeavy("Building the \(preview.name) squad…") {
                    store.newGame(clubIndex: clubIndex, startYear: startYear, managerName: managerName)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 13, weight: .black))
                    Text("MANAGE \(preview.name.uppercased())")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 520)
                .frame(height: 46)
                .background(LinearGradient(colors: [CareerPalette.line, CareerPalette.ink],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: CareerPalette.line.opacity(0.24), radius: 7, y: 3)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.newGameManage)
            .accessibilityLabel("Manage \(preview.name)")

            Text("A fresh, independent career save — existing saves stay untouched.")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(CareerPalette.canvas)
        .overlay(alignment: .top) { Rectangle().fill(CareerPalette.line.opacity(0.18)).frame(height: 1) }
    }

    private func confirmStat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
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
