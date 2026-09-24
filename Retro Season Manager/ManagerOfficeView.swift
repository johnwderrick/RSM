//
//  ManagerOfficeView.swift
//  Retro Season Manager
//
//  The manager's office: a hub tying together the career-at-a-glance
//  overview (trophy shelf + generated autobiography), the full career
//  timeline, and the scrapbook — the front door into "the living story."
//
//  Presented in the accepted Career light-card design language (pale
//  canvas, white cards, ink headings, green accents, gold only for
//  emphasis, monospaced figures). The three tabs share ONE vertical
//  scroll container: switching tabs swaps content views inside the same
//  ScrollView identity, so returning from another destination never
//  rebuilds the container and the sheet never jumps unpredictably. Every
//  value shown comes straight from the authoritative GameStore career
//  APIs — `managerCV()`, `careerTimeline()`, `generateAutobiography()`,
//  `careerHonours`, `careerAchievementPoints`, `careerRecordByClub` —
//  nothing here recalculates, reinterprets or stores anything.
//
//  Stable `career.office.*` / `career.timeline.*` / `career.scrapbook.*`
//  identifiers support the focused UI tests.
//

import SwiftUI

struct ManagerOfficeView: View {
    let store: GameStore
    let showsClose: Bool

    init(store: GameStore, showsClose: Bool = true) {
        self.store = store
        self.showsClose = showsClose
    }

    enum OfficeTab: String, CaseIterable { case overview = "Overview", timeline = "Timeline", scrapbook = "Scrapbook" }

    @State private var tab: OfficeTab = .overview

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabPicker
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch tab {
                        case .overview:  OfficeOverviewTab(store: store)
                        case .timeline:  CareerTimelineView(store: store)
                        case .scrapbook: ManagerScrapbookView(store: store)
                        }
                        endAnchor
                    }
                    .padding(14)
                    .padding(.trailing, 6) // breathing room around the floating close
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .accessibilityIdentifier(CareerIdentifiers.officeScroll)
            }

            // Season-end still presents this as a sheet. The Manager tab
            // navigates through the sidebar, so it has no close control.
            if showsClose {
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
                .accessibilityIdentifier(CareerIdentifiers.officeClose)
                .accessibilityLabel("Close manager office")
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    @Environment(\.dismiss) private var dismiss

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("MANAGER OFFICE")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.managerName) · \(store.userClub.name)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.officeHeader)
        .accessibilityLabel("Manager office. \(store.managerName), \(store.userClub.name).")
    }

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(OfficeTab.allCases, id: \.self) { candidate in
                officeTabButton(candidate)
            }
        }
        .padding(6)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Compact, always-3-across tab control — reads clearly on landscape
    /// phones where a system segmented control crowds its labels.
    private func officeTabButton(_ candidate: OfficeTab) -> some View {
        let selected = tab == candidate
        return Button {
            Haptics.tap()
            tab = candidate
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon(for: candidate))
                    .font(.system(size: 10, weight: .black))
                Text(candidate.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(selected ? CareerPalette.line : Color.clear)
            .foregroundStyle(selected ? Color.white : CareerPalette.mutedInk)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.officeTab(candidate.rawValue))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func icon(for tab: OfficeTab) -> String {
        switch tab {
        case .overview:  return "speedometer"
        case .timeline:  return "scroll"
        case .scrapbook: return "book.fill"
        }
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.officeEnd(tab == .overview ? "overview" : tab == .timeline ? "timeline" : "scrapbook"))
    }
}

private struct OfficeOverviewTab: View {
    let store: GameStore

    private var cv: [GameStore.ManagerCVEntry] { store.managerCV() }
    private var totalMatches: Int { store.careerRecordByClub.values.reduce(0) { $0 + $1.wins + $1.draws + $1.losses } }
    private var totalWins: Int { store.careerRecordByClub.values.reduce(0) { $0 + $1.wins } }
    private var winPercentage: Int { totalMatches > 0 ? Int((Double(totalWins) / Double(totalMatches) * 100).rounded()) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryBand
            if !store.careerHonours.isEmpty {
                trophyShelf
            }
            storyCard
        }
    }

    // MARK: Summary band

    private var summaryBand: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: "CAREER AT A GLANCE", icon: "speedometer")
            // Single row on landscape widths; wraps on narrow portrait.
            // Figures stay pinned to their label pairs so the wrap keeps
            // them readable.
            FlowStatGrid(stats: [
                ("CLUBS", "\(cv.count)"),
                ("MATCHES", totalMatches.formatted()),
                ("WIN %", "\(winPercentage)%"),
                ("TROPHIES", "\(store.careerHonours.filter { $0.contains("🏆") }.count)"),
                ("POINTS", store.careerAchievementPoints.formatted()),
            ])
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.officeSummary)
        .accessibilityLabel("""
        Career at a glance. \(cv.count) clubs managed, \(totalMatches.formatted()) matches, \
        \(winPercentage) percent win rate, \(store.careerHonours.filter { $0.contains("🏆") }.count) trophies, \
        \(store.careerAchievementPoints.formatted()) career points.
        """)
    }

    // MARK: Trophy shelf

    private var trophyShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: "TROPHY SHELF", icon: "trophy.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { index, honour in
                    VStack(spacing: 5) {
                        if let guess = TrophyKind.guess(from: honour) {
                            TrophyView(kind: guess.kind, tier: guess.tier, size: 36)
                        } else {
                            Image(systemName: "medal.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Retro.gold)
                                .frame(height: 36)
                        }
                        Text(honour)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(CareerIdentifiers.officeTrophy(index))
                    .accessibilityLabel(honour)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.gold.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: trim))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.officeTrophyShelf)
    }

    // MARK: My story

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: "MY STORY", icon: "book.fill")
            Text(store.generateAutobiography())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.9))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: trim))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.officeStory)
    }

    // MARK: Shared card primitives

    private func cardHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(CareerPalette.line)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
            Spacer()
        }
    }

    private var trim: CGFloat { 14 }
}

/// The overview's five figures as compact ink-on-white tiles. One row of
/// five fits landscape phones (each tile scales); on portrait the grid
/// wraps to 3+2 through its flexible columns — no clipping either way.
private struct FlowStatGrid: View {
    let stats: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.0)
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                    Text(stat.1)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(CareerPalette.canvas.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
    }
}
