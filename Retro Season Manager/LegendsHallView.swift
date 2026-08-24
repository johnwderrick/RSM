//
//  LegendsHallView.swift
//  Retro Season Manager
//
//  Permanent museum for completed player careers. A Hall entry survives
//  removing the retired card from the active collection and is independent
//  from any later generation of the same database player.
//

import SwiftUI

struct LegendsHallView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void
    @State private var selectedEntry: LegendsHallEntry? = nil

    private var entries: [LegendsHallEntry] { Array(store.profile.legendsHall.reversed()) }

    private var ranking: [LegendsHallEntry] {
        store.profile.legendsHall.sorted { $0.legacyScore > $1.legacyScore }
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "LEGENDS HALL",
                         subtitle: "\(entries.count) COMPLETED CAREERS",
                         icon: "rosette", accent: LegendsPalette.gold,
                         onBack: onBack, currentNav: .hall, onNavigate: onNavigate) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if entries.isEmpty {
                    emptyState
                } else {
                    rankingPanel
                    ForEach(entries) { entry in
                        Button {
                            Haptics.tap()
                            selectedEntry = entry
                        } label: {
                            careerCard(entry)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            LegendsHallEntryDetailView(store: store, entry: entry)
        }
    }

    private var rankingPanel: some View {
        LegendsDashboardPanel(title: "GREATEST RSM LEGENDS", icon: "crown.fill", color: LegendsPalette.gold) {
            VStack(spacing: 7) {
                ForEach(Array(ranking.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(index == 0 ? LegendsPalette.goldDeep : LegendsPalette.navy.opacity(0.5))
                            .frame(width: 20)
                        Text(entry.playerName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(LegendsPalette.navy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        if entry.isClubLegend {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(LegendsPalette.gold)
                        }
                        Text("\(entry.legacyScore)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.goldDeep)
                    }
                }
            }
        }
    }

    private var header: some View {
        LegendsDashboardPanel(title: "CREATE THE STORY", icon: "book.closed.fill", color: LegendsPalette.gold) {
            Text("Retired players stay here forever. Every new card generation begins a separate career.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.7))
        }
    }

    private var emptyState: some View {
        LegendsDashboardPanel(title: "NO COMPLETED CAREERS YET", icon: "sparkles", color: LegendsPalette.blue) {
            Text("Sign a player, build their career, and the Hall will remember their final season.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func careerCard(_ entry: LegendsHallEntry) -> some View {
        let card = LegendsCardDatabase.all.first { $0.id == entry.cardID }
        return HStack(spacing: 12) {
            if let card {
                PlayerPortraitView(name: entry.playerName, position: card.position.broad,
                                   nation: entry.nation, size: 54)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(LegendsPalette.gold, lineWidth: 2))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LegendsPalette.gold)
                    .frame(width: 54, height: 54)
                    .background(LegendsPalette.goldWash)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.playerName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(LegendsPalette.navy)
                Text("\(entry.position.rawValue) · \(entry.nation) · AGE \(entry.startingAge) → \(entry.finalAge)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                Text("CAREER \(entry.signedSeason)–\(entry.retiredSeason) · \(entry.seasonsAtClub) SEASONS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.goldDeep)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.highestOverall)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(LegendsPalette.goldDeep)
                Text("PEAK OVR")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                if entry.legacyScore > 0 {
                    Text("\(entry.legacyScore)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.goldDeep)
                    Text("LEGACY")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.5))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if entry.isClubLegend {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(LegendsPalette.gold)
                    .offset(x: -4, y: -4)
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.gold.opacity(0.35), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 12) {
                stat("APP", entry.appearances)
                stat("G", entry.goals)
                stat("A", entry.assists)
                stat("CS", entry.cleanSheets)
            }
            .padding(.leading, 80)
            .padding(.bottom, 8)
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        Text("\(label) \(value)")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy.opacity(0.62))
    }
}

/// The permanent career page for one retired player: full statistics,
/// season-by-season history, milestones and club records.
private struct LegendsHallEntryDetailView: View {
    let store: LegendsStore
    let entry: LegendsHallEntry
    @Environment(\.dismiss) private var dismiss

    private var records: [(LegendsClubRecordKind, LegendsClubRecordEntry)] {
        store.profile.clubRecords
            .filter { $0.value.playerName == entry.playerName }
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close career page")
                    }
                    VStack(spacing: 8) {
                        PlayerPortraitView(name: entry.playerName, position: entry.position.broad, nation: entry.nation, size: 84)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(entry.isClubLegend ? Retro.gold : Retro.accent, lineWidth: 3))
                        Text(entry.playerName)
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                        Text(entry.isClubLegend ? "★ CLUB LEGEND ★" : "\(entry.position.rawValue) · \(entry.nation)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(entry.isClubLegend ? Retro.gold : Retro.text.opacity(0.7))
                        Text("CAREER COMPLETE — LEGACY SCORE \(entry.legacyScore)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Retro.highlight)
                    }

                    Panel(title: "CAREER TOTALS") {
                        VStack(alignment: .leading, spacing: 6) {
                            detailLine("Career", "S\(entry.signedSeason)–S\(entry.retiredSeason) · \(entry.seasonsAtClub) seasons")
                            detailLine("Age", "\(entry.startingAge) → \(entry.finalAge)")
                            detailLine("OVR", "\(entry.startingOverall) → \(entry.highestOverall) (final \(entry.finalOverall))")
                            detailLine("Appearances", "\(entry.appearances)")
                            detailLine("Goals / Assists", "\(entry.goals) / \(entry.assists)")
                            detailLine("Clean sheets", "\(entry.cleanSheets)")
                            detailLine("Trophies", "\(entry.trophies)")
                            detailLine("Legacy Score", "\(entry.legacyScore)")
                        }
                    }

                    if !entry.careerHistory.isEmpty {
                        Panel(title: "SEASON-BY-SEASON") {
                            VStack(spacing: 6) {
                                ForEach(Array(entry.careerHistory.reversed()), id: \.season) { record in
                                    HStack(spacing: 8) {
                                        Text("S\(record.season)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.8))
                                            .frame(width: 30, alignment: .leading)
                                        Text("AGE \(record.age)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                            .frame(width: 46, alignment: .leading)
                                        Text("\(record.appearances) APP")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                        Text("\(record.goals) G · \(record.assists) A")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                        Spacer()
                                        Text("\(record.overallAtStart) → \(record.overallAtEnd)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(record.overallAtEnd > record.overallAtStart ? Retro.emerald
                                                             : (record.overallAtEnd < record.overallAtStart ? Retro.warning : Retro.gold))
                                    }
                                }
                            }
                        }
                    }

                    if !entry.milestones.isEmpty {
                        Panel(title: "MILESTONES") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(entry.milestones).sorted { $0.rawValue < $1.rawValue }, id: \.self) { milestone in
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(milestone == .clubLegend ? Retro.gold : Retro.emerald)
                                        Text(milestone.rawValue)
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.9))
                                    }
                                }
                            }
                        }
                    }

                    if !records.isEmpty {
                        Panel(title: "CLUB RECORDS") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(records, id: \.0) { kind, record in
                                    HStack {
                                        Image(systemName: kind.icon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Retro.gold)
                                        Text(kind.displayName)
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text.opacity(0.85))
                                        Spacer()
                                        Text("\(record.value)")
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.highlight)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.65))
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
        }
    }
}
