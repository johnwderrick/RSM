//
//  HallOfFameView.swift
//  Retro Season Manager
//
//  The Hall of Fame building — every legend inducted (real career data,
//  see GameStore+CareerHistory.swift's evaluateForLegendStatus) displayed
//  as a framed portrait on the wall, plus a trophy cabinet for the user's
//  own managerial career. Three rooms: Club Legends, the Global Hall of
//  Fame (an extraordinary few), and the Legendary Manager exhibit.
//

import SwiftUI

struct HallOfFameView: View {
    let store: GameStore
    @State private var tab: HallOfFameTab = .clubLegends
    @State private var selectedLegend: ClubLegend?

    enum HallOfFameTab: String, CaseIterable, Identifiable {
        case clubLegends = "CLUB LEGENDS"
        case global = "GLOBAL"
        case manager = "MANAGER"
        var id: String { rawValue }
    }

    private var clubLegends: [ClubLegend] {
        store.clubLegends.filter { !$0.isGlobalLegend }.sorted { $0.legendScore > $1.legendScore }
    }
    private var globalLegends: [ClubLegend] {
        store.clubLegends.filter { $0.isGlobalLegend }.sorted { $0.legendScore > $1.legendScore }
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            Picker("", selection: $tab) {
                ForEach(HallOfFameTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView {
                switch tab {
                case .clubLegends: legendsSection(clubLegends, empty: "No club legends inducted yet — a long, decorated career at one club earns a place on the wall when a player retires.")
                case .global:      legendsSection(globalLegends, empty: "The Global Hall of Fame is reserved for truly extraordinary careers. None have reached that bar yet.")
                case .manager:     managerSection
                }
            }
        }
        .padding()
        .sheet(item: $selectedLegend) { legend in
            ClubLegendDetailSheet(legend: legend)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("🏛 HALL OF FAME")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.gold)
                .shadow(color: Retro.gold.opacity(0.4), radius: 6)
            Text("\(store.clubLegends.count) legend\(store.clubLegends.count == 1 ? "" : "s") inducted")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
    }

    @ViewBuilder
    private func legendsSection(_ legends: [ClubLegend], empty: String) -> some View {
        if legends.isEmpty {
            VStack(spacing: 10) {
                Text("🖼")
                    .font(.system(size: 40))
                    .opacity(0.4)
                Text(empty)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(legends) { legend in
                    Button {
                        Haptics.tap()
                        selectedLegend = legend
                    } label: {
                        LegendPortraitCard(legend: legend)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private var managerSection: some View {
        let profile = store.legendaryManagerProfile()
        return VStack(spacing: 16) {
            ManagerLegendCard(store: store, profile: profile)
            if !store.careerHonours.isEmpty {
                Panel(title: "TROPHY CABINET") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { _, honour in
                            VStack(spacing: 6) {
                                let guess = TrophyKind.guess(from: honour)
                                TrophyView(kind: guess?.kind ?? .league, tier: guess?.tier ?? .bronze, size: 40)
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
    }
}

/// One framed portrait on the Hall of Fame wall — an ornate gold/bronze
/// frame (brighter, thicker for a Global legend) around the player's
/// procedural portrait, with a small brass-plaque-style name label.
struct LegendPortraitCard: View {
    let legend: ClubLegend

    private var frameColors: [Color] {
        legend.isGlobalLegend ? [Retro.gold, Color(red: 0.85, green: 0.65, blue: 0.15)] : [Retro.bronze, Retro.bronze.opacity(0.6)]
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: frameColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 78, height: 78)
                PlayerPortraitView(name: legend.name, position: legend.position, age: legend.finalAge, nation: legend.nationality, size: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: frameColors[0].opacity(0.5), radius: legend.isGlobalLegend ? 8 : 4, y: 2)

            Text(legend.name)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(legend.clubName)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
                .lineLimit(1)
            if legend.isGlobalLegend {
                Text("★ GLOBAL")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Retro.gold)
                    .clipShape(Capsule())
            }
        }
    }
}

/// The manager's own exhibit — no procedural portrait system exists for
/// the manager (only players), so this leans on the club crest and
/// trophy-style presentation instead of a face.
struct ManagerLegendCard: View {
    let store: GameStore
    let profile: LegendaryManagerProfile

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                CrestView(shortName: store.userClub.shortName, size: 56, color: store.userColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.isLegendary ? "★ LEGENDARY MANAGER" : "MANAGERIAL CAREER")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(profile.isLegendary ? Retro.gold : Retro.accent)
                    Text("\(profile.totalSeasons) season\(profile.totalSeasons == 1 ? "" : "s") · \(profile.clubsManaged) club\(profile.clubsManaged == 1 ? "" : "s")")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }
                Spacer()
            }
            Divider().overlay(Retro.accent.opacity(0.2))
            VStack(alignment: .leading, spacing: 6) {
                statRow("Win rate", "\(profile.winPercentage)% (\(profile.totalWins)/\(profile.totalMatches))")
                statRow("Trophies won", "\(profile.totalTrophies)")
                statRow("Reputation", "\(profile.reputation)")
                if let longest = profile.longestSpell {
                    statRow("Longest spell", "\(longest.club) (\(longest.seasons) season\(longest.seasons == 1 ? "" : "s"))")
                }
            }
            Text(profile.biography)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            if !profile.isLegendary {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Retro.text.opacity(0.15))
                            Capsule().fill(Retro.accent)
                                .frame(width: geo.size.width * CGFloat(min(1, Double(profile.legendScore) / Double(GameStore.legendaryManagerThreshold))))
                        }
                    }
                    .frame(height: 6)
                    Text("\(profile.legendScore) / \(GameStore.legendaryManagerThreshold) toward Legendary Manager status")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.78)], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke((profile.isLegendary ? Retro.gold : Retro.accent).opacity(0.3), lineWidth: 1))
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
        }
    }
}

/// The full induction record for one legend — portrait, career timeline,
/// statistics, trophies won during their spell, and their generated
/// biography.
struct ClubLegendDetailSheet: View {
    let legend: ClubLegend
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Retro.text.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    LegendPortraitCard(legend: legend)
                        .scaleEffect(1.6)
                        .padding(.top, 4)
                        .padding(.bottom, 10)

                    VStack(spacing: 4) {
                        Text(legend.name)
                            .font(.system(.title2, design: .monospaced).bold())
                            .foregroundStyle(legend.isGlobalLegend ? Retro.gold : Retro.text)
                        HStack(spacing: 5) {
                            FlagView(nationality: legend.nationality, width: 16)
                            Text("\(legend.nationality) · \(legend.position.rawValue) · \(legend.clubName)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.75))
                        }
                        Text("\(legend.joinedSeason)–\(legend.retiredSeason) (\(legend.yearsAtClub) season\(legend.yearsAtClub == 1 ? "" : "s"))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    }

                    Panel(title: "CAREER STATISTICS") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            statTile("APPS", "\(legend.appearances)")
                            statTile("GOALS", "\(legend.goals)")
                            statTile("ASSISTS", "\(legend.assists)")
                            statTile("CLEAN SHEETS", "\(legend.cleanSheets)")
                            statTile("AVG RATING", String(format: "%.2f", legend.averageRating))
                            statTile("PEAK OVR", "\(legend.peakRating)")
                            statTile("CAPTAIN", "\(legend.seasonsAsCaptain) yr")
                            statTile("MOTM AWARDS", "\(legend.individualAwards)")
                            statTile("LEGEND SCORE", "\(legend.legendScore)")
                        }
                    }

                    if !legend.trophiesWon.isEmpty {
                        Panel(title: "TROPHIES WON AT \(legend.clubName.uppercased())") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(legend.trophiesWon, id: \.self) { trophy in
                                    HStack(spacing: 10) {
                                        let guess = TrophyKind.guess(from: trophy)
                                        TrophyView(kind: guess?.kind ?? .league, tier: guess?.tier ?? .gold, size: 24)
                                        Text(trophy)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.9))
                                    }
                                }
                            }
                        }
                    }

                    Panel(title: "BIOGRAPHY") {
                        Text(legend.biography)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.9))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if legend.isGlobalLegend {
                        Text("★ GLOBAL HALL OF FAME ★")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [Retro.gold, Color(red: 0.85, green: 0.65, blue: 0.15)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: Retro.gold.opacity(0.5), radius: 8)
                    }
                }
                .padding(24)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Text(label)
                .font(.system(size: 8, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
