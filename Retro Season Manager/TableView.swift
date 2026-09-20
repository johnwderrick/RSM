import SwiftUI

private enum CompetitionTab: String, CaseIterable, Identifiable {
    case league = "LEAGUE", faCup = "NATIONAL CUP", leagueCup = "LEAGUE TROPHY"
    case europe = "CONTINENTAL CUP", uefaCup = "MIDWEEK CUP"
    var id: String { rawValue }
    var slug: String { rawValue.lowercased().replacingOccurrences(of: " ", with: "-") }
}

struct TableView: View {
    let store: GameStore
    @State private var tier: Int?
    @State private var competition: CompetitionTab = .league
    @State private var squadClubIndex: IdentifiableInt?

    private var shownTier: Int { tier ?? store.userDivisionTier }
    private var table: [Club] { store.leagueTable(tier: shownTier) }
    private var userFixtures: [Fixture] {
        store.fixtures.filter { $0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex }
            .sorted { $0.matchday < $1.matchday }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    competitionTabs
                    switch competition {
                    case .league: leagueSection(wide: geo.size.width >= 900)
                    case .faCup: cupSection(GameStore.cupName, store.cupTies, store.cupRoundLabel, store.cupWinnerName)
                    case .leagueCup: cupSection(GameStore.leagueCupName, store.leagueCupTies, store.leagueCupRoundLabel, store.leagueCupWinnerName)
                    case .europe: cupSection(GameStore.euroName, store.euroTies, store.euroWinnerName == nil ? store.euroRoundLabel : "Completed", store.euroWinnerName)
                    case .uefaCup: cupSection(GameStore.uefaCupName, store.uefaCupTies, store.uefaCupRoundLabel, store.uefaCupWinnerName)
                    }
                }
                .padding(14)
            }
            .accessibilityIdentifier("career.table.scroll")
            .background(CareerPalette.canvas)
        }
        .sheet(item: $squadClubIndex) { ClubSquadSheet(store: store, clubIndex: $0.value) }
    }

    private var summaryBand: some View {
        let ownTable = store.userTable()
        let position = (ownTable.firstIndex { $0.id == store.userClub.id } ?? 0) + 1
        return HStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 24, weight: .black)).foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52).background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("COMPETITION CENTRE").font(.system(size: 15, weight: .black, design: .monospaced))
                Text("SEASON \(store.season) · \(store.divisionName(store.userDivisionTier).uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer(minLength: 0)
            metric("POSITION", ordinal(position)); metric("POINTS", "\(store.userClub.points)"); metric("PLAYED", "\(store.userClub.played)")
            VStack(alignment: .trailing, spacing: 3) {
                Text("FORM").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                FormView(outcomes: store.recentForm(forClubIndex: store.userClubIndex), emptyColor: CareerPalette.mutedInk)
            }
        }
        .foregroundStyle(CareerPalette.ink).padding(14).background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityIdentifier("career.table.summary")
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            Text(value).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
        }
    }

    private var competitionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(CompetitionTab.allCases) { tab in
                    Button { Haptics.tap(); competition = tab } label: {
                        Text(tab.rawValue).font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(competition == tab ? .white : CareerPalette.mutedInk)
                            .padding(.horizontal, 13).padding(.vertical, 9)
                            .background(competition == tab ? CareerPalette.line : CareerPalette.surface).clipShape(Capsule())
                            .overlay(Capsule().stroke(CareerPalette.line.opacity(competition == tab ? 0 : 0.18)))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("career.table.competition.\(tab.slug)")
                    .accessibilityAddTraits(competition == tab ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder private func leagueSection(wide: Bool) -> some View {
        divisionTabs
        if wide {
            HStack(alignment: .top, spacing: 12) {
                leagueTableCard.frame(maxWidth: .infinity)
                VStack(spacing: 12) { nextFixtureCard; fixtureCentre; topScorers }.frame(width: 360)
            }
        } else {
            VStack(spacing: 12) { leagueTableCard; nextFixtureCard; fixtureCentre; topScorers }
        }
    }

    private var divisionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(0..<GameStore.divisionNames.count, id: \.self) { item in
                    Button { Haptics.tap(); tier = item } label: {
                        Text(GameStore.divisionNames[item].uppercased()).font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(shownTier == item ? CareerPalette.ink : CareerPalette.mutedInk)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(shownTier == item ? Retro.highlight.opacity(0.72) : CareerPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.table.division.\(item)")
                    .accessibilityAddTraits(shownTier == item ? .isSelected : [])
                }
            }
        }
    }

    private var leagueTableCard: some View {
        CompetitionCard(title: GameStore.divisionNames[shownTier].uppercased(), subtitle: "FULL LEAGUE TABLE", symbol: "list.number") {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("POS").frame(width: 34, alignment: .leading); Text("CLUB"); Spacer()
                    header("P"); header("W"); header("D"); header("L"); header("GD", 34); header("PTS", 36)
                }
                .font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                .padding(.horizontal, 8).padding(.bottom, 6)
                .accessibilityIdentifier("career.table.leagueTable")
                ForEach(Array(table.enumerated()), id: \.element.id) { index, club in
                    tableRow(club, rank: index + 1)
                    if index < table.count - 1 { Rectangle().fill(CareerPalette.line.opacity(0.08)).frame(height: 1) }
                }
                zoneKey.padding(.top, 9)
            }
        }
    }

    private func header(_ text: String, _ width: CGFloat = 28) -> some View { Text(text).frame(width: width, alignment: .trailing) }
    private func number(_ value: Int) -> some View { Text("\(value)").frame(width: 28, alignment: .trailing) }

    private func tableRow(_ club: Club, rank: Int) -> some View {
        let isUser = club.id == store.userClub.id
        return Button {
            Haptics.tap()
            if let index = store.clubs.firstIndex(where: { $0.id == club.id }) { squadClubIndex = IdentifiableInt(value: index) }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 5) { RoundedRectangle(cornerRadius: 2).fill(zoneColor(rank)).frame(width: 3, height: 20); Text("\(rank)") }
                    .frame(width: 34, alignment: .leading)
                Text(club.shortName).fontWeight(isUser ? .black : .semibold).lineLimit(1); Spacer(minLength: 3)
                number(club.played); number(club.won); number(club.drawn); number(club.lost)
                Text(club.goalDifference > 0 ? "+\(club.goalDifference)" : "\(club.goalDifference)").frame(width: 34, alignment: .trailing)
                Text("\(club.points)").fontWeight(.black).frame(width: 36, alignment: .trailing)
            }
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(CareerPalette.ink)
            .padding(.horizontal, 8).padding(.vertical, 6).background(isUser ? CareerPalette.line.opacity(0.11) : Color.clear)
            .overlay(alignment: .leading) { Rectangle().fill(isUser ? CareerPalette.line : Color.clear).frame(width: 3) }
        }
        .buttonStyle(.plain).accessibilityIdentifier(isUser ? "career.table.userRow" : "career.table.club.\(rank)")
        .accessibilityLabel("Position \(rank), \(club.name), played \(club.played), won \(club.won), drawn \(club.drawn), lost \(club.lost), goal difference \(club.goalDifference), \(club.points) points\(isUser ? ", your club" : "")")
    }

    private var zoneKey: some View {
        HStack(spacing: 11) {
            if shownTier > 0 { zoneLabel("AUTOMATIC", CareerPalette.line); zoneLabel("PLAY-OFF", .blue.opacity(0.75)) }
            if shownTier < GameStore.divisionNames.count - 1 { zoneLabel("RELEGATION", .orange) }
            Spacer(); Text("TAP A CLUB FOR SQUAD").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
        }
    }
    private func zoneLabel(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 6, height: 6); Text(text).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk) }
    }
    private func zoneColor(_ rank: Int) -> Color {
        if shownTier > 0 { if rank <= 2 { return CareerPalette.line }; if rank <= 6 { return .blue.opacity(0.75) } }
        if shownTier < GameStore.divisionNames.count - 1 && rank > max(0, table.count - 3) { return .orange }
        return CareerPalette.mutedInk.opacity(0.28)
    }

    @ViewBuilder private var nextFixtureCard: some View {
        if let fixture = userFixtures.first(where: { !$0.played }) {
            let home = fixture.homeIndex == store.userClubIndex
            let opponentIndex = home ? fixture.awayIndex : fixture.homeIndex
            let opponent = store.clubs[opponentIndex]
            CompetitionCard(title: "NEXT FIXTURE", subtitle: "MATCHDAY \(fixture.matchday)", symbol: "calendar.badge.clock") {
                HStack(spacing: 10) {
                    CrestView(shortName: opponent.shortName, size: 38, color: store.color(forClubIndex: opponentIndex))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(opponent.name).font(.system(size: 12, weight: .black, design: .monospaced)).lineLimit(1)
                        Text("\(home ? "HOME" : "AWAY") · \(store.date(forMatchday: fixture.matchday).formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                    }
                    Spacer(); Text(String(repeating: "★", count: store.fixtureDifficulty(opponentIndex: opponentIndex))).font(.system(size: 9)).foregroundStyle(Retro.highlight)
                }.accessibilityIdentifier("career.table.nextFixture")
            }
        }
    }

    private var fixtureCentre: some View {
        let recent = Array(userFixtures.filter(\.played).suffix(4).reversed())
        let upcoming = Array(userFixtures.filter { !$0.played }.prefix(4))
        return CompetitionCard(title: "FIXTURE CENTRE", subtitle: "RECENT & UPCOMING", symbol: "sportscourt.fill") {
            VStack(alignment: .leading, spacing: 8) {
                fixtureHeading("UPCOMING")
                    .accessibilityIdentifier("career.table.fixtureCentre")
                if upcoming.isEmpty { emptyLine("No league fixtures remaining") }
                ForEach(upcoming) { fixtureRow($0) }
                Rectangle().fill(CareerPalette.line.opacity(0.10)).frame(height: 1)
                fixtureHeading("RECENT RESULTS")
                    .accessibilityIdentifier("career.table.fixtureCentre.recent")
                if recent.isEmpty { emptyLine("No league results yet") }
                ForEach(recent) { fixtureRow($0) }
            }
        }
    }
    private func fixtureHeading(_ text: String) -> some View { Text(text).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.line) }
    private func emptyLine(_ text: String) -> some View { Text(text).font(.system(size: 9, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk) }
    private func fixtureRow(_ fixture: Fixture) -> some View {
        let home = fixture.homeIndex == store.userClubIndex
        let opponent = store.clubs[home ? fixture.awayIndex : fixture.homeIndex]
        let scored = home ? fixture.homeGoals : fixture.awayGoals, conceded = home ? fixture.awayGoals : fixture.homeGoals
        return HStack(spacing: 6) {
            Text(store.date(forMatchday: fixture.matchday).formatted(.dateTime.day().month(.abbreviated))).frame(width: 47, alignment: .leading).foregroundStyle(CareerPalette.mutedInk)
            Text(home ? "H" : "A").fontWeight(.black).foregroundStyle(CareerPalette.line); Text(opponent.shortName).lineLimit(1); Spacer()
            if fixture.played {
                Text(scored > conceded ? "W" : (scored == conceded ? "D" : "L")).fontWeight(.black).foregroundStyle(.white).frame(width: 19, height: 19)
                    .background(scored > conceded ? CareerPalette.line : (scored == conceded ? CareerPalette.mutedInk : .orange)).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("\(scored)–\(conceded)").fontWeight(.black)
            } else { Text("MD \(fixture.matchday)").foregroundStyle(CareerPalette.mutedInk) }
        }.font(.system(size: 9, design: .monospaced)).foregroundStyle(CareerPalette.ink).padding(.vertical, 2)
    }

    private var topScorers: some View {
        CompetitionCard(title: "TOP SCORERS", subtitle: GameStore.divisionNames[shownTier].uppercased(), symbol: "soccerball") {
            let scorers = store.topScorers(limit: 5, tier: shownTier)
            if scorers.isEmpty { emptyLine("No goals scored yet") } else {
                VStack(spacing: 5) {
                    ForEach(Array(scorers.enumerated()), id: \.offset) { index, entry in
                        HStack { Text("\(index + 1)").foregroundStyle(CareerPalette.mutedInk).frame(width: 16); Text(entry.player.name).lineLimit(1); Text(entry.club.shortName).foregroundStyle(CareerPalette.mutedInk); Spacer(); Text("\(entry.player.goals)").fontWeight(.black).foregroundStyle(CareerPalette.line) }
                            .font(.system(size: 9, design: .monospaced))
                    }
                }
            }
        }
    }

    @ViewBuilder private func cupSection(_ name: String, _ ties: [CupTie], _ round: String, _ winner: String?) -> some View {
        CompetitionCard(title: name.uppercased(), subtitle: round.uppercased(), symbol: "trophy.fill") {
            if let winner { Text("🏆 \(winner) lifted the \(name)").font(.system(size: 12, weight: .black, design: .monospaced)) }
            else if ties.isEmpty { emptyLine("This competition hasn't started yet") }
            else { VStack(spacing: 5) { ForEach(ties) { cupTieRow($0) } } }
        }
    }
    private func cupTieRow(_ tie: CupTie) -> some View {
        let isUser = tie.homeIndex == store.userClubIndex || tie.awayIndex == store.userClubIndex
        return HStack(spacing: 8) {
            Text(store.clubs[tie.homeIndex].shortName).frame(maxWidth: .infinity, alignment: .trailing)
                .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
            Text(tie.isBye ? "BYE" : (tie.played ? "\(tie.homeGoals)–\(tie.awayGoals)\(tie.onPenalties ? " P" : "")" : "V"))
                .fontWeight(.black).foregroundStyle(tie.played ? CareerPalette.line : CareerPalette.mutedInk)
            Text(tie.isBye ? "" : store.clubs[tie.awayIndex].shortName).frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture { if !tie.isBye { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.awayIndex) } }
        }
        .font(.system(size: 10, weight: isUser ? .black : .semibold, design: .monospaced)).foregroundStyle(CareerPalette.ink)
        .padding(9).background(isUser ? CareerPalette.line.opacity(0.10) : CareerPalette.canvas).clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct CompetitionCard<Content: View>: View {
    let title: String, subtitle: String, symbol: String, content: Content
    init(title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(CareerPalette.line)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
                    Text(subtitle).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                }; Spacer()
            }; content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 2)
    }
}
