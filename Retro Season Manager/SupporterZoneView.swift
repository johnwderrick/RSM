//
//  SupporterZoneView.swift
//  Retro Season Manager
//
//  The Supporter Zone: fan happiness, atmosphere, attendance, season
//  ticket holders, expectations, club traditions and fan culture, plus
//  the generated social-media-style reaction feed.
//
//  Presented in the accepted Career light-card design language (pale
//  canvas, white cards, ink headings, green accents, gold only for
//  emphasis, monospaced figures). Every value shown comes straight from
//  the authoritative GameStore supporter/fan APIs — nothing here
//  recalculates, reinterprets or stores anything.
//
//  The sheet has exactly one vertical scroll container, a pinned close
//  control, and stable `career.supporter.*` identifiers for the UI
//  tests. Compact landscape keeps every control reachable (the close
//  button floats above the scroll; nothing is gated behind it).
//

import SwiftUI

struct SupporterZoneView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var nextAtmosphere: String? {
        guard let fixture = store.nextUserFixture else { return nil }
        return store.matchAtmosphere(homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex)
    }

    private var starPlayer: Player? {
        store.userClub.players.max { $0.rating < $1.rating }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    fanHappinessCard
                    fanPatienceCard
                    matchdayCard
                    if !store.attendanceHistory.isEmpty {
                        attendanceCard
                    }
                    traditionsCard
                    fanCultureCard
                    if let starPlayer {
                        terracesCard(starPlayer)
                    }
                    reactionsCard
                    endAnchor
                }
                .padding(14)
                .padding(.trailing, 6) // breathing room around the floating close
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier(CareerIdentifiers.supporterScroll)

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
            .accessibilityIdentifier(CareerIdentifiers.supporterClose)
            .accessibilityLabel("Close supporter zone")
        }
        .font(.system(.body, design: .monospaced))
    }

    // MARK: Summary band

    private var summaryBand: some View {
        HStack(spacing: 14) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("SUPPORTER ZONE")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.userClub.name) · SEASON \(store.season)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            summaryStat("MOOD", store.fanMoodLabel.uppercased(),
                        accent: confidenceColor(store.fanConfidence))
            summaryStat("FANS", "\(store.fanConfidence)%",
                        accent: confidenceColor(store.fanConfidence))
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.supporterSummary)
        .accessibilityLabel("""
        Supporter zone. \(store.userClub.name), season \(store.season). \
        Fan confidence \(store.fanConfidence) percent — \(store.fanMoodLabel). \
        \(store.seasonTicketHolders.formatted()) season ticket holders.
        """)
    }

    private func summaryStat(_ title: String, _ value: String, accent: Color? = nil) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(accent ?? CareerPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 42)
    }

    // MARK: Fan happiness

    private var fanHappinessCard: some View {
        card(title: "FAN HAPPINESS", icon: "heart.fill") {
            VStack(alignment: .leading, spacing: 10) {
                LightConfidenceBar(value: store.fanConfidence, trend: store.fanConfidenceTrend)
                Text(store.fanMoodLabel)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(confidenceColor(store.fanConfidence))
                Text("Expectations: \(store.fanExpectation())")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
        }
    }

    // MARK: Fan patience

    private var fanPatienceCard: some View {
        card(title: "FAN PATIENCE", icon: "hourglass") {
            VStack(alignment: .leading, spacing: 6) {
                LightConfidenceBar(value: store.fanPatience)
                Text("A slow-moving read on the fanbase — only really shifts over a sustained run of results, not one match either way.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
        }
    }

    // MARK: Matchday

    private var matchdayCard: some View {
        card(title: "MATCHDAY", icon: "ticket.fill") {
            VStack(alignment: .leading, spacing: 8) {
                statRow("Season ticket holders",
                        store.seasonTicketHolders.formatted(),
                        identifier: CareerIdentifiers.supporterStat("season-ticket-holders"))
                statRow("Ground capacity",
                        store.stadiumInfo(forClubIndex: store.userClubIndex).capacity.formatted(),
                        identifier: CareerIdentifiers.supporterStat("ground-capacity"))
                if let nextAtmosphere {
                    statRow("Next-match atmosphere", nextAtmosphere,
                            identifier: CareerIdentifiers.supporterStat("next-match-atmosphere"))
                }
            }
        }
    }

    // MARK: Attendance trend

    private var attendanceCard: some View {
        card(title: "ATTENDANCE TREND", icon: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(store.attendanceHistory.suffix(5).enumerated()), id: \.offset) { offset, average in
                    let seasonsAgo = store.attendanceHistory.suffix(5).count - offset
                    statRow(seasonsAgo == 1 ? "Last season" : "\(seasonsAgo) seasons ago",
                            "\(average.formatted()) avg.",
                            identifier: CareerIdentifiers.supporterStat("attendance-\(seasonsAgo)"))
                }
            }
        }
    }

    // MARK: Traditions & culture

    private var traditionsCard: some View {
        card(title: "TRADITIONS", icon: "scroll.fill") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(FanCulture.traditions(for: store.userClub.name), id: \.self) { tradition in
                    Text("• \(tradition)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink.opacity(0.85))
                }
            }
        }
    }

    private var fanCultureCard: some View {
        card(title: "FAN CULTURE", icon: "person.3.fill") {
            Text(FanCulture.cultureProfile(for: store.userClub.name))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func terracesCard(_ star: Player) -> some View {
        card(title: "FROM THE TERRACES", icon: "music.note") {
            Text("\"\(ChantBook.goalChant(playerName: star.name))\"")
                .font(.system(size: 11, weight: .bold, design: .monospaced).italic())
                .foregroundStyle(CareerPalette.line)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Fan reactions

    private var reactionsCard: some View {
        card(title: "FAN REACTIONS", icon: "bubble.left.and.bubble.right.fill") {
            if store.socialFeed.isEmpty {
                Text("Nothing yet — big moments will show up here.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(CareerIdentifiers.supporterFeedEmpty)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(store.socialFeed.prefix(40).enumerated()), id: \.element.id) { index, post in
                        SocialPostRow(post: post, identifier: CareerIdentifiers.supporterPost(index))
                    }
                }
            }
        }
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier("career.supporter.end")
    }

    // MARK: Card & row primitives

    private func card(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
    }

    private func statRow(_ label: String, _ value: String, identifier: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// The light-card twin of the dark-theme `ConfidenceBar` used elsewhere —
/// same values, same colour semantics, drawn for the pale canvas. Pure
/// presentation: it renders `value`/`trend` and computes nothing.
private struct LightConfidenceBar: View {
    let value: Int
    var trend: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(CareerPalette.line.opacity(0.14))
                    Capsule().fill(confidenceColor(value))
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 8)
            Text("Confidence \(value)% \(confidenceTrendArrow(trend))")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(value) percent\(trend != 0 ? ", \(trend > 0 ? "rising" : "falling")" : "")")
    }
}

/// One generated fan reaction, in the light-card row style.
private struct SocialPostRow: View {
    let post: SocialPost
    let identifier: String

    private var accent: Color {
        switch post.sentiment {
        case .hype:    return confidenceColor(95)
        case .outrage: return Retro.warning
        case .banter:  return Retro.royalBlue
        case .concern: return Retro.warning.opacity(0.8)
        case .pride:   return CareerPalette.line
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(post.handle)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                Spacer()
                Text(post.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.7))
            }
            Text(post.text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text("♥ \(post.likeCount)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.7))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.canvas.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("Fan post from \(post.handle): \(post.text)")
    }
}
