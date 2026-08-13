//
//  NewspaperView.swift
//  Retro Season Manager
//
//  The presentation layer for generated Newspaper front pages: a full
//  article view (used from the inbox and the archive) and a compact card
//  for list/grid browsing.
//

import SwiftUI

extension NewspaperOutlet {
    /// The outlet's identity colour — threaded through masthead, rules and
    /// trim so a local paper, a national splash, a European wire report and
    /// a glossy magazine feature never read as the same publication.
    var accent: Color {
        switch self {
        case .local:    return Retro.accent
        case .national: return Retro.highlight
        case .european: return Retro.royalBlue
        case .magazine: return Retro.gold
        }
    }
}

extension NewspaperImportance {
    var headlineColor: Color {
        switch self {
        case .historic: return Retro.highlight
        case .major:    return Retro.accent
        case .notable, .minor: return Retro.text
        }
    }

    var headlineSize: CGFloat {
        switch self {
        case .historic: return 30
        case .major:    return 24
        case .notable:  return 19
        case .minor:    return 16
        }
    }
}

/// A full generated newspaper front page — masthead, headline, art, article
/// body and byline, styled distinctly per outlet.
struct NewspaperArticleView: View {
    let newspaper: Newspaper

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mastheadBar
                headlineBlock
                artRow
                Text(newspaper.body)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Retro.text)
                    .lineSpacing(4)
                bylineRow
            }
            .padding()
        }
        .background(paperBackground.ignoresSafeArea())
    }

    private var mastheadBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(newspaper.outlet.editionLabel)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(newspaper.outlet.accent.opacity(0.85))
                Spacer()
                if newspaper.outlet == .magazine {
                    Text("FEATURE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Retro.gold.opacity(0.25))
                        .clipShape(Capsule())
                        .foregroundStyle(Retro.gold)
                }
                Text("SEASON \(newspaper.season)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
            }
            Text(newspaper.masthead)
                .font(.system(newspaper.outlet == .national ? .largeTitle : .title, design: .monospaced).bold())
                .foregroundStyle(newspaper.outlet.accent)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            Rectangle().fill(newspaper.outlet.accent.opacity(0.7))
                .frame(height: newspaper.outlet == .national ? 3 : 1.5)
            if newspaper.outlet == .national {
                Rectangle().fill(newspaper.outlet.accent.opacity(0.3)).frame(height: 1)
            }
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(newspaper.headline)
                .font(.system(size: newspaper.importance.headlineSize, weight: .heavy, design: .monospaced))
                .foregroundStyle(newspaper.importance.headlineColor)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
            if !newspaper.standfirst.isEmpty {
                Text(newspaper.standfirst)
                    .font(.system(.subheadline, design: .monospaced))
                    .italic()
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var artRow: some View {
        HStack(spacing: 12) {
            if let name = newspaper.playerName {
                PlayerPortraitView(name: name, position: newspaper.playerPosition, age: newspaper.playerAge, size: 64)
            } else if let clubName = newspaper.clubName {
                CrestView(shortName: clubName, size: 56, color: newspaper.outlet.accent)
            } else {
                Text(newspaper.category.glyph)
                    .font(.system(size: 34))
                    .frame(width: 64, height: 64)
            }
            if let guess = TrophyKind.guess(from: newspaper.headline) {
                TrophyView(kind: guess.kind, tier: guess.tier, size: 48)
            }
            Spacer()
        }
    }

    private var bylineRow: some View {
        HStack {
            Text(newspaper.category.sender)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.55))
            Spacer()
            Text(newspaper.date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.55))
        }
    }

    @ViewBuilder
    private var paperBackground: some View {
        if newspaper.outlet == .magazine {
            LinearGradient(colors: [Retro.panel, Retro.token.opacity(0.4), Retro.panel],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Retro.panel
        }
    }
}

/// A compact front-page thumbnail for lists and archive grids.
struct NewspaperFrontPageCard: View {
    let newspaper: Newspaper

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(newspaper.outlet.editionLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(newspaper.outlet.accent.opacity(0.85))
                Spacer()
                if newspaper.importance == .historic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Retro.highlight)
                }
            }
            Text(newspaper.masthead)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(newspaper.outlet.accent.opacity(0.7))
                .lineLimit(1)
            Text(newspaper.headline)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(newspaper.importance.headlineColor)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 2)
            Text(newspaper.date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.5))
        }
        .padding(10)
        .frame(height: 118, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Retro.panel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(newspaper.outlet.accent.opacity(0.3), lineWidth: 1))
    }
}
