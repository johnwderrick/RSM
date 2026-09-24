//
//  HallOfFameView.swift
//  Retro Season Manager
//
//  The Hall of Fame building — every legend inducted (real career data,
//  see GameStore+CareerHistory.swift's evaluateForLegendStatus) displayed
//  as a framed portrait on the wall, plus the manager's own exhibit with
//  its trophy cabinet. Three exhibits: Club Legends, the Global Hall of
//  Fame (an extraordinary few), and the Legendary Manager exhibit.
//
//  Presented in the accepted Career light-card design language (pale
//  canvas, white cards, ink headings, green accents, gold reserved for
//  genuine emphasis, monospaced figures). The three exhibits share ONE
//  vertical scroll container: switching exhibits swaps content views
//  inside the same ScrollView identity, so nothing rebuilds and the
//  sheet never jumps unpredictably. Every value shown comes straight
//  from the authoritative GameStore career APIs — `clubLegends`,
//  `legendaryManagerProfile()`, `careerHonours` — nothing here
//  recalculates, reinterprets or stores anything; induction itself is
//  untouched in GameStore+CareerHistory.swift.
//
//  Presented both as a full sheet (from Settings' whole-building
//  treatment) and embedded by the Settings detail page — the close
//  control only exists in the sheet presentation, matching the Manager
//  Office's `showsClose` convention.
//
//  Stable `career.hall.*` identifiers support the focused UI tests.
//

import SwiftUI

struct HallOfFameView: View {
    let store: GameStore
    let showsClose: Bool

    init(store: GameStore, showsClose: Bool = true) {
        self.store = store
        self.showsClose = showsClose
    }

    @State private var tab: HallOfFameTab = .clubLegends
    @State private var selectedLegend: ClubLegend?
    @Environment(\.dismiss) private var dismiss

    enum HallOfFameTab: String, CaseIterable, Identifiable {
        case clubLegends = "CLUB LEGENDS"
        case global = "GLOBAL"
        case manager = "MANAGER"
        var id: String { rawValue }
    }

    /// Club legends only — Global inductees live in their own exhibit.
    /// Sorted by legend score, exactly as the wall hangs them.
    private var clubLegends: [ClubLegend] {
        store.clubLegends.filter { !$0.isGlobalLegend }.sorted { $0.legendScore > $1.legendScore }
    }
    private var globalLegends: [ClubLegend] {
        store.clubLegends.filter { $0.isGlobalLegend }.sorted { $0.legendScore > $1.legendScore }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabPicker
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch tab {
                        case .clubLegends: legendsSection(clubLegends, empty: "No club legends inducted yet — a long, decorated career at one club earns a place on the wall when a player retires.")
                        case .global:      legendsSection(globalLegends, empty: "The Global Hall of Fame is reserved for truly extraordinary careers. None have reached that bar yet.")
                        case .manager:     managerSection
                        }
                        endAnchor
                    }
                    .padding(14)
                    .padding(.trailing, 6) // breathing room around the floating close
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .accessibilityIdentifier(CareerIdentifiers.hallScroll)
            }

            // The Settings sheet presents this whole-building style; the
            // Settings detail page hosts it inside its own back-bar layout,
            // where the extra close control would duplicate the back bar.
            if showsClose {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                        .padding(12)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.hallClose)
                .accessibilityLabel("Close hall of fame")
            }
        }
        .font(.system(.body, design: .monospaced))
        .sheet(item: $selectedLegend) { legend in
            ClubLegendDetailSheet(legend: legend)
        }
    }

    // MARK: Header band

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("HALL OF FAME")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.clubLegends.count) legend\(store.clubLegends.count == 1 ? "" : "s") inducted · \(store.userClub.name)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.hallHeader)
        .accessibilityLabel("Hall of fame. \(store.clubLegends.count) legends inducted.")
    }

    // MARK: Exhibit switcher

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(HallOfFameTab.allCases) { candidate in
                hallTabButton(candidate)
            }
        }
        .padding(6)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Compact, always-3-across exhibit control — reads clearly on
    /// landscape phones where a system segmented control crowds its
    /// labels (the Manager Office tab pattern).
    private func hallTabButton(_ candidate: HallOfFameTab) -> some View {
        let selected = tab == candidate
        return Button {
            Haptics.tap()
            tab = candidate
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon(for: candidate))
                    .font(.system(size: 10, weight: .black))
                Text(candidate.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(selected ? CareerPalette.line : Color.clear)
            .foregroundStyle(selected ? Color.white : CareerPalette.mutedInk)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.hallTab(candidate.rawValue))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func icon(for tab: HallOfFameTab) -> String {
        switch tab {
        case .clubLegends: return "person.fill"
        case .global:      return "globe.europe.africa.fill"
        case .manager:     return "building.columns.fill"
        }
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.hallEnd(tab.rawValue))
    }

    // MARK: Legend wall

    @ViewBuilder
    private func legendsSection(_ legends: [ClubLegend], empty: String) -> some View {
        if legends.isEmpty {
            emptyState(empty)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(legends.enumerated()), id: \.element.id) { index, legend in
                    Button {
                        Haptics.tap()
                        selectedLegend = legend
                    } label: {
                        LegendPortraitCard(legend: legend)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.hallLegend(index))
                    .accessibilityLabel("\(legend.name). \(legend.isGlobalLegend ? "Global hall of fame inductee" : "Club legend"), \(legend.clubName). Opens the induction record.")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .accessibilityIdentifier(CareerIdentifiers.hallWall)
        }
    }

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "picture")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.45))
                .frame(height: 36)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.hallEmpty)
    }

    // MARK: Manager exhibit

    private var managerSection: some View {
        let profile = store.legendaryManagerProfile()
        return VStack(spacing: 12) {
            ManagerLegendCard(store: store, profile: profile)
            if !store.careerHonours.isEmpty {
                trophyCabinet
            }
        }
    }

    private var trophyCabinet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("TROPHY CABINET")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { index, honour in
                    VStack(spacing: 5) {
                        if let guess = TrophyKind.guess(from: honour) {
                            TrophyView(kind: guess.kind, tier: guess.tier, size: 36)
                        } else {
                            Image(systemName: "medal.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Retro.gold)
                                .frame(height: 36)
                        }
                        Text(honour)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(CareerIdentifiers.hallTrophy(index))
                    .accessibilityLabel(honour)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.gold.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.hallTrophyCabinet)
    }
}

/// One framed portrait on the Hall of Fame wall — a restrained bronze (or
/// gold for a Global inductee) frame around the player's procedural
/// portrait, with a name and club line beneath in the light-card
/// vocabulary. Global legends carry a small gold pill.
struct LegendPortraitCard: View {
    let legend: ClubLegend

    private var frameColor: Color {
        legend.isGlobalLegend ? Retro.gold : Retro.bronze
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(frameColor.opacity(0.22))
                    .frame(width: 78, height: 78)
                PlayerPortraitView(name: legend.name, position: legend.position, age: legend.finalAge, nation: legend.nationality, size: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(frameColor.opacity(0.55), lineWidth: legend.isGlobalLegend ? 2 : 1.5))
            .shadow(color: CareerPalette.ink.opacity(0.08), radius: 4, y: 2)

            Text(legend.name)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(legend.clubName)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .lineLimit(1)
            if legend.isGlobalLegend {
                Text("★ GLOBAL")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Retro.gold)
                    .clipShape(Capsule())
            }
        }
    }
}

/// The manager's own exhibit — no procedural portrait system exists for
/// the manager (only players), so this leans on the club crest and a
/// restrained gold rule for legendary status instead of a face. Every
/// figure comes from `legendaryManagerProfile()`.
struct ManagerLegendCard: View {
    let store: GameStore
    let profile: LegendaryManagerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                CrestView(shortName: store.userClub.shortName, size: 48, color: store.userColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.isLegendary ? "★ LEGENDARY MANAGER" : "MANAGERIAL CAREER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(profile.isLegendary ? CareerPalette.ink : CareerPalette.mutedInk)
                    Text("\(profile.totalSeasons) season\(profile.totalSeasons == 1 ? "" : "s") · \(profile.clubsManaged) club\(profile.clubsManaged == 1 ? "" : "s") managed")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                        .lineLimit(1)
                }
                Spacer()
                if profile.isLegendary {
                    Text("LEGENDARY")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Retro.gold)
                        .clipShape(Capsule())
                }
            }
            FlowStatGrid(stats: [
                ("WIN %", "\(profile.winPercentage)%"),
                ("WINS", "\(profile.totalWins)"),
                ("MATCHES", profile.totalMatches.formatted()),
                ("TROPHIES", "\(profile.totalTrophies)"),
                ("REPUTATION", "\(profile.reputation)"),
            ])
            if let longest = profile.longestSpell {
                HStack(spacing: 6) {
                    Text("LONGEST SPELL")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                    Text("\(longest.club) · \(longest.seasons) season\(longest.seasons == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Text(profile.biography)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.9))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if !profile.isLegendary {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(CareerPalette.canvas.opacity(0.8))
                            Capsule().fill(CareerPalette.line)
                                .frame(width: geo.size.width * CGFloat(min(1, Double(profile.legendScore) / Double(GameStore.legendaryManagerThreshold))))
                        }
                    }
                    .frame(height: 6)
                    Text("\(profile.legendScore) / \(GameStore.legendaryManagerThreshold) toward Legendary Manager status")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            profile.isLegendary ? Retro.gold.opacity(0.35) : CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.hallManagerCard)
        .accessibilityLabel("""
        Managerial career. \(profile.totalSeasons) seasons, \(profile.clubsManaged) clubs managed, \
        \(profile.winPercentage) percent win rate, \(profile.totalTrophies) trophies, \
        reputation \(profile.reputation). \(profile.isLegendary ? "Legendary manager." : "")
        """)
    }
}

/// The overview's figures as compact ink-on-white tiles — the same
/// primitive the Manager Office summary uses, shared visually rather than
/// duplicated as a file dependency (the office's version is `private` to
/// its file).
private struct FlowStatGrid: View {
    let stats: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.0)
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                    Text(stat.1)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(CareerPalette.canvas.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
    }
}

/// The full induction record for one legend — portrait, identity line,
/// career statistics, trophies won during their spell, and their
/// generated biography. Everything reads straight off the `ClubLegend`
/// the store inducted; nothing is recomputed or reinterpreted here.
struct ClubLegendDetailSheet: View {
    let legend: ClubLegend
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    identityCard
                    statsCard
                    if !legend.trophiesWon.isEmpty {
                        honoursCard
                    }
                    biographyCard
                    if legend.isGlobalLegend {
                        globalBanner
                    }
                }
                .padding(14)
                .padding(.trailing, 6) // breathing room around the floating close
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier(CareerIdentifiers.hallDetail(legend.name))

            // Pinned close — always reachable, sits above the scroll.
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                    .padding(12)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.hallDetailClose)
            .accessibilityLabel("Close legend record")
        }
        .font(.system(.body, design: .monospaced))
    }

    // MARK: Identity card

    private var identityCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((legend.isGlobalLegend ? Retro.gold : Retro.bronze).opacity(0.22))
                    .frame(width: 64, height: 64)
                PlayerPortraitView(name: legend.name, position: legend.position, age: legend.finalAge, nation: legend.nationality, size: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke((legend.isGlobalLegend ? Retro.gold : Retro.bronze).opacity(0.55), lineWidth: legend.isGlobalLegend ? 2 : 1.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(legend.name)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    FlagView(nationality: legend.nationality, width: 14)
                    Text("\(legend.nationality) · \(legend.position.rawValue) · \(legend.clubName)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text("\(legend.joinedSeason)–\(legend.retiredSeason) · \(legend.yearsAtClub) season\(legend.yearsAtClub == 1 ? "" : "s") at the club")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(legend.isGlobalLegend ? "★ GLOBAL" : "CLUB LEGEND")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(legend.isGlobalLegend ? CareerPalette.ink : CareerPalette.mutedInk)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(legend.isGlobalLegend ? Retro.gold : CareerPalette.canvas.opacity(0.8))
                    .clipShape(Capsule())
                Text("SCORE \(legend.legendScore)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }

    // MARK: Career statistics

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("CAREER STATISTICS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statTile("APPS", "\(legend.appearances)")
                statTile("GOALS", "\(legend.goals)")
                statTile("ASSISTS", "\(legend.assists)")
                statTile("CLEAN SHEETS", "\(legend.cleanSheets)")
                statTile("AVG RATING", String(format: "%.2f", legend.averageRating))
                statTile("PEAK OVR", "\(legend.peakRating)")
                statTile("CAPTAIN", "\(legend.seasonsAsCaptain) yr")
                statTile("MOTM", "\(legend.individualAwards)")
                statTile("LEGEND SCORE", "\(legend.legendScore)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.hallDetailStats)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(CareerPalette.canvas.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: Honours

    private var honoursCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("TROPHIES WON AT \(legend.clubName.uppercased())")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(legend.trophiesWon.enumerated()), id: \.offset) { index, trophy in
                    HStack(spacing: 10) {
                        if let guess = TrophyKind.guess(from: trophy) {
                            TrophyView(kind: guess.kind, tier: guess.tier, size: 22)
                        } else {
                            Image(systemName: "medal.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Retro.gold)
                                .frame(width: 22)
                        }
                        Text(trophy)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(CareerIdentifiers.hallDetailHonour(index))
                    .accessibilityLabel(trophy)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.gold.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.hallDetailHonours)
    }

    // MARK: Biography

    private var biographyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("BIOGRAPHY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            Text(legend.biography)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.9))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.hallDetailBiography)
    }

    private var globalBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 15, weight: .black))
            Text("GLOBAL HALL OF FAME INDUCTEE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
        }
        .foregroundStyle(CareerPalette.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Retro.gold.opacity(0.25))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.gold.opacity(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
