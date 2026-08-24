//
//  HomeView.swift
//  Retro Season Manager
//
//  The manager's office dashboard and its supporting mini panels
//  (next match, medical centre, contracts, standings, fixtures).
//

import SwiftUI

// MARK: - Home / manager's office

/// Career dashboard card: keeps the established readable dark-green surface,
/// but adds the raised, edged treatment used by the redesigned mode screens.
struct CareerPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.emerald)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [Retro.forest, Retro.darkGreen],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Retro.emerald.opacity(0.22), lineWidth: 1))
        .shadow(color: Retro.darkGreen.opacity(0.18), radius: 8, y: 4)
    }
}

struct HomeView: View {
    let store: GameStore
    @Binding var section: GameSection
    @State private var showingSeasonObjectives = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        ScrollView {
            VStack(spacing: isCompact ? 10 : 14) {
                careerHero
                dayStrip
                boardStrip
                seasonObjectivesStrip
                WorldPulsePanel(store: store, section: $section)
                dashboardPanels
            }
            .padding(.horizontal, isCompact ? 10 : 18)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .background(CareerPalette.canvas)
    }

    private var careerHero: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Retro.darkGreen, Retro.forest, Retro.pitchGreen],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image("StadiumBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(0.18)
                HStack(spacing: isCompact ? 12 : 18) {
                    CrestView(shortName: store.userClub.shortName,
                              size: isCompact ? 58 : 76,
                              color: store.userColor)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MANAGER'S DESK")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Retro.gold)
                        Text(store.userClub.name.uppercased())
                            .font(.system(size: isCompact ? 21 : 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("\(store.managerName.isEmpty ? "MANAGER" : store.managerName.uppercased()) · SEASON \(store.seasonLabel)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            careerHeroBadge("\(store.divisionName(store.userDivisionTier))", Retro.emerald)
                            careerHeroBadge("\(store.managerReputation) REP", Retro.gold)
                            if store.isFormationBeddingIn {
                                careerHeroBadge("FORMATION BEDDING IN", Retro.highlight)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if !isCompact || geo.size.width > 620 {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(store.isUserMatchToday ? "MATCHDAY" : "NEXT TARGET")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(store.isUserMatchToday ? Retro.gold : .white.opacity(0.65))
                            Text(store.nextUserMatchInfo?.label.uppercased() ?? "SEASON COMPLETE")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                            Text("BOARD CONFIDENCE \(store.boardConfidence)%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.72))
                            GeometryReader { progressGeo in
                                Capsule()
                                    .fill(.white.opacity(0.22))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(store.boardConfidence >= 50 ? Retro.emerald : Retro.highlight)
                                            .frame(width: progressGeo.size.width * CGFloat(store.boardConfidence) / 100)
                                    }
                            }
                            .frame(width: isCompact ? 140 : 190, height: 7)
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 16 : 24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Retro.emerald.opacity(0.55), lineWidth: 1))
            .shadow(color: Retro.darkGreen.opacity(0.22), radius: 12, y: 6)
        }
        .frame(height: isCompact ? 142 : 168)
    }

    private func careerHeroBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(Retro.darkGreen)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var dashboardPanels: some View {
        if isCompact {
            // The compact order follows the manager's likely decisions:
            // match plan first, then context, then availability and squad
            // actions. A single column keeps every row readable.
            VStack(spacing: 10) {
                NextMatchPanel(store: store)
                StandingsMiniPanel(store: store, section: $section)
                FixturesMiniPanel(store: store, section: $section)
                MedicalCentrePanel(store: store, section: $section)
                SquadNeedsPanel(store: store, section: $section)
                ContractsPanel(store: store)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    NextMatchPanel(store: store)
                    MedicalCentrePanel(store: store, section: $section)
                    ContractsPanel(store: store)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 14) {
                    StandingsMiniPanel(store: store, section: $section)
                    FixturesMiniPanel(store: store, section: $section)
                    SquadNeedsPanel(store: store, section: $section)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var dayStrip: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        dateSummary
                        Spacer(minLength: 0)
                        if store.isUserMatchToday {
                            matchDayBadge
                        }
                    }
                    if isCompactHeight {
                        // Short screens: give the form and the bid/deadline
                        // alerts their own lines instead of a shared row.
                        VStack(alignment: .leading, spacing: 8) {
                            FormView(outcomes: store.recentForm(forClubIndex: store.userClubIndex, count: 6))
                            statusBadges
                        }
                    } else {
                        HStack(spacing: 8) {
                            FormView(outcomes: store.recentForm(forClubIndex: store.userClubIndex, count: 6))
                            Spacer(minLength: 0)
                            statusBadges
                        }
                    }
                    if canSkipToMatch {
                        skipButton
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    dateSummary
                    statusBadges
                    Spacer()
                    if canSkipToMatch {
                        skipButton
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Retro.panel.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dateSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.currentDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(countdownText)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(store.isUserMatchToday ? Retro.highlight : Retro.text.opacity(0.85))
                .lineLimit(1)
        }
    }

    private var matchDayBadge: some View {
        Text(store.isCupMatchDay ? "🏆 CUP DAY" : "⚽︎ MATCH DAY")
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(Retro.background)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Retro.highlight)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var statusBadges: some View {
        HStack(spacing: 8) {
            if !store.pendingOffers.isEmpty {
                Text("⚠️ \(store.pendingOffers.count) bid\(store.pendingOffers.count == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .lineLimit(1)
            }
            if store.isDeadlineDayRush, let days = store.daysUntilTransferDeadline {
                Text(days == 0 ? "🔥 DEADLINE DAY" : "🔥 Deadline in \(days)d")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
                    .lineLimit(1)
            }
        }
    }

    private var canSkipToMatch: Bool {
        !store.isSeasonOver && !store.isUserMatchToday
    }

    private var skipButton: some View {
        Button {
            Haptics.tap()
            store.runHeavy("Skipping to the next match…") {
                await store.advanceToNextMatch()
                if store.isUserMatchToday {
                    store.enterPreMatch()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "forward.end.fill")
                Text("SKIP TO MATCH")
            }
            .font(.system(.caption, design: .monospaced).bold())
            .frame(maxWidth: isCompact ? .infinity : nil)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Retro.accent)
            .foregroundStyle(Retro.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var countdownText: String {
        if store.isSeasonOver { return "SEASON COMPLETE" }
        if store.isUserMatchToday { return store.isCupMatchDay ? "🏆 CUP DAY" : "⚽︎ MATCH DAY" }
        if let days = store.daysUntilNextMatch {
            return "Next match in \(days) day\(days == 1 ? "" : "s")"
        }
        return ""
    }

    private var boardStrip: some View {
        Button {
            Haptics.tap()
            section = .transfers
        } label: {
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 12) {
                        boardObjective
                        boardMetrics
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(spacing: 14) {
                        boardObjective
                        Spacer()
                        boardMetrics
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Retro.panel.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var boardObjective: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BOARD OBJECTIVE")
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.75))
            Text(store.boardObjective)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text("Reputation: \(store.reputationLabel) (\(store.managerReputation))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
            if store.isObjectiveAtRisk {
                Text("⚠️ Off the pace for this")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var boardMetrics: some View {
        VStack(alignment: isCompact ? .leading : .trailing, spacing: 3) {
            Text("BUDGET \(formatMoney(store.userClub.transferBudget))")
                .foregroundStyle(Retro.highlight)
                .font(.system(.caption, design: .monospaced).bold())
            Text("Confidence \(store.boardConfidence)% \(confidenceTrendArrow(store.boardConfidenceTrend)) · \(store.jobSecurity)")
                .foregroundStyle(confidenceColor(store.boardConfidence))
                .font(.system(.caption, design: .monospaced).bold())
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            ZStack(alignment: .leading) {
                Capsule().fill(Retro.text.opacity(0.2))
                GeometryReader { geo in
                    Capsule()
                        .fill(confidenceColor(store.boardConfidence))
                        .frame(width: geo.size.width * CGFloat(store.boardConfidence) / 100)
                }
            }
            .frame(width: isCompact ? nil : 100, height: 5)
            if store.boardConfidence <= 20 {
                Text("⚠️ Sacking risk")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.35))
            }
            Text("Squad morale: \(store.teamMoraleLabel(forClubIndex: store.userClubIndex))")
                .foregroundStyle(Retro.text.opacity(0.85))
                .font(.system(.caption, design: .monospaced).bold())
            Text("Fans: \(store.fanMoodLabel)")
                .foregroundStyle(confidenceColor(store.fanConfidence))
                .font(.system(.caption, design: .monospaced).bold())
        }
        .frame(maxWidth: .infinity, alignment: isCompact ? .leading : .trailing)
    }

    private var seasonObjectivesStrip: some View {
        Button {
            Haptics.tap()
            showingSeasonObjectives = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundStyle(Retro.highlight)
                Text("🎯 \(store.completedSeasonObjectiveIDs.count)/\(store.seasonObjectives.count) season goals")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Retro.text.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Retro.panel.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSeasonObjectives) {
            SeasonObjectivesView(store: store)
        }
    }
}


// MARK: - World pulse

/// A compact living-world digest for the Career Home screen. It reuses
/// existing news, newspaper and supporter systems so the home dashboard
/// immediately shows that the football world is moving around the player.
struct WorldPulsePanel: View {
    let store: GameStore
    @Binding var section: GameSection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    private var leadHeadline: Newspaper? {
        store.newspapers.first { $0.importance >= .major } ?? store.newspapers.first
    }

    private var worldStory: NewsItem? {
        store.news.first { $0.category == .world }
    }

    private var clubStory: NewsItem? {
        store.news.first { $0.category != .world }
    }

    private var fanPost: SocialPost? {
        store.socialFeed.first
    }

    private var matchPressure: String? {
        guard let match = store.nextUserMatchInfo else { return nil }
        let isHome = match.homeIndex == store.userClubIndex
        let opponentIndex = isHome ? match.awayIndex : match.homeIndex
        guard store.clubs.indices.contains(opponentIndex) else { return nil }
        let opponent = store.clubs[opponentIndex]
        let atmosphere = store.matchAtmosphere(homeIndex: match.homeIndex, awayIndex: match.awayIndex)
        let venue = isHome ? "home" : "away"
        return "\(venue.uppercased()) vs \(opponent.shortName) · \(atmosphere)"
    }

    var body: some View {
        CareerPanel(title: "FOOTBALL WORLD") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Latest from around the game")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.75))
                    Spacer()
                    if !store.unreadNewsIDs.isEmpty {
                        Text("\(store.unreadNewsIDs.count) unread")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight)
                    }
                }

                Group {
                    if isCompact {
                        VStack(spacing: 8) {
                            leadPulse
                            worldPulse
                            fanPulse
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            leadPulse
                            worldPulse
                            fanPulse
                        }
                    }
                }

                if isCompactHeight {
                    // Short screens: the match-pressure line gets its own
                    // row so it never squeezes the inbox shortcut.
                    VStack(alignment: .leading, spacing: 8) {
                        if worldStory != nil, let matchPressure {
                            Text(matchPressure)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.7))
                                .lineLimit(2)
                        }
                        Button {
                            Haptics.tap()
                            section = .inbox
                        } label: {
                            Text("OPEN INBOX")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.background)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Retro.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack {
                        if worldStory != nil, let matchPressure {
                            Text(matchPressure)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            Haptics.tap()
                            section = .inbox
                        } label: {
                            Text("OPEN INBOX")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.background)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Retro.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var leadPulse: some View {
        pulseColumn {
            if let leadHeadline {
                pulseRow(icon: "▰",
                         title: leadHeadline.headline,
                         body: leadHeadline.standfirst,
                         accent: Retro.highlight)
            } else if let clubStory {
                pulseRow(icon: clubStory.category.glyph,
                         title: clubStory.title,
                         body: clubStory.body,
                         accent: Retro.highlight)
            } else {
                pulseRow(icon: "ⓘ",
                         title: "Season story building",
                         body: "Headlines will appear here as the campaign develops.",
                         accent: Retro.text.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private var worldPulse: some View {
        pulseColumn {
            if let worldStory {
                pulseRow(icon: worldStory.category.glyph,
                         title: worldStory.title,
                         body: worldStory.body,
                         accent: Retro.accent)
            } else if let matchPressure {
                pulseRow(icon: "⚽︎",
                         title: "Matchday pressure",
                         body: matchPressure,
                         accent: Retro.accent)
            } else {
                pulseRow(icon: "🌍",
                         title: "World watch",
                         body: "Takeovers, crises, rivalries and wonderkids will surface here.",
                         accent: Retro.accent.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private var fanPulse: some View {
        pulseColumn {
            if let fanPost {
                pulseRow(icon: "☊",
                         title: store.fanMoodLabel,
                         body: "\(fanPost.handle): \(fanPost.text)",
                         accent: Retro.gold)
            } else {
                pulseRow(icon: "☊",
                         title: "Fans: \(store.fanMoodLabel)",
                         body: store.fanExpectation(),
                         accent: Retro.gold.opacity(0.85))
            }
        }
    }

    private func pulseColumn<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Retro.background.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func pulseRow(icon: String, title: String, body: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(icon)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .lineLimit(2)
            }
            Text(body)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.78))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Next match panel

struct NextMatchPanel: View {
    let store: GameStore

    var body: some View {
        CareerPanel(title: "NEXT MATCH") {
            if let match = store.nextUserMatchInfo {
                let isHome = match.homeIndex == store.userClubIndex
                let opponentIndex = isHome ? match.awayIndex : match.homeIndex
                let opponent = store.clubs[opponentIndex]
                let probs = store.outcomeProbabilities(homeIndex: match.homeIndex, awayIndex: match.awayIndex)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(isHome ? "HOME" : "AWAY")
                            .foregroundStyle(Retro.highlight)
                        Spacer()
                        Text(match.label)
                            .foregroundStyle(match.isCup ? Retro.highlight : Retro.text.opacity(0.85))
                    }
                    .font(.system(.caption, design: .monospaced).bold())

                    HStack(spacing: 12) {
                        CrestView(shortName: opponent.shortName, size: 48, color: store.color(forClubIndex: opponentIndex))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opponent.name)
                                .font(.system(.body, design: .monospaced).bold())
                            StarRatingView(stars: store.starRating(forClubIndex: opponentIndex))
                            Text(match.isCup ? store.clubDivisionLabel(forClubIndex: opponentIndex)
                                 : "\(ordinal(store.position(ofClubIndex: opponentIndex))) in the league")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.85))
                        }
                    }

                    labelled("FORM") {
                        FormView(outcomes: store.recentForm(forClubIndex: opponentIndex))
                    }

                    labelled("ODDS") {
                        let userWin = isHome ? probs.home : probs.away
                        let oppWin = isHome ? probs.away : probs.home
                        HStack(spacing: 10) {
                            oddsChip("You", userWin, favourite: userWin >= oppWin && userWin >= probs.draw)
                            oddsChip("Draw", probs.draw, favourite: probs.draw > userWin && probs.draw > oppWin)
                            oddsChip(opponent.shortName, oppWin, favourite: oppWin > userWin && oppWin >= probs.draw)
                        }
                    }

                    labelled("MANAGER") {
                        Text(store.manager(forClubIndex: opponentIndex))
                            .font(.system(.callout, design: .monospaced))
                    }
                }
            } else {
                seasonOver
            }
        }
    }

    @ViewBuilder
    private var seasonOver: some View {
        if let champion = store.champion {
            VStack(alignment: .leading, spacing: 8) {
                Text("SEASON \(store.season) COMPLETE")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                Text("🏆 Champions: \(champion.name)")
                    .font(.system(.callout, design: .monospaced))
                Text(champion.id == store.userClub.id
                     ? "Congratulations, boss — you won the league!"
                     : "You finished \(ordinal(store.userPosition)). Press NEW SEASON to go again.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
        }
    }

    private func labelled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.8))
            content()
        }
    }

    private func oddsChip(_ title: String, _ probability: Double, favourite: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .monospaced))
            Text("\(Int((probability * 100).rounded()))%")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(favourite ? Retro.highlight : Retro.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Retro.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Medical centre

struct MedicalCentrePanel: View {
    let store: GameStore
    @Binding var section: GameSection
    @State private var showingMedicalCentre = false

    var body: some View {
        Button {
            Haptics.tap()
            showingMedicalCentre = true
        } label: {
            CareerPanel(title: "MEDICAL CENTRE") {
                let injured = store.injuredPlayers(forClubIndex: store.userClubIndex)
                let suspended = store.suspendedPlayers(forClubIndex: store.userClubIndex)
                if injured.isEmpty && suspended.isEmpty {
                    Text("No injuries or bans — squad fully available. ✓")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(injured.prefix(5)) { player in
                            HStack(spacing: 8) {
                                Text("⚠️")
                                Text(player.name)
                                Spacer()
                                Text(returnDateText(for: player))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(player.injuryWeeks >= 3 ? .red : Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                        ForEach(suspended.prefix(3)) { player in
                            HStack(spacing: 8) {
                                Text("🟥")
                                Text(player.name)
                                Spacer()
                                Text("banned \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es")")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                        let hiddenCount = max(0, injured.count - 5) + max(0, suspended.count - 3)
                        if hiddenCount > 0 {
                            Text("+ \(hiddenCount) more — view squad")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingMedicalCentre) {
            MedicalCentreSheet(store: store)
        }
    }

    private func returnDateText(for player: Player) -> String {
        guard let date = store.expectedReturnDate(for: player) else {
            return "out ~\(player.injuryWeeks) wk\(player.injuryWeeks == 1 ? "" : "s")"
        }
        return "back ~\(date.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

/// The full Medical Centre — every injured or suspended squad player with
/// how long they're out and (for injuries) a fitness-return countdown, in
/// place of the Home dashboard panel's five-a-side preview.
struct MedicalCentreSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Computed once per render rather than re-filtering the squad
        // separately for the empty-state check, each panel header count,
        // and each ForEach.
        let injured = store.injuredPlayers(forClubIndex: store.userClubIndex)
        let suspended = store.suspendedPlayers(forClubIndex: store.userClubIndex)

        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("MEDICAL CENTRE")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Retro.text.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                if injured.isEmpty && suspended.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("✓")
                            .font(.system(size: 40))
                            .foregroundStyle(Retro.accent)
                        Text("Full squad availability — no injuries or bans.")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if !injured.isEmpty {
                                CareerPanel(title: "INJURED (\(injured.count))") {
                                    VStack(spacing: 10) {
                                        ForEach(injured) { player in
                                            injuryRow(player)
                                        }
                                    }
                                }
                            }
                            if !suspended.isEmpty {
                                CareerPanel(title: "SUSPENDED (\(suspended.count))") {
                                    VStack(spacing: 10) {
                                        ForEach(suspended) { player in
                                            suspensionRow(player)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func injuryRow(_ player: Player) -> some View {
        let severe = player.injuryWeeks >= 3
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(severe ? Color(red: 0.95, green: 0.4, blue: 0.35) : Retro.highlight)
                    .frame(width: 8, height: 8)
                Text(player.position.rawValue)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Retro.highlight)
                    .clipShape(Capsule())
                Text(player.name)
                    .font(.system(.callout, design: .monospaced).bold())
                Spacer()
                Text(returnDateText(for: player))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(severe ? Color(red: 0.95, green: 0.4, blue: 0.35) : Retro.highlight)
            }
            Text("\(player.durability.label) durability · \(player.injuriesThisSeason) injur\(player.injuriesThisSeason == 1 ? "y" : "ies") this season")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
        }
        .padding(10)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func suspensionRow(_ player: Player) -> some View {
        HStack {
            Text("🟥")
            Text(player.name)
                .font(.system(.callout, design: .monospaced).bold())
            Spacer()
            Text("\(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es") left")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
        .padding(10)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func returnDateText(for player: Player) -> String {
        guard let date = store.expectedReturnDate(for: player) else {
            return "out ~\(player.injuryWeeks) wk\(player.injuryWeeks == 1 ? "" : "s")"
        }
        return "back ~\(date.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

// MARK: - Contracts panel

/// Contracts never just expire and cost you a player any more — an
/// unrenewed deal quietly auto-renews at season's end — but renewing on
/// your own terms is still better than leaving it to chance, so this
/// surfaces who's worth locking down now.
/// Flags detailed positions where the squad is dangerously thin — a quick
/// at-a-glance nudge toward what the transfer market should be fixing.
struct SquadNeedsPanel: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        Button {
            Haptics.tap()
            section = .squad
        } label: {
            CareerPanel(title: "SQUAD NEEDS") {
                let needs = store.squadNeeds()
                if needs.isEmpty {
                    Text("Squad has cover everywhere. ✓")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(needs, id: \.role) { need in
                            HStack(spacing: 8) {
                                Text(need.count == 0 ? "🔴" : "🟡")
                                Text(need.role.fullName)
                                Spacer()
                                Text(need.count == 0 ? "none fit" : "\(need.count) fit")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(need.count == 0 ? Color(red: 0.9, green: 0.35, blue: 0.35) : Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ContractsPanel: View {
    let store: GameStore
    @State private var renewing: Player?
    @State private var message: String?

    var body: some View {
        CareerPanel(title: "CONTRACTS") {
            let expiring = store.expiringContracts
            if expiring.isEmpty {
                Text("No deals expiring soon. ✓")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let message {
                        Text(message)
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight)
                    }
                    ForEach(expiring.prefix(5)) { player in
                        Button {
                            Haptics.tap()
                            renewing = player
                        } label: {
                            HStack(spacing: 8) {
                                Text(player.contractYears <= 0 ? "⏳" : "📄")
                                Text(player.name)
                                Spacer()
                                Text(player.contractYears <= 0 ? "expires this year" : "\(player.contractYears) yr left")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(player.contractYears <= 0 ? .red : Retro.highlight)
                            }
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text)
                        }
                        .buttonStyle(.plain)
                    }
                    if expiring.count > 5 {
                        Text("+ \(expiring.count - 5) more — view squad")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    }
                }
            }
        }
        .sheet(item: $renewing) { player in
            ContractOfferSheet(store: store, player: player) { result in
                message = result
                renewing = nil
            }
        }
    }
}

// MARK: - Standings mini panel

struct StandingsMiniPanel: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        Button {
            Haptics.tap()
            section = .table
        } label: {
            CareerPanel(title: store.divisionName(store.userDivisionTier).uppercased()) {
                let table = store.userTable()
                let userRow = table.firstIndex { $0.id == store.userClub.id } ?? 0
                let lower = max(0, min(userRow - 1, table.count - 4))
                let window = Array(table.enumerated())[lower..<min(lower + 4, table.count)]

                VStack(spacing: 4) {
                    HStack {
                        Text("Pos").frame(width: 36, alignment: .leading)
                        Text("Team")
                        Spacer()
                        Text("P").frame(width: 24, alignment: .trailing)
                        Text("GD").frame(width: 30, alignment: .trailing)
                        Text("Pts").frame(width: 30, alignment: .trailing)
                    }
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.8))

                    ForEach(Array(window), id: \.element.id) { index, club in
                        let isUser = club.id == store.userClub.id
                        HStack {
                            Text(ordinal(index + 1)).frame(width: 36, alignment: .leading)
                            Text(club.shortName)
                            Spacer()
                            Text("\(club.played)").frame(width: 24, alignment: .trailing)
                            Text("\(club.goalDifference)").frame(width: 30, alignment: .trailing)
                            Text("\(club.points)").frame(width: 30, alignment: .trailing)
                        }
                        .font(.system(.callout, design: .monospaced)
                            .weight(isUser ? .bold : .regular))
                        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fixtures mini panel

struct FixturesMiniPanel: View {
    let store: GameStore
    @Binding var section: GameSection

    var body: some View {
        Button {
            Haptics.tap()
            section = .fixtures
        } label: {
            CareerPanel(title: "FIXTURES & RESULTS · SEE CALENDAR") {
                VStack(spacing: 6) {
                    ForEach(store.userFixtureWindow()) { fixture in
                        fixtureRow(fixture)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func fixtureRow(_ fixture: Fixture) -> some View {
        let isHome = fixture.homeIndex == store.userClubIndex
        let opponentIndex = isHome ? fixture.awayIndex : fixture.homeIndex
        let opponent = store.clubs[opponentIndex]
        return HStack(spacing: 8) {
            Text(store.date(forMatchday: fixture.matchday).formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
                .frame(width: 58, alignment: .leading)
            Text(opponent.shortName)
            Text(isHome ? "H" : "A")
                .foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            if fixture.played {
                let us = isHome ? fixture.homeGoals : fixture.awayGoals
                let them = isHome ? fixture.awayGoals : fixture.homeGoals
                Text("\(us)-\(them)")
                    .foregroundStyle(us > them ? Retro.accent : (us == them ? Retro.text : Retro.highlight))
            } else {
                let difficulty = store.fixtureDifficulty(opponentIndex: opponentIndex)
                Text(String(repeating: "★", count: difficulty))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(difficultyColor(difficulty))
            }
        }
        .font(.system(.callout, design: .monospaced))
    }

    private func difficultyColor(_ stars: Int) -> Color {
        switch stars {
        case 5, 4: return Color(red: 0.85, green: 0.35, blue: 0.3)
        case 3: return Retro.highlight
        default: return Retro.accent
        }
    }
}

