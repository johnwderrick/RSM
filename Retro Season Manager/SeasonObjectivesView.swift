//
//  SeasonObjectivesView.swift
//  Retro Season Manager
//
//  This season's four Season Objectives — same grid-of-cards/tap-to-detail
//  visual language as AchievementGalleryView, sized for four items instead
//  of a whole career's worth.
//

import SwiftUI

struct SeasonObjectivesView: View {
    let store: GameStore
    @State private var selected: SeasonObjective?

    private var completedCount: Int { store.completedSeasonObjectiveIDs.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Panel(title: "SEASON \(store.season)") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(store.seasonObjectives) { objective in
                            Button {
                                Haptics.tap()
                                selected = objective
                            } label: {
                                SeasonObjectiveCard(objective: objective,
                                                     completed: store.completedSeasonObjectiveIDs.contains(objective.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
        .sheet(item: $selected) { objective in
            SeasonObjectiveDetailSheet(store: store, objective: objective)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🎯 SEASON OBJECTIVES")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text("\(completedCount)/\(store.seasonObjectives.count) complete this season")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
    }
}

private struct SeasonObjectiveCard: View {
    let objective: SeasonObjective
    let completed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: completed ? "checkmark.seal.fill" : objective.kind.glyph)
                    .font(.system(size: 20))
                    .foregroundStyle(completed ? Retro.emerald : Retro.highlight.opacity(0.85))
                Spacer()
            }
            Text(objective.title)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .multilineTextAlignment(.leading)
            Text(objective.description)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Retro.panel.opacity(completed ? 0.4 : 0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(completed ? Retro.emerald.opacity(0.4) : Retro.accent.opacity(0.1), lineWidth: 1))
    }
}

private struct SeasonObjectiveDetailSheet: View {
    let store: GameStore
    let objective: SeasonObjective
    @Environment(\.dismiss) private var dismiss

    private var completed: Bool { store.completedSeasonObjectiveIDs.contains(objective.id) }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Retro.text.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Image(systemName: completed ? "checkmark.seal.fill" : objective.kind.glyph)
                    .font(.system(size: 60))
                    .foregroundStyle(completed ? Retro.emerald : Retro.highlight.opacity(0.85))
                Text(objective.title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(completed ? Retro.emerald : Retro.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(objective.description)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                if completed {
                    Text("+2 REPUTATION · +3 FAN CONFIDENCE · +1 CAREER POINT")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    Text("IN PROGRESS — KEEP PLAYING")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }
}
