//
//  SettingsView.swift
//  Retro Season Manager
//
//  The Settings tab's grouped menu and every drill-down destination
//  screen it hosts.
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
    case facilities = "Club Facilities"
    case managerOffice = "Manager Office"
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
        case .facilities:       return "building.2.fill"
        case .managerOffice:    return "building.columns.fill"
        case .transferHub:      return "arrow.triangle.2.circlepath.circle.fill"
        case .transferHistory:  return "arrow.left.arrow.right.circle.fill"
        case .seasonHistory:    return "calendar.badge.clock"
        case .currentSave:      return "gamecontroller.fill"
        case .difficulty:       return "slider.horizontal.3"
        case .teamSelection:    return "checklist"
        }
    }

    static let manager: [SettingsDestination] = [.managerProfile, .boardConfidence, .trophyCabinet, .achievements, .seasonObjectives, .managerCV, .records, .hallOfFame, .bestXI, .newspaperArchive, .supporterZone, .facilities, .managerOffice, .transferHub, .transferHistory, .seasonHistory]
    static let options: [SettingsDestination] = [.currentSave, .difficulty, .teamSelection]
}

struct SettingsView: View {
    let store: GameStore
    @State private var destination: SettingsDestination?
    @State private var showingHallOfFame = false
    @State private var showingNewspaperArchive = false
    @State private var showingSupporterZone = false
    @State private var showingFacilities = false
    @State private var showingAchievements = false
    @State private var showingSeasonObjectives = false
    @State private var showingManagerOffice = false
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
                    // The Hall of Fame, Newspaper Archive, Supporter Zone,
                    // Facilities and Achievement Gallery are whole buildings,
                    // not settings sub-pages — a full sheet feels like the
                    // grander, "somewhere you visit" presentation they deserve.
                    switch selected {
                    case .hallOfFame:       showingHallOfFame = true
                    case .newspaperArchive: showingNewspaperArchive = true
                    case .supporterZone:    showingSupporterZone = true
                    case .facilities:       showingFacilities = true
                    case .achievements:     showingAchievements = true
                    case .seasonObjectives: showingSeasonObjectives = true
                    case .managerOffice:    showingManagerOffice = true
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
            NewspaperArchiveView(store: store)
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
        .sheet(isPresented: $showingManagerOffice) {
            ManagerOfficeView(store: store)
        }
        .sheet(isPresented: $showingSupporterZone) {
            SupporterZoneView(store: store)
        }
        .sheet(isPresented: $showingFacilities) {
            FacilitiesView(store: store)
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
        case .achievements:     AchievementGalleryView(store: store)
        case .seasonObjectives: SeasonObjectivesView(store: store)
        case .currentSave:      currentSavePanel
        case .difficulty:       difficultyPanel
        case .teamSelection:    teamSelectionPanel
        case .records:          recordsPanel
        case .hallOfFame:       HallOfFameView(store: store)
        case .bestXI:           bestXIPanel
        case .newspaperArchive: NewspaperArchiveView(store: store)
        case .supporterZone:    SupporterZoneView(store: store)
        case .facilities:       FacilitiesView(store: store)
        case .managerOffice:    ManagerOfficeView(store: store)
        case .transferHub:      TransferHubView(store: store)
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

    private var bestXIPanel: some View {
        Panel(title: "BEST XI YOU'VE MANAGED") {
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

