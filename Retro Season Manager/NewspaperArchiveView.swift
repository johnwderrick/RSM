//
//  NewspaperArchiveView.swift
//  Retro Season Manager
//
//  Every generated newspaper front page, browsable season by season — the
//  permanent illustrated record the plain news inbox never kept.
//
//  Restyled into the accepted Career light-card language. The archive is
//  hosted two ways: as a full sheet (pinned, always-reachable close) and
//  inside a Settings detail page (where the detail page's own scroll is
//  the single vertical container — no nested scrolling here).
//

import SwiftUI

struct NewspaperArchiveView: View {
    let store: GameStore
    /// True when presented as a full sheet (draws its own canvas and
    /// pinned close). False when hosted inside a Settings detail page's
    /// scroll container.
    var isSheet: Bool = false

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
        Group {
            if isSheet {
                VStack(spacing: 10) {
                    header
                    filterRow
                    archiveContent
                }
                .background(CareerPalette.canvas.ignoresSafeArea())
                .overlay(alignment: .topTrailing) {
                    Button {
                        Haptics.tap()
                        // dismiss is environment-scoped; the sheet hosts
                        // us directly so this always targets the sheet.
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                            .padding(12)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.settingsSheetClose)
                    .accessibilityLabel("Close newspaper archive")
                }
            } else {
                VStack(spacing: 10) {
                    header
                    filterRow
                    archiveContent
                }
            }
        }
        .sheet(item: $selected) { newspaper in
            NewspaperArticleView(newspaper: newspaper)
        }
    }

    @ViewBuilder
    private var archiveContent: some View {
        if filtered.isEmpty {
            // Empty state — the sheet keeps this vertically centred; the
            // hosted variant flows inline in the detail page's scroll.
            Group {
                if isSheet { Spacer() }
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 30))
                        .foregroundStyle(CareerPalette.mutedInk.opacity(0.45))
                    Text("No front pages yet — big moments in your career will run here.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                if isSheet { Spacer() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(seasons, id: \.self) { season in
                        seasonSection(season)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier("career.settings.archive.scroll")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("📰 THE ARCHIVE")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.newspapers.count) front page\(store.newspapers.count == 1 ? "" : "s") printed")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.settings.archive.header")
        .accessibilityLabel("The archive. \(store.newspapers.count) front pages printed.")
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
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? CareerPalette.line : CareerPalette.surface)
                .foregroundStyle(isSelected ? .white : CareerPalette.mutedInk)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(CareerPalette.line.opacity(isSelected ? 0 : 0.25), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("career.settings.archive.filter.\(label.lowercased())")
        .accessibilityLabel("\(label) edition filter\(isSelected ? ", selected" : "")")
    }

    private func seasonSection(_ season: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEASON \(season)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.line)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                let seasonPapers = filtered.filter { $0.season == season }
                ForEach(Array(seasonPapers.enumerated()), id: \.element.id) { index, newspaper in
                    Button {
                        Haptics.tap()
                        selected = newspaper
                    } label: {
                        NewspaperFrontPageCard(newspaper: newspaper)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.settings.archive.frontPage.\(season).\(index)")
                    .accessibilityLabel("Season \(season) front page: \(newspaper.headline)")
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
