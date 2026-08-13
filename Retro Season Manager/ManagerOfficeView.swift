//
//  ManagerOfficeView.swift
//  Retro Season Manager
//
//  The manager's office: a hub tying together the career-at-a-glance
//  overview (trophy shelf + generated autobiography), the full career
//  timeline, and the scrapbook — the front door into "the living story."
//

import SwiftUI

struct ManagerOfficeView: View {
    let store: GameStore
    @State private var tab: OfficeTab = .overview

    enum OfficeTab: String, CaseIterable { case overview = "Overview", timeline = "Timeline", scrapbook = "Scrapbook" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("", selection: $tab) {
                ForEach(OfficeTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            switch tab {
            case .overview:  OfficeOverviewTab(store: store)
            case .timeline:  CareerTimelineView(store: store)
            case .scrapbook: ManagerScrapbookView(store: store)
            }
        }
        .background(Retro.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            CrestView(shortName: store.userClub.shortName, size: 36, color: store.userColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("🏛 MANAGER OFFICE")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                Text(store.managerName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
            Spacer()
        }
        .padding()
    }
}

private struct OfficeOverviewTab: View {
    let store: GameStore

    private var cv: [GameStore.ManagerCVEntry] { store.managerCV() }
    private var totalMatches: Int { store.careerRecordByClub.values.reduce(0) { $0 + $1.wins + $1.draws + $1.losses } }
    private var totalWins: Int { store.careerRecordByClub.values.reduce(0) { $0 + $1.wins } }
    private var winPercentage: Int { totalMatches > 0 ? Int((Double(totalWins) / Double(totalMatches) * 100).rounded()) : 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel(title: "CAREER AT A GLANCE") {
                    VStack(alignment: .leading, spacing: 8) {
                        statRow("Managed", "\(cv.count) club\(cv.count == 1 ? "" : "s")")
                        statRow("Matches", "\(totalMatches.formatted())")
                        statRow("Win rate", "\(winPercentage)%")
                        statRow("Trophies", "\(store.careerHonours.filter { $0.contains("🏆") }.count)")
                        statRow("Career points", "\(store.careerAchievementPoints.formatted())")
                    }
                }
                if !store.careerHonours.isEmpty {
                    Panel(title: "TROPHY SHELF") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { _, honour in
                                if let guess = TrophyKind.guess(from: honour) {
                                    VStack(spacing: 4) {
                                        TrophyView(kind: guess.kind, tier: guess.tier, size: 36)
                                        Text(honour)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
                Panel(title: "MY STORY") {
                    Text(store.generateAutobiography())
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text)
                        .lineSpacing(4)
                }
            }
            .padding()
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
        }
    }
}
