//
//  SupporterZoneView.swift
//  Retro Season Manager
//
//  The Supporter Zone: fan happiness, atmosphere, attendance, season
//  ticket holders, expectations, club traditions and fan culture, plus
//  the generated social-media-style reaction feed.
//

import SwiftUI

struct SupporterZoneView: View {
    let store: GameStore

    private var nextAtmosphere: String? {
        guard let fixture = store.nextUserFixture else { return nil }
        return store.matchAtmosphere(homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex)
    }

    private var starPlayer: Player? {
        store.userClub.players.max { $0.rating < $1.rating }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Panel(title: "FAN HAPPINESS") {
                    VStack(alignment: .leading, spacing: 10) {
                        ConfidenceBar(value: store.fanConfidence, trend: store.fanConfidenceTrend)
                        Text(store.fanMoodLabel)
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight)
                        Text("Expectations: \(store.fanExpectation())")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    }
                }
                Panel(title: "FAN PATIENCE") {
                    VStack(alignment: .leading, spacing: 6) {
                        ConfidenceBar(value: store.fanPatience)
                        Text("A slow-moving read on the fanbase — only really shifts over a sustained run of results, not one match either way.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    }
                }
                Panel(title: "MATCHDAY") {
                    VStack(alignment: .leading, spacing: 8) {
                        statRow("Season ticket holders", "\(store.seasonTicketHolders.formatted())")
                        statRow("Ground capacity", "\(store.stadiumInfo(forClubIndex: store.userClubIndex).capacity.formatted())")
                        if let nextAtmosphere {
                            statRow("Next-match atmosphere", nextAtmosphere)
                        }
                    }
                }
                if !store.attendanceHistory.isEmpty {
                    Panel(title: "ATTENDANCE TREND") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(store.attendanceHistory.suffix(5).enumerated()), id: \.offset) { offset, average in
                                let seasonsAgo = store.attendanceHistory.suffix(5).count - offset
                                statRow(seasonsAgo == 1 ? "Last season" : "\(seasonsAgo) seasons ago", "\(average.formatted()) avg.")
                            }
                        }
                    }
                }
                Panel(title: "TRADITIONS") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(FanCulture.traditions(for: store.userClub.name), id: \.self) { tradition in
                            Text("• \(tradition)")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.9))
                        }
                    }
                }
                Panel(title: "FAN CULTURE") {
                    Text(FanCulture.cultureProfile(for: store.userClub.name))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.9))
                }
                if let starPlayer {
                    Panel(title: "FROM THE TERRACES") {
                        Text("\"\(ChantBook.goalChant(playerName: starPlayer.name))\"")
                            .font(.system(.callout, design: .monospaced).italic())
                            .foregroundStyle(Retro.accent)
                    }
                }
                Panel(title: "FAN REACTIONS") {
                    if store.socialFeed.isEmpty {
                        Text("Nothing yet — big moments will show up here.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.socialFeed.prefix(40)) { post in
                                SocialPostRow(post: post)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("🗣 SUPPORTER ZONE")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text(store.userClub.name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
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
                .foregroundStyle(Retro.text)
        }
    }
}

private struct SocialPostRow: View {
    let post: SocialPost

    private var accent: Color {
        switch post.sentiment {
        case .hype:    return Retro.highlight
        case .outrage: return Retro.warning
        case .banter:  return Retro.royalBlue
        case .concern: return Retro.warning.opacity(0.8)
        case .pride:   return Retro.accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(post.handle)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(accent)
                Spacer()
                Text(post.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.5))
            }
            Text(post.text)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.9))
            Text("♥ \(post.likeCount)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.5))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.25), lineWidth: 1))
    }
}
