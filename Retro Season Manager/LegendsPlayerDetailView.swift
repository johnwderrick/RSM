//
//  LegendsPlayerDetailView.swift
//  Retro Season Manager
//
//  Consolidated player detail sheet (Phase 2 lifecycle): OVERVIEW,
//  DEVELOPMENT, CAREER and ACHIEVEMENTS in one scrollable presentation so
//  the main squad/collection screens stay uncluttered while every piece of
//  a career's story stays reachable.
//

import SwiftUI

struct LegendsPlayerDetailView: View {
    let store: LegendsStore
    let card: LegendsCard
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSign = false
    @State private var showingWelcome = false
    @State private var showingComparison = false

    private var owned: Bool { store.profile.ownedCardIDs.contains(card.id) }
    private var effectiveOverall: Int { store.effectiveOverall(for: card) }
    private var age: Int { store.effectiveAge(for: card) }
    private var retired: Bool { owned && store.isRetired(card) }
    private var signed: Bool { owned && store.isCareerStarted(card) && !retired }
    private var career: LegendsPlayerCareer? { store.careerState(for: card) }
    private var status: LegendsStore.LegendsPlayerStatus? { signed ? store.playerStatus(for: card) : nil }
    private var event: LegendsStore.LegendsDevelopmentEvent? { signed ? store.developmentEvent(for: card) : nil }
    private var hallEntry: LegendsHallEntry? {
        store.profile.legendsHall.last { $0.cardID == card.id }
    }
    private var records: [(LegendsClubRecordKind, LegendsClubRecordEntry)] {
        store.profile.clubRecords
            .filter { $0.value.playerName == card.name }
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    private var statusColor: Color {
        guard let status else { return LegendsPalette.navy.opacity(0.5) }
        let tint = status.tint
        return Color(red: tint.red, green: tint.green, blue: tint.blue)
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    actionBar
                    if retired {
                        careerCompletePanel
                    } else if signed {
                        if showingWelcome { welcomePanel }
                        overview
                        developmentPanel
                        careerPanel
                        achievementsPanel
                    } else if owned {
                        collectionPanel
                        if showingWelcome { welcomePanel }
                        overview
                    } else {
                        notOwnedPanel
                    }
                }
                .padding(16)
            }
        }
        .alert("BEGIN CAREER?", isPresented: $confirmingSign) {
            Button("NOT YET", role: .cancel) { }
            Button("SIGN PLAYER") {
                guard store.signPlayer(cardID: card.id) else { return }
                Haptics.success()
                showingWelcome = true
            }
        } message: {
            Text("Once signed, \(card.name) will begin ageing, development and career statistics. This cannot normally be reversed.")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
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
                .accessibilityLabel("Close player details")
            }
            PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 84)
                .clipShape(Circle())
                .overlay(Circle().stroke(card.rarity.tint, lineWidth: 3))
            Text(card.name)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
            Text("\(card.rarity.rawValue.uppercased()) · \(card.era.rawValue.uppercased())")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(card.rarity.tint)
            HStack(spacing: 6) {
                FlagView(nationality: card.nation, width: 16)
                Text("\(card.position.rawValue) · \(card.club) · \(card.nation) · \(card.season)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
            if signed, let status {
                Text(status.rawValue)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            HStack(spacing: 16) {
                metric("\(effectiveOverall)", "OVR", color: card.rarity.tint)
                metric("\(age)", "AGE", color: Retro.text)
                if let state = career {
                    metric("\(state.appearances)", "APPS", color: Retro.text)
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                store.toggleFavourite(cardID: card.id)
            } label: {
                Label(store.isFavourite(card.id) ? "FAVOURITED" : "FAVOURITE", systemImage: store.isFavourite(card.id) ? "star.fill" : "star")
            }
            .accessibilityIdentifier("legends.player.favourite")
            .buttonStyle(.borderedProminent)
            Button("COMPARE") { showingComparison = true }
                .accessibilityIdentifier("legends.player.compare")
                .buttonStyle(.bordered)
        }
        .foregroundStyle(Retro.text)
        .sheet(isPresented: $showingComparison) {
            LegendsPlayerComparisonView(store: store, primary: card)
        }
    }

    private var collectionPanel: some View {
        Panel(title: "UNSIGNED · CAREER NOT STARTED") {
            VStack(spacing: 10) {
                Text("Age frozen at \(card.age). Signing starts this player's career clock and makes them eligible for the Active Club.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
                    .multilineTextAlignment(.center)
                Button("SIGN PLAYER") { confirmingSign = true }
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Retro.highlight)
                    .clipShape(Capsule())
                    .buttonStyle(PressableButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var welcomePanel: some View {
        Panel(title: "WELCOME TO THE CLUB") {
            VStack(spacing: 8) {
                Text("\(card.name) · CAREER BEGINS AT AGE \(store.effectiveAge(for: card))")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.emerald)
                Text("The player is now ACTIVE. Add them to matchday from Squad, or leave them in Reserves while their career continues.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var notOwnedPanel: some View {
        Panel(title: "NOT YET OWNED") {
            Text("Open packs to add this card to your collection.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var careerCompletePanel: some View {
        VStack(spacing: 12) {
            if let entry = hallEntry {
                Panel(title: "LEGENDS HALL — CAREER COMPLETE") {
                    VStack(alignment: .leading, spacing: 6) {
                        hallLine("Career", "S\(entry.signedSeason)–S\(entry.retiredSeason) · \(entry.seasonsAtClub) seasons")
                        hallLine("Appearances", "\(entry.appearances)")
                        hallLine("Goals / Assists", "\(entry.goals) / \(entry.assists)")
                        hallLine("Clean sheets", "\(entry.cleanSheets)")
                        hallLine("Peak OVR", "\(entry.highestOverall)")
                        hallLine("Trophies", "\(entry.trophies)")
                        hallLine("Legacy Score", "\(entry.legacyScore)")
                        if entry.isClubLegend {
                            Text("★ CLUB LEGEND ★")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundStyle(Retro.gold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                if !entry.careerHistory.isEmpty {
                    seasonHistory(entry.careerHistory)
                }
                if !entry.milestones.isEmpty {
                    milestonesList(Array(entry.milestones))
                }
            } else {
                Panel(title: "CAREER COMPLETE") {
                    Text("This player has retired and is remembered in the Legends Hall.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var overview: some View {
        Panel(title: "OVERVIEW") {
            VStack(alignment: .leading, spacing: 8) {
                if career != nil {
                    statRow("POTENTIAL", store.potentialLabel(for: card))
                    statRow("FORM", event?.rawValue ?? "USUAL PACE")
                    statRow("SCOUTING", store.potentialDescription(for: card))
                }
                Text("Base \(card.overall)\(upgradeText)\(agingText)\(formText) = \(effectiveOverall)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
                ForEach([("PAC", card.pace), ("SHO", card.shooting), ("PAS", card.passing),
                         ("DRI", card.dribbling), ("DEF", card.defending), ("PHY", card.physical)],
                        id: \.0) { metric in
                    statBar(metric.0, metric.1)
                }
            }
        }
    }

    private var upgradeText: String {
        let level = store.profile.cardUpgrades[card.id] ?? 0
        return level > 0 ? " + \(level) upgrade" : ""
    }

    private var agingText: String {
        let penalty = store.agingPenalty(for: card)
        return penalty > 0 ? " − \(penalty) aging" : ""
    }

    private var formText: String {
        let boost = store.formBoost(for: card)
        return boost > 0 ? " + \(boost) form" : ""
    }

    private var developmentPanel: some View {
        Panel(title: "DEVELOPMENT") {
            VStack(alignment: .leading, spacing: 8) {
                if let state = career {
                    statRow("SEASON", "S\(store.profile.currentSeason) of career")
                    statRow("TRAINING", "\(state.trainingSessionsThisSeason)/\(LegendsStore.maxTrainingSessionsPerSeason) sessions this season")
                    statRow("APPEARANCES", "\(state.seasonAppearances) this season · \(state.starts) starts")
                    if let event {
                        Text(event.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundStyle(event.multiplier > 1 ? Retro.emerald : (event.multiplier < 1 ? Retro.warning : Retro.text))
                    }
                    Text("Young players develop through matches and training; minutes matter. Players past their peak decline instead.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }
            }
        }
    }

    private var careerPanel: some View {
        Panel(title: "CAREER") {
            if let career {
                VStack(alignment: .leading, spacing: 6) {
                    statRow("APPEARANCES", "\(career.appearances)")
                    statRow("GOALS / ASSISTS", "\(career.goals) / \(career.assists)")
                    statRow("CLEAN SHEETS", "\(career.cleanSheets)")
                    statRow("MINUTES", "\(career.minutesPlayed)")
                    statRow("HIGHEST OVR", "\(career.highestOverall)")
                    statRow("CLUB LEGEND", career.isClubLegend ? "YES" : "—")
                }
                if !career.seasonRecords.isEmpty {
                    Divider()
                    seasonHistory(career.seasonRecords)
                }
            }
        }
    }

    private func seasonHistory(_ records: [LegendsSeasonRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SEASON-BY-SEASON")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Retro.accent)
            ForEach(Array(records.reversed()), id: \.season) { record in
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
        .padding(.top, 4)
    }

    private var achievementsPanel: some View {
        Panel(title: "ACHIEVEMENTS") {
            VStack(alignment: .leading, spacing: 8) {
                if let career, !career.milestones.isEmpty {
                    milestonesList(Array(career.milestones))
                } else {
                    Text("No milestones yet — milestones unlock for appearances, goals and trophies.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }
                if !records.isEmpty {
                    Divider()
                    Text("CLUB RECORDS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Retro.gold)
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

    private func milestonesList(_ milestones: [LegendsCareerMilestone]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(milestones, id: \.self) { milestone in
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

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
        }
    }

    private func hallLine(_ label: String, _ value: String) -> some View {
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

    private func metric(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.black)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.55))
        }
    }

    private func statBar(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.7))
                .frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Retro.background.opacity(0.5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(card.rarity.tint)
                        .frame(width: geo.size.width * CGFloat(min(value, 99)) / 99)
                }
            }
            .frame(height: 8)
            Text("\(value)")
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .frame(width: 26, alignment: .trailing)
        }
    }
}
