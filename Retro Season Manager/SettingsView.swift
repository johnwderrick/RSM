//
//  SettingsView.swift
//  Retro Season Manager
//
//  The Career control centre, in the accepted Career light-card design
//  language (canvas, white cards, ink headings, green primary accents,
//  gold only for emphasis, monospaced figures).
//
//  Everything shown is read straight from the authoritative GameStore:
//  club/manager/season identity, the save-slot index, the existing
//  difficulty and team-selection preferences, honour/record/archive APIs
//  and the existing SAVE & EXIT route. Nothing here adds, reinterprets or
//  redirects gameplay — destructive behaviour stays exactly as shipped
//  (Save & Exit persists and returns to the menu; it never deletes).
//

import SwiftUI

// MARK: - Settings

/// A destination reachable from the Settings menu — mirrors the grouped
/// MANAGER / OPTIONS list pattern, so each is a focused single-topic page
/// instead of one endless scroll.
enum SettingsDestination: String, CaseIterable, Identifiable {
    case managerProfile = "Manager Profile"
    case boardConfidence = "Board Confidence"
    case trophyCabinet = "Trophy Cabinet"
    case achievements = "Achievements"
    case seasonObjectives = "Season Objectives"
    case managerCV = "Manager CV"
    case records = "All-Time Records"
    case hallOfFame = "Hall of Fame"
    case bestXI = "Best XI"
    case newspaperArchive = "Newspaper Archive"
    case supporterZone = "Supporter Zone"
    case transferHub = "Transfer Hub"
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
        case .seasonObjectives: return "target"
        case .managerCV:        return "briefcase.fill"
        case .records:          return "chart.bar.fill"
        case .hallOfFame:       return "star.circle.fill"
        case .bestXI:           return "star.square.on.square.fill"
        case .newspaperArchive: return "newspaper.fill"
        case .supporterZone:    return "megaphone.fill"
        case .transferHub:      return "arrow.triangle.2.circlepath.circle.fill"
        case .transferHistory:  return "arrow.left.arrow.right.circle.fill"
        case .seasonHistory:    return "calendar.badge.clock"
        case .currentSave:      return "gamecontroller.fill"
        case .difficulty:       return "slider.horizontal.3"
        case .teamSelection:    return "checklist"
        }
    }

    static let manager: [SettingsDestination] = [.managerProfile, .boardConfidence, .trophyCabinet, .achievements, .seasonObjectives, .managerCV, .records, .hallOfFame, .bestXI, .newspaperArchive, .supporterZone, .transferHub, .transferHistory, .seasonHistory]
    static let options: [SettingsDestination] = [.currentSave, .difficulty, .teamSelection]
}

struct SettingsView: View {
    let store: GameStore
    @State private var destination: SettingsDestination?
    @State private var showingHallOfFame = false
    @State private var showingNewspaperArchive = false
    @State private var showingSupporterZone = false
    @State private var showingAchievements = false
    @State private var showingSeasonObjectives = false
    @State private var showingTransferHub = false

    var body: some View {
        Group {
            if let destination {
                SettingsDetailView(store: store, destination: destination) {
                    Haptics.tap()
                    self.destination = nil
                }
            } else {
                SettingsMenuView(store: store) { selected in
                    Haptics.tap()
                    // Whole buildings (Hall of Fame, Newspaper Archive,
                    // Supporter Zone, Achievements, Season
                    // Objectives, Transfer Hub) present as
                    // full sheets — the grander, "somewhere you visit"
                    // presentation, unchanged from the previous menu.
                    switch selected {
                    case .hallOfFame:       showingHallOfFame = true
                    case .newspaperArchive: showingNewspaperArchive = true
                    case .supporterZone:    showingSupporterZone = true
                    case .achievements:     showingAchievements = true
                    case .seasonObjectives: showingSeasonObjectives = true
                    case .transferHub:      showingTransferHub = true
                    default:                destination = selected
                    }
                }
            }
        }
        .sheet(isPresented: $showingHallOfFame) {
            HallOfFameView(store: store)
        }
        .sheet(isPresented: $showingNewspaperArchive) {
            NewspaperArchiveView(store: store, isSheet: true)
        }
        .sheet(isPresented: $showingTransferHub) {
            TransferHubView(store: store)
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementGalleryView(store: store)
        }
        .sheet(isPresented: $showingSeasonObjectives) {
            SeasonObjectivesView(store: store)
        }
        .sheet(isPresented: $showingSupporterZone) {
            SupporterZoneView(store: store)
        }
    }
}

// MARK: - Settings menu (the light-card control centre)

/// The top-level Settings screen: a career summary, save & career, the
/// existing preferences, records & archives, and the grouped drill-down
/// menu — one stable vertical scroll container, no nested scrolling.
struct SettingsMenuView: View {
    let store: GameStore
    let onSelect: (SettingsDestination) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summaryCard
                saveAndCareerCard
                preferencesCard
                recordsCard
                drillDownCard(title: "MANAGER", destinations: SettingsDestination.manager)
                drillDownCard(title: "OPTIONS", destinations: SettingsDestination.options)
                careerManagementCard
                endAnchor
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier(CareerIdentifiers.settingsScroll)
        .background(CareerPalette.canvas.ignoresSafeArea())
    }

    // MARK: Career summary

    private var summaryCard: some View {
        HStack(spacing: 13) {
            CrestView(shortName: store.userClub.shortName, size: 52, color: store.userColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.userClub.name)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(store.managerName.isEmpty ? "The Manager" : store.managerName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("SEASON")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text(store.seasonLabel)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
            }
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.settingsSummary)
        .accessibilityLabel("""
        Career summary. \(store.userClub.name), managed by \(store.managerName.isEmpty ? "you" : store.managerName). \
        Season \(store.seasonLabel), \(store.divisionName(store.userDivisionTier)). \
        Board objective: \(store.boardObjective.isEmpty ? "none" : store.boardObjective).
        """)
    }

    // MARK: Save & career

    /// The authoritative last-saved stamp: `SaveSlots` refreshes
    /// `lastPlayed` on every `persist()`, so the most recent slot matching
    /// this career's ID is exactly when the club was last written to disk.
    private var lastSavedLine: String? {
        guard let id = store.currentSaveID else { return nil }
        return SaveSlots.all().first { $0.id == id }.map { slot in
            "\(slot.lastPlayed.formatted(.relative(presentation: .named)))"
        }
    }

    private var saveAndCareerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("SAVE & CAREER")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            Text("Your career saves automatically after every match, and whenever you leave the game from this screen. Progress is never lost between sessions.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let lastSavedLine {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(CareerPalette.line)
                    Text("Last saved \(lastSavedLine)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(CareerIdentifiers.settingsLastSaved)
                .accessibilityLabel(lastSavedAccessibility)
            }
            Button {
                Haptics.tap()
                store.quitToMenu()
            } label: {
                Text("⟲  SAVE & EXIT TO MENU")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CareerPalette.line)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.settingsSaveExit)
            .accessibilityLabel("Save and exit to the main menu. Your career is saved automatically.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.settingsSaveCard)
    }

    private var lastSavedAccessibility: String {
        guard let id = store.currentSaveID,
              let slot = SaveSlots.all().first(where: { $0.id == id }) else {
            return "Save status"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return "Last saved \(formatter.string(from: slot.lastPlayed))"
    }

    // MARK: Preferences

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("PREFERENCES")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("DIFFICULTY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Picker("Difficulty", selection: Binding(
                    get: { store.difficulty },
                    set: { Haptics.tap(); store.difficulty = $0 }
                )) {
                    ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(CareerIdentifiers.settingsPreference("difficulty"))
                Text("Affects your team's edge in matches and how patient the board is.")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(CareerPalette.line.opacity(0.14))
            prefToggle(
                title: "ASSIST: AUTO-PICK STARTING XI",
                explanation: "Picks your strongest available side before every match, factoring fitness and morale. When a bigger game is close behind a smaller one, it rests key players who aren't fully fresh rather than risking them.",
                isOn: Binding(
                    get: { store.autoPickAssist },
                    set: { Haptics.tap(); store.autoPickAssist = $0 }
                ),
                identifier: CareerIdentifiers.settingsPreference("auto-pick-assist"),
                disabled: false
            )
            Divider().overlay(CareerPalette.line.opacity(0.14))
            prefToggle(
                title: "DELEGATE PRESS CONFERENCES & TEAM TALKS",
                explanation: store.staffLevel(.assistantManager) >= 3
                    ? "Your assistant handles routine press questions and team talks automatically, picking whichever option reads best."
                    : "Needs an assistant manager of at least level 3 on staff.",
                isOn: Binding(
                    get: { store.delegateToAssistant },
                    set: { Haptics.tap(); store.delegateToAssistant = $0 }
                ),
                identifier: CareerIdentifiers.settingsPreference("delegate-assistant"),
                disabled: store.staffLevel(.assistantManager) < 3
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.settingsPreferences)
    }

    private func prefToggle(title: String, explanation: String,
                            isOn: Binding<Bool>, identifier: String, disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(disabled ? CareerPalette.mutedInk.opacity(0.6) : CareerPalette.ink)
            }
            .tint(CareerPalette.line)
            .disabled(disabled)
            .accessibilityIdentifier(identifier)
            Text(explanation)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Records & archives

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("RECORDS & ARCHIVES")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            ForEach(SettingsDestination.manager.filter(\.isAnArchiveRow)) { destination in
                archiveRow(destination)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.settingsRecords)
    }

    private func archiveRow(_ destination: SettingsDestination) -> some View {
        Button {
            onSelect(destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(CareerPalette.line)
                    .frame(width: 22)
                Text(destination.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
                archiveTrailing(destination)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.settingsArchive(destination.rawValue))
        .accessibilityLabel("\(destination.rawValue), opens \(destination.opensInSheet ? "a full-page sheet" : "a detail page")")
    }

    /// The right-hand context value for an archive row — existing
    /// authoritative counts only.
    @ViewBuilder
    private func archiveTrailing(_ destination: SettingsDestination) -> some View {
        switch destination {
        case .newspaperArchive:
            archiveCount(store.newspapers.count)
        case .transferHistory:
            archiveCount(store.transferHistory.count)
        case .seasonHistory:
            archiveCount(store.history.count)
        case .achievements:
            archiveCount(store.unlockedAchievements.count)
        case .trophyCabinet:
            archiveCount(store.careerHonours.count)
        default:
            EmptyView()
        }
    }

    private func archiveCount(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(CareerPalette.line)
            .monospacedDigit()
    }

    // MARK: Drill-down menu

    private func drillDownCard(title: String, destinations: [SettingsDestination]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            ForEach(destinations) { destination in
                menuRow(destination)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
    }

    private func menuRow(_ destination: SettingsDestination) -> some View {
        Button {
            onSelect(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(CareerPalette.line)
                    .frame(width: 20)
                Text(destination.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(CareerPalette.canvas.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        // Stable per-destination selector derived from the enum raw value,
        // so menu wording changes can't silently move test anchors.
        .accessibilityIdentifier(CareerIdentifiers.settingsRow(destination))
    }

    // MARK: Career management

    private var careerManagementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text("CAREER MANAGEMENT")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            Text("""
            Leaving from this screen always saves first — there is no way to abandon a match or season from here. \
            Careers are managed from the main menu's Load Game screen, where a slot can be renamed or removed \
            (removal is confirmed there and deletes only that career's save).
            """)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(CareerPalette.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.settingsCareerManagement)
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.settingsEnd)
    }
}

/// Rows that surface live authoritative content (a count or a whole
/// building) rather than being plain drill-downs.
private extension SettingsDestination {
    /// Archive-style rows get the records-card treatment with a count.
    var isAnArchiveRow: Bool {
        switch self {
        case .trophyCabinet, .achievements, .newspaperArchive, .transferHistory, .seasonHistory:
            return true
        default:
            return false
        }
    }

    /// The Newspaper Archive presents as a full-page sheet.
    var opensInSheet: Bool { self == .newspaperArchive }
}

// MARK: - Settings detail pages

/// A single Settings sub-page — the drill-down content for one
/// `SettingsDestination`, with a back chevron to return to the menu.
struct SettingsDetailView: View {
    let store: GameStore
    let destination: SettingsDestination
    let onBack: () -> Void

    private func recordLine(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label).foregroundStyle(CareerPalette.mutedInk)
            Spacer()
            Text(value ?? "—").bold().foregroundStyle(CareerPalette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.system(size: 10, design: .monospaced))
    }

    /// A white card wrapper with the accepted shadow/outline treatment.
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }

    /// The building destinations draw their own full-height scrollable
    /// content (they are the same views the menu presents as sheets), so
    /// their detail pages pin the back bar above the building instead of
    /// wrapping it in another vertical scroll — one vertical container,
    /// never nested.
    private static let wholeBuildingDestinations: Set<SettingsDestination> = [
        .achievements, .seasonObjectives, .hallOfFame, .newspaperArchive,
        .supporterZone, .transferHub,
    ]

    var body: some View {
        Group {
            if Self.wholeBuildingDestinations.contains(destination) {
                VStack(spacing: 0) {
                    backBar
                    building
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        backBar
                        content
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .background(CareerPalette.canvas.ignoresSafeArea())
    }

    private var backBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .black))
                    Text("SETTINGS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(CareerPalette.line)
            }
            .buttonStyle(PressableButtonStyle())
            .frame(minHeight: 44)
            .accessibilityIdentifier(CareerIdentifiers.settingsBack)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var building: some View {
        switch destination {
        case .achievements:     AchievementGalleryView(store: store, showsClose: false)
        case .seasonObjectives: SeasonObjectivesView(store: store)
        case .hallOfFame:       HallOfFameView(store: store, showsClose: false)
        case .newspaperArchive: NewspaperArchiveView(store: store)
        case .supporterZone:    SupporterZoneView(store: store)
        case .transferHub:      TransferHubView(store: store)
        default:                EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .managerProfile:   card { managerProfilePanel }
        case .boardConfidence:  card { boardConfidencePanel }
        case .trophyCabinet:    card { trophyCabinetPanel }
        // Whole-building destinations render through `building` above the
        // detail scroll (they bring their own scroll containers).
        case .achievements, .seasonObjectives, .hallOfFame, .newspaperArchive,
             .supporterZone, .transferHub:
            EmptyView()
        case .currentSave:      card { currentSavePanel }
        case .difficulty:       card { difficultyPanel }
        case .teamSelection:    card { teamSelectionPanel }
        case .records:          card { recordsPanel }
        case .bestXI:           card { bestXIPanel }
        case .managerCV:        card { managerCVPanel }
        case .transferHistory:  card { transferHistoryPanel }
        case .seasonHistory:    card { seasonHistoryPanel }
        }
    }

    private var managerProfilePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                CrestView(shortName: store.userClub.shortName, size: 54, color: store.userColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.userClub.name)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                    Text(store.divisionName(store.userDivisionTier))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
            }
            Divider().overlay(CareerPalette.line.opacity(0.14))
            recordLine("Reputation", "\(store.reputationLabel) (\(store.managerReputation))")
            recordLine("Job security", store.jobSecurity)
            recordLine("Board objective", store.boardObjective)
            recordLine("Season", store.seasonLabel)
            recordLine("Honours won", "\(store.careerHonours.count)")
        }
    }

    private var boardConfidencePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConfidenceBar(value: store.boardConfidence, trend: store.boardConfidenceTrend)
            Divider().overlay(CareerPalette.line.opacity(0.14))
            Text(confidenceReadout)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            recordLine("This season's objective", store.boardObjective)
            recordLine("Job security", store.jobSecurity)
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
        VStack(alignment: .leading, spacing: 10) {
            if store.careerHonours.isEmpty {
                Text("Nothing in the cabinet yet — win something to start filling it.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
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
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(CareerPalette.mutedInk)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    private var currentSavePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            recordLine("Club", "\(store.userClub.name) (\(store.divisionName(store.userDivisionTier)))")
            recordLine("Season", store.seasonLabel)
            recordLine("Reputation", "\(store.reputationLabel) (\(store.managerReputation))")
            recordLine("Honours", "\(store.careerHonours.count)")
            if let id = store.currentSaveID,
               let slot = SaveSlots.all().first(where: { $0.id == id }) {
                Divider().overlay(CareerPalette.line.opacity(0.14))
                recordLine("Save slot", slot.clubName)
                recordLine("Last saved", slot.lastPlayed.formatted(.relative(presentation: .named)))
            }
        }
    }

    private var difficultyPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Difficulty", selection: Binding(
                get: { store.difficulty },
                set: { store.difficulty = $0 }
            )) {
                ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(CareerIdentifiers.settingsPreference("difficulty"))
            Text("Affects your team's edge in matches and how patient the board is.")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var teamSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { store.autoPickAssist },
                set: { store.autoPickAssist = $0 }
            )) {
                Text("Assist: auto-pick starting XI")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
            }
            .tint(CareerPalette.line)
            .accessibilityIdentifier(CareerIdentifiers.settingsPreference("auto-pick-assist"))
            Text("Picks your strongest available side before every match, factoring fitness and morale. When a bigger game is close behind a smaller one (say a midweek cup tie before a big league weekend), it rests key players who aren't fully fresh rather than risking them.")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(CareerPalette.line.opacity(0.14))
            Toggle(isOn: Binding(
                get: { store.delegateToAssistant },
                set: { store.delegateToAssistant = $0 }
            )) {
                Text("Delegate press conferences & team talks")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
            }
            .tint(CareerPalette.line)
            .disabled(store.staffLevel(.assistantManager) < 3)
            .accessibilityIdentifier(CareerIdentifiers.settingsPreference("delegate-assistant"))
            Text(store.staffLevel(.assistantManager) >= 3
                 ? "Your assistant handles routine press questions and team talks automatically, picking whichever option reads best."
                 : "Needs an assistant manager of at least level 3 on staff.")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recordsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            let honours = store.honourTally()
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
            Divider().overlay(CareerPalette.line.opacity(0.14))
            Text("Your honours: \(honours.titles) titles · \(honours.cups) cups · \(honours.euros) European · \(honours.promotions) promotions")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.line)
        }
    }

    private var bestXIPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            let xi = store.bestEverXI()
            if xi.isEmpty {
                Text("Complete a season to start building your Hall of Fame.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(xi) { entry in
                        HStack(spacing: 6) {
                            Text(entry.position.rawValue)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(CareerPalette.line)
                                .frame(width: 32, alignment: .leading)
                            Text(entry.name).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundStyle(CareerPalette.ink)
                            Spacer(minLength: 2)
                            Text("\(entry.peakRating)")
                                .foregroundStyle(CareerPalette.line).bold()
                                .monospacedDigit()
                        }
                        .font(.system(size: 9, design: .monospaced))
                    }
                }
            }
        }
    }

    private var managerCVPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            let cv = store.managerCV()
            if cv.isEmpty {
                Text("Complete a season to start your CV.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                ForEach(cv) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.club)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(CareerPalette.line)
                            Spacer()
                            Text("\(entry.seasons) season\(entry.seasons == 1 ? "" : "s")")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(CareerPalette.mutedInk)
                        }
                        Text("\(entry.record.wins)W \(entry.record.draws)D \(entry.record.losses)L · \(entry.record.winPercentage)% win rate")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                        if !entry.trophies.isEmpty {
                            ForEach(entry.trophies, id: \.self) { trophy in
                                HonourRow(text: trophy, size: 16)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(CareerPalette.line)
                            }
                        }
                    }
                }
            }
        }
    }

    private var transferHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.transferHistory.isEmpty {
                Text("No transfer activity yet. Signings and sales will be recorded here.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                ForEach(store.transferHistory.prefix(25)) { entry in
                    HStack {
                        Text(entry.date.formatted(.dateTime.day().month(.abbreviated).year()))
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(CareerPalette.mutedInk.opacity(0.8))
                        Text("\(entry.action) \(entry.playerName)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(CareerPalette.ink)
                        if let otherClub = entry.otherClub {
                            Text(otherClub)
                                .foregroundStyle(CareerPalette.mutedInk)
                        }
                        if let fee = entry.fee {
                            Text(formatMoney(fee))
                                .foregroundStyle(CareerPalette.line)
                                .monospacedDigit()
                        }
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                if store.transferHistory.count > 25 {
                    Text("+ \(store.transferHistory.count - 25) more")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk.opacity(0.8))
                }
            }
        }
    }

    private var seasonHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if store.history.isEmpty {
                Text("No completed seasons yet.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                HStack {
                    Text("Season").frame(width: 70, alignment: .leading)
                    Text("You").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Champions").frame(maxWidth: .infinity, alignment: .leading)
                    Text("National Cup").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Europe").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.line)
                ForEach(store.history.reversed()) { record in
                    HStack {
                        Text(record.label).frame(width: 70, alignment: .leading)
                            .foregroundStyle(CareerPalette.mutedInk)
                        Text("\(ordinal(record.userPosition)) \(record.userDivision)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(CareerPalette.ink)
                        Text(record.champion).frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(CareerPalette.mutedInk)
                        Text(record.cupWinner).frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(CareerPalette.mutedInk)
                        Text(record.euroWinner).frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        }
    }
}
