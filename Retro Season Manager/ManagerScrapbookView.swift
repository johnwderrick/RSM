//
//  ManagerScrapbookView.swift
//
//  A curated highlight reel of a career — framed "photos" for the biggest
//  moments (trophies, promotions, retirement) alongside the most historic
//  front pages already archived by the newspaper system. Nothing new is
//  tracked here — it's a curated view over what's already there.
//
//  This view renders INSIDE the Manager Office's shared scroll container
//  (the host owns the one vertical ScrollView), so it draws content only —
//  no container of its own, no background of its own. Light-card language:
//  gold-framed photos on white cards, ink captions, monospaced dates.
//

import SwiftUI

private enum PhotoSubject {
    case trophy(TrophyKind, TrophyTier)
    case crest(String, Color)
}

/// One framed "photo": trophy or crest in a gold-trimmed frame, with a
/// caption and date beneath. Pure presentation over the moment data.
private struct HistoricPhotoCard: View {
    let subject: PhotoSubject
    let caption: String
    let dateLabel: String
    let identifier: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                CareerPalette.canvas.opacity(0.8)
                switch subject {
                case .trophy(let kind, let tier):
                    TrophyView(kind: kind, tier: tier, size: 64)
                case .crest(let shortName, let color):
                    CrestView(shortName: shortName, size: 64, color: color)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Retro.gold.opacity(0.5), lineWidth: 2))
            Text(caption)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(dateLabel)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.7))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(caption), \(dateLabel)")
    }
}

/// The Scrapbook tab's content. Hosted by `ManagerOfficeView`'s single
/// scroll container — deliberately NOT a ScrollView itself.
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
        VStack(alignment: .leading, spacing: 12) {
            if photoMoments.isEmpty && featuredNewspapers.isEmpty {
                emptyState
            }
            if !photoMoments.isEmpty {
                momentsCard
            }
            if !featuredNewspapers.isEmpty {
                frontPagesCard
            }
        }
        .sheet(item: $selectedNewspaper) { newspaper in
            NewspaperArticleView(newspaper: newspaper)
        }
    }

    // MARK: Sections

    private var momentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "MOMENTS TO REMEMBER", icon: "star.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(photoMoments) { moment in
                    HistoricPhotoCard(subject: subject(for: moment),
                                      caption: moment.headline,
                                      dateLabel: String(moment.year),
                                      identifier: CareerIdentifiers.scrapbookMoment(moment.year))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.scrapbookMoments)
    }

    private var frontPagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "FRONT PAGES", icon: "newspaper.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(featuredNewspapers.enumerated()), id: \.element.id) { index, newspaper in
                    Button {
                        Haptics.tap()
                        selectedNewspaper = newspaper
                    } label: {
                        NewspaperFrontPageCard(newspaper: newspaper)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.scrapbookFrontPage(index))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.scrapbookFrontPages)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.5))
            Text("Nothing to remember yet — the big moments will land here.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.scrapbookEmpty)
        .accessibilityLabel("Nothing to remember yet. Win trophies to fill your scrapbook.")
    }

    private func sectionHeader(title: String, icon: String) -> some View {
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
