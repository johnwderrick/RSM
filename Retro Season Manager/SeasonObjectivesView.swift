//
//  SeasonObjectivesView.swift
//  Retro Season Manager
//
//  This season's four Season Objectives — the light-card companion to
//  the rest of the redesigned Career screens, with a tap-to-detail
//  sheet that keeps every authoritative completion/reward read straight
//  from the GameStore.
//
//  One vertical scroll container, a pinned close on the sheet, and
//  stable `career.objectives.*` identifiers. Objective cards are keyed
//  by the objective's stable id (never its display title) and the
//  detail sheet scrolls comfortably on compact landscape instead of
//  clipping.
//

import SwiftUI

struct SeasonObjectivesView: View {
    let store: GameStore
    @State private var selected: SeasonObjective?
    @Environment(\.dismiss) private var dismiss

    private var completedCount: Int { store.completedSeasonObjectiveIDs.count }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    objectivesGrid
                    endAnchor
                }
                .padding(14)
                .padding(.trailing, 6) // breathing room around the floating close
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier(CareerIdentifiers.objectivesScroll)

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
            .accessibilityIdentifier(CareerIdentifiers.objectivesClose)
            .accessibilityLabel("Close season objectives")
        }
        .font(.system(.body, design: .monospaced))
        .sheet(item: $selected) { objective in
            SeasonObjectiveDetailSheet(store: store, objective: objective)
        }
    }

    // MARK: Summary band

    private var summaryBand: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("SEASON OBJECTIVES")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.userClub.name) · SEASON \(store.season)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("COMPLETE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text("\(completedCount)/\(store.seasonObjectives.count)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(completedCount == store.seasonObjectives.count
                                     ? CareerPalette.line : CareerPalette.ink)
            }
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.objectivesSummary)
        .accessibilityLabel("""
        Season \(store.season) objectives for \(store.userClub.name). \
        \(completedCount) of \(store.seasonObjectives.count) complete.
        """)
    }

    // MARK: Objective grid

    private var objectivesGrid: some View {
        // Two columns where width allows, one on compact landscape phones —
        // same cards either way, just stacked.
        VStack(spacing: 12) {
            ForEach(store.seasonObjectives) { objective in
                Button {
                    Haptics.tap()
                    selected = objective
                } label: {
                    SeasonObjectiveCard(
                        objective: objective,
                        completed: store.completedSeasonObjectiveIDs.contains(objective.id))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.objectivesCard(objective.id))
                .accessibilityLabel("""
                \(objective.title). \(objective.description) \
                \(store.completedSeasonObjectiveIDs.contains(objective.id) ? "Completed." : "In progress.")
                """)
            }
        }
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier("career.objectives.end")
    }
}

/// One objective tile — white card, ink text, green when done, gold only
/// for the in-progress glyph. Pure presentation over the model values.
private struct SeasonObjectiveCard: View {
    let objective: SeasonObjective
    let completed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: completed ? "checkmark.seal.fill" : objective.kind.glyph)
                .font(.system(size: 20))
                .foregroundStyle(completed ? CareerPalette.line : Retro.gold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(objective.title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .multilineTextAlignment(.leading)
                Text(objective.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(completed ? "COMPLETED" : "IN PROGRESS")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(completed ? CareerPalette.line : CareerPalette.mutedInk.opacity(0.7))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(completed ? CareerPalette.line.opacity(0.12) : CareerPalette.canvas)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(completed ? CareerPalette.line.opacity(0.45) : CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }
}

/// The objective's detail sheet — light canvas, one scroll container, a
/// pinned close, and the existing reward copy (unchanged: the store owns
/// what completion grants; this restyles only how it's announced).
private struct SeasonObjectiveDetailSheet: View {
    let store: GameStore
    let objective: SeasonObjective
    @Environment(\.dismiss) private var dismiss

    private var completed: Bool { store.completedSeasonObjectiveIDs.contains(objective.id) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: completed ? "checkmark.seal.fill" : objective.kind.glyph)
                        .font(.system(size: 56))
                        .foregroundStyle(completed ? CareerPalette.line : Retro.gold)
                        .padding(.top, 44)
                    Text(objective.title)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(completed ? CareerPalette.line : CareerPalette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Text(objective.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)

                    if completed {
                        Text("+2 REPUTATION · +3 FAN CONFIDENCE · +1 CAREER POINT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.line)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(CareerPalette.line.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .padding(.horizontal, 20)
                            .accessibilityIdentifier(CareerIdentifiers.objectivesDetailReward)
                    } else {
                        Text("IN PROGRESS — KEEP PLAYING")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(CareerPalette.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .padding(.horizontal, 20)
                            .accessibilityIdentifier(CareerIdentifiers.objectivesDetailStatus)
                    }
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(CareerIdentifiers.objectivesDetail)

            // Pinned close.
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
            .accessibilityIdentifier(CareerIdentifiers.objectivesDetailClose)
            .accessibilityLabel("Close objective details")
        }
        .font(.system(.body, design: .monospaced))
    }
}
