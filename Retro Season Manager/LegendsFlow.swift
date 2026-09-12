//
//  LegendsFlow.swift
//  Retro Season Manager
//
//  Top-level mode selection and the RSM Legends dashboard.
//

import SwiftUI

enum GameExperience {
    case career
    case legends
}

/// Geometry contract for the supplied 1844 × 853 experience artwork.
/// Keeping the conversion pure makes the selector easy to verify across
/// device sizes without relying on screenshot coordinates.
enum ExperienceSelectorLayout {
    static let referenceSize = CGSize(width: 1844, height: 853)
    static let careerPanel = CGRect(x: 188, y: 178, width: 708, height: 638)
    static let legendsPanel = CGRect(x: 920, y: 178, width: 708, height: 638)
    static let careerButton = CGRect(x: 290, y: 724, width: 500, height: 102)
    static let legendsButton = CGRect(x: 1022, y: 724, width: 500, height: 102)

    static func fittedArtworkFrame(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(size.width / referenceSize.width,
                        size.height / referenceSize.height)
        let displayedSize = CGSize(width: referenceSize.width * scale,
                                   height: referenceSize.height * scale)
        return CGRect(x: max(0, (size.width - displayedSize.width) / 2),
                      y: max(0, (size.height - displayedSize.height) / 2),
                      width: displayedSize.width,
                      height: displayedSize.height)
    }

    static func frame(_ referenceRect: CGRect, in artworkFrame: CGRect) -> CGRect {
        guard referenceSize.width > 0 else { return .zero }
        let scale = artworkFrame.width / referenceSize.width
        return CGRect(x: artworkFrame.minX + referenceRect.minX * scale,
                      y: artworkFrame.minY + referenceRect.minY * scale,
                      width: referenceRect.width * scale,
                      height: referenceRect.height * scale)
    }
}

/// Single source of truth for the experience-selector normal/pressed artwork.
/// Both the button styles and the unit tests use these so the pressed variant
/// kept in sync with a button's press state.
enum ExperienceSelectorArtwork {
    /// Which entry experience a TAP TO ENTER button represents.
    enum Entry {
        case career, legends

        var imageName: String {
            switch self {
            case .career: return "RSMCareerEntryButton"
            case .legends: return "RSMLegendsEntryButton"
            }
        }

        var pressedImageName: String {
            switch self {
            case .career: return "RSMCareerEntryButtonPressed"
            case .legends: return "RSMLegendsEntryButtonPressed"
            }
        }
    }

    static let settingsImageName = "RSMSettingsButton"
    static let settingsPressedImageName = "RSMSettingsButtonPressed"

    static func entry(_ kind: Entry, pressed: Bool) -> String {
        pressed ? kind.pressedImageName : kind.imageName
    }

    static func settings(pressed: Bool) -> String {
        pressed ? settingsPressedImageName : settingsImageName
    }
}

struct ExperienceSelectView: View {
    @Binding var experience: GameExperience?
    @State private var appeared = false
    @State private var showingSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum ExperienceType {
        case career
        case legends

        var artworkEntry: ExperienceSelectorArtwork.Entry {
            switch self {
            case .career: return .career
            case .legends: return .legends
            }
        }

        var accessibilityLabel: LocalizedStringKey {
            switch self {
            case .career: return "experience.enterCareer"
            case .legends: return "experience.enterLegends"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .career: return "experience.career"
            case .legends: return "experience.legends"
            }
        }
    }

    /// Reference coordinates match the supplied 1844 × 853 composition.
    /// Keeping these in one layout value makes the aspect-fit conversion
    /// auditable and prevents device-specific magic numbers from spreading
    /// through the selector.

    var body: some View {
        GeometryReader { geo in
            let artworkFrame = fittedArtworkFrame(in: geo.size)
            ZStack {
                selectorBackground

                Image("RSMExperienceBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: artworkFrame.width, height: artworkFrame.height)
                    .position(x: artworkFrame.midX, y: artworkFrame.midY)
                    .accessibilityHidden(true)

                panelHitArea(ExperienceSelectorLayout.careerPanel, label: "experience.enterCareer") {
                    enter(.career)
                }
                panelHitArea(ExperienceSelectorLayout.legendsPanel, label: "experience.enterLegends") {
                    enter(.legends)
                }

                entryButton(.career, artworkFrame: artworkFrame)
                entryButton(.legends, artworkFrame: artworkFrame)
            }
            .overlay(alignment: .topTrailing) {
                settingsButton(compact: geo.size.width < 700)
                    .padding(.top, max(10, geo.safeAreaInsets.top + 8))
                    .padding(.trailing, max(10, geo.safeAreaInsets.trailing + 8))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            }
        }
        // iPad gets a focused full-screen settings destination; iPhone
        // keeps the lightweight sheet presentation.
        .sheet(isPresented: settingsSheetBinding) {
            settingsDestinationView
        }
        .fullScreenCover(isPresented: settingsFullScreenBinding) {
            settingsDestinationView
        }
    }

    private var selectorBackground: some View {
        // Edge colours are sampled from the RSMExperienceBackground artwork so
        // the surrounding glow blends with it instead of forming a visible
        // saturated ring around the composition.
        let base = Color(red: 0.01, green: 0.015, blue: 0.025)
        let leftGlow = Color(red: 0.043, green: 0.090, blue: 0.004)
        let rightGlow = Color(red: 0.039, green: 0.004, blue: 0.114)
        return ZStack {
            base
            RadialGradient(colors: [leftGlow, .clear],
                           center: .leading, startRadius: 30, endRadius: 620)
            RadialGradient(colors: [rightGlow, .clear],
                           center: .trailing, startRadius: 30, endRadius: 620)
        }
        .ignoresSafeArea()
    }

    private func fittedArtworkFrame(in size: CGSize) -> CGRect {
        ExperienceSelectorLayout.fittedArtworkFrame(in: size)
    }

    private func frame(_ referenceRect: CGRect, in artworkFrame: CGRect) -> CGRect {
        ExperienceSelectorLayout.frame(referenceRect, in: artworkFrame)
    }

    private func panelHitArea(_ referenceRect: CGRect, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        GeometryReader { geo in
            let artworkFrame = fittedArtworkFrame(in: geo.size)
            Button(action: action) {
                Color.clear
            }
            .frame(width: frame(referenceRect, in: artworkFrame).width,
                   height: frame(referenceRect, in: artworkFrame).height)
            .position(x: frame(referenceRect, in: artworkFrame).midX,
                      y: frame(referenceRect, in: artworkFrame).midY)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(label))
            .accessibilityHidden(true)
        }
        .allowsHitTesting(true)
    }

    private func entryButton(_ type: ExperienceType, artworkFrame: CGRect) -> some View {
        let referenceRect = type == .career ? ExperienceSelectorLayout.careerButton : ExperienceSelectorLayout.legendsButton
        let buttonFrame = frame(referenceRect, in: artworkFrame)
        return ExperienceEntryButton(entry: type.artworkEntry,
                                     label: type.accessibilityLabel,
                                     accessibilityIdentifier: type.accessibilityIdentifier,
                                     appeared: appeared) {
            enter(type == .career ? .career : .legends)
        }
        .frame(width: buttonFrame.width, height: buttonFrame.height)
        .position(x: buttonFrame.midX, y: buttonFrame.midY)
    }

    private func settingsButton(compact: Bool) -> some View {
        // Two-state artwork: RSMSettingsButton (normal) and
        // RSMSettingsButtonPressed. The Pressed imageset carries the original
        // pressed variant of the pill; the gear and SETTINGS text are rendered
        // natively inside SettingsButtonStyle. The button swaps the artwork on
        // press instead of relying on scale/brightness alone.
        Button {
            Haptics.tap()
            SoundManager.shared.play(.menuSettings)
            showingSettings = true
        } label: {
            Color.clear
        }
        .frame(width: compact ? 48 : 142, height: compact ? 40 : 45)
        .accessibilityLabel(Text("experience.settings"))
        .accessibilityIdentifier("experience.settings")
        .buttonStyle(SettingsButtonStyle(compact: compact))
    }

    private var settingsDestinationView: some View {
        ZStack(alignment: .topTrailing) {
            AppSettingsView()
            Button {
                showingSettings = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Retro.text)
                    .padding(12)
            }
            .accessibilityLabel(Text("experience.closeSettings"))
            .buttonStyle(ExperienceEntryButtonStyle())
        }
    }

    private var settingsSheetBinding: Binding<Bool> {
        Binding(
            get: { showingSettings && horizontalSizeClass != .regular },
            set: { showingSettings = $0 }
        )
    }

    private var settingsFullScreenBinding: Binding<Bool> {
        Binding(
            get: { showingSettings && horizontalSizeClass == .regular },
            set: { showingSettings = $0 }
        )
    }

    private func enter(_ destination: GameExperience) {
        Haptics.tap()
        SoundManager.shared.play(destination == .career ? .menuCareer : .menuLegends)
        experience = destination
    }
}

private struct ExperienceEntryButton: View {
    let entry: ExperienceSelectorArtwork.Entry
    let label: LocalizedStringKey
    let accessibilityIdentifier: String
    let appeared: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Two-state artwork matching SettingsButtonStyle: the normal and
        // pressed entry-button images are swapped by EntryArtworkButtonStyle
        // on press, while the TAP TO ENTER text renders natively on top.
        Button(action: action) {
            Color.clear
        }
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(accessibilityIdentifier)
        .buttonStyle(EntryArtworkButtonStyle(entry: entry))
        .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
        .offset(y: reduceMotion ? 0 : (appeared ? 0 : 8))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: appeared)
    }
}

/// Two-state button style for the Career/Legends TAP TO ENTER buttons. It
/// swaps the normal and pressed artwork on press and draws the label natively,
/// matching how SettingsButtonStyle handles the Settings button.
private struct EntryArtworkButtonStyle: ButtonStyle {
    let entry: ExperienceSelectorArtwork.Entry

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Image(ExperienceSelectorArtwork.entry(entry, pressed: configuration.isPressed))
                .resizable()
                .aspectRatio(contentMode: .fit)
                // Expose the resolved state as a leaf accessibility element so
                // UI tests can assert the pressed artwork swaps in on press.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("")
                .accessibilityIdentifier(ExperienceSelectorArtwork.entry(entry, pressed: configuration.isPressed))
            HStack(spacing: 7) {
                Text("experience.tapToEnter")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.96))
            .shadow(color: .black.opacity(0.7), radius: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
        .brightness(configuration.isPressed ? -0.02 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// Pressed-state button style for the experience-selector Settings button.
/// It swaps between the normal and pressed pill artwork on press while
/// keeping the gear + label overlay and the existing scale/brightness feel.
private struct SettingsButtonStyle: ButtonStyle {
    let compact: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Image(ExperienceSelectorArtwork.settings(pressed: configuration.isPressed))
                .resizable()
                .aspectRatio(contentMode: .fit)
                // Expose the resolved state as a leaf accessibility element so
                // UI tests can assert the pressed artwork swaps in on press.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("")
                .accessibilityIdentifier(ExperienceSelectorArtwork.settings(pressed: configuration.isPressed))
            if compact {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                    Text("experience.settings")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            }
        }
        .frame(width: compact ? 48 : 142, height: compact ? 40 : 45)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
        .brightness(configuration.isPressed ? -0.035 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct ExperienceEntryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .brightness(configuration.isPressed ? -0.035 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

enum LegendsNavItem: String, CaseIterable, Identifiable {
    case home = "HOME"
    case squad = "SQUAD"
    case training = "TRAINING"
    case packs = "PACKS"
    case collection = "PLAYERS"
    case challenges = "CHALLENGES"
    case table = "DIVISION"
    case club = "CLUB"
    case hall = "HALL"
    case planning = "PLANNING"
    case reports = "REPORTS"
    case profile = "MANAGER"
    case settings = "SETTINGS"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .squad: return "person.3.fill"
        case .training: return "figure.run.circle.fill"
        case .packs: return "shippingbox.fill"
        case .collection: return "square.stack.3d.up.fill"
        case .challenges: return "flag.checkered"
        case .table: return "trophy.fill"
        case .club: return "building.columns.fill"
        case .hall: return "rosette"
        case .planning: return "chart.bar.xaxis"
        case .reports: return "doc.text.magnifyingglass"
        case .profile: return "person.crop.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// The destination rendered inside the Legends home container. `nil` is
/// the dashboard itself; the other cases are the full-screen menus that
/// previously used modal covers.
enum LegendsScreen {
    case squad, training, packs, collection, match, challenges, table, club, facilities, managers, stadiums, hall, profile, settings, planning, reports
}

/// The real RSM Legends home screen. All displayed progression values are
/// read from LegendsStore; this view only changes presentation and routing.
struct LegendsHomeView: View {
    let store: LegendsStore
    var onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedNav: LegendsNavItem = .home
    @State private var screen: LegendsScreen? = nil
    @State private var confirmExit = false

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var crestColor: Color { Color(rgb: store.profile.crestColorRGB) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LegendsPalette.contentBackground.ignoresSafeArea()

                // Destinations render in place and swap instantly. No
                // screen-level transition: the outgoing and incoming views
                // each draw their own sidebar, so any crossfade here flashes
                // and double-renders the whole chrome during the swap.
                switch screen {
                case .squad:
                    LegendsSquadView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .squad)
                    }) { requestExit() }
                case .training:
                    LegendsTrainingView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .training)
                    }) { requestExit() }
                case .packs:
                    LegendsPacksView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .packs)
                    }) { requestExit() }
                case .collection:
                    LegendsCollectionView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .collection)
                    }) { requestExit() }
                case .match:
                    LegendsMatchView(store: store, onNavigate: { item in
                        if item == .home { screen = nil; selectedNav = .home }
                        else { navigateFromDestination(item, current: .home) }
                    }) { requestExit() }
                case .challenges:
                    LegendsChallengesView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .challenges)
                    }) { requestExit() }
                case .table:
                    LegendsDivisionTableView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .table)
                    }) { requestExit() }
                case .club:
                    LegendsClubHubView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .club)
                    }, onOpenManagers: { screen = .managers }, onOpenStadiums: { screen = .stadiums }, onOpenFacilities: { screen = .facilities }) { requestExit() }
                case .facilities:
                    LegendsFacilitiesView(store: store, onNavigate: { item in
                        if item == .club { screen = .club }
                        else { navigateFromDestination(item, current: .club) }
                    }) { requestExit() }
                case .managers:
                    LegendsManagersView(store: store, onNavigate: { item in
                        if item == .club { screen = .club }
                        else { navigateFromDestination(item, current: .club) }
                    }) { requestExit() }
                case .stadiums:
                    LegendsStadiumsView(store: store, onNavigate: { item in
                        if item == .club { screen = .club }
                        else { navigateFromDestination(item, current: .club) }
                    }) { requestExit() }
                case .hall:
                    LegendsHallView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .hall)
                    }) { requestExit() }
                case .planning:
                    LegendsCareerPlanningView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .planning)
                    }, onBack: { screen = nil; selectedNav = .home })
                case .reports:
                    LegendsSeasonReportsView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .reports)
                    }, onBack: { screen = nil; selectedNav = .home })
                case .profile:
                    LegendsManagerProfileView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .profile)
                    }) { requestExit() }
                case .settings:
                    LegendsSettingsView(store: store, onNavigate: { item in
                        navigateFromDestination(item, current: .settings)
                    }) { requestExit() }
                case nil:
                    HStack(spacing: 0) {
                        LegendsSidebar(selected: $selectedNav, compact: isCompact) { item in
                            handleNavigation(item)
                        } onBack: {
                            requestExit()
                        }

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                topBar
                                hero
                                if !store.profile.lastSeasonReview.isEmpty {
                                    seasonReviewBanner
                                }
                                resourceSummary
                                featureGrid
                                divisionPodium
                                bottomPanels
                            }
                            .padding(.horizontal, isCompact ? 14 : 24)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            store.refreshChallengeCadences()
            store.ensureDivisionTable()
        }
        .alert("Leave RSM Legends?", isPresented: $confirmExit) {
            Button("Stay", role: .cancel) { }
            Button("Main Menu", role: .destructive) { onBack() }
        } message: {
            Text("Your Legends progress is saved. Are you sure you want to return to the main menu?")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RSM LEGENDS")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(LegendsPalette.navy)
                Text("COLLECT. BUILD. COMPETE.")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.blue)
            }

            Spacer(minLength: 8)
            resourceBar
        }
    }

    private var resourceBar: some View {
        HStack(spacing: isCompact ? 8 : 14) {
            LegendsMiniResource(icon: "dollarsign.circle.fill", value: "\(store.profile.coins)", label: "BALANCE", color: LegendsPalette.gold)
            LegendsMiniResource(icon: "cube.fill", value: "\(store.profile.packTokens)", label: "TOKENS", color: LegendsPalette.green)
            LegendsMiniResource(icon: "star.fill", value: ratingText, label: "RATING", color: LegendsPalette.blue)
            LegendsMiniResource(icon: "trophy.fill", value: divisionShortName, label: "DIVISION", color: LegendsPalette.purple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: LegendsPalette.navy.opacity(0.12), radius: 12, y: 5)
    }

    private var seasonReviewBanner: some View {
        let entries = store.profile.lastSeasonReview.values.sorted { $0.playerName < $1.playerName }
        return LegendsDashboardPanel(title: "SEASON DEVELOPMENT REVIEW", icon: "chart.line.uptrend.xyaxis", color: LegendsPalette.blue) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entries, id: \.cardID) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(entry.playerName)
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundStyle(LegendsPalette.navy)
                                        .lineLimit(1)
                                    Text(entry.overallDelta >= 0 ? "+\(entry.overallDelta)" : "\(entry.overallDelta)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundStyle(entry.overallDelta > 0 ? LegendsPalette.green : (entry.overallDelta < 0 ? LegendsPalette.orange : LegendsPalette.navy.opacity(0.5)))
                                }
                                Text(entry.reason)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                                    .lineLimit(2)
                                    .frame(width: 150, alignment: .leading)
                            }
                            .padding(8)
                            .background(LegendsPalette.blueWash)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
                Button {
                    Haptics.tap()
                    store.profile.lastSeasonReview = [:]
                    store.persist()
                } label: {
                    Text("DISMISS REVIEW")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.blue)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var hero: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Image("StadiumBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(colors: [LegendsPalette.navy.opacity(0.82), LegendsPalette.navy.opacity(0.32), .clear],
                               startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, LegendsPalette.contentBackground.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom)

                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 12) {
                            CrestView(shortName: store.profile.crestShort, size: isCompact ? 52 : 66, color: crestColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("RSM")
                                    .font(.system(size: isCompact ? 18 : 24, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("LEGENDS")
                                    .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
                                    .foregroundStyle(LegendsPalette.green)
                            }
                        }

                        Text(store.profile.clubName.uppercased())
                            .font(.system(size: isCompact ? 11 : 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)

                        Text("MANAGER LEVEL \(store.profile.managerLevel)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.gold)

                        LegendsProgressBar(value: managerProgress, tint: LegendsPalette.green, height: 8)
                            .frame(maxWidth: isCompact ? 190 : 250)
                        Text("\(store.profile.managerXP) / \(managerThreshold) XP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(.leading, 20)

                    Spacer(minLength: 0)
                    if !isCompact || geo.size.width > 500 {
                        LegendsHeroPlayers()
                            .frame(width: min(310, geo.size.width * 0.42), height: geo.size.height)
                            .padding(.trailing, 12)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.36), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.18), radius: 14, y: 7)
        }
        .frame(height: isCompact ? 194 : 236)
    }

    private var resourceSummary: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4), spacing: 12) {
            LegendsResourceCard(icon: "dollarsign.circle.fill", value: "\(store.profile.coins)", label: "BALANCE", color: LegendsPalette.gold, background: LegendsPalette.goldWash)
            LegendsResourceCard(icon: "cube.fill", value: "\(store.profile.packTokens)", label: "TOKENS", color: LegendsPalette.green, background: LegendsPalette.greenWash)
            LegendsResourceCard(icon: "star.fill", value: ratingText, label: "TEAM RATING", color: LegendsPalette.blue, background: LegendsPalette.blueWash)
            LegendsResourceCard(icon: "trophy.fill", value: divisionShortName, label: "DIVISION", color: LegendsPalette.purple, background: LegendsPalette.purpleWash)
        }
    }

    private var featureGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 3), spacing: 12) {
            LegendsFeatureCard(title: "PLAY MATCH", subtitle: divisionShortName, icon: "soccerball", color: LegendsPalette.green, style: .pitch) {
                selectedNav = .home
                screen = .match
            }
            LegendsFeatureCard(title: "SQUAD", subtitle: "RATING \(ratingText)", icon: "person.3.fill", color: LegendsPalette.blue, style: .players) {
                handleNavigation(.squad)
            }
            LegendsFeatureCard(title: "PACKS", subtitle: "\(availablePackCount) AVAILABLE", icon: "shippingbox.fill", color: LegendsPalette.purple, style: .pack) {
                handleNavigation(.packs)
            }
            LegendsFeatureCard(title: "COLLECTION", subtitle: "\(store.profile.ownedCardIDs.count) / \(LegendsCardDatabase.all.count)", icon: "square.stack.3d.up.fill", color: LegendsPalette.orange, style: .cards) {
                handleNavigation(.collection)
            }
            LegendsFeatureCard(title: "CHALLENGES", subtitle: "\(activeChallengeCount) ACTIVE", icon: "shield.lefthalf.filled", color: LegendsPalette.cyan, style: .shield) {
                handleNavigation(.challenges)
            }
            LegendsFeatureCard(title: "CLUB", subtitle: "STADIUM & STAFF", icon: "building.columns.fill", color: LegendsPalette.blue, style: .stadium) {
                handleNavigation(.club)
            }
        }
    }

    private var divisionPodium: some View {
        let topThree = Array(store.divisionStandings().prefix(3))
        return LegendsDashboardPanel(title: "DIVISION PODIUM", icon: "trophy.fill", color: LegendsPalette.gold) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(topThree.enumerated()), id: \.element.id) { index, club in
                    VStack(spacing: 4) {
                        Text(index == 0 ? "1ST" : index == 1 ? "2ND" : "3RD")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(index == 0 ? LegendsPalette.goldDeep : LegendsPalette.navy.opacity(0.55))
                        Text(club.name)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(LegendsPalette.navy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("\(club.points) PTS")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                        Rectangle()
                            .fill(index == 0 ? LegendsPalette.gold : index == 1 ? LegendsPalette.blue : LegendsPalette.orange)
                            .frame(height: index == 0 ? 48 : index == 1 ? 34 : 26)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var bottomPanels: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                dailyObjective
                seasonProgress
                promoBanner
            }
            VStack(spacing: 12) {
                dailyObjective
                seasonProgress
                promoBanner
            }
        }
    }

    private var dailyObjective: some View {
        let challenge = dailyChallenge
        return LegendsDashboardPanel(title: "DAILY OBJECTIVE", icon: "gift.fill", color: LegendsPalette.green) {
            if let challenge {
                Text(challenge.title.uppercased())
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(LegendsPalette.navy)
                    .lineLimit(1)
                Text(challenge.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.68))
                    .lineLimit(2)
                HStack {
                    LegendsProgressBar(value: store.progress(for: challenge), tint: LegendsPalette.green, height: 8)
                    Text(progressText(for: challenge))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                }
                Text("REWARD  \(challenge.coinReward) BALANCE\(challenge.tokenReward > 0 ? " + \(challenge.tokenReward) TOKEN" : "")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.goldDeep)
            } else {
                Text("ALL DAILY OBJECTIVES COMPLETE")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(LegendsPalette.navy)
                Text("Check back tomorrow for a fresh challenge.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.68))
            }
        }
    }

    private var seasonProgress: some View {
        LegendsDashboardPanel(title: "SEASON PROGRESS", icon: "shield.fill", color: LegendsPalette.blue) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(store.profile.currentSeason)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(LegendsPalette.blue)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 7) {
                    Text("SEASON \(store.profile.currentSeason)")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(LegendsPalette.navy)
                    LegendsProgressBar(value: seasonProgressValue, tint: LegendsPalette.blue, height: 8)
                    Text("\(store.profile.matchesPlayedThisSeason) / \(LegendsStore.matchesPerSeason) MATCHES TO NEXT SEASON")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.68))
                }
            }
            Text("NEXT MILESTONE  \(store.profile.division.displayName.uppercased())")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.blue)
        }
    }

    private var promoBanner: some View {
        LegendsDashboardPanel(title: "RSM LEGENDS", icon: "sparkles", color: LegendsPalette.purple) {
            ZStack(alignment: .leading) {
                LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.blue], startPoint: .leading, endPoint: .trailing)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEGENDS")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("ARE MADE")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(LegendsPalette.green)
                        Text("BUILD YOUR STORY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    Image(systemName: "figure.soccer")
                        .font(.system(size: 62, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(14)
            }
            .frame(minHeight: 104)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 5) {
                Circle().fill(LegendsPalette.green).frame(width: 6, height: 6)
                Circle().fill(LegendsPalette.navy.opacity(0.2)).frame(width: 6, height: 6)
                Circle().fill(LegendsPalette.navy.opacity(0.2)).frame(width: 6, height: 6)
            }
        }
    }

    private var ratingText: String {
        store.currentTeamRating > 0 ? "\(store.currentTeamRating)" : "--"
    }

    private var divisionShortName: String {
        store.profile.division == .worldLeague ? "WORLD" : "DIV \(store.profile.division.rawValue)"
    }

    private var managerThreshold: Int { max(1, store.profile.managerLevel * 100) }
    private var managerProgress: Double { min(1, max(0, Double(store.profile.managerXP) / Double(managerThreshold))) }
    private var seasonProgressValue: Double { min(1, max(0, Double(store.profile.matchesPlayedThisSeason) / Double(LegendsStore.matchesPerSeason))) }
    private var availablePackCount: Int { LegendsPackDatabase.all.count }
    private var activeChallengeCount: Int { LegendsChallengeDatabase.all.filter { !store.isCompleted($0) }.count }
    private var dailyChallenge: LegendsChallenge? {
        LegendsChallengeDatabase.all.first { $0.cadence == .daily && !store.isCompleted($0) }
    }

    private func progressText(for challenge: LegendsChallenge) -> String {
        switch challenge.kind {
        case .playMatchesToday: return "\(store.profile.matchesToday) / 1"
        case .winMatchesToday: return "\(store.profile.winsToday) / 1"
        default: return store.isCompleted(challenge) ? "DONE" : "IN PROGRESS"
        }
    }

    private func navigateFromDestination(_ item: LegendsNavItem, current: LegendsNavItem) {
        // The active Club tab is also the route back from Managers/Stadiums
        // to the Club hub, so same-tab taps are meaningful in submenus.
        handleNavigation(item)
    }

    private func requestExit() {
        confirmExit = true
    }

    private func handleNavigation(_ item: LegendsNavItem) {
        selectedNav = item
        Haptics.tap()
        switch item {
        case .home: screen = nil
        case .squad: screen = .squad
        case .training: screen = .training
        case .packs: screen = .packs
        case .collection: screen = .collection
        case .challenges: screen = .challenges
        case .table: screen = .table
        case .club: screen = .club
        case .hall: screen = .hall
        case .profile: screen = .profile
        case .settings: screen = .settings
        case .planning: screen = .planning
        case .reports: screen = .reports
        }
    }
}

enum LegendsPalette {
    static let navy = Color(red: 0.027, green: 0.118, blue: 0.255)
    static let green = Color(red: 0.259, green: 0.761, blue: 0.102)
    static let blue = Color(red: 0.071, green: 0.404, blue: 0.910)
    static let purple = Color(red: 0.518, green: 0.169, blue: 0.910)
    static let gold = Color(red: 0.961, green: 0.722, blue: 0.000)
    static let goldDeep = Color(red: 0.690, green: 0.420, blue: 0.000)
    static let orange = Color(red: 0.961, green: 0.541, blue: 0.000)
    static let cyan = Color(red: 0.020, green: 0.686, blue: 0.812)
    static let contentBackground = Color(red: 0.953, green: 0.969, blue: 0.985)
    static let greenWash = Color(red: 0.890, green: 0.970, blue: 0.830)
    static let blueWash = Color(red: 0.870, green: 0.925, blue: 1.000)
    static let goldWash = Color(red: 1.000, green: 0.957, blue: 0.820)
    static let purpleWash = Color(red: 0.940, green: 0.880, blue: 1.000)
}

/// Shared presentation shell for every RSM Legends destination screen.
/// It keeps the home screen's navy, green, blue and light-surface language
/// visible while each destination retains its own feature content.
struct LegendsMenuShell<Content: View>: View {
    let store: LegendsStore
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let onBack: () -> Void
    let currentNav: LegendsNavItem
    let onNavigate: ((LegendsNavItem) -> Void)?
    let scrollContent: Bool
    let centerContent: Bool
    var squadPresentation = false
    @ViewBuilder let content: () -> Content

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compactHeight: Bool { verticalSizeClass == .compact }

    init(store: LegendsStore, title: String, subtitle: String = "RSM LEGENDS", icon: String,
         accent: Color, onBack: @escaping () -> Void, currentNav: LegendsNavItem = .home,
         onNavigate: ((LegendsNavItem) -> Void)? = nil, scrollContent: Bool = true, centerContent: Bool = false, squadPresentation: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.store = store
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.onBack = onBack
        self.currentNav = currentNav
        self.onNavigate = onNavigate
        self.scrollContent = scrollContent
        self.centerContent = centerContent
        self.squadPresentation = squadPresentation
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                (squadPresentation ? LegendsPalette.navy : LegendsPalette.contentBackground).ignoresSafeArea()
                HStack(spacing: 0) {
                    LegendsSidebar(selected: .constant(currentNav), compact: geo.size.width < 700) { item in
                        onNavigate?(item)
                    } onBack: {
                        onBack()
                    }

                    VStack(spacing: 0) {
                        header
                        if scrollContent {
                            if centerContent {
                                GeometryReader { contentGeo in
                                    ScrollView(showsIndicators: false) {
                                        content()
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 18)
                                            .frame(maxWidth: .infinity, minHeight: contentGeo.size.height, alignment: .center)
                                    }
                                    .frame(width: contentGeo.size.width, height: contentGeo.size.height)
                                }
                            } else {
                                ScrollView(showsIndicators: false) {
                                    content()
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 18)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            content()
                                .padding(.horizontal, squadPresentation ? 8 : 18)
                                .padding(.vertical, squadPresentation ? 6 : 18)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var header: some View {
        VStack(spacing: compactHeight ? 8 : 12) {
            HStack(spacing: compactHeight ? 8 : 12) {
                Image(systemName: icon)
                    .font(.system(size: compactHeight ? 17 : 20, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: compactHeight ? 32 : 38, height: compactHeight ? 32 : 38)
                    .background(accent.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: compactHeight ? 8 : 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: compactHeight ? 16 : 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        // Lets XCUITest assert which destination is actually
                        // on screen after a sidebar tap. Lives on a real
                        // element no destination overrides.
                        .accessibilityIdentifier("legends.shell.\(currentNav.rawValue.lowercased())")
                    Text(subtitle.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: compactHeight ? 4 : 8)
                resourceSummary
            }
            .padding(.horizontal, compactHeight ? 12 : 16)
            .padding(.top, compactHeight ? 8 : 12)
            .padding(.bottom, compactHeight ? 8 : 14)
        }
        .background(
            LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.blue.opacity(0.92)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .shadow(color: LegendsPalette.navy.opacity(0.2), radius: 10, y: 5)
    }

    private var resourceSummary: some View {
        HStack(spacing: compactHeight ? 6 : 8) {
            LegendsMiniResource(icon: "dollarsign.circle.fill", value: "\(store.profile.coins)", label: "BALANCE", color: LegendsPalette.gold)
            LegendsMiniResource(icon: "cube.fill", value: "\(store.profile.packTokens)", label: "TOKENS", color: LegendsPalette.green)
            LegendsMiniResource(icon: "star.fill", value: store.currentTeamRating > 0 ? "\(store.currentTeamRating)" : "--", label: "RATING", color: LegendsPalette.blue)
        }
        .padding(.horizontal, compactHeight ? 7 : 9)
        .padding(.vertical, compactHeight ? 5 : 7)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LegendsSidebar: View {
    @Binding var selected: LegendsNavItem
    let compact: Bool
    let onSelect: (LegendsNavItem) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button {
                onBack()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Switch mode")
            .buttonStyle(PressableButtonStyle())

            Rectangle().fill(.white.opacity(0.18)).frame(height: 1).padding(.horizontal, 12)

            // The item list scrolls so every tab stays reachable on short
            // landscape screens instead of clipping the bottom entries.
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(LegendsNavItem.allCases) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                VStack(spacing: 3) {
                                    LegendsNavIcon(item: item, size: compact ? 17 : 21)
                                    Text(item.rawValue)
                                        .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .foregroundStyle(selected == item ? .white : .white.opacity(0.68))
                                .frame(maxWidth: .infinity, minHeight: compact ? 40 : 52)
                                .background(selected == item ? LegendsPalette.green : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .id(item.id)
                            .accessibilityLabel(item.rawValue.capitalized)
                            .accessibilityIdentifier("legends.nav.\(item.rawValue.lowercased())")
                            .accessibilityAddTraits(selected == item ? [.isSelected] : [])
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.bottom, 8)
                }
                .onAppear {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
                .onChange(of: selected) { _, item in
                    proxy.scrollTo(item.id, anchor: .center)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 8)
        .frame(width: compact ? 72 : 88)
        .background(LegendsPalette.navy)
        .shadow(color: LegendsPalette.navy.opacity(0.22), radius: 10, x: 4)
    }
}

struct LegendsNavIcon: View {
    let item: LegendsNavItem
    let size: CGFloat

    var body: some View {
        ZStack {
            switch item {
            case .squad:
                // A team jersey: torso, angled sleeves and squad number.
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.26)
                        .fill(.white.opacity(0.95))
                        .frame(width: size * 0.78, height: size * 0.84)
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: size * 0.09)
                            .fill(.white.opacity(0.95))
                            .frame(width: size * 0.30, height: size * 0.26)
                            .rotationEffect(.degrees(40))
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: size * 0.09)
                            .fill(.white.opacity(0.95))
                            .frame(width: size * 0.30, height: size * 0.26)
                            .rotationEffect(.degrees(-40))
                    }
                    .frame(width: size * 1.0)
                    .offset(y: -size * 0.26)
                    Text("10")
                        .font(.system(size: size * 0.40, weight: .black, design: .rounded))
                        .foregroundStyle(LegendsPalette.navy)
                }
            case .packs:
                LegendsPackArtwork(compact: true)
            case .challenges:
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.95)).frame(width: size * 0.82, height: size)
                    Image(systemName: "star.fill").font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(LegendsPalette.cyan)
                    Image(systemName: "checkmark").font(.system(size: size * 0.28, weight: .black)).foregroundStyle(LegendsPalette.navy)
                }
            case .collection:
                // A collectible player card with a star-rating badge.
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.55))
                        .frame(width: size * 0.64, height: size * 0.82)
                        .rotationEffect(.degrees(-14))
                        .offset(x: -size * 0.22, y: -size * 0.05)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.75))
                        .frame(width: size * 0.64, height: size * 0.82)
                        .rotationEffect(.degrees(14))
                        .offset(x: size * 0.22, y: -size * 0.05)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.95))
                        .frame(width: size * 0.68, height: size * 0.86)
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(LegendsPalette.navy)
                        .offset(y: size * 0.02)
                    Image(systemName: "star.fill")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundStyle(LegendsPalette.orange)
                        .offset(x: size * 0.30, y: -size * 0.32)
                }
            default:
                Image(systemName: item.icon).font(.system(size: size, weight: .semibold))
            }
        }
        .frame(width: size * 1.25, height: size * 1.25)
    }
}

struct LegendsPackArtwork: View {
    var pack: LegendsPack? = nil
    var compact: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        Group {
            if let pack {
                Image(pack.artworkAssetName)
                    .resizable()
                    .scaledToFit()
                    .saturation(isEnabled ? 1 : 0.15)
                    .opacity(isEnabled ? 1 : 0.42)
                    .shadow(color: LegendsPalette.navy.opacity(isEnabled ? 0.24 : 0.08), radius: compact ? 2 : 8, y: compact ? 1 : 5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 4 : 9)
                        .fill(LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: compact ? 18 : 68, height: compact ? 22 : 86)
                        .overlay(RoundedRectangle(cornerRadius: compact ? 4 : 9).stroke(.white.opacity(0.9), lineWidth: compact ? 1 : 2))
                        .rotationEffect(.degrees(-7))
                    VStack(spacing: compact ? 1 : 4) {
                        Text("RSM")
                            .font(.system(size: compact ? 5 : 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Rectangle().fill(LegendsPalette.green).frame(width: compact ? 11 : 38, height: compact ? 1 : 3)
                        Image(systemName: "sparkles")
                            .font(.system(size: compact ? 6 : 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .rotationEffect(.degrees(-7))
                }
            }
        }
        .frame(width: compact ? 26 : 88, height: compact ? 32 : 112)
        .accessibilityHidden(true)
    }
}

struct LegendsMiniResource: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: icon).font(.system(size: compact ? 11 : 13, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: compact ? 11 : 12, weight: .black, design: .rounded)).foregroundStyle(LegendsPalette.navy).lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.55)).lineLimit(1)
        }
        .frame(minWidth: compact ? 32 : 42)
    }
}

struct LegendsResourceCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let background: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.75))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(LegendsPalette.navy).lineLimit(1).minimumScaleFactor(0.65)
                Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.62))
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(minHeight: 78)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
    }
}

struct LegendsProgressBar: View {
    let value: Double
    let tint: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LegendsPalette.navy.opacity(0.13))
                Capsule().fill(tint).frame(width: geo.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
    }
}

struct LegendsHeroPlayers: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: -16) {
            LegendsHeroPlayer(number: "10", color: LegendsPalette.blue, scale: 0.82)
            LegendsHeroPlayer(number: "7", color: LegendsPalette.green, scale: 1.0)
            LegendsHeroPlayer(number: "11", color: LegendsPalette.purple, scale: 0.88)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

struct LegendsHeroPlayer: View {
    let number: String
    let color: Color
    let scale: CGFloat

    var body: some View {
        VStack(spacing: -2) {
            Circle().fill(LegendsPalette.navy.opacity(0.9)).frame(width: 44 * scale, height: 44 * scale)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.92)).frame(width: 78 * scale, height: 112 * scale)
                VStack(spacing: 2) {
                    Rectangle().fill(color).frame(width: 60 * scale, height: 4)
                    Text(number).font(.system(size: 24 * scale, weight: .black, design: .rounded)).foregroundStyle(color)
                    Text("RSM").font(.system(size: 7 * scale, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .shadow(color: LegendsPalette.navy.opacity(0.3), radius: 5, y: 3)
    }
}

enum LegendsFeatureStyle {
    case pitch, players, pack, cards, shield, stadium

    var symbol: String {
        switch self {
        case .pitch: return "soccerball"
        case .players: return "person.3.fill"
        case .pack: return "shippingbox.fill"
        case .cards: return "square.stack.3d.up.fill"
        case .shield: return "shield.lefthalf.filled"
        case .stadium: return "building.columns.fill"
        }
    }
}

struct LegendsFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let style: LegendsFeatureStyle
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [color, LegendsPalette.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.08)).frame(width: 150, height: 150).offset(x: 70, y: -30)
                Image(systemName: style.symbol == icon ? icon : style.symbol)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(13)
                LinearGradient(colors: [.clear, LegendsPalette.navy.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(color)
                            .frame(width: 30, height: 30)
                            .background(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(13)
            }
            .aspectRatio(1.55, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.55), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.14), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct LegendsDashboardPanel<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
                Text(title).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.22), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
    }
}

struct LegendsDivisionTableView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    let onBack: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        LegendsMenuShell(store: store, title: "DIVISION TABLE", subtitle: store.profile.division.displayName,
                         icon: "trophy.fill", accent: LegendsPalette.gold, onBack: onBack,
                         currentNav: .table, onNavigate: onNavigate) {
            GeometryReader { geo in
                let wide = geo.size.width >= 860
                Group {
                    if wide {
                        // League table as the main panel, fixture centre beside it.
                        HStack(alignment: .top, spacing: 14) {
                            leagueTablePanel
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 12) {
                                seasonContextPanel
                                fixtureCentre
                            }
                            .frame(width: 330)
                        }
                    } else {
                        VStack(spacing: 12) {
                            seasonContextPanel
                            fixtureCentre
                            leagueTablePanel
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(minHeight: wideMinHeight, alignment: .top)
        }
    }

    // On compact heights (landscape iPhones) the shell's ScrollView provides
    // scrolling; the next fixture still anchors to the top so it's visible
    // without scrolling. On regular heights, fill the panel vertically so
    // upcoming/results get room to breathe.
    private var wideMinHeight: CGFloat { compactHeight ? 0 : 560 }

    // MARK: - League table

    private var leagueTablePanel: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Array(store.divisionStandings().enumerated()), id: \.element.id) { index, club in
                tableRow(index: index, club: club)
            }
            zoneKey
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.gold.opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.division.table")
    }

    private var tableHeader: some View {
        HStack(spacing: 6) {
            Text("POS").frame(width: 26, alignment: .leading)
            Text("CLUB").frame(maxWidth: .infinity, alignment: .leading)
            Text("P").frame(width: 22)
            Text("W").frame(width: 22)
            Text("D").frame(width: 22)
            Text("L").frame(width: 22)
            Text("GD").frame(width: 32)
            Text("PTS").frame(width: 36)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(LegendsPalette.contentBackground)
    }

    private func tableRow(index: Int, club: LegendsDivisionRecord) -> some View {
        let isUser = club.id == store.profile.clubName
        let zone = store.divisionZone(forRank: index + 1, totalTeams: store.divisionStandings().count)
        return HStack(spacing: 6) {
            // Zone marker: colour plus shape, so the meaning is never
            // colour-alone (the key text spells it out too).
            RoundedRectangle(cornerRadius: 2)
                .fill(zoneColor(zone))
                .frame(width: 4, height: 18)
                .accessibilityHidden(true)
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(isUser ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.72))
                .frame(width: 22, alignment: .leading)
            Text(club.name)
                .font(.system(size: 11, weight: isUser ? .black : .bold, design: .rounded))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(club.played)").frame(width: 22)
            Text("\(club.won)").frame(width: 22)
            Text("\(club.drawn)").frame(width: 22)
            Text("\(club.lost)").frame(width: 22)
            Text(club.goalDifference > 0 ? "+\(club.goalDifference)" : "\(club.goalDifference)").frame(width: 32)
            Text("\(club.points)")
                .font(.system(size: 11, weight: isUser ? .black : .bold, design: .monospaced))
                .frame(width: 36)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(LegendsPalette.navy.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(isUser ? LegendsPalette.greenWash : .white)
        .overlay(alignment: .leading) {
            if isUser {
                Rectangle().fill(LegendsPalette.green).frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(LegendsPalette.navy.opacity(0.06)).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(isUser ? "legends.division.userRow" : "legends.division.row.\(club.id)")
        .accessibilityLabel(accessibilityText(index: index, club: club, zone: zone))
    }

    private func zoneColor(_ zone: LegendsDivisionZone) -> Color {
        switch zone {
        case .promotion: return LegendsPalette.green
        case .relegation: return LegendsPalette.orange
        case .none: return LegendsPalette.navy.opacity(0.14)
        }
    }

    private func accessibilityText(index: Int, club: LegendsDivisionRecord, zone: LegendsDivisionZone) -> String {
        var text = "Position \(index + 1), \(club.name), \(club.played) played, " +
            "\(club.won) won, \(club.drawn) drawn, \(club.lost) lost, " +
            "goal difference \(club.goalDifference), \(club.points) points"
        if club.id == store.profile.clubName { text += ". Your club" }
        switch zone {
        case .promotion: text += ". Promotion zone"
        case .relegation: text += ". Relegation zone"
        case .none: break
        }
        return text
    }

    /// Restrained key explaining the zone colours in words.
    private var zoneKey: some View {
        HStack(spacing: 12) {
            if store.profile.division != .worldLeague {
                keyDot(color: LegendsPalette.green, text: "Promotion")
            }
            if store.profile.division != .division10 {
                keyDot(color: LegendsPalette.orange, text: "Relegation")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(LegendsPalette.contentBackground.opacity(0.6))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.division.zoneKey")
    }

    private func keyDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text) positions are marked in \(text == "Promotion" ? "green" : "orange")")
    }

    // MARK: - Season context

    private var seasonContextPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("SEASON \(store.profile.divisionSeason)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                Spacer()
                Text("\(store.divisionMatchesPlayed) / \(store.divisionMatchCount) PLAYED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.blue)
            }
            Text(statusLine)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.66))
                .lineLimit(2)
            if let result = store.profile.lastDivisionSeasonResult {
                Divider()
                seasonResultRow(result)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LegendsPalette.gold.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.division.seasonContext")
    }

    private var statusLine: String {
        let standings = store.divisionStandings()
        let total = standings.count
        let rank = (standings.firstIndex { $0.id == store.profile.clubName } ?? 0) + 1
        switch store.divisionZone(forRank: rank, totalTeams: total) {
        case .promotion: return "PROMOTION ZONE — WIN AND YOU GO UP."
        case .relegation: return "RELEGATION ZONE — EVERY POINT COUNTS."
        case .none:
            let pressure = Int((store.divisionPressure * 100).rounded())
            return "MID-TABLE · SEASON PRESSURE \(pressure)%"
        }
    }

    private func seasonResultRow(_ result: LegendsDivisionSeasonResult) -> some View {
        let promoted = result.outcome != .relegated
        return HStack(spacing: 8) {
            Image(systemName: promoted ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(promoted ? LegendsPalette.green : LegendsPalette.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("SEASON \(result.season) · \(result.outcome.displayName)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                Text("Finished \(result.finalRank)/\(result.totalTeams)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.66))
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fixture centre

    private var fixtureCentre: some View {
        let view = store.userDivisionFixtureView()
        return VStack(spacing: 10) {
            if let next = view.nextFixture {
                nextFixtureCard(next)
            }
            upcomingSection(view.upcoming, resultCount: view.recentResults.count)
            resultsSection(view.recentResults)
        }
    }

    private func nextFixtureCard(_ fixture: LegendsFixture) -> some View {
        let isHome = fixture.homeTeamID == store.profile.clubName
        let opponent = isHome ? fixture.awayTeamID : fixture.homeTeamID
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("NEXT")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LegendsPalette.green)
                    .clipShape(Capsule())
                Spacer()
                Text("ROUND \(fixture.round)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.62))
            }
            Text(opponent)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(isHome ? "HOME" : "AWAY") FIXTURE · \(store.profile.division.displayName.uppercased())")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(isHome ? LegendsPalette.blue : LegendsPalette.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LegendsPalette.greenWash)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LegendsPalette.green.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.division.nextFixture")
        .accessibilityLabel("Next fixture: round \(fixture.round), \(isHome ? "home" : "away") against \(opponent)")
    }

    private func upcomingSection(_ upcoming: [LegendsFixture], resultCount: Int) -> some View {
        let following = upcoming.dropFirst().prefix(4)
        return LegendsDashboardPanel(title: "UPCOMING", icon: "calendar", color: LegendsPalette.blue) {
            if following.isEmpty {
                Text(resultCount > 0 ? "Season complete — every fixture played."
                                     : "Your season opener is up next.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.66))
            } else {
                ForEach(Array(following), id: \.id) { fixture in
                    upcomingRow(fixture)
                }
            }
        }
        .accessibilityIdentifier("legends.division.upcoming")
    }

    private func upcomingRow(_ fixture: LegendsFixture) -> some View {
        let isHome = fixture.homeTeamID == store.profile.clubName
        let opponent = isHome ? fixture.awayTeamID : fixture.homeTeamID
        return HStack(spacing: 8) {
            Text("R\(fixture.round)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                .frame(width: 26, alignment: .leading)
            Text(isHome ? "H" : "A")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(isHome ? LegendsPalette.blue : LegendsPalette.orange)
                .frame(width: 12)
            Text(opponent)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(LegendsPalette.navy.opacity(0.06)).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Round \(fixture.round), \(isHome ? "home" : "away") against \(opponent)")
    }

    private func resultsSection(_ results: [LegendsFixture]) -> some View {
        LegendsDashboardPanel(title: "RECENT RESULTS", icon: "clock.arrow.circlepath", color: LegendsPalette.purple) {
            if results.isEmpty {
                Text("No matches played yet this season.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.66))
            } else {
                ForEach(results.prefix(5)) { fixture in
                    resultRow(fixture)
                }
            }
        }
        .accessibilityIdentifier("legends.division.results")
    }

    private func resultRow(_ fixture: LegendsFixture) -> some View {
        let isHome = fixture.homeTeamID == store.profile.clubName
        let opponent = isHome ? fixture.awayTeamID : fixture.homeTeamID
        let teamGoals = isHome ? (fixture.homeGoals ?? 0) : (fixture.awayGoals ?? 0)
        let opponentGoals = isHome ? (fixture.awayGoals ?? 0) : (fixture.homeGoals ?? 0)
        let outcome: LegendsMatchOutcome = teamGoals > opponentGoals ? .win : (teamGoals == opponentGoals ? .draw : .loss)
        let badge = outcome == .win ? "W" : (outcome == .draw ? "D" : "L")
        let badgeColor = outcome == .win ? LegendsPalette.green : (outcome == .draw ? LegendsPalette.blue : LegendsPalette.orange)
        return HStack(spacing: 8) {
            Text("R\(fixture.round)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                .frame(width: 26, alignment: .leading)
            Text(isHome ? "H" : "A")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(isHome ? LegendsPalette.blue : LegendsPalette.orange)
                .frame(width: 12)
            Text(opponent)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(teamGoals)-\(opponentGoals)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
            Text(badge)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(LegendsPalette.navy.opacity(0.06)).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Round \(fixture.round), \(isHome ? "home" : "away") against \(opponent), \(teamGoals)-\(opponentGoals), " +
                            (outcome == .win ? "won" : (outcome == .draw ? "drew" : "lost")))
    }    }

struct LegendsClubHubView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onOpenManagers: () -> Void
    var onOpenStadiums: () -> Void
    var onOpenFacilities: () -> Void
    let onBack: () -> Void

    var body: some View {
        LegendsMenuShell(store: store, title: "CLUB", subtitle: "STADIUM, STAFF & FACILITIES", icon: "building.columns.fill", accent: LegendsPalette.blue, onBack: onBack, currentNav: .club, onNavigate: onNavigate) {
            // Keep the Club tiles in a stable two-row layout. Unlike an adaptive
            // grid or ViewThatFits, this guarantees that the third destination is
            // materialized and reachable in iPad compatibility mode as well as
            // on compact landscape phones.
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    clubDestination(title: "ASSISTANTS", subtitle: "HIRE STAFF FOR THE SIDELINE", icon: "person.crop.rectangle.stack.fill", color: LegendsPalette.green,
                                    value: "\(store.profile.ownedManagerIDs.count) / \(LegendsManagerDatabase.all.count) OWNED", action: onOpenManagers)
                    clubDestination(title: "STADIUMS", subtitle: "GROW YOUR HOME ADVANTAGE", icon: "building.2.fill", color: LegendsPalette.blue,
                                    value: "\(store.profile.ownedStadiumIDs.count) / \(LegendsStadiumDatabase.all.count) OWNED", action: onOpenStadiums)
                }
                clubDestination(title: "FACILITIES", subtitle: "UPGRADE THE CLUB WITH BALANCE", icon: "building.2.crop.circle.fill", color: LegendsPalette.goldDeep,
                                value: "\(store.profile.coins) BALANCE", action: onOpenFacilities)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func clubDestination(title: String, subtitle: String, icon: String, color: Color, value: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [color, LegendsPalette.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: icon)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(14)
                LinearGradient(colors: [.clear, LegendsPalette.navy.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(value.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.gold)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 156)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.55), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.14), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.club.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}
