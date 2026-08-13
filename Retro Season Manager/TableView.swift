//
//  TableView.swift
//  Retro Season Manager
//
//  The Competitions / league table tab.
//

import SwiftUI

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

