//
//  ManagerScrapbookView.swift
//  Retro Season Manager
//
//  A curated highlight reel of a career — a handful of framed "photos"
//  for the biggest moments (trophies, promotions, retirement) alongside
//  the most historic front pages already archived by the newspaper
//  system. Nothing new is tracked here — it's a curated view over what's
//  already there.
//

import SwiftUI

private enum PhotoSubject {
    case trophy(TrophyKind, TrophyTier)
    case crest(String, Color)
}

private struct HistoricPhotoCard: View {
    let subject: PhotoSubject
    let caption: String
    let dateLabel: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Retro.panel.opacity(0.9)
                switch subject {
                case .trophy(let kind, let tier):
                    TrophyView(kind: kind, tier: tier, size: 64)
                case .crest(let shortName, let color):
                    CrestView(shortName: shortName, size: 64, color: color)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Retro.gold.opacity(0.5), lineWidth: 2))
            Text(caption)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(dateLabel)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.5))
        }
        .padding(10)
        .background(Retro.panel.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ManagerScrapbookView: View {
    let store: GameStore
    @State private var selectedNewspaper: Newspaper?

    private var photoMoments: [CareerMoment] {
        store.careerTimeline().filter { ["🏆", "🏅", "🎓"].contains($0.icon) }
    }

    private var featuredNewspapers: [Newspaper] {
        Array(store.newspapers.filter { $0.importance == .historic }.prefix(12))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if photoMoments.isEmpty && featuredNewspapers.isEmpty {
                    Text("Nothing to remember yet — the big moments will land here.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }
                if !photoMoments.isEmpty {
                    Panel(title: "MOMENTS TO REMEMBER") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(photoMoments) { moment in
                                HistoricPhotoCard(subject: subject(for: moment), caption: moment.headline, dateLabel: "\(moment.year)")
                            }
                        }
                    }
                }
                if !featuredNewspapers.isEmpty {
                    Panel(title: "FRONT PAGES") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(featuredNewspapers) { newspaper in
                                Button {
                                    Haptics.tap()
                                    selectedNewspaper = newspaper
                                } label: {
                                    NewspaperFrontPageCard(newspaper: newspaper)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
        .sheet(item: $selectedNewspaper) { newspaper in
            NewspaperArticleView(newspaper: newspaper)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("📖 MANAGER SCRAPBOOK")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text(store.managerName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
    }

    private func subject(for moment: CareerMoment) -> PhotoSubject {
        if moment.icon == "🏆", let guess = TrophyKind.guess(from: moment.headline) {
            return .trophy(guess.kind, guess.tier)
        }
        if moment.icon == "🏅" {
            return .trophy(.managerAward, .premium)
        }
        return .crest(store.userClub.shortName, store.userColor)
    }
}
