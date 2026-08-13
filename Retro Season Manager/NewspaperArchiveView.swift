//
//  NewspaperArchiveView.swift
//  Retro Season Manager
//
//  Every generated newspaper front page, browsable season by season — the
//  permanent illustrated record the plain news inbox never kept.
//

import SwiftUI

struct NewspaperArchiveView: View {
    let store: GameStore
    @State private var outletFilter: NewspaperOutlet?
    @State private var selected: Newspaper?

    private var filtered: [Newspaper] {
        guard let outletFilter else { return store.newspapers }
        return store.newspapers.filter { $0.outlet == outletFilter }
    }

    private var seasons: [Int] {
        Array(Set(filtered.map { $0.season })).sorted(by: >)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            filterRow
            if filtered.isEmpty {
                Spacer()
                Text("No front pages yet — big moments in your career will run here.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(seasons, id: \.self) { season in
                            seasonSection(season)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Retro.background.ignoresSafeArea())
        .sheet(item: $selected) { newspaper in
            NewspaperArticleView(newspaper: newspaper)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("📰 THE ARCHIVE")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                Text("\(store.newspapers.count) front page\(store.newspapers.count == 1 ? "" : "s") printed")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(nil, label: "All")
                filterPill(.local, label: "Local")
                filterPill(.national, label: "National")
                filterPill(.european, label: "European")
                filterPill(.magazine, label: "Magazine")
            }
            .padding(.horizontal)
        }
    }

    private func filterPill(_ outlet: NewspaperOutlet?, label: String) -> some View {
        let isSelected = outletFilter == outlet
        return Button {
            Haptics.tap()
            outletFilter = outlet
        } label: {
            Text(label)
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? (outlet?.accent ?? Retro.accent).opacity(0.3) : Retro.panel.opacity(0.6))
                .foregroundStyle(isSelected ? (outlet?.accent ?? Retro.accent) : Retro.text.opacity(0.7))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? (outlet?.accent ?? Retro.accent).opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func seasonSection(_ season: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEASON \(season)")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(filtered.filter { $0.season == season }) { newspaper in
                    Button {
                        Haptics.tap()
                        selected = newspaper
                    } label: {
                        NewspaperFrontPageCard(newspaper: newspaper)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
