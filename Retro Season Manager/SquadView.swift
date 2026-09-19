//
//  SquadView.swift
//  Retro Season Manager
//
//  The Squad tab's Tactics mode: formation picker, pitch/list split
//  and the squad-needs sheet.
//

import SwiftUI

// MARK: - Squad / Tactics

enum SquadViewMode: String, CaseIterable {
    case tactics = "TACTICS"
    case list = "SQUAD LIST"
}

struct SquadView: View {
    let store: GameStore
    @State private var message: String?
    @State private var mode: SquadViewMode = .tactics
    @State private var showingDepth = false
    @State private var showingTeamSetup = false

    var body: some View {
        VStack(spacing: 0) {
            squadHeader

            if mode == .tactics {
                tacticsToolbar
                GeometryReader { geo in
                    // Side-by-side needs real width for both the pitch and
                    // a legible bench list; below that, stack instead of
                    // squeezing the pitch into a sliver.
                    if geo.size.width >= 560 {
                        HStack(spacing: 0) {
                            PitchView(store: store, message: $message)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            SquadListPanel(store: store, message: $message)
                                .frame(width: 248)
                        }
                    } else {
                        VStack(spacing: 0) {
                            PitchView(store: store, message: $message)
                                .frame(maxWidth: .infinity)
                                .frame(height: max(280, geo.size.height * 0.62))
                            SquadListPanel(store: store, message: $message)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            } else {
                SquadTableView(store: store)
            }
        }
        .background(CareerPalette.canvas)
        .sheet(isPresented: $showingDepth) {
            SquadDepthSheet(store: store)
        }
        .sheet(isPresented: $showingTeamSetup) {
            TeamSetupSheet(store: store, message: $message)
        }
    }

    private var squadHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(SquadViewMode.allCases, id: \.self) { item in
                    Button {
                        Haptics.tap()
                        mode = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(mode == item ? .white : CareerPalette.mutedInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(mode == item ? Retro.darkGreen : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.squad.mode.\(item == .tactics ? "tactics" : "list")")
                    .accessibilityAddTraits(mode == item ? .isSelected : [])
                }
            }
            .padding(4)
            .frame(maxWidth: 360)
            .background(CareerPalette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Spacer(minLength: 0)

            summaryMetric("PLAYERS", "\(store.userClub.players.count)")
            summaryMetric("XI", "\(store.userStarterIDs.count)/11")
            summaryMetric("AVG OVR", "\(averageRating)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CareerPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CareerPalette.line.opacity(0.16)).frame(height: 1)
        }
    }

    private func summaryMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
        }
    }

    private var averageRating: Int {
        guard !store.userClub.players.isEmpty else { return 0 }
        return store.userClub.players.map(\.rating).reduce(0, +) / store.userClub.players.count
    }

    /// A slim, single-row toolbar replacing what used to be a permanently
    /// visible formation strip, squad-depth banner, and bottom action bar —
    /// all three now live behind one "Team Setup" button and one depth
    /// icon, so the pitch itself gets the vast majority of the screen.
    private var tacticsToolbar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    showingTeamSetup = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3.fill")
                        Text("\(store.formation.name) · \(store.preferredMentality.rawValue)")
                    }
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CareerPalette.canvas)
                    .foregroundStyle(CareerPalette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())

                let needs = store.squadNeeds()
                Button {
                    Haptics.tap()
                    showingDepth = true
                } label: {
                    Image(systemName: needs.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(needs.isEmpty ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                        .padding(8)
                        .background(CareerPalette.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())

                Spacer()

                if let message {
                    Text(message)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.highlight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text("XI \(store.userStarterIDs.count)/11")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(store.userStarterIDs.count == 11 ? CareerPalette.line : Retro.highlight)
            }
            if store.isFormationBeddingIn {
                Text("Formation still bedding in — performance dips slightly for a few matches after a switch.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CareerPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CareerPalette.line.opacity(0.12)).frame(height: 1)
        }
    }
}

/// The full squad-depth picture: which roles are thin or empty, and any
/// market targets that would plug the gap within budget — reached from
/// the Squad tab's summary strip instead of only being a Home-dashboard
/// panel, so "how do I improve this squad?" has one obvious home.
struct SquadDepthSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var opened: TransferTarget?

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("SQUAD DEPTH")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        let needs = store.squadNeeds()
                        Panel(title: "COVER BY POSITION") {
                            if needs.isEmpty {
                                Text("Every role has cover. ✓")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.85))
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(needs, id: \.role) { need in
                                        HStack(spacing: 8) {
                                            Text(need.count == 0 ? "🔴" : "🟡")
                                            Text(need.role.fullName)
                                            Spacer()
                                            Text(need.count == 0 ? "none fit" : "\(need.count) fit")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(need.count == 0 ? Color(red: 0.9, green: 0.35, blue: 0.35) : Retro.highlight)
                                        }
                                        .font(.system(.callout, design: .monospaced))
                                    }
                                }
                            }
                        }

                        let suggestions = store.suggestedTransferTargets(limit: 6)
                        if !suggestions.isEmpty {
                            Panel(title: "COULD PLUG THE GAP") {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fits a thin role and your budget.")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Retro.text.opacity(0.6))
                                    ForEach(suggestions) { target in
                                        Button { opened = target } label: {
                                            HStack {
                                                Text(target.player.detailedPosition.rawValue)
                                                    .font(.system(.footnote, design: .monospaced).bold())
                                                    .foregroundStyle(Retro.highlight)
                                                    .frame(width: 40, alignment: .leading)
                                                Text(target.player.name)
                                                    .font(.system(.footnote, design: .monospaced))
                                                Spacer()
                                                Text(target.sellingClubIndex == nil ? "FREE" : formatMoney(target.askingPrice))
                                                    .font(.system(.caption, design: .monospaced).bold())
                                                    .foregroundStyle(Retro.accent)
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(item: $opened) { target in
            PlayerProfileSheet(store: store, context: .market(target)) { _ in }
        }
    }
}
