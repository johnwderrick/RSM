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
    var onSwitchExperience: (() -> Void)? = nil
    @State private var showClubSelect = false
    @State private var showSaveList = false
    @State private var showLegacyCareers = false

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
                        menuTile(icon: "trophy.fill", title: "Legacy",
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
        .sheet(isPresented: $showSaveList) {
            SaveSlotListSheet(store: store)
        }
        .sheet(isPresented: $showLegacyCareers) {
            LegacyCareersListView()
        }
    }

    /// A subtitle describing which start years a new career can begin in —
    /// The most recently played save, if any — `savedGames()` is already
    /// sorted newest first, so this is the one "Resume" jumps straight into.
    private var mostRecentSave: SaveSlotInfo? { GameStore.savedGames().first }

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
    @State private var managerName = ""
    @FocusState private var nameFieldFocused: Bool

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

            Panel(title: "YOUR NAME") {
                TextField("e.g. John Derrick (leave blank for a random name)", text: $managerName)
                    .focused($nameFieldFocused)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Retro.text)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { nameFieldFocused = false }
            }
            .frame(maxWidth: 420)

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
                        store.newGame(clubIndex: clubIndex, startYear: startYear, managerName: managerName)
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

