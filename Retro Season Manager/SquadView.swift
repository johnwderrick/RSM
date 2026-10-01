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
                            .foregroundStyle(mode == item ? .white : CareerPalette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(mode == item ? Retro.darkGreen : CareerPalette.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            // The unselected segment must read as a real
                            // control on the shared pale canvas chip.
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(CareerPalette.line.opacity(0.35)))
                    }
                    .buttonStyle(PressableButtonStyle())
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
                .accessibilityIdentifier("career.squad.teamSetup")
                .accessibilityLabel("Team Setup — \(store.formation.name), \(store.preferredMentality.rawValue) mentality")

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
                .accessibilityIdentifier("career.squad.depthButton")
                .accessibilityLabel(needs.isEmpty ? "Squad depth — every role has cover" : "Squad depth — \(needs.count) roles need cover")

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
///
/// Career light-card treatment: pale canvas, white cards, dark ink
/// headings, restrained green accents. One vertical scroll container;
/// the header close stays pinned outside it so the sheet is always
/// closable on a compact landscape phone.
struct SquadDepthSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var opened: TransferTarget?

    /// Red for a role with no available player at all; amber for thin but
    /// non-empty cover. Text always carries the meaning — colour only
    /// reinforces it.
    private var gapColor: Color { Color(red: 0.72, green: 0.16, blue: 0.16) }
    private var thinColor: Color { Color(red: 0.70, green: 0.44, blue: 0.04) }

    var body: some View {
        VStack(spacing: 0) {
            depthHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    coverCard
                    suggestionsCard
                    Color.clear
                        .frame(height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier(CareerIdentifiers.depthEnd)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CareerIdentifiers.depthScroll)
        }
        .background(CareerPalette.canvas.ignoresSafeArea())
        .font(.system(.body, design: .monospaced))
        // The sheet's root anchor lives on a 1x1 overlay element instead of
        // the container itself: an identifier on a parent container is
        // inherited by its descendants and masks their own identifiers.
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(CareerIdentifiers.depthSheet)
        }
        .sheet(item: $opened) { target in
            PlayerProfileSheet(store: store, context: .market(target)) { _ in }
        }
    }

    // MARK: Header (pinned)

    private var depthHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SQUAD DEPTH")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("Cover by role and affordable fixes")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer(minLength: 8)
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(CareerPalette.ink)
                    .frame(width: 32, height: 32)
                    .background(CareerPalette.surface)
                    .overlay(Circle().stroke(CareerPalette.line.opacity(0.18)))
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.depthClose)
            .accessibilityLabel("Close squad depth")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(CareerPalette.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(CareerPalette.line.opacity(0.12)).frame(height: 1) }
    }

    // MARK: Cover card

    private var coverCard: some View {
        let needs = store.squadNeeds()
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                    .accessibilityHidden(true)
                Text("COVER BY POSITION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }

            if needs.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(CareerPalette.line)
                        .accessibilityHidden(true)
                    Text("Every role has cover.")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(CareerPalette.line.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(CareerIdentifiers.depthAllCovered)
                .accessibilityLabel("Every role has cover")
            } else {
                VStack(spacing: 0) {
                    ForEach(needs, id: \.role) { need in
                        depthRow(need)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.depthCoverList)
    }

    /// One thin-role row: the role's code in a tinted pill, its full name,
    /// and a readable count that text-carries the severity.
    private func depthRow(_ need: GameStore.SquadNeed) -> some View {
        let empty = need.count == 0
        let tint = empty ? gapColor : thinColor
        return HStack(spacing: 9) {
            Text(need.role.rawValue)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 34, height: 24)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            Text(need.role.fullName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
            Spacer(minLength: 6)
            Text(empty ? "none fit" : "\(need.count) fit")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.depthRole(need.role))
        .accessibilityLabel("\(need.role.fullName): \(empty ? "no players fit" : "\(need.count) players fit")")
    }

    // MARK: Suggestions card

    private var suggestionsCard: some View {
        let suggestions = store.suggestedTransferTargets(limit: 6)
        return Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(CareerPalette.line)
                            .accessibilityHidden(true)
                        Text("COULD PLUG THE GAP")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                        Spacer()
                    }

                    Text("Fits a thin role and your budget.")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)

                    VStack(spacing: 0) {
                        ForEach(suggestions) { target in
                            suggestionRow(target)
                        }
                    }
                    .background(CareerPalette.canvas.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CareerPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.16)))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(CareerIdentifiers.depthSuggestions)
            }
        }
    }

    /// One market suggestion row: same FREE-vs-fee read as before, now on
    /// a pressable card with a full VoiceOver label.
    private func suggestionRow(_ target: TransferTarget) -> some View {
        let isFree = target.sellingClubIndex == nil
        let price = isFree ? "FREE" : formatMoney(target.askingPrice)
        return Button {
            Haptics.tap()
            opened = target
        } label: {
            HStack(spacing: 9) {
                Text(target.player.detailedPosition.rawValue)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .frame(width: 34, height: 24)
                    .background(CareerPalette.line.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
                Text(target.player.name)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                Text(price)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isFree ? CareerPalette.line : CareerPalette.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.depthTarget(target.player.name))
        .accessibilityLabel("\(target.player.name), \(target.player.detailedPosition.fullName), \(isFree ? "free agent" : "asking price \(price)")")
    }
}
